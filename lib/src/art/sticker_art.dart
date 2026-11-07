import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../meta/stickers.dart';
import 'art_raster_cache.dart';

/// Where the [StickerSlots.count] slots sit around a board square: 0-2 in
/// the lane above, 3-5 below, 6-7 left and 8-9 right, each slightly tilted
/// like a hand-stuck sticker.
class StickerSlotGeometry {
  const StickerSlotGeometry._();

  static const List<double> _across = [0.2, 0.5, 0.8];
  static const List<double> _down = [0.3, 0.7];
  static const List<double> _tilts = [
    -0.14,
    0.06,
    0.18,
    0.12,
    -0.08,
    -0.16,
    -0.1,
    0.14,
    0.1,
    -0.12,
  ];

  /// Left and right slots, which narrow portrait screens leave out.
  static bool isSide(int slot) => slot >= StickerSlots.topBottomCount;

  /// Center of [slot] relative to the top-left corner of a [board] wide
  /// square with [lane] wide margins around it.
  static Offset center(int slot, double board, double lane) {
    if (slot < 3) return Offset(board * _across[slot], -lane / 2);
    if (slot < 6) return Offset(board * _across[slot - 3], board + lane / 2);
    if (slot < 8) return Offset(-lane / 2, board * _down[slot - 6]);
    return Offset(board + lane / 2, board * _down[slot - 8]);
  }

  static double tilt(int slot) => _tilts[slot % _tilts.length];

  /// Sticker diameter in a [lane] wide margin.
  static double diameter(double lane) => lane * 0.86;
}

/// One sticker badge: drop shadow, white (common) or gold (rare) border, a
/// tinted disc and a flat vector picture. Fills the square it is given.
/// [sparkle] twinkles rare stickers (decor screen and reward banners only).
class StickerArt extends StatefulWidget {
  const StickerArt({
    super.key,
    required this.sticker,
    this.silhouette = false,
    this.sparkle = false,
  });

  final Sticker sticker;

  /// Not owned yet: grey disc and a flat dark shape.
  final bool silhouette;
  final bool sparkle;

  @override
  State<StickerArt> createState() => _StickerArtState();
}

class _StickerArtState extends State<StickerArt>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  bool get _wantsSparkle =>
      widget.sparkle && widget.sticker.rare && !widget.silhouette;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(StickerArt oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (_wantsSparkle) {
      final controller = _controller ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1800),
      );
      if (!controller.isAnimating) controller.repeat();
    } else if (_controller?.isAnimating ?? false) {
      _controller!.stop();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = RepaintBoundary(
      child: CustomPaint(
        painter: _StickerPainter(
          widget.sticker,
          widget.silhouette,
          MediaQuery.maybeDevicePixelRatioOf(context) ?? 1,
        ),
        child: const SizedBox.expand(),
      ),
    );
    if (!_wantsSparkle) return still;
    return Stack(
      fit: StackFit.expand,
      children: [
        still,
        IgnorePointer(
          child: CustomPaint(painter: _SparklePainter(_controller!)),
        ),
      ],
    );
  }
}

class _StickerPainter extends CustomPainter {
  _StickerPainter(this.sticker, this.silhouette, this.devicePixelRatio);

  final Sticker sticker;
  final bool silhouette;
  final double devicePixelRatio;

  /// The decor screen shows the 25 tray stickers and up to 10 slots.
  static final ArtRasterCache _rasters = ArtRasterCache(maxEntries: 64);

  @override
  void paint(Canvas canvas, Size size) {
    final d = math.min(size.width, size.height);
    if (d <= 0) return;
    final dx = (size.width - d) / 2;
    final dy = (size.height - d) / 2;
    final px = (d * devicePixelRatio).ceil();
    if (!ArtRasterCache.enabled || px > ArtRasterCache.maxSide) {
      canvas.save();
      canvas.translate(dx, dy);
      paintSticker(canvas, sticker, d, silhouette: silhouette);
      canvas.restore();
      return;
    }
    final image = _rasters.image((sticker.id, silhouette, px), px, px, (c) {
      c.scale(px / d);
      paintSticker(c, sticker, d, silhouette: silhouette);
    });
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, px.toDouble(), px.toDouble()),
      Rect.fromLTWH(dx, dy, d, d),
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(_StickerPainter old) =>
      old.sticker != sticker ||
      old.silhouette != silhouette ||
      old.devicePixelRatio != devicePixelRatio;
}

/// Three small stars twinkling around the rim of a rare sticker.
class _SparklePainter extends CustomPainter {
  _SparklePainter(this.animation) : super(repaint: animation);

  final Animation<double> animation;

  static const List<(double, double, double)> _spots = [
    (-0.75, 0.0, 0.22), // angle (turns from top), phase, size
    (0.15, 0.4, 0.16),
    (0.4, 0.7, 0.13),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final d = math.min(size.width, size.height);
    final c = size.center(Offset.zero);
    for (final (turn, phase, s) in _spots) {
      final v = math.sin((animation.value + phase) * math.pi * 2);
      if (v <= 0) continue;
      final a = turn * math.pi * 2 - math.pi / 2;
      final p = c + Offset(math.cos(a), math.sin(a)) * d * 0.44;
      final r = d * s * 0.5 * (0.6 + 0.4 * v);
      canvas.drawPath(
        _star4(p, r, r * 0.28),
        Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: v),
      );
      canvas.drawCircle(
        p,
        r * 0.3,
        Paint()..color = const Color(0xFFFFE07A).withValues(alpha: v),
      );
    }
  }

  @override
  bool shouldRepaint(_SparklePainter old) => old.animation != animation;
}

