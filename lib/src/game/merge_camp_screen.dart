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
import '../meta/daily_camp.dart';
import '../meta/camp_progress_store.dart';
import '../meta/camp_theme.dart';
import '../meta/missions.dart';
import '../meta/stickers.dart';
import '../platform/game_platform.dart';
import 'feedback_fx.dart';
import 'how_to_play.dart';
import 'tool_hints.dart';
import 'merge_camp_controller.dart';
import 'share/result_share.dart';
import 'ui/album_overlay.dart';
import 'ui/banners.dart';
import 'ui/board_fx.dart';
import 'ui/camp_layout.dart';
import 'ui/decor_overlay.dart';
import 'ui/run_summary_overlay.dart';
import 'ui/second_wind_overlay.dart';
import '../../result_registration.dart';

/// How a restart picks the next run.
enum _RunMode { same, daily, free }

class MergeCampScreen extends StatefulWidget {
  const MergeCampScreen({
    super.key,
    this.enableAds = false,
    this.platform = const NoopGamePlatform(),
    this.controller,
    this.howToPlayStore = const HowToPlayStore(),
    this.toolHintStore = const ToolHintStore(),
    this.soundMuteStore = const SoundMuteStore(),
    this.progressStore = const CampProgressStore(),
    this.missions,
    this.animateArt = true,
    this.resultShare = const ResultShare(),
    this.clock = DateTime.now,
  });

  final bool enableAds;
  final GamePlatform platform;

  /// Injected for tests; when null the screen owns its controller.
  final MergeCampController? controller;

  /// First-run tutorial flag storage; tests inject a fake.
  final HowToPlayStore howToPlayStore;

  /// One-time tool hint flags; tests inject a fake.
  final ToolHintStore toolHintStore;

  /// Persisted user mute choice; tests inject a fake.
  final SoundMuteStore soundMuteStore;

  /// Best score, album, camp XP and theme; tests inject a memory store.
  final CampProgressStore progressStore;

  /// Injected for tests (seeded missions); when null the screen owns one.
  final MissionBoard? missions;

  /// Local time source; tests inject a fixed date for the Daily Camp.
  final DateTime Function() clock;

  /// Looping art motion (tile loops, scenery, danger pulse). Tests turn it
  /// off so pumpAndSettle can settle; one-shot effects still play.
  final bool animateArt;

  /// Clipboard, download and Web Share of a finished run; tests inject a
  /// fake. Shown only when [GamePlatform.shareLink] is set.
  final ResultShare resultShare;

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
  bool _shiftModeOn = false;
  // Camp picked to step; its neighbor cells glow while it is set.
  int? _shiftFrom;
  bool get _shiftMode => _shiftModeOn;
  set _shiftMode(bool on) {
    _shiftModeOn = on;
    if (!on) _shiftFrom = null;
  }

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

  // Second Wind (feature-second-wind): a locked board waits for the player's
  // choice before the run is settled.
  bool _secondWindOffer = false;
  // CrazyGames allows a revive offer once per session, not on every lock.
  bool _secondWindShown = false;
  final FocusNode _secondWindFocus = FocusNode(debugLabel: 'SecondWind');
  int _completedRuns = 0;
  // The tutorial blocks all game input while the first-run check is pending
  // (_tutorialLoading) and while the card is open (_showHowTo).
  bool _tutorialLoading = true;
  bool _showHowTo = false;
  bool _albumOpen = false;
  bool _decorOpen = false;
  // The first run still owes the fixed starter missions until stored
  // progress arrives.
  bool _starterPending = false;
  bool _starterPrepared = false;
  bool _guidedPractice = false;
  // Next-step hint after the practice merge; ends after a few placements.
  bool _coachActive = false;

  // One-time Shift / Trail Axe hints (feature-tool-hints). Until the saved
  // flags are read every hint counts as seen.
  Set<ToolHint> _hintsSeen = {...ToolHint.values};
  ToolHint? _toolHint;
  int _toolHintPlacement = 0;
  // A first run waits for stored progress before its guided practice.
  bool _practiceRequested = false;
  bool _restoringRun = false;
  Future<void> _saveQueue = Future<void>.value();

  // Whether the platform currently believes gameplay is running.
  bool _gameplayActive = false;
  // False while the app or browser tab is hidden; gameplay is not running then.
  bool _appActive =
      WidgetsBinding.instance.lifecycleState == null ||
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

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
  // First-run celebrations already shown in this run.
  final Set<_Milestone> _milestones = <_Milestone>{};

