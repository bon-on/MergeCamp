import 'dart:math';

import 'package:flutter/foundation.dart';

import '../meta/daily_camp.dart';

enum MergeAction { placed, merged, removed, shifted, blocked, noTool, gameOver }

/// Direction a camp steps in when a Shift is used.
enum ShiftDirection { up, down, left, right }

/// The camp a Shift moved, for presentation.
class ShiftMove {
  const ShiftMove({required this.from, required this.to, required this.tier});

  final int from;
  final int to;
  final int tier;
}

class MergeResult {
  const MergeResult(this.action);

  final MergeAction action;
}

/// One merge inside a placement, for presentation (absorb animation, popups).
class MergeStep {
  const MergeStep({
    required this.origin,
    required this.absorbed,
    required this.fromTier,
    required this.toTier,
    required this.points,
    required this.chainIndex,
  });

  /// Cell that received the upgraded tile.
  final int origin;

  /// Cells that were cleared into [origin] (excludes [origin]).
  final List<int> absorbed;
  final int fromTier;
  final int toTier;
  final int points;

  /// 1-based position of this merge in the chain started by one placement.
  final int chainIndex;
}

class MergeCampController extends ChangeNotifier {
  MergeCampController({Random? random, List<int>? scriptedTiers, int? dailyDay})
    : _baseRandom = random ?? Random(),
      _random = dailyDay == null
          ? (random ?? Random())
          : SeededRandom(dailySeed(dailyDay)),
      _dailyDay = dailyDay,
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

  /// Shift (step one camp one cell) holds one charge at most.
  static const int maxShifts = 1;

  /// A single placement merging this many tiles at once earns a Shift.
  static const int bigShiftCluster = 5;

  /// A single placement chaining this many merges earns a Shift.
  static const int chainForShift = 3;

  /// Highest camp tier with its own name and illustration.
  static const int maxCampTier = 8;

  /// Relative spawn weight per tier, lowest first. Lower tiers come up more
  /// often so runs lean on building up rather than on direct high-tier drops.
  static const List<int> tierSpawnWeights = [8, 6, 4, 3, 2];

  // Random of free play; a daily run swaps in a date-seeded one.
  final Random _baseRandom;
  Random _random;
  int? _dailyDay;

  /// Random draws taken by this run's piece rolls (resumes a daily run).
  int _draws = 0;
  final List<int>? _scriptedTiers;
  late List<int?> _board;
  int _scriptedIndex = 0;

  int _score = 0;
  final List<int> _previewTiers = <int>[];
  int _highestTier = 1;
  int _placements = 0;
  int _trailAxes = 1;
  int _lastAwardedAxeAt = 0;
  int _shifts = 0;
  bool _lastEarnedShift = false;
  List<ShiftMove> _lastShiftMoves = const <ShiftMove>[];
  int? _lastShiftErased;
  int _lastMergeChain = 0;
  int _bestMergeChain = 0;
  bool _isGameOver = false;
  int _mergeCount = 0;
  int? _lastPlacedIndex;
  List<MergeStep> _lastMergeSteps = const <MergeStep>[];

  /// Merge steps of the most recent [place]; empty otherwise.
  List<MergeStep> get lastMergeSteps => _lastMergeSteps;

  /// Cell of the most recent successful [place], or null.
  int? get lastPlacedIndex => _lastPlacedIndex;
  int get occupiedCount => _board.where((cell) => cell != null).length;

  /// Total merge steps in this run.
  int get mergeCount => _mergeCount;

  List<int?> get board => List.unmodifiable(_board);
  int get score => _score;
  int get nextTier => _previewTiers.first;
  List<int> get previewTiers => List.unmodifiable(_previewTiers);
  int get highestTier => _highestTier;
  int get placements => _placements;
  int get trailAxes => _trailAxes;
  int get shifts => _shifts;
  bool get canUseShift => _shifts > 0 && !_isGameOver;

  /// Whether the most recent [place] earned a Shift by itself.
  bool get lastEarnedShift => _lastEarnedShift;

  /// The camp moved by the most recent [useShift]; empty otherwise.
  List<ShiftMove> get lastShiftMoves => _lastShiftMoves;

  /// Tier of the camp the most recent [useShift] cleared at its target.
  int? get lastShiftErased => _lastShiftErased;
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

  /// Day of the Daily Camp run in progress, null in free play.
  int? get dailyDay => _dailyDay;

  void restart() {
    _resetRun();
    notifyListeners();
  }

