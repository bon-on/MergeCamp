import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_camp/src/game/merge_camp_controller.dart';
import 'package:merge_camp/src/meta/camp_progress.dart';
import 'package:merge_camp/src/meta/camp_theme.dart';
import 'package:merge_camp/src/meta/missions.dart';

void main() {
  test('starter set rewards the first merge without a chain requirement', () {
    final missions = MissionBoard(random: Random(0))..startStarterSet();
    final controller = MergeCampController(scriptedTiers: [1, 1, 1, 1, 1]);
    addTearDown(controller.dispose);
    expect(missions.active.map((m) => m.kind), [
      MissionKind.mergeTimes,
      MissionKind.placeTiles,
      MissionKind.buildTier,
    ]);
    for (final index in [0, 1]) {
      controller.place(index);
      expect(missions.update(controller), isEmpty);
    }
    controller.place(2);
    final completed = missions.update(controller);
    expect(completed.single.kind, MissionKind.mergeTimes);
    expect(missions.xpEarned, MissionBoard.xpPerMission);
    expect(missions.active[1].target, 6);
    expect(missions.active[2].target, 3);
  });

  test('mission resume preserves earned rewards and does not pay twice', () {
    final missions = MissionBoard(random: Random(0))..startStarterSet();
    final controller = MergeCampController(scriptedTiers: List.filled(20, 1));
    addTearDown(controller.dispose);
    for (final index in [0, 1, 2]) {
      controller.place(index);
      missions.update(controller);
    }
    final resumed = MissionBoard(random: Random(99));
    final snapshot = jsonDecode(jsonEncode(missions.toSnapshot()));
    expect(resumed.restoreSnapshot(snapshot), isTrue);
    expect(resumed.toSnapshot(), missions.toSnapshot());
    controller.place(15);
    expect(resumed.update(controller), isEmpty);
    expect(resumed.completedThisRun, 1);
    expect(resumed.xpEarned, MissionBoard.xpPerMission);
  });

  test('mission snapshots preserve later-set baselines and event trackers', () {
    final missions = MissionBoard(random: Random(0));
    final state = {
      'version': 1,
      'setNumber': 2,
      'completedThisRun': 4,
      'setBestChain': 2,
      'setBestCluster': 4,
      'active': [
        {'kind': 'placeTiles', 'target': 16, 'progress': 3, 'baseline': 20},
        {'kind': 'makeChain', 'target': 3, 'progress': 2, 'baseline': 0},
        {'kind': 'buildTier', 'target': 4, 'progress': 4, 'baseline': 0},
      ],
    };
    expect(missions.restoreSnapshot(state), isTrue);
    expect(missions.toSnapshot(), state);
    final resumed = MissionBoard(random: Random(8));
    expect(resumed.restoreSnapshot(jsonDecode(jsonEncode(state))), isTrue);
    expect(resumed.active.first.baseline, 20);
    expect(resumed.xpEarned, 120);
  });

  test('malformed mission snapshot is rejected without partial mutation', () {
    final missions = MissionBoard(random: Random(0))..startStarterSet();
    final before = missions.toSnapshot();
    final invalid = <Object?>[
      null,
      [],
      {'version': 8},
      {...before, 'setNumber': -1},
      {...before, 'setBestChain': 99},
      {...before, 'completedThisRun': 3},
      {...before, 'active': []},
      {
        ...before,
        'active': [
          {'kind': 'mergeTimes', 'target': 'bad', 'progress': 0, 'baseline': 0},
          ...((before['active'] as List).skip(1)),
        ],
      },
      {
        ...before,
        'active': [
          {'kind': 'unknown', 'target': 1, 'progress': 0, 'baseline': 0},
          ...((before['active'] as List).skip(1)),
        ],
      },
    ];
    for (final bad in invalid) {
      expect(missions.restoreSnapshot(bad), isFalse, reason: '$bad');
      expect(missions.toSnapshot(), before);
    }
  });

  test('legacy progress survives and active run travels with meta updates', () {
    final legacy = {
      'bestScore': 900,
      'totalXp': 600,
      'discoveredTiers': [1, 2, 3],
      'selectedTheme': 'autumn',
    };
    final old = CampProgress.fromJson(legacy);
    expect(old.activeRun, isNull);
    expect(old.bestScore, 900);
    final active = {
      'version': 1,
      'controller': {'score': 72},
    };
    final next = old.withActiveRun(active).withDiscovered(4);
    final loaded = CampProgress.fromJson(jsonDecode(jsonEncode(next.toJson())));
    expect(loaded.activeRun, active);
    expect(loaded.withTheme(CampTheme.summer).activeRun, active);
    expect(loaded.discoveredTiers, {1, 2, 3, 4});
    expect(loaded.withActiveRun(null).activeRun, isNull);
    expect(loaded.withActiveRun(null).bestScore, 900);
    final corrupt = CampProgress.fromJson({
      ...legacy,
      'activeRun': [1, 2],
    });
    expect(corrupt.activeRun, isNull);
    expect(corrupt.bestScore, 900);
  });

  test('settlement clears the active run in the meta envelope', () {
    final progress = const CampProgress.initial().withActiveRun({'version': 1});
    final settled = progress.applyRun(
      const RunSummary(
        score: 720,
        highestTier: 3,
        bestChain: 1,
        placements: 10,
        mergeCount: 2,
        missionXp: 30,
      ),
    );
    expect(settled.progress.activeRun, isNull);
    expect(settled.progress.bestScore, 720);
    expect(settled.xpGained, 122);
    final empty = progress.applyRun(
      const RunSummary(score: 0, highestTier: 1, bestChain: 0, placements: 0),
    );
    expect(empty.progress.activeRun, isNull);
    expect(empty.xpGained, 0);
  });

  test('zero-merge restarts never earn participation XP', () {
    final noMerge = const CampProgress.initial().applyRun(
      const RunSummary(score: 0, highestTier: 2, bestChain: 0, placements: 5),
    );
    expect(noMerge.xpGained, 0);
    final earned = const CampProgress.initial().applyRun(
      const RunSummary(
        score: 72,
        highestTier: 2,
        bestChain: 1,
        placements: 5,
        mergeCount: 1,
      ),
    );
    expect(earned.xpGained, 7 + CampProgress.participationXp);
  });

  test('invalid oversized XP cannot cause an unbounded level scan', () {
    final p = CampProgress.fromJson({'totalXp': 1e100, 'bestScore': 12});
    expect(p.level, 1);
    expect(p.bestScore, 12);
  });
}
