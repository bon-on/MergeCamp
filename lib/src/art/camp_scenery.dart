import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../meta/camp_theme.dart';
import 'art_raster_cache.dart';
import 'camp_palette.dart';

/// Full-bleed forest background for a [CampTheme]: sky, sun or moon, two hill
/// ridges and pine forests along the sides and the bottom.
///
/// The middle of the screen stays calm and low-contrast because the board
/// sits there. With [animate] clouds drift (summer, autumn), snow falls,
/// leaves tumble (autumn) and stars twinkle and fireflies glow (night).
class CampScenery extends StatefulWidget {
  const CampScenery({super.key, required this.theme, this.animate = true});

  final CampTheme theme;
  final bool animate;

  @override
  State<CampScenery> createState() => _CampSceneryState();
}

class _CampSceneryState extends State<CampScenery>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<double> _time = ValueNotifier<double>(0);
  Ticker? _ticker;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(CampScenery oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTicker();
  }

  /// Time already shown before the ticker was last (re)started.
  double _timeBase = 0;

  /// Creates the single ticker lazily and afterwards only starts or stops it,
  /// continuing from the last shown time.
  void _syncTicker() {
    if (widget.animate) {
      final ticker = _ticker ??= createTicker((elapsed) {
        _time.value = _timeBase + elapsed.inMicroseconds / 1e6;
      });
      if (!ticker.isActive) {
        _timeBase = _time.value;
        ticker.start();
      }
    } else if (_ticker?.isActive ?? false) {
      _ticker!.stop();
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = CampPalette.of(widget.theme);
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: CustomPaint(
            painter: _StillPainter(_SkyPainter(palette), 'sky', dpr),
          ),
        ),
        RepaintBoundary(
          child: CustomPaint(painter: _SkyMotionPainter(palette, _time, dpr)),
        ),
        RepaintBoundary(
          child: CustomPaint(
            painter: _StillPainter(_LandPainter(palette), 'land', dpr),
          ),
        ),
        RepaintBoundary(
          child: CustomPaint(painter: _AirPainter(palette, _time)),
        ),
      ],
    );
  }
}

/// Draws a static [inner] painter from an image rasterized once per size,
/// theme and pixel ratio when [ArtRasterCache.enabled] (web), so animating
/// layers above it do not replay hundreds of tree paths every frame.
class _StillPainter extends CustomPainter {
  _StillPainter(this.inner, this.layer, this.devicePixelRatio);

  final CustomPainter inner;
  final String layer;
  final double devicePixelRatio;

  // Two layers; room for a theme switch or a resize without thrashing.
  static final ArtRasterCache _rasters = ArtRasterCache(maxEntries: 4);

  CampTheme get _theme => switch (inner) {
    _SkyPainter(:final palette) => palette.theme,
    _LandPainter(:final palette) => palette.theme,
    _ => CampTheme.summer,
  };

  @override
  void paint(Canvas canvas, Size size) {
    final w = (size.width * devicePixelRatio).ceil();
    final h = (size.height * devicePixelRatio).ceil();
    if (!ArtRasterCache.enabled ||
        w <= 0 ||
        h <= 0 ||
        w > ArtRasterCache.maxSide ||
        h > ArtRasterCache.maxSide) {
      inner.paint(canvas, size);
      return;
    }
    final image = _rasters.image((layer, _theme, w, h), w, h, (c) {
      c.scale(w / size.width, h / size.height);
      inner.paint(c, size);
    });
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.low,
    );
  }

  @override
  bool shouldRepaint(_StillPainter old) =>
      old.inner.shouldRepaint(inner) ||
      old.layer != layer ||
      old.devicePixelRatio != devicePixelRatio;
}

/// Reference length so trees and suns scale on both landscape and portrait.
double _unit(Size size) => math.min(size.width, size.height * 0.9);

/// Deterministic pseudo random values in 0..1.
List<List<double>> _scatter(int seed, int count, int dims) {
  final random = math.Random(seed);
  return List.generate(
    count,
    (_) => List.generate(dims, (_) => random.nextDouble()),
  );
}

