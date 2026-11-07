import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../meta/camp_theme.dart';
import 'art_raster_cache.dart';
import 'camp_palette.dart';

/// A complete camp tile: rounded card in the tier color, a flat vector
/// illustration of the camp and a small tier badge.
///
/// The widget fills the (square) box it is given. Tiers above [maxArtTier]
/// draw the last illustration, tiers below 1 draw the first one.
class CampTileArt extends StatefulWidget {
  const CampTileArt({
    super.key,
    required this.tier,
    this.theme = CampTheme.summer,
    this.animate = true,
    this.silhouette = false,
    this.showBadge = true,
  });

  /// Number of distinct illustrations.
  static const int maxArtTier = 8;

  /// Camp tier; clamped to 1..[maxArtTier] for drawing.
  final int tier;

  /// Theme of the ground patch and roof details (snow caps, night glow).
  final CampTheme theme;

  /// Runs the small loop animation (flame, smoke, flags, stars) when the tier
  /// has one. Turn off for tests and reduced motion.
  final bool animate;

  /// Draws an undiscovered camp: muted card and a flat dark shape.
  final bool silhouette;

  /// Shows the tier number badge in the top-left corner.
  final bool showBadge;

  @override
  State<CampTileArt> createState() => _CampTileArtState();
}

/// Tiers whose illustration has motion.
const Set<int> _animatedTiers = {2, 4, 5, 7, 8};

/// One loop of every tile animation. All motion uses whole cycles per loop.
const Duration _loopDuration = Duration(milliseconds: 2400);

