import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:merge_camp/src/game/how_to_play.dart';
import 'package:merge_camp/src/game/merge_camp_controller.dart';
import 'package:merge_camp/src/game/merge_camp_screen.dart';
import 'package:merge_camp/src/game/tool_hints.dart';
import 'package:merge_camp/src/meta/camp_progress_store.dart';

class _SeenStore extends HowToPlayStore {
  const _SeenStore();
  @override
  Future<bool> loadSeen() async => true;
  @override
  Future<void> markSeen() async {}
}

class _MemoryHints extends ToolHintStore {
  _MemoryHints([Set<ToolHint>? seen]) : seen = seen ?? <ToolHint>{};
  final Set<ToolHint> seen;
  @override
  Future<Set<ToolHint>> loadSeen() async => {...seen};
  @override
  Future<void> markSeen(ToolHint hint) async => seen.add(hint);
}

const _shiftHint = ValueKey('tool-hint');

Finder _cell(int index) => find
    .descendant(
      of: find.byType(GridView),
      matching: find.byType(GestureDetector),
    )
    .at(index);

Future<void> _pump(
  WidgetTester tester,
  MergeCampController controller,
  ToolHintStore store, {
  Size size = const Size(800, 1400),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: MergeCampScreen(
        controller: controller,
        howToPlayStore: const _SeenStore(),
        toolHintStore: store,
        progressStore: MemoryCampProgressStore(),
        animateArt: false,
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

List<int?> _sparse() {
  final board = List<int?>.filled(MergeCampController.cellCount, null);
  board[0] = 1;
  board[5] = 2;
  return board;
}

void main() {
  testWidgets('the first Shift shows its hint once', (tester) async {
    final controller = MergeCampController();
    final store = _MemoryHints();
    addTearDown(controller.dispose);
    await _pump(tester, controller, store);
    expect(find.byKey(_shiftHint), findsNothing);

    controller.debugLoadBoard(_sparse(), nextTier: 1, placements: 5, shifts: 1);
    controller.addBonusScore(1);
    await tester.pump();
    expect(find.byKey(_shiftHint), findsOneWidget);
    expect(find.text(ToolHint.shift.text), findsOneWidget);
    expect(store.seen, {ToolHint.shift});

    // Visible after 3 more placements, gone with the 4th.
    for (final cell in [1, 2, 3]) {
      controller.place(cell);
      await tester.pump();
    }
    expect(find.byKey(_shiftHint), findsOneWidget);
    controller.place(4);
    await tester.pump();
    expect(find.byKey(_shiftHint), findsNothing);
  });

  testWidgets('a seen Shift hint stays hidden on a new device launch', (
    tester,
  ) async {
    final controller = MergeCampController();
    addTearDown(controller.dispose);
    await _pump(tester, controller, _MemoryHints({ToolHint.shift}));
    controller.debugLoadBoard(_sparse(), nextTier: 1, placements: 5, shifts: 1);
    controller.addBonusScore(1);
    await tester.pump();
    expect(find.byKey(_shiftHint), findsNothing);
  });

  testWidgets('the Trail Axe hint waits for the danger level', (tester) async {
    final controller = MergeCampController();
    final store = _MemoryHints();
    addTearDown(controller.dispose);
    await _pump(tester, controller, store);

    controller.debugLoadBoard(_sparse(), nextTier: 1, placements: 5);
    controller.addBonusScore(1);
    await tester.pump();
    expect(find.byKey(_shiftHint), findsNothing);

    final full = List<int?>.generate(
      MergeCampController.cellCount,
      (i) => i < 13 ? ((i ~/ 4 + i % 4).isEven ? 1 : 2) : null,
    );
    controller.debugLoadBoard(full, nextTier: 3, placements: 14);
    controller.addBonusScore(1);
    await tester.pump();
    expect(find.text(ToolHint.axe.text), findsOneWidget);
    expect(store.seen, {ToolHint.axe});
  });

  testWidgets('the hint fits a 320px wide screen', (tester) async {
    final controller = MergeCampController();
    addTearDown(controller.dispose);
    await _pump(tester, controller, _MemoryHints(), size: const Size(320, 640));
    controller.debugLoadBoard(_sparse(), nextTier: 1, placements: 5, shifts: 1);
    controller.addBonusScore(1);
    await tester.pump();
    expect(find.byKey(_shiftHint), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('the store keeps its bits across loads', () async {
    SharedPreferences.setMockInitialValues({});
    const store = ToolHintStore();
    expect(await store.loadSeen(), isEmpty);
    await store.markSeen(ToolHint.axe);
    await store.markSeen(ToolHint.shift);
    expect(await store.loadSeen(), {ToolHint.shift, ToolHint.axe});
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(ToolHintStore.key), 3);
  });

  testWidgets('a second Shift after the hint does not bring it back', (
    tester,
  ) async {
    final controller = MergeCampController();
    final store = _MemoryHints();
    addTearDown(controller.dispose);
    await _pump(tester, controller, store);
    controller.debugLoadBoard(_sparse(), nextTier: 1, placements: 5, shifts: 1);
    controller.addBonusScore(1);
    await tester.pump();
    expect(find.byKey(_shiftHint), findsOneWidget);

    // Use the Shift from the screen, earn another one: no new hint.
    await tester.tap(find.byKey(const ValueKey('shift-button')));
    await tester.pump();
    expect(find.byKey(_shiftHint), findsNothing);
    await tester.tap(_cell(0));
    await tester.pump();
    await tester.tap(_cell(1));
    await tester.pump();
    controller.grantShift();
    controller.addBonusScore(1);
    await tester.pump();
    expect(find.byKey(_shiftHint), findsNothing);
  });

  testWidgets('shift mode hides the hint and cancelling shows it again', (
    tester,
  ) async {
    final controller = MergeCampController();
    addTearDown(controller.dispose);
    await _pump(tester, controller, _MemoryHints());
    controller.debugLoadBoard(_sparse(), nextTier: 1, placements: 5, shifts: 1);
    controller.addBonusScore(1);
    await tester.pump();
    expect(find.byKey(_shiftHint), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('shift-button')));
    await tester.pump();
    expect(find.byKey(_shiftHint), findsNothing);
    await tester.tap(find.byKey(const ValueKey('shift-button')));
    await tester.pump();
    expect(find.byKey(_shiftHint), findsOneWidget);
  });

  testWidgets('using the Trail Axe drops its hint', (tester) async {
    final controller = MergeCampController();
    addTearDown(controller.dispose);
    await _pump(tester, controller, _MemoryHints());
    final full = List<int?>.generate(
      MergeCampController.cellCount,
      (i) => i < 13 ? ((i ~/ 4 + i % 4).isEven ? 1 : 2) : null,
    );
    controller.debugLoadBoard(full, nextTier: 3, placements: 14);
    controller.addBonusScore(1);
    await tester.pump();
    expect(find.text(ToolHint.axe.text), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('trail-axe-button')));
    await tester.pump();
    await tester.tap(_cell(0));
    await tester.pump();
    expect(find.text(ToolHint.axe.text), findsNothing);
  });

  testWidgets('game over and restart clear the hint', (tester) async {
    final controller = MergeCampController();
    addTearDown(controller.dispose);
    await _pump(tester, controller, _MemoryHints());
    controller.debugLoadBoard(_sparse(), nextTier: 1, placements: 5, shifts: 1);
    controller.addBonusScore(1);
    await tester.pump();
    expect(find.byKey(_shiftHint), findsOneWidget);

    controller.restart();
    await tester.pump();
    expect(find.byKey(_shiftHint), findsNothing);
  });
}
