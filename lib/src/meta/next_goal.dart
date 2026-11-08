import '../game/merge_camp_controller.dart';
import 'camp_progress.dart';
import 'camp_theme.dart';
import 'stickers.dart';

enum NextGoalKind { level, album, theme }

/// One concrete goal shown on the run summary ("140 XP to Lv 3").
class NextGoal {
  const NextGoal({
    required this.kind,
    required this.title,
    required this.detail,
    required this.runsAway,
    required this.progress,
    this.sticker,
    this.theme,
    this.tier,
  });

  final NextGoalKind kind;

  /// Short headline with the number, e.g. "140 XP to Lv 3".
  final String title;

  /// What the goal gives or needs, e.g. "Unlocks the Acorn sticker".
  final String detail;

  /// Estimated runs until the goal; the smallest one is highlighted.
  final double runsAway;

  /// 0..1 progress towards the goal (for its bar).
  final double progress;

  /// Reward sticker of a level goal, if any.
  final Sticker? sticker;

  /// Theme unlocked by a theme goal (or by a level goal's level).
  final CampTheme? theme;

  /// Album tier of an album goal.
  final int? tier;
}

/// Average XP of one run (see the tuning notes on [CampProgress]), used to
/// turn missing XP into an estimated number of runs.
const int averageRunXp = 300;

/// The closest goals for [progress], nearest first (at most three: next
/// level, next undiscovered album camp, next locked theme). Ties prefer the
/// level, then the album, so the order is deterministic.
List<NextGoal> nextGoals(CampProgress progress) {
  final goals = <NextGoal>[];
  final level = progress.level;
  final nextLevel = level + 1;
  final missingLevelXp = progress.xpForNextLevel - progress.xpIntoLevel;
  final sticker = Sticker.forLevel(nextLevel);
  CampTheme? levelTheme;
  CampTheme? lockedTheme;
  for (final theme in CampTheme.values) {
    if (theme.requiredLevel > level) {
      lockedTheme = theme;
      break;
    }
  }
  if (lockedTheme != null && lockedTheme.requiredLevel == nextLevel) {
    levelTheme = lockedTheme;
  }
  final rewards = [
    if (sticker != null) '${sticker.name} sticker',
    if (levelTheme != null) '${levelTheme.label} theme',
  ];
  goals.add(
    NextGoal(
      kind: NextGoalKind.level,
      title: '$missingLevelXp XP to Lv $nextLevel',
      detail: rewards.isEmpty
          ? 'Keep growing your camp'
          : 'Unlocks the ${rewards.join(' + ')}',
      runsAway: missingLevelXp / averageRunXp,
      progress: progress.xpForNextLevel <= 0
          ? 0
          : progress.xpIntoLevel / progress.xpForNextLevel,
      sticker: sticker,
      theme: levelTheme,
    ),
  );

  int? missingTier;
  for (var tier = 1; tier <= CampProgress.maxAlbumTier; tier++) {
    if (!progress.discoveredTiers.contains(tier)) {
      missingTier = tier;
      break;
    }
  }
  if (missingTier != null) {
    var below = 0;
    for (final tier in progress.discoveredTiers) {
      if (tier < missingTier && tier > below) below = tier;
    }
    final found = progress.discoveredTiers
        .where((tier) => tier >= 1 && tier <= CampProgress.maxAlbumTier)
        .length;
    final steps = missingTier - below;
    goals.add(
      NextGoal(
        kind: NextGoalKind.album,
        title: 'Build a ${MergeCampController.campTierName(missingTier)}',
        detail: 'New album camp ($found/${CampProgress.maxAlbumTier} found)',
        runsAway: steps < 1 ? 1 : steps.toDouble(),
        progress: found / CampProgress.maxAlbumTier,
        tier: missingTier,
      ),
    );
  }

  if (lockedTheme != null && levelTheme == null) {
    final target = CampProgress.totalXpForLevel(lockedTheme.requiredLevel);
    final missing = target - progress.totalXp;
    goals.add(
      NextGoal(
        kind: NextGoalKind.theme,
        title: '$missing XP to the ${lockedTheme.label} theme',
        detail: 'Unlocks at Lv ${lockedTheme.requiredLevel}',
        runsAway: missing / averageRunXp,
        progress: target <= 0 ? 0 : progress.totalXp / target,
        theme: lockedTheme,
      ),
    );
  }

  // Stable sort keeps the level > album > theme order on ties.
  final indexed = [for (var i = 0; i < goals.length; i++) (i, goals[i])];
  indexed.sort((a, b) {
    final byRuns = a.$2.runsAway.compareTo(b.$2.runsAway);
    return byRuns != 0 ? byRuns : a.$1.compareTo(b.$1);
  });
  return [for (final entry in indexed) entry.$2];
}
