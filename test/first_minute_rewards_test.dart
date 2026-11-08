import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_camp/src/art/sticker_art.dart';
import 'package:merge_camp/src/audio/sound_mute_store.dart';
import 'package:merge_camp/src/game/how_to_play.dart';
import 'package:merge_camp/src/game/merge_camp_controller.dart';
import 'package:merge_camp/src/game/merge_camp_screen.dart';
import 'package:merge_camp/src/meta/camp_progress.dart';
import 'package:merge_camp/src/meta/camp_progress_store.dart';
import 'package:merge_camp/src/meta/camp_theme.dart';
import 'package:merge_camp/src/meta/missions.dart';
import 'package:merge_camp/src/meta/stickers.dart';

// Acceptance tests for harness/specs/feature-first-minute-rewards.md.

class _TutorialStore extends HowToPlayStore {
  _TutorialStore({this.seen = false});
  bool seen;
  @override
  Future<bool> loadSeen() async => seen;
  @override
  Future<void> markSeen() async => seen = true;
}

class _UnmutedStore extends SoundMuteStore {
  const _UnmutedStore();
  @override
  Future<bool> loadMuted() async => false;
  @override
  Future<void> saveMuted(bool muted) async {}
}

class _Screen {
  _Screen(this.controller, this.missions, this.audio);
  final MergeCampController controller;
  final MissionBoard missions;
  final List<String> audio;
}

