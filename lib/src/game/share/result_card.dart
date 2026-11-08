import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../../art/camp_palette.dart';
import '../../art/camp_tile_art.dart';
import '../../art/sticker_art.dart';
import '../../meta/camp_theme.dart';
import '../../meta/stickers.dart';
import '../merge_camp_controller.dart';
import '../ui/camp_ui.dart';

/// What the shared result card shows (feature-next-goal-share).
class ResultCardData {
  const ResultCardData({
    required this.score,
    required this.best,
    required this.isNewBest,
    required this.highestTier,
    required this.level,
    required this.board,
    required this.stickerSlots,
    required this.theme,
  });

  final int score;
  final int best;
  final bool isNewBest;
  final int highestTier;
  final int level;

  /// Final board, row by row (null is an empty plot).
  final List<int?> board;
  final StickerSlots stickerSlots;
  final CampTheme theme;
}

/// Turns the rendered card into PNG bytes; injectable for tests.
typedef PngEncoder = Future<Uint8List?> Function(ui.Image image);

Future<Uint8List?> encodePng(ui.Image image) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data?.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

/// Card size in pixels (4:5 portrait, the common social feed format).
const Size resultCardSize = Size(1080, 1350);

const String resultCardFileName = 'mergecamp-result.png';

/// Renders the card offscreen and encodes it. Returns null on any failure
/// so callers can show a soft error instead of throwing.
Future<Uint8List?> renderResultCard(
  ResultCardData data, {
  PngEncoder encode = encodePng,
}) async {
  try {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Offset.zero & resultCardSize);
    paintResultCard(canvas, resultCardSize, data);
    final picture = recorder.endRecording();
    final ui.Image image;
    try {
      image = await picture.toImage(
        resultCardSize.width.toInt(),
        resultCardSize.height.toInt(),
      );
    } finally {
      picture.dispose();
    }
    try {
      final bytes = await encode(image);
      return bytes == null || bytes.isEmpty ? null : bytes;
    } finally {
      image.dispose();
    }
  } catch (_) {
    return null;
  }
}

/// Paints the whole card into [size] (designed for [resultCardSize]).
void paintResultCard(Canvas canvas, Size size, ResultCardData data) {
  final palette = CampPalette.of(data.theme);
  final k = size.width / resultCardSize.width;
  canvas.save();
  canvas.scale(k);
  final w = resultCardSize.width;
  final h = resultCardSize.height;

  // Sky and two hill ridges.
  final full = Rect.fromLTWH(0, 0, w, h);
  canvas.drawRect(
    full,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [palette.skyTop, palette.skyBottom],
      ).createShader(full),
  );
  canvas.drawPath(
    Path()
      ..moveTo(0, h * 0.78)
      ..quadraticBezierTo(w * 0.3, h * 0.68, w * 0.62, h * 0.76)
      ..quadraticBezierTo(w * 0.85, h * 0.81, w, h * 0.72)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close(),
    Paint()..color = palette.hillFar,
  );
  canvas.drawPath(
    Path()
      ..moveTo(0, h * 0.88)
      ..quadraticBezierTo(w * 0.45, h * 0.8, w, h * 0.9)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close(),
    Paint()..color = palette.hillNear,
  );

  // Panel.
  final panelRect = Rect.fromLTWH(50, 40, w - 100, h - 80);
  final panelColor = Color.alphaBlend(
    palette.panel,
    palette.skyBottom,
  ).withValues(alpha: 0.94);
  final panel = RRect.fromRectAndRadius(panelRect, const Radius.circular(56));
  canvas.drawRRect(
    panel.shift(const Offset(0, 10)),
    Paint()
      ..color = const Color(0x40000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
  );
  canvas.drawRRect(panel, Paint()..color = panelColor);
  canvas.drawRRect(
    panel,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = palette.panelBorder,
  );

  final cx = w / 2;
  _text(
    canvas,
    'MergeCamp',
    Offset(cx, 78),
    size: 64,
    color: palette.textPrimary,
  );
  _text(
    canvas,
    'SCORE',
    Offset(cx, 172),
    size: 30,
    color: palette.textSecondary,
    weight: FontWeight.w800,
    spacing: 4,
  );
  _text(
    canvas,
    formatScore(data.score),
    Offset(cx, 206),
    size: 140,
    color: palette.textPrimary,
    maxWidth: panelRect.width - 80,
  );

  // Best and the "New best!" pill.
  final bestText = _layout(
    'Best ${formatScore(data.best)}',
    size: 40,
    color: palette.textSecondary,
    weight: FontWeight.w800,
  );
  final pill = data.isNewBest
      ? _layout('New best!', size: 34, color: const Color(0xFFFFFFFF))
      : null;
  final pillWidth = pill == null ? 0.0 : pill.width + 40;
  final rowWidth = bestText.width + (pill == null ? 0 : 24 + pillWidth);
  var x = cx - rowWidth / 2;
  const rowTop = 380.0;
  bestText.paint(canvas, Offset(x, rowTop + 6));
  if (pill != null) {
    x += bestText.width + 24;
    final pillRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, rowTop, pillWidth, pill.height + 16),
      const Radius.circular(20),
    );
    canvas.drawRRect(pillRect, Paint()..color = palette.danger);
    pill.paint(canvas, Offset(x + 20, rowTop + 8));
  }

  // Top camp and camp level.
  const statsTop = 470.0;
  final statsLeft = panelRect.left + 70;
  canvas.save();
  canvas.translate(statsLeft, statsTop);
  paintCampTile(canvas, data.highestTier, data.theme, 130, showBadge: false);
  canvas.restore();
  _layout(
    'TOP CAMP',
    size: 26,
    color: palette.textSecondary,
    weight: FontWeight.w800,
  ).paint(canvas, Offset(statsLeft + 154, statsTop + 18));
  _layout(
    MergeCampController.campTierName(data.highestTier),
    size: 44,
    color: palette.textPrimary,
    maxWidth: 420,
  ).paint(canvas, Offset(statsLeft + 154, statsTop + 56));
  final badgeCenter = Offset(panelRect.right - 150, statsTop + 65);
  canvas.drawCircle(badgeCenter, 70, Paint()..color = const Color(0xFFFFFFFF));
  canvas.drawCircle(badgeCenter, 62, Paint()..color = palette.accent);
  _text(
    canvas,
    'Lv',
    badgeCenter.translate(0, -50),
    size: 30,
    color: palette.onAccent,
    weight: FontWeight.w800,
  );
  _text(
    canvas,
    '${data.level}',
    badgeCenter.translate(0, -18),
    size: 60,
    color: palette.onAccent,
  );

  // Final board with the stickers around it.
  const boardSide = 440.0;
  const lane = 72.0;
  final boardRect = Rect.fromLTWH(
    cx - boardSide / 2,
    712,
    boardSide,
    boardSide,
  );
  _paintBoard(canvas, boardRect, data, palette);
  final d = StickerSlotGeometry.diameter(lane);
  for (final slot in data.stickerSlots.occupied) {
    final sticker = Sticker.byId(data.stickerSlots.at(slot)!);
    if (sticker == null) continue;
    final center =
        boardRect.topLeft +
        StickerSlotGeometry.center(slot, boardRect.width, lane);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(StickerSlotGeometry.tilt(slot));
    canvas.translate(-d / 2, -d / 2);
    paintSticker(canvas, sticker, d);
    canvas.restore();
  }

  _text(
    canvas,
    'Can you build a bigger camp?',
    Offset(cx, 1238),
    size: 38,
    color: palette.textSecondary,
    weight: FontWeight.w800,
  );
  canvas.restore();
}

