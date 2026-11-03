import 'camp_theme.dart';

/// Facts about one finished (or restarted) run, fed to [CampProgress.applyRun].
class RunSummary {
  const RunSummary({
    required this.score,
    required this.highestTier,
    required this.bestChain,
    required this.placements,
    this.missionXp = 0,
    this.mergeCount = 0,
  });

  final int score;
  final int highestTier;
  final int bestChain;
  final int placements;
  final int mergeCount;

  /// XP already earned from completed missions during the run.
  final int missionXp;
}

/// Result of applying a run to the saved progress.
class RunOutcome {
  const RunOutcome({
    required this.progress,
    required this.xpGained,
    required this.isNewBest,
    required this.previousBest,
    required this.levelBefore,
    required this.levelAfter,
    required this.newlyUnlockedThemes,
  });

  final CampProgress progress;
  final int xpGained;
  final bool isNewBest;
  final int previousBest;
  final int levelBefore;
  final int levelAfter;
  final List<CampTheme> newlyUnlockedThemes;
}

/// Saved meta progress: best score, camp album, camp XP and chosen theme.
///
/// Tuning (measured with a throwaway greedy/random player on the real
/// controller, 400 seeds per player type; scores before missions):
///   random placement   mean 1078  (p10 468, p50 1020, p90 1728)
///   casual (35% noise) mean 2408  (p10 1260, p50 2208, p90 3876)
///   greedy             mean 3408  (p10 1728, p50 3240, p90 5256)
/// With mission rewards (an axe per mission) players finish 3 to 5 missions
/// per run. XP per run = score / 10 + missionXp + 20 (participation, only for
/// runs with at least [participationMinPlacements] placements and one merge);
/// the following tuning measurements predate that merge requirement. Mean
/// XP per run measured 230 (random), 400 (casual), 510 (greedy), so an average
/// player earns roughly 300. Even a 30 point run moves the bar by about 10%.
/// Level curve: reaching level L+1 costs 230 + 55 * (L - 1) XP. Measured runs
/// to reach Lv3 / Lv6 / Lv10: random 2.8 / 8.0 / 18.0, casual 1.9 / 4.8 / 10.7,
/// greedy 1.6 / 4.0 / 8.5; between random and casual that is ~2 / ~6 / ~14.
class CampProgress {
  const CampProgress({
    required this.bestScore,
    required this.discoveredTiers,
    required this.totalXp,
    required this.selectedTheme,
    this.activeRun,
  });

  const CampProgress.initial()
    : bestScore = 0,
      discoveredTiers = const <int>{1},
      totalXp = 0,
      activeRun = null,
      selectedTheme = CampTheme.summer;

  /// Highest camp tier that has an album entry.
  static const int maxAlbumTier = 8;

  /// XP granted for a run with at least [participationMinPlacements]
  /// placements and one merge.
  static const int participationXp = 20;

  /// Placements a run needs before it earns [participationXp].
  static const int participationMinPlacements = 5;

  final int bestScore;
  final Set<int> discoveredTiers;
  final int totalXp;
  final CampTheme selectedTheme;

  /// Optional live run envelope, validated by the screen before restoration.
  final Map<String, dynamic>? activeRun;

  CampProgress withActiveRun(Map<String, dynamic>? run) => CampProgress(
    bestScore: bestScore,
    discoveredTiers: Set.unmodifiable(discoveredTiers),
    totalXp: totalXp,
    selectedTheme: selectedTheme,
    activeRun: run == null ? null : Map.unmodifiable(run),
  );

  /// XP needed to go from [level] to the next one.
  static int xpToAdvance(int level) => 230 + 55 * (level < 1 ? 0 : level - 1);

  /// XP awarded for a run's score.
  static int xpForScore(int score) => score <= 0 ? 0 : score ~/ 10;

  int get level => _split().$1;
  int get xpIntoLevel => _split().$2;
  int get xpForNextLevel => xpToAdvance(level);

  (int, int) _split() {
    var level = 1;
    var left = totalXp < 0 ? 0 : totalXp;
    while (left >= xpToAdvance(level)) {
      left -= xpToAdvance(level);
      level += 1;
    }
    return (level, left);
  }