/// All placed stickers around the board as one static layer. With
/// [ArtRasterCache.enabled] (web) it is rasterized once per placement,
/// logical size and pixel ratio and then drawn as a single image, so the
/// animating board never replays the sticker vectors (feature-mobile-perf).
class BoardStickerPainter extends CustomPainter {
  BoardStickerPainter({
    required this.slots,
    required this.boardRect,
    required this.lane,
    required this.showSides,
    required this.devicePixelRatio,
  });

  final StickerSlots slots;

  /// Board square inside the painted area; the lanes are around it.
  final Rect boardRect;
  final double lane;

  /// False on narrow portrait screens: the left and right slots stay
  /// visible in the decor screen only.
  final bool showSides;
  final double devicePixelRatio;

  static final ArtRasterCache _rasters = ArtRasterCache(maxEntries: 2);

  /// Same limit as the scenery layers.
  static const int maxPixels = 3200000;

  /// Number of times the layer was rasterized (tests check reuse).
  static int debugRasterCount = 0;

  @override
  void paint(Canvas canvas, Size size) {
    if (slots.isEmpty || lane <= 0) return;
    final w = (size.width * devicePixelRatio).ceil();
    final h = (size.height * devicePixelRatio).ceil();
    if (!ArtRasterCache.enabled || w <= 0 || h <= 0 || w * h > maxPixels) {
      _paintStickers(canvas);
      return;
    }
    final key = (
      slots.signature,
      size.width,
      size.height,
      boardRect,
      lane,
      showSides,
      devicePixelRatio,
    );
    final image = _rasters.image(key, w, h, (c) {
      debugRasterCount += 1;
      c.scale(w / size.width, h / size.height);
      _paintStickers(c);
    });
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.low,
    );
  }

  void _paintStickers(Canvas canvas) {
    final d = StickerSlotGeometry.diameter(lane);
    for (final slot in slots.occupied) {
      if (!showSides && StickerSlotGeometry.isSide(slot)) continue;
      final sticker = Sticker.byId(slots.at(slot)!);
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
  }

  @override
  bool shouldRepaint(BoardStickerPainter old) =>
      old.slots != slots ||
      old.boardRect != boardRect ||
      old.lane != lane ||
      old.showSides != showSides ||
      old.devicePixelRatio != devicePixelRatio;
}

// ----------------------------------------------------------------- drawing

const Color _silhouetteFace = Color(0xFFBAC4C2);
const Color _silhouetteShape = Color(0xFF55636A);

/// Paints [sticker] as a badge in a [d] x [d] square at the origin.
void paintSticker(
  Canvas canvas,
  Sticker sticker,
  double d, {
  bool silhouette = false,
}) {
  final r = d / 2;
  final c = Offset(r, r);
  final outer = r * 0.92;
  final inner = outer * 0.84;
  canvas.drawCircle(
    c + Offset(0, d * 0.035),
    outer,
    Paint()
      ..color = const Color(0x55000000)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, d * 0.03),
  );
  final ring = Rect.fromCircle(center: c, radius: outer);
  final Paint border;
  if (silhouette) {
    border = Paint()..color = const Color(0xFFDDE3E2);
  } else if (sticker.rare) {
    border = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFF0A8), Color(0xFFF2B829), Color(0xFFC98A10)],
      ).createShader(ring);
  } else {
    border = Paint()..color = const Color(0xFFFFFFFF);
  }
  canvas.drawCircle(c, outer, border);
  canvas.drawCircle(
    c,
    outer,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.5, d * 0.012)
      ..color = sticker.rare && !silhouette
          ? const Color(0xFFA06C00)
          : const Color(0x26000000),
  );

  final disc = Rect.fromCircle(center: c, radius: inner);
  final bg = silhouette ? _silhouetteFace : _backgrounds[sticker.id]!;
  canvas.drawCircle(
    c,
    inner,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color.lerp(bg, const Color(0xFFFFFFFF), 0.25)!, bg],
      ).createShader(disc),
  );

  canvas.save();
  canvas.clipPath(Path()..addOval(disc));
  canvas.translate(c.dx, c.dy);
  canvas.scale(inner);
  if (silhouette) {
    canvas.saveLayer(
      const Rect.fromLTRB(-1, -1, 1, 1),
      Paint()
        ..colorFilter = const ColorFilter.mode(
          _silhouetteShape,
          BlendMode.srcIn,
        ),
    );
  }
  (_pictures[sticker.id] ?? _pennant)(canvas);
  if (silhouette) canvas.restore();
  canvas.restore();

  // Glossy highlight on the border.
  if (!silhouette) {
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: outer * 0.92),
      math.pi * 1.1,
      math.pi * 0.5,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = d * 0.03
        ..color = const Color(0x88FFFFFF),
    );
  }
}

