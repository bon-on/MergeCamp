import 'dart:math';

import '../game/merge_camp_controller.dart';

enum MissionKind {
  placeTiles,
  makeChain,
  buildTier,
  bigMerge,
  reachScore,
  mergeTimes,
}

/// One in-run goal. Snapshots are immutable; [MissionBoard] replaces them.
class Mission {
  const Mission({
    required this.kind,
    required this.target,
    this.progress = 0,
    this.baseline = 0,
  });

  final MissionKind kind;

  /// Meaning depends on [kind]: tile count, chain length, camp tier, cluster
  /// size, absolute score or merge count.
  final int target;

  /// Always within 0..[target].
  final int progress;

  /// Run state when the mission was created (placements, merges), kept so
  /// progress is relative to that moment. Not shown in the UI.
  final int baseline;

  bool get completed => progress >= target;

  String get label {
    switch (kind) {
      case MissionKind.placeTiles:
        return 'Place $target tiles';
      case MissionKind.makeChain:
        return 'Make a x$target chain';
      case MissionKind.buildTier:
        return 'Build a ${MergeCampController.campTierName(target)}';
      case MissionKind.bigMerge:
        return 'Merge $target+ tiles at once';
      case MissionKind.reachScore:
        return 'Score ${_groupThousands(target)}';
      case MissionKind.mergeTimes:
        return 'Merge $target times';
    }
  }

  Mission _withProgress(int value) => Mission(
    kind: kind,
    target: target,
    progress: value.clamp(0, target),
    baseline: baseline,
  );

  static String _groupThousands(int value) {
    final digits = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }
}

/// Three active missions per run; finishing all three opens a harder set.
///
/// Missions are relative to the run state at creation, so they are always
/// achievable. Rewards (Trail Axe or bonus score) are applied by the screen.
class MissionBoard {
  MissionBoard({Random? random}) : _random = random ?? Random() {
    _active = _buildSet(placements: 0, mergeCount: 0, score: 0, highestTier: 1);
  }

  static const int xpPerMission = 30;
  static const int missionsPerSet = 3;

  final Random _random;
  late List<Mission> _active;
  int _setNumber = 1;
  int _completedThisRun = 0;

  // Per-set trackers for event style missions.
  int _setBestChain = 0;
  int _setBestCluster = 0;

  List<Mission> get active => List.unmodifiable(_active);
  int get setNumber => _setNumber;
  int get completedThisRun => _completedThisRun;
  int get xpEarned => _completedThisRun * xpPerMission;

  /// Starts a fresh run: set 1, no completions.
  void reset() {
    _setNumber = 1;
    _completedThisRun = 0;
    _active = _buildSet(placements: 0, mergeCount: 0, score: 0, highestTier: 1);
  }

  /// Call after every successful placement. Returns the missions that were
  /// newly completed by it. If that finishes the set, the next set replaces
  /// [active] before this returns.
  List<Mission> update(MergeCampController controller) {
    _setBestChain = max(_setBestChain, controller.lastMergeChain);
    for (final step in controller.lastMergeSteps) {
      _setBestCluster = max(_setBestCluster, step.absorbed.length + 1);
    }

    final newlyCompleted = <Mission>[];
    for (var i = 0; i < _active.length; i++) {
      final mission = _active[i];
      if (mission.completed) continue;
      final updated = mission._withProgress(_progressOf(mission, controller));
      _active[i] = updated;
      if (updated.completed) {
        newlyCompleted.add(updated);
        _completedThisRun += 1;
      }
    }

    if (_active.every((m) => m.completed)) {
      _setNumber += 1;
      _active = _buildSet(
        placements: controller.placements,
        mergeCount: controller.mergeCount,
        score: controller.score,
        highestTier: controller.highestTier,
      );
    }
    return newlyCompleted;
  }

  int _progressOf(Mission mission, MergeCampController c) {
    switch (mission.kind) {
      case MissionKind.placeTiles:
        return c.placements - mission.baseline;
      case MissionKind.makeChain:
        return _setBestChain;
      case MissionKind.buildTier:
        return c.highestTier;
      case MissionKind.bigMerge:
        return _setBestCluster;
      case MissionKind.reachScore:
        return c.score;
      case MissionKind.mergeTimes:
        return c.mergeCount - mission.baseline;
    }
  }

  List<Mission> _buildSet({
    required int placements,
    required int mergeCount,
    required int score,
    required int highestTier,
  }) {
    _setBestChain = 0;
    _setBestCluster = 0;
    final s = _setNumber;
    final kinds = List<MissionKind>.of(MissionKind.values);
    if (highestTier >= MergeCampController.maxCampTier) {
      kinds.remove(MissionKind.buildTier);
    }
    // Fisher-Yates with the injected Random keeps seeded boards deterministic.
    for (var i = kinds.length - 1; i > 0; i--) {
      final j = _random.nextInt(i + 1);
      final tmp = kinds[i];
      kinds[i] = kinds[j];
      kinds[j] = tmp;
    }
    return [
      for (final kind in kinds.take(missionsPerSet))
        switch (kind) {
          MissionKind.placeTiles => Mission(
            kind: kind,
            target: 8 + 4 * s,
            baseline: placements,
          ),
          MissionKind.makeChain => Mission(kind: kind, target: min(5, 1 + s)),
          MissionKind.buildTier => Mission(
            kind: kind,
            target: min(
              MergeCampController.maxCampTier,
              max(highestTier + 1, 3),
            ),
          ),
          MissionKind.bigMerge => Mission(kind: kind, target: min(6, 3 + s)),
          MissionKind.reachScore => Mission(
            kind: kind,
            target: score + 300 + 250 * s,
          ),
          MissionKind.mergeTimes => Mission(
            kind: kind,
            target: 2 + 2 * s,
            baseline: mergeCount,
          ),
        },
    ];
  }
}