void _paintBoard(
  Canvas canvas,
  Rect rect,
  ResultCardData data,
  CampPalette palette,
) {
  final frame = RRect.fromRectAndRadius(
    rect.inflate(14),
    const Radius.circular(34),
  );
  canvas.drawRRect(frame, Paint()..color = palette.groundBoard);
  canvas.drawRRect(
    frame,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = Color.lerp(palette.groundBoard, const Color(0xFF000000), 0.25)!,
  );
  const columns = MergeCampController.boardWidth;
  final rows = math.max(1, (data.board.length / columns).ceil());
  final gap = rect.width * 0.02;
  final cell = (rect.width - gap * (columns - 1)) / columns;
  for (var i = 0; i < data.board.length; i++) {
    final col = i % columns;
    final row = i ~/ columns;
    if (row >= rows) break;
    final origin =
        rect.topLeft + Offset(col * (cell + gap), row * (cell + gap));
    final tier = data.board[i];
    if (tier == null) {
      final plot = RRect.fromRectAndRadius(
        origin & Size(cell, cell),
        Radius.circular(cell * 0.18),
      );
      canvas.drawRRect(plot, Paint()..color = palette.plotEmpty);
      canvas.drawRRect(
        plot,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = palette.plotEmptyBorder,
      );
      continue;
    }
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    paintCampTile(canvas, tier, data.theme, cell, showBadge: false);
    canvas.restore();
  }
}

TextPainter _layout(
  String text, {
  required double size,
  required Color color,
  FontWeight weight = FontWeight.w900,
  double spacing = 0,
  double maxWidth = 960,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: 'Roboto',
        fontSize: size,
        fontWeight: weight,
        letterSpacing: spacing,
        color: color,
        height: 1.1,
      ),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: '...',
  )..layout(maxWidth: maxWidth);
  return painter;
}

/// Paints [text] horizontally centered on [top].
void _text(
  Canvas canvas,
  String text,
  Offset top, {
  required double size,
  required Color color,
  FontWeight weight = FontWeight.w900,
  double spacing = 0,
  double maxWidth = 960,
}) {
  final painter = _layout(
    text,
    size: size,
    color: color,
    weight: weight,
    spacing: spacing,
    maxWidth: maxWidth,
  );
  painter.paint(canvas, Offset(top.dx - painter.width / 2, top.dy));
  painter.dispose();
}