class _CampTileArtState extends State<CampTileArt>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  int get _artTier => widget.tier.clamp(1, CampTileArt.maxArtTier);

  bool get _wantsMotion =>
      widget.animate && !widget.silhouette && _animatedTiers.contains(_artTier);

  @override
  void initState() {
    super.initState();
    _syncController();
  }

  @override
  void didUpdateWidget(CampTileArt oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncController();
  }

  /// Creates the single controller lazily the first time motion is wanted
  /// and afterwards only starts or stops it.
  void _syncController() {
    if (_wantsMotion) {
      final controller = _controller ??= AnimationController(
        vsync: this,
        duration: _loopDuration,
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
    return RepaintBoundary(
      child: CustomPaint(
        painter: _CampTilePainter(
          tier: _artTier,
          palette: CampPalette.of(widget.theme),
          silhouette: widget.silhouette,
          showBadge: widget.showBadge,
          animation: _wantsMotion ? _controller : null,
          devicePixelRatio: MediaQuery.maybeDevicePixelRatioOf(context) ?? 1,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _CampTilePainter extends CustomPainter {
  _CampTilePainter({
    required this.tier,
    required this.palette,
    required this.silhouette,
    required this.showBadge,
    required this.animation,
    required this.devicePixelRatio,
  }) : super(repaint: animation);

  final int tier;
  final CampPalette palette;
  final bool silhouette;
  final bool showBadge;
  final Animation<double>? animation;
  final double devicePixelRatio;

  /// Rasterized still tiles (see [ArtRasterCache]); a board, the next
  /// pieces and the effect copies use only a handful of sizes.
  static final ArtRasterCache _rasters = ArtRasterCache(maxEntries: 64);

  static const Color _silhouetteFace = Color(0xFFBAC4C2);
  static const Color _silhouetteShape = Color(0xFF55636A);

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    if (s <= 0) return;
    final px = (s * devicePixelRatio).ceil();
    final cache = ArtRasterCache.enabled && px <= ArtRasterCache.maxSide;
    final dst = Rect.fromLTWH(
      (size.width - s) / 2,
      (size.height - s) / 2,
      s,
      s,
    );
    final src = Rect.fromLTWH(0, 0, px.toDouble(), px.toDouble());
    final imagePaint = Paint()..filterQuality = FilterQuality.medium;
    if (cache && animation == null) {
      // Still tiles: rasterize once, then draw the image every frame.
      final image = _rasters.image(
        (tier, palette.theme, silhouette, showBadge, px),
        px,
        px,
        (c) {
          c.scale(px / s);
          _paintTile(c, s, 0);
        },
      );
      canvas.drawImageRect(image, src, dst, imagePaint);
      return;
    }
    canvas.save();
    canvas.translate(dst.left, dst.top);
    if (cache) {
      // Looping tiles: the card (gradients, glow, bevel) never moves, so
      // only the illustration and the badge are drawn as vectors.
      final card = _rasters.image(
        ('card', tier, palette.theme, silhouette, px),
        px,
        px,
        (c) {
          c.scale(px / s);
          _paintCard(c, s, _baseColor);
        },
      );
      canvas.drawImageRect(card, src, Offset.zero & Size(s, s), imagePaint);
    }
    _paintTile(canvas, s, animation?.value ?? 0.0, card: !cache);
    canvas.restore();
  }

  Color get _baseColor =>
      silhouette ? _silhouetteFace : palette.tierColor(tier);

  /// The whole tile in an [s] x [s] square at the origin; [card] false
  /// leaves out the card behind the illustration (drawn from the cache).
  void _paintTile(Canvas canvas, double s, double phase, {bool card = true}) {
    final base = _baseColor;
    if (card) _paintCard(canvas, s, base);

    final art = Rect.fromLTWH(s * 0.07, s * 0.05, s * 0.86, s * 0.86);
    if (silhouette) {
      canvas.saveLayer(
        Rect.fromLTWH(0, 0, s, s),
        Paint()
          ..colorFilter = const ColorFilter.mode(
            _silhouetteShape,
            BlendMode.srcIn,
          ),
      );
    }
    canvas.save();
    canvas.translate(art.left, art.top);
    canvas.scale(art.width / 100);
    _Illustration(
      canvas: canvas,
      palette: palette,
      phase: phase,
      flat: silhouette,
    ).paint(tier);
    canvas.restore();
    if (silhouette) canvas.restore();

    if (showBadge) _paintBadge(canvas, s, base);
  }

  void _paintCard(Canvas canvas, double s, Color base) {
    final radius = Radius.circular(s * 0.2);
    final lipColor = _shade(base, 0.28);
    final full = RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, s, s), radius);
    canvas.drawRRect(full, Paint()..color = lipColor);

    final faceRect = Rect.fromLTWH(0, 0, s, s * 0.94);
    final face = RRect.fromRectAndRadius(faceRect, radius);
    canvas.drawRRect(
      face,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_tint(base, 0.32), base, _shade(base, 0.06)],
          stops: const [0, 0.6, 1],
        ).createShader(faceRect),
    );
    // Soft spotlight behind the illustration.
    final glowCenter = Offset(s * 0.5, s * 0.5);
    canvas.drawCircle(
      glowCenter,
      s * 0.46,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFFFFF).withValues(alpha: tier == 8 ? 0.16 : 0.34),
            const Color(0x00FFFFFF),
          ],
        ).createShader(Rect.fromCircle(center: glowCenter, radius: s * 0.46)),
    );
    if (tier == 8 && !silhouette) _paintNightSpecks(canvas, s);
    // Bevel highlight along the top edge.
    canvas.drawRRect(
      face.deflate(s * 0.015),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, s * 0.02)
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFFFFFFF).withValues(alpha: 0.55),
            const Color(0x00FFFFFF),
          ],
          stops: const [0, 0.5],
        ).createShader(faceRect),
    );
    if (tier == CampTileArt.maxArtTier && !silhouette) {
      // The top camp gets a gold rim so it stands out on dark boards too.
      canvas.drawRRect(
        full.deflate(s * 0.012),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.2, s * 0.024)
          ..color = const Color(0xFFFFCF6B),
      );
    }
  }

  void _paintNightSpecks(Canvas canvas, double s) {
    final paint = Paint()..color = const Color(0x66FFFFFF);
    const specks = [
      Offset(0.32, 0.12),
      Offset(0.58, 0.09),
      Offset(0.9, 0.42),
      Offset(0.12, 0.5),
      Offset(0.44, 0.24),
      Offset(0.7, 0.33),
    ];
    for (final p in specks) {
      canvas.drawCircle(Offset(p.dx * s, p.dy * s), s * 0.008, paint);
    }
  }

  void _paintBadge(Canvas canvas, double s, Color base) {
    final r = s * 0.11;
    final center = Offset(s * 0.16, s * 0.16);
    canvas.drawCircle(
      center.translate(0, s * 0.012),
      r,
      Paint()..color = _shade(base, 0.35).withValues(alpha: 0.55),
    );
    canvas.drawCircle(center, r, Paint()..color = const Color(0xFFFFFBF2));
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, s * 0.018)
        ..color = _shade(base, 0.3),
    );
    final label = silhouette ? '?' : '$tier';
    final text = _badgeText(
      label,
      silhouette ? _silhouetteShape : _shade(base, 0.55),
      r * 1.25,
    );
    text.paint(
      canvas,
      center - Offset(text.width / 2, text.height / 2 - s * 0.003),
    );
  }

  /// Laid-out badge labels, shared by all tiles. Animated tiles repaint every
  /// frame, so building a TextPainter per paint would be wasteful. The cache
  /// is small (labels x tile sizes) and reset if it ever grows.
  static final Map<String, TextPainter> _badgeCache = <String, TextPainter>{};

  static TextPainter _badgeText(String label, Color color, double fontSize) {
    final size = (fontSize * 2).roundToDouble() / 2;
    final key = '$label|${color.toARGB32()}|$size';
    final cached = _badgeCache[key];
    if (cached != null) return cached;
    if (_badgeCache.length >= 96) {
      for (final painter in _badgeCache.values) {
        painter.dispose();
      }
      _badgeCache.clear();
    }
    return _badgeCache[key] = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: color,
          fontSize: size,
          height: 1,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  @override
  bool shouldRepaint(_CampTilePainter old) =>
      old.tier != tier ||
      old.palette != palette ||
      old.silhouette != silhouette ||
      old.showBadge != showBadge ||
      old.animation != animation ||
      old.devicePixelRatio != devicePixelRatio;
}

Color _tint(Color c, double t) => Color.lerp(c, const Color(0xFFFFFFFF), t)!;

Color _shade(Color c, double t) => Color.lerp(c, const Color(0xFF1C1410), t)!;

/// Paints one camp illustration in a 100 x 100 unit square.
///
/// Style: flat shapes, two or three tones per object, one warm dark outline
/// and a ground patch under every camp.
class _Illustration {
  _Illustration({
    required this.canvas,
    required this.palette,
    required this.phase,
    required this.flat,
  });

  final Canvas canvas;
  final CampPalette palette;

  /// Animation loop position in 0..1.
  final double phase;

  /// Silhouette mode: skip glows and translucent effects.
  final bool flat;