const Map<String, Color> _backgrounds = {
  'pennant': Color(0xFFBFE3F5),
  'pine-tree': Color(0xFFD3EECB),
  'acorn': Color(0xFFF7E1BE),
  'lantern': Color(0xFF3B4C74),
  'spark': Color(0xFF5E4A9E),
  'marshmallow': Color(0xFFFFD9E0),
  'compass': Color(0xFFCFE7EC),
  'mug': Color(0xFFFFE4BF),
  'hiking-boot': Color(0xFFDDEBCE),
  'moon': Color(0xFF243266),
  'binoculars': Color(0xFFD6E8CC),
  'kite': Color(0xFFC6E7FA),
  'mushroom': Color(0xFFDDEFD0),
  'fox': Color(0xFFFFE4C7),
  'owl': Color(0xFFE2D7F4),
  'map': Color(0xFFCDEAF3),
  'canoe': Color(0xFFCBE8F6),
  'fish': Color(0xFFCBEDEA),
  'butterfly': Color(0xFFF1DCF6),
  'rainbow': Color(0xFFD2ECFB),
  'bear-cub': Color(0xFFF4E2C9),
  'snowflake': Color(0xFF7FB8E6),
  'leaf': Color(0xFFFFEDCF),
  'sunflower': Color(0xFFD5ECFF),
  'star-badge': Color(0xFF2F5F91),
};

/// Pictures in unit space: the disc is the circle of radius 1 at the origin.
const Map<String, void Function(Canvas)> _pictures = {
  'pennant': _pennant,
  'pine-tree': _pineTree,
  'acorn': _acorn,
  'lantern': _lantern,
  'spark': _spark,
  'marshmallow': _marshmallow,
  'compass': _compass,
  'mug': _mug,
  'hiking-boot': _hikingBoot,
  'moon': _moon,
  'binoculars': _binoculars,
  'kite': _kite,
  'mushroom': _mushroom,
  'fox': _fox,
  'owl': _owl,
  'map': _map,
  'canoe': _canoe,
  'fish': _fish,
  'butterfly': _butterfly,
  'rainbow': _rainbow,
  'bear-cub': _bearCub,
  'snowflake': _snowflake,
  'leaf': _leaf,
  'sunflower': _sunflower,
  'star-badge': _starBadge,
};

Paint _fill(int color) => Paint()..color = Color(color);

Paint _stroke(int color, double width) => Paint()
  ..color = Color(color)
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

Path _poly(List<Offset> points) => Path()..addPolygon(points, true);

Path _star4(Offset c, double outer, double inner) {
  final path = Path();
  for (var i = 0; i < 8; i++) {
    final a = -math.pi / 2 + i * math.pi / 4;
    final r = i.isEven ? outer : inner;
    final p = c + Offset(math.cos(a), math.sin(a)) * r;
    i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
  }
  return path..close();
}

Path _star5(Offset c, double outer, double inner) {
  final path = Path();
  for (var i = 0; i < 10; i++) {
    final a = -math.pi / 2 + i * math.pi / 5;
    final r = i.isEven ? outer : inner;
    final p = c + Offset(math.cos(a), math.sin(a)) * r;
    i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
  }
  return path..close();
}

Rect _oval(double cx, double cy, double w, double h) =>
    Rect.fromCenter(center: Offset(cx, cy), width: w, height: h);

void _grass(Canvas canvas, [int color = 0xFF7BC46A]) {
  canvas.drawOval(_oval(0, 0.98, 2.2, 0.6), _fill(color));
}

void _pennant(Canvas canvas) {
  _grass(canvas);
  canvas.drawRRect(
    RRect.fromLTRBR(-0.55, -0.68, -0.45, 0.8, const Radius.circular(0.05)),
    _fill(0xFF8D5A3B),
  );
  canvas.drawCircle(const Offset(-0.5, -0.72), 0.09, _fill(0xFFF2B829));
  canvas.drawPath(
    _poly(const [
      Offset(-0.45, -0.62),
      Offset(0.66, -0.34),
      Offset(-0.45, -0.06),
    ]),
    _fill(0xFFE84A4A),
  );
  canvas.drawPath(
    _poly(const [
      Offset(-0.45, -0.44),
      Offset(0.22, -0.34),
      Offset(-0.45, -0.24),
    ]),
    _fill(0xFFFFF1D6),
  );
}

void _pineTree(Canvas canvas) {
  _grass(canvas, 0xFF8FCB78);
  canvas.drawRect(
    const Rect.fromLTRB(-0.1, 0.42, 0.1, 0.78),
    _fill(0xFF8D5A3B),
  );
  const green = 0xFF2F8F4E;
  canvas.drawPath(
    _poly(const [Offset(0, -0.82), Offset(0.38, -0.26), Offset(-0.38, -0.26)]),
    _fill(green),
  );
  canvas.drawPath(
    _poly(const [Offset(0, -0.52), Offset(0.5, 0.1), Offset(-0.5, 0.1)]),
    _fill(green),
  );
  canvas.drawPath(
    _poly(const [Offset(0, -0.16), Offset(0.62, 0.5), Offset(-0.62, 0.5)]),
    _fill(green),
  );
  // Darker right half for a little depth.
  canvas.drawPath(
    _poly(const [Offset(0, -0.16), Offset(0.62, 0.5), Offset(0, 0.5)]),
    _fill(0x33000000),
  );
}

