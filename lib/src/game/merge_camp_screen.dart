import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ads/ad_banner.dart';
import '../ads/ad_service.dart';
import '../art/camp_palette.dart';
import '../art/camp_scenery.dart';
import '../art/camp_tile_art.dart';
import '../audio/sound_mute_store.dart';
import '../meta/camp_progress.dart';
import '../meta/camp_progress_store.dart';
import '../meta/camp_theme.dart';
import '../meta/missions.dart';
import '../platform/game_platform.dart';
import 'feedback_fx.dart';
import 'how_to_play.dart';
import 'merge_camp_controller.dart';
import 'ui/album_overlay.dart';
import 'ui/banners.dart';
import 'ui/board_fx.dart';
import 'ui/camp_layout.dart';
import 'ui/run_summary_overlay.dart';
import '../../result_registration.dart';

class MergeCampScreen extends StatefulWidget {
  const MergeCampScreen({
    super.key,
    this.enableAds = false,
    this.platform = const NoopGamePlatform(),
    this.controller,
    this.howToPlayStore = const HowToPlayStore(),
    this.soundMuteStore = const SoundMuteStore(),
    this.progressStore = const CampProgressStore(),
    this.missions,
    this.animateArt = true,
  });

  final bool enableAds;
  final GamePlatform platform;

  /// Injected for tests; when null the screen owns its controller.
  final MergeCampController? controller;

  /// First-run tutorial flag storage; tests inject a fake.
  final HowToPlayStore howToPlayStore;

  /// Persisted user mute choice; tests inject a fake.
  final SoundMuteStore soundMuteStore;

  /// Best score, album, camp XP and theme; tests inject a memory store.
  final CampProgressStore progressStore;

  /// Injected for tests (seeded missions); when null the screen owns one.
  final MissionBoard? missions;

  /// Looping art motion (tile loops, scenery, danger pulse). Tests turn it
  /// off so pumpAndSettle can settle; one-shot effects still play.
  final bool animateArt;

  @override
  State<MergeCampScreen> createState() => _MergeCampScreenState();
}

class _MergeCampScreenState extends State<MergeCampScreen> {
  late final MergeCampController _controller;
  late final FeedbackFx _feedback;
  late final MissionBoard _missions;
  late final AppLifecycleListener _lifecycle;
  final BoardFx _fx = BoardFx();
  bool _trailAxeMode = false;
  // Keyboard cursor; null until the player uses the keyboard.
  int? _cursor;
  // Game keys bubble up to this node from any focused child, so it never
  // needs a Tab stop; skipping it keeps Tab inside the how-to-play card.
  final FocusNode _focusNode = FocusNode(
    debugLabel: 'MergeCampBoard',
    skipTraversal: true,
  );
  final FocusNode _playAgainFocus = FocusNode(debugLabel: 'PlayAgain');
  // User sound toggle; effective mute also includes the platform mute.
  bool _soundMuted = false;
  bool _soundTouched = false;
  bool _handlingTap = false;
  bool _wasGameOver = false;
  bool _breakAdInProgress = false;
  int _completedRuns = 0;
  // The tutorial blocks all game input while the first-run check is pending
  // (_tutorialLoading) and while the card is open (_showHowTo).
  bool _tutorialLoading = true;
  bool _showHowTo = false;
  bool _albumOpen = false;

  // Whether the platform currently believes gameplay is running.
  bool _gameplayActive = false;

  // Meta progress. Changes made before the stored value has loaded are
  // merged into it once it arrives.
  CampProgress _progress = const CampProgress.initial();
  bool _progressLoaded = false;
  bool _progressChangedBeforeLoad = false;
  int _xpBeforeLoad = 0;
  bool _themeTouched = false;

  // Run bookkeeping driven by controller notifications.
  int _seenPlacements = 0;
  bool _handlingChange = false;
  bool _runApplied = false;
  RunReport? _report;

  // Presentation state.
  bool _reduceMotion = false;
  bool _wasDanger = false;
  int _shakeSerial = 0;
  int _chainSerial = 0;
  int _chainLength = 0;
  int _discoverySerial = 0;
  int _discoveryTier = 0;
  int _toastSerial = 0;
  final List<ToastMessage> _toasts = <ToastMessage>[];

