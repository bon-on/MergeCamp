import 'dart:math';

import 'package:flutter/foundation.dart';

enum MergeAction { placed, merged, removed, blocked, noTool, gameOver }

class MergeResult {
  const MergeResult(this.action);

  final MergeAction action;
}

class MergeCampController extends ChangeNotifier {
  MergeCampController({Random? random, List<int>? scriptedTiers})
    : _random = random ?? Random(),
      _scriptedTiers = scriptedTiers,
      _board = List<int?>.filled(cellCount, null) {
    _previewTiers.addAll(
      List<int>.generate(previewCount, (_) => _rollNextTier()),
    );
  }

  static const int boardWidth = 4;
  static const int cellCount = boardWidth * boardWidth;
  static const int previewCount = 3;
  static const int maxTrailAxes = 2;

  /// Relative spawn weight per tier, lowest first. Lower tiers come up more
  /// often so runs lean on building up rather than on direct high-tier drops.
  static const List<int> tierSpawnWeights = [8, 6, 4, 3, 2];

  final Random _random;
  final List<int>? _scriptedTiers;
  late List<int?> _board;
  int _scriptedIndex = 0;

  int _score = 0;
  final List<int> _previewTiers = <int>[];
  int _highestTier = 1;
  int _placements = 0;
  int _trailAxes = 1;
  int _lastAwardedAxeAt = 0;
  int _lastMergeChain = 0;
  int _bestMergeChain = 0;
  bool _isGameOver = false;

  List<int?> get board => List.unmodifiable(_board);
  int get score => _score;
  int get nextTier => _previewTiers.first;
  List<int> get previewTiers => List.unmodifiable(_previewTiers);
  int get highestTier => _highestTier;
  int get placements => _placements;
  int get trailAxes => _trailAxes;
  int get lastMergeChain => _lastMergeChain;
  int get bestMergeChain => _bestMergeChain;
  bool get isGameOver => _isGameOver;
  bool get canUseTrailAxe => _trailAxes > 0 && !_isGameOver;
  int get currentTierCap => min(5, 2 + (_placements ~/ 8));
  int get goalTargetTier => min(6, 4 + (_placements ~/ 18));
  String get goalLabel => 'Raise a ${campTierName(goalTargetTier)} camp';
  double get goalProgress => (highestTier / goalTargetTier).clamp(0, 1);
  String get pressureLabel {
    if (_placements < 12) return 'Warm';
    if (_placements < 24) return 'Busy';
    if (_placements < 40) return 'Packed';
    return 'Crunch';
  }

  void restart() {
    _board = List<int?>.filled(cellCount, null);
    _score = 0;
    _highestTier = 1;
    _placements = 0;
    _trailAxes = 1;
    _lastAwardedAxeAt = 0;
    _lastMergeChain = 0;
    _bestMergeChain = 0;
    _isGameOver = false;
    _previewTiers
      ..clear()
      ..addAll(List<int>.generate(previewCount, (_) => _rollNextTier()));
    notifyListeners();
  }

  MergeResult place(int index) {
    if (_isGameOver) {
      return const MergeResult(MergeAction.gameOver);
    }
    if (_board[index] != null) {
      return const MergeResult(MergeAction.blocked);
    }

    _lastMergeChain = 0;
    final placedTier = _previewTiers.removeAt(0);
    _board[index] = placedTier;
    _placements += 1;
    _highestTier = max(_highestTier, placedTier);
    final mergeCount = _resolveMerges(index);
    _lastMergeChain = mergeCount;
    _bestMergeChain = max(_bestMergeChain, mergeCount);
    _awardTrailAxeIfReady();
    _previewTiers.add(_rollNextTier());
    if (_board.every((cell) => cell != null) && _trailAxes == 0) {
      _isGameOver = true;
    }
    notifyListeners();
    return MergeResult(
      _isGameOver
          ? MergeAction.gameOver
          : mergeCount > 0
          ? MergeAction.merged
          : MergeAction.placed,
    );
  }

