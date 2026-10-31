import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ads/ad_banner.dart';
import '../ads/ad_service.dart';
import '../platform/game_platform.dart';
import 'feedback_fx.dart';
import 'how_to_play.dart';
import 'merge_camp_controller.dart';
import '../../result_registration.dart';

class MergeCampScreen extends StatefulWidget {
  const MergeCampScreen({
    super.key,
    this.enableAds = false,
    this.platform = const NoopGamePlatform(),
    this.controller,
    this.howToPlayStore = const HowToPlayStore(),
  });

  final bool enableAds;
  final GamePlatform platform;

  /// Injected for tests; when null the screen owns its controller.
  final MergeCampController? controller;

  /// First-run tutorial flag storage; tests inject a fake.
  final HowToPlayStore howToPlayStore;

  @override
  State<MergeCampScreen> createState() => _MergeCampScreenState();
}

class _MergeCampScreenState extends State<MergeCampScreen> {
  late final MergeCampController _controller;
  late final FeedbackFx _feedback;
  bool _trailAxeMode = false;
  // Keyboard cursor; null until the player uses the keyboard.
  int? _cursor;
  final FocusNode _focusNode = FocusNode(debugLabel: 'MergeCampBoard');
  bool _handlingTap = false;
  bool _wasGameOver = false;
  bool _breakAdInProgress = false;
  int _completedRuns = 0;
  // The tutorial blocks all game input while the first-run check is pending
  // (_tutorialLoading) and while the card is open (_showHowTo).
  bool _tutorialLoading = true;
  bool _showHowTo = false;

  // Whether the platform currently believes gameplay is running.
  bool _gameplayActive = false;

  bool get _tutorialBlocking => _tutorialLoading || _showHowTo;

  @override
  void initState() {
    super.initState();
    unawaited(_checkTutorial());
    _feedback = FeedbackFx(isMuted: () => widget.platform.isAudioMuted);
    unawaited(_feedback.initialize());
    _controller = (widget.controller ?? MergeCampController())
      ..addListener(_onChanged);
    _wasGameOver = _controller.isGameOver;
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
    _focusNode.requestFocus();
    unawaited(_markTutorialSeen());
  }

  Future<void> _markTutorialSeen() async {
    try {
      await widget.howToPlayStore.markSeen();
    } catch (_) {}
  }

