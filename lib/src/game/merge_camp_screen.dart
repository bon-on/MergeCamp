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
import 'ui/decor_overlay.dart';
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
  bool _decorOpen = false;
  bool _firstRun = false;
  // The first run still owes the fixed starter missions; survives closing
  // the card before stored progress arrives.
  bool _starterPending = false;
  bool _starterPrepared = false;
  bool _guidedPractice = false;
  // Play was chosen on the first-run card before stored progress arrived.
  bool _practiceRequested = false;
  bool _restoringRun = false;
  Future<void> _saveQueue = Future<void>.value();

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

  /// Empty plot next to the two practice tents (see startGuidedRun).
  static const int _guidedPlot = 2;

  bool get _tutorialBlocking =>
      _tutorialLoading || _showHowTo || !_progressLoaded;
  bool get _overlayOpen => _albumOpen || _decorOpen || _controller.isGameOver;
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
        activeRun: loaded.activeRun,
        stickerSlots: loaded.stickerSlots,
        stickersSeen: loaded.stickersSeen,
      );
    });
    _announceStickers();
    if (!_progressChangedBeforeLoad) _restoreRun();
    _prepareStarterMissions();
    _startRequestedPractice();
    if (_progressChangedBeforeLoad) unawaited(_saveProgress());
    _syncGameplay();
  }

  /// Players returning from before stickers existed get one quiet notice
  /// for the stickers their level already owns (they wait in the tray).
  /// Brand-new players only have the marker set, saved with the next write.
  void _announceStickers() {
    final unseen = _progress.unseenStickerCount;
    final seen = _progress.withStickersSeen();
    if (identical(seen, _progress)) return;
    if (unseen == 0) {
      _progress = seen;
      return;
    }
    setState(() {
      _toast(
        unseen == 1
            ? '1 sticker ready to place'
            : '$unseen stickers ready to place',
        Icons.auto_awesome_rounded,
      );
      _setProgress(seen);
    });
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

  Future<void> _saveProgress() {
    final snapshot = _progress;
    _saveQueue = _saveQueue.then((_) async {
      try {
        await widget.progressStore.save(snapshot);
      } catch (_) {}
    });
    return _saveQueue;
  }

  void _checkpointRun() {
    if (!_progressLoaded || _restoringRun || _controller.isGameOver) return;
    _setProgress(
      _progress.withActiveRun({
        'version': 1,
        'controller': _controller.toSnapshot(),
        'missions': _missions.toSnapshot(),
        'guidedPractice': _guidedPractice,
      }),
    );
  }

  void _restoreRun() {
    final run = _progress.activeRun;
    if (run == null) return;
    final controller = MergeCampController();
    final missions = MissionBoard();
    try {
      if (run['version'] != 1 ||
          !controller.restoreSnapshot(run['controller']) ||
          controller.isGameOver ||
          !missions.restoreSnapshot(run['missions']) ||
          run['guidedPractice'] is! bool) {
        _setProgress(_progress.withActiveRun(null));
        return;
      }
      final guided = run['guidedPractice'] == true;
      if (guided &&
          (controller.placements != 0 ||
              controller.board[0] != 1 ||
              controller.board[1] != 1 ||
              controller.board[_guidedPlot] != null ||
              controller.nextTier != 1)) {
        _setProgress(_progress.withActiveRun(null));
        return;
      }
      _restoringRun = true;
      _controller.restoreSnapshot(run['controller']);
      _missions.restoreSnapshot(run['missions']);
      _seenPlacements = _controller.placements;
      _wasGameOver = false;
      _wasDanger = _controller.occupiedCount >= dangerOccupied;
      _guidedPractice = guided;
      _cursor = guided ? _guidedPlot : null;
      _starterPrepared = true;
      _firstRun = false;
      _starterPending = false;
      _practiceRequested = false;
    } finally {
      _restoringRun = false;
      controller.dispose();
    }
  }

  /// Starts the guided first merge once Play was chosen on the first-run
  /// card and the stored progress has loaded (a restored run wins).
  void _startRequestedPractice() {
    if (!_practiceRequested || !_progressLoaded) return;
    _practiceRequested = false;
    if (_controller.placements != 0 || _controller.isGameOver) return;
    _guidedPractice = true;
    _trailAxeMode = false;
    _cursor = _guidedPlot;
    // Notifies _onChanged, which saves the practice board and rebuilds.
    _controller.startGuidedRun();
  }

  void _prepareStarterMissions() {
    if (!_progressLoaded ||
        _tutorialLoading ||
        !_starterPending ||
        _starterPrepared ||
        _controller.placements > 0) {
      return;
    }
    _missions.startStarterSet();
    _starterPrepared = true;
    _starterPending = false;
    // Saved at once so a reload before the first move keeps the set.
    _checkpointRun();
  }

  void _skipPractice() {
    if (!_guidedPractice) return;
    _guidedPractice = false;
    _cursor = null;
    // Notifies _onChanged, which saves the empty board and rebuilds.
    _controller.restart();
    _focusNode.requestFocus();
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
      _firstRun = !seen && !_starterPrepared;
      _starterPending = _firstRun;
    });
    _prepareStarterMissions();
    _syncGameplay();
  }

  void _openHowToPlay() {
    setState(() => _showHowTo = true);
    _syncGameplay();
  }

  void _closeHowToPlay({bool practice = false}) {
    setState(() {
      _showHowTo = false;
      _practiceRequested = practice && _firstRun;
      _firstRun = false;
    });
    _startRequestedPractice();
    _checkpointRun();
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

  void _openDecor() {
    if (_decorOpen) return;
    setState(() {
      _decorOpen = true;
      _trailAxeMode = false;
    });
    _syncGameplay();
  }

  void _closeDecor() {
    if (!_decorOpen) return;
    setState(() => _decorOpen = false);
    _syncGameplay();
    _refocus();
  }

  void _placeSticker(String id, int slot) {
    final next = _progress.withSticker(id, slot);
    if (identical(next, _progress)) return;
    setState(() => _setProgress(next));
  }

  void _removeSticker(int slot) {
    final next = _progress.withoutSticker(slot);
    if (identical(next, _progress)) return;
    setState(() => _setProgress(next));
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
      // After the album or decor screen the summary only becomes focusable
      // again once it is rebuilt without its ExcludeFocus.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.isGameOver) _playAgainFocus.requestFocus();
      });
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
    if (_handlingChange || _restoringRun) return;
    _handlingChange = true;
    try {
      final placed =
          _controller.placements != _seenPlacements &&
          _controller.lastPlacedIndex != null;
      _seenPlacements = _controller.placements;
      if (placed) {
        _guidedPractice = false;
        _afterPlacement();
      }

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
      if (!_controller.isGameOver) _checkpointRun();
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
      if (!axe) {
        if (_controller.isGameOver) {
          _controller.addFinalMissionBonus(_missionBonusScore);
        } else {
          _controller.addBonusScore(_missionBonusScore);
        }
      }
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
        mergeCount: _controller.mergeCount,
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
    if (_breakAdInProgress || _tutorialBlocking) {
      return;
    }
    // Restarting the untouched practice board just skips the practice and
    // keeps the starter missions.
    if (_guidedPractice && _controller.placements == 0) {
      _skipPractice();
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
        final stickers = outcome.newStickers;
        if (stickers.isNotEmpty) {
          _toast(
            '${stickers.length == 1 ? 'New sticker' : 'New stickers'}: '
            '${stickers.map((award) => award.sticker.name).join(', ')}',
            Icons.auto_awesome_rounded,
          );
        }
      }
    }
    _trailAxeMode = false;
    _guidedPractice = false;
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
  /// running only while no tutorial, album or decor screen is open and the
  /// run is not over (the run summary is up while it is).
  void _syncGameplay() {
    final wantActive =
        !_tutorialBlocking &&
        !_controller.isGameOver &&
        !_albumOpen &&
        !_decorOpen;
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
    // Album, decor screen and run summary: the board gets no input. Their
    // buttons keep Enter/Space (focus activation) and arrows (focus moves).
    if (_albumOpen || _decorOpen) {
      if (key == LogicalKeyboardKey.escape) {
        if (!isRepeat) _albumOpen ? _closeAlbum() : _closeDecor();
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
    if (key == LogicalKeyboardKey.escape && _guidedPractice) {
      if (!isRepeat) _skipPractice();
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
    if (_breakAdInProgress ||
        _handlingTap ||
        _tutorialBlocking ||
        _albumOpen ||
        _decorOpen) {
      return;
    }
    if (fromPointer && _cursor != null) {
      setState(() => _cursor = null);
    }
    // Practice accepts only the highlighted plot, and no axe.
    if (_guidedPractice &&
        (index != _guidedPlot || forceAxe || _trailAxeMode)) {
      return;
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
    if (_guidedPractice) return;
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
                            guidedIndex: _guidedPractice ? _guidedPlot : null,
                            onSkipPractice: _skipPractice,
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
                            onOpenDecor: _openDecor,
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
                if (_tutorialLoading || !_progressLoaded)
                  const Positioned.fill(child: AbsorbPointer()),
                if (_controller.isGameOver)
                  Positioned.fill(
                    child: ExcludeFocus(
                      excluding: _albumOpen || _decorOpen || _tutorialBlocking,
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
                        onDecorate: _openDecor,
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
                if (_decorOpen)
                  Positioned.fill(
                    child: ExcludeFocus(
                      excluding: _tutorialBlocking,
                      child: DecorOverlay(
                        progress: _progress,
                        animateArt: loopingArt,
                        onPlace: _placeSticker,
                        onRemove: _removeSticker,
                        onClose: _closeDecor,
                      ),
                    ),
                  ),
                if (_showHowTo)
                  Positioned.fill(
                    child: HowToPlayOverlay(
                      steps: _howToPlaySteps,
                      theme: _theme,
                      onClose: _closeHowToPlay,
                      onPlay: () => _closeHowToPlay(practice: true),
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
