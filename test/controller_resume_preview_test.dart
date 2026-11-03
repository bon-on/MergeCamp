import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_camp/src/game/merge_camp_controller.dart';

class _CountingRandom implements Random {
  int calls = 0;
  @override
  int nextInt(int max) {
    calls++;
    return 0;
  }

  @override
  bool nextBool() => nextInt(2) == 0;
  @override
  double nextDouble() => nextInt(100) / 100;
}

List<Object> _steps(List<MergeStep> steps) => [
  for (final step in steps)
    [
      step.origin,
      step.absorbed,
      step.fromTier,
      step.toTier,
      step.points,
      step.chainIndex,
    ],
];

MergeCampController _terminalController() {
  final c = MergeCampController(random: Random(1));
  c.debugLoadBoard(
    [1, 2, 1, 2, 2, 1, 2, 1, 1, 2, 1, 2, 2, 1, 2, null],
    nextTier: 3,
    previewTiers: [3, 1, 2],
    score: 500,
    placements: 15,
    highestTier: 2,
    trailAxes: 0,
    lastAwardedAxeAt: 10,
  );
  c.place(15);
  return c;
}

void main() {
  test(
    'live snapshot roundtrip preserves tools, pressure and visible pieces',
    () {
      final original = MergeCampController(random: _CountingRandom());
      final restored = MergeCampController(random: Random(999));
      addTearDown(original.dispose);
      addTearDown(restored.dispose);
      original.startGuidedRun();
      original.place(2);
      for (var n = 0; n < 11; n++) {
        original.place(original.board.indexOf(null));
      }
      original.useTrailAxe(original.board.indexWhere((t) => t != null));
      final snapshot = jsonDecode(jsonEncode(original.toSnapshot()));
      var notifications = 0;
      restored.addListener(() => notifications++);
      expect(restored.restoreSnapshot(snapshot), isTrue);
      expect(restored.toSnapshot(), original.toSnapshot());
      expect(restored.currentTierCap, original.currentTierCap);
      expect(restored.lastPlacedIndex, isNull);
      expect(restored.lastMergeSteps, isEmpty);
      expect(notifications, 1);

      final firstPreview = original.nextTier;
      final empty = restored.board.indexOf(null);
      final predicted = restored.previewPlacement(empty);
      restored.place(empty);
      expect(_steps(restored.lastMergeSteps), _steps(predicted));
      if (predicted.isEmpty) expect(restored.board[empty], firstPreview);
    },
  );

  test('snapshot result is detached from controller lists', () {
    final c = MergeCampController(random: Random(0));
    addTearDown(c.dispose);
    final snapshot = c.toSnapshot();
    (snapshot['board'] as List)[0] = 8;
    (snapshot['previewTiers'] as List)[0] = 5;
    expect(c.board[0], isNull);
    expect(c.nextTier, lessThanOrEqualTo(2));
  });

  test('malformed snapshots leave state and listeners untouched', () {
    final c = MergeCampController(random: Random(0));
    addTearDown(c.dispose);
    c.startGuidedRun();
    c.place(2);
    final before = c.toSnapshot();
    var notifications = 0;
    c.addListener(() => notifications++);
    final badFields = <String, Object?>{
      'version': 2,
      'board': List.filled(15, null),
      'previewTiers': [1, 2, 99],
      'score': double.nan,
      'highestTier': 0,
      'placements': -1,
      'trailAxes': 3,
      'lastAwardedAxeAt': 10,
      'lastMergeChain': 8,
      'bestMergeChain': 7,
      'mergeCount': 0,
      'isGameOver': true,
    };
    for (final field in badFields.entries) {
      expect(
        c.restoreSnapshot({...before, field.key: field.value}),
        isFalse,
        reason: field.key,
      );
      expect(c.toSnapshot(), before);
    }
    expect(c.restoreSnapshot(null), isFalse);
    expect(c.restoreSnapshot({'version': 1}), isFalse);
    expect(notifications, 0);
  });

  test(
    'terminal/live inconsistencies are rejected; terminal can roundtrip',
    () {
      final terminal = _terminalController();
      final restored = MergeCampController();
      addTearDown(terminal.dispose);
      addTearDown(restored.dispose);
      expect(terminal.isGameOver, isTrue);
      final data = terminal.toSnapshot();
      expect(restored.restoreSnapshot({...data, 'isGameOver': false}), isFalse);
      expect(restored.restoreSnapshot({...data, 'trailAxes': 1}), isFalse);
      expect(restored.restoreSnapshot(data), isTrue);
      expect(restored.toSnapshot(), data);
      expect(restored.previewPlacement(0), isEmpty);
    },
  );

  test(
    'practice has one guaranteed real merge and can be restored before it',
    () {
      final c = MergeCampController(random: Random(3));
      final restored = MergeCampController();
      addTearDown(c.dispose);
      addTearDown(restored.dispose);
      c.startGuidedRun();
      expect(c.placements, 0);
      expect(c.score, 0);
      expect(c.occupiedCount, 2);
      expect(restored.restoreSnapshot(c.toSnapshot()), isTrue);
      expect(restored.place(2).action, MergeAction.merged);
      expect(restored.board[0], isNull);
      expect(restored.board[1], isNull);
      expect(restored.board[2], 2);
      expect(restored.score, 72);
      expect(restored.placements, 1);
      expect(restored.mergeCount, 1);
    },
  );

  test('preview is pure and matches actual cluster and chain resolution', () {
    final random = _CountingRandom();
    final c = MergeCampController(random: random);
    addTearDown(c.dispose);
    for (final board in <List<int?>>[
      List<int?>.filled(16, null),
      [
        null,
        1,
        1,
        1,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
      ],
      [
        null,
        1,
        1,
        null,
        2,
        2,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
      ],
    ]) {
      c.debugLoadBoard(board, nextTier: 1, highestTier: 2);
      final before = c.toSnapshot();
      final draws = random.calls;
      var notifications = 0;
      void listener() => notifications++;
      c.addListener(listener);
      final predicted = c.previewPlacement(0);
      expect(_steps(c.previewPlacement(0)), _steps(predicted));
      expect(c.toSnapshot(), before);
      expect(random.calls, draws);
      expect(notifications, 0);
      final points = predicted.fold<int>(0, (sum, step) => sum + step.points);
      c.place(0);
      expect(_steps(c.lastMergeSteps), _steps(predicted));
      expect(c.score, points);
      c.removeListener(listener);
    }
    expect(c.lastMergeSteps.length, 2);
    expect(c.previewPlacement(-1), isEmpty);
    expect(c.previewPlacement(16), isEmpty);
    expect(c.previewPlacement(0), isEmpty);
  });

  test('final mission bonus credits score without reviving terminal run', () {
    final c = _terminalController();
    addTearDown(c.dispose);
    final score = c.score;
    c.addFinalMissionBonus(150);
    expect(c.score, score + 150);
    expect(c.isGameOver, isTrue);
    expect(c.trailAxes, 0);
    c.addFinalMissionBonus(-150);
    expect(c.score, score + 150);
    c.restart();
    c.addFinalMissionBonus(150);
    expect(c.score, 0);
  });
}