final List<List<double>> _starSeeds = _scatter(11, 110, 4);
final List<List<double>> _cloudSeeds = _scatter(23, 6, 4);
final List<List<double>> _snowSeeds = _scatter(37, 90, 4);
final List<List<double>> _leafSeeds = _scatter(41, 22, 5);
final List<List<double>> _fireflySeeds = _scatter(53, 24, 5);
final List<List<double>> _treeSeeds = _scatter(67, 80, 3);

/// Picks an x fraction that prefers the outer bands of the screen.
double _sideBiased(double a, double b) {
  if (b < 0.75) {
    return a < 0.5 ? a * 0.56 : 0.44 + a * 0.56;
  }
  return a;
}

// --------------------------------------------------------------------- sky

class _SkyPainter extends CustomPainter {
  _SkyPainter(this.palette);

  final CampPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [palette.skyTop, palette.skyBottom],
          stops: const [0.0, 0.7],
        ).createShader(rect),
    );
    final u = _unit(size);
    final portrait = size.height > size.width;
    switch (palette.theme) {
      case CampTheme.summer:
        _sun(
          canvas,
          Offset(
            size.width * (portrait ? 0.8 : 0.84),
            size.height * (portrait ? 0.1 : 0.16),
          ),
          u * 0.07,
          const Color(0xFFFFF1A6),
          const Color(0xFFFFF6C8),
        );
      case CampTheme.autumn:
        _sun(
          canvas,
          Offset(
            size.width * (portrait ? 0.22 : 0.16),
            size.height * (portrait ? 0.13 : 0.22),
          ),
          u * 0.085,
          const Color(0xFFFFC874),
          const Color(0xFFFFDDA0),
        );
      case CampTheme.snow:
        _sun(
          canvas,
          Offset(size.width * 0.78, size.height * (portrait ? 0.1 : 0.15)),
          u * 0.06,
          const Color(0xFFFFFCEE),
          const Color(0xFFFFFFFF),
        );
      case CampTheme.night:
        _moon(
          canvas,
          Offset(
            size.width * (portrait ? 0.78 : 0.82),
            size.height * (portrait ? 0.1 : 0.17),
          ),
          u * 0.06,
        );
    }
  }

  void _sun(Canvas canvas, Offset c, double r, Color core, Color halo) {
    canvas.drawCircle(
      c,
      r * 4,
      Paint()
        ..shader = RadialGradient(
          colors: [halo.withValues(alpha: 0.55), halo.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: c, radius: r * 4)),
    );
    canvas.drawCircle(
      c,
      r * 1.35,
      Paint()..color = halo.withValues(alpha: 0.35),
    );
    canvas.drawCircle(c, r, Paint()..color = core);
  }

  void _moon(Canvas canvas, Offset c, double r) {
    canvas.drawCircle(
      c,
      r * 4.5,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF9FB2FF).withValues(alpha: 0.28),
            const Color(0x009FB2FF),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r * 4.5)),
    );
    final disk = Path()..addOval(Rect.fromCircle(center: c, radius: r));
    final bite = Path()
      ..addOval(
        Rect.fromCircle(
          center: c.translate(r * 0.55, -r * 0.3),
          radius: r * 0.9,
        ),
      );
    final crescent = Path.combine(PathOperation.difference, disk, bite);
    canvas.drawPath(crescent, Paint()..color = const Color(0xFFFFF4CF));
    canvas.drawCircle(
      c.translate(-r * 0.5, r * 0.25),
      r * 0.12,
      Paint()..color = const Color(0xFFE9DDB0),
    );
  }

  @override
  bool shouldRepaint(_SkyPainter old) => old.palette != palette;
}

class _SkyMotionPainter extends CustomPainter {
  _SkyMotionPainter(this.palette, this.time, [this.devicePixelRatio = 1])
    : super(repaint: time);

  final CampPalette palette;
  final ValueNotifier<double> time;
  final double devicePixelRatio;

