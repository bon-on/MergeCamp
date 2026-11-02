import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_camp/src/game/merge_camp_controller.dart';

void main() {
  test('connected group of three merges into upgraded tile', () {
    final controller = MergeCampController(
      random: Random(0),
      scriptedTiers: [1, 1, 1],
    );

    controller.place(0);
    controller.place(1);
    final result = controller.place(4);

    expect(result.action, MergeAction.merged);
    expect(controller.board[4], 2);
    expect(controller.board[0], isNull);
    expect(controller.board[1], isNull);
    expect(controller.score, greaterThan(0));
    expect(controller.lastMergeChain, 1);
  });

  test('preview queue exposes three upcoming camp tiles', () {
    final controller = MergeCampController(
      random: Random(0),
      scriptedTiers: [1, 2, 1, 2],
    );

    expect(controller.previewTiers, [1, 2, 1]);
    final displayedNextTier = controller.nextTier;

    controller.place(0);

    expect(controller.board[0], displayedNextTier);
    expect(controller.previewTiers, [2, 1, 2]);
    expect(controller.nextTier, 2);
  });

  test(
    'trail axe clears one occupied tile before game over pressure locks in',
    () {
      final controller = MergeCampController(random: Random(2));
      controller.debugLoadBoard(
        const [1, 2, 3, 4, 2, 3, 4, 1, 3, 4, 1, 2, 4, 1, 2, null],
        nextTier: 4,
        placements: 15,
        highestTier: 4,
        trailAxes: 1,
        lastAwardedAxeAt: 15,
      );

      controller.place(15);
      final result = controller.useTrailAxe(0);

      expect(controller.isGameOver, isFalse);
      expect(result.action, MergeAction.removed);
      expect(controller.board[0], isNull);
      expect(controller.trailAxes, 0);
    },
  );

  test('trail axe recharges every ten placements up to cap', () {
    final controller = MergeCampController(random: Random(3));
    controller.debugLoadBoard(
      List<int?>.filled(MergeCampController.cellCount, null),
      nextTier: 1,
      placements: 9,
      trailAxes: 0,
    );

    controller.place(0);

    expect(controller.trailAxes, 1);
  });

  test('placement count raises tier cap over a run', () {
    final controller = MergeCampController(random: Random(1));
    controller.debugLoadBoard(
      List<int?>.filled(MergeCampController.cellCount, null),
      nextTier: 1,
      placements: 16,
    );

    expect(controller.currentTierCap, greaterThanOrEqualTo(3));
  });

  test('board full ends the run', () {
    final controller = MergeCampController(random: Random(2));
    controller.debugLoadBoard(
      const [1, 2, 3, 4, 2, 3, 4, 1, 3, 4, 1, 2, 4, 1, 2, null],
      nextTier: 4,
      placements: 15,
      highestTier: 4,
      trailAxes: 0,
      lastAwardedAxeAt: 10,
    );
    controller.place(15);

    expect(controller.isGameOver, isTrue);
  });

  test('lower tiers spawn more often than higher tiers', () {
    final controller = MergeCampController(random: Random(7));
    controller.debugLoadBoard(
      List<int?>.filled(MergeCampController.cellCount, null),
      nextTier: 1,
      placements: 40,
    );
    expect(controller.currentTierCap, 5);

    final counts = List<int>.filled(6, 0);
    for (var i = 0; i < 4000; i++) {
      controller.debugLoadBoard(
        List<int?>.filled(MergeCampController.cellCount, null),
        nextTier: 1,
        placements: 40,
      );
      controller.place(0);
      counts[controller.previewTiers.last] += 1;
    }

    for (var tier = 1; tier < 5; tier++) {
      expect(counts[tier], greaterThan(counts[tier + 1]), reason: 'tier $tier');
    }
    expect(counts[5], greaterThan(0));
  });

  group('presentation helpers', () {
    test('single merge records one step', () {
      final controller = MergeCampController(
        random: Random(0),
        scriptedTiers: [1, 1, 1],
      );
      controller.place(0);
      expect(controller.lastMergeSteps, isEmpty);
      controller.place(1);
      controller.place(4);

      expect(controller.lastPlacedIndex, 4);
      final steps = controller.lastMergeSteps;
      expect(steps.length, 1);
      expect(steps.single.origin, 4);
      expect(steps.single.absorbed.toSet(), {0, 1});
      expect(steps.single.fromTier, 1);
      expect(steps.single.toTier, 2);
      expect(steps.single.chainIndex, 1);
      expect(steps.single.points, controller.score);
      expect(controller.mergeCount, 1);
      expect(controller.occupiedCount, 1);
    });

    test('chained merges record ordered steps and reset next placement', () {
      final controller = MergeCampController(
        random: Random(0),
        scriptedTiers: [1],
      );
      // Placing tier 1 at 2 merges 0,1,2 into tier 2 at 2, which joins 6,10.
      controller.debugLoadBoard([
        1,
        1,
        null,
        null,
        null,
        null,
        2,
        null,
        null,
        null,
        2,
        null,
        null,
        null,
        null,
        null,
      ], nextTier: 1);
      controller.place(2);
      final steps = controller.lastMergeSteps;
      expect(steps.map((s) => s.chainIndex), [1, 2]);
      expect(steps[1].fromTier, 2);
      expect(steps[1].toTier, 3);
      expect(steps[1].absorbed.toSet(), {6, 10});
      expect(steps.fold<int>(0, (a, s) => a + s.points), controller.score);
      expect(controller.mergeCount, 2);

      controller.place(15);
      expect(controller.lastMergeSteps, isEmpty);
      expect(controller.lastPlacedIndex, 15);
      controller.restart();
      expect(controller.lastMergeSteps, isEmpty);
      expect(controller.lastPlacedIndex, isNull);
      expect(controller.mergeCount, 0);
    });

    test('grantTrailAxe respects cap and game over', () {
      final controller = MergeCampController(random: Random(0));
      var notified = 0;
      controller.addListener(() => notified++);
      expect(controller.trailAxes, 1);
      expect(controller.grantTrailAxe(), isTrue);
      expect(controller.trailAxes, MergeCampController.maxTrailAxes);
      expect(controller.grantTrailAxe(), isFalse);
      expect(notified, 1);

      controller.debugLoadBoard(
        List<int?>.filled(16, 1),
        nextTier: 1,
        trailAxes: 0,
        isGameOver: true,
      );
      expect(controller.grantTrailAxe(), isFalse);
      expect(controller.trailAxes, 0);
    });

    test('granted axe on a full board keeps the run alive', () {
      final controller = MergeCampController(random: Random(0));
      // Checkerboard of 1/2 with one hole: no merge possible.
      final board = <int?>[
        for (var i = 0; i < 16; i++) ((i ~/ 4 + i % 4).isEven ? 1 : 2),
      ];
      board[0] = null;
      controller.debugLoadBoard(board, nextTier: 3, trailAxes: 0);
      expect(controller.grantTrailAxe(), isTrue);
      expect(controller.place(0).action, MergeAction.placed);
      expect(controller.isGameOver, isFalse);
      expect(controller.occupiedCount, 16);
    });

    test('addBonusScore adds and notifies', () {
      final controller = MergeCampController(random: Random(0));
      var notified = 0;
      controller.addListener(() => notified++);
      controller.addBonusScore(150);
      expect(controller.score, 150);
      expect(notified, 1);
      controller.addBonusScore(0);
      expect(controller.score, 150);
    });

    test('camp tier names cover eight tiers and clamp', () {
      expect(MergeCampController.maxCampTier, 8);
      expect(MergeCampController.campTierName(8), 'Star Observatory');
      expect(MergeCampController.campTierName(9), 'Star Observatory');
      expect(MergeCampController.campTierName(0), 'Trail Tent');
    });
  });
}