  static const int _missionBonusScore = 150;

  bool get _tutorialBlocking => _tutorialLoading || _showHowTo;
  bool get _overlayOpen => _albumOpen || _controller.isGameOver;
  CampTheme get _theme => _progress.selectedTheme;
  bool get _effectsOn => !_reduceMotion;

  @override
  void initState() {
    super.initState();
    unawaited(_checkTutorial());
    _feedback = FeedbackFx(
      isMuted: () => _soundMuted || widget.platform.isAudioMuted,
    );
    unawaited(_feedback.initialize());
    unawaited(_loadSoundMuted());
    unawaited(_loadProgress());
    _missions = widget.missions ?? MissionBoard();
    _controller = (widget.controller ?? MergeCampController())
      ..addListener(_onChanged);
    _wasGameOver = _controller.isGameOver;
    _seenPlacements = _controller.placements;
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) => _feedback.setAppVisible(
        state == AppLifecycleState.resumed ||
            state == AppLifecycleState.inactive,
      ),
    );
    HardwareKeyboard.instance.addHandler(_onHardwareKey);
    // Portal mute settings and ads can change the platform mute at any time.
    widget.platform.setAudioMuteListener(_feedback.refreshMute);
  }

  Future<void> _loadSoundMuted() async {
    var muted = false;
    try {
      muted = await widget.soundMuteStore.loadMuted();
    } catch (_) {}
    if (!mounted) return;
    // A toggle made before the load finished wins over the stored value.
    if (!_soundTouched) setState(() => _soundMuted = muted);
    // Music waits for the stored mute so a muted player never hears a blip
    // (and, on web, for the first user input).
    _feedback.startMusic();
  }

  Future<void> _loadProgress() async {
    CampProgress loaded;
    try {
      loaded = await widget.progressStore.load();
    } catch (_) {
      loaded = const CampProgress.initial();
    }
    if (!mounted) return;
    setState(() {
      _progressLoaded = true;
      if (!_progressChangedBeforeLoad) {
        _progress = loaded;
        return;
      }
      _progress = CampProgress(
        bestScore: math.max(loaded.bestScore, _progress.bestScore),
        discoveredTiers: {
          ...loaded.discoveredTiers,
          ..._progress.discoveredTiers,
        },
        totalXp: loaded.totalXp + _xpBeforeLoad,
        selectedTheme: _themeTouched
            ? _progress.selectedTheme
            : loaded.selectedTheme,
      );
    });
    if (_progressChangedBeforeLoad) unawaited(_saveProgress());
  }

  void _setProgress(CampProgress next, {int xpGained = 0}) {
    _progress = next;
    if (!_progressLoaded) {
      _progressChangedBeforeLoad = true;
      _xpBeforeLoad += xpGained;
    }
    // Saving before the stored value has loaded could overwrite it; the
    // merge in _loadProgress saves the combined progress instead.
    if (_progressLoaded) unawaited(_saveProgress());
  }

  Future<void> _saveProgress() async {
    try {
      await widget.progressStore.save(_progress);
    } catch (_) {}
  }

  void _toggleSound() {
    final muted = !_soundMuted;
    setState(() {
      _soundTouched = true;
      _soundMuted = muted;
    });
    _feedback.refreshMute();
    _focusNode.requestFocus();
    unawaited(_saveSoundMuted(muted));
  }

  Future<void> _saveSoundMuted(bool muted) async {
    try {
      await widget.soundMuteStore.saveMuted(muted);
    } catch (_) {}
  }

  /// Any pointer or key input: browsers only allow music after one, and the
  /// platform mute may have changed meanwhile.
  void _onAnyInput() {
    _feedback.onUserInput();
    _feedback.refreshMute();
  }

  bool _onHardwareKey(KeyEvent event) {
    if (event is KeyDownEvent) _onAnyInput();
    return false;
  }

  Future<void> _checkTutorial() async {
    var seen = false;
    try {
      seen = await widget.howToPlayStore.loadSeen();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _tutorialLoading = false;
      _showHowTo = !seen;
    });
    _syncGameplay();
  }

  void _openHowToPlay() {
    setState(() => _showHowTo = true);
    _syncGameplay();
  }

  void _closeHowToPlay() {
    setState(() => _showHowTo = false);
    _syncGameplay();
    _refocus();
    unawaited(_markTutorialSeen());
  }

  Future<void> _markTutorialSeen() async {
    try {
      await widget.howToPlayStore.markSeen();
    } catch (_) {}
  }

  void _openAlbum() {
    if (_albumOpen) return;
    setState(() {
      _albumOpen = true;
      _trailAxeMode = false;
    });
    _syncGameplay();
  }

  void _closeAlbum() {
    if (!_albumOpen) return;
    setState(() => _albumOpen = false);
    _syncGameplay();
    _refocus();
  }

  void _selectTheme(CampTheme theme) {
    final next = _progress.withTheme(theme);
    if (identical(next, _progress) || next.selectedTheme == _theme) return;
    _themeTouched = true;
    setState(() => _setProgress(next));
  }

  /// Focus goes back to the board, or to "Play again" while the run summary
  /// is up.
  void _refocus() {
    if (_controller.isGameOver && _playAgainFocus.context != null) {
      _playAgainFocus.requestFocus();
    } else {
      _focusNode.requestFocus();
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onHardwareKey);
    widget.platform.setAudioMuteListener(null);
    _lifecycle.dispose();
    _focusNode.dispose();
    _playAgainFocus.dispose();
    _feedback.stopMusic();
    unawaited(_feedback.dispose());
    _fx.dispose();
    _controller.removeListener(_onChanged);
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _onChanged() {
    // Mission rewards notify again from inside this handler; the outer call
    // already handles the new state.
    if (_handlingChange) return;
    _handlingChange = true;
    try {
      final placed =
          _controller.placements != _seenPlacements &&
          _controller.lastPlacedIndex != null;
      _seenPlacements = _controller.placements;
      if (placed) _afterPlacement();

      final danger = _controller.occupiedCount >= dangerOccupied;
      if (danger && !_wasDanger && placed && _effectsOn) _shakeSerial += 1;
      _wasDanger = danger;

      final runEnded = _controller.isGameOver && !_wasGameOver;
      _wasGameOver = _controller.isGameOver;
      if (runEnded) {
        _trailAxeMode = false;
        _report = RunReport(
          score: _controller.score,
          highestTier: _controller.highestTier,
          bestChain: _controller.bestMergeChain,
          missionsCompleted: _missions.completedThisRun,
          outcome: _applyRun(),
        );
        _syncGameplay();
        if (widget.platform.allowsResultRegistration) {
          _offerResultRegistration();
        }
        if (widget.enableAds) {
          _handleRunEndedAds();
        }
      }
    } finally {
      _handlingChange = false;
    }
    if (mounted) {
      setState(() {});
    }
  }

  /// Effects, missions and discoveries of the placement that just happened.
  /// The rules have already been applied; everything here trails behind.
  void _afterPlacement() {
    final index = _controller.lastPlacedIndex!;
    final steps = _controller.lastMergeSteps;
    final placedTier = steps.isEmpty
        ? (_controller.board[index] ?? 1)
        : steps.first.fromTier;

    if (_effectsOn) _fx.addPlacement(index, placedTier, steps);
    if (steps.length >= 2) {
      _chainLength = steps.length;
      _chainSerial += 1;
    }

    for (final mission in _missions.update(_controller)) {
      final axe = _controller.grantTrailAxe();
      if (!axe) _controller.addBonusScore(_missionBonusScore);
      unawaited(_feedback.mission());
      _toast(
        'Mission complete: ${mission.label} '
        '(${axe ? '+1 Trail Axe' : '+$_missionBonusScore'})',
        Icons.emoji_events_rounded,
      );
    }

    var next = _progress;
    var newest = 0;
    final created = <int>{
      placedTier.clamp(1, CampTileArt.maxArtTier),
      for (final step in steps) step.toTier.clamp(1, CampTileArt.maxArtTier),
    }.toList()..sort();
    for (final tier in created) {
      if (!next.discoveredTiers.contains(tier)) {
        next = next.withDiscovered(tier);
        newest = tier;
      }
    }
    if (newest > 0) {
      _setProgress(next);
      unawaited(_feedback.discover());
      _discoveryTier = newest;
      _discoverySerial += 1;
    }
  }

  void _toast(String text, IconData icon) {
    _toastSerial += 1;
    _toasts.add(ToastMessage(id: _toastSerial, text: text, icon: icon));
    // Only the latest few stay on screen.
    while (_toasts.length > 2) {
      _toasts.removeAt(0);
    }
  }

  /// Applies the current run to the saved progress once. Returns null when
  /// nothing was applied (already done, or no placements).
  RunOutcome? _applyRun() {
    if (_runApplied) return null;
    _runApplied = true;
    if (_controller.placements <= 0) return null;
    final outcome = _progress.applyRun(
      RunSummary(
        score: _controller.score,
        highestTier: _controller.highestTier,
        bestChain: _controller.bestMergeChain,
        placements: _controller.placements,
        missionXp: _missions.xpEarned,
      ),
    );
    _setProgress(outcome.progress, xpGained: outcome.xpGained);
    if (outcome.levelAfter > outcome.levelBefore) {
      unawaited(_feedback.levelUp());
    }
    return outcome;
  }

  void _offerResultRegistration() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        offerResultRegistration(
          context,
          gameId: 'merge-camp',
          metric: 'score',
          value: _controller.score,
          displayValue: '${_controller.score}점',
        );
      }
    });
  }

  void _handleRunEndedAds() {
    _completedRuns += 1;
    if (_completedRuns % 3 == 0) {
      // The music must not play over a full-screen ad.
      _feedback.stopMusic();
      final shown = AdService.instance.showInterstitialIfReady(
        onClosed: _resumeMusicAfterAd,
      );
      if (!shown) _resumeMusicAfterAd();
    } else {
      unawaited(AdService.instance.loadInterstitial());
    }
  }

  void _resumeMusicAfterAd() {
    if (!mounted) return;
    _feedback.startMusic();
    _feedback.refreshMute();
  }

  Future<void> _restartRun() async {
    if (_breakAdInProgress) {
      return;
    }
    final afterGameOver = _controller.isGameOver;
    if (afterGameOver) {
      setState(() {
        _breakAdInProgress = true;
      });
      // Hold the music for the whole ad; it resumes (if not muted) after.
      _feedback.stopMusic();
      try {
        await widget.platform.showRunBreakAd();
      } catch (error) {
        debugPrint('Run break ad failed: $error');
      } finally {
        _resumeMusicAfterAd();
      }
      if (!mounted) {
        return;
      }
      _breakAdInProgress = false;
    } else {
      // Restarting mid-run still counts the run (no-op without placements).
      final outcome = _applyRun();
      if (outcome != null && outcome.levelAfter > outcome.levelBefore) {
        _toast(
          'Camp level up! Lv ${outcome.levelAfter}',
          Icons.arrow_upward_rounded,
        );
      }
    }
    _trailAxeMode = false;
    _report = null;
    _runApplied = false;
    _missions.reset();
    _fx.clear();
    _chainLength = 0;
    _controller.restart();
    _syncGameplay();
    _focusNode.requestFocus();
  }

  /// Reports gameplay start/stop to the platform exactly on transitions:
  /// running only while no tutorial or album is open and the run is not
  /// over (the run summary is up while it is).
  void _syncGameplay() {
    final wantActive =
        !_tutorialBlocking && !_controller.isGameOver && !_albumOpen;
    if (wantActive == _gameplayActive) return;
    _gameplayActive = wantActive;
    if (wantActive) {
      widget.platform.gameplayStart();
    } else {
      widget.platform.gameplayStop();
    }
  }

  static const int _boardColumns = MergeCampController.boardWidth;

  bool _isKey(LogicalKeyboardKey key, List<LogicalKeyboardKey> keys) =>
      keys.contains(key);

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    // Leave Tab traversal and browser/OS shortcuts (Cmd/Ctrl+R, F5 etc.)
    // alone, also while the how-to-play card is open.
    if (key == LogicalKeyboardKey.tab ||
        key == LogicalKeyboardKey.f5 ||
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isAltPressed) {
      return KeyEventResult.ignored;
    }
    // The how-to-play card owns the keyboard while it is open.
    if (_tutorialBlocking) return KeyEventResult.handled;
    // Held keys only repeat cursor moves: a key held on the card's "Play"
    // button must not place a tile, swing the axe or restart once it closes.
    final isRepeat = event is KeyRepeatEvent;
    const activate = [
      LogicalKeyboardKey.enter,
      LogicalKeyboardKey.numpadEnter,
      LogicalKeyboardKey.space,
    ];
    // Album and run summary: the board gets no input. Their buttons keep
    // Enter/Space (focus activation) and arrows (focus moves).
    if (_albumOpen) {
      if (key == LogicalKeyboardKey.escape) {
        if (!isRepeat) _closeAlbum();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (_controller.isGameOver) {
      if (key == LogicalKeyboardKey.keyR ||
          (_isKey(key, activate) &&
              FocusManager.instance.primaryFocus == _focusNode)) {
        if (!isRepeat) unawaited(_restartRun());
        return KeyEventResult.handled;
      }
      if (_isKey(key, activate) && isRepeat) return KeyEventResult.handled;
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.keyR) {
      if (isRepeat) return KeyEventResult.handled;
      unawaited(_restartRun());
      return KeyEventResult.handled;
    }
    final size = _controller.board.length;
    final current = _cursor ?? 0;
    int? next;
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyA) {
      next = current % _boardColumns == 0 ? current : current - 1;
    } else if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.keyD) {
      next = current % _boardColumns == _boardColumns - 1
          ? current
          : current + 1;
    } else if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.keyW) {
      next = current - _boardColumns < 0 ? current : current - _boardColumns;
    } else if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.keyS) {
      next = current + _boardColumns >= size
          ? current
          : current + _boardColumns;
    }
    if (next != null) {
      // The first key press only reveals the cursor without moving it.
      setState(() => _cursor = _cursor == null ? 0 : next);
      return KeyEventResult.handled;
    }
    if (_isKey(key, activate)) {
      if (isRepeat) return KeyEventResult.handled;
      if (_cursor == null) {
        setState(() => _cursor = 0);
      } else {
        unawaited(_handleCellTap(_cursor!));
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyX || key == LogicalKeyboardKey.keyE) {
      if (isRepeat) return KeyEventResult.handled;
      if (_cursor == null) {
        setState(() => _cursor = 0);
      } else {
        unawaited(_handleCellTap(_cursor!, forceAxe: true));
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape && _trailAxeMode) {
      setState(() => _trailAxeMode = false);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _handleCellTap(
    int index, {
    bool forceAxe = false,
    bool fromPointer = false,
  }) async {
    if (_breakAdInProgress || _handlingTap || _tutorialBlocking || _albumOpen) {
      return;
    }
    if (fromPointer && _cursor != null) {
      setState(() => _cursor = null);
    }
    _handlingTap = true;
    try {
      final useAxe = forceAxe || _trailAxeMode;
      if (forceAxe && !_controller.canUseTrailAxe) {
        await _feedback.warning();
        return;
      }
      final tierBefore = _controller.board[index];
      final result = useAxe
          ? _controller.useTrailAxe(index)
          : _controller.place(index);
      if (result.action == MergeAction.removed && mounted) {
        if (_effectsOn && tierBefore != null) {
          _fx.addRemoval(index, tierBefore);
        }
        setState(() {
          _trailAxeMode = false;
        });
      }
      switch (result.action) {
        case MergeAction.placed:
          await _feedback.tap();
        case MergeAction.merged:
          final chain = _controller.lastMergeChain;
          await (chain >= 2 ? _feedback.chain(chain) : _feedback.merge());
        case MergeAction.removed:
          await _feedback.tap();
        case MergeAction.blocked:
        case MergeAction.noTool:
        case MergeAction.gameOver:
          await _feedback.warning();
      }
    } finally {
      _handlingTap = false;
    }
  }

  void _toggleTrailAxe() {
    setState(() => _trailAxeMode = !_trailAxeMode);
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final palette = CampPalette.of(_theme);
    final loopingArt = widget.animateArt && !_reduceMotion;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: palette.skyBottom,
      body: Listener(
        onPointerDown: (_) => _onAnyInput(),
        child: Focus(
          focusNode: _focusNode,
          autofocus: true,
          onKeyEvent: _onKeyEvent,
          child: DefaultTextStyle.merge(
            style: TextStyle(color: palette.textPrimary),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CampScenery(theme: _theme, animate: loopingArt),
                ),
                // Keep Tab traversal inside the open card or overlay.
                ExcludeFocus(
                  excluding: _tutorialBlocking || _overlayOpen,
                  child: SafeArea(
                    child: Column(
                      children: [
                        Expanded(
                          child: CampHudLayout(
                            controller: _controller,
                            theme: _theme,
                            fx: _fx,
                            progress: _progress,
                            missions: _missions,
                            cursor: _cursor,
                            trailAxeMode: _trailAxeMode,
                            soundMuted: _soundMuted,
                            loopingArt: loopingArt,
                            shakeSerial: _shakeSerial,
                            chainLength: _chainLength,
                            chainSerial: _chainSerial,
                            discoveryTier: _discoveryTier,
                            discoverySerial: _discoverySerial,
                            toasts: _toasts,
                            onCellTap: (index) =>
                                _handleCellTap(index, fromPointer: true),
                            onOpenAlbum: _openAlbum,
                            onOpenHelp: _openHowToPlay,
                            onToggleSound: _toggleSound,
                            onRestart: () => unawaited(_restartRun()),
                            onToggleTrailAxe: _toggleTrailAxe,
                            onChainDone: () {
                              if (mounted) setState(() => _chainLength = 0);
                            },
                            onDiscoveryDone: () {
                              if (mounted) setState(() => _discoveryTier = 0);
                            },
                            onToastDone: (toast) {
                              if (!mounted) return;
                              setState(() => _toasts.remove(toast));
                            },
                          ),
                        ),
                        AdBanner(enabled: widget.enableAds),
                      ],
                    ),
                  ),
                ),
                // Taps must not reach the board before the seen-flag read
                // decides whether the how-to-play card opens.
                if (_tutorialLoading)
                  const Positioned.fill(child: AbsorbPointer()),
                if (_controller.isGameOver)
                  Positioned.fill(
                    child: ExcludeFocus(
                      excluding: _albumOpen || _tutorialBlocking,
                      child: RunSummaryOverlay(
                        report:
                            _report ??
                            RunReport(
                              score: _controller.score,
                              highestTier: _controller.highestTier,
                              bestChain: _controller.bestMergeChain,
                              missionsCompleted: _missions.completedThisRun,
                            ),
                        theme: _theme,
                        busy: _breakAdInProgress,
                        animateArt: loopingArt,
                        playAgainFocus: _playAgainFocus,
                        onPlayAgain: () => unawaited(_restartRun()),
                        onAlbum: _openAlbum,
                      ),
                    ),
                  ),
                if (_albumOpen)
                  Positioned.fill(
                    child: ExcludeFocus(
                      excluding: _tutorialBlocking,
                      child: AlbumOverlay(
                        progress: _progress,
                        animateArt: loopingArt,
                        onSelectTheme: _selectTheme,
                        onClose: _closeAlbum,
                      ),
                    ),
                  ),
                if (_showHowTo)
                  Positioned.fill(
                    child: HowToPlayOverlay(
                      steps: _howToPlaySteps,
                      theme: _theme,
                      onClose: _closeHowToPlay,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The three how-to-play steps (English ASCII; see the tutorial spec).
const List<HowToPlayStep> _howToPlaySteps = [
  HowToPlayStep(
    icon: Icons.grid_view_rounded,
    tiers: [1, 1, 1, 2],
    text:
        'Match 3 or more touching camp tiles to merge them into a bigger '
        'camp. Merges can chain! Keep the 4x4 board from jamming.',
  ),
  HowToPlayStep(
    icon: Icons.touch_app_rounded,
    tiers: [3, 4],
    text:
        'Tap an empty plot to place the next piece. Keyboard: arrows/WASD '
        'move, Enter/Space place.',
  ),
  HowToPlayStep(
    icon: Icons.emoji_events_rounded,
    text:
        'Missions give a Trail Axe (X clears one tile) and camp XP. '
        'Level up to unlock new camp themes.',
  ),
];