  /// Cloud sprites (one per cloud size, theme and pixel ratio): a moving
  /// cloud path would otherwise be rasterized again on every frame.
  static final ArtRasterCache _cloudSprites = ArtRasterCache(maxEntries: 16);

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    if (palette.theme == CampTheme.night) {
      _stars(canvas, size, t);
      _clouds(canvas, size, t, const Color(0xFF4B5C93), 0.22, 2);
      return;
    }
    final (color, alpha, count) = switch (palette.theme) {
      CampTheme.summer => (const Color(0xFFFFFFFF), 0.92, 4),
      CampTheme.autumn => (const Color(0xFFFFF3E2), 0.85, 3),
      _ => (const Color(0xFFF7FAFF), 0.9, 3),
    };
    _clouds(canvas, size, t, color, alpha, count);
  }

  void _stars(Canvas canvas, Size size, double t) {
    final paint = Paint();
    for (final s in _starSeeds) {
      final x = s[0] * size.width;
      final y = math.pow(s[1], 1.4) * size.height * 0.62;
      final twinkle =
          0.55 + 0.45 * math.sin(t * (0.8 + s[3] * 2.2) + s[2] * 20);
      final r = 0.6 + s[2] * 1.4;
      paint.color = const Color(
        0xFFFFF8E1,
      ).withValues(alpha: 0.35 + 0.6 * twinkle * (0.4 + s[2] * 0.6));
      canvas.drawCircle(Offset(x, y), r, paint);
      if (s[2] > 0.85) {
        final arm = r * 3 * twinkle;
        final cross = Paint()
          ..color = paint.color.withValues(alpha: 0.5 * twinkle)
          ..strokeWidth = 0.8;
        canvas.drawLine(Offset(x - arm, y), Offset(x + arm, y), cross);
        canvas.drawLine(Offset(x, y - arm), Offset(x, y + arm), cross);
      }
    }
  }

  void _clouds(
    Canvas canvas,
    Size size,
    double t,
    Color color,
    double alpha,
    int count,
  ) {
    final u = _unit(size);
    final body = Paint()..color = color.withValues(alpha: alpha);
    final shade = Paint()
      ..color = Color.lerp(
        color,
        palette.skyTop,
        0.35,
      )!.withValues(alpha: alpha);
    for (var i = 0; i < count; i++) {
      final s = _cloudSeeds[i];
      final scale = u * (0.035 + s[2] * 0.03);
      final cw = scale * 4.6;
      final speed = 4 + s[3] * 8;
      final span = size.width + cw * 2;
      final x = ((i + s[0] * 0.6) / count * span + t * speed) % span - cw;
      final y = size.height * (0.05 + ((i * 0.618 + s[1] * 0.2) % 1.0) * 0.24);
      _spriteCloud(canvas, Offset(x, y), scale, body, shade);
    }
  }

  /// Cloud bounds relative to its anchor, in multiples of the cloud scale.
  static const Rect _cloudBox = Rect.fromLTRB(-0.1, -2.1, 4.5, 0.8);

  void _spriteCloud(
    Canvas canvas,
    Offset o,
    double k,
    Paint body,
    Paint shade,
  ) {
    final box = Rect.fromLTRB(
      _cloudBox.left * k,
      _cloudBox.top * k,
      _cloudBox.right * k,
      _cloudBox.bottom * k,
    );
    final w = (box.width * devicePixelRatio).ceil();
    final h = (box.height * devicePixelRatio).ceil();
    if (!ArtRasterCache.enabled ||
        w <= 0 ||
        h <= 0 ||
        w > ArtRasterCache.maxSide ||
        h > ArtRasterCache.maxSide) {
      _cloud(canvas, o, k, body, shade);
      return;
    }
    final image = _cloudSprites.image(
      (palette.theme, k, body.color, shade.color, devicePixelRatio),
      w,
      h,
      (c) {
        c.scale(w / box.width, h / box.height);
        c.translate(-box.left, -box.top);
        _cloud(c, Offset.zero, k, body, shade);
      },
    );
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      box.shift(o),
      Paint()..filterQuality = FilterQuality.low,
    );
  }

  void _cloud(Canvas canvas, Offset o, double k, Paint body, Paint shade) {
    final base = RRect.fromLTRBR(
      o.dx,
      o.dy - k * 0.55,
      o.dx + k * 4.4,
      o.dy + k * 0.5,
      Radius.circular(k * 0.5),
    );
    final puffs = Path()
      ..addRRect(base)
      ..addOval(
        Rect.fromCircle(
          center: o.translate(k * 1.2, -k * 0.5),
          radius: k * 0.85,
        ),
      )
      ..addOval(
        Rect.fromCircle(
          center: o.translate(k * 2.4, -k * 0.85),
          radius: k * 1.15,
        ),
      )
      ..addOval(
        Rect.fromCircle(
          center: o.translate(k * 3.4, -k * 0.35),
          radius: k * 0.75,
        ),
      );
    canvas.save();
    canvas.translate(0, k * 0.18);
    canvas.drawPath(puffs, shade);
    canvas.restore();
    canvas.drawPath(puffs, body);
  }

  @override
  bool shouldRepaint(_SkyMotionPainter old) =>
      old.palette != palette ||
      old.time != time ||
      old.devicePixelRatio != devicePixelRatio;
}

