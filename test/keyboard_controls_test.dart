import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_camp/src/game/merge_camp_controller.dart';
import 'package:merge_camp/src/game/merge_camp_screen.dart';

Future<MergeCampController> _pump(
  WidgetTester tester, {
  List<int>? scripted,
  Size size = const Size(800, 1400),
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
  final controller = MergeCampController(
    random: Random(0),
    scriptedTiers: scripted,
  );
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(home: MergeCampScreen(controller: controller)),
  );
  await tester.pump();
  return controller;
}

/// Lets the screen's in-flight feedback (haptics/audio channels) finish.
Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await tester.pump();
}

final _cursor = find.byKey(const ValueKey('keyboard-cursor'));

void main() {
  testWidgets('cursor is hidden until a key is pressed', (tester) async {
    await _pump(tester);
    expect(_cursor, findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(_cursor, findsOneWidget);
  });

  testWidgets('arrows and WASD move the cursor and clamp at edges', (
    tester,
  ) async {
    final controller = await _pump(tester, scripted: [1, 1, 1, 1]);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown); // reveal at 0
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft); // clamped
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp); // clamped
    await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(controller.board[5], isNotNull);
    expect(controller.placements, 1);

    await _settle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(controller.board[0], isNotNull);
    expect(controller.placements, 2);
  });

  testWidgets('Enter on an occupied cell is rejected', (tester) async {
    final controller = await _pump(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter); // reveal
    await tester.sendKeyEvent(LogicalKeyboardKey.enter); // place at 0
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter); // occupied
    await tester.pump();
    expect(controller.placements, 1);
  });

  testWidgets('X uses the trail axe on the cursor cell', (tester) async {
    final controller = await _pump(tester);
    controller.debugLoadBoard(
      const [1, 2, 3, 4, 2, 3, 4, 1, 3, 4, 1, 2, 4, 1, 2, null],
      nextTier: 4,
      placements: 3,
      highestTier: 4,
      trailAxes: 1,
      lastAwardedAxeAt: 3,
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyX); // reveal
    await tester.sendKeyEvent(LogicalKeyboardKey.keyX); // axe cell 0
    await tester.pump();

    expect(controller.board[0], isNull);
    expect(controller.trailAxes, 0);
  });

  testWidgets('X without an axe leaves the board untouched', (tester) async {
    final controller = await _pump(tester);
    controller.debugLoadBoard(
      const [1, 2, 3, 4, 2, 3, 4, 1, 3, 4, 1, 2, 4, 1, 2, null],
      nextTier: 4,
      placements: 3,
      highestTier: 4,
      trailAxes: 0,
      lastAwardedAxeAt: 3,
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyX); // reveal
    await tester.sendKeyEvent(LogicalKeyboardKey.keyX);
    await tester.pump();
    expect(controller.board[0], 1);
  });

  testWidgets('R restarts the run', (tester) async {
    final controller = await _pump(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(controller.placements, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await tester.pump();
    expect(controller.placements, 0);
    expect(controller.board.every((tier) => tier == null), isTrue);
  });

  testWidgets('tapping a cell hides the keyboard cursor', (tester) async {
    await _pump(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(_cursor, findsOneWidget);

    await tester.tap(
      find
          .descendant(
            of: find.byType(GridView),
            matching: find.byType(GestureDetector),
          )
          .at(3),
    );
    await tester.pump();
    expect(_cursor, findsNothing);
  });

  testWidgets('Ctrl+R does not restart the run', (tester) async {
    final controller = await _pump(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(controller.placements, 1);
  });

  for (final size in const [
    Size(1280, 720),
    Size(1280, 672), // 720 minus the hub nav bar
    Size(1366, 768),
    Size(390, 844),
  ]) {
    testWidgets('layout fits $size without overflow', (tester) async {
      await _pump(tester, size: size);
      expect(tester.takeException(), isNull);
      final board = tester.getRect(find.byType(GridView));
      expect(board.bottom, lessThanOrEqualTo(size.height));
      expect(board.height, greaterThan(300));
    });
  }
}
