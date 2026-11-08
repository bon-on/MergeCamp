import 'package:flutter_test/flutter_test.dart';
import 'package:merge_camp/src/meta/camp_progress.dart';
import 'package:merge_camp/src/meta/camp_theme.dart';
import 'package:merge_camp/src/meta/next_goal.dart';

CampProgress _at({
  required int level,
  int extraXp = 0,
  Set<int> tiers = const {1},
}) => CampProgress(
  bestScore: 100,
  discoveredTiers: tiers,
  totalXp: CampProgress.totalXpForLevel(level) + extraXp,
  selectedTheme: CampTheme.summer,
);

void main() {
  test('totalXpForLevel matches the level split', () {
    for (var level = 1; level < 30; level++) {
      final p = _at(level: level);
      expect(p.level, level);
      expect(p.xpIntoLevel, 0);
    }
  });

  test('level goal shows missing XP and the next sticker', () {
    final p = _at(level: 1, extraXp: 100, tiers: {1, 2, 3});
    final goals = nextGoals(p);
    final level = goals.firstWhere((g) => g.kind == NextGoalKind.level);
    expect(level.title, '${p.xpForNextLevel - 100} XP to Lv 2');
    expect(level.sticker?.name, 'Pine Tree');
    expect(level.detail, 'Unlocks the Pine Tree sticker');
    expect(level.progress, closeTo(100 / p.xpForNextLevel, 1e-9));
  });

  test('a theme unlocking at the next level folds into the level goal', () {
    final goals = nextGoals(_at(level: 2, tiers: {1, 2, 3}));
    expect(goals.where((g) => g.kind == NextGoalKind.theme), isEmpty);
    final level = goals.firstWhere((g) => g.kind == NextGoalKind.level);
    expect(level.theme, CampTheme.autumn);
    expect(level.detail, 'Unlocks the Acorn sticker + Autumn theme');
  });

  test('a farther theme is its own goal with the XP still missing', () {
    final p = _at(level: 4, extraXp: 10, tiers: {1, 2, 3, 4, 5});
    final theme = nextGoals(p).firstWhere((g) => g.kind == NextGoalKind.theme);
    expect(theme.theme, CampTheme.snow);
    final missing = CampProgress.totalXpForLevel(6) - p.totalXp;
    expect(theme.title, '$missing XP to the Snow theme');
    expect(theme.detail, 'Unlocks at Lv 6');
  });

  test('album goal is the lowest undiscovered tier', () {
    final goals = nextGoals(_at(level: 1, tiers: {1, 2, 4}));
    final album = goals.firstWhere((g) => g.kind == NextGoalKind.album);
    expect(album.tier, 3);
    expect(album.title, 'Build a Supply Shed');
    expect(album.detail, 'New album camp (3/8 found)');
    expect(album.runsAway, 1);
  });

  test('nearest goal comes first; ties prefer the level', () {
    // Almost levelled: the level is nearest.
    var goals = nextGoals(
      _at(level: 3, extraXp: CampProgress.xpToAdvance(3) - 5, tiers: {1, 2}),
    );
    expect(goals.first.kind, NextGoalKind.level);
    // Far from the next level (> 1 run) while the album camp is one step.
    final far = _at(level: 20, tiers: {1, 2});
    goals = nextGoals(far);
    expect(far.xpForNextLevel / averageRunXp, greaterThan(1));
    expect(goals.first.kind, NextGoalKind.album);
    // Exactly one run away: tie, level wins.
    final tieGoals = nextGoals(
      _at(
        level: 3,
        extraXp: CampProgress.xpToAdvance(3) - averageRunXp,
        tiers: {1, 2},
      ),
    );
    expect(tieGoals.first.runsAway, 1);
    expect(tieGoals.first.kind, NextGoalKind.level);
    expect(tieGoals[1].kind, NextGoalKind.album);
  });

  test('works past the sticker catalog with everything unlocked', () {
    final goals = nextGoals(_at(level: 40, tiers: {1, 2, 3, 4, 5, 6, 7, 8}));
    expect(goals, hasLength(1));
    expect(goals.single.kind, NextGoalKind.level);
    expect(goals.single.sticker, isNull);
    expect(goals.single.detail, 'Keep growing your camp');
  });

  test('a brand-new player gets level, album and theme goals', () {
    final goals = nextGoals(const CampProgress.initial());
    expect(goals.map((g) => g.kind), [
      NextGoalKind.level,
      NextGoalKind.album,
      NextGoalKind.theme,
    ]);
    expect(goals.first.title, '230 XP to Lv 2');
  });
}
