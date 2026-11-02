import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../art/camp_palette.dart';
import '../../art/camp_tile_art.dart';
import '../../art/empty_plot_art.dart';
import '../../meta/camp_theme.dart';
import 'board_fx.dart';

/// The 4x4 camp board: a clearing backdrop, one tappable cell per plot, the
/// effect layer on top and the danger glow around it.
class BoardView extends StatelessWidget {
  const BoardView({
    super.key,
    required this.board,
    required this.theme,
    required this.fx,
    required this.onCellTap,
    required this.nextTier,
    this.cursor,
    this.axeMode = false,
    this.animateArt = true,
    this.danger = false,
    this.pulseDanger = true,
    this.shakeSerial = 0,
    this.overlays = const <Widget>[],
  });

  final List<int?> board;
  final CampTheme theme;
  final BoardFx fx;
  final ValueChanged<int> onCellTap;

  /// Tier shown as a faint preview on a hovered empty plot.
  final int nextTier;
  final int? cursor;
  final bool axeMode;
  final bool animateArt;

  /// 13+ occupied cells: glowing red edge.
  final bool danger;
  final bool pulseDanger;

  /// Changing this value plays one short shake.
  final int shakeSerial;

  /// Banners stacked over the board (never take input).
  final List<Widget> overlays;

  @override
  Widget build(BuildContext context) {
    final palette = CampPalette.of(theme);
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = math.min(constraints.maxWidth, constraints.maxHeight);
        final padding = math.max(8.0, side * 0.035);
        final inner = side - padding * 2;
        final gap = math.max(5.0, inner * 0.022);
        final geometry = BoardGeometry(side: inner, gap: gap);
        Widget content = Container(
          width: side,
          height: side,
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(side * 0.07),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.lerp(palette.groundBoard, Colors.white, 0.08)!,
                palette.groundBoard,
                Color.lerp(palette.groundBoard, Colors.black, 0.12)!,
              ],
            ),
            border: Border.all(
              color: Color.lerp(palette.groundBoard, Colors.black, 0.25)!,
              width: math.max(2, side * 0.006),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x47000000),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              ValueListenableBuilder<Set<int>>(
                valueListenable: fx.hiddenCells,
                builder: (context, hidden, _) => GridView.builder(
                  padding: EdgeInsets.zero,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: board.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: BoardGeometry.columns,
                    crossAxisSpacing: gap,
                    mainAxisSpacing: gap,
                  ),
                  itemBuilder: (context, index) => _BoardCell(
                    tier: hidden.contains(index) ? null : board[index],
                    occupied: board[index] != null,
                    theme: theme,
                    palette: palette,
                    highlighted: cursor == index,
                    axeMode: axeMode,
                    animate: animateArt,
                    nextTier: nextTier,
                    onTap: () => onCellTap(index),
                  ),
                ),
              ),
              Positioned.fill(
                child: BoardFxLayer(fx: fx, geometry: geometry, theme: theme),
              ),
              ...overlays,
            ],
          ),
        );
        content = Stack(
          clipBehavior: Clip.none,
          children: [
            if (danger)
              Positioned.fill(
                child: _DangerGlow(
                  key: const ValueKey('danger-vignette'),
                  palette: palette,
                  pulse: pulseDanger,
                  radius: side * 0.07,
                ),
              ),
            content,
          ],
        );
        if (shakeSerial > 0) {
          content = TweenAnimationBuilder<double>(
            key: ValueKey('shake-$shakeSerial'),
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 380),
            builder: (context, t, child) => Transform.translate(
              offset: Offset(
                math.sin(t * math.pi * 7) * side * 0.012 * (1 - t),
                0,
              ),
              child: child,
            ),
            child: content,
          );
        }
        return Center(child: content);
      },
    );
  }
}

class _BoardCell extends StatefulWidget {
  const _BoardCell({
    required this.tier,
    required this.occupied,
    required this.theme,
    required this.palette,
    required this.highlighted,
    required this.axeMode,
    required this.animate,
    required this.nextTier,
    required this.onTap,
  });

  /// Tier to draw, null for an empty (or momentarily covered) plot.
  final int? tier;

  /// Real board state, which decides the axe-mode look.
  final bool occupied;
  final CampTheme theme;
  final CampPalette palette;
  final bool highlighted;
  final bool axeMode;
  final bool animate;
  final int nextTier;
  final VoidCallback onTap;

  @override
  State<_BoardCell> createState() => _BoardCellState();
}

class _BoardCellState extends State<_BoardCell> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final tier = widget.tier;
    final palette = widget.palette;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final s = constraints.biggest.shortestSide;
            final radius = BorderRadius.circular(s * 0.2);
            return Stack(
              key: widget.highlighted
                  ? const ValueKey('keyboard-cursor')
                  : null,
              fit: StackFit.expand,
              children: [
                if (tier == null)
                  EmptyPlotArt(
                    theme: widget.theme,
                    highlighted: widget.highlighted && !widget.occupied,
                    axeMode: widget.axeMode,
                  )
                else
                  AnimatedScale(
                    scale: _hover && !widget.axeMode ? 1.04 : 1,
                    duration: const Duration(milliseconds: 120),
                    child: CampTileArt(
                      tier: tier,
                      theme: widget.theme,
                      animate: widget.animate,
                    ),
                  ),
                // Preview of the next tile on a hovered empty plot.
                if (tier == null &&
                    !widget.occupied &&
                    _hover &&
                    !widget.axeMode)
                  IgnorePointer(
                    child: Padding(
                      padding: EdgeInsets.all(s * 0.1),
                      child: Opacity(
                        opacity: 0.5,
                        child: CampTileArt(
                          tier: widget.nextTier,
                          theme: widget.theme,
                          animate: false,
                          showBadge: false,
                        ),
                      ),
                    ),
                  ),
                if (widget.axeMode && widget.occupied)
                  IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: radius,
                        color: _hover
                            ? palette.danger.withValues(alpha: 0.28)
                            : null,
                        border: Border.all(
                          color: _hover
                              ? palette.danger
                              : const Color(0xFFFFD166),
                          width: math.max(2, s * 0.04),
                        ),
                      ),
                      child: _hover
                          ? Center(
                              child: Icon(
                                Icons.carpenter_rounded,
                                color: Colors.white,
                                size: s * 0.4,
                              ),
                            )
                          : null,
                    ),
                  ),
                if (widget.highlighted && widget.occupied)
                  IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: radius,
                        border: Border.all(
                          color: Colors.white,
                          width: math.max(3, s * 0.06),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: palette.accent.withValues(alpha: 0.8),
                            blurRadius: s * 0.12,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Pulsing red/orange glow around the board while it is nearly full.
class _DangerGlow extends StatefulWidget {
  const _DangerGlow({
    super.key,
    required this.palette,
    required this.pulse,
    required this.radius,
  });

  final CampPalette palette;
  final bool pulse;
  final double radius;

  @override
  State<_DangerGlow> createState() => _DangerGlowState();
}

class _DangerGlowState extends State<_DangerGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
    value: 0.6,
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_DangerGlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.pulse) {
      if (!_controller.isAnimating) _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = 0.6;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final v = Curves.easeInOut.transform(_controller.value);
          final danger = widget.palette.danger;
          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.radius),
              boxShadow: [
                BoxShadow(
                  color: danger.withValues(alpha: 0.35 + 0.4 * v),
                  blurRadius: 18 + 22 * v,
                  spreadRadius: 3 + 6 * v,
                ),
                BoxShadow(
                  color: const Color(0xFFFF9F43).withValues(alpha: 0.25 * v),
                  blurRadius: 40,
                  spreadRadius: 10 * v,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
