import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_camp/src/game/how_to_play.dart';
import 'package:merge_camp/src/game/merge_camp_controller.dart';
import 'package:merge_camp/src/game/merge_camp_screen.dart';
import 'package:merge_camp/src/game/ui/hud.dart';
import 'package:merge_camp/src/meta/camp_progress.dart';
import 'package:merge_camp/src/meta/camp_progress_store.dart';
import 'package:merge_camp/src/meta/missions.dart';
import 'package:merge_camp/src/platform/game_platform.dart';

List<int?> _board(Map<int, int> tiles) =>
    List<int?>.generate(MergeCampController.cellCount, (index) => tiles[index]);

MergeCampController _loaded(
  Map<int, int> tiles, {
  int shifts = 1,
  int placements = 4,
  int nextTier = 1,
  int highestTier = 1,
}) {
  final c = MergeCampController();
  c.debugLoadBoard(
    _board(tiles),
    nextTier: nextTier,
    placements: placements,
    shifts: shifts,
    highestTier: highestTier,
  );
  return c;
}

bool _armed(WidgetTester tester) =>
    tester.widget<ShiftButton>(find.byType(ShiftButton)).selected;

Finder _cell(int index) => find
    .descendant(
      of: find.byType(GridView),
      matching: find.byType(GestureDetector),
    )
    .at(index);

