import 'dart:math';

import 'package:flutter/foundation.dart';

enum MergeAction { placed, merged, blocked, gameOver }

class MergeResult {
  const MergeResult(this.action);

  final MergeAction action;
}

class MergeCampController extends ChangeNotifier {
  MergeCampController({Random? random, List<int>? scriptedTiers})
    : _random = random ?? Random(),
      _scriptedTiers = scriptedTiers,
      _board = List<int?>.filled(cellCount, null) {
    _nextTier = _rollNextTier();
  }

  static const int boardWidth = 4;
  static const int cellCount = boardWidth * boardWidth;

  final Random _random;
  final List<int>? _scriptedTiers;
  late List<int?> _board;
  int _scriptedIndex = 0;

  int _score = 0;
  int _nextTier = 1;
  int _highestTier = 1;
  int _placements = 0;
  bool _isGameOver = false;

  List<int?> get board => List.unmodifiable(_board);
  int get score => _score;
  int get nextTier => _nextTier;
  int get highestTier => _highestTier;
  int get placements => _placements;
  bool get isGameOver => _isGameOver;
  int get currentTierCap => min(5, 2 + (_placements ~/ 8));
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
    _isGameOver = false;
    _nextTier = _rollNextTier();
    notifyListeners();
  }

  MergeResult place(int index) {
    if (_isGameOver) {
      return const MergeResult(MergeAction.gameOver);
    }
    if (_board[index] != null) {
      return const MergeResult(MergeAction.blocked);
    }

    _board[index] = _nextTier;
    _placements += 1;
    _highestTier = max(_highestTier, _nextTier);
    final merged = _resolveMerges(index);
    _nextTier = _rollNextTier();
    if (_board.every((cell) => cell != null)) {
      _isGameOver = true;
    }
    notifyListeners();
    return MergeResult(
      _isGameOver
          ? MergeAction.gameOver
          : merged
          ? MergeAction.merged
          : MergeAction.placed,
    );
  }

  bool _resolveMerges(int origin) {
    var didMerge = false;
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

      didMerge = true;
      for (final index in cluster) {
        if (index != current) {
          _board[index] = null;
        }
      }

      final upgraded = tier + 1;
      _board[current] = upgraded;
      _highestTier = max(_highestTier, upgraded);
      _score += cluster.length * 12 * upgraded;
    }

    return didMerge;
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
    bool isGameOver = false,
  }) {
    _board = List<int?>.from(board);
    _nextTier = nextTier;
    _score = score;
    _highestTier = highestTier;
    _placements = placements;
    _isGameOver = isGameOver;
  }

  int _rollNextTier() {
    final scriptedTiers = _scriptedTiers;
    if (scriptedTiers != null && _scriptedIndex < scriptedTiers.length) {
      return scriptedTiers[_scriptedIndex++];
    }
    return _random.nextInt(currentTierCap) + 1;
  }
}
