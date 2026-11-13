import 'package:flutter_test/flutter_test.dart';
import 'package:merge_camp/src/meta/camp_progress.dart';

RunSummary _run({int score = 1000, int placements = 20, int merges = 6}) =>
    RunSummary(
      score: score,
      highestTier: 3,
      bestChain: 1,
      placements: placements,
      mergeCount: merges,
      missionXp: 0,
    );

void main() {
  const start = CampProgress.initial();

  test('a counted daily run pays the bonus on top of the run XP', () {
    final free = start.applyRun(_run());
    final daily = start.applyRun(_run(), dailyDay: 100);
    expect(free.daily, isNull);
    expect(daily.daily!.rewarded, isTrue);
    expect(daily.xpGained, free.xpGained + 40);
    expect(daily.progress.totalXp, free.progress.totalXp + 40);
    expect(daily.progress.daily.streak, 1);
    expect(daily.progress.daily.bestScoreOn(100), 1000);
  });

  test('only the first counted run of a day pays and extends the streak', () {
    final first = start.applyRun(_run(score: 800), dailyDay: 100).progress;
    final second = first.applyRun(_run(score: 1500), dailyDay: 100);
    expect(second.daily!.rewarded, isFalse);
    expect(second.daily!.isDayBest, isTrue);
    expect(second.xpGained, CampProgress.runXp(_run(score: 1500)));
    expect(second.progress.daily.streak, 1);
    expect(second.progress.daily.total, 1);
    expect(second.progress.daily.bestScoreOn(100), 1500);

    final next = second.progress.applyRun(_run(), dailyDay: 101);
    expect(next.progress.daily.streak, 2);
    expect(next.daily!.bonusXp, 50);
  });

  test(
    'a short or mergeless daily run neither counts nor breaks the streak',
    () {
      final day1 = start.applyRun(_run(), dailyDay: 100).progress;
      final few = day1.applyRun(_run(placements: 4), dailyDay: 101);
      expect(few.daily, isNull);
      expect(few.progress.daily.streak, 1);
      final noMerge = day1.applyRun(_run(merges: 0), dailyDay: 101);
      expect(noMerge.daily, isNull);
      expect(noMerge.progress.daily, same(day1.daily));
      // The streak is still alive the next day.
      final day2 = few.progress.applyRun(_run(), dailyDay: 101);
      expect(day2.progress.daily.streak, 2);
    },
  );

  test('free play leaves the daily counters alone', () {
    final day1 = start.applyRun(_run(), dailyDay: 100).progress;
    final free = day1.applyRun(_run(score: 5000));
    expect(free.daily, isNull);
    expect(free.progress.daily.toJson(), day1.daily.toJson());
  });

  test('daily counters survive JSON and old saves load without them', () {
    final day1 = start.applyRun(_run(), dailyDay: 100).progress;
    final back = CampProgress.fromJson(day1.toJson());
    expect(back.daily.toJson(), day1.daily.toJson());
    expect(back.totalXp, day1.totalXp);

    final old = CampProgress.fromJson({
      'bestScore': 900,
      'discoveredTiers': [1, 2],
      'totalXp': 100,
      'selectedTheme': 'summer',
    });
    expect(old.daily.total, 0);
    expect(old.toJson().containsKey('daily'), isFalse);
    expect(CampProgress.fromJson({'daily': 'broken'}).daily.streak, 0);
  });

  test('withActiveRun and level changes keep the daily counters', () {
    final day1 = start.applyRun(_run(), dailyDay: 100).progress;
    expect(day1.withActiveRun({'x': 1}).daily, same(day1.daily));
    expect(day1.withDiscovered(5).daily, same(day1.daily));
  });
}
