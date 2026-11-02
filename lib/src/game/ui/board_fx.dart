import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../art/camp_palette.dart';
import '../../art/camp_tile_art.dart';
import '../../meta/camp_theme.dart';
import '../merge_camp_controller.dart';

/// Cell geometry of the 4x4 board inside a square of [side] pixels.
class BoardGeometry {
  const BoardGeometry({required this.side, required this.gap});

  final double side;
  final double gap;

  double get cell => (side - gap * (columns - 1)) / columns;

  static const int columns = MergeCampController.boardWidth;

  Rect cellRect(int index) {
    final col = index % columns;
    final row = index ~/ columns;
    return Rect.fromLTWH(col * (cell + gap), row * (cell + gap), cell, cell);
  }
}

/// Timing of the merge presentation. Rules apply instantly; these effects
/// only trail behind the real board state.
class FxTiming {
  static const Duration drop = Duration(milliseconds: 180);
  static const Duration firstFlight = Duration(milliseconds: 110);
  static const Duration stagger = Duration(milliseconds: 220);
  static const Duration flight = Duration(milliseconds: 200);
  static const Duration pop = Duration(milliseconds: 260);
  static const Duration particles = Duration(milliseconds: 650);
  static const Duration popup = Duration(milliseconds: 950);
  static const Duration removal = Duration(milliseconds: 360);

  /// When the absorbed tiles of merge [chainIndex] (1-based) start flying.
  static Duration flightStart(int chainIndex) =>
      firstFlight + stagger * (chainIndex - 1);

  /// When the absorbed tiles of merge [chainIndex] land in the origin.
  static Duration impact(int chainIndex) => flightStart(chainIndex) + flight;
}

abstract class _FxEvent {
  Duration? start;

  /// Random seed for this event's particles.
  int seed = 0;
  Duration get length;

  /// Cell the event paints a tile over (the real cell hides meanwhile).
  int? get coverCell => null;

  /// Whether the cover / ghost part of the event is still running.
  bool coverActive(Duration t) => false;
}

class _PlaceEvent extends _FxEvent {
  _PlaceEvent(this.index, this.placedTier, this.steps);

  final int index;
  final int placedTier;
  final List<MergeStep> steps;

  // Set when a later placement interrupts this one: only particles and
  // popups keep playing.
  bool coverCancelled = false;

  Duration get coverLength => steps.isEmpty
      ? FxTiming.drop
      : FxTiming.impact(steps.last.chainIndex) + FxTiming.pop;

  @override
  Duration get length => steps.isEmpty
      ? FxTiming.drop
      : FxTiming.impact(steps.last.chainIndex) + FxTiming.popup;

  @override
  int? get coverCell => index;

  @override
  bool coverActive(Duration t) => !coverCancelled && t < coverLength;
}

class _RemoveEvent extends _FxEvent {
  _RemoveEvent(this.index, this.tier);

  final int index;
  final int tier;

  @override
  Duration get length => FxTiming.removal + const Duration(milliseconds: 200);
}

/// Queue of board effects. The screen pushes events; [BoardFxLayer] plays
/// them and [hiddenCells] tells the board which real cells are covered by an
/// animated copy for the moment.
class BoardFx extends ChangeNotifier {
  final List<_FxEvent> _events = <_FxEvent>[];
  final ValueNotifier<Set<int>> hiddenCells = ValueNotifier<Set<int>>(
    const <int>{},
  );
  int _seed = 1;

  /// Effect clock. It belongs to the queue, not to the layer, so a layer
  /// that is rebuilt from scratch (shake, layout switch) continues the same
  /// timeline instead of restarting at zero under already started events.
  Duration _clock = Duration.zero;

  bool get isActive => _events.isNotEmpty;

  /// A tile was placed at [index]; [steps] are its merges (may be empty).
  void addPlacement(int index, int placedTier, List<MergeStep> steps) {
    _cancelCovers();
    _events.add(_PlaceEvent(index, placedTier, steps));
    _syncHidden();
    notifyListeners();
  }

