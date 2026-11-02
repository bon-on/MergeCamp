import 'package:flutter_test/flutter_test.dart';
import 'package:merge_camp/src/meta/camp_progress.dart';
import 'package:merge_camp/src/meta/camp_progress_store.dart';
import 'package:merge_camp/src/meta/camp_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

CampProgress withXp(int xp) => CampProgress(
  bestScore: 0,
  discoveredTiers: const {1},
  totalXp: xp,
  selectedTheme: CampTheme.summer,
);

RunSummary run(int score, {int tier = 1, int placements = 10, int mxp = 0}) =>
    RunSummary(
      score: score,
      highestTier: tier,
      bestChain: 1,
      placements: placements,
      missionXp: mxp,
    );

void main() {
  group('level math', () {
    test('initial progress is level 1 with empty bar', () {
      const p = CampProgress.initial();
      expect(p.level, 1);
      expect(p.xpIntoLevel, 0);
      expect(p.xpForNextLevel, CampProgress.xpToAdvance(1));
      expect(p.discoveredTiers, {1});
    });

    test('level boundaries', () {
      final need = CampProgress.xpToAdvance(1);
      expect(withXp(need - 1).level, 1);
      expect(withXp(need).level, 2);
      expect(withXp(need).xpIntoLevel, 0);
      final two = need + CampProgress.xpToAdvance(2);
      expect(withXp(two + 5).level, 3);
      expect(withXp(two + 5).xpIntoLevel, 5);
    });

    test('curve grows and theme thresholds follow level', () {
      expect(
        CampProgress.xpToAdvance(5),
        greaterThan(CampProgress.xpToAdvance(1)),
      );
      var total = 0;
      for (var l = 1; l < 10; l++) {
        total += CampProgress.xpToAdvance(l);
      }
      expect(withXp(total).level, 10);
      expect(withXp(total).isThemeUnlocked(CampTheme.night), isTrue);
      expect(withXp(total - 1).isThemeUnlocked(CampTheme.night), isFalse);
    });

    test('theme selection ignores locked themes', () {
      const p = CampProgress.initial();
      expect(p.withTheme(CampTheme.snow).selectedTheme, CampTheme.summer);
      expect(p.isThemeUnlocked(CampTheme.summer), isTrue);
    });

    test('withDiscovered clamps tiers', () {
      final p = const CampProgress.initial()
          .withDiscovered(12)
          .withDiscovered(0);
      expect(p.discoveredTiers, {1, 8});
    });
  });

  group('applyRun', () {
    test('zero placements changes nothing', () {
      final outcome = const CampProgress.initial().applyRun(
        run(500, placements: 0),
      );
      expect(outcome.xpGained, 0);
      expect(outcome.isNewBest, isFalse);
      expect(outcome.progress.bestScore, 0);
    });

    test('best score, xp, discovery', () {
      final outcome = const CampProgress.initial().applyRun(
        run(1000, tier: 4, mxp: 60),
      );
      expect(outcome.isNewBest, isTrue);
      expect(outcome.previousBest, 0);
      expect(outcome.xpGained, 100 + 60 + CampProgress.participationXp);
      expect(outcome.progress.bestScore, 1000);
      expect(outcome.progress.discoveredTiers, {1, 4});
      final lower = outcome.progress.applyRun(run(10));
      expect(lower.isNewBest, isFalse);
      expect(lower.progress.bestScore, 1000);
      expect(lower.previousBest, 1000);
    });

    test('participation XP needs a few placements', () {
      final quick = const CampProgress.initial().applyRun(
        run(0, placements: CampProgress.participationMinPlacements - 1),
      );
      expect(quick.xpGained, 0);
      final real = const CampProgress.initial().applyRun(
        run(0, placements: CampProgress.participationMinPlacements),
      );
      expect(real.xpGained, CampProgress.participationXp);
    });

    test('small runs still move the bar and level ups unlock themes', () {
      final tiny = const CampProgress.initial().applyRun(run(30));
      expect(tiny.xpGained, greaterThan(0));
      final need = CampProgress.xpToAdvance(1) + CampProgress.xpToAdvance(2);
      final outcome = withXp(need - 10).applyRun(run(200));
      expect(outcome.levelBefore, 2);
      expect(outcome.levelAfter, 3);
      expect(outcome.newlyUnlockedThemes, [CampTheme.autumn]);
    });

    test('typical run reaches Lv3 in about two runs', () {
      var p = const CampProgress.initial();
      for (var i = 0; i < 2; i++) {
        p = p.applyRun(run(2000, mxp: 90)).progress;
      }
      expect(p.level, greaterThanOrEqualTo(3));
    });
  });

  group('json', () {
    test('round trip', () {
      final p = CampProgress(
        bestScore: 1234,
        discoveredTiers: const {1, 3, 5},
        totalXp: 2000,
        selectedTheme: CampTheme.autumn,
      );
      final back = CampProgress.fromJson(p.toJson());
      expect(back.bestScore, 1234);
      expect(back.discoveredTiers, {1, 3, 5});
      expect(back.totalXp, 2000);
      expect(back.selectedTheme, CampTheme.autumn);
    });

    test('corrupt and partial data fall back per field', () {
      expect(CampProgress.fromJson('nope').level, 1);
      expect(CampProgress.fromJson(null).bestScore, 0);
      final p = CampProgress.fromJson({
        'bestScore': 'x',
        'discoveredTiers': [2, 'a', 99, -3],
        'totalXp': -5,
        'selectedTheme': 'night',
      });
      expect(p.bestScore, 0);
      expect(p.discoveredTiers, {1, 2, 8});
      expect(p.totalXp, 0);
      expect(p.selectedTheme, CampTheme.summer, reason: 'night is locked');
      final kept = CampProgress.fromJson({'bestScore': 50});
      expect(kept.bestScore, 50);
    });
  });

  group('store', () {
    test('memory store round trip', () async {
      final store = MemoryCampProgressStore();
      expect((await store.load()).bestScore, 0);
      await store.save(withXp(10).applyRun(run(300)).progress);
      expect((await store.load()).bestScore, 300);
      expect(store.saveCount, 1);
    });

    test(
      'shared preferences store persists and survives corrupt data',
      () async {
        SharedPreferences.setMockInitialValues({});
        const store = CampProgressStore();
        expect((await store.load()).bestScore, 0);
        await store.save(withXp(5).applyRun(run(700, tier: 3)).progress);
        final loaded = await store.load();
        expect(loaded.bestScore, 700);
        expect(loaded.discoveredTiers, {1, 3});

        SharedPreferences.setMockInitialValues({
          CampProgressStore.progressKey: '{not json',
        });
        expect((await store.load()).bestScore, 0);
        SharedPreferences.setMockInitialValues({
          CampProgressStore.progressKey: '[1,2]',
        });
        expect((await store.load()).level, 1);
      },
    );
  });
}