  @override
  void dispose() {
    _focusNode.dispose();
    unawaited(_feedback.dispose());
    _controller.removeListener(_onChanged);
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _onChanged() {
    final runEnded = _controller.isGameOver && !_wasGameOver;
    _wasGameOver = _controller.isGameOver;
    if (runEnded) {
      _syncGameplay();
      if (widget.platform.allowsResultRegistration) {
        _offerResultRegistration();
      }
      if (widget.enableAds) {
        _handleRunEndedAds();
      }
    }
    if (mounted) {
      setState(() {});
    }
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
      AdService.instance.showInterstitialIfReady();
    } else {
      unawaited(AdService.instance.loadInterstitial());
    }
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
      try {
        await widget.platform.showRunBreakAd();
      } catch (error) {
        debugPrint('Run break ad failed: $error');
      }
      if (!mounted) {
        return;
      }
      _breakAdInProgress = false;
    }
    _trailAxeMode = false;
    _controller.restart();
    _syncGameplay();
  }

  /// Reports gameplay start/stop to the platform exactly on transitions:
  /// running only while no tutorial is open and the run is not over.
  void _syncGameplay() {
    final wantActive = !_tutorialBlocking && !_controller.isGameOver;
    if (wantActive == _gameplayActive) return;
    _gameplayActive = wantActive;
    if (wantActive) {
      widget.platform.gameplayStart();
    } else {
      widget.platform.gameplayStop();
    }
  }

  static const int _boardColumns = 4;

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    // The how-to-play card owns the keyboard while it is open.
    if (_tutorialBlocking) return KeyEventResult.handled;
    // Leave browser/OS shortcuts (Cmd/Ctrl+R etc.) alone.
    if (HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isAltPressed) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.keyR) {
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
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space) {
      if (_cursor == null) {
        setState(() => _cursor = 0);
      } else {
        unawaited(_handleCellTap(_cursor!));
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyX || key == LogicalKeyboardKey.keyE) {
      if (_cursor == null) {
        setState(() => _cursor = 0);
      } else {
        unawaited(_handleCellTap(_cursor!, forceAxe: true));
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _handleCellTap(
    int index, {
    bool forceAxe = false,
    bool fromPointer = false,
  }) async {
    if (_breakAdInProgress || _handlingTap) return;
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
      final result = useAxe
          ? _controller.useTrailAxe(index)
          : _controller.place(index);
      if (result.action == MergeAction.removed && mounted) {
        setState(() {
          _trailAxeMode = false;
        });
      }
      switch (result.action) {
        case MergeAction.placed:
          await _feedback.tap();
        case MergeAction.merged:
          await _feedback.merge();
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

  @override
  Widget build(BuildContext context) {
    final board = _controller.board;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _onKeyEvent,
        child: Stack(
          children: [
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  // Keeps the portrait layout readable in landscape desktop iframes.
                  constraints: const BoxConstraints(
                    maxWidth: kIsWeb ? 560 : double.infinity,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                    child: Column(
                      children: [
                        _TopBar(
                          controller: _controller,
                          onRestart: _restartRun,
                          onHelp: _openHowToPlay,
                        ),
                        const SizedBox(height: 8),
                        _ToolBar(
                          controller: _controller,
                          trailAxeMode: _trailAxeMode,
                          onToggleTrailAxe: _controller.canUseTrailAxe
                              ? () {
                                  setState(() {
                                    _trailAxeMode = !_trailAxeMode;
                                  });
                                }
                              : null,
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final boardSize = math.min(
                                constraints.maxWidth,
                                constraints.maxHeight,
                              );
                              return Center(
                                child: SizedBox.square(
                                  dimension: boardSize,
                                  child: GridView.builder(
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: board.length,
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 4,
                                          crossAxisSpacing: 8,
                                          mainAxisSpacing: 8,
                                        ),
                                    itemBuilder: (context, index) {
                                      final tier = board[index];
                                      return _CampTile(
                                        tier: tier,
                                        trailAxeMode: _trailAxeMode,
                                        highlighted: _cursor == index,
                                        onTap: () => _handleCellTap(
                                          index,
                                          fromPointer: true,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _controller.isGameOver
                              ? 'Board jammed. Restart for another run.'
                              : _cursor != null
                              ? 'Arrows/WASD move, Enter/Space place, X axe, R restart.'
                              : _trailAxeMode
                              ? 'Tap an occupied camp tile to clear a path.'
                              : 'Connect 3 matching camp tiles to raise the camp.',
                          style: const TextStyle(
                            color: Color(0xFFD8E4D9),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (_controller.isGameOver) ...[
                          const SizedBox(height: 8),
                          FilledButton(
                            onPressed: _breakAdInProgress ? null : _restartRun,
                            child: const Text('Restart Run'),
                          ),
                        ],
                        AdBanner(enabled: widget.enableAds),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (_showHowTo)
              Positioned.fill(
                child: HowToPlayOverlay(
                  steps: _howToPlaySteps,
                  onClose: _closeHowToPlay,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

const List<HowToPlayStep> _howToPlaySteps = [
  HowToPlayStep(
    icon: Icons.grid_view,
    text:
        'Match 3 or more touching camp tiles to merge them into a higher '
        'tier. Keep the 4x4 board from jamming.',
  ),
  HowToPlayStep(
    icon: Icons.touch_app,
    text:
        'Tap an empty tile to place the next piece. Keyboard: arrows/WASD '
        'move, Enter/Space place.',
  ),
  HowToPlayStep(
    icon: Icons.hardware,
    text:
        'Stuck? The Trail Axe clears one tile (X on keyboard). You get one '
        'now and more every 10 moves.',
  ),
];

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.controller,
    required this.onRestart,
    required this.onHelp,
  });

  final MergeCampController controller;
  final VoidCallback onRestart;
  final VoidCallback onHelp;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              'MergeCamp',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _MetricPill(label: 'Score', value: '${controller.score}'),
                const SizedBox(width: 6),
                _MetricPill(label: 'Moves', value: '${controller.placements}'),
              ],
            ),
          ),
        ),
        IconButton(
          onPressed: onHelp,
          tooltip: 'How to play',
          icon: const Icon(Icons.help_outline),
        ),
        IconButton(
          onPressed: onRestart,
          tooltip: 'Restart run',
          icon: const Icon(Icons.refresh),
        ),
      ],
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2B22),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Color(0xFFA6BBA8)),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _ToolBar extends StatelessWidget {
  const _ToolBar({
    required this.controller,
    required this.trailAxeMode,
    required this.onToggleTrailAxe,
  });

  final MergeCampController controller;
  final bool trailAxeMode;
  final VoidCallback? onToggleTrailAxe;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _PreviewStrip(tiers: controller.previewTiers)),
        const SizedBox(width: 10),
        Tooltip(
          message: 'Trail Axe clears one occupied tile',
          child: IconButton.filledTonal(
            onPressed: onToggleTrailAxe,
            isSelected: trailAxeMode,
            icon: Badge.count(
              count: controller.trailAxes,
              isLabelVisible: controller.trailAxes > 0,
              child: const Icon(Icons.hardware),
            ),
            selectedIcon: Badge.count(
              count: controller.trailAxes,
              child: const Icon(Icons.hardware),
            ),
          ),
        ),
      ],
    );
  }
}

class _PreviewStrip extends StatelessWidget {
  const _PreviewStrip({required this.tiers});

  final List<int> tiers;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2D23),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF42624C)),
      ),
      child: Row(
        children: [
          const Text(
            'Next',
            style: TextStyle(
              color: Color(0xFFC7DCC9),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 10),
          for (final tier in tiers) ...[
            _MiniCampTile(tier: tier),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

class _MiniCampTile extends StatelessWidget {
  const _MiniCampTile({required this.tier});

  final int tier;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 38,
      decoration: BoxDecoration(
        color: _tileColor(tier),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          'T$tier',
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _CampTile extends StatelessWidget {
  const _CampTile({
    required this.tier,
    required this.trailAxeMode,
    required this.onTap,
    this.highlighted = false,
  });

  final int? tier;
  final bool trailAxeMode;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tileTier = tier;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          key: highlighted ? const ValueKey('keyboard-cursor') : null,
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: tileTier == null
                ? const Color(0xFF243329)
                : _tileColor(tileTier),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: highlighted
                  ? Colors.white
                  : trailAxeMode && tileTier != null
                  ? const Color(0xFFFFD166)
                  : const Color(0xFF92DE7D),
              width: highlighted ? 4 : (tileTier == null ? 1 : 2),
            ),
          ),
          child: Center(
            child: tileTier == null
                ? Icon(
                    trailAxeMode ? Icons.block : Icons.add,
                    color: const Color(0xFF7B9381),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'T$tileTier',
                        style: const TextStyle(
                          fontSize: 20,
                          height: 1,
                          fontWeight: FontWeight.w900,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Icon(
                        _tileIcon(tileTier),
                        color: Colors.black87,
                        size: 22,
                      ),
                      const SizedBox(height: 3),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            MergeCampController.campTierName(tileTier),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Colors.black87,
                            ),
                          ),
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

Color _tileColor(int tier) {
  const palette = [
    Color(0xFFB4E197),
    Color(0xFFFFC857),
    Color(0xFF7DCF7B),
    Color(0xFF4EA8DE),
    Color(0xFFF29E4C),
    Color(0xFFA275D1),
    Color(0xFFF06AA0),
    Color(0xFF6ED6D1),
  ];
  return palette[(tier - 1).clamp(0, palette.length - 1)];
}

IconData _tileIcon(int tier) {
  const icons = [
    Icons.terrain,
    Icons.local_fire_department,
    Icons.inventory_2,
    Icons.cabin,
    Icons.cell_tower,
    Icons.holiday_village,
    Icons.flag,
    Icons.workspace_premium,
  ];
  return icons[(tier - 1).clamp(0, icons.length - 1)];
}