  static const int _missionBonusScore = 150;

  /// Empty plot next to the two practice tents (see startGuidedRun).
  static const int _guidedPlot = 2;

  /// The coach hint stays up until this many placements were made.
  static const int _coachUntilPlacements = 3;

  bool get _tutorialBlocking =>
      _tutorialLoading || _showHowTo || !_progressLoaded;
  bool get _overlayOpen => _albumOpen || _decorOpen || _controller.isGameOver;
  CampTheme get _theme => _progress.selectedTheme;
  bool get _effectsOn => !_reduceMotion;

  @override
  void initState() {
    super.initState();
    unawaited(_checkTutorial());
    unawaited(_loadToolHints());
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
    _lifecycle = AppLifecycleListener(onStateChange: _onAppLifecycleChanged);
    HardwareKeyboard.instance.addHandler(_onHardwareKey);
    // Portal mute settings and ads can change the platform mute at any time.
    widget.platform.setAudioMuteListener(_feedback.refreshMute);
  }

  Future<void> _loadToolHints() async {
    final seen = await widget.toolHintStore.loadSeen();
    if (mounted) _hintsSeen = seen;
  }

  /// Shows, keeps or drops the one-time tool hint after a change.
  void _updateToolHint() {
    final current = _toolHint;
    if (current != null &&
        (_controller.isGameOver ||
            _controller.placements == 0 ||
            _controller.placements - _toolHintPlacement >= 4)) {
      _toolHint = null;
    }
    if (_toolHint != null ||
        _guidedPractice ||
        _coachActive ||
        _controller.isGameOver ||
        _controller.placements == 0) {
      return;
    }
    ToolHint? next;
    if (_controller.shifts > 0 && !_hintsSeen.contains(ToolHint.shift)) {
      next = ToolHint.shift;
    } else if (_controller.trailAxes > 0 &&
        _controller.occupiedCount >= dangerOccupied &&
        !_hintsSeen.contains(ToolHint.axe)) {
      next = ToolHint.axe;
    }
    if (next == null) return;
    _toolHint = next;
    _toolHintPlacement = _controller.placements;
    _hintsSeen = {..._hintsSeen, next};
    unawaited(widget.toolHintStore.markSeen(next));
  }