  /// The Trail Axe cleared [tier] from [index].
  void addRemoval(int index, int tier) {
    _cancelCovers();
    _events.add(_RemoveEvent(index, tier));
    _syncHidden();
    notifyListeners();
  }

  void clear() {
    _events.clear();
    _syncHidden();
    notifyListeners();
  }

  @override
  void dispose() {
    hiddenCells.dispose();
    super.dispose();
  }

  /// Stamps new events with the current clock and a particle seed.
  void _stampNew() {
    for (final event in _events) {
      if (event.start == null) {
        event.start = _clock;
        event.seed = _seed++;
      }
    }
  }

  void _cancelCovers() {
    for (final event in _events) {
      if (event is _PlaceEvent) event.coverCancelled = true;
    }
  }

  /// Drops finished events; returns whether anything is left.
  bool _prune(Duration now) {
    _events.removeWhere((e) => e.start != null && now - e.start! >= e.length);
    _syncHidden(now);
    return _events.isNotEmpty;
  }

  void _syncHidden([Duration? now]) {
    final hidden = <int>{
      for (final e in _events)
        if (e.coverCell != null &&
            (e.start == null || now == null || e.coverActive(now - e.start!)))
          if (e is! _PlaceEvent || !e.coverCancelled) e.coverCell!,
    };
    if (!_sameSet(hidden, hiddenCells.value)) {
      hiddenCells.value = hidden;
    }
  }

  static bool _sameSet(Set<int> a, Set<int> b) =>
      a.length == b.length && a.containsAll(b);
}

/// Paints [BoardFx] events over the board. Only this layer rebuilds per
/// frame, and only while effects are running. Never takes pointer input.
class BoardFxLayer extends StatefulWidget {
  const BoardFxLayer({
    super.key,
    required this.fx,
    required this.geometry,
    required this.theme,
  });

  final BoardFx fx;
  final BoardGeometry geometry;
  final CampTheme theme;

  @override
  State<BoardFxLayer> createState() => _BoardFxLayerState();
}