// -------------------------------------------------------------------- land

class _LandPainter extends CustomPainter {
  _LandPainter(this.palette);

  final CampPalette palette;

  bool get _snow => palette.theme == CampTheme.snow;
  bool get _autumn => palette.theme == CampTheme.autumn;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final u = _unit(size);
    final portrait = h > w;

    // Far ridge with a row of tiny pines.
    final farY = h * (portrait ? 0.56 : 0.6);
    double farRidge(double x) =>
        farY -
        u *
            0.05 *
            (math.sin(x / w * 2 * math.pi * 1.2 + 0.6) * 0.7 +
                math.sin(x / w * 2 * math.pi * 3.3 + 1.9) * 0.3);
    final farColor = Color.lerp(palette.hillFar, palette.hillNear, 0.45)!;
    for (var x = -u * 0.02; x < w + u * 0.04; x += u * 0.026) {
      final jitter = math.sin(x * 12.9898) * 0.5 + 0.5;
      final th = u * (0.035 + 0.03 * jitter);
      _pineShape(
        canvas,
        Offset(x, farRidge(x) + th * 0.25),
        th,
        farColor,
        farColor,
        snowCap: false,
        layers: 2,
      );
    }
    _ridge(canvas, size, farRidge, palette.hillFar);

    // Near ridge.
    final nearY = h * (portrait ? 0.7 : 0.76);
    double nearRidge(double x) =>
        nearY -
        u *
            0.045 *
            (math.sin(x / w * 2 * math.pi * 0.9 + 2.4) * 0.65 +
                math.sin(x / w * 2 * math.pi * 2.2 + 0.3) * 0.35);
    _ridge(canvas, size, nearRidge, palette.hillNear);
    if (_snow) {
      // Soft snow sparkle band on the near ridge.
      _ridge(
        canvas,
        size,
        (x) => nearRidge(x) + u * 0.012,
        const Color(0xFFE3EDF6),
      );
    }

    // Back forest row: low in the middle, tall at the sides.
    final backColor = Color.lerp(palette.treeLight, palette.hillNear, 0.35)!;
    final backShade = Color.lerp(palette.treeDark, palette.hillNear, 0.35)!;
    _forestRow(
      canvas,
      size,
      seedOffset: 0,
      baseY: (x) => nearRidge(x) + u * 0.06,
      spacing: u * 0.05,
      minH: u * 0.07,
      maxH: u * 0.42,
      lit: backColor,
      shade: backShade,
    );
    // Front row along the bottom edge.
    _forestRow(
      canvas,
      size,
      seedOffset: 40,
      baseY: (x) => h + u * 0.04,
      spacing: u * 0.075,
      minH: u * 0.1,
      maxH: u * 0.62,
      lit: palette.treeLight,
      shade: palette.treeDark,
      calmCenter: true,
    );