void _acorn(Canvas canvas) {
  final body = Path()
    ..moveTo(-0.46, -0.08)
    ..cubicTo(-0.46, 0.45, -0.16, 0.7, 0, 0.82)
    ..cubicTo(0.16, 0.7, 0.46, 0.45, 0.46, -0.08)
    ..close();
  canvas.drawPath(body, _fill(0xFFC98A4B));
  canvas.drawOval(_oval(-0.2, 0.18, 0.16, 0.36), _fill(0x55FFFFFF));
  canvas.drawOval(_oval(0, -0.18, 1.12, 0.48), _fill(0xFF7A4B2A));
  canvas.drawLine(
    const Offset(-0.32, -0.18),
    const Offset(0.32, -0.18),
    _stroke(0x55000000, 0.05),
  );
  canvas.drawRRect(
    RRect.fromLTRBR(-0.06, -0.66, 0.06, -0.36, const Radius.circular(0.06)),
    _fill(0xFF5A3620),
  );
}

void _lantern(Canvas canvas) {
  canvas.drawCircle(const Offset(0, 0.1), 0.78, _fill(0x44FFD86B));
  canvas.drawArc(
    const Rect.fromLTRB(-0.26, -0.82, 0.26, -0.3),
    math.pi,
    math.pi,
    false,
    _stroke(0xFF2E2E2E, 0.08),
  );
  canvas.drawPath(
    _poly(const [
      Offset(-0.3, -0.48),
      Offset(0.3, -0.48),
      Offset(0.42, -0.3),
      Offset(-0.42, -0.3),
    ]),
    _fill(0xFFC0392B),
  );
  canvas.drawRect(
    const Rect.fromLTRB(-0.32, -0.3, 0.32, 0.46),
    _fill(0xFFFFE08A),
  );
  canvas.drawOval(_oval(0, 0.1, 0.24, 0.4), _fill(0xFFFF8A2A));
  canvas.drawOval(_oval(0, 0.16, 0.1, 0.18), _fill(0xFFFFF4C2));
  for (final x in const [-0.32, 0.32]) {
    canvas.drawLine(
      Offset(x, -0.3),
      Offset(x, 0.46),
      _stroke(0xFF2E2E2E, 0.07),
    );
  }
  canvas.drawRect(
    const Rect.fromLTRB(-0.42, 0.46, 0.42, 0.6),
    _fill(0xFFC0392B),
  );
}

void _spark(Canvas canvas) {
  final star = _star4(Offset.zero, 0.8, 0.22);
  canvas.drawPath(star, _fill(0xFFFFC93C));
  canvas.drawPath(star, _stroke(0xFFFF9F1C, 0.05));
  canvas.drawPath(
    _star4(const Offset(0.55, -0.5), 0.24, 0.07),
    _fill(0xFFFF9F1C),
  );
  canvas.drawPath(
    _star4(const Offset(-0.55, 0.52), 0.17, 0.05),
    _fill(0xFFFF9F1C),
  );
  canvas.drawCircle(Offset.zero, 0.12, _fill(0xFFFFFFFF));
}

void _marshmallow(Canvas canvas) {
  canvas.drawLine(
    const Offset(-0.72, 0.78),
    const Offset(0.1, -0.1),
    _stroke(0xFF8D5A3B, 0.1),
  );
  canvas.save();
  canvas.translate(0.24, -0.26);
  canvas.rotate(math.pi / 4);
  final body = RRect.fromLTRBR(
    -0.3,
    -0.36,
    0.3,
    0.36,
    const Radius.circular(0.14),
  );
  canvas.drawRRect(body, _fill(0xFFFFFBF2));
  canvas.save();
  canvas.clipRRect(body);
  canvas.drawRect(
    const Rect.fromLTRB(-0.4, -0.4, 0.4, -0.1),
    _fill(0xFFE3A35E),
  );
  canvas.drawRect(
    const Rect.fromLTRB(-0.4, -0.12, 0.4, -0.04),
    _fill(0x55E3A35E),
  );
  canvas.restore();
  canvas.drawRRect(body, _stroke(0x22000000, 0.04));
  canvas.restore();
}

void _compass(Canvas canvas) {
  canvas.drawCircle(const Offset(0, -0.8), 0.12, _stroke(0xFFC9962E, 0.07));
  canvas.drawCircle(Offset.zero, 0.74, _fill(0xFFE0B252));
  canvas.drawCircle(Offset.zero, 0.6, _fill(0xFFFFFDF5));
  for (var i = 0; i < 4; i++) {
    final a = i * math.pi / 2;
    final dir = Offset(math.sin(a), -math.cos(a));
    canvas.drawLine(dir * 0.46, dir * 0.56, _stroke(0xFF6B5A3A, 0.06));
  }
  canvas.drawPath(
    _poly(const [Offset(0, -0.48), Offset(0.14, 0), Offset(-0.14, 0)]),
    _fill(0xFFE84A4A),
  );
  canvas.drawPath(
    _poly(const [Offset(0, 0.48), Offset(0.14, 0), Offset(-0.14, 0)]),
    _fill(0xFF4A6FA5),
  );
  canvas.drawCircle(Offset.zero, 0.07, _fill(0xFF2E2E2E));
}