class _BoardFxLayerState extends State<BoardFxLayer>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);

  // fx clock value when the ticker last started (its elapsed restarts at 0).
  Duration _base = Duration.zero;

  @override
  void initState() {
    super.initState();
    widget.fx.addListener(_onFxChanged);
    _onFxChanged();
  }

  @override
  void didUpdateWidget(BoardFxLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fx != widget.fx) {
      oldWidget.fx.removeListener(_onFxChanged);
      widget.fx.addListener(_onFxChanged);
      _onFxChanged();
    }
  }

  @override
  void dispose() {
    widget.fx.removeListener(_onFxChanged);
    _ticker.dispose();
    super.dispose();
  }

  void _onFxChanged() {
    final fx = widget.fx;
    fx._stampNew();
    if (fx.isActive && !_ticker.isActive) {
      _base = fx._clock;
      _ticker.start();
    } else if (!fx.isActive && _ticker.isActive) {
      _ticker.stop();
    }
    if (mounted) setState(() {});
  }

  void _onTick(Duration elapsed) {
    final fx = widget.fx;
    fx._clock = _base + elapsed;
    if (!fx._prune(fx._clock)) _ticker.stop();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final events = widget.fx._events;
    if (events.isEmpty) return const SizedBox.expand();
    final g = widget.geometry;
    final palette = CampPalette.of(widget.theme);
    final tiles = <Widget>[];
    final sparks = <_Spark>[];
    final popups = <Widget>[];

    for (final event in events) {
      final now = widget.fx._clock;
      final t = now - (event.start ?? now);
      final seed = event.seed;
      if (event is _PlaceEvent) {
        _buildPlace(event, t, seed, g, palette, tiles, sparks, popups);
      } else if (event is _RemoveEvent) {
        _buildRemove(event, t, seed, g, tiles, sparks);
      }
    }

    return IgnorePointer(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ...tiles,
          Positioned.fill(child: CustomPaint(painter: _SparkPainter(sparks))),
          ...popups,
        ],
      ),
    );
  }

  Widget _tileAt(
    Rect rect,
    int tier, {
    double scale = 1,
    double opacity = 1,
    Key? key,
  }) {
    return Positioned.fromRect(
      key: key,
      rect: rect,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: scale,
          child: CampTileArt(tier: tier, theme: widget.theme, animate: false),
        ),
      ),
    );
  }

  void _buildPlace(
    _PlaceEvent e,
    Duration t,
    int seed,
    BoardGeometry g,
    CampPalette palette,
    List<Widget> tiles,
    List<_Spark> sparks,
    List<Widget> popups,
  ) {
    final origin = g.cellRect(e.index);
    final ms = t.inMicroseconds / 1000;

    if (e.coverActive(t)) {
      // Ghosts: absorbed tiles wait in place, then fly into the origin.
      for (final step in e.steps) {
        final start = FxTiming.flightStart(step.chainIndex).inMilliseconds;
        final f = ((ms - start) / FxTiming.flight.inMilliseconds).clamp(
          0.0,
          1.0,
        );
        if (f >= 1) continue;
        final eased = Curves.easeInCubic.transform(f);
        for (final cell in step.absorbed) {
          final from = g.cellRect(cell);
          final center = Offset.lerp(from.center, origin.center, eased)!;
          tiles.add(
            _tileAt(
              Rect.fromCenter(center: center, width: g.cell, height: g.cell),
              step.fromTier,
              scale: 1 - 0.35 * eased,
              opacity: 1 - 0.5 * eased,
              key: ValueKey('fx-ghost-${identityHashCode(e)}-$cell'),
            ),
          );
        }
      }
      // Origin: drop in, then pop once per merge with the new tier.
      var tier = e.placedTier;
      var scale = Curves.easeOutBack.transform(
        (ms / FxTiming.drop.inMilliseconds).clamp(0.0, 1.0),
      );
      scale = 0.45 + 0.55 * scale;
      for (final step in e.steps) {
        final hit = FxTiming.impact(step.chainIndex).inMilliseconds;
        if (ms >= hit) {
          tier = step.toTier;
          final p = ((ms - hit) / FxTiming.pop.inMilliseconds).clamp(0.0, 1.0);
          if (p < 1) scale = 1 + 0.18 * math.sin(math.pi * p);
        }
      }
      tiles.add(
        _tileAt(origin, tier, scale: scale, key: const ValueKey('fx-origin')),
      );
    }

    for (final step in e.steps) {
      final hit = FxTiming.impact(step.chainIndex).inMilliseconds;
      final since = ms - hit;
      if (since < 0) continue;
      // Spark burst in the new tier color.
      final life = since / FxTiming.particles.inMilliseconds;
      if (life < 1) {
        final random = math.Random(seed * 31 + step.chainIndex);
        final count = 10 + math.min(4, step.absorbed.length);
        final color = palette.tierColor(step.toTier);
        for (var i = 0; i < count; i++) {
          final angle = random.nextDouble() * math.pi * 2;
          final speed = g.cell * (0.6 + random.nextDouble() * 0.7);
          final dist = speed * Curves.easeOutCubic.transform(life);
          final drop = g.cell * 0.35 * life * life;
          sparks.add(
            _Spark(
              center:
                  origin.center +
                  Offset(math.cos(angle) * dist, math.sin(angle) * dist + drop),
              radius:
                  g.cell *
                  (0.035 + random.nextDouble() * 0.035) *
                  (1 - life * 0.6),
              color: i.isEven ? color : Colors.white,
              opacity: 1 - life,
              leaf: i % 3 == 0,
              angle: angle + life * 4,
            ),
          );
        }
      }
      // Floating "+points" rising from the origin.
      final p = since / FxTiming.popup.inMilliseconds;
      if (p < 1) {
        final rise = g.cell * 0.75 * Curves.easeOutCubic.transform(p);
        final fade = p < 0.55 ? 1.0 : 1 - (p - 0.55) / 0.45;
        final scale =
            0.7 + 0.3 * Curves.easeOutBack.transform(math.min(1, p * 4));
        popups.add(
          Positioned(
            left: origin.center.dx - g.cell,
            width: g.cell * 2,
            top: origin.top - rise - g.cell * 0.05 * (step.chainIndex - 1),
            child: Opacity(
              opacity: fade.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: scale,
                child: Text(
                  '+${step.points}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: math.max(16, g.cell * 0.3),
                    fontWeight: FontWeight.w900,
                    shadows: const [
                      Shadow(
                        color: Color(0xCC3A2414),
                        blurRadius: 0,
                        offset: Offset(0, 2),
                      ),
                      Shadow(color: Color(0x993A2414), blurRadius: 6),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }
  }

  void _buildRemove(
    _RemoveEvent e,
    Duration t,
    int seed,
    BoardGeometry g,
    List<Widget> tiles,
    List<_Spark> sparks,
  ) {
    final rect = g.cellRect(e.index);
    final f = t.inMicroseconds / FxTiming.removal.inMicroseconds;
    if (f < 1) {
      tiles.add(
        Positioned.fromRect(
          key: ValueKey('fx-removal-${e.seed}'),
          rect: rect,
          child: Opacity(
            opacity: (1 - f).clamp(0.0, 1.0),
            child: Transform.rotate(
              angle: 0.35 * f,
              child: Transform.scale(
                scale: 1 - 0.75 * Curves.easeIn.transform(f),
                child: CampTileArt(
                  tier: e.tier,
                  theme: widget.theme,
                  animate: false,
                ),
              ),
            ),
          ),
        ),
      );
    }
    final life = t.inMicroseconds / e.length.inMicroseconds;
    if (life < 1) {
      final random = math.Random(seed * 17);
      for (var i = 0; i < 9; i++) {
        final angle = -math.pi * (0.1 + random.nextDouble() * 0.8);
        final speed = g.cell * (0.4 + random.nextDouble() * 0.5);
        final dist = speed * Curves.easeOut.transform(life);
        sparks.add(
          _Spark(
            center:
                rect.center +
                Offset(
                  math.cos(angle) * dist,
                  math.sin(angle) * dist + g.cell * 0.9 * life * life,
                ),
            radius: g.cell * (0.04 + random.nextDouble() * 0.03),
            color: i.isEven ? const Color(0xFFB07A45) : const Color(0xFFE2B57A),
            opacity: 1 - life,
            chip: true,
            angle: angle * 3 + life * 6,
          ),
        );
      }
    }
  }
}

class _Spark {
  const _Spark({
    required this.center,
    required this.radius,
    required this.color,
    required this.opacity,
    this.leaf = false,
    this.chip = false,
    this.angle = 0,
  });

  final Offset center;
  final double radius;
  final Color color;
  final double opacity;
  final bool leaf;
  final bool chip;
  final double angle;
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.sparks);

  final List<_Spark> sparks;

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in sparks) {
      final paint = Paint()
        ..color = s.color.withValues(alpha: s.opacity.clamp(0.0, 1.0));
      if (s.chip || s.leaf) {
        canvas.save();
        canvas.translate(s.center.dx, s.center.dy);
        canvas.rotate(s.angle);
        if (s.chip) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset.zero,
                width: s.radius * 2.6,
                height: s.radius * 1.2,
              ),
              Radius.circular(s.radius * 0.3),
            ),
            paint,
          );
        } else {
          final path = Path()
            ..moveTo(-s.radius * 1.6, 0)
            ..quadraticBezierTo(0, -s.radius * 1.2, s.radius * 1.6, 0)
            ..quadraticBezierTo(0, s.radius * 1.2, -s.radius * 1.6, 0);
          canvas.drawPath(path, paint);
        }
        canvas.restore();
      } else {
        // Four-point star spark.
        final r = s.radius * 1.6;
        final c = s.center;
        final path = Path()
          ..moveTo(c.dx, c.dy - r)
          ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
          ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
          ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
          ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r);
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_SparkPainter old) => true;
}