  void _onAppLifecycleChanged(AppLifecycleState state) {
    _feedback.setAppVisible(
      state == AppLifecycleState.resumed || state == AppLifecycleState.inactive,
    );
    final active = state == AppLifecycleState.resumed;
    if (_appActive == active) return;
    _appActive = active;
    _syncGameplay();
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
        welcomeRun: loaded.welcomeRun,
        daily: loaded.daily,
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
  /// Brand-new players get the Pennant stuck on the board instead.
  void _announceStickers() {
    final unseen = _progress.unseenStickerCount;
    final seen = _progress.withStickersSeen();
    if (identical(seen, _progress)) return;
    setState(() {
      if (unseen > 0) {
        _toast(
          unseen == 1
              ? '1 sticker ready to place'
              : '$unseen stickers ready to place',
          Icons.auto_awesome_rounded,
        );
      }
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
    final pending = _controller.isGameOver && _secondWindOffer;
    if (!_progressLoaded ||
        _restoringRun ||
        (_controller.isGameOver && !pending)) {
      return;
    }
    _setProgress(
      _progress.withActiveRun({
        'version': 1,
        'controller': _controller.toSnapshot(),
        'missions': _missions.toSnapshot(),
        'guidedPractice': _guidedPractice,
        if (pending) 'secondWindPending': true,
      }),
    );
  }

  void _restoreRun() {
    final run = _progress.activeRun;
    if (run == null) return;
    final controller = MergeCampController();
    final missions = MissionBoard();
    try {
      final pending = run['secondWindPending'] == true;
      if (run['version'] != 1 ||
          !controller.restoreSnapshot(run['controller']) ||
          (run.containsKey('secondWindPending') && !pending) ||
          controller.isGameOver != pending ||
          (pending && !controller.canRevive) ||
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
      _wasGameOver = _controller.isGameOver;
      _wasDanger = _controller.occupiedCount >= dangerOccupied;
      _guidedPractice = guided;
      _cursor = guided ? _guidedPlot : null;
      _starterPrepared = true;
      _starterPending = false;
      _practiceRequested = false;
      // Celebrations the restored run already passed are not repeated.
      _milestones.clear();
      if (_controller.mergeCount > 0) _milestones.add(_Milestone.firstMerge);
      if (_controller.bestMergeChain >= 2) _milestones.add(_Milestone.chain);
      if (pending) _offerSecondWindOrSettle();
    } finally {
      _restoringRun = false;
      controller.dispose();
    }
  }

  /// Starts the guided first merge of a first run once the stored progress
  /// has loaded (a restored run wins; feature-instant-first-run).
  void _startRequestedPractice() {
    if (!_practiceRequested || !_progressLoaded) return;
    _practiceRequested = false;
    if (_controller.placements != 0 || _controller.isGameOver) return;
    _guidedPractice = true;
    _trailAxeMode = false;
    _shiftMode = false;
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
    // First run: no card, straight into the guided merge
    // (feature-instant-first-run). The card stays one tap away on `?`.
    final firstRun = !seen && !_starterPrepared;
    setState(() {
      _tutorialLoading = false;
      _starterPending = firstRun;
      _practiceRequested = firstRun;
    });
    _prepareStarterMissions();
    _startRequestedPractice();
    if (!seen) unawaited(_markTutorialSeen());
    _syncGameplay();
  }

  void _openHowToPlay() {
    setState(() => _showHowTo = true);
    _syncGameplay();
  }

  void _closeHowToPlay() {
    setState(() => _showHowTo = false);
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
      _shiftMode = false;
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
      _shiftMode = false;
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
    _secondWindFocus.dispose();
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
      // Any restart (button, key, Daily) puts the board back at zero.
      if (_controller.placements == 0) _coachActive = false;
      if (placed) {
        if (_guidedPractice) _coachActive = true;
        _guidedPractice = false;
        if (_controller.placements > _coachUntilPlacements) {
          _coachActive = false;
        }
        _afterPlacement();
      }
      _updateToolHint();

      final danger = _controller.occupiedCount >= dangerOccupied;
      if (danger && !_wasDanger && placed && _effectsOn) _shakeSerial += 1;
      _wasDanger = danger;

      final runEnded = _controller.isGameOver && !_wasGameOver;
      _wasGameOver = _controller.isGameOver;
      if (runEnded) {
        _trailAxeMode = false;
        _shiftMode = false;
        _offerSecondWindOrSettle();
      }
      _checkpointRun();
    } finally {
      _handlingChange = false;
    }
    if (mounted) {
      setState(() {});
    }
  }

  void _offerSecondWindOrSettle() {
    if (!widget.platform.supportsRewardedAds ||
        _secondWindShown ||
        !_controller.canRevive ||
        _guidedPractice) {
      _settleRunEnd();
      return;
    }
    _secondWindOffer = true;
    _secondWindShown = true;
    _syncGameplay();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _secondWindOffer) _secondWindFocus.requestFocus();
    });
  }

  /// Settles a finished run: report, progress, result registration and the
  /// ads that follow the run.
  void _settleRunEnd() {
    _report = RunReport(
      score: _controller.score,
      highestTier: _controller.highestTier,
      bestChain: _controller.bestMergeChain,
      missionsCompleted: _missions.completedThisRun,
      outcome: _applyRun(),
      dailyDay: _controller.dailyDay,
    );
    _syncGameplay();
    if (widget.platform.allowsResultRegistration) {
      _offerResultRegistration();
    }
    if (widget.enableAds) {
      _handleRunEndedAds();
    }
  }

  /// "Continue" on the Second Wind card: a finished rewarded ad clears the
  /// lowest camps and resumes the run; anything else keeps the card.
  Future<void> _continueSecondWind() async {
    if (!_secondWindOffer || _breakAdInProgress) return;
    setState(() => _breakAdInProgress = true);
    _feedback.stopMusic();
    var watched = false;
    try {
      watched = await widget.platform.showRewardedAd();
    } catch (error) {
      debugPrint('Rewarded ad failed: $error');
    } finally {
      _resumeMusicAfterAd();
    }
    if (!mounted) return;
    _breakAdInProgress = false;
    if (watched && _controller.revive()) {
      _secondWindOffer = false;
      _toast('Second Wind! Camps cleared.', Icons.air_rounded);
      _syncGameplay();
      _focusNode.requestFocus();
    } else {
      // No reward without a finished ad, and no dead button: settle the run.
      _secondWindOffer = false;
      _settleRunEnd();
      _toast('No video available right now.', Icons.info_outline_rounded);
    }
    setState(() {});
  }