void main() {
  group('Shift rules', () {
    test('steps one camp one cell in all four directions', () {
      final expected = {
        ShiftDirection.left: 4,
        ShiftDirection.right: 6,
        ShiftDirection.up: 1,
        ShiftDirection.down: 9,
      };
      for (final entry in expected.entries) {
        final c = _loaded({5: 1, 10: 2});
        expect(c.useShift(5, entry.key).action, MergeAction.shifted);
        expect(
          c.board,
          _board({entry.value: 1, 10: 2}),
          reason: entry.key.name,
        );
        expect(c.shifts, 0);
        expect(c.lastShiftMoves.single.to, entry.value);
        expect(c.lastShiftErased, isNull);
        expect(c.lastMergeSteps, isEmpty);
      }
    });

    test('shiftTarget stops at the walls', () {
      expect(MergeCampController.shiftTarget(0, ShiftDirection.left), isNull);
      expect(MergeCampController.shiftTarget(0, ShiftDirection.up), isNull);
      expect(MergeCampController.shiftTarget(3, ShiftDirection.right), isNull);
      expect(MergeCampController.shiftTarget(15, ShiftDirection.down), isNull);
      expect(MergeCampController.shiftTarget(5, ShiftDirection.down), 9);
    });

    test('a camp on the target cell is cleared without points', () {
      final c = _loaded({5: 1, 6: 2});
      final scoreBefore = c.score;
      expect(c.useShift(5, ShiftDirection.right).action, MergeAction.shifted);
      expect(c.board, _board({6: 1}));
      expect(c.lastShiftErased, 2);
      expect(c.score, scoreBefore);
      expect(c.mergeCount, 0);
    });

    test('a wall or an empty plot is blocked and spends nothing', () {
      final c = _loaded({4: 1, 5: 2});
      final before = c.board;
      expect(c.useShift(4, ShiftDirection.left).action, MergeAction.blocked);
      expect(c.useShift(0, ShiftDirection.right).action, MergeAction.blocked);
      expect(c.useShift(-1, ShiftDirection.right).action, MergeAction.blocked);
      expect(c.useShift(99, ShiftDirection.right).action, MergeAction.blocked);
      expect(c.shifts, 1);
      expect(c.board, before);
    });

    test('cannot be used without a charge or after game over', () {
      final none = _loaded({5: 1}, shifts: 0);
      expect(none.useShift(5, ShiftDirection.left).action, MergeAction.noTool);
      final over = MergeCampController();
      over.debugLoadBoard(
        _board({5: 1}),
        nextTier: 1,
        placements: 4,
        shifts: 1,
        isGameOver: true,
      );
      expect(
        over.useShift(5, ShiftDirection.left).action,
        MergeAction.gameOver,
      );
      expect(over.shifts, 1);
    });

    test('merges from the target cell and empties the old one', () {
      // 6 steps up next to 0 and 1 and joins them at cell 2.
      final c = _loaded({0: 1, 1: 1, 6: 1});
      final result = c.useShift(6, ShiftDirection.up);
      expect(result.action, MergeAction.shifted);
      expect(c.board, _board({2: 2}));
      expect(c.lastMergeSteps.single.origin, 2);
      expect(c.mergeCount, 1);
      expect(c.score, 3 * 12 * 2);
      expect(c.highestTier, 2);
      expect(c.bestMergeChain, 1);
    });

    test('clearing a camp can open the way for a merge', () {
      final c = _loaded({0: 1, 1: 1, 2: 3, 6: 1});
      c.useShift(6, ShiftDirection.up);
      expect(c.lastShiftErased, 3);
      expect(c.board, _board({2: 2}));
    });

    test('keeps merging a chain it starts', () {
      final c = _loaded({0: 1, 1: 1, 6: 1, 3: 2, 7: 2});
      c.useShift(6, ShiftDirection.up);
      expect(c.lastMergeSteps.map((s) => s.toTier), [2, 3]);
      expect(c.board, _board({2: 3}));
      expect(c.lastMergeChain, 2);
      expect(c.highestTier, 3);
    });

    test('the cleared camp is forgotten after the next action', () {
      final c = _loaded({5: 1, 6: 2, 12: 3});
      c.useShift(5, ShiftDirection.right);
      expect(c.lastShiftErased, 2);
      c.place(0);
      expect(c.lastShiftErased, isNull);
    });

    test('a step that joins nothing merges nothing', () {
      final c = _loaded({0: 1, 1: 1, 6: 2});
      c.useShift(6, ShiftDirection.up);
      expect(c.board, _board({0: 1, 1: 1, 2: 2}));
      expect(c.lastMergeSteps, isEmpty);
      expect(c.lastMergeChain, 0);
    });

    test('does not count as a placement or draw a piece', () {
      final c = _loaded({0: 1, 1: 1, 6: 1});
      final preview = c.previewTiers;
      c.useShift(6, ShiftDirection.up);
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

    test('a 4-tile merge earns a Shift, a 3-tile one does not', () {
      // Placing at 1 joins 0, 2 and 5 into a group of four.
      final four = _loaded({0: 1, 2: 1, 5: 1}, shifts: 0);
      four.place(1);
      expect(four.lastMergeSteps.first.absorbed.length + 1, 4);
      expect(four.shifts, 1);
      final three = _loaded({0: 1, 2: 1}, shifts: 0);
      three.place(1);
      expect(three.shifts, 0);
    });

    test('the first tier 6 camp of a run earns a Shift, once', () {
      final first = _loaded({0: 5, 1: 5}, shifts: 0, nextTier: 5);
      first.place(2);
      expect(first.highestTier, 6);
      expect(first.shifts, 1);
      expect(first.lastEarnedShift, isTrue);

      // A tier 6 camp already stands: another one earns nothing.
      final again = _loaded(
        {0: 5, 1: 5, 15: 6},
        shifts: 0,
        nextTier: 5,
        highestTier: 6,
      );
      again.place(2);
      expect(again.shifts, 0);
    });

    test('the first tier 6 with a full charge keeps one and is spent', () {
      final c = _loaded({0: 5, 1: 5}, shifts: 2, nextTier: 5);
      c.place(2);
      expect(c.shifts, 2);
      expect(c.lastEarnedShift, isFalse);
      // The chance is gone for the run: highestTier already moved on.
      expect(c.highestTier, 6);
    });

    test('the tier 6 reward is not earned again after a snapshot reload', () {
      final c = _loaded({0: 5, 1: 5}, shifts: 0, nextTier: 5);
      c.place(2);
      expect(c.shifts, 1);
      final copy = MergeCampController();
      expect(copy.restoreSnapshot(c.toSnapshot()), isTrue);
      copy.useShift(2, ShiftDirection.down);
      expect(copy.shifts, 0);
      copy.debugLoadBoard(
        _board({0: 5, 1: 5, 15: 6}),
        nextTier: 5,
        placements: 5,
        highestTier: 6,
      );
      copy.place(2);
      expect(copy.shifts, 0);
    });

    test('a Shift merge that builds the first tier 6 refills the charge', () {
      final c = _loaded({0: 5, 1: 5, 6: 5});
      c.useShift(6, ShiftDirection.up);
      expect(c.highestTier, 6);
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

    test('an ordinary 3-merge earns nothing and the cap is 2', () {
      final plain = _loaded({0: 1, 1: 1}, shifts: 0);
      plain.place(2);
      expect(plain.lastMergeSteps, hasLength(1));
      expect(plain.shifts, 0);
      expect(plain.lastEarnedShift, isFalse);

      final full = _loaded({0: 1, 1: 1, 3: 1, 7: 1}, shifts: 2);
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
      for (final bad in [-1, 3, '1']) {
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
      expect(_armed(tester), isFalse);
    });

    testWidgets(
      'pick a camp, then a neighbor cell, steps it and spends the charge',
      (tester) async {
        final c = _loaded({5: 1, 10: 2});
        await _pump(tester, c);
        await tester.tap(find.byKey(const ValueKey('shift-button')));
        await tester.pump();
        expect(find.byKey(const ValueKey('shift-target')), findsNothing);
        await tester.tap(_cell(5));
        await tester.pump();
        expect(find.byKey(const ValueKey('shift-target')), findsWidgets);
        await tester.tap(_cell(6));
        await tester.pump();
        expect(c.board, _board({6: 1, 10: 2}));
        expect(c.shifts, 0);
        expect(c.placements, 4);
        expect(find.byKey(const ValueKey('shift-target')), findsNothing);
        await tester.pumpAndSettle(const Duration(seconds: 2));
      },
    );

    testWidgets('a merge started by a step plays out and settles', (
      tester,
    ) async {
      final c = _loaded({0: 1, 1: 1, 6: 1});
      await _pump(tester, c);
      await tester.tap(find.byKey(const ValueKey('shift-button')));
      await tester.pump();
      await tester.tap(_cell(6));
      await tester.pump();
      await tester.tap(_cell(2));
      await tester.pump();
      expect(c.board, _board({2: 2}));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
    });

    testWidgets('clearing the target camp plays out and settles', (
      tester,
    ) async {
      final c = _loaded({5: 1, 6: 2});
      await _pump(tester, c);
      await tester.tap(find.byKey(const ValueKey('shift-button')));
      await tester.pump();
      await tester.tap(_cell(5));
      await tester.pump();
      await tester.tap(_cell(6));
      await tester.pump();
      expect(c.board, _board({6: 1}));
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
    });

    testWidgets('empty plots are ignored and a second tap drops the pick', (
      tester,
    ) async {
      final c = _loaded({5: 1});
      await _pump(tester, c);
      await tester.tap(find.byKey(const ValueKey('shift-button')));
      await tester.pump();
      await tester.tap(_cell(9));
      await tester.pump();
      expect(c.placements, 4);
      expect(find.byKey(const ValueKey('shift-target')), findsNothing);
      await tester.tap(_cell(5));
      await tester.pump();
      expect(find.byKey(const ValueKey('shift-target')), findsWidgets);
      await tester.tap(_cell(5));
      await tester.pump();
      expect(find.byKey(const ValueKey('shift-target')), findsNothing);
      expect(c.shifts, 1);
    });

    testWidgets('only the cells the camp can step onto glow', (tester) async {
      final c = _loaded({4: 1, 9: 2});
      await _pump(tester, c);
      await tester.tap(find.byKey(const ValueKey('shift-button')));
      await tester.pump();
      await tester.tap(_cell(4));
      await tester.pump();
      // Left is a wall: right (5), up (0) and down (8); not the far camp.
      expect(find.byKey(const ValueKey('shift-target')), findsNWidgets(3));
      await tester.tap(_cell(15));
      await tester.pump();
      expect(c.shifts, 1);
      expect(c.board, _board({4: 1, 9: 2}));
    });

    testWidgets('tapping a far camp switches the pick without moving', (
      tester,
    ) async {
      final c = _loaded({5: 1, 13: 2});
      await _pump(tester, c);
      await tester.tap(find.byKey(const ValueKey('shift-button')));
      await tester.pump();
      await tester.tap(_cell(5));
      await tester.pump();
      await tester.tap(_cell(13));
      await tester.pump();
      expect(c.board, _board({5: 1, 13: 2}));
      expect(c.shifts, 1);
      // Cell 13 now has three neighbors inside the board: 9, 12 and 14.
      expect(find.byKey(const ValueKey('shift-target')), findsNWidgets(3));
      expect(find.byKey(const ValueKey('keyboard-cursor')), findsOneWidget);
    });

    testWidgets('a camp on a target cell is marked as cleared', (tester) async {
      final c = _loaded({5: 1, 6: 2});
      await _pump(tester, c);
      await tester.tap(find.byKey(const ValueKey('shift-button')));
      await tester.pump();
      await tester.tap(_cell(5));
      await tester.pump();
      expect(find.byKey(const ValueKey('shift-clear-mark')), findsOneWidget);
    });

    testWidgets('the Shift button cancels and keeps the charge', (
      tester,
    ) async {
      final c = _loaded({5: 1});
      await _pump(tester, c);
      await tester.tap(find.byKey(const ValueKey('shift-button')));
      await tester.pump();
      await tester.tap(_cell(5));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('shift-button')));
      await tester.pump();
      expect(find.byKey(const ValueKey('shift-target')), findsNothing);
      expect(_armed(tester), isFalse);
      expect(c.shifts, 1);
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
      expect(_armed(tester), isTrue);
      expect(find.text('Pick a tile'), findsNothing);
      await tester.tap(_cell(5));
      await tester.pump();
      expect(find.byKey(const ValueKey('shift-target')), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('trail-axe-button')));
      await tester.pump();
      expect(find.byKey(const ValueKey('shift-target')), findsNothing);
      expect(find.text('Pick a tile'), findsOneWidget);
    });

    testWidgets('keyboard: C arms, Enter picks the cursor camp, arrow steps', (
      tester,
    ) async {
      final c = _loaded({5: 1, 10: 2});
      await _pump(tester, c);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.pump();
      expect(_armed(tester), isTrue);
      // The first arrow only shows the cursor; then it moves 0 -> 4 -> 5.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(find.byKey(const ValueKey('keyboard-cursor')), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(find.byKey(const ValueKey('shift-target')), findsWidgets);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(c.board, _board({9: 1, 10: 2}));
      expect(c.shifts, 0);
      await tester.pumpAndSettle(const Duration(seconds: 2));
    });

    testWidgets('Esc drops the pick first, then leaves the mode', (
      tester,
    ) async {
      final c = _loaded({0: 1, 5: 2});
      await _pump(tester, c);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.pump();
      await tester.tap(_cell(5));
      await tester.pump();
      expect(find.byKey(const ValueKey('shift-target')), findsWidgets);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.byKey(const ValueKey('shift-target')), findsNothing);
      expect(_armed(tester), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(_armed(tester), isFalse);
      expect(c.shifts, 1);
    });

    testWidgets('arrows only move the cursor before a camp is picked', (
      tester,
    ) async {
      final c = _loaded({5: 1});
      await _pump(tester, c);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(c.board, _board({5: 1}));
      expect(c.shifts, 1);
    });

    testWidgets('C does nothing without a charge', (tester) async {
      await _pump(tester, _loaded({5: 1}, shifts: 0));
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.pump();
      expect(_armed(tester), isFalse);
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
      // A first run starts the guided merge without a card.
      await tester.pump();
      expect(find.text('Tap the glowing plot to merge!'), findsOneWidget);
      c.grantShift();
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('shift-button')));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.pump();
      expect(find.byKey(const ValueKey('shift-target')), findsNothing);
      expect(c.shifts, 1);
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

    testWidgets('a Shift merge that builds the first tier 6 shows a toast', (
      tester,
    ) async {
      final c = _loaded({0: 5, 1: 5, 6: 5});
      await _pump(tester, c);
      await tester.tap(find.byKey(const ValueKey('shift-button')));
      await tester.pump();
      await tester.tap(_cell(6));
      await tester.pump();
      await tester.tap(_cell(2));
      await tester.pump();
      expect(c.shifts, 1);
      expect(find.textContaining('Shift earned'), findsOneWidget);
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
      testWidgets('picking a camp fits $size', (tester) async {
        await _pump(tester, _loaded({5: 1, 13: 1}), size: size);
        await tester.tap(find.byKey(const ValueKey('shift-button')));
        await tester.pump();
        for (final cell in [5, 13]) {
          await tester.tap(_cell(cell));
          await tester.pump();
          expect(find.byKey(const ValueKey('shift-target')), findsWidgets);
          expect(tester.takeException(), isNull);
          await tester.tap(_cell(cell));
          await tester.pump();
        }
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