  /// Starts today's Daily Camp: the same piece sequence for every player.
  /// Restarting afterwards replays that sequence.
  void startDaily(int day) {
    _dailyDay = day;
    _resetRun();
    notifyListeners();
  }

  /// Back to a normal run with a random sequence.
  void startFreePlay() {
    _dailyDay = null;
    _resetRun();
    notifyListeners();
  }

  void _resetRun() {
    final day = _dailyDay;
    _random = day == null ? _baseRandom : SeededRandom(dailySeed(day));
    _draws = 0;
    _board = List<int?>.filled(cellCount, null);
    _score = 0;
    _highestTier = 1;
    _placements = 0;
    _trailAxes = 1;
    _lastAwardedAxeAt = 0;
    _shifts = 0;
    _lastEarnedShift = false;
    _lastShiftMoves = const <ShiftMove>[];
    _lastShiftErased = null;
    _lastMergeChain = 0;
    _bestMergeChain = 0;
    _isGameOver = false;
    _mergeCount = 0;
    _lastPlacedIndex = null;
    _lastMergeSteps = const <MergeStep>[];
    _previewTiers
      ..clear()
      ..addAll(List<int>.generate(previewCount, (_) => _rollNextTier()));
  }

  /// The first merge exercise is a real run: the two starter tents do not
  /// count as player placements or earn points on their own.
  void startGuidedRun() {
    _resetRun();
    _board[0] = 1;
    _board[1] = 1;
    _previewTiers[0] = 1;
    notifyListeners();
  }

  /// Predicts a placement without consuming a piece, a random draw or input.
  List<MergeStep> previewPlacement(int index) {
    if (_isGameOver ||
        index < 0 ||
        index >= cellCount ||
        _board[index] != null) {
      return const <MergeStep>[];
    }
    final simulated = List<int?>.of(_board)..[index] = nextTier;
    return List.unmodifiable(_resolveMergeSteps(simulated, index));
  }

  /// Only persistent rule state is saved; transient animation events are not.
  Map<String, dynamic> toSnapshot() => {
    'version': 1,
    'board': List<int?>.of(_board),
    'previewTiers': List<int>.of(_previewTiers),
    'score': _score,
    'highestTier': _highestTier,
    'placements': _placements,
    'trailAxes': _trailAxes,
    'lastAwardedAxeAt': _lastAwardedAxeAt,
    'shifts': _shifts,
    'lastMergeChain': _lastMergeChain,
    'bestMergeChain': _bestMergeChain,
    'mergeCount': _mergeCount,
    'isGameOver': _isGameOver,
    if (_dailyDay != null) 'daily': {'day': _dailyDay, 'draws': _draws},
  };

