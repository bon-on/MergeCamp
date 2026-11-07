import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// Small LRU cache of vector art rasterized once into images.
///
/// Flutter web (CanvasKit) has no raster cache: every frame replays every
/// recorded picture, so static vector art (gradients, many paths) is drawn
/// again whenever anything on screen animates. Drawing a cached image is a
/// single textured quad instead. Native engines cache rasters themselves,
/// so the cache is only on for web by default (see feature-mobile-perf).
class ArtRasterCache {
  ArtRasterCache({required this.maxEntries});

  /// Whether painters should use their cache. Tests may flip it.
  static bool enabled = kIsWeb;

  /// Largest image side in physical pixels a painter may cache; bigger art
  /// is drawn as vectors (avoids huge textures on unusual screens).
  static const int maxSide = 4096;

  final int maxEntries;
  final LinkedHashMap<Object, ui.Image> _images =
      LinkedHashMap<Object, ui.Image>();

  int get length => _images.length;

  /// Image for [key], rasterized by [paint] at [width] x [height] physical
  /// pixels the first time it is needed.
  ui.Image image(
    Object key,
    int width,
    int height,
    void Function(ui.Canvas canvas) paint,
  ) {
    final cached = _images.remove(key);
    if (cached != null) {
      _images[key] = cached;
      return cached;
    }
    final recorder = ui.PictureRecorder();
    paint(ui.Canvas(recorder));
    final picture = recorder.endRecording();
    final image = picture.toImageSync(width, height);
    picture.dispose();
    _images[key] = image;
    while (_images.length > maxEntries) {
      // Pictures already recorded keep their own reference to the image.
      _images.remove(_images.keys.first)!.dispose();
    }
    return image;
  }

  void clear() {
    for (final image in _images.values) {
      image.dispose();
    }
    _images.clear();
  }
}