void _mug(Canvas canvas) {
  for (final x in const [-0.22, 0.06]) {
    final steam = Path()
      ..moveTo(x, -0.42)
      ..cubicTo(x - 0.12, -0.55, x + 0.12, -0.65, x, -0.8);
    canvas.drawPath(steam, _stroke(0xCCFFFFFF, 0.07));
  }
  canvas.drawArc(
    const Rect.fromLTRB(0.12, -0.08, 0.62, 0.42),
    -math.pi / 2,
    math.pi,
    false,
    _stroke(0xFF3E7CB1, 0.12),
  );
  canvas.drawRRect(
    RRect.fromLTRBR(-0.48, -0.3, 0.3, 0.62, const Radius.circular(0.14)),
    _fill(0xFF3E7CB1),
  );
  canvas.drawOval(_oval(-0.09, -0.3, 0.78, 0.16), _fill(0xFFEAF2F8));
  canvas.drawOval(_oval(-0.09, -0.29, 0.62, 0.1), _fill(0xFF7A4B2A));
  for (final p in const [
    Offset(-0.3, 0.05),
    Offset(0.1, 0.3),
    Offset(-0.15, 0.4),
  ]) {
    canvas.drawCircle(p, 0.04, _fill(0xCCFFFFFF));
  }
}

void _hikingBoot(Canvas canvas) {
  final boot = Path()
    ..moveTo(-0.36, -0.66)
    ..lineTo(0.16, -0.66)
    ..lineTo(0.2, 0.04)
    ..quadraticBezierTo(0.76, 0.12, 0.78, 0.42)
    ..lineTo(0.78, 0.55)
    ..lineTo(-0.46, 0.55)
    ..lineTo(-0.46, 0.0)
    ..quadraticBezierTo(-0.42, -0.36, -0.36, -0.66)
    ..close();
  canvas.drawPath(boot, _fill(0xFF9C6B3F));
  canvas.drawRRect(
    RRect.fromLTRBR(-0.52, 0.52, 0.84, 0.72, const Radius.circular(0.06)),
    _fill(0xFF3E2C22),
  );
  canvas.drawRect(
    const Rect.fromLTRB(-0.4, -0.78, 0.2, -0.6),
    _fill(0xFFC0392B),
  );
  for (final y in const [-0.42, -0.22, -0.02]) {
    canvas.drawLine(
      Offset(-0.16, y),
      Offset(0.12, y + 0.05),
      _stroke(0xFFFFF1D6, 0.06),
    );
  }
}

void _moon(Canvas canvas) {
  final crescent = Path.combine(
    PathOperation.difference,
    Path()..addOval(
      Rect.fromCircle(center: const Offset(-0.06, 0.04), radius: 0.62),
    ),
    Path()..addOval(
      Rect.fromCircle(center: const Offset(0.26, -0.16), radius: 0.54),
    ),
  );
  canvas.drawPath(crescent, _fill(0xFFFFE27A));
  canvas.drawPath(
    _star4(const Offset(0.5, 0.42), 0.16, 0.05),
    _fill(0xFFFFFFFF),
  );
  canvas.drawPath(
    _star4(const Offset(0.42, -0.62), 0.1, 0.03),
    _fill(0xFFFFFFFF),
  );
  canvas.drawCircle(const Offset(-0.6, -0.6), 0.05, _fill(0xCCFFFFFF));
  canvas.drawCircle(const Offset(0.72, -0.1), 0.04, _fill(0xCCFFFFFF));
}

void _binoculars(Canvas canvas) {
  for (final x in const [-0.62, 0.12]) {
    canvas.drawRRect(
      RRect.fromLTRBR(x, -0.48, x + 0.5, 0.5, const Radius.circular(0.18)),
      _fill(0xFF2F3B45),
    );
  }
  canvas.drawRect(
    const Rect.fromLTRB(-0.14, -0.3, 0.14, -0.04),
    _fill(0xFF56656F),
  );
  for (final x in const [-0.37, 0.37]) {
    canvas.drawCircle(Offset(x, 0.28), 0.2, _fill(0xFF6EC1E4));
    canvas.drawCircle(Offset(x - 0.07, 0.21), 0.06, _fill(0xCCFFFFFF));
  }
}

void _kite(Canvas canvas) {
  const top = Offset(0, -0.8);
  const right = Offset(0.5, -0.24);
  const bottom = Offset(0, 0.36);
  const left = Offset(-0.5, -0.24);
  const mid = Offset(0, -0.24);
  final tail = Path()
    ..moveTo(bottom.dx, bottom.dy)
    ..cubicTo(0.32, 0.55, -0.3, 0.7, 0.12, 0.92);
  canvas.drawPath(tail, _stroke(0xFF2E2E2E, 0.04));
  canvas.drawPath(_poly(const [top, right, mid]), _fill(0xFFFFC93C));
  canvas.drawPath(_poly(const [top, left, mid]), _fill(0xFFE84A4A));
  canvas.drawPath(_poly(const [bottom, right, mid]), _fill(0xFF3E7CB1));
  canvas.drawPath(_poly(const [bottom, left, mid]), _fill(0xFF5DBB63));
  canvas.drawLine(top, bottom, _stroke(0x66000000, 0.03));
  canvas.drawLine(left, right, _stroke(0x66000000, 0.03));
  for (final p in const [Offset(0.12, 0.55), Offset(-0.06, 0.73)]) {
    canvas.drawPath(
      _poly([
        p + const Offset(-0.1, -0.06),
        p + const Offset(0.1, 0.06),
        p + const Offset(-0.1, 0.06),
        p + const Offset(0.1, -0.06),
      ]),
      _fill(0xFFE84A4A),
    );
  }
}