  MergeResult useTrailAxe(int index) {
    if (_isGameOver) {
      return const MergeResult(MergeAction.gameOver);
    }
    if (_trailAxes == 0) {
      return const MergeResult(MergeAction.noTool);
    }
    if (_board[index] == null) {
      return const MergeResult(MergeAction.blocked);
    }

    _board[index] = null;
    _trailAxes -= 1;
    _lastMergeChain = 0;
    notifyListeners();
    return const MergeResult(MergeAction.removed);
  }

  int _resolveMerges(int origin) {
    var mergeCount = 0;
    var current = origin;

    while (true) {
      final tier = _board[current];
      if (tier == null) {
        break;
      }
      final cluster = _connectedCluster(current, tier);
      if (cluster.length < 3) {
        break;
      }

      mergeCount += 1;
      for (final index in cluster) {
        if (index != current) {
          _board[index] = null;
        }
      }

      final upgraded = tier + 1;
      _board[current] = upgraded;
      _highestTier = max(_highestTier, upgraded);
      _score += cluster.length * 12 * upgraded * mergeCount;
    }

    return mergeCount;
  }

  Set<int> _connectedCluster(int start, int tier) {
    final visited = <int>{};
    final stack = <int>[start];

    while (stack.isNotEmpty) {
      final index = stack.removeLast();
      if (!visited.add(index)) {
        continue;
      }

      for (final neighbor in _neighbors(index)) {
        if (_board[neighbor] == tier && !visited.contains(neighbor)) {
          stack.add(neighbor);
        }
      }
    }
    return visited;
  }

  Iterable<int> _neighbors(int index) sync* {
    final row = index ~/ boardWidth;
    final col = index % boardWidth;
    if (row > 0) yield index - boardWidth;
    if (row < boardWidth - 1) yield index + boardWidth;
    if (col > 0) yield index - 1;
    if (col < boardWidth - 1) yield index + 1;
  }

  @visibleForTesting
  void debugLoadBoard(
    List<int?> board, {
    required int nextTier,
    int score = 0,
    int highestTier = 1,
    int placements = 0,
    int trailAxes = 1,
    int lastAwardedAxeAt = 0,
    List<int>? previewTiers,
    bool isGameOver = false,
  }) {
    _board = List<int?>.from(board);
    _previewTiers
      ..clear()
      ..addAll(previewTiers ?? <int>[nextTier, 1, 1]);
    _score = score;
    _highestTier = highestTier;
    _placements = placements;
    _trailAxes = trailAxes;
    _lastAwardedAxeAt = lastAwardedAxeAt;
    _lastMergeChain = 0;
    _bestMergeChain = 0;
    _isGameOver = isGameOver;
  }

  void _awardTrailAxeIfReady() {
    if (_placements < 10 || _placements - _lastAwardedAxeAt < 10) {
      return;
    }
    if (_trailAxes >= maxTrailAxes) {
      _lastAwardedAxeAt = _placements;
      return;
    }
    _trailAxes += 1;
    _lastAwardedAxeAt = _placements;
  }

  int _rollNextTier() {
    final scriptedTiers = _scriptedTiers;
    if (scriptedTiers != null && _scriptedIndex < scriptedTiers.length) {
      return scriptedTiers[_scriptedIndex++];
    }
    assert(tierSpawnWeights.length >= currentTierCap);
    final weights = tierSpawnWeights.take(currentTierCap);
    var roll = _random.nextInt(weights.reduce((a, b) => a + b));
    var tier = 1;
    for (final weight in weights) {
      if (roll < weight) {
        return tier;
      }
      roll -= weight;
      tier += 1;
    }
    return tier - 1;
  }

  static String campTierName(int tier) {
    const names = [
      'Trail Tent',
      'Cook Fire',
      'Supply Shed',
      'Scout Cabin',
      'Signal Tower',
      'Base Lodge',
      'Summit Camp',
    ];
    return names[(tier - 1).clamp(0, names.length - 1)];
  }
}