  static const Color ink = Color(0xFF3D2A20);
  static const double line = 2.4;

  bool get _snow => palette.theme == CampTheme.snow;
  bool get _night => palette.theme == CampTheme.night;

  /// Wave in -1..1 that completes [cycles] whole cycles per loop.
  double wave(int cycles, [double offset = 0]) =>
      math.sin((phase * cycles + offset) * 2 * math.pi);

  void paint(int tier) {
    switch (tier) {
      case 1:
        _tent();
      case 2:
        _cookFire();
      case 3:
        _supplyShed();
      case 4:
        _scoutCabin();
      case 5:
        _signalTower();
      case 6:
        _baseLodge();
      case 7:
        _summitCamp();
      default:
        _observatory();
    }
  }

  // ---------------------------------------------------------------- helpers

  Paint _fill(Color c) => Paint()
    ..color = c
    ..isAntiAlias = true;

  Paint _stroke(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  void shape(Path p, Color fill, {double outline = line}) {
    canvas.drawPath(p, _fill(fill));
    if (outline > 0) canvas.drawPath(p, _stroke(ink, outline));
  }

  /// Draws [shade] clipped to [clip], for a second tone inside a shape.
  void shadeInside(Path clip, Path shade, Color color) {
    canvas.save();
    canvas.clipPath(clip);
    canvas.drawPath(shade, _fill(color));
    canvas.restore();
  }

  Path poly(List<double> xy, {bool close = true}) {
    final p = Path()..moveTo(xy[0], xy[1]);
    for (var i = 2; i < xy.length; i += 2) {
      p.lineTo(xy[i], xy[i + 1]);
    }
    if (close) p.close();
    return p;
  }

  Path rrect(double l, double t, double r, double b, double radius) =>
      Path()..addRRect(RRect.fromLTRBR(l, t, r, b, Radius.circular(radius)));

  void segment(double x1, double y1, double x2, double y2, Color c, double w) {
    canvas.drawLine(Offset(x1, y1), Offset(x2, y2), _stroke(c, w));
  }

  void ground({double cx = 50, double cy = 86, double rx = 42, double ry = 9}) {
    final oval = Path()
      ..addOval(
        Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2),
      );
    canvas.drawPath(oval, _fill(_shade(palette.groundPatch, 0.18)));
    final top = Path()
      ..addOval(
        Rect.fromCenter(
          center: Offset(cx, cy - 1.6),
          width: rx * 2 - 3,
          height: ry * 2 - 3.5,
        ),
      );
    canvas.drawPath(top, _fill(palette.groundPatch));
    final light = Path()
      ..addOval(
        Rect.fromCenter(
          center: Offset(cx - rx * 0.25, cy - ry * 0.45),
          width: rx * 0.9,
          height: ry * 0.7,
        ),
      );
    canvas.drawPath(light, _fill(palette.groundPatchLight));
    if (!_snow) {
      _tuft(cx - rx * 0.82, cy - 0.5);
      _tuft(cx + rx * 0.78, cy + 1);
    }
  }

  void _tuft(double x, double y) {
    final c = _shade(palette.groundPatch, 0.3);
    segment(x, y, x - 1.6, y - 4, c, 1.6);
    segment(x, y, x + 0.4, y - 5, c, 1.6);
    segment(x, y, x + 2.2, y - 3.6, c, 1.6);
  }

  /// White snow band along a roof ridge line (snow theme only).
  void snowLine(List<double> xy, {double width = 4.2}) {
    if (!_snow) return;
    final p = poly(xy, close: false);
    canvas.drawPath(p, _stroke(const Color(0xFF9DB6CC), width + 1.6));
    canvas.drawPath(p, _stroke(const Color(0xFFFFFFFF), width));
  }

  /// Warm window glow halo (skipped in silhouette mode).
  void glow(Offset c, double r, Color color, {double alpha = 0.5}) {
    if (flat) return;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: alpha),
            color.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  void window(double l, double t, double r, double b, {bool cross = true}) {
    final lit = _night ? const Color(0xFFFFD86B) : const Color(0xFFFFE6A0);
    if (_night) {
      glow(
        Offset((l + r) / 2, (t + b) / 2),
        (r - l) * 1.3,
        const Color(0xFFFFC94D),
      );
    }
    final p = rrect(l, t, r, b, 1.2);
    shape(p, lit, outline: 2);
    shadeInside(
      p,
      poly([l, b, r, t + (b - t) * 0.35, r, b]),
      const Color(0xFFF7C35C),
    );
    if (cross) {
      segment((l + r) / 2, t + 0.8, (l + r) / 2, b - 0.8, ink, 1.4);
      segment(l + 0.8, (t + b) / 2, r - 0.8, (t + b) / 2, ink, 1.4);
    }
  }

  /// Small waving flag; [x],[y] is the top of the pole.
  void flag(double x, double y, double len, double h, Color color) {
    final w1 = wave(2) * 1.6;
    final w2 = wave(2, 0.3) * 2.2;
    final p = Path()
      ..moveTo(x, y)
      ..cubicTo(
        x + len * 0.35,
        y - 1.5 + w1,
        x + len * 0.65,
        y + 1.5 - w1,
        x + len,
        y + 1 + w2,
      )
      ..lineTo(x + len, y + h + 1 + w2 * 0.8)
      ..cubicTo(
        x + len * 0.65,
        y + h + 1.5 - w1,
        x + len * 0.35,
        y + h - 1.5 + w1,
        x,
        y + h,
      )
      ..close();
    shape(p, color, outline: 2);
    shadeInside(
      p,
      Path()..addRect(Rect.fromLTWH(x, y + h * 0.55, len + 2, h)),
      _shade(color, 0.16),
    );
  }

