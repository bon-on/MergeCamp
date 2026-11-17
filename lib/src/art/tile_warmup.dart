import 'dart:async';

import 'package:flutter/widgets.dart';

import '../meta/camp_theme.dart';
import 'art_raster_cache.dart';
import 'camp_tile_art.dart';

/// Draws the first camp tiers once, nearly invisible, right after the board
/// appears, so the raster cache and the GPU already hold them when the first
/// merges happen (see feature-first-minute-polish).
///
/// Only active where [ArtRasterCache.enabled] (web). Tiers are mounted one
/// step at a time so no single frame pays for all of them, and the whole
/// layer removes itself when done.
class TileWarmup extends StatefulWidget {
  const TileWarmup({
    super.key,
    required this.cell,
    required this.theme,
    this.tiers = 5,
    this.step = const Duration(milliseconds: 120),
  });

  /// Edge of one board cell in logical pixels (the size real tiles use).
  final double cell;
  final CampTheme theme;

  /// Tiers 1..[tiers] are warmed.
  final int tiers;
  final Duration step;

  @override
  State<TileWarmup> createState() => _TileWarmupState();
}

class _TileWarmupState extends State<TileWarmup> {
  int _mounted = 0;
  bool _done = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (!ArtRasterCache.enabled) {
      _done = true;
      return;
    }
    _timer = Timer.periodic(widget.step, (timer) {
      if (!mounted) return;
      setState(() {
        if (_mounted < widget.tiers) {
          _mounted += 1;
        } else {
          _done = true;
          timer.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_done || _mounted == 0 || widget.cell <= 0) {
      return const SizedBox.shrink();
    }
    // The tile painters are the real ones, so cache keys match real use.
    return IgnorePointer(
      child: ExcludeSemantics(
        child: Opacity(
          opacity: 0.01,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (var tier = 1; tier <= _mounted; tier++) ...[
                for (final animate in const [true, false])
                  SizedBox(
                    key: ValueKey('warm-$tier-$animate'),
                    width: widget.cell,
                    height: widget.cell,
                    child: CampTileArt(
                      tier: tier,
                      theme: widget.theme,
                      animate: animate,
                    ),
                  ),
                SizedBox(
                  key: ValueKey('warm-preview-$tier'),
                  width: widget.cell,
                  height: widget.cell,
                  // Same structure as the board's placement preview.
                  child: Padding(
                    padding: EdgeInsets.all(widget.cell * 0.1),
                    child: CampTileArt(
                      tier: tier,
                      theme: widget.theme,
                      animate: false,
                      showBadge: false,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
