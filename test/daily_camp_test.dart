import 'package:flutter_test/flutter_test.dart';
import 'package:merge_camp/src/meta/daily_camp.dart';

const pinnedUint32 = [
  3677456184,
  2433263795,
  131063100,
  1902920200,
  3700092254,
  2769081358,
];
const pinnedDailyDraws = [21, 19, 4, 17, 12, 9, 10, 17];

void main() {
  test('day index uses the calendar date only', () {
    expect(dayIndexOf(DateTime(1970, 1, 1, 23, 59)), 0);
    expect(dayIndexOf(DateTime(1970, 1, 2, 0, 1)), 1);
    expect(
      dayIndexOf(DateTime(2026, 11, 13)) - dayIndexOf(DateTime(2026, 11, 12)),
      1,
    );
  });

  test('seeded random is deterministic and day dependent', () {
    List<int> draw(int day) {
      final r = SeededRandom(dailySeed(day));
      return [for (var i = 0; i < 12; i++) r.nextInt(23)];
    }

    expect(draw(20000), draw(20000));
    expect(draw(20000), isNot(draw(20001)));
    expect(dailySeed(0), isNonZero);
    // Pinned values: the web test repeats these so VM and web must agree.
    final r = SeededRandom(1);
    expect([for (var i = 0; i < 6; i++) r.nextUint32()], pinnedUint32);
    final d = SeededRandom(dailySeed(20000));
    expect([for (var i = 0; i < 8; i++) d.nextInt(23)], pinnedDailyDraws);
    expect(dailySeed(20000), 162184709);
  });

  test('first run starts a streak, later runs of the day pay nothing', () {
    final first = applyDaily(DailyCamp.none, 100, 900);
    expect(first.rewarded, isTrue);
    expect(first.state.streak, 1);
    expect(first.bonusXp, 40);
    expect(first.isDayBest, isTrue);
    expect(first.state.bestScoreOn(100), 900);

    final worse = applyDaily(first.state, 100, 500);
    expect(worse.rewarded, isFalse);
    expect(worse.bonusXp, 0);
    expect(worse.state.streak, 1);
    expect(worse.isDayBest, isFalse);
    expect(worse.state.bestScoreOn(100), 900);

    final better = applyDaily(first.state, 100, 1500);
    expect(better.rewarded, isFalse);
    expect(better.isDayBest, isTrue);
    expect(better.state.bestScoreOn(100), 1500);
    expect(better.state.total, 1);
  });

  test('consecutive days grow the bonus up to 80 XP', () {
    var s = DailyCamp.none;
    final bonus = <int>[];
    for (var day = 10; day < 17; day++) {
      final r = applyDaily(s, day, 100);
      bonus.add(r.bonusXp);
      s = r.state;
    }
    expect(bonus, [40, 50, 60, 70, 80, 80, 80]);
    expect(s.streak, 7);
    expect(s.best, 7);
  });

  test('one missed day is forgiven once and the grace refills later', () {
    var s = applyDaily(DailyCamp.none, 10, 100).state;
    final grace = applyDaily(s, 12, 100);
    expect(grace.graceUsed, isTrue);
    expect(grace.state.streak, 2);
    expect(grace.state.graceReady, isFalse);
    expect(grace.state.refillLeft, kGraceRefillSolves);
    s = grace.state;
    // A second miss before the refill resets the streak.
    final broken = applyDaily(s, 14, 100);
    expect(broken.state.streak, 1);
    expect(broken.graceUsed, isFalse);
    // Seven rewarded days refill the grace.
    s = grace.state;
    for (var day = 13; day < 13 + kGraceRefillSolves; day++) {
      s = applyDaily(s, day, 100).state;
    }
    expect(s.graceReady, isTrue);
    expect(s.refillLeft, 0);
  });

  test('a long gap resets the streak to one', () {
    final s = applyDaily(DailyCamp.none, 10, 100).state;
    final r = applyDaily(s, 20, 100);
    expect(r.rewarded, isTrue);
    expect(r.state.streak, 1);
    expect(r.state.best, 1);
  });

  test('a clock set back pays nothing and keeps the streak and best score', () {
    final s = applyDaily(
      applyDaily(DailyCamp.none, 10, 100).state,
      11,
      700,
    ).state;
    final back = applyDaily(s, 9, 99999);
    expect(back.rewarded, isFalse);
    expect(back.bonusXp, 0);
    expect(back.state.streak, 2);
    expect(back.state.bestScoreOn(11), 700);
    expect(streakOn(s, 5).status, StreakStatus.safe);
  });

  test('streak view and tomorrow hint', () {
    final s = applyDaily(DailyCamp.none, 10, 100).state;
    expect(streakOn(s, 10).status, StreakStatus.safe);
    expect(streakOn(s, 11).status, StreakStatus.pending);
    expect(streakOn(s, 12).status, StreakStatus.graceCovers);
    expect(streakOn(s, 13).status, StreakStatus.none);
    expect(streakIfRewarded(s, 10), 1);
    expect(streakIfRewarded(s, 11), 2);
    expect(streakIfRewarded(DailyCamp.none, 11), 1);
  });

  test('json round trip and damaged fields', () {
    final s = applyDaily(
      applyDaily(DailyCamp.none, 10, 100).state,
      11,
      700,
    ).state;
    final back = DailyCamp.fromJson(s.toJson());
    expect(back.toJson(), s.toJson());
    expect(DailyCamp.fromJson(null).streak, 0);
    final bad = DailyCamp.fromJson({
      'lastDay': 'x',
      'streak': -5,
      'graceReady': false,
      'refillLeft': 999,
      'bestScore': double.nan,
    });
    expect(bad.lastDay, isNull);
    expect(bad.streak, 0);
    expect(bad.refillLeft, kGraceRefillSolves);
    expect(bad.bestScore, 0);
  });
}