  /// Rejects malformed snapshots before touching state or notifying listeners.
  /// Future, unseen pieces may differ after restoring; the three visible
  /// pieces and all pressure/tool counters are preserved exactly.
  bool restoreSnapshot(Object? data) {
    if (data is! Map || data['version'] != 1) return false;
    bool integer(Object? value, int minValue, int maxValue) =>
        value is int && value >= minValue && value <= maxValue;
    final board = data['board'];
    final preview = data['previewTiers'];
    if (board is! List ||
        board.length != cellCount ||
        preview is! List ||
        preview.length != previewCount ||
        !integer(data['score'], 0, 9007199254740991) ||
        !integer(data['highestTier'], 1, 32) ||
        !integer(data['placements'], 0, 1000000) ||
        !integer(data['trailAxes'], 0, maxTrailAxes) ||
        !integer(data['lastAwardedAxeAt'], 0, 1000000) ||
        !integer(data['shifts'] ?? 0, 0, maxShifts) ||
        !integer(data['lastMergeChain'], 0, 7) ||
        !integer(data['bestMergeChain'], 0, 7) ||
        !integer(data['mergeCount'], 0, 7000000) ||
        data['isGameOver'] is! bool) {
      return false;
    }
    final highest = data['highestTier'] as int;
    final placements = data['placements'] as int;
    final awardedAt = data['lastAwardedAxeAt'] as int;
    final merges = data['mergeCount'] as int;
    final bestChain = data['bestMergeChain'] as int;
    final cap = min(5, 2 + placements ~/ 8);
    if (board.any((tier) => tier != null && !integer(tier, 1, highest)) ||
        preview.any((tier) => !integer(tier, 1, cap)) ||
        awardedAt > placements ||
        awardedAt % 10 != 0 ||
        merges > placements * 7 ||
        bestChain > merges ||
        (data['lastMergeChain'] as int) > bestChain) {
      return false;
    }
    final occupied = board.where((tier) => tier != null).length;
    final terminal = occupied == cellCount && data['trailAxes'] == 0;
    if (terminal != data['isGameOver'] || occupied > placements + 2) {
      return false;
    }
    if (placements == 0) {
      final emptyStart = occupied == 0;
      final guidedStart =
          occupied == 2 && board[0] == 1 && board[1] == 1 && preview[0] == 1;
      if ((!emptyStart && !guidedStart) ||
          data['score'] != 0 ||
          highest != 1 ||
          data['trailAxes'] != 1 ||
          (data['shifts'] ?? 0) != 0) {
        return false;
      }
    }

    // A daily run resumes its own sequence: reseed and skip what was drawn.
    int? day;
    var random = _baseRandom;
    var draws = 0;
    final daily = data['daily'];
    if (data.containsKey('daily')) {
      if (daily is! Map ||
          !integer(daily['day'], 0, 1 << 18) ||
          daily['draws'] != previewCount + placements) {
        return false;
      }
      day = daily['day'] as int;
      draws = daily['draws'] as int;
      final seeded = SeededRandom(dailySeed(day));
      for (var i = 0; i < draws; i++) {
        seeded.nextUint32();
      }
      random = seeded;
    }
    _dailyDay = day;
    _random = random;
    _draws = draws;

    _board = List<int?>.from(board);
    _previewTiers
      ..clear()
      ..addAll(List<int>.from(preview));
    _score = data['score'] as int;
    _highestTier = highest;
    _placements = placements;
    _trailAxes = data['trailAxes'] as int;
    _lastAwardedAxeAt = awardedAt;
    _shifts = (data['shifts'] ?? 0) as int;
    _lastEarnedShift = false;
    _lastShiftMoves = const <ShiftMove>[];
    _lastShiftErased = null;
    _lastMergeChain = data['lastMergeChain'] as int;
    _bestMergeChain = bestChain;
    _mergeCount = merges;
    _isGameOver = terminal;
    _lastPlacedIndex = null;
    _lastMergeSteps = const <MergeStep>[];
    notifyListeners();
    return true;
  }