void _mushroom(Canvas canvas) {
  _grass(canvas, 0xFF8FCB78);
  canvas.drawRRect(
    RRect.fromLTRBR(-0.2, -0.02, 0.2, 0.66, const Radius.circular(0.12)),
    _fill(0xFFF6E7CF),
  );
  final cap = Path()
    ..addArc(const Rect.fromLTRB(-0.74, -0.62, 0.74, 0.22), math.pi, math.pi)
    ..close();
  canvas.drawPath(cap, _fill(0xFFE53935));
  canvas.drawCircle(const Offset(-0.36, -0.12), 0.12, _fill(0xFFFFFFFF));
  canvas.drawCircle(const Offset(0.04, -0.38), 0.13, _fill(0xFFFFFFFF));
  canvas.drawCircle(const Offset(0.42, -0.1), 0.09, _fill(0xFFFFFFFF));
}

void _fox(Canvas canvas) {
  const orange = 0xFFE8742A;
  for (final s in const [-1.0, 1.0]) {
    canvas.drawPath(
      _poly([
        Offset(0.62 * s, -0.86),
        Offset(0.2 * s, -0.3),
        Offset(0.66 * s, -0.22),
      ]),
      _fill(orange),
    );
    canvas.drawPath(
      _poly([
        Offset(0.56 * s, -0.66),
        Offset(0.34 * s, -0.36),
        Offset(0.58 * s, -0.32),
      ]),
      _fill(0xFF5A3620),
    );
  }
  final head = Path()
    ..moveTo(-0.68, -0.32)
    ..lineTo(0.68, -0.32)
    ..quadraticBezierTo(0.62, 0.22, 0, 0.62)
    ..quadraticBezierTo(-0.62, 0.22, -0.68, -0.32)
    ..close();
  canvas.drawPath(head, _fill(orange));
  for (final s in const [-1.0, 1.0]) {
    final cheek = Path()
      ..moveTo(0.64 * s, -0.08)
      ..quadraticBezierTo(0.2 * s, 0.0, 0, 0.62)
      ..quadraticBezierTo(0.46 * s, 0.32, 0.64 * s, -0.08)
      ..close();
    canvas.drawPath(cheek, _fill(0xFFFFF6EA));
    canvas.drawOval(_oval(0.26 * s, -0.06, 0.12, 0.16), _fill(0xFF2E2E2E));
  }
  canvas.drawOval(_oval(0, 0.5, 0.18, 0.13), _fill(0xFF2E2E2E));
}

void _owl(Canvas canvas) {
  canvas.drawRect(const Rect.fromLTRB(-0.9, 0.7, 0.9, 0.82), _fill(0xFF7A4B2A));
  for (final s in const [-1.0, 1.0]) {
    canvas.drawPath(
      _poly([
        Offset(0.48 * s, -0.42),
        Offset(0.18 * s, -0.46),
        Offset(0.46 * s, -0.8),
      ]),
      _fill(0xFF6E4630),
    );
  }
  canvas.drawOval(_oval(0, 0.12, 1.1, 1.24), _fill(0xFF8A5A3C));
  canvas.drawOval(_oval(0, 0.38, 0.68, 0.64), _fill(0xFFD9B48F));
  for (final s in const [-1.0, 1.0]) {
    canvas.drawCircle(Offset(0.24 * s, -0.14), 0.21, _fill(0xFFFFFFFF));
    canvas.drawCircle(Offset(0.24 * s, -0.14), 0.21, _stroke(0xFFF2B829, 0.05));
    canvas.drawCircle(Offset(0.24 * s, -0.12), 0.1, _fill(0xFF2E2E2E));
    canvas.drawOval(_oval(0.2 * s, 0.72, 0.16, 0.08), _fill(0xFFFF9F1C));
  }
  canvas.drawPath(
    _poly(const [Offset(-0.08, 0.0), Offset(0.08, 0.0), Offset(0, 0.16)]),
    _fill(0xFFFF9F1C),
  );
}

void _map(Canvas canvas) {
  const xs = [-0.68, -0.23, 0.23, 0.68];
  for (var i = 0; i < 3; i++) {
    final up = i.isEven ? -0.5 : -0.4;
    final down = i.isEven ? 0.4 : 0.5;
    canvas.drawPath(
      _poly([
        Offset(xs[i], i.isEven ? -0.4 : -0.5),
        Offset(xs[i + 1], up),
        Offset(xs[i + 1], down),
        Offset(xs[i], i.isEven ? 0.5 : 0.4),
      ]),
      _fill(i.isOdd ? 0xFFE9D6AE : 0xFFF5E6C4),
    );
  }
  canvas.drawOval(_oval(-0.4, -0.15, 0.32, 0.22), _fill(0xFF8FCB78));
  canvas.drawOval(_oval(0.1, 0.25, 0.24, 0.16), _fill(0xFF8FCB78));
  for (var i = 0; i < 6; i++) {
    final t = i / 6;
    canvas.drawCircle(
      Offset(-0.5 + t * 0.85, 0.3 - t * 0.5 + math.sin(t * math.pi) * 0.12),
      0.035,
      _fill(0xFFE84A4A),
    );
  }
  canvas.drawLine(
    const Offset(0.32, -0.34),
    const Offset(0.5, -0.16),
    _stroke(0xFFE84A4A, 0.07),
  );
  canvas.drawLine(
    const Offset(0.5, -0.34),
    const Offset(0.32, -0.16),
    _stroke(0xFFE84A4A, 0.07),
  );
}

