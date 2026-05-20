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
      const [
        1, 2, 3, 4,
        2, 3, 4, 1,
        3, 4, 1, 2,
        4, 1, 2, null,
      ],
      nextTier: 4,
      placements: 15,
      highestTier: 4,
    );
    controller.place(15);

    expect(controller.isGameOver, isTrue);
  });
}