    // Gentle vignette keeps the eye on the board. The gradient is laid on a
    // square around the screen so portrait and landscape fade the same way.
    final rect = Offset.zero & size;
    final diagonal = math.sqrt(w * w + h * h);
    final tone = Color.lerp(palette.treeDark, const Color(0xFF000000), 0.4)!;
    canvas.drawRect(
      rect,
      Paint()
        ..shader =
            RadialGradient(
              radius: 0.5,
              colors: [
                tone.withValues(alpha: 0),
                tone.withValues(
                  alpha: palette.theme == CampTheme.night ? 0.4 : 0.22,
                ),
              ],
              stops: const [0.55, 1],
            ).createShader(
              Rect.fromCenter(
                center: rect.center,
                width: diagonal,
                height: diagonal,
              ),
            ),
    );
  }

  void _ridge(
    Canvas canvas,
    Size size,
    double Function(double) y,
    Color color,
  ) {
    final p = Path()..moveTo(0, size.height);
    final step = size.width / 48;
    for (var x = 0.0; x <= size.width + step; x += step) {
      p.lineTo(x, y(x));
    }
    p
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(p, Paint()..color = color);
    final rim = Path()..moveTo(0, y(0));
    for (var x = step; x <= size.width + step; x += step) {
      rim.lineTo(x, y(x));
    }
    canvas.drawPath(
      rim,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.5, _unit(size) * 0.004)
        ..color = Color.lerp(
          color,
          const Color(0xFFFFFFFF),
          0.25,
        )!.withValues(alpha: 0.6),
    );
  }

  void _forestRow(
    Canvas canvas,
    Size size, {
    required int seedOffset,
    required double Function(double) baseY,
    required double spacing,
    required double minH,
    required double maxH,
    required Color lit,
    required Color shade,
    bool calmCenter = false,
  }) {
    final w = size.width;
    final trees = <(double, double, double, int)>[];
    var i = 0;
    for (var x = -spacing * 0.5; x < w + spacing; x += spacing) {
      final s = _treeSeeds[(i + seedOffset) % _treeSeeds.length];
      i++;
      final tx = x + (s[0] - 0.5) * spacing * 0.8;
      final edge = ((tx - w / 2).abs() / (w / 2)).clamp(0.0, 1.0);
      final grow = math.pow(edge, calmCenter ? 2.4 : 1.8).toDouble();
      var th = minH + (maxH - minH) * grow * (0.75 + s[1] * 0.4);
      if (calmCenter && edge < 0.35) th *= 0.75;
      trees.add((
        tx,
        baseY(tx) + s[2] * spacing * 0.3,
        th,
        (s[1] * 10).floor(),
      ));
    }
    // Shorter trees in front of taller ones looks better: draw tall first.
    trees.sort((a, b) => b.$3.compareTo(a.$3));
    for (final (x, y, th, kind) in trees) {
      if (_autumn && kind % 2 == 0) {
        _roundTree(canvas, Offset(x, y), th * 0.8, kind);
      } else {
        _pineShape(
          canvas,
          Offset(x, y),
          th,
          lit,
          shade,
          snowCap: _snow,
          layers: 4,
        );
      }
    }
  }

  void _pineShape(
    Canvas canvas,
    Offset base,
    double h,
    Color lit,
    Color shade, {
    required bool snowCap,
    required int layers,
  }) {
    final trunkW = h * 0.07;
    canvas.drawRect(
      Rect.fromLTWH(base.dx - trunkW / 2, base.dy - h * 0.16, trunkW, h * 0.16),
      Paint()..color = Color.lerp(shade, const Color(0xFF3A2416), 0.5)!,
    );
    final shadowPaint = Paint()
      ..color = Color.lerp(shade, const Color(0xFF000000), 0.25)!;
    final litPaint = Paint()..color = lit;
    final shadePaint = Paint()..color = shade;
    final snowPaint = Paint()..color = const Color(0xFFF5F9FF);
    final tops = layers == 4 ? const [1.0, 0.8, 0.6, 0.42] : const [1.0, 0.62];
    final bottoms = layers == 4
        ? const [0.6, 0.41, 0.24, 0.1]
        : const [0.42, 0.1];
    final halves = layers == 4
        ? const [0.12, 0.165, 0.205, 0.24]
        : const [0.15, 0.24];
    // Bottom layer first so each upper layer overlaps (and shades) the next.
    for (var i = layers - 1; i >= 0; i--) {
      final top = base.dy - h * tops[i];
      final bottom = base.dy - h * bottoms[i];
      final half = h * halves[i];
      final droop = h * 0.03;
      Path halfPath(double dir) => Path()
        ..moveTo(base.dx, top)
        ..lineTo(base.dx + half * dir, bottom)
        ..quadraticBezierTo(
          base.dx + half * 0.5 * dir,
          bottom + droop,
          base.dx,
          bottom + droop * 0.5,
        )
        ..close();
      final left = halfPath(-1);
      final right = halfPath(1);
      if (i < layers - 1) {
        canvas.save();
        canvas.translate(0, h * 0.028);
        canvas.drawPath(left, shadowPaint);
        canvas.drawPath(right, shadowPaint);
        canvas.restore();
      }
      canvas.drawPath(left, shadePaint);
      canvas.drawPath(right, litPaint);
      if (snowCap) {
        // Snow rests on the part of the layer that peeks out below the layer
        // above it (the whole tip for the top layer).
        final visibleTop = i == 0 ? top : base.dy - h * bottoms[i - 1];
        final depth = (bottom - top) * (i == 0 ? 0.42 : 0.2);
        final scallop = depth * 0.35;
        final snowBand = Path()
          ..moveTo(base.dx - half * 1.2, visibleTop - h)
          ..lineTo(base.dx + half * 1.2, visibleTop - h)
          ..lineTo(base.dx + half * 1.2, visibleTop + depth);
        const bumps = 4;
        for (var b = bumps; b > 0; b--) {
          final x0 = base.dx - half * 1.2 + half * 2.4 * b / bumps;
          final x1 = base.dx - half * 1.2 + half * 2.4 * (b - 1) / bumps;
          snowBand.quadraticBezierTo(
            (x0 + x1) / 2,
            visibleTop + depth + scallop * (b.isEven ? 1 : -0.4),
            x1,
            visibleTop + depth,
          );
        }
        snowBand.close();
        canvas.save();
        canvas.clipPath(Path.combine(PathOperation.union, left, right));
        canvas.drawPath(snowBand, snowPaint);
        canvas.restore();
      }
    }
  }

  void _roundTree(Canvas canvas, Offset base, double h, int kind) {
    const leaves = [
      (Color(0xFFE5793A), Color(0xFFC95F2B)),
      (Color(0xFFE9B04A), Color(0xFFCC8E32)),
      (Color(0xFFCF4F3A), Color(0xFFA93C2E)),
    ];
    final (lit, shade) = leaves[(kind ~/ 2) % leaves.length];
    final trunk = Paint()..color = const Color(0xFF5E3B26);
    canvas.drawRect(
      Rect.fromLTWH(base.dx - h * 0.04, base.dy - h * 0.4, h * 0.08, h * 0.4),
      trunk,
    );
    final r = h * 0.26;
    final c = base.translate(0, -h * 0.62);
    final shadePaint = Paint()..color = shade;
    final litPaint = Paint()..color = lit;
    canvas.drawCircle(c.translate(-r * 0.6, r * 0.3), r * 0.85, shadePaint);
    canvas.drawCircle(c.translate(r * 0.62, r * 0.32), r * 0.8, litPaint);
    canvas.drawCircle(c.translate(0, -r * 0.35), r, litPaint);
    canvas.drawCircle(
      c.translate(-r * 0.3, -r * 0.5),
      r * 0.45,
      Paint()..color = Color.lerp(lit, const Color(0xFFFFFFFF), 0.18)!,
    );
  }

  @override
  bool shouldRepaint(_LandPainter old) => old.palette != palette;
}