void _canoe(Canvas canvas) {
  canvas.drawRect(const Rect.fromLTRB(-1, 0.34, 1, 1), _fill(0xFF5AB0E0));
  final wave = Path()
    ..moveTo(-1, 0.5)
    ..quadraticBezierTo(-0.5, 0.42, 0, 0.5)
    ..quadraticBezierTo(0.5, 0.58, 1, 0.5);
  canvas.drawPath(wave, _stroke(0x99FFFFFF, 0.05));
  canvas.drawLine(
    const Offset(-0.24, -0.72),
    const Offset(0.3, 0.42),
    _stroke(0xFF8D5A3B, 0.07),
  );
  canvas.save();
  canvas.translate(0.33, 0.5);
  canvas.rotate(-0.44);
  canvas.drawOval(_oval(0, 0, 0.16, 0.34), _fill(0xFF8D5A3B));
  canvas.restore();
  final hull = Path()
    ..moveTo(-0.82, 0.04)
    ..quadraticBezierTo(0, 0.68, 0.82, 0.04)
    ..quadraticBezierTo(0, 0.26, -0.82, 0.04)
    ..close();
  canvas.drawPath(hull, _fill(0xFFC0532E));
  final rim = Path()
    ..moveTo(-0.78, 0.06)
    ..quadraticBezierTo(0, 0.3, 0.78, 0.06);
  canvas.drawPath(rim, _stroke(0xFFF2C38B, 0.05));
}

void _fish(Canvas canvas) {
  canvas.drawCircle(
    const Offset(-0.66, -0.52),
    0.08,
    _stroke(0xCCFFFFFF, 0.04),
  );
  canvas.drawCircle(const Offset(-0.5, -0.72), 0.05, _stroke(0xCCFFFFFF, 0.04));
  const body = 0xFFFF8C42;
  canvas.drawPath(
    _poly(const [Offset(0.3, 0.0), Offset(0.78, -0.38), Offset(0.78, 0.38)]),
    _fill(body),
  );
  canvas.drawPath(
    _poly(const [Offset(-0.2, -0.3), Offset(0.1, -0.56), Offset(0.22, -0.26)]),
    _fill(0xFFE56B1F),
  );
  canvas.drawOval(_oval(-0.1, 0, 1.08, 0.7), _fill(body));
  for (final x in const [0.0, 0.18]) {
    canvas.drawArc(
      Rect.fromCenter(center: Offset(x, 0), width: 0.3, height: 0.56),
      -math.pi / 2,
      math.pi,
      false,
      _stroke(0xFFFFD8B5, 0.05),
    );
  }
  canvas.drawCircle(const Offset(-0.38, -0.08), 0.1, _fill(0xFFFFFFFF));
  canvas.drawCircle(const Offset(-0.4, -0.08), 0.05, _fill(0xFF2E2E2E));
}

void _butterfly(Canvas canvas) {
  for (final s in const [-1.0, 1.0]) {
    canvas.drawOval(_oval(0.34 * s, -0.24, 0.62, 0.72), _fill(0xFF9B59D0));
    canvas.drawOval(_oval(0.27 * s, 0.34, 0.46, 0.5), _fill(0xFFF06292));
    canvas.drawCircle(Offset(0.38 * s, -0.28), 0.1, _fill(0xCCFFFFFF));
    canvas.drawCircle(Offset(0.28 * s, 0.38), 0.07, _fill(0xCCFFFFFF));
    final antenna = Path()
      ..moveTo(0.03 * s, -0.42)
      ..quadraticBezierTo(0.08 * s, -0.66, 0.26 * s, -0.76);
    canvas.drawPath(antenna, _stroke(0xFF2E2E2E, 0.04));
    canvas.drawCircle(Offset(0.26 * s, -0.76), 0.05, _fill(0xFF2E2E2E));
  }
  canvas.drawRRect(
    RRect.fromLTRBR(-0.06, -0.46, 0.06, 0.56, const Radius.circular(0.06)),
    _fill(0xFF2E2E2E),
  );
}

void _rainbow(Canvas canvas) {
  const colors = [0xFFE84A4A, 0xFFFF9F1C, 0xFFFFD43B, 0xFF5DBB63, 0xFF3E7CB1];
  for (var i = 0; i < colors.length; i++) {
    final r = 0.74 - i * 0.12;
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(0, 0.36), radius: r),
      math.pi,
      math.pi,
      false,
      _stroke(colors[i], 0.125)..strokeCap = StrokeCap.butt,
    );
  }
  for (final s in const [-1.0, 1.0]) {
    canvas.drawCircle(Offset(0.6 * s, 0.4), 0.18, _fill(0xFFFFFFFF));
    canvas.drawCircle(Offset(0.42 * s, 0.46), 0.14, _fill(0xFFFFFFFF));
    canvas.drawCircle(Offset(0.76 * s, 0.48), 0.13, _fill(0xFFFFFFFF));
  }
}