  void pole(double x, double top, double bottom) {
    segment(x, bottom, x, top, ink, 3.2);
    segment(x, bottom, x, top, const Color(0xFFB98A5C), 1.4);
    canvas.drawCircle(
      Offset(x, top - 0.8),
      1.8,
      _fill(const Color(0xFFFFD166)),
    );
  }

  void star(Offset c, double r, Color color) {
    final p = Path()..moveTo(c.dx, c.dy - r);
    final k = r * 0.28;
    p
      ..quadraticBezierTo(c.dx + k, c.dy - k, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx + k, c.dy + k, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx - k, c.dy + k, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx - k, c.dy - k, c.dx, c.dy - r)
      ..close();
    canvas.drawPath(p, _fill(color));
  }

  // ------------------------------------------------------------ 1 Trail Tent

  void _tent() {
    ground();
    // Guy ropes and stakes.
    segment(30, 56, 12, 85, ink.withValues(alpha: 0.6), 1.2);
    segment(80, 46, 92, 84, ink.withValues(alpha: 0.6), 1.2);
    segment(12, 85, 12, 81, ink, 2.2);
    segment(92, 84, 92, 80, ink, 2.2);
    // Side panel (shaded) and front face.
    final side = poly([46, 30, 80, 38, 90, 84, 62, 86]);
    shape(side, const Color(0xFFD9653D));
    shadeInside(
      side,
      poly([46, 30, 80, 38, 82, 46, 50, 40]),
      const Color(0xFFE77B4C),
    );
    final front = poly([18, 86, 46, 30, 62, 86]);
    shape(front, const Color(0xFFF6904F));
    shadeInside(front, poly([46, 30, 62, 86, 52, 86]), const Color(0xFFE37A44));
    // Door opening with a rolled-up flap.
    final door = poly([45, 50, 33, 86, 55, 86]);
    shape(door, const Color(0xFF5B3424), outline: 2);
    shadeInside(door, poly([45, 50, 40, 86, 33, 86]), const Color(0xFF7A4630));
    segment(45, 50, 57, 84, const Color(0xFFFFD9A8), 1.6);
    // Bottom trim stripe.
    segment(19, 86, 33, 86, const Color(0xFFFFE3B8), 1.4);
    snowLine([46, 30, 80, 38]);
    snowLine([20, 84, 46, 31], width: 3);
    // Little pennant on the ridge pole.
    pole(46, 16, 30);
    flag(46, 16, 12, 7, const Color(0xFFFFD166));
  }

  // ------------------------------------------------------------- 2 Cook Fire

  void _cookFire() {
    ground(cy: 85);
    final flick = flat ? 0.0 : wave(3);
    final flick2 = flat ? 0.0 : wave(5, 0.25);
    glow(
      const Offset(50, 64),
      40 + flick * 2,
      const Color(0xFFFF9A3C),
      alpha: 0.55,
    );

    // Back stones.
    for (final x in [30.0, 42.0, 58.0, 70.0]) {
      _stone(x, 74, 7, 4.5);
    }
    // Crossed logs.
    _log(50, 75, 50, 9.5, -0.3);
    _log(50, 75, 50, 9.5, 0.3);
    // Flame layers.
    final sway = flick * 1.4;
    final stretch = 1 + flick2 * 0.05;
    _flame(50, 78, 32, 50 * stretch, sway * 1.4, const Color(0xFFF04E37));
    _flame(50, 78, 23, 36 * stretch, sway, const Color(0xFFFF9C1F), outline: 0);
    _flame(
      50,
      78,
      13,
      21 * (1 + flick * 0.06),
      sway * 0.6,
      const Color(0xFFFFE36B),
      outline: 0,
    );
    // Sparks.
    if (!flat) {
      for (var i = 0; i < 3; i++) {
        final t = (phase * 2 + i / 3) % 1.0;
        final x = 50 + (i - 1) * 9 + math.sin((t + i) * 2 * math.pi) * 2.5;
        final y = 32 - t * 22;
        canvas.drawCircle(
          Offset(x, y),
          1.5 * (1 - t) + 0.4,
          _fill(const Color(0xFFFFD45A).withValues(alpha: 1 - t)),
        );
      }
    }
    // Front stones.
    for (final x in [24.0, 37.0, 50.0, 63.0, 76.0]) {
      _stone(x, 86 - (x - 50).abs() * 0.14, 6.6, 4.2);
    }
  }

