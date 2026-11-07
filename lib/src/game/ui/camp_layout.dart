import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../art/camp_palette.dart';
import '../../art/sticker_art.dart';
import '../../meta/camp_progress.dart';
import '../../meta/camp_theme.dart';
import '../../meta/missions.dart';
import '../../meta/stickers.dart';
import '../merge_camp_controller.dart';
import 'banners.dart';
import 'board_fx.dart';
import 'board_view.dart';
import 'camp_ui.dart';
import 'hud.dart';

/// Board 13+ cells full: danger glow.
const int dangerOccupied = 13;

/// Screen layout without game logic: wide (board centered between two side
/// panels) or narrow (stacked, phone portrait). All state comes in from
/// the screen, all actions go out through callbacks.
class CampHudLayout extends StatelessWidget {
  const CampHudLayout({
    super.key,
    required this.controller,
    required this.theme,
    required this.fx,
    required this.progress,
    required this.missions,
    required this.cursor,
    this.guidedIndex,
    this.onSkipPractice,
    required this.trailAxeMode,
    required this.soundMuted,
    required this.loopingArt,
    required this.shakeSerial,
    required this.chainLength,
    required this.chainSerial,
    required this.discoveryTier,
    required this.discoverySerial,
    required this.toasts,
    required this.onCellTap,
    required this.onOpenAlbum,
    required this.onOpenDecor,
    required this.onOpenHelp,
    required this.onToggleSound,
    required this.onRestart,
    required this.onToggleTrailAxe,
    required this.onChainDone,
    required this.onDiscoveryDone,
    required this.onToastDone,
  });

  final MergeCampController controller;
  final CampTheme theme;
  final BoardFx fx;
  final CampProgress progress;
  final MissionBoard missions;
  final int? cursor;
  final int? guidedIndex;
  final VoidCallback? onSkipPractice;
  final bool trailAxeMode;
  final bool soundMuted;
  final bool loopingArt;
  final int shakeSerial;
  final int chainLength;
  final int chainSerial;
  final int discoveryTier;
  final int discoverySerial;
  final List<ToastMessage> toasts;
  final ValueChanged<int> onCellTap;
  final VoidCallback onOpenAlbum;
  final VoidCallback onOpenDecor;
  final VoidCallback onOpenHelp;
  final VoidCallback onToggleSound;
  final VoidCallback onRestart;
  final VoidCallback onToggleTrailAxe;
  final VoidCallback onChainDone;
  final VoidCallback onDiscoveryDone;
  final ValueChanged<ToastMessage> onToastDone;

  /// Wide when there is clearly more width than height (desktop, 16:9
  /// iframes, landscape phones).
  static bool isWide(BoxConstraints c) =>
      c.maxWidth >= 640 && c.maxWidth >= c.maxHeight * 1.25;

  @override
  Widget build(BuildContext context) {
    final palette = CampPalette.of(theme);
    return LayoutBuilder(
      builder: (context, constraints) => isWide(constraints)
          ? _buildWide(constraints, palette, loopingArt)
          : _buildNarrow(constraints, palette, loopingArt),
    );
  }

