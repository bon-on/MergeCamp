import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_camp/src/game/how_to_play.dart';
import 'package:merge_camp/src/game/merge_camp_controller.dart';
import 'package:merge_camp/src/game/merge_camp_screen.dart';
import 'package:merge_camp/src/game/ui/camp_layout.dart';
import 'package:merge_camp/src/meta/camp_progress_store.dart';

class _SeenStore extends HowToPlayStore {
  const _SeenStore();
  @override
  Future<bool> loadSeen() async => true;
  @override
  Future<void> markSeen() async {}
}

Future<void> _pump(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final controller = MergeCampController();
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: MergeCampScreen(
        controller: controller,
        howToPlayStore: const _SeenStore(),
        progressStore: MemoryCampProgressStore(),
        animateArt: false,
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

/// On-screen height of the "Score" caption (after any scale).
double _captionHeight(WidgetTester tester) {
  final f = find.text('SCORE').evaluate().isNotEmpty
      ? find.text('SCORE')
      : find.text('Score');
  final tl = tester.getTopLeft(f.first);
  final br = tester.getBottomRight(f.first);
  return br.dy - tl.dy;
}

/// On-screen caption height at 1280x720 and 1100x620 before the change.
double _baseCaption(Size size) => size.height >= 720 ? 16 : 15;

void main() {
  test('side scale is 1 up to 720 px and capped at 1.5', () {
    expect(wideSideScaleFor(620), 1);
    expect(wideSideScaleFor(720), 1);
    expect(wideSideScaleFor(1080), 1.5);
    expect(wideSideScaleFor(1440), 1.5);
  });

  // Values measured before feature-large-screen-scale: windows up to 720 px
  // tall must keep them.
  for (final (size, board) in const [
    (Size(1280, 720), 515.0),
    (Size(1100, 620), 437.0),
  ]) {
    testWidgets('$size keeps its board and panel size', (tester) async {
      await _pump(tester, size);
      expect(tester.getSize(find.byType(GridView)).width, closeTo(board, 1.5));
      expect(_captionHeight(tester), closeTo(_baseCaption(size), 0.5));
    });
  }

  testWidgets('fullscreen grows the side panels', (tester) async {
    await _pump(tester, const Size(1920, 1080));
    expect(
      _captionHeight(tester),
      greaterThanOrEqualTo(_baseCaption(const Size(1280, 720)) * 1.3),
    );
    expect(tester.getSize(find.byType(GridView)).width, greaterThan(700));
    expect(tester.takeException(), isNull);
  });

  for (final size in const [
    Size(1100, 620),
    Size(1366, 768),
    Size(1600, 900),
    Size(2560, 1440),
    Size(2560, 1080),
    Size(1920, 900),
  ]) {
    testWidgets('panels stay on screen and off the board at $size', (
      tester,
    ) async {
      await _pump(tester, size);
      final screen = Offset.zero & size;
      final board = tester.getRect(find.byType(GridView));
      final f = find.text('SCORE').evaluate().isNotEmpty
          ? find.text('SCORE')
          : find.text('Score');
      final caption = Rect.fromPoints(
        tester.getTopLeft(f.first),
        tester.getBottomRight(f.first),
      );
      expect(screen.contains(caption.topLeft), isTrue);
      expect(screen.contains(caption.bottomRight), isTrue);
      expect(caption.overlaps(board), isFalse);
      expect(tester.takeException(), isNull);
    });
  }
}