  void _stone(double cx, double cy, double rx, double ry) {
    final p = Path()
      ..addOval(
        Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2),
      );
    shape(p, const Color(0xFF9AA0A8), outline: 2);
    shadeInside(
      p,
      Path()..addOval(
        Rect.fromCenter(
          center: Offset(cx - 1.5, cy - 1.6),
          width: rx * 1.3,
          height: ry,
        ),
      ),
      const Color(0xFFC3C8CE),
    );
    if (_snow) {
      shadeInside(
        p,
        Path()..addRect(Rect.fromLTWH(cx - rx, cy - ry, rx * 2, ry * 0.7)),
        const Color(0xFFFFFFFF),
      );
    }
  }

  void _log(double cx, double cy, double len, double h, double angle) {
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(angle);
    final body = rrect(-len / 2, -h / 2, len / 2, h / 2, h / 2);
    shape(body, const Color(0xFFA0623A));
    shadeInside(
      body,
      Path()..addRect(Rect.fromLTWH(-len / 2, h * 0.1, len, h)),
      const Color(0xFF7F4A2B),
    );
    segment(
      -len * 0.2,
      -h * 0.15,
      len * 0.15,
      -h * 0.15,
      const Color(0xFFC48455),
      1.3,
    );
    final endCap = Path()
      ..addOval(
        Rect.fromCenter(
          center: Offset(len / 2 - h * 0.35, 0),
          width: h * 0.75,
          height: h,
        ),
      );
    shape(endCap, const Color(0xFFE8BB82), outline: 1.8);
    canvas.drawCircle(
      Offset(len / 2 - h * 0.35, 0),
      h * 0.16,
      _fill(const Color(0xFFB9824E)),
    );
    canvas.restore();
  }

  void _flame(
    double cx,
    double baseY,
    double w,
    double h,
    double sway,
    Color color, {
    double outline = line,
  }) {
    final tipX = cx + sway;
    final tipY = baseY - h;
    final half = w / 2;
    final p = Path()
      ..moveTo(tipX, tipY)
      ..cubicTo(
        cx + half * 0.25 + sway * 0.6,
        baseY - h * 0.62,
        cx + half * 1.08,
        baseY - h * 0.48,
        cx + half * 0.98,
        baseY - h * 0.2,
      )
      ..cubicTo(
        cx + half * 0.9,
        baseY + h * 0.04,
        cx + half * 0.35,
        baseY + 2,
        cx,
        baseY + 2,
      )
      ..cubicTo(
        cx - half * 0.35,
        baseY + 2,
        cx - half * 0.9,
        baseY + h * 0.04,
        cx - half * 0.98,
        baseY - h * 0.2,
      )
      ..cubicTo(
        cx - half * 1.05,
        baseY - h * 0.4,
        cx - half * 0.55,
        baseY - h * 0.5,
        cx - half * 0.35 + sway * 0.3,
        baseY - h * 0.66,
      )
      ..cubicTo(
        cx - half * 0.1 + sway * 0.4,
        baseY - h * 0.5,
        cx - half * 0.05 + sway,
        baseY - h * 0.82,
        tipX,
        tipY,
      )
      ..close();
    shape(p, color, outline: outline);
  }

  // ----------------------------------------------------------- 3 Supply Shed

  void _supplyShed() {
    ground();
    const wood = Color(0xFFCB8C4E);
    const woodDark = Color(0xFFB0743C);
    // Body: pentagon gable end.
    final body = poly([20, 86, 20, 50, 44, 30, 68, 50, 68, 86]);
    shape(body, wood);
    shadeInside(body, poly([56, 20, 80, 20, 80, 90, 56, 90]), woodDark);
    for (final x in [28.0, 36.0, 52.0, 60.0]) {
      segment(
        x,
        50 - (44 - (x - 44).abs()) * 0 + 0,
        x,
        85,
        const Color(0xFF9A6234),
        1.1,
      );
    }
    // Door with Z brace.
    final door = rrect(34, 58, 54, 86, 1.5);
    shape(door, const Color(0xFF8C5530));
    segment(36, 62, 52, 62, const Color(0xFFBF8550), 2.2);
    segment(36, 82, 52, 82, const Color(0xFFBF8550), 2.2);
    segment(36, 81, 52, 63, const Color(0xFFBF8550), 2.2);
    canvas.drawCircle(
      const Offset(50, 72),
      1.4,
      _fill(const Color(0xFFFFD166)),
    );
    // Round gable window.
    final win = Path()
      ..addOval(Rect.fromCircle(center: const Offset(44, 45), radius: 4.6));
    shape(win, const Color(0xFFFFE6A0), outline: 2);
    segment(44, 40.8, 44, 49.2, ink, 1.2);
    // Roof band.
    final roof = poly([14, 53, 44, 25, 74, 53, 68, 57, 44, 35, 20, 57]);
    shape(roof, const Color(0xFFD9534F));
    shadeInside(
      roof,
      poly([44, 25, 74, 53, 68, 57, 44, 35]),
      const Color(0xFFB8413E),
    );
    snowLine([15, 52, 44, 25.5, 73, 52], width: 4.6);
    // Barrel.
    final barrel = rrect(8, 64, 22, 87, 4);
    shape(barrel, const Color(0xFFB7743F));
    shadeInside(
      barrel,
      Path()..addRect(const Rect.fromLTWH(16, 60, 10, 30)),
      const Color(0xFF975C30),
    );
    segment(8.5, 70, 21.5, 70, const Color(0xFF6E7378), 2);
    segment(8.5, 81, 21.5, 81, const Color(0xFF6E7378), 2);
    // Crates.
    _crate(68, 68, 18);
    _crate(71, 53, 13);
  }

  void _crate(double l, double t, double size) {
    final p = rrect(l, t, l + size, t + size, 1.2);
    shape(p, const Color(0xFFE4B36F));
    shadeInside(
      p,
      Path()..addRect(Rect.fromLTWH(l, t + size * 0.62, size, size)),
      const Color(0xFFCB9656),
    );
    final inset = size * 0.16;
    const plank = Color(0xFFB27C40);
    segment(
      l + inset,
      t + inset,
      l + size - inset,
      t + size - inset,
      plank,
      1.8,
    );
    segment(
      l + size - inset,
      t + inset,
      l + inset,
      t + size - inset,
      plank,
      1.8,
    );
    canvas.drawPath(
      rrect(l + 1.2, t + 1.2, l + size - 1.2, t + size - 1.2, 0.8),
      _stroke(plank, 1.2),
    );
    if (_snow) snowLine([l + 1, t + 0.6, l + size - 1, t + 0.6], width: 2.6);
  }

  // ----------------------------------------------------------- 4 Scout Cabin

  void _scoutCabin() {
    ground();
    // Chimney smoke.
    if (!flat) {
      for (var i = 0; i < 3; i++) {
        final t = (phase + i / 3) % 1.0;
        final r = 3 + t * 4.5;
        canvas.drawCircle(
          Offset(70 + t * 7 + math.sin(t * 2 * math.pi) * 1.5, 18 - t * 16),
          r,
          _fill(const Color(0xFFF4F1EC).withValues(alpha: 0.85 * (1 - t))),
        );
      }
    }
    // Chimney.
    final chimney = rrect(63, 20, 75, 46, 1.2);
    shape(chimney, const Color(0xFF98A0A8));
    shadeInside(
      chimney,
      Path()..addRect(const Rect.fromLTWH(70, 18, 6, 30)),
      const Color(0xFF7D858D),
    );
    segment(64, 27, 74, 27, const Color(0xFF6C737A), 1.1);
    segment(64, 34, 74, 34, const Color(0xFF6C737A), 1.1);
    final cap = rrect(61.5, 18, 76.5, 22, 1);
    shape(cap, const Color(0xFF6C737A), outline: 1.8);
    snowLine([62, 18.4, 76, 18.4], width: 2.6);

    // Log wall.
    final wall = rrect(18, 50, 82, 87, 2);
    shape(wall, const Color(0xFFB9763F));
    const logs = [Color(0xFFC98447), Color(0xFFAE6C38)];
    canvas.save();
    canvas.clipPath(wall);
    for (var i = 0; i < 6; i++) {
      final y = 50 + i * 6.2;
      canvas.drawRect(Rect.fromLTWH(18, y, 64, 6.2), _fill(logs[i % 2]));
      segment(18, y, 82, y, const Color(0xFF8A5530), 1);
    }
    canvas.restore();
    canvas.drawPath(wall, _stroke(ink, line));
    // Log ends on both corners.
    for (var i = 0; i < 6; i++) {
      final y = 53.1 + i * 6.2;
      for (final x in [18.0, 82.0]) {
        final end = Path()
          ..addOval(Rect.fromCircle(center: Offset(x, y), radius: 3));
        shape(end, const Color(0xFFE6B47C), outline: 1.4);
      }
    }
    // Window and door.
    window(26, 58, 42, 72);
    final door = rrect(54, 60, 68, 87, 1.5);
    shape(door, const Color(0xFF7A4528));
    segment(61, 62, 61, 85, const Color(0xFF9B5C35), 1.2);
    canvas.drawCircle(
      const Offset(65, 74),
      1.3,
      _fill(const Color(0xFFFFD166)),
    );
    // Roof.
    final roof = poly([10, 54, 26, 30, 74, 30, 90, 54]);
    shape(roof, const Color(0xFF3F8F5C));
    shadeInside(
      roof,
      poly([10, 54, 90, 54, 86, 48, 14, 48]),
      const Color(0xFF2F7449),
    );
    for (final y in [38.0, 46.0]) {
      final inset = (y - 30) * (16 / 24);
      segment(
        26 - inset + 2,
        y,
        74 + inset - 2,
        y,
        const Color(0xFF5CAE76),
        1.4,
      );
    }
    snowLine([26, 30.5, 74, 30.5], width: 5);
    snowLine([11, 53, 26, 31], width: 3);
    snowLine([74, 31, 89, 53], width: 3);
  }

  // ---------------------------------------------------------- 5 Signal Tower

  void _signalTower() {
    ground(rx: 36);
    const leg = Color(0xFF9A5F34);
    const brace = Color(0xFFB57744);
    // Legs (outlined by drawing ink first).
    for (final pts in [
      [38.0, 44.0, 28.0, 86.0],
      [62.0, 44.0, 72.0, 86.0],
    ]) {
      segment(pts[0], pts[1], pts[2], pts[3], ink, 7);
      segment(pts[0], pts[1], pts[2], pts[3], leg, 4);
    }
    // Cross braces.
    for (final b in [
      [36.5, 52.0, 66.0, 68.0],
      [64.0, 52.0, 33.5, 68.0],
      [33.5, 68.0, 70.0, 84.0],
      [66.5, 68.0, 30.0, 84.0],
    ]) {
      segment(b[0], b[1], b[2], b[3], ink, 4.6);
      segment(b[0], b[1], b[2], b[3], brace, 2.2);
    }
    // Ladder rungs feel: horizontal tie.
    segment(33.5, 68, 66.5, 68, ink, 4.6);
    segment(33.5, 68, 66.5, 68, brace, 2.2);
    // Platform.
    final deck = rrect(24, 41, 76, 48, 1.5);
    shape(deck, const Color(0xFFCF8D4F));
    shadeInside(
      deck,
      Path()..addRect(const Rect.fromLTWH(24, 45, 52, 4)),
      const Color(0xFFAE7140),
    );
    // Lookout hut.
    final hut = rrect(31, 25, 69, 42, 1.5);
    shape(hut, const Color(0xFFE9B56E));
    shadeInside(
      hut,
      Path()..addRect(const Rect.fromLTWH(58, 24, 12, 20)),
      const Color(0xFFD29C58),
    );
    final opening = rrect(36, 28.5, 64, 35.5, 1);
    shape(opening, const Color(0xFF5B3424), outline: 1.6);
    if (_night) glow(const Offset(50, 32), 16, const Color(0xFFFFC94D));
    segment(45, 29, 45, 35, const Color(0xFFE9B56E), 1.6);
    segment(55, 29, 55, 35, const Color(0xFFE9B56E), 1.6);
    // Roof.
    final roof = poly([26, 27, 50, 11, 74, 27]);
    shape(roof, const Color(0xFFD9534F));
    shadeInside(roof, poly([50, 11, 74, 27, 50, 27]), const Color(0xFFB8413E));
    snowLine([27, 26, 50, 11.5, 73, 26], width: 3.6);
    // Flag on top.
    pole(50, 0, 11);
    flag(50, 1, 17, 9, const Color(0xFF3FA2DB));
  }

  // ------------------------------------------------------------ 6 Base Lodge

  void _baseLodge() {
    ground(rx: 46, cy: 87);
    const wall = Color(0xFFC98A4D);
    const wallDark = Color(0xFFAE733D);
    const roofColor = Color(0xFFB4483E);
    const roofDark = Color(0xFF953A33);
    // Wings.
    for (final left in [true, false]) {
      final l = left ? 6.0 : 64.0;
      final body = rrect(l, 58, l + 30, 87, 1.5);
      shape(body, left ? wall : wallDark);
      window(l + 7, 65, l + 19, 75);
      final r = left
          ? poly([2, 61, 10, 50, 40, 50, 40, 61])
          : poly([60, 61, 60, 50, 90, 50, 98, 61]);
      shape(r, left ? roofColor : roofDark);
      snowLine(left ? [10, 50.5, 38, 50.5] : [62, 50.5, 90, 50.5], width: 3.6);
    }
    // Central A-frame.
    final aRoof = poly([24, 88, 50, 18, 76, 88]);
    shape(aRoof, roofColor);
    shadeInside(aRoof, poly([50, 18, 76, 88, 50, 88]), roofDark);
    final gable = poly([33, 88, 50, 40, 67, 88]);
    shape(gable, const Color(0xFFE2AE6E), outline: 2);
    // Big lit triangular window.
    final glass = poly([39, 76, 50, 48, 61, 76]);
    if (_night) {
      glow(const Offset(50, 66), 24, const Color(0xFFFFC94D), alpha: 0.6);
    }
    shape(
      glass,
      _night ? const Color(0xFFFFD86B) : const Color(0xFFFFE6A0),
      outline: 2,
    );
    shadeInside(glass, poly([50, 48, 61, 76, 50, 76]), const Color(0xFFF7C35C));
    segment(50, 49, 50, 76, ink, 1.4);
    segment(43.5, 65, 56.5, 65, ink, 1.4);
    // Door and steps.
    final door = rrect(45, 78, 55, 88, 1.2);
    shape(door, const Color(0xFF6E3E24), outline: 1.8);
    final step = rrect(41, 87, 59, 90, 1);
    shape(step, const Color(0xFFA0A6AD), outline: 1.6);
    snowLine([25, 86, 50, 19, 75, 86], width: 3.6);
    // Lantern posts.
    for (final x in [18.0, 82.0]) {
      if (_night) glow(Offset(x, 82), 8, const Color(0xFFFFC94D), alpha: 0.7);
    }
  }

  // ----------------------------------------------------------- 7 Summit Camp

  void _summitCamp() {
    ground(rx: 46);
    // Back peak.
    final back = poly([54, 86, 76, 36, 98, 86]);
    shape(back, const Color(0xFF6E78A6));
    shadeInside(back, poly([76, 36, 98, 86, 80, 86]), const Color(0xFF5C6593));
    shape(
      poly([76, 36, 82.5, 51, 78, 48, 74, 52, 70.5, 49.5]),
      const Color(0xFFF2F6FF),
      outline: 1.8,
    );
    // Main peak.
    final main = poly([4, 86, 42, 18, 80, 86]);
    shape(main, const Color(0xFFA2ABD1));
    shadeInside(
      main,
      poly([42, 18, 80, 86, 56, 86, 50, 64, 54, 50]),
      const Color(0xFF8189B8),
    );
    final cap = poly([
      42,
      18,
      54.5,
      40.5,
      49,
      37,
      44,
      43,
      39,
      37,
      33.5,
      39,
      30.5,
      39.5,
    ]);
    shape(cap, const Color(0xFFF6F9FF), outline: 2);
    shadeInside(
      cap,
      poly([42, 18, 54.5, 40.5, 49, 37, 44, 30]),
      const Color(0xFFD9E2F5),
    );
    // Summit flag.
    pole(42, 4, 19);
    flag(42, 4, 15, 8, const Color(0xFFE5484D));
    // Camp at the foot.
    _miniTent(10, 86, 22, const Color(0xFFF6904F));
    _miniTent(66, 87, 18, const Color(0xFFFFC94D));
    _pine(32, 87, 16);
  }

  void _miniTent(double l, double b, double w, Color color) {
    final h = w * 0.8;
    final p = poly([l, b, l + w / 2, b - h, l + w, b]);
    shape(p, color, outline: 2);
    shadeInside(
      p,
      poly([l + w / 2, b - h, l + w, b, l + w / 2, b]),
      _shade(color, 0.14),
    );
    shape(
      poly([l + w / 2, b - h * 0.48, l + w * 0.36, b, l + w * 0.64, b]),
      const Color(0xFF5B3424),
      outline: 1.6,
    );
    if (_night) {
      glow(
        Offset(l + w / 2, b - 2),
        w * 0.55,
        const Color(0xFFFFC94D),
        alpha: 0.6,
      );
    }
  }

  void _pine(double cx, double b, double h) {
    segment(cx, b, cx, b - h * 0.25, const Color(0xFF6B4329), 3);
    final w = h * 0.62;
    for (var i = 0; i < 3; i++) {
      final top = b - h + i * h * 0.24;
      final bottom = b - h * 0.18 - (2 - i) * h * 0.16;
      final ww = w * (0.55 + i * 0.22);
      final p = poly([cx, top, cx + ww / 2, bottom, cx - ww / 2, bottom]);
      shape(p, const Color(0xFF3E8B5C), outline: 1.8);
      shadeInside(
        p,
        poly([cx, top, cx + ww / 2, bottom, cx, bottom]),
        const Color(0xFF2F7049),
      );
    }
    if (_snow) {
      snowLine([
        cx - 2,
        b - h + 3,
        cx,
        b - h + 0.5,
        cx + 2,
        b - h + 3,
      ], width: 2.4);
    }
  }

  // ------------------------------------------------------ 8 Star Observatory

  void _observatory() {
    ground(rx: 40);
    // Twinkling stars around the dome.
    const stars = [
      (Offset(80, 12), 5.0, 0.0),
      (Offset(92, 34), 3.4, 0.35),
      (Offset(30, 18), 3.0, 0.6),
      (Offset(10, 44), 3.6, 0.15),
      (Offset(66, 4), 2.4, 0.8),
    ];
    for (final (c, r, off) in stars) {
      final tw = flat ? 1.0 : 0.75 + 0.25 * wave(2, off);
      if (!flat) glow(c, r * 2.4 * tw, const Color(0xFFFFE27A), alpha: 0.45);
      star(c, r * tw, const Color(0xFFFFE27A));
    }
    // Telescope (behind the dome edge).
    canvas.save();
    canvas.translate(56, 46);
    canvas.rotate(-0.72);
    final tube = rrect(0, -4.5, 30, 4.5, 2);
    shape(tube, const Color(0xFFE7B94E));
    shadeInside(
      tube,
      Path()..addRect(const Rect.fromLTWH(0, 1, 30, 4)),
      const Color(0xFFC79733),
    );
    final lens = rrect(26, -6, 32, 6, 1.5);
    shape(lens, const Color(0xFFC79733), outline: 2);
    canvas.restore();
    // Dome.
    final dome = Path()
      ..moveTo(22, 58)
      ..arcToPoint(const Offset(78, 58), radius: const Radius.circular(28))
      ..close();
    shape(dome, const Color(0xFFC3D0EE));
    shadeInside(
      dome,
      Path()..addRect(const Rect.fromLTWH(56, 20, 30, 40)),
      const Color(0xFF9FB0DA),
    );
    shadeInside(
      dome,
      Path()..addOval(const Rect.fromLTWH(28, 34, 16, 12)),
      const Color(0xFFE8EEFB),
    );
    // Dome ribs and open slit.
    canvas.save();
    canvas.clipPath(dome);
    segment(36, 58, 42, 31, const Color(0xFF8E9FCB), 1.2);
    segment(64, 58, 60, 31, const Color(0xFF7E8FBE), 1.2);
    canvas.restore();
    final slit = poly([47, 31, 55, 31.5, 57.5, 58, 46, 58]);
    shape(slit, const Color(0xFF263064), outline: 1.8);
    snowLine([24, 52, 30, 40, 40, 33, 50, 30.5, 60, 31.5], width: 3.4);
    // Drum building.
    final drum = rrect(24, 56, 76, 87, 2);
    shape(drum, const Color(0xFFEDE6D6));
    shadeInside(
      drum,
      Path()..addRect(const Rect.fromLTWH(60, 54, 18, 36)),
      const Color(0xFFD3CAB5),
    );
    final band = rrect(20, 55, 80, 61, 2);
    shape(band, const Color(0xFF8A6FC7), outline: 2);
    // Arched door and round window.
    final door = Path()
      ..moveTo(44, 87)
      ..lineTo(44, 74)
      ..arcToPoint(const Offset(56, 74), radius: const Radius.circular(6))
      ..lineTo(56, 87)
      ..close();
    shape(door, const Color(0xFF5B3E8C), outline: 2);
    if (_night) glow(const Offset(33, 71), 9, const Color(0xFFFFC94D));
    final win = Path()
      ..addOval(Rect.fromCircle(center: const Offset(33, 71), radius: 4));
    shape(win, const Color(0xFFFFE6A0), outline: 1.8);
    final win2 = Path()
      ..addOval(Rect.fromCircle(center: const Offset(67, 71), radius: 4));
    shape(win2, const Color(0xFFF7C35C), outline: 1.8);
  }
}
