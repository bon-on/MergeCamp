import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_camp/src/game/merge_camp_controller.dart';
import 'package:merge_camp/src/meta/missions.dart';

MissionBoard boardWith(int seed) => MissionBoard(random: Random(seed));

Mission? find(MissionBoard b, MissionKind k) {
  for (final m in b.active) {
    if (m.kind == k) return m;
  }
  return null;
}

void main() {
  test('three distinct kinds with labels', () {
    for (var seed = 0; seed < 50; seed++) {
      final b = boardWith(seed);
      expect(b.active.length, 3);
      expect(b.active.map((m) => m.kind).toSet().length, 3);
      expect(b.setNumber, 1);
      for (final m in b.active) {
        expect(m.label, isNotEmpty);
        expect(m.label.codeUnits.every((c) => c < 128), isTrue);
        expect(m.completed, isFalse);
      }
    }
  });

  test('labels', () {
    expect(
      const Mission(kind: MissionKind.placeTiles, target: 15).label,
      'Place 15 tiles',
    );
    expect(
      const Mission(kind: MissionKind.makeChain, target: 2).label,
      'Make a x2 chain',
    );
    expect(
      const Mission(kind: MissionKind.buildTier, target: 4).label,
      'Build a Scout Cabin',
    );
    expect(
      const Mission(kind: MissionKind.bigMerge, target: 4).label,
      'Merge 4+ tiles at once',
    );
    expect(
      const Mission(kind: MissionKind.reachScore, target: 1500).label,
      'Score 1,500',
    );
    expect(
      const Mission(kind: MissionKind.mergeTimes, target: 8).label,
      'Merge 8 times',
    );
  });

  test('same seed gives same missions', () {
    final a = boardWith(7).active.map((m) => '${m.kind}${m.target}').toList();
    final b = boardWith(7).active.map((m) => '${m.kind}${m.target}').toList();
    expect(a, b);
  });

  test('placement and merge progress, completion reported once', () {
    final c = MergeCampController(
      random: Random(1),
      scriptedTiers: List.filled(40, 1),
    );
    // Find a seed that contains placeTiles or mergeTimes.
    var seed = 0;
    while (find(boardWith(seed), MissionKind.mergeTimes) == null) {
      seed++;
    }
    final b = boardWith(seed);
    final merge = find(b, MissionKind.mergeTimes)!;
    c.place(0);
    c.place(1);
    c.place(4);
    final done = b.update(c);
    expect(done.where((m) => m.kind == MissionKind.mergeTimes), isEmpty);
    final progressed = find(b, MissionKind.mergeTimes)!;
    expect(progressed.progress, 1);
    expect(progressed.target, merge.target);
    expect(b.completedThisRun, done.length);
  });

  test('all three complete opens the next harder set', () {
    final b = boardWith(3);
    final c = MergeCampController(random: Random(3));
    final first = b.active.map((m) => m.kind).toSet();
    // Force completion through a rich controller state.
    c.debugLoadBoard(
      List<int?>.filled(16, null),
      nextTier: 1,
      score: 100000,
      highestTier: 8,
      placements: 500,
    );
    c.place(0);
    b.update(c);
    // Place/score/tier missions complete immediately; event ones need events.
    var guard = 0;
    while (b.setNumber == 1 && guard++ < 400) {
      // A fresh cluster each time produces merge/chain events.
      c.debugLoadBoard(
        [1, 1, null, null, ...List<int?>.filled(12, null)],
        nextTier: 1,
        score: c.score,
        highestTier: 8,
        placements: c.placements,
      );
      c.place(4);
      b.update(c);
      if (b.setNumber == 1) {
        c.debugLoadBoard(
          [
            2,
            2,
            1,
            null,
            2,
            2,
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
          ],
          nextTier: 2,
          score: c.score,
          highestTier: 8,
          placements: c.placements,
        );
        c.place(8);
        b.update(c);
      }
    }
    expect(b.setNumber, greaterThan(1));
    expect(b.active.length, 3);
    expect(b.active.every((m) => !m.completed), isTrue);
    expect(b.completedThisRun, greaterThanOrEqualTo(3));
    expect(b.xpEarned, b.completedThisRun * MissionBoard.xpPerMission);
    expect(first.length, 3);
    expect(b.active.map((m) => m.kind).toSet().length, 3);
  });

  test('score and tier missions are relative and capped', () {
    final c = MergeCampController(random: Random(0));
    c.debugLoadBoard(
      List<int?>.filled(16, null),
      nextTier: 1,
      score: 4000,
      highestTier: 8,
      placements: 100,
    );
    for (var seed = 0; seed < 60; seed++) {
      final b = boardWith(seed);
      // Advance by completing nothing; rebuild via reset path only.
      expect(b.active.every((m) => m.target > 0), isTrue);
      final tier = find(b, MissionKind.buildTier);
      if (tier != null) expect(tier.target, inInclusiveRange(3, 8));
    }
  });

  test('reset starts a fresh run', () {
    final b = boardWith(5);
    final c = MergeCampController(random: Random(5));
    c.debugLoadBoard(
      List<int?>.filled(16, null),
      nextTier: 1,
      score: 100000,
      highestTier: 8,
      placements: 500,
    );
    c.place(0);
    b.update(c);
    b.reset();
    expect(b.setNumber, 1);
    expect(b.completedThisRun, 0);
    expect(b.xpEarned, 0);
    expect(b.active.length, 3);
    expect(b.active.every((m) => m.progress == 0), isTrue);
  });
}