  Widget _board(
    CampPalette palette,
    bool loopingArt, {
    bool toastsOnBoard = false,
  }) {
    return BoardView(
      board: controller.board,
      theme: theme,
      fx: fx,
      cursor: cursor,
      axeMode: trailAxeMode,
      animateArt: loopingArt,
      nextTier: controller.nextTier,
      previewPlacement: controller.previewPlacement,
      guidedIndex: guidedIndex,
      danger: controller.occupiedCount >= dangerOccupied,
      pulseDanger: loopingArt,
      shakeSerial: shakeSerial,
      onCellTap: onCellTap,
      overlays: [
        if (guidedIndex != null)
          Positioned(
            left: 4,
            right: 4,
            bottom: 4,
            child: Material(
              color: palette.panel,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                // Wraps on small boards (360x640, 640x480) instead of
                // overflowing; it only ever covers the bottom row.
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  children: [
                    Text(
                      'Tap the glowing plot to merge!',
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                      ),
                      onPressed: onSkipPractice,
                      child: const Text('Skip practice'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (chainLength >= 2)
          Positioned.fill(
            child: ChainBanner(
              key: ValueKey('chain-$chainSerial'),
              chain: chainLength,
              palette: palette,
              onDone: onChainDone,
            ),
          ),
        if (toastsOnBoard)
          Positioned(
            left: 8,
            right: 8,
            bottom: 8,
            child: _toastColumn(palette),
          ),
      ],
    );
  }

  /// "New camp discovered!" card. Lives in the side column (wide) or over
  /// the top HUD (narrow), never over the board cells.
  Widget? _discoveryBanner(bool loopingArt) {
    if (discoveryTier <= 0) return null;
    return DiscoveryBanner(
      key: ValueKey('discovery-$discoverySerial'),
      tier: discoveryTier,
      theme: theme,
      animateArt: loopingArt,
      onDone: onDiscoveryDone,
    );
  }

  Widget _toastColumn(CampPalette palette) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (final toast in toasts)
          CampToast(
            key: ValueKey('toast-${toast.id}'),
            message: toast,
            palette: palette,
            onDone: () => onToastDone(toast),
          ),
      ],
    );
  }

  String get _hint {
    if (trailAxeMode) return 'Tap a camp tile to clear it. Esc cancels.';
    if (cursor != null) {
      return 'Arrows/WASD move, Enter place, X axe, R restart.';
    }
    return 'Connect 3 matching camps to merge them.';
  }

  List<Widget> _menuButtons(CampPalette palette, double size) => [
    PanelIconButton(
      palette: palette,
      icon: Icons.collections_bookmark_rounded,
      tooltip: 'Camp album',
      onPressed: onOpenAlbum,
      size: size,
    ),
    PanelIconButton(
      palette: palette,
      icon: Icons.auto_awesome_rounded,
      tooltip: 'Decorate',
      onPressed: onOpenDecor,
      size: size,
    ),
    PanelIconButton(
      palette: palette,
      icon: Icons.help_outline_rounded,
      tooltip: 'How to play',
      onPressed: onOpenHelp,
      size: size,
    ),
    PanelIconButton(
      palette: palette,
      icon: soundMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
      tooltip: soundMuted ? 'Sound off' : 'Sound on',
      onPressed: onToggleSound,
      size: size,
    ),
    PanelIconButton(
      palette: palette,
      icon: Icons.refresh_rounded,
      tooltip: 'Restart run',
      onPressed: onRestart,
      size: size,
    ),
  ];

  Widget _axeButton(CampPalette palette, {bool compact = false}) {
    return TrailAxeButton(
      palette: palette,
      charges: controller.trailAxes,
      selected: trailAxeMode,
      compact: compact,
      onPressed: controller.canUseTrailAxe || trailAxeMode
          ? onToggleTrailAxe
          : null,
    );
  }

  Widget _bestLine(CampPalette palette, {double fontSize = 14}) {
    final best = math.max(progress.bestScore, controller.score);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.emoji_events_rounded,
          size: fontSize + 4,
          color: palette.accent,
        ),
        const SizedBox(width: 4),
        Text(
          'Best ${formatScore(best)}',
          key: const ValueKey('hud-best'),
          maxLines: 1,
          style: TextStyle(
            color: palette.textSecondary,
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  /// Desktop / 16:9 iframe: big centered board with side panels.
  Widget _buildWide(BoxConstraints c, CampPalette palette, bool loopingArt) {
    const pad = 16.0;
    // A little extra room below the board so it never touches the bottom
    // edge (hub page, browser chrome).
    const bottomPad = 28.0;
    final side = (c.maxWidth * 0.23).clamp(180.0, 300.0);
    final columnHeight = c.maxHeight - pad - bottomPad;
    // Sticker lanes around the board. The left and right lanes take the
    // place of the gaps, and only when the board keeps its minimum size.
    final lane = (math.min(c.maxWidth, c.maxHeight) * 0.06).clamp(24.0, 52.0);
    final across = c.maxWidth - side * 2 - pad * 2;
    final showSides = across - 12 - lane * 2 >= 200;
    final gap = showSides ? 6.0 : 20.0;
    final boardSide = math.max(
      200.0,
      math.min(
        columnHeight - lane * 2,
        across - gap * 2 - (showSides ? lane * 2 : 0),
      ),
    );

    final left = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(child: CampTitle(fontSize: 40)),
        const SizedBox(height: 14),
        CampPanel(
          palette: palette,
          child: CampLevelCard(palette: palette, progress: progress),
        ),
        const SizedBox(height: 12),
        MissionsPanel(
          palette: palette,
          missions: missions.active,
          setNumber: missions.setNumber,
        ),
        // Notices area: discovery banner and toasts, fixed height so the
        // column never jumps.
        SizedBox(
          height: 190,
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.topCenter,
              maxHeight: double.infinity,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_discoveryBanner(loopingArt) case final banner?) ...[
                    const SizedBox(height: 10),
                    banner,
                  ],
                  _toastColumn(palette),
                ],
              ),
            ),
          ),
        ),
      ],
    );

    final right = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CampPanel(
          palette: palette,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              PanelCaption('Score', palette: palette),
              const SizedBox(height: 2),
              ScoreValue(
                score: controller.score,
                palette: palette,
                fontSize: 40,
              ),
              const SizedBox(height: 4),
              _bestLine(palette),
            ],
          ),
        ),
        const SizedBox(height: 12),
        CampPanel(
          palette: palette,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              PanelCaption('Next', palette: palette),
              const SizedBox(height: 8),
              NextTiles(
                tiers: controller.previewTiers,
                theme: theme,
                size: 76,
                animate: loopingArt,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        CampPanel(
          palette: palette,
          padding: const EdgeInsets.all(8),
          highlight: trailAxeMode ? palette.accent : null,
          child: _axeButton(palette),
        ),
        const SizedBox(height: 12),
        CampPanel(
          palette: palette,
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: _menuButtons(palette, 46),
              ),
              const SizedBox(height: 8),
              Text(
                _hint,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(
                  color: palette.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    Widget sideColumn(Widget child) => SizedBox(
      width: side,
      height: columnHeight,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        // Panels are laid out at least at their design width and scaled
        // down as a whole on small screens.
        child: SizedBox(width: math.max(side, 270), child: child),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(pad, pad, pad, bottomPad),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          sideColumn(left),
          SizedBox(width: gap),
          _StickerFrame(
            slots: progress.stickerSlots,
            board: boardSide,
            lane: lane,
            showSides: showSides,
            child: _board(palette, loopingArt),
          ),
          SizedBox(width: gap),
          sideColumn(right),
        ],
      ),
    );
  }

  /// Phone portrait (and anything not wide enough): stacked layout.
  Widget _buildNarrow(BoxConstraints c, CampPalette palette, bool loopingArt) {
    final small = c.maxWidth < 360;
    final buttonSize = small ? 36.0 : 40.0;
    final banner = _discoveryBanner(loopingArt);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: Stack(
            children: [
              _narrowColumn(c, palette, loopingArt, small, buttonSize),
              // Over the score/next panels (not the board); never takes input.
              if (banner != null)
                Positioned(
                  top: buttonSize + 14,
                  left: 0,
                  right: 0,
                  child: Center(child: banner),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _narrowColumn(
    BoxConstraints c,
    CampPalette palette,
    bool loopingArt,
    bool small,
    double buttonSize,
  ) {
    return Column(
      children: [
        Row(
          children: [
            const Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: CampTitle(fontSize: 28),
              ),
            ),
            const SizedBox(width: 6),
            for (final button in _menuButtons(palette, buttonSize)) ...[
              const SizedBox(width: 5),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.panel,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x2A000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: button,
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        CampPanel(
          palette: palette,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PanelCaption('Score', palette: palette),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: ScoreValue(
                        score: controller.score,
                        palette: palette,
                        fontSize: 28,
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: _bestLine(palette, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 6,
                child: CampLevelCard(
                  palette: palette,
                  progress: progress,
                  compact: true,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: small ? 64 : 74,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: CampPanel(
                  palette: palette,
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PanelCaption('Next', palette: palette),
                        const SizedBox(width: 10),
                        NextTiles(
                          tiers: controller.previewTiers,
                          theme: theme,
                          size: 54,
                          animate: loopingArt,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CampPanel(
                palette: palette,
                padding: const EdgeInsets.all(6),
                highlight: trailAxeMode ? palette.accent : null,
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: _axeButton(palette, compact: true),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: LayoutBuilder(
            builder: (context, area) {
              final stripHeight = small ? 58.0 : 66.0;
              // Sticker lanes above and below the board; the side lanes
              // only when the board leaves room for them.
              final lane = (area.maxWidth * 0.1).clamp(24.0, 44.0);
              final boardSide = math.max(
                120.0,
                math.min(
                  area.maxWidth,
                  area.maxHeight - stripHeight - 10 - lane * 2,
                ),
              );
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _StickerFrame(
                    slots: progress.stickerSlots,
                    board: boardSide,
                    lane: lane,
                    showSides: area.maxWidth - boardSide >= lane * 2,
                    child: _board(palette, loopingArt, toastsOnBoard: true),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: stripHeight,
                    child: MissionStrip(
                      palette: palette,
                      missions: missions.active,
                      setNumber: missions.setNumber,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// The board with its sticker lanes: [lane] above and below, and left and
/// right when [showSides]. Stickers are one static, non-interactive layer
/// in the lanes and never cover the board.
class _StickerFrame extends StatelessWidget {
  const _StickerFrame({
    required this.slots,
    required this.board,
    required this.lane,
    required this.showSides,
    required this.child,
  });

  final StickerSlots slots;
  final double board;
  final double lane;
  final bool showSides;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final side = showSides ? lane : 0.0;
    final rect = Rect.fromLTWH(side, lane, board, board);
    return SizedBox(
      width: board + side * 2,
      height: board + lane * 2,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fromRect(rect: rect, child: child),
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(
                  key: const ValueKey('board-stickers'),
                  painter: BoardStickerPainter(
                    slots: slots,
                    boardRect: rect,
                    lane: lane,
                    showSides: showSides,
                    devicePixelRatio:
                        MediaQuery.maybeDevicePixelRatioOf(context) ?? 1,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
