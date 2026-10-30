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
}
