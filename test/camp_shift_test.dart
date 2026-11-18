import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_camp/src/game/how_to_play.dart';
import 'package:merge_camp/src/game/merge_camp_controller.dart';
import 'package:merge_camp/src/game/merge_camp_screen.dart';
import 'package:merge_camp/src/meta/camp_progress.dart';
import 'package:merge_camp/src/meta/camp_progress_store.dart';
import 'package:merge_camp/src/meta/missions.dart';
import 'package:merge_camp/src/platform/game_platform.dart';

const _empty = null;

List<int?> _board(Map<int, int> tiles) =>
    List<int?>.generate(MergeCampController.cellCount, (index) => tiles[index]);

MergeCampController _loaded(
  Map<int, int> tiles, {
  int shifts = 1,
  int placements = 4,
  int nextTier = 1,
}) {
  final c = MergeCampController();
  c.debugLoadBoard(
    _board(tiles),
    nextTier: nextTier,
    placements: placements,
    shifts: shifts,
  );
  return c;
}

void main() {
  group('Shift rules', () {
    test('slides every camp to the wall and keeps their order', () {
      final c = _loaded({1: 3, 3: 1, 6: 2, 12: 4, 15: 5});
      final result = c.useShift(ShiftDirection.left);
      expect(result.action, MergeAction.shifted);
      expect(c.board, [
        3, 1, _empty, _empty, //
        2, _empty, _empty, _empty, //
        _empty, _empty, _empty, _empty, //
        4, 5, _empty, _empty, //
      ]);
      expect(c.shifts, 0);
      expect(c.lastShiftMoves.map((m) => m.to), containsAll([0, 1, 4, 13]));
      expect(c.lastMergeSteps, isEmpty);
    });

    test('slides in all four directions', () {
      Map<int, int> start() => {5: 1, 10: 2};
      final expected = {
        ShiftDirection.left: {4: 1, 8: 2},
        ShiftDirection.right: {7: 1, 11: 2},
        ShiftDirection.up: {1: 1, 2: 2},
        ShiftDirection.down: {13: 1, 14: 2},
      };
      for (final entry in expected.entries) {
        final c = _loaded(start());
        expect(c.useShift(entry.key).action, MergeAction.shifted);
        expect(c.board, _board(entry.value), reason: entry.key.name);
      }
    });

    test('does nothing and spends nothing when no camp can move', () {
      final c = _loaded({0: 1, 4: 2, 8: 1});
      final before = c.board;
      final result = c.useShift(ShiftDirection.left);
      expect(result.action, MergeAction.blocked);
      expect(c.shifts, 1);
      expect(c.board, before);
    });

    test('cannot be used without a charge or after game over', () {
      final none = _loaded({5: 1}, shifts: 0);
      expect(none.useShift(ShiftDirection.left).action, MergeAction.noTool);
      final over = MergeCampController();
      over.debugLoadBoard(
        _board({5: 1}),
        nextTier: 1,
        placements: 4,
        shifts: 1,
        isGameOver: true,
      );
      expect(over.useShift(ShiftDirection.left).action, MergeAction.gameOver);
      expect(over.shifts, 1);
    });

    test('a full board has nowhere to slide', () {
      final c = _loaded({
        for (var i = 0; i < MergeCampController.cellCount; i++)
          i: (i ~/ 4 + i % 4).isEven ? 1 : 2,
      });
      expect(c.useShift(ShiftDirection.up).action, MergeAction.blocked);
      expect(c.shifts, 1);
    });

    test('merges the touching groups it creates at the wall side', () {
      final c = _loaded({0: 1, 2: 1, 3: 1});
      final result = c.useShift(ShiftDirection.left);
      expect(result.action, MergeAction.shifted);
      expect(c.board[0], 2, reason: 'origin is the cell nearest the wall');
      expect(c.board.where((t) => t != null), hasLength(1));
      expect(c.lastMergeSteps.single.origin, 0);
      expect(c.mergeCount, 1);
      expect(c.score, 3 * 12 * 2);
      expect(c.highestTier, 2);
      expect(c.bestMergeChain, 1);

      final right = _loaded({0: 1, 1: 1, 3: 1});
      right.useShift(ShiftDirection.right);
      expect(right.board[3], 2);
      expect(right.lastMergeSteps.single.origin, 3);
    });

    test('merges at the wall-nearest cell across rows and columns', () {
      // Left: the group {1, 4, 5} has its wall-nearest cell in column 0.
      final left = _loaded({0: 2, 2: 1, 5: 1, 7: 1});
      left.useShift(ShiftDirection.left);
      expect(left.lastMergeSteps.single.origin, 4);
      expect(left.board[4], 2);

      // Down: the group {8, 9, 13} has its wall-nearest cell in the bottom row.
      final down = _loaded({0: 1, 1: 1, 4: 2, 5: 1});
      down.useShift(ShiftDirection.down);
      expect(down.lastMergeSteps.single.origin, 13);
      expect(down.board[13], 2);
    });

    test('keeps merging a chain it starts', () {
      // Left: row 0 slides into 1,1,1 -> tier 2 next to two tier 2 below.
      final c = _loaded({0: 1, 2: 1, 3: 1, 4: 2, 8: 2});
      c.useShift(ShiftDirection.left);
      expect(c.lastMergeSteps.map((s) => s.toTier), [2, 3]);
      expect(c.board[0], 3);
      expect(c.lastMergeChain, 2);
      expect(c.highestTier, 3);
    });

    test('does not count as a placement or draw a piece', () {
      final c = _loaded({0: 1, 2: 1, 3: 1});
      final preview = c.previewTiers;
      c.useShift(ShiftDirection.left);
      expect(c.placements, 4);
      expect(c.previewTiers, preview);
      expect(c.lastPlacedIndex, isNull);
    });

    test('a 5-tile merge earns a Shift', () {
      // Placing at 2 joins 0-1 and 3-7 into one group of five.
      final c = _loaded({0: 1, 1: 1, 3: 1, 7: 1}, shifts: 0);
      final result = c.place(2);
      expect(result.action, MergeAction.merged);
      expect(c.lastMergeSteps.first.absorbed.length + 1, 5);
      expect(c.shifts, 1);
      expect(c.lastEarnedShift, isTrue);
    });

    test('a 3-merge chain earns a Shift', () {
      final c = _loaded({4: 1, 6: 1, 1: 2, 0: 2, 9: 3, 13: 3}, shifts: 0);
      c.place(5);
      expect(c.lastMergeSteps, hasLength(3));
      expect(c.shifts, 1);
      expect(c.lastEarnedShift, isTrue);
    });

    test('an ordinary 3-merge earns nothing and the cap is 1', () {
      final plain = _loaded({0: 1, 1: 1}, shifts: 0);
      plain.place(2);
      expect(plain.lastMergeSteps, hasLength(1));
      expect(plain.shifts, 0);
      expect(plain.lastEarnedShift, isFalse);

      final full = _loaded({0: 1, 1: 1, 3: 1, 7: 1}, shifts: 1);
      full.place(2);
      expect(full.shifts, MergeCampController.maxShifts);
      expect(full.lastEarnedShift, isFalse);
      expect(full.grantShift(), isFalse);
    });

    test('a new run starts without a Shift', () {
      final c = _loaded({5: 1});
      c.restart();
      expect(c.shifts, 0);
    });

    test('shifts survive a snapshot round trip', () {
      final c = _loaded({5: 1, 6: 1});
      final copy = MergeCampController();
      expect(copy.restoreSnapshot(c.toSnapshot()), isTrue);
      expect(copy.shifts, 1);
    });

    test('older snapshots without shifts restore as zero', () {
      final c = _loaded({5: 1, 6: 1});
      final data = Map<String, dynamic>.of(c.toSnapshot())..remove('shifts');
      final copy = MergeCampController();
      expect(copy.restoreSnapshot(data), isTrue);
      expect(copy.shifts, 0);
    });

    test('rejects an out of range Shift count', () {
      final c = _loaded({5: 1, 6: 1});
      final data = Map<String, dynamic>.of(c.toSnapshot());
      for (final bad in [-1, 2, '1']) {
        data['shifts'] = bad;
        expect(MergeCampController().restoreSnapshot(data), isFalse);
      }
    });

    test('rejects a Shift before the first placement', () {
      final c = MergeCampController();
      final data = Map<String, dynamic>.of(c.toSnapshot())..['shifts'] = 1;
      expect(MergeCampController().restoreSnapshot(data), isFalse);
    });
  });

  group('Shift screen', () {
    testWidgets('the button is dimmed without a charge', (tester) async {
      await _pump(tester, _loaded({5: 1}, shifts: 0));
      expect(find.byKey(const ValueKey('shift-count')), findsOneWidget);
      expect(find.text('x0'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('shift-button')));
      await tester.pump();
      expect(find.byKey(const ValueKey('shift-bar')), findsNothing);
    });

    testWidgets('a direction slides the camps and spends the charge', (
      tester,
    ) async {
      final c = _loaded({5: 1, 10: 2});
      await _pump(tester, c);
      await tester.tap(find.byKey(const ValueKey('shift-button')));
      await tester.pump();
      expect(find.byKey(const ValueKey('shift-bar')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('shift-left')));
      await tester.pump();
      expect(c.board, _board({4: 1, 8: 2}));
      expect(c.shifts, 0);
      expect(c.placements, 4);
      expect(find.byKey(const ValueKey('shift-bar')), findsNothing);
      await tester.pumpAndSettle(const Duration(seconds: 2));
    });

    testWidgets('a merge started by a Shift plays out and settles', (
      tester,
    ) async {
      final c = _loaded({0: 1, 2: 1, 3: 1});
      await _pump(tester, c);
      await tester.tap(find.byKey(const ValueKey('shift-button')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('shift-left')));
      await tester.pump();
      expect(c.board[0], 2);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Shift cannot be armed during the guided practice', (
      tester,
    ) async {
      final c = MergeCampController();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      addTearDown(c.dispose);
      for (final channel in const [
        MethodChannel('merge_camp/audio'),
        SystemChannels.platform,
      ]) {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          (call) async => null,
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            null,
          ),
        );
      }
      await tester.pumpWidget(
        MaterialApp(
          home: MergeCampScreen(
            controller: c,
            howToPlayStore: _NewPlayerStore(),
            progressStore: MemoryCampProgressStore(),
            animateArt: false,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.widgetWithText(FilledButton, 'Next'));
        await tester.pump();
      }
      await tester.tap(find.widgetWithText(FilledButton, 'Play'));
      await tester.pump();
      expect(find.text('Tap the glowing plot to merge!'), findsOneWidget);
      c.grantShift();
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('shift-button')));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.pump();
      expect(find.byKey(const ValueKey('shift-bar')), findsNothing);
      expect(c.shifts, 1);
    });

    testWidgets('cancel closes the bar and keeps the charge', (tester) async {
      final c = _loaded({5: 1});
      await _pump(tester, c);
      await tester.tap(find.byKey(const ValueKey('shift-button')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('shift-cancel')));
      await tester.pump();
      expect(find.byKey(const ValueKey('shift-bar')), findsNothing);
      expect(c.shifts, 1);
    });

    testWidgets('a direction with no movement keeps the mode open', (
      tester,
    ) async {
      final c = _loaded({0: 1, 4: 2});
      await _pump(tester, c);
      await tester.tap(find.byKey(const ValueKey('shift-button')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('shift-left')));
      await tester.pump();
      expect(find.byKey(const ValueKey('shift-bar')), findsOneWidget);
      expect(c.shifts, 1);
      await tester.tap(find.byKey(const ValueKey('shift-right')));
      await tester.pump();
      expect(c.board, _board({3: 1, 7: 2}));
      expect(c.shifts, 0);
    });

    testWidgets('Shift mode and Trail Axe mode exclude each other', (
      tester,
    ) async {
      await _pump(tester, _loaded({5: 1}));
      await tester.tap(find.byKey(const ValueKey('trail-axe-button')));
      await tester.pump();
      expect(find.text('Pick a tile'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('shift-button')));
      await tester.pump();
      expect(find.byKey(const ValueKey('shift-bar')), findsOneWidget);
      expect(find.text('Pick a tile'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('trail-axe-button')));
      await tester.pump();
      expect(find.byKey(const ValueKey('shift-bar')), findsNothing);
      expect(find.text('Pick a tile'), findsOneWidget);
    });

    testWidgets('tapping a plot while Shift is armed places nothing', (
      tester,
    ) async {
      final c = _loaded({5: 1});
      await _pump(tester, c);
      await tester.tap(find.byKey(const ValueKey('shift-button')));
      await tester.pump();
      await tester.tapAt(tester.getCenter(find.byType(GridView)));
      await tester.pump();
      expect(c.placements, 4);
    });

    testWidgets('C arms Shift, arrows pick the way, Esc cancels', (
      tester,
    ) async {
      final c = _loaded({5: 1, 10: 2});
      await _pump(tester, c);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.pump();
      expect(find.byKey(const ValueKey('shift-bar')), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.byKey(const ValueKey('shift-bar')), findsNothing);
      expect(c.shifts, 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(c.board, _board({13: 1, 14: 2}));
      expect(c.shifts, 0);
      await tester.pumpAndSettle(const Duration(seconds: 2));
    });

    testWidgets('C does nothing without a charge', (tester) async {
      await _pump(tester, _loaded({5: 1}, shifts: 0));
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.pump();
      expect(find.byKey(const ValueKey('shift-bar')), findsNothing);
    });

    testWidgets('a Big merge mission pays a Shift instead of a Trail Axe', (
      tester,
    ) async {
      final seed = _loaded({0: 1, 1: 1}, shifts: 0, placements: 3);
      final missions = MissionBoard()
        ..restoreSnapshot({
          'version': 1,
          'setNumber': 1,
          'completedThisRun': 0,
          'setBestChain': 0,
          'setBestCluster': 0,
          'active': [
            {'kind': 'bigMerge', 'target': 3, 'progress': 0, 'baseline': 0},
            {'kind': 'buildTier', 'target': 8, 'progress': 0, 'baseline': 0},
            {
              'kind': 'reachScore',
              'target': 100000,
              'progress': 0,
              'baseline': 0,
            },
          ],
        });
      final progress = const CampProgress.initial().withActiveRun({
        'version': 1,
        'controller': seed.toSnapshot(),
        'missions': missions.toSnapshot(),
        'guidedPractice': false,
      });
      final c = MergeCampController();
      await _pump(tester, c, progress: progress);
      await tester.pump();
      expect(c.placements, 3);
      final axesBefore = c.trailAxes;
      c.place(2);
      await tester.pump();
      expect(c.shifts, 1);
      expect(c.trailAxes, axesBefore);
      expect(find.textContaining('+1 Shift'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 4));
    });

    testWidgets('an earned Shift shows a toast', (tester) async {
      final c = _loaded({0: 1, 1: 1, 3: 1, 7: 1}, shifts: 0);
      await _pump(tester, c);
      c.place(2);
      await tester.pump();
      expect(find.textContaining('Shift earned'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 4));
    });

    for (final size in const [
      Size(320, 640),
      Size(360, 640),
      Size(390, 844),
      Size(640, 480),
      Size(844, 390),
      Size(1280, 720),
    ]) {
      testWidgets('the Shift bar fits $size', (tester) async {
        await _pump(tester, _loaded({5: 1}), size: size);
        await tester.tap(find.byKey(const ValueKey('shift-button')));
        await tester.pump();
        expect(find.byKey(const ValueKey('shift-bar')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}

class _NewPlayerStore extends HowToPlayStore {
  bool seen = false;
  @override
  Future<bool> loadSeen() async => seen;
  @override
  Future<void> markSeen() async => seen = true;
}

class _SeenStore extends HowToPlayStore {
  const _SeenStore();
  @override
  Future<bool> loadSeen() async => true;
  @override
  Future<void> markSeen() async {}
}

Future<void> _pump(
  WidgetTester tester,
  MergeCampController controller, {
  CampProgress progress = const CampProgress.initial(),
  Size size = const Size(390, 844),
  bool animateArt = false,
}) async {
  for (final channel in const [
    MethodChannel('merge_camp/audio'),
    SystemChannels.platform,
  ]) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async => null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
  }
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: MergeCampScreen(
        controller: controller,
        howToPlayStore: const _SeenStore(),
        progressStore: MemoryCampProgressStore(progress),
        animateArt: animateArt,
        platform: const NoopGamePlatform(allowsResultRegistration: false),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}
