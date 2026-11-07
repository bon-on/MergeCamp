import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_camp/src/art/art_raster_cache.dart';
import 'package:merge_camp/src/art/camp_scenery.dart';
import 'package:merge_camp/src/art/camp_tile_art.dart';
import 'package:merge_camp/src/meta/camp_theme.dart';

void main() {
  // The cache is web-only by default; these tests force it on for the VM.
  late bool wasEnabled;
  setUp(() => wasEnabled = ArtRasterCache.enabled);
  tearDown(() => ArtRasterCache.enabled = wasEnabled);

  group('ArtRasterCache', () {
    test('rasterizes once per key and evicts least recently used', () {
      final cache = ArtRasterCache(maxEntries: 2);
      var paints = 0;
      void paint(ui.Canvas canvas) {
        paints += 1;
        canvas.drawRect(
          const ui.Rect.fromLTWH(0, 0, 4, 4),
          ui.Paint()..color = const ui.Color(0xFF00FF00),
        );
      }

      final a = cache.image('a', 4, 4, paint);
      expect(a.width, 4);
      final first = a;
      expect(identical(cache.image('a', 4, 4, paint), a), isTrue);
      expect(paints, 1);
      final b = cache.image('b', 4, 4, paint);
      cache.image('a', 4, 4, paint); // 'a' is now the most recent
      cache.image('c', 4, 4, paint); // evicts 'b'
      expect(cache.length, 2);
      expect(b.debugDisposed, isTrue);
      expect(first.debugDisposed, isFalse);
      expect(paints, 3);
      cache.image('a', 4, 4, paint);
      expect(paints, 3);
      cache.image('b', 4, 4, paint);
      expect(paints, 4);
      cache.clear();
      expect(cache.length, 0);
      expect(first.debugDisposed, isTrue);
    });
  });

  testWidgets('cached tiles and scenery paint for all themes', (tester) async {
    ArtRasterCache.enabled = true;
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    for (final theme in CampTheme.values) {
      for (final animate in [false, true]) {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CampScenery(theme: theme, animate: animate),
                ),
                Wrap(
                  children: [
                    for (var tier = 1; tier <= 9; tier++)
                      SizedBox.square(
                        dimension: 60,
                        child: CampTileArt(
                          tier: tier,
                          theme: theme,
                          animate: animate,
                        ),
                      ),
                    const SizedBox.square(
                      dimension: 40,
                      child: CampTileArt(tier: 3, silhouette: true),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
      }
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a cached still tile looks like the vector tile', (tester) async {
    tester.view.physicalSize = const Size(200, 200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Future<List<int>> render(
      bool cached,
      int tier, {
      bool showBadge = true,
      bool silhouette = false,
    }) async {
      ArtRasterCache.enabled = cached;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox.square(
              key: ValueKey('$cached-$tier-$showBadge-$silhouette'),
              dimension: 64,
              child: CampTileArt(
                tier: tier,
                animate: false,
                showBadge: showBadge,
                silhouette: silhouette,
              ),
            ),
          ),
        ),
      );
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.descendant(
          of: find.byType(CampTileArt),
          matching: find.byType(RepaintBoundary),
        ),
      );
      final bytes = await tester.runAsync(() async {
        final image = await boundary.toImage();
        final data = await image.toByteData();
        image.dispose();
        return data!.buffer.asUint8List().toList();
      });
      return bytes!;
    }

    for (final tier in [1, 2, 6, 8]) {
      final vector = await render(false, tier);
      final cached = await render(true, tier);
      expect(cached.length, vector.length);
      var total = 0;
      for (var i = 0; i < vector.length; i++) {
        total += (vector[i] - cached[i]).abs();
      }
      // Same art; only anti-aliasing and resampling may differ slightly.
      expect(total / vector.length, lessThan(2.0), reason: 'tier $tier');
    }
    // Badge and silhouette variants get their own cache entries.
    final plain = await render(true, 3);
    for (final variant in [
      await render(true, 3, showBadge: false),
      await render(true, 3, silhouette: true),
    ]) {
      var total = 0;
      for (var i = 0; i < plain.length; i++) {
        total += (plain[i] - variant[i]).abs();
      }
      expect(total, greaterThan(0));
    }
    await tester.pumpWidget(const SizedBox());
  });
}