  /// "End run" on the Second Wind card: settle the run as it stands.
  void _endSecondWind() {
    if (!_secondWindOffer || _breakAdInProgress) return;
    setState(() {
      _secondWindOffer = false;
      _settleRunEnd();
    });
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

    final missionsDone = _settleMissions();
    if (_controller.lastEarnedShift) {
      _toast('Shift earned! Move one camp a step.', Icons.open_with_rounded);
      if (missionsDone.isEmpty) unawaited(_feedback.mission());
    }
    _discoverTiers({
      placedTier.clamp(1, CampTileArt.maxArtTier),
      for (final step in steps) step.toTier.clamp(1, CampTileArt.maxArtTier),
    });
    _firstMinuteRewards(steps, quiet: missionsDone.isNotEmpty);
  }

  /// Mission rewards: a Shift for the "merge N at once" goal, otherwise a
  /// Trail Axe, and bonus points when the tool is already at its cap.
  List<Mission> _settleMissions() {
    final done = _missions.update(_controller);
    for (final mission in done) {
      final shift =
          mission.kind == MissionKind.bigMerge && _controller.grantShift();
      final axe = !shift && _controller.grantTrailAxe();
      if (!shift && !axe) {
        if (_controller.isGameOver) {
          _controller.addFinalMissionBonus(_missionBonusScore);
        } else {
          _controller.addBonusScore(_missionBonusScore);
        }
      }
      unawaited(_feedback.mission());
      _toast(
        'Mission complete: ${mission.label} '
        '(${shift
            ? '+1 Shift'
            : axe
            ? '+1 Trail Axe'
            : '+$_missionBonusScore'})',
        Icons.emoji_events_rounded,
      );
    }
    return done;
  }

  /// Marks camp tiers the player created for the first time in the album.
  void _discoverTiers(Set<int> tiers) {
    var next = _progress;
    var newest = 0;
    for (final tier in tiers.toList()..sort()) {
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

  /// Brand-new players only (feature-first-minute-rewards): the welcome
  /// bonus on the first merge, first-run celebrations and the welcome run's
  /// mid-run level-up. [quiet] skips the extra sound when a mission sound
  /// already plays for this placement.
  void _firstMinuteRewards(List<MergeStep> steps, {bool quiet = false}) {
    if (!_progressLoaded ||
        (!_progress.welcomeBonusDue && !_progress.welcomeRun)) {
      return;
    }
    if (steps.isNotEmpty && _milestones.add(_Milestone.firstMerge)) {
      if (_progress.welcomeBonusDue) {
        _setProgress(_progress.withWelcomeBonus());
        _toast(
          'First merge! Welcome bonus +${CampProgress.welcomeBonusXp} camp XP',
          Icons.celebration_rounded,
        );
        if (!quiet) unawaited(_feedback.mission());
        quiet = true;
      }
    }
    if (steps.any((step) => step.absorbed.length + 1 >= 4)) {
      quiet = _celebrate(_Milestone.bigMerge, quiet: quiet);
    }
    if (steps.length >= 2) {
      quiet = _celebrate(_Milestone.chain, quiet: quiet);
    }
    _liveLevelUp();
  }

  /// Shows a first-run celebration once per run; returns whether a sound
  /// is already playing for this action. A mission completed by the same
  /// action already celebrates it, so the milestone is only marked as seen
  /// (its toast would push the mission toast out).
  bool _celebrate(_Milestone milestone, {bool quiet = false}) {
    if (!_progressLoaded ||
        (!_progress.welcomeBonusDue && !_progress.welcomeRun) ||
        !_milestones.add(milestone) ||
        quiet) {
      return quiet;
    }
    _toast(milestone.text, Icons.celebration_rounded);
    unawaited(_feedback.mission());
    return true;
  }

  /// The welcome run reaches Lv 2 mid-run: its sticker is stuck on the
  /// board and saved at once; the run's XP is still credited at its end.
  void _liveLevelUp() {
    if (!_progress.welcomeRun) return;
    final awards = <StickerAward>[];
    final next = _progress.withLiveLevelUp(_runXpSoFar, awards: awards);
    if (identical(next, _progress)) return;
    _setProgress(next);
    unawaited(_feedback.levelUp());
    final sticker = awards.isEmpty ? null : awards.last.sticker;
    _toast(
      sticker == null
          ? 'Level up! Lv ${next.stickerLevel}'
          : 'Level up! Lv ${next.stickerLevel} - New sticker: ${sticker.name}',
      Icons.arrow_upward_rounded,
      sticker: sticker,
    );
  }

  RunSummary get _runSummary => RunSummary(
    score: _controller.score,
    highestTier: _controller.highestTier,
    bestChain: _controller.bestMergeChain,
    placements: _controller.placements,
    missionXp: _missions.xpEarned,
    mergeCount: _controller.mergeCount,
  );

  /// XP the current run would credit if it ended now.
  int get _runXpSoFar => CampProgress.runXp(_runSummary);

  /// During the welcome run the HUD shows the run's XP live (never past the
  /// welcome level, which is the only mid-run level-up); saved XP is only
  /// credited when the run ends.
  CampProgress get _hudProgress {
    if (!_progress.welcomeRun || _controller.isGameOver) return _progress;
    final cap =
        CampProgress.totalXpForLevel(CampProgress.welcomeLevel + 1) -
        1 -
        _progress.totalXp;
    final pending = _runXpSoFar;
    return _progress.withPendingXp(pending < cap ? pending : cap);
  }

  void _toast(String text, IconData icon, {Sticker? sticker}) {
    _toastSerial += 1;
    _toasts.add(
      ToastMessage(id: _toastSerial, text: text, icon: icon, sticker: sticker),
    );
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
      _runSummary,
      dailyDay: _controller.dailyDay,
    );
    _setProgress(outcome.progress, xpGained: outcome.xpGained);
    if (outcome.announcesLevelUp) {
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

  /// Index of today's local date (for the Daily Camp).
  int get _today => dayIndexOf(widget.clock());

  bool get _dailyOpenToday => !_progress.daily.rewardedOn(_today);

  String get _dailyTooltip {
    final view = streakOn(_progress.daily, _today);
    return view.current > 0
        ? 'Daily camp (streak ${view.current})'
        : 'Daily camp';
  }

  /// Starts or resumes today's Daily Camp from the header button.
  Future<void> _openDaily() async {
    if (_breakAdInProgress || _tutorialBlocking) return;
    if (_guidedPractice) {
      _toast(
        'Finish the practice merge first.',
        Icons.local_fire_department_rounded,
      );
      setState(() {});
      return;
    }
    if (_controller.dailyDay == _today && !_controller.isGameOver) {
      _toast('Daily camp: keep going!', Icons.local_fire_department_rounded);
      setState(() {});
      return;
    }
    await _restartRun(mode: _RunMode.daily);
    if (!mounted) return;
    setState(() {
      _toast(
        'Daily camp: place 5+ tiles and merge to build your streak.',
        Icons.local_fire_department_rounded,
      );
    });
  }

  Future<void> _restartRun({_RunMode mode = _RunMode.same}) async {
    if (_breakAdInProgress || _tutorialBlocking || _secondWindOffer) {
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
      if (outcome != null && outcome.announcesLevelUp) {
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
    _shiftMode = false;
    _guidedPractice = false;
    _coachActive = false;
    _report = null;
    _runApplied = false;
    _missions.reset();
    _milestones.clear();
    _fx.clear();
    _chainLength = 0;
    switch (mode) {
      case _RunMode.same:
        // A daily run from an earlier day retries on today's camp.
        final runDay = _controller.dailyDay;
        if (runDay != null && runDay != _today) {
          _controller.startDaily(_today);
        } else {
          _controller.restart();
        }
      case _RunMode.daily:
        _controller.startDaily(_today);
      case _RunMode.free:
        _controller.startFreePlay();
    }
    _syncGameplay();
    _focusNode.requestFocus();
  }

  /// Reports gameplay start/stop to the platform exactly on transitions:
  /// running only while no tutorial, album or decor screen is open and the
  /// run is not over (the run summary is up while it is).
  void _syncGameplay() {
    final wantActive =
        _appActive &&
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
    if (_secondWindOffer) {
      if (key == LogicalKeyboardKey.keyR || key == LogicalKeyboardKey.escape) {
        if (!isRepeat) _endSecondWind();
        return KeyEventResult.handled;
      }
      if (_isKey(key, activate) &&
          FocusManager.instance.primaryFocus == _focusNode) {
        if (!isRepeat) unawaited(_continueSecondWind());
        return KeyEventResult.handled;
      }
      if (_isKey(key, activate) && isRepeat) return KeyEventResult.handled;
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
    if (key == LogicalKeyboardKey.keyC) {
      if (!isRepeat) _toggleShift();
      return KeyEventResult.handled;
    }
    if (_shiftMode) {
      if (key == LogicalKeyboardKey.escape) {
        // First Esc drops the picked camp, the next one ends the mode.
        if (!isRepeat) {
          setState(() {
            if (_shiftFrom != null) {
              _shiftFrom = null;
            } else {
              _shiftMode = false;
            }
          });
        }
        return KeyEventResult.handled;
      }
      // With a camp picked the arrows choose its direction; before that
      // they move the cursor like usual.
      final direction = _shiftFrom == null ? null : _shiftDirectionOf(key);
      if (direction != null) {
        if (!isRepeat) unawaited(_applyShift(direction));
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyX || key == LogicalKeyboardKey.keyE) {
        return KeyEventResult.handled;
      }
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

  static ShiftDirection? _shiftDirectionOf(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.keyW) {
      return ShiftDirection.up;
    }
    if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.keyS) {
      return ShiftDirection.down;
    }
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyA) {
      return ShiftDirection.left;
    }
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.keyD) {
      return ShiftDirection.right;
    }
    return null;
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
    if (_shiftMode) {
      if (!forceAxe) await _pickShiftCamp(index);
      return;
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
      if (useAxe && result.action == MergeAction.removed) {
        _toolHint = _toolHint == ToolHint.axe ? null : _toolHint;
      }
      if (result.action == MergeAction.removed && mounted) {
        if (_effectsOn && tierBefore != null) {
          _fx.addRemoval(index, tierBefore);
        }
        setState(() {
          _trailAxeMode = false;
          _shiftMode = false;
          _celebrate(_Milestone.axe);
        });
      }
      switch (result.action) {
        case MergeAction.placed:
          await _feedback.tap();
        case MergeAction.merged:
          final chain = _controller.lastMergeChain;
          await (chain >= 2 ? _feedback.chain(chain) : _feedback.merge());
        case MergeAction.removed:
        case MergeAction.shifted:
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
    setState(() {
      _trailAxeMode = !_trailAxeMode;
      _shiftMode = false;
    });
    _focusNode.requestFocus();
  }

  void _toggleShift() {
    if (_guidedPractice || _tutorialBlocking || _albumOpen || _decorOpen) {
      return;
    }
    if (!_shiftMode && !_controller.canUseShift) return;
    setState(() {
      _shiftMode = !_shiftMode;
      _trailAxeMode = false;
    });
    _focusNode.requestFocus();
  }

  /// Shift mode: a tap picks the camp to move; with one picked, a tap on a
  /// highlighted neighbor moves it there and a tap on the camp drops the pick.
  Future<void> _pickShiftCamp(int index) async {
    final from = _shiftFrom;
    if (from != null && index != from) {
      for (final direction in ShiftDirection.values) {
        if (MergeCampController.shiftTarget(from, direction) == index) {
          await _applyShift(direction);
          return;
        }
      }
    }
    if (_controller.board[index] == null) {
      await _feedback.warning();
      return;
    }
    setState(() => _shiftFrom = _shiftFrom == index ? null : index);
    await _feedback.tap();
  }

  Future<void> _applyShift(ShiftDirection direction) async {
    final from = _shiftFrom;
    if (from == null ||
        !_shiftMode ||
        _breakAdInProgress ||
        _handlingTap ||
        _tutorialBlocking ||
        _albumOpen ||
        _decorOpen) {
      return;
    }
    _handlingTap = true;
    try {
      final result = _controller.useShift(from, direction);
      switch (result.action) {
        case MergeAction.shifted:
          if (_toolHint == ToolHint.shift) _toolHint = null;
          setState(() => _shiftMode = false);
          _afterShift();
          final chain = _controller.lastMergeChain;
          if (_controller.lastMergeSteps.isEmpty) {
            await _feedback.tap();
          } else {
            await (chain >= 2 ? _feedback.chain(chain) : _feedback.merge());
          }
        case MergeAction.blocked:
          // Nothing could move that way: keep the mode so another camp can
          // be picked.
          await _feedback.warning();
        case MergeAction.placed:
        case MergeAction.merged:
        case MergeAction.removed:
        case MergeAction.noTool:
        case MergeAction.gameOver:
          if (mounted) setState(() => _shiftMode = false);
          await _feedback.warning();
      }
    } finally {
      _handlingTap = false;
    }
  }

  /// Effects, missions and discoveries of a Shift. The rules have already
  /// been applied; the step plays first, then each merged group.
  void _afterShift() {
    final steps = _controller.lastMergeSteps;
    if (_effectsOn) {
      final groups = <List<MergeStep>>[];
      for (final step in steps) {
        if (step.chainIndex == 1) groups.add(<MergeStep>[]);
        groups.last.add(step);
      }
      // Merged cells that did not move already show their final state; hold
      // their old tiers until the merge effects take over after the slide.
      final moves = List<ShiftMove>.of(_controller.lastShiftMoves);
      final taken = {for (final move in moves) move.to};
      for (final step in steps) {
        for (final cell in [step.origin, ...step.absorbed]) {
          if (taken.add(cell)) {
            moves.add(ShiftMove(from: cell, to: cell, tier: step.fromTier));
          }
        }
      }
      _fx.addShift(
        moves,
        merges: groups,
        erasedTier: _controller.lastShiftErased,
      );
    }
    if (_controller.lastMergeChain >= 2) {
      _chainLength = _controller.lastMergeChain;
      _chainSerial += 1;
    }
    final missionsDone = _settleMissions();
    if (_controller.lastEarnedShift) {
      _toast('Shift earned! Move one camp a step.', Icons.open_with_rounded);
      if (missionsDone.isEmpty) unawaited(_feedback.mission());
    }
    _discoverTiers({
      for (final step in steps) step.toTier.clamp(1, CampTileArt.maxArtTier),
    });
    // The checkpoint taken when the board changed predates mission progress.
    if (!_controller.isGameOver) _checkpointRun();
    setState(() {});
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
                            progress: _hudProgress,
                            missions: _missions,
                            cursor: _cursor,
                            guidedIndex: _guidedPractice ? _guidedPlot : null,
                            onSkipPractice: _skipPractice,
                            coachHint: _coachActive && !_controller.isGameOver
                                ? 'Nice! Keep placing tiles - 3 touching matches merge.'
                                : null,
                            toolHint: _shiftMode || _trailAxeMode
                                ? null
                                : _toolHint?.text,
                            trailAxeMode: _trailAxeMode,
                            shiftMode: _shiftMode,
                            shiftFrom: _shiftFrom,
                            onToggleShift: _toggleShift,
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
                            onOpenDaily: () => unawaited(_openDaily()),
                            dailyOpen: _progressLoaded && _dailyOpenToday,
                            dailyTooltip: _dailyTooltip,
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
                // decides whether the guided first run starts.
                if (_tutorialLoading || !_progressLoaded)
                  const Positioned.fill(child: AbsorbPointer()),
                if (_secondWindOffer)
                  Positioned.fill(
                    child: ExcludeFocus(
                      excluding: _tutorialBlocking,
                      child: SecondWindOverlay(
                        theme: _theme,
                        clears: MergeCampController.secondWindClears,
                        busy: _breakAdInProgress,
                        continueFocus: _secondWindFocus,
                        onContinue: () => unawaited(_continueSecondWind()),
                        onEnd: _endSecondWind,
                      ),
                    ),
                  ),
                if (_controller.isGameOver && !_secondWindOffer)
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
                        progress: _progress,
                        board: _controller.board,
                        shareLink: widget.platform.shareLink,
                        share: widget.resultShare,
                        busy: _breakAdInProgress,
                        animateArt: loopingArt,
                        clock: widget.clock,
                        playAgainFocus: _playAgainFocus,
                        onPlayAgain: () => unawaited(_restartRun()),
                        onAlbum: _openAlbum,
                        onDecorate: _openDecor,
                        onFreePlay: () =>
                            unawaited(_restartRun(mode: _RunMode.free)),
                        onDaily: _dailyOpenToday
                            ? () => unawaited(_openDaily())
                            : null,
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

/// First-run celebrations (feature-first-minute-rewards).
enum _Milestone {
  // Shown as the welcome bonus toast.
  firstMerge('First merge!'),
  bigMerge('Big merge! 4+ camps at once'),
  chain('First chain!'),
  axe('Trail Axe cleared a plot!');

  const _Milestone(this.text);

  final String text;
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
        'Big merges earn a Shift (C moves one camp a step). '
        'Level up to unlock new camp themes.',
  ),
];
