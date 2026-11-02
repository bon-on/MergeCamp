import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_camp/src/art/camp_palette.dart';
import 'package:merge_camp/src/art/camp_scenery.dart';
import 'package:merge_camp/src/art/camp_tile_art.dart';
import 'package:merge_camp/src/art/empty_plot_art.dart';
import 'package:merge_camp/src/meta/camp_theme.dart';

Widget _boxed(double size, Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: Center(
    child: SizedBox(width: size, height: size, child: child),
  ),
);

void _useView(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  group('CampTileArt', () {
    for (final animate in [false, true]) {
      for (final size in [48.0, 220.0]) {
        testWidgets('tiers 0..9, all themes, ${size.toInt()} px, '
            'animate=$animate', (tester) async {
          _useView(tester, const Size(400, 400));
          for (final theme in CampTheme.values) {
            for (final silhouette in [false, true]) {
              for (var tier = 0; tier <= 9; tier++) {
                await tester.pumpWidget(
                  _boxed(
                    size,
                    CampTileArt(
                      key: ValueKey('$theme-$silhouette-$tier'),
                      tier: tier,
                      theme: theme,
                      animate: animate,
                      silhouette: silhouette,
                    ),
                  ),
                );
                if (animate) {
                  await tester.pump(const Duration(milliseconds: 250));
                  await tester.pump(const Duration(milliseconds: 900));
                } else {
                  expect(tester.hasRunningAnimations, isFalse);
                }
                expect(tester.takeException(), isNull);
                expect(
                  tester.getSize(find.byType(CampTileArt)),
                  Size(size, size),
                );
              }
            }
          }
          await tester.pumpWidget(const SizedBox());
        });
      }
    }

    testWidgets('animates only tiers with motion', (tester) async {
      _useView(tester, const Size(300, 300));
      await tester.pumpWidget(_boxed(120, const CampTileArt(tier: 2)));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpWidget(_boxed(120, const CampTileArt(tier: 1)));
      expect(tester.hasRunningAnimations, isFalse);
      await tester.pumpWidget(
        _boxed(120, const CampTileArt(tier: 8, silhouette: true)),
      );
      expect(tester.hasRunningAnimations, isFalse);
      // Toggling animate on and off disposes the controller cleanly.
      await tester.pumpWidget(_boxed(120, const CampTileArt(tier: 5)));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpWidget(
        _boxed(120, const CampTileArt(tier: 5, animate: false)),
      );
      expect(tester.hasRunningAnimations, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('badge can be hidden and non-square boxes paint', (
      tester,
    ) async {
      _useView(tester, const Size(300, 300));
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 90,
              height: 60,
              child: CampTileArt(tier: 4, animate: false, showBadge: false),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    test('maxArtTier covers the eight camps', () {
      expect(CampTileArt.maxArtTier, 8);
    });
  });

  group('CampScenery', () {
    for (final size in [const Size(1280, 720), const Size(390, 844)]) {
      for (final animate in [false, true]) {
        testWidgets('all themes at ${size.width.toInt()}x'
            '${size.height.toInt()}, animate=$animate', (tester) async {
          _useView(tester, size);
          for (final theme in CampTheme.values) {
            await tester.pumpWidget(
              Directionality(
                textDirection: TextDirection.ltr,
                child: CampScenery(
                  key: ValueKey(theme),
                  theme: theme,
                  animate: animate,
                ),
              ),
            );
            if (animate) {
              expect(tester.hasRunningAnimations, isTrue);
              await tester.pump(const Duration(milliseconds: 16));
              await tester.pump(const Duration(seconds: 3));
            } else {
              expect(tester.hasRunningAnimations, isFalse);
            }
            expect(tester.takeException(), isNull);
            expect(tester.getSize(find.byType(CampScenery)), size);
          }
          await tester.pumpWidget(const SizedBox());
        });
      }
    }

    testWidgets('switching theme and animation keeps painting', (tester) async {
      _useView(tester, const Size(800, 600));
      Widget scene(CampTheme theme, bool animate) => Directionality(
        textDirection: TextDirection.ltr,
        child: CampScenery(theme: theme, animate: animate),
      );
      await tester.pumpWidget(scene(CampTheme.summer, true));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(scene(CampTheme.night, true));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(scene(CampTheme.snow, false));
      expect(tester.hasRunningAnimations, isFalse);
      expect(tester.takeException(), isNull);
    });
  });

  group('EmptyPlotArt', () {
    testWidgets('all variants paint at 48 and 220 px', (tester) async {
      _useView(tester, const Size(400, 400));
      for (final theme in CampTheme.values) {
        for (final highlighted in [false, true]) {
          for (final axeMode in [false, true]) {
            for (final size in [48.0, 220.0]) {
              await tester.pumpWidget(
                _boxed(
                  size,
                  EmptyPlotArt(
                    theme: theme,
                    highlighted: highlighted,
                    axeMode: axeMode,
                  ),
                ),
              );
              expect(tester.takeException(), isNull);
              expect(
                tester.getSize(find.byType(EmptyPlotArt)),
                Size(size, size),
              );
            }
          }
        }
      }
    });
  });

  group('CampPalette', () {
    test('every theme has its own palette', () {
      final palettes = CampTheme.values.map(CampPalette.of).toList();
      expect(palettes.map((p) => p.theme), CampTheme.values);
      expect(palettes.map((p) => p.skyTop).toSet(), hasLength(4));
      expect(palettes.map((p) => p.groundBoard).toSet(), hasLength(4));
    });

    test('tier colors are distinct and clamp out-of-range tiers', () {
      final palette = CampPalette.of(CampTheme.summer);
      final colors = [for (var t = 1; t <= 8; t++) palette.tierColor(t)];
      expect(colors.toSet(), hasLength(8));
      expect(palette.tierColor(0), palette.tierColor(1));
      expect(palette.tierColor(12), palette.tierColor(8));
      expect(
        CampPalette.of(CampTheme.night).tierColor(3),
        palette.tierColor(3),
      );
    });
  });
}
