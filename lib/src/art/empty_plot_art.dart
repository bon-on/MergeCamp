import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../meta/camp_theme.dart';
import 'camp_palette.dart';

/// An empty camp plot: a soft grass (or snow) patch with stake markers and a
/// faint "+". Fills the square box it gets, same corner radius as
/// [CampTileArt] cards.
class EmptyPlotArt extends StatelessWidget {
  const EmptyPlotArt({
    super.key,
    this.theme = CampTheme.summer,
    this.highlighted = false,
    this.axeMode = false,
  });

  final CampTheme theme;

  /// Keyboard cursor ring.
  final bool highlighted;

  /// Trail Axe mode: empty plots are not targets, so they are dimmed.
  final bool axeMode;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: axeMode ? 0.5 : 1,
      child: CustomPaint(
        painter: _EmptyPlotPainter(
          palette: CampPalette.of(theme),
          highlighted: highlighted,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _EmptyPlotPainter extends CustomPainter {
  _EmptyPlotPainter({required this.palette, required this.highlighted});

  final CampPalette palette;
  final bool highlighted;

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    if (s <= 0) return;
    canvas.save();
    canvas.translate((size.width - s) / 2, (size.height - s) / 2);
    final rect = Rect.fromLTWH(0, 0, s, s);
    final radius = Radius.circular(s * 0.2);
    final plot = RRect.fromRectAndRadius(rect, radius);
    final base = palette.plotEmpty;

    canvas.drawRRect(
      plot,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(base, const Color(0xFF000000), 0.12)!, base],
        ).createShader(rect),
    );
    // Inner sunken soil patch.
    final inner = plot.deflate(s * 0.1);
    canvas.drawRRect(
      inner,
      Paint()
        ..color = Color.lerp(
          base,
          const Color(0xFF000000),
          0.1,
        )!.withValues(alpha: 0.6),
    );
    canvas.drawRRect(
      inner,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, s * 0.015)
        ..color = Color.lerp(
          base,
          const Color(0xFF000000),
          0.22,
        )!.withValues(alpha: 0.5),
    );

    // Corner stakes.
    final stake = Paint()
      ..color = palette.plotEmptyBorder
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(1.2, s * 0.035);
    final d = s * 0.2;
    final l = s * 0.07;
    for (final c in [
      Offset(d, d),
      Offset(s - d, d),
      Offset(d, s - d),
      Offset(s - d, s - d),
    ]) {
      final dx = c.dx < s / 2 ? 1 : -1;
      final dy = c.dy < s / 2 ? 1 : -1;
      canvas.drawLine(c, c.translate(l * dx, 0), stake);
      canvas.drawLine(c, c.translate(0, l * dy), stake);
    }

    // Faint plus.
    final plus = Paint()
      ..color = palette.plotEmptyBorder.withValues(alpha: 0.75)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(1.4, s * 0.05);
    final c = Offset(s / 2, s / 2);
    final arm = s * 0.1;
    canvas.drawLine(c.translate(-arm, 0), c.translate(arm, 0), plus);
    canvas.drawLine(c.translate(0, -arm), c.translate(0, arm), plus);

    // Rim.
    canvas.drawRRect(
      plot.deflate(s * 0.01),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, s * 0.02)
        ..color = palette.plotEmptyBorder,
    );

    if (highlighted) {
      canvas.drawRRect(
        plot.deflate(s * 0.03),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(2, s * 0.06)
          ..color = const Color(0xFFFFFFFF),
      );
      canvas.drawRRect(
        plot.deflate(s * 0.085),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1, s * 0.025)
          ..color = palette.accent,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_EmptyPlotPainter old) =>
      old.palette != palette || old.highlighted != highlighted;
}
