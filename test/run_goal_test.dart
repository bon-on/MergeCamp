import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_camp/src/game/how_to_play.dart';
import 'package:merge_camp/src/game/merge_camp_controller.dart';
import 'package:merge_camp/src/game/merge_camp_screen.dart';
import 'package:merge_camp/src/meta/camp_progress_store.dart';

class _SeenStore extends HowToPlayStore {
  const _SeenStore({this.seen = true});
  final bool seen;
  @override
  Future<bool> loadSeen() async => seen;
  @override
  Future<void> markSeen() async {}
}

List<int?> _sparse() {
  final board = List<int?>.filled(MergeCampController.cellCount, null);
  board[0] = 1;
  return board;
}

Future<void> _pump(
  WidgetTester tester,
  MergeCampController controller,
  Size size, {
  bool newPlayer = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: MergeCampScreen(
        controller: controller,
        howToPlayStore: _SeenStore(seen: !newPlayer),
        progressStore: MemoryCampProgressStore(),
        animateArt: false,
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  group('controller goal', () {
    test('a fresh run aims at tier 4 with a quarter bar', () {
      final c = MergeCampController();
      addTearDown(c.dispose);
      expect(c.goalTier, 4);
      expect(c.goalLabel, 'Build a Scout Cabin');
      expect(c.goalProgress, closeTo(1 / 4, 1e-9));
    });

    test('the goal moves up once the best camp reaches it', () {
      final c = MergeCampController();
      addTearDown(c.dispose);
      c.debugLoadBoard(_sparse(), nextTier: 1, highestTier: 4, placements: 5);
      expect(c.goalTier, 5);
      expect(c.goalLabel, 'Build a Signal Tower');
      expect(c.goalProgress, closeTo(4 / 5, 1e-9));
    });

    test('placements alone never move the goal or shrink the bar', () {
      final c = MergeCampController();
      addTearDown(c.dispose);
      c.debugLoadBoard(_sparse(), nextTier: 1, highestTier: 3, placements: 17);
      expect(c.goalTier, 4);
      c.debugLoadBoard(_sparse(), nextTier: 1, highestTier: 3, placements: 60);
      expect(c.goalTier, 4);
      expect(c.goalProgress, closeTo(3 / 4, 1e-9));
    });

    test('the top tier reads as built with a full bar', () {
      final c = MergeCampController();
      addTearDown(c.dispose);
      c.debugLoadBoard(_sparse(), nextTier: 1, highestTier: 8, placements: 5);
      expect(c.goalTier, 8);
      expect(c.goalLabel, 'Star Observatory built!');
      expect(c.goalProgress, 1);
    });
  });

  for (final size in const [Size(1200, 800), Size(390, 800), Size(360, 640)]) {
    testWidgets('the goal line shows at ${size.width.toInt()}px', (
      tester,
    ) async {
      final controller = MergeCampController();
      addTearDown(controller.dispose);
      await _pump(tester, controller, size);
      expect(find.byKey(const ValueKey('run-goal')), findsOneWidget);
      expect(find.text('Build a Scout Cabin'), findsOneWidget);

      controller.debugLoadBoard(
        _sparse(),
        nextTier: 1,
        highestTier: 4,
        placements: 5,
      );
      controller.addBonusScore(1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Build a Signal Tower'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in const [Size(600, 500), Size(320, 568)]) {
    testWidgets('a small narrow window ${size.width.toInt()}x'
        '${size.height.toInt()} keeps the board and skips the line', (
      tester,
    ) async {
      final controller = MergeCampController();
      addTearDown(controller.dispose);
      await _pump(tester, controller, size);
      expect(find.byKey(const ValueKey('run-goal')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the top tier shows as built with a full bar', (tester) async {
    final controller = MergeCampController();
    addTearDown(controller.dispose);
    await _pump(tester, controller, const Size(360, 640));
    controller.debugLoadBoard(
      _sparse(),
      nextTier: 1,
      highestTier: 8,
      placements: 5,
    );
    controller.addBonusScore(1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Star Observatory built!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in const [Size(1200, 800), Size(390, 800)]) {
    testWidgets('guided practice hides the goal at ${size.width.toInt()}px', (
      tester,
    ) async {
      final controller = MergeCampController();
      addTearDown(controller.dispose);
      await _pump(tester, controller, size, newPlayer: true);
      expect(find.text('Tap the glowing plot to merge!'), findsOneWidget);
      expect(find.byKey(const ValueKey('run-goal')), findsNothing);
    });
  }

  testWidgets('the narrow board never shrinks below 200px for the line', (
    tester,
  ) async {
    for (final height in const [520.0, 540.0, 560.0, 580.0, 600.0, 640.0]) {
      final controller = MergeCampController();
      await _pump(tester, controller, Size(390, height));
      final shown = find
          .byKey(const ValueKey('run-goal'))
          .evaluate()
          .isNotEmpty;
      if (shown) {
        // The sticker frame holds the board side the layout computed.
        final frame = tester.getSize(
          find
              .ancestor(
                of: find.byType(GridView),
                matching: find.byType(SizedBox),
              )
              .first,
        );
        expect(frame.height, greaterThanOrEqualTo(200), reason: '$height');
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    }
  });

  for (final size in const [Size(390, 844), Size(360, 640)]) {
    testWidgets('the board does not move when practice ends at $size', (
      tester,
    ) async {
      final controller = MergeCampController();
      addTearDown(controller.dispose);
      await _pump(tester, controller, size, newPlayer: true);
      await tester.pump();
      expect(find.text('Tap the glowing plot to merge!'), findsOneWidget);
      final before = tester.getRect(find.byType(GridView));
      await tester.tap(find.text('Skip practice'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('run-goal')), findsOneWidget);
      expect(tester.getRect(find.byType(GridView)), before);
    });
  }
}