Future<_Screen> _pump(
  WidgetTester tester, {
  required HowToPlayStore tutorial,
  required MemoryCampProgressStore store,
  int seed = 0,
  MissionBoard? missions,
}) async {
  final audio = <String>[];
  for (final channel in const [
    MethodChannel('merge_camp/audio'),
    SystemChannels.platform,
  ]) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      if (channel.name == 'merge_camp/audio') {
        audio.add('${call.method}:${call.arguments}');
      }
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
  }
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final controller = MergeCampController(random: Random(seed));
  addTearDown(controller.dispose);
  missions ??= MissionBoard(random: Random(seed));
  await tester.pumpWidget(
    MaterialApp(
      // A new key per pump mounts a fresh screen, like reopening the game.
      key: UniqueKey(),
      home: MergeCampScreen(
        controller: controller,
        missions: missions,
        howToPlayStore: tutorial,
        soundMuteStore: const _UnmutedStore(),
        progressStore: store,
        animateArt: false,
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return _Screen(controller, missions, audio);
}

Finder _cell(int index) => find
    .descendant(
      of: find.byType(GridView),
      matching: find.byType(GestureDetector),
    )
    .at(index);

Future<void> _finishCardWithPlay(WidgetTester tester) async {
  for (var i = 0; i < 2; i++) {
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pump();
  }
  await tester.tap(find.widgetWithText(FilledButton, 'Play'));
  await tester.pump();
}

/// Places on free plots (far from the practice camp first) until the run
/// has [placements] placements.
Future<void> _placeUntil(
  WidgetTester tester,
  MergeCampController c,
  int placements,
) async {
  const order = [15, 12, 3, 9, 6, 14, 11, 8, 13, 7, 4, 10, 5, 1, 0, 2];
  while (c.placements < placements) {
    final free = order.firstWhere((i) => c.board[i] == null);
    await tester.tap(_cell(free));
    await tester.pump();
  }
}

Set<int> _boardStickerSlots(WidgetTester tester) {
  final painter =
      tester
              .widget<CustomPaint>(find.byKey(const ValueKey('board-stickers')))
              .painter!
          as BoardStickerPainter;
  return painter.slots.occupied.toSet();
}

int _xpForLevel(int level) => CampProgress.totalXpForLevel(level);

CampProgress _welcome() => CampProgress(
  bestScore: 0,
  discoveredTiers: const {1, 2},
  totalXp: CampProgress.welcomeBonusXp,
  selectedTheme: CampTheme.summer,
  stickerSlots: const StickerSlots.empty().put('pennant', 0),
  stickersSeen: 1,
  welcomeRun: true,
);

const _summary = RunSummary(
  score: 300,
  highestTier: 3,
  bestChain: 1,
  placements: 8,
  mergeCount: 2,
  missionXp: 60,
);

void main() {
  group('progress', () {
    test('runXp matches what applyRun credits', () {
      final xp = CampProgress.runXp(_summary);
      expect(xp, 30 + 60 + CampProgress.participationXp);
      final outcome = const CampProgress.initial().applyRun(_summary);
      expect(outcome.xpGained, xp);
      expect(
        CampProgress.runXp(
          const RunSummary(
            score: 500,
            highestTier: 1,
            bestChain: 0,
            placements: 0,
          ),
        ),
        0,
      );
    });

    test('the welcome bonus is given once and only to new players', () {
      final fresh = const CampProgress.initial().withStickersSeen();
      expect(fresh.welcomeBonusDue, isTrue);
      final bonus = fresh.withWelcomeBonus();
      expect(bonus.totalXp, CampProgress.welcomeBonusXp);
      expect(bonus.welcomeRun, isTrue);
      expect(bonus.welcomeBonusDue, isFalse);
      expect(identical(bonus.withWelcomeBonus(), bonus), isTrue);
      for (final existing in [
        CampProgress(
          bestScore: 10,
          discoveredTiers: const {1},
          totalXp: 0,
          selectedTheme: CampTheme.summer,
        ),
        CampProgress(
          bestScore: 0,
          discoveredTiers: const {1},
          totalXp: 5,
          selectedTheme: CampTheme.summer,
        ),
      ]) {
        expect(existing.welcomeBonusDue, isFalse);
        expect(identical(existing.withWelcomeBonus(), existing), isTrue);
      }
    });

    test('the welcome run levels up to Lv 2 once, mid-run', () {
      final start = _welcome();
      // Not enough XP yet.
      expect(identical(start.withLiveLevelUp(10), start), isTrue);
      final awards = <StickerAward>[];
      final missing = _xpForLevel(2) - start.totalXp;
      final up = start.withLiveLevelUp(missing, awards: awards);
      expect(awards.single.sticker.id, 'pine-tree');
      expect(awards.single.slot, 1);
      expect(up.stickerSlots.at(1), 'pine-tree');
      expect(up.stickersSeen, 2);
      expect(up.level, 1, reason: 'saved XP is unchanged mid-run');
      expect(up.stickerLevel, 2);
      expect(up.totalXp, start.totalXp);
      // Idempotent, and never past the welcome level mid-run.
      expect(identical(up.withLiveLevelUp(missing + 5000), up), isTrue);
      // Only during the welcome run.
      final normal = CampProgress(
        bestScore: 10,
        discoveredTiers: const {1},
        totalXp: 200,
        selectedTheme: CampTheme.summer,
        stickersSeen: 1,
      );
      expect(identical(normal.withLiveLevelUp(500), normal), isTrue);
    });

    test('the run end neither repeats the sticker nor double counts XP', () {
      final missing = _xpForLevel(2) - CampProgress.welcomeBonusXp;
      final up = _welcome().withLiveLevelUp(missing);
      final summary = RunSummary(
        score: missing * 10,
        highestTier: 3,
        bestChain: 1,
        placements: 3,
        mergeCount: 1,
      );
      final outcome = up.applyRun(summary);
      final p = outcome.progress;
      expect(
        p.totalXp,
        CampProgress.welcomeBonusXp + CampProgress.runXp(summary),
      );
      expect(p.level, 2);
      expect(outcome.newStickers, isEmpty);
      expect(outcome.announcesLevelUp, isFalse);
      expect(outcome.newlyUnlockedThemes, isEmpty);
      expect(p.welcomeRun, isFalse);
      expect(p.stickerSlots.occupied.toList(), [0, 1]);
      expect(p.stickerSlots.slotOf('pine-tree'), 1);
      expect(p.stickersSeen, 2);
    });

    test('levels past the welcome level are still announced at run end', () {
      final up = _welcome().withLiveLevelUp(1000);
      final summary = RunSummary(
        score: (_xpForLevel(3) - CampProgress.welcomeBonusXp) * 10,
        highestTier: 4,
        bestChain: 1,
        placements: 9,
        mergeCount: 3,
      );
      final outcome = up.applyRun(summary);
      expect(outcome.levelBefore, 1);
      expect(outcome.announcedLevel, 2);
      expect(outcome.levelAfter, greaterThanOrEqualTo(3));
      expect(outcome.announcesLevelUp, isTrue);
      expect(outcome.newStickers.first.sticker.id, 'acorn');
      expect(
        outcome.newStickers.map((a) => a.sticker.id),
        isNot(contains('pine-tree')),
      );
      expect(outcome.newlyUnlockedThemes, contains(CampTheme.autumn));
    });

    test('a mid-run sticker survives a reload of the save', () {
      final up = _welcome().withLiveLevelUp(1000).withActiveRun({
        'version': 1,
        'controller': 'x',
      });
      final json = jsonDecode(jsonEncode(up.toJson()));
      final loaded = CampProgress.fromJson(json);
      expect(loaded.welcomeRun, isTrue);
      expect(loaded.level, 1);
      expect(loaded.stickerSlots.at(1), 'pine-tree');
      expect(loaded.activeRun, isNotNull);
      expect(identical(loaded.withLiveLevelUp(5000), loaded), isTrue);
      // Old saves have no welcome flag.
      final legacy = CampProgress.fromJson({'totalXp': 40, 'bestScore': 9});
      expect(legacy.welcomeRun, isFalse);
      expect(legacy.toJson().containsKey('welcomeRun'), isFalse);
    });

    test('existing players keep the old run-end level-up', () {
      final p = CampProgress(
        bestScore: 50,
        discoveredTiers: const {1},
        totalXp: _xpForLevel(2) - 10,
        selectedTheme: CampTheme.summer,
        stickerSlots: const StickerSlots.empty().put('pennant', 0),
        stickersSeen: 1,
      );
      expect(p.stickerLevel, 1);
      final outcome = p.applyRun(_summary);
      expect(outcome.announcedLevel, outcome.levelBefore);
      expect(outcome.announcesLevelUp, isTrue);
      expect(outcome.newStickers.single.sticker.id, 'pine-tree');
      expect(outcome.progress.stickersSeen, 2);
    });
  });

  group('screen', () {
    testWidgets('a new player levels up with a second sticker in the first '
        'run', (tester) async {
      final store = MemoryCampProgressStore();
      final tutorial = _TutorialStore();
      var s = await _pump(tester, tutorial: tutorial, store: store);
      await _finishCardWithPlay(tester);
      expect(store.value.stickerSlots.at(0), 'pennant');

      // Guided first merge: welcome bonus and the first starter mission.
      await tester.tap(_cell(2));
      await tester.pump();
      expect(
        find.text('First merge! Welcome bonus +150 camp XP'),
        findsOneWidget,
      );
      expect(store.value.totalXp, CampProgress.welcomeBonusXp);
      expect(store.value.welcomeRun, isTrue);
      expect(store.value.stickerSlots.at(1), isNull);
      expect(s.audio.where((a) => a.contains('level_up')), isEmpty);

      // Second starter mission (6 placements) brings Lv 2 mid-run.
      await _placeUntil(tester, s.controller, 5);
      expect(store.value.stickersSeen, 1);
      await _placeUntil(tester, s.controller, 6);
      expect(s.controller.isGameOver, isFalse);
      expect(s.missions.completedThisRun, greaterThanOrEqualTo(2));
      expect(find.byKey(const ValueKey('reward-toast')), findsOneWidget);
      expect(
        find.text('Level up! Lv 2 - New sticker: Pine Tree'),
        findsOneWidget,
      );
      expect(store.value.stickersSeen, 2);
      expect(store.value.stickerSlots.at(1), 'pine-tree');
      expect(store.value.totalXp, CampProgress.welcomeBonusXp);
      expect(store.value.activeRun, isNotNull);
      expect(_boardStickerSlots(tester), {0, 1});
      expect(s.audio.where((a) => a.contains('level_up')), hasLength(1));
      // The HUD shows the live level.
      expect(find.text('Lv'), findsWidgets);
      await tester.pump(const Duration(seconds: 3));

      // Reload mid-run: the run and the sticker are back, nothing repeats.
      final snapshot = s.controller.toSnapshot();
      s = await _pump(tester, tutorial: tutorial, store: store, seed: 7);
      expect(s.controller.toSnapshot(), snapshot);
      expect(_boardStickerSlots(tester), {0, 1});
      await _placeUntil(tester, s.controller, 7);
      expect(find.byKey(const ValueKey('reward-toast')), findsNothing);
      expect(s.audio.where((a) => a.contains('level_up')), isEmpty);
      await tester.pump(const Duration(seconds: 3));

      // Settling the run credits its XP once and announces nothing again.
      final runXp = CampProgress.runXp(
        RunSummary(
          score: s.controller.score,
          highestTier: s.controller.highestTier,
          bestChain: s.controller.bestMergeChain,
          placements: s.controller.placements,
          missionXp: s.missions.xpEarned,
          mergeCount: s.controller.mergeCount,
        ),
      );
      await tester.tap(find.byTooltip('Restart run'));
      await tester.pump();
      expect(store.value.totalXp, CampProgress.welcomeBonusXp + runXp);
      expect(store.value.welcomeRun, isFalse);
      expect(store.value.level, 2);
      expect(find.textContaining('New sticker'), findsNothing);
      expect(store.value.stickerSlots.occupied.toList(), [0, 1]);
      await tester.pump(const Duration(seconds: 3));

      // The next run is a normal one: no bonus, no celebrations.
      s = await _pump(tester, tutorial: tutorial, store: store);
      await _placeUntil(tester, s.controller, 6);
      expect(find.textContaining('Welcome bonus'), findsNothing);
      expect(store.value.totalXp, CampProgress.welcomeBonusXp + runXp);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('first-run celebrations show once; not for existing players', (
      tester,
    ) async {
      // A mission set without big-merge and chain missions, so the toasts
      // are not replaced by mission toasts.
      var seed = 0;
      while (MissionBoard(random: Random(seed)).active.any(
        (m) =>
            m.kind == MissionKind.bigMerge || m.kind == MissionKind.makeChain,
      )) {
        seed += 1;
      }
      Future<_Screen> start(CampProgress progress) => _pump(
        tester,
        tutorial: _TutorialStore(seen: true),
        store: MemoryCampProgressStore(progress),
        missions: MissionBoard(random: Random(seed)),
      );
      List<int?> board(List<int> ones) => [
        for (var i = 0; i < 16; i++) ones.contains(i) ? 1 : null,
      ];

      Future<void> play(_Screen s, {required bool celebrate}) async {
        // First merge (3 camps).
        s.controller.debugLoadBoard(board([0, 1]), nextTier: 1);
        await tester.tap(_cell(2));
        await tester.pump();
        expect(
          find.text('First merge! Welcome bonus +150 camp XP'),
          celebrate ? findsOneWidget : findsNothing,
        );
        await tester.pump(const Duration(seconds: 3));
        // A 4 camp merge, twice: celebrated the first time only.
        for (var i = 0; i < 2; i++) {
          s.controller.debugLoadBoard(
            board([8, 9, 12]),
            nextTier: 1,
            placements: 1,
            trailAxes: 2,
          );
          await tester.tap(_cell(13));
          await tester.pump();
          expect(
            find.text('Big merge! 4+ camps at once'),
            celebrate && i == 0 ? findsOneWidget : findsNothing,
          );
          await tester.pump(const Duration(seconds: 3));
        }
        // Trail Axe.
        await tester.tap(find.byKey(const ValueKey('trail-axe-button')));
        await tester.pump();
        await tester.tap(_cell(13));
        await tester.pump();
      }

      var s = await start(const CampProgress.initial());
      await play(s, celebrate: true);
      expect(find.text('Trail Axe cleared a plot!'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));

      s = await start(
        CampProgress(
          bestScore: 40,
          discoveredTiers: const {1, 2},
          totalXp: 60,
          selectedTheme: CampTheme.summer,
          stickersSeen: 1,
        ),
      );
      await play(s, celebrate: false);
      expect(find.text('Trail Axe cleared a plot!'), findsNothing);
      expect(find.textContaining('Welcome bonus'), findsNothing);
      expect(find.text('Big merge! 4+ camps at once'), findsNothing);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('an existing player still levels up at the run end', (
      tester,
    ) async {
      final store = MemoryCampProgressStore(
        CampProgress(
          bestScore: 40,
          discoveredTiers: const {1, 2},
          totalXp: _xpForLevel(2) - 5,
          selectedTheme: CampTheme.summer,
          stickerSlots: const StickerSlots.empty().put('pennant', 0),
          stickersSeen: 1,
        ),
      );
      final s = await _pump(
        tester,
        tutorial: _TutorialStore(seen: true),
        store: store,
      );
      await _placeUntil(tester, s.controller, 6);
      // Nothing mid-run.
      expect(store.value.level, 1);
      expect(store.value.stickersSeen, 1);
      expect(find.byKey(const ValueKey('reward-toast')), findsNothing);
      expect(find.textContaining('Welcome bonus'), findsNothing);
      // The run end levels up and announces the sticker as before.
      final board = List<int?>.generate(
        MergeCampController.cellCount,
        (index) => (index ~/ 4 + index % 4).isEven ? 1 : 2,
      );
      board[15] = null;
      s.controller.debugLoadBoard(
        board,
        nextTier: 3,
        trailAxes: 0,
        score: 200,
        placements: 10,
        lastAwardedAxeAt: 10,
      );
      await tester.tap(_cell(15));
      await tester.pumpAndSettle();
      expect(find.text('Camp jammed!'), findsOneWidget);
      expect(store.value.level, 2);
      expect(find.text('Level up! Lv 2'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('summary-sticker-pine-tree')),
        findsOneWidget,
      );
      expect(store.value.stickerSlots.at(1), 'pine-tree');
    });
  });
}