  MergeResult place(int index) {
    if (_isGameOver) {
      return const MergeResult(MergeAction.gameOver);
    }
    if (_board[index] != null) {
      return const MergeResult(MergeAction.blocked);
    }

    _lastMergeChain = 0;
    _lastMergeSteps = const <MergeStep>[];
    _lastEarnedShift = false;
    _lastShiftMoves = const <ShiftMove>[];
    _lastShiftErased = null;
    _lastPlacedIndex = index;
    final placedTier = _previewTiers.removeAt(0);
    _board[index] = placedTier;
    _placements += 1;
    _highestTier = max(_highestTier, placedTier);
    final steps = _resolveMergeSteps(_board, index);
    for (final step in steps) {
      _score += step.points;
      _highestTier = max(_highestTier, step.toTier);
    }
    final mergeCount = steps.length;
    _lastMergeSteps = List.unmodifiable(steps);
    _mergeCount += mergeCount;
    _lastMergeChain = mergeCount;
    _bestMergeChain = max(_bestMergeChain, mergeCount);
    _awardTrailAxeIfReady();
    if (steps.length >= chainForShift ||
        steps.any((step) => step.absorbed.length + 1 >= bigShiftCluster)) {
      _lastEarnedShift = grantShift(notify: false);
    }
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

  /// Grants one Trail Axe (mission reward). Returns false at the cap or after
  /// game over. Game over is only decided in [place], so a granted axe on a
  /// full board keeps the run going.
  bool grantTrailAxe() {
    if (_isGameOver || _trailAxes >= maxTrailAxes) return false;
    _trailAxes += 1;
    notifyListeners();
    return true;
  }

  /// Grants one Shift (big merge or mission reward). Returns false at the cap
  /// or after game over.
  bool grantShift({bool notify = true}) {
    if (_isGameOver || _shifts >= maxShifts) return false;
    _shifts += 1;
    if (notify) notifyListeners();
    return true;
  }

  /// Cell one step from [from] toward [direction], or null past the wall.
  static int? shiftTarget(int from, ShiftDirection direction) {
    if (from < 0 || from >= cellCount) return null;
    final row = from ~/ boardWidth;
    final col = from % boardWidth;
    return switch (direction) {
      ShiftDirection.left => col == 0 ? null : from - 1,
      ShiftDirection.right => col == boardWidth - 1 ? null : from + 1,
      ShiftDirection.up => row == 0 ? null : from - boardWidth,
      ShiftDirection.down => row == boardWidth - 1 ? null : from + boardWidth,
    };
  }

  /// Moves the camp at [from] one step toward [direction]. A camp standing
  /// on the target cell is cleared (no points). Merges then start from the
  /// target cell. A move off the board, or from an empty plot, spends nothing
  /// ([MergeAction.blocked]). Placements, piece draws and the Trail Axe clock
  /// are not touched.
  MergeResult useShift(int from, ShiftDirection direction) {
    if (_isGameOver) {
      return const MergeResult(MergeAction.gameOver);
    }
    if (_shifts == 0) {
      return const MergeResult(MergeAction.noTool);
    }
    final tier = from >= 0 && from < cellCount ? _board[from] : null;
    final to = shiftTarget(from, direction);
    if (tier == null || to == null) {
      return const MergeResult(MergeAction.blocked);
    }

    _lastShiftErased = _board[to];
    _board[from] = null;
    _board[to] = tier;
    _shifts -= 1;
    _lastEarnedShift = false;
    _lastPlacedIndex = null;
    _lastShiftMoves = List.unmodifiable([
      ShiftMove(from: from, to: to, tier: tier),
    ]);
    var steps = const <MergeStep>[];
    if (_connectedCluster(_board, to, tier).length >= 3) {
      steps = _resolveMergeSteps(_board, to);
    }
    for (final step in steps) {
      _score += step.points;
      _highestTier = max(_highestTier, step.toTier);
    }
    _lastMergeSteps = List.unmodifiable(steps);
    _mergeCount += steps.length;
    _lastMergeChain = steps.length;
    _bestMergeChain = max(_bestMergeChain, steps.length);
    notifyListeners();
    return const MergeResult(MergeAction.shifted);
  }

  /// Adds bonus points (mission reward) without touching any rule. Ignored
  /// after game over so the final score stays final.
  void addBonusScore(int points) {
    if (points <= 0 || _isGameOver) return;
    _score += points;
    notifyListeners();
  }

  /// Settles a mission completed by the terminal placement before the screen
  /// captures the result. It does not resurrect the run or grant a tool.
  void addFinalMissionBonus(int points) {
    if (!_isGameOver || points <= 0) return;
    _score += points;
    notifyListeners();
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
    _lastEarnedShift = false;
    _lastShiftMoves = const <ShiftMove>[];
    _lastShiftErased = null;
    notifyListeners();
    return const MergeResult(MergeAction.removed);
  }

  List<MergeStep> _resolveMergeSteps(List<int?> board, int origin) {
    final steps = <MergeStep>[];
    var mergeCount = 0;
    var current = origin;

    while (true) {
      final tier = board[current];
      if (tier == null) {
        break;
      }
      final cluster = _connectedCluster(board, current, tier);
      if (cluster.length < 3) {
        break;
      }

      mergeCount += 1;
      for (final index in cluster) {
        if (index != current) {
          board[index] = null;
        }
      }

      final upgraded = tier + 1;
      board[current] = upgraded;
      final points = cluster.length * 12 * upgraded * mergeCount;
      steps.add(
        MergeStep(
          origin: current,
          absorbed: List.unmodifiable(cluster.where((i) => i != current)),
          fromTier: tier,
          toTier: upgraded,
          points: points,
          chainIndex: mergeCount,
        ),
      );
    }

    return steps;
  }

  Set<int> _connectedCluster(List<int?> board, int start, int tier) {
    final visited = <int>{};
    final stack = <int>[start];

    while (stack.isNotEmpty) {
      final index = stack.removeLast();
      if (!visited.add(index)) {
        continue;
      }

      for (final neighbor in _neighbors(index)) {
        if (board[neighbor] == tier && !visited.contains(neighbor)) {
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
    int shifts = 0,
    List<int>? previewTiers,
    bool isGameOver = false,
    int mergeCount = 0,
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
    _shifts = shifts;
    _lastEarnedShift = false;
    _lastShiftMoves = const <ShiftMove>[];
    _lastShiftErased = null;
    _lastMergeChain = 0;
    _bestMergeChain = 0;
    _isGameOver = isGameOver;
    _mergeCount = mergeCount;
    _lastPlacedIndex = null;
    _lastMergeSteps = const <MergeStep>[];
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
    _draws += 1;
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
      'Star Observatory',
    ];
    return names[(tier - 1).clamp(0, names.length - 1)];
  }
}