// --------------------------------------------------------------------- air

class _AirPainter extends CustomPainter {
  _AirPainter(this.palette, this.time) : super(repaint: time);

  final CampPalette palette;
  final ValueNotifier<double> time;

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    switch (palette.theme) {
      case CampTheme.summer:
        _motes(canvas, size, t);
      case CampTheme.autumn:
        _leaves(canvas, size, t);
      case CampTheme.snow:
        _snowfall(canvas, size, t);
      case CampTheme.night:
        _fireflies(canvas, size, t);
    }
  }

  /// Slow pollen motes near the trees.
  void _motes(Canvas canvas, Size size, double t) {
    final paint = Paint();
    for (var i = 0; i < 12; i++) {
      final s = _fireflySeeds[i];
      final x =
          _sideBiased(s[0], 0.1) * size.width +
          math.sin(t * 0.4 + s[3] * 9) * 14;
      final y =
          size.height * (0.55 + s[1] * 0.4) + math.cos(t * 0.3 + s[4] * 7) * 10;
      paint.color = const Color(
        0xFFFFFBE0,
      ).withValues(alpha: 0.35 + 0.3 * math.sin(t + s[2] * 6).abs());
      canvas.drawCircle(Offset(x, y), 1.4 + s[2] * 1.2, paint);
    }
  }

  void _leaves(Canvas canvas, Size size, double t) {
    const colors = [Color(0xFFE5793A), Color(0xFFE9B04A), Color(0xFFCF4F3A)];
    final u = _unit(size);
    for (var i = 0; i < _leafSeeds.length; i++) {
      final s = _leafSeeds[i];
      final speed = 18 + s[2] * 22;
      final span = size.height + 40;
      final y = (s[1] * span + t * speed) % span - 20;
      final x =
          _sideBiased(s[0], s[4]) * size.width +
          math.sin(t * (0.6 + s[3]) + i) * 22;
      final len = u * (0.012 + s[3] * 0.008);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(t * (0.8 + s[2] * 1.6) + i);
      final leaf = Path()
        ..moveTo(-len, 0)
        ..quadraticBezierTo(0, -len * 0.7, len, 0)
        ..quadraticBezierTo(0, len * 0.7, -len, 0)
        ..close();
      canvas.drawPath(
        leaf,
        Paint()..color = colors[i % colors.length].withValues(alpha: 0.9),
      );
      canvas.restore();
    }
  }

  void _snowfall(Canvas canvas, Size size, double t) {
    final paint = Paint();
    for (final s in _snowSeeds) {
      final speed = 16 + s[2] * 34;
      final span = size.height + 12;
      final y = (s[1] * span + t * speed) % span - 6;
      final x = s[0] * size.width + math.sin(t * (0.5 + s[3]) + s[0] * 30) * 10;
      paint.color = const Color(
        0xFFFFFFFF,
      ).withValues(alpha: 0.55 + s[3] * 0.4);
      canvas.drawCircle(Offset(x, y), 1 + s[2] * 2.2, paint);
    }
  }

  void _fireflies(Canvas canvas, Size size, double t) {
    final u = _unit(size);
    for (final s in _fireflySeeds) {
      final x =
          _sideBiased(s[0], s[4] * 0.9) * size.width +
          math.sin(t * (0.3 + s[2] * 0.4) + s[3] * 12) * u * 0.04;
      final y =
          size.height * (0.6 + s[1] * 0.36) +
          math.cos(t * (0.25 + s[3] * 0.3) + s[2] * 9) * u * 0.025;
      final pulse = math
          .pow(0.5 + 0.5 * math.sin(t * (1.2 + s[4]) + s[0] * 20), 2)
          .toDouble();
      final c = Offset(x, y);
      final r = u * 0.018;
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFFFF09A).withValues(alpha: 0.55 * pulse),
              const Color(0x00FFF09A),
            ],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
      canvas.drawCircle(
        c,
        1.6,
        Paint()
          ..color = const Color(
            0xFFFFF7C2,
          ).withValues(alpha: 0.3 + 0.7 * pulse),
      );
    }
  }

  @override
  bool shouldRepaint(_AirPainter old) =>
      old.palette != palette || old.time != time;
}