  bool isThemeUnlocked(CampTheme theme) => level >= theme.requiredLevel;

  CampProgress withDiscovered(int tier) {
    final clamped = tier.clamp(1, maxAlbumTier);
    if (discoveredTiers.contains(clamped)) return this;
    return _copy(discoveredTiers: {...discoveredTiers, clamped});
  }

  /// Returns this progress unchanged when [theme] is still locked.
  CampProgress withTheme(CampTheme theme) {
    if (!isThemeUnlocked(theme)) return this;
    return _copy(selectedTheme: theme);
  }

  RunOutcome applyRun(RunSummary summary) {
    final levelBefore = level;
    if (summary.placements <= 0) {
      return RunOutcome(
        progress: withActiveRun(null),
        xpGained: 0,
        isNewBest: false,
        previousBest: bestScore,
        levelBefore: levelBefore,
        levelAfter: levelBefore,
        newlyUnlockedThemes: const <CampTheme>[],
      );
    }
    final xp =
        xpForScore(summary.score) +
        (summary.missionXp < 0 ? 0 : summary.missionXp) +
        (summary.placements >= participationMinPlacements &&
                summary.mergeCount > 0
            ? participationXp
            : 0);
    final isNewBest = summary.score > bestScore;
    var next = withActiveRun(null)._copy(
      bestScore: isNewBest ? summary.score : bestScore,
      totalXp: totalXp + xp,
    );
    // The screen records every camp the moment it is built; the run only
    // guarantees its highest camp is in the album.
    next = next.withDiscovered(summary.highestTier);
    final levelAfter = next.level;
    return RunOutcome(
      progress: next,
      xpGained: xp,
      isNewBest: isNewBest,
      previousBest: bestScore,
      levelBefore: levelBefore,
      levelAfter: levelAfter,
      newlyUnlockedThemes: [
        for (final theme in CampTheme.values)
          if (levelBefore < theme.requiredLevel &&
              levelAfter >= theme.requiredLevel)
            theme,
      ],
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'bestScore': bestScore,
    'discoveredTiers': (discoveredTiers.toList()..sort()),
    'totalXp': totalXp,
    'selectedTheme': selectedTheme.name,
    if (activeRun != null) 'activeRun': activeRun,
  };

  /// Tolerant parser: any missing or invalid field falls back on its own.
  factory CampProgress.fromJson(Object? json) {
    if (json is! Map) return const CampProgress.initial();
    int readInt(Object? value) =>
        value is num && value.isFinite && value >= 0 && value <= 1000000000
        ? value.toInt()
        : 0;
    final tiers = <int>{1};
    final rawTiers = json['discoveredTiers'];
    if (rawTiers is List) {
      for (final value in rawTiers) {
        if (value is num && value.isFinite) {
          tiers.add(value.toInt().clamp(1, maxAlbumTier));
        }
      }
    }
    var progress = CampProgress(
      bestScore: readInt(json['bestScore']),
      discoveredTiers: Set.unmodifiable(tiers),
      totalXp: readInt(json['totalXp']),
      selectedTheme: CampTheme.summer,
      activeRun:
          json['activeRun'] is Map &&
              (json['activeRun'] as Map).keys.every((key) => key is String)
          ? Map<String, dynamic>.unmodifiable(json['activeRun'] as Map)
          : null,
    );
    final theme = CampTheme.fromName(
      json['selectedTheme'] is String ? json['selectedTheme'] as String : null,
    );
    progress = progress.withTheme(theme);
    return progress;
  }

  CampProgress _copy({
    int? bestScore,
    Set<int>? discoveredTiers,
    int? totalXp,
    CampTheme? selectedTheme,
  }) {
    return CampProgress(
      bestScore: bestScore ?? this.bestScore,
      discoveredTiers: Set.unmodifiable(
        discoveredTiers ?? this.discoveredTiers,
      ),
      totalXp: totalXp ?? this.totalXp,
      selectedTheme: selectedTheme ?? this.selectedTheme,
      activeRun: activeRun,
    );
  }
}
