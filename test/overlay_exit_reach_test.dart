import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_camp/src/game/how_to_play.dart';
import 'package:merge_camp/src/game/ui/album_overlay.dart';
import 'package:merge_camp/src/game/ui/second_wind_overlay.dart';
import 'package:merge_camp/src/meta/camp_progress.dart';
import 'package:merge_camp/src/meta/camp_theme.dart';

/// Short phone windows (browser bars, landscape) where a card can be taller
/// than the screen. The way out of every card must stay on screen without
/// scrolling.
const _sizes = [Size(360, 560), Size(320, 480), Size(640, 300)];

Future<void> _pump(WidgetTester tester, Size size, Widget overlay) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: SizedBox.expand(child: overlay))),
  );
  await tester.pumpAndSettle();
}

void _expectOnScreen(WidgetTester tester, Finder finder, Size size) {
  expect(finder, findsOneWidget);
  final rect = tester.getRect(finder);
  expect(rect.top, greaterThanOrEqualTo(0), reason: '$finder at $size');
  expect(rect.bottom, lessThanOrEqualTo(size.height), reason: '$finder');
  expect(rect.left, greaterThanOrEqualTo(0), reason: '$finder');
  expect(rect.right, lessThanOrEqualTo(size.width), reason: '$finder');
}

void main() {
  for (final size in _sizes) {
    testWidgets('How to play keeps Skip and Next on screen at $size', (
      tester,
    ) async {
      var closed = 0;
      await _pump(
        tester,
        size,
        HowToPlayOverlay(
          steps: [
            HowToPlayStep(
              icon: Icons.touch_app_rounded,
              text: List.filled(12, 'Merge three matching camps.').join(' '),
              tiers: const [1, 1, 2],
            ),
            const HowToPlayStep(icon: Icons.star, text: 'Last step.'),
          ],
          onClose: () => closed++,
        ),
      );
      expect(tester.takeException(), isNull);
      _expectOnScreen(tester, find.text('Skip'), size);
      _expectOnScreen(tester, find.text('Next'), size);
      await tester.tap(find.text('Skip'));
      expect(closed, 1);
    });

    testWidgets('Second Wind keeps both answers on screen at $size', (
      tester,
    ) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      var ended = 0;
      await _pump(
        tester,
        size,
        SecondWindOverlay(
          theme: CampTheme.summer,
          clears: 3,
          onContinue: () {},
          onEnd: () => ended++,
          continueFocus: focus,
        ),
      );
      expect(tester.takeException(), isNull);
      _expectOnScreen(
        tester,
        find.byKey(const ValueKey('second-wind-continue')),
        size,
      );
      final end = find.byKey(const ValueKey('second-wind-end'));
      _expectOnScreen(tester, end, size);
      await tester.tap(end);
      expect(ended, 1);
    });

    testWidgets('the album close button stays pinned at $size', (
      tester,
    ) async {
      var closed = 0;
      await _pump(
        tester,
        size,
        AlbumOverlay(
          progress: const CampProgress.initial(),
          onSelectTheme: (_) {},
          onClose: () => closed++,
          animateArt: false,
        ),
      );
      expect(tester.takeException(), isNull);
      final close = find.byTooltip('Close album');
      _expectOnScreen(tester, close, size);
      // Still there after scrolling to the end of the album.
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -2000),
      );
      await tester.pumpAndSettle();
      _expectOnScreen(tester, close, size);
      await tester.tap(close);
      expect(closed, 1);
    });
  }
}