void _bearCub(Canvas canvas) {
  const fur = 0xFF8B5A35;
  for (final s in const [-1.0, 1.0]) {
    canvas.drawCircle(Offset(0.48 * s, -0.5), 0.24, _fill(fur));
    canvas.drawCircle(Offset(0.48 * s, -0.5), 0.12, _fill(0xFFD9B48F));
  }
  canvas.drawCircle(const Offset(0, 0.06), 0.62, _fill(fur));
  canvas.drawOval(_oval(0, 0.28, 0.52, 0.38), _fill(0xFFD9B48F));
  canvas.drawOval(_oval(0, 0.18, 0.2, 0.13), _fill(0xFF2E2E2E));
  final mouth = Path()
    ..moveTo(-0.1, 0.34)
    ..quadraticBezierTo(0, 0.42, 0.1, 0.34);
  canvas.drawPath(mouth, _stroke(0xFF2E2E2E, 0.04));
  for (final s in const [-1.0, 1.0]) {
    canvas.drawCircle(Offset(0.22 * s, -0.08), 0.07, _fill(0xFF2E2E2E));
    canvas.drawCircle(Offset(0.38 * s, 0.14), 0.08, _fill(0x55FF7A8A));
  }
}

void _snowflake(Canvas canvas) {
  final arm = _stroke(0xFFFFFFFF, 0.1);
  final twig = _stroke(0xFFFFFFFF, 0.07);
  for (var i = 0; i < 6; i++) {
    canvas.save();
    canvas.rotate(i * math.pi / 3);
    canvas.drawLine(Offset.zero, const Offset(0, -0.74), arm);
    for (final (y, w) in const [(-0.46, 0.2), (-0.24, 0.13)]) {
      canvas.drawLine(Offset(0, y), Offset(-w, y - w * 0.85), twig);
      canvas.drawLine(Offset(0, y), Offset(w, y - w * 0.85), twig);
    }
    canvas.restore();
  }
  canvas.drawCircle(Offset.zero, 0.12, _fill(0xFFFFFFFF));
}

void _leaf(Canvas canvas) {
  final leaf = Path()
    ..moveTo(-0.52, 0.52)
    ..cubicTo(-0.7, -0.2, 0, -0.76, 0.66, -0.66)
    ..cubicTo(0.62, 0.02, 0.1, 0.66, -0.52, 0.52)
    ..close();
  canvas.drawPath(leaf, _fill(0xFFE8742A));
  canvas.drawLine(
    const Offset(-0.52, 0.52),
    const Offset(-0.76, 0.78),
    _stroke(0xFF8D5A3B, 0.07),
  );
  final vein = _stroke(0xFFB4501A, 0.05);
  canvas.drawLine(const Offset(-0.52, 0.52), const Offset(0.5, -0.5), vein);
  for (final t in const [0.3, 0.55, 0.78]) {
    final p = Offset(-0.52 + 1.02 * t, 0.52 - 1.02 * t);
    canvas.drawLine(p, p + const Offset(-0.2, -0.08), vein);
    canvas.drawLine(p, p + const Offset(0.08, 0.2), vein);
  }
}

void _sunflower(Canvas canvas) {
  canvas.drawLine(
    const Offset(0, 0.2),
    const Offset(0, 1),
    _stroke(0xFF3E9A4E, 0.1),
  );
  canvas.drawOval(_oval(0.22, 0.62, 0.36, 0.16), _fill(0xFF3E9A4E));
  canvas.save();
  canvas.translate(0, -0.14);
  for (var i = 0; i < 12; i++) {
    canvas.save();
    canvas.rotate(i * math.pi / 6);
    canvas.drawOval(_oval(0, -0.44, 0.22, 0.38), _fill(0xFFFFC928));
    canvas.restore();
  }
  canvas.drawCircle(Offset.zero, 0.3, _fill(0xFF7A4B2A));
  for (var i = 0; i < 6; i++) {
    final a = i * math.pi / 3;
    canvas.drawCircle(
      Offset(math.cos(a), math.sin(a)) * 0.15,
      0.04,
      _fill(0xFFB07A4A),
    );
  }
  canvas.restore();
}

void _starBadge(Canvas canvas) {
  final star = _star5(const Offset(0, 0.05), 0.78, 0.34);
  canvas.drawPath(star, _fill(0xFFFFC93C));
  canvas.drawPath(star, _stroke(0xFFE09A00, 0.05));
  canvas.drawPath(_star5(const Offset(0, 0.05), 0.4, 0.17), _fill(0xFFFFE38A));
  canvas.drawPath(
    _star4(const Offset(0.62, -0.58), 0.14, 0.04),
    _fill(0xFFFFFFFF),
  );
  canvas.drawPath(
    _star4(const Offset(-0.66, -0.44), 0.09, 0.03),
    _fill(0xFFFFFFFF),
  );
}
