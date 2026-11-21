import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_camp/src/game/how_to_play.dart';
import 'package:merge_camp/src/game/merge_camp_controller.dart';
import 'package:merge_camp/src/game/merge_camp_screen.dart';
import 'package:merge_camp/src/meta/camp_progress_store.dart';
import 'package:merge_camp/src/platform/game_platform.dart';

class _SeenStore extends HowToPlayStore {
  const _SeenStore();
  @override
  Future<bool> loadSeen() async => true;
  @override
  Future<void> markSeen() async {}
}

class _RewardedPlatform extends GamePlatform {
  _RewardedPlatform({this.rewarded = true});

  final bool rewarded;
  Completer<bool>? pending;
  int rewardedAds = 0;
  int breakAds = 0;

  @override
  Future<void> initialize() async {}
  final List<String> events = <String>[];
  @override
  void gameplayStart() => events.add('start');
  @override
  void gameplayStop() => events.add('stop');
  @override
  Future<void> showRunBreakAd() async => breakAds += 1;
  @override
  bool get supportsRewardedAds => rewarded;
  @override
  Future<bool> showRewardedAd() {
    rewardedAds += 1;
    pending = Completer<bool>();
    return pending!.future;
  }

  @override
  bool get isAudioMuted => false;
  @override
  bool get allowsResultRegistration => false;
}

/// Checkerboard of tiers 1 and 2 with the last cell empty; a tier-3 tile
/// fills the board without merging and locks the run.
void _loadLock(
  MergeCampController controller, {
  int placements = 30,
  bool revived = false,
}) {
  final board = List<int?>.generate(
    MergeCampController.cellCount,
    (index) => (index ~/ 4 + index % 4).isEven ? 1 : 2,
  );
  board[15] = null;
  controller.debugLoadBoard(
    board,
    nextTier: 3,
    trailAxes: 0,
    placements: placements,
    lastAwardedAxeAt: placements ~/ 10 * 10,
    score: 500,
    highestTier: 3,
    revived: revived,
  );
}

Future<void> _pump(
  WidgetTester tester,
  GamePlatform platform,
  MergeCampController controller, {
  MemoryCampProgressStore? store,
}) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: MergeCampScreen(
        platform: platform,
        controller: controller,
        howToPlayStore: const _SeenStore(),
        progressStore: store ?? MemoryCampProgressStore(),
        animateArt: false,
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('controller', () {
    test('a lock after 20 placements can be revived once', () {
      final c = MergeCampController();
      addTearDown(c.dispose);
      _loadLock(c);
      expect(c.canRevive, isFalse);
      c.place(15);
      expect(c.isGameOver, isTrue);
      expect(c.canRevive, isTrue);

      final score = c.score;
      final placements = c.placements;
      expect(c.revive(), isTrue);
      expect(c.isGameOver, isFalse);
      expect(c.revived, isTrue);
      expect(c.board.where((t) => t != null).length, 16 - 6);
      expect(c.score, score);
      expect(c.placements, placements);
      expect(c.revive(), isFalse);
    });

    test('clears the lowest tiers first, lowest cell first on ties', () {
      final c = MergeCampController();
      addTearDown(c.dispose);
      _loadLock(c);
      c.place(15);
      final before = c.board;
      c.revive();
      final after = c.board;
      // Tier 1 camps sit on even (x + y) cells: 0,2,5,7,8,10,13 (the 15th holds the
      // new tier 3), so the six lowest cell indexes among them are cleared.
      for (final cell in [0, 2, 5, 7, 8, 10]) {
        expect(before[cell], 1);
        expect(after[cell], isNull);
      }
      expect(after[13], 1);
      expect(after[15], 3);
      expect(after[1], 2);
    });

    test('short runs and live boards cannot be revived', () {
      final c = MergeCampController();
      addTearDown(c.dispose);
      _loadLock(c, placements: 18);
      c.place(15);
      expect(c.isGameOver, isTrue);
      expect(c.canRevive, isFalse);
      expect(c.revive(), isFalse);

      final live = MergeCampController();
      addTearDown(live.dispose);
      expect(live.revive(), isFalse);
    });

    test('restart gives the run a new Second Wind', () {
      final c = MergeCampController();
      addTearDown(c.dispose);
      _loadLock(c);
      c.place(15);
      c.revive();
      expect(c.revived, isTrue);
      c.restart();
      expect(c.revived, isFalse);
    });

    test('revived is saved and a reload cannot revive again', () {
      final c = MergeCampController();
      addTearDown(c.dispose);
      _loadLock(c);
      c.place(15);
      c.revive();
      final snapshot = c.toSnapshot();
      expect(snapshot['revived'], isTrue);

      final other = MergeCampController();
      addTearDown(other.dispose);
      expect(other.restoreSnapshot(snapshot), isTrue);
      expect(other.revived, isTrue);

      expect(other.isGameOver, isFalse);
    });

    test('snapshots without the field load as not revived', () {
      final c = MergeCampController();
      addTearDown(c.dispose);
      final snapshot = c.toSnapshot();
      expect(snapshot.containsKey('revived'), isFalse);
      expect(c.restoreSnapshot(snapshot), isTrue);
      expect(c.revived, isFalse);
      expect(c.restoreSnapshot({...snapshot, 'revived': 'yes'}), isFalse);
      expect(c.restoreSnapshot({...snapshot, 'revived': false}), isTrue);
    });
  });

  group('screen', () {
    testWidgets('a lock shows the card and settles nothing yet', (
      tester,
    ) async {
      final platform = _RewardedPlatform();
      final controller = MergeCampController();
      addTearDown(controller.dispose);
      await _pump(tester, platform, controller);

      _loadLock(controller);
      controller.place(15);
      await tester.pump();

      expect(find.byKey(const ValueKey('second-wind-card')), findsOneWidget);
      expect(find.text('Play again'), findsNothing);
      expect(platform.breakAds, 0);
    });

    testWidgets('a finished ad clears camps and resumes the run', (
      tester,
    ) async {
      final platform = _RewardedPlatform();
      final controller = MergeCampController();
      addTearDown(controller.dispose);
      await _pump(tester, platform, controller);
      _loadLock(controller);
      controller.place(15);
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('second-wind-continue')));
      await tester.pump();
      expect(platform.rewardedAds, 1);
      platform.pending!.complete(true);
      await tester.pump();
      await tester.pump();

      expect(controller.isGameOver, isFalse);
      expect(controller.board.where((t) => t != null).length, 10);
      expect(find.byKey(const ValueKey('second-wind-card')), findsNothing);
      expect(find.text('Play again'), findsNothing);
    });

    testWidgets('an unfinished ad rewards nothing and settles the run', (
      tester,
    ) async {
      final platform = _RewardedPlatform();
      final controller = MergeCampController();
      final store = MemoryCampProgressStore();
      addTearDown(controller.dispose);
      await _pump(tester, platform, controller, store: store);
      _loadLock(controller);
      controller.place(15);
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('second-wind-continue')));
      await tester.pump();
      platform.pending!.complete(false);
      await tester.pump();
      await tester.pump();

      expect(controller.isGameOver, isTrue);
      expect(controller.board.where((t) => t != null).length, 16);
      expect(find.byKey(const ValueKey('second-wind-card')), findsNothing);
      expect(find.text('Play again'), findsOneWidget);
      expect(store.value.bestScore, controller.score);
    });

    testWidgets('the offer comes once per session, not on every lock', (
      tester,
    ) async {
      final platform = _RewardedPlatform();
      final controller = MergeCampController();
      addTearDown(controller.dispose);
      await _pump(tester, platform, controller);
      _loadLock(controller);
      controller.place(15);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('second-wind-end')));
      await tester.pump();
      expect(find.text('Play again'), findsOneWidget);

      // A new run that locks again in the same session gets no card.
      controller.restart();
      await tester.pump();
      _loadLock(controller);
      controller.place(15);
      await tester.pump();
      expect(find.byKey(const ValueKey('second-wind-card')), findsNothing);
      expect(find.text('Play again'), findsOneWidget);
    });

    testWidgets('Esc ends the run and shows the summary', (tester) async {
      final platform = _RewardedPlatform();
      final controller = MergeCampController();
      addTearDown(controller.dispose);
      await _pump(tester, platform, controller);
      _loadLock(controller);
      controller.place(15);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.byKey(const ValueKey('second-wind-card')), findsNothing);
      expect(find.text('Play again'), findsOneWidget);
      expect(platform.rewardedAds, 0);
    });

    testWidgets('platforms without rewarded ads end the run as before', (
      tester,
    ) async {
      final platform = _RewardedPlatform(rewarded: false);
      final controller = MergeCampController();
      addTearDown(controller.dispose);
      await _pump(tester, platform, controller);
      _loadLock(controller);
      controller.place(15);
      await tester.pump();

      expect(find.byKey(const ValueKey('second-wind-card')), findsNothing);
      expect(find.text('Play again'), findsOneWidget);
    });

    testWidgets('nothing is credited until End run, and only once', (
      tester,
    ) async {
      final platform = _RewardedPlatform();
      final controller = MergeCampController();
      final store = MemoryCampProgressStore();
      addTearDown(controller.dispose);
      await _pump(tester, platform, controller, store: store);
      _loadLock(controller);
      controller.place(15);
      await tester.pump();

      expect(store.value.bestScore, 0);
      expect(store.value.totalXp, 0);

      await tester.tap(find.byKey(const ValueKey('second-wind-end')));
      await tester.pump();
      await tester.pump();
      final credited = store.value.totalXp;
      expect(store.value.bestScore, controller.score);
      expect(credited, greaterThan(0));

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(store.value.totalXp, credited);
    });

    testWidgets('Enter on the card starts the ad; R is ignored meanwhile', (
      tester,
    ) async {
      final platform = _RewardedPlatform();
      final controller = MergeCampController();
      addTearDown(controller.dispose);
      await _pump(tester, platform, controller);
      _loadLock(controller);
      controller.place(15);
      await tester.pump();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(platform.rewardedAds, 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
      await tester.pump();
      expect(find.byKey(const ValueKey('second-wind-card')), findsOneWidget);
      expect(platform.rewardedAds, 1);

      platform.pending!.complete(true);
      await tester.pump();
      await tester.pump();
      expect(controller.isGameOver, isFalse);
    });

    testWidgets('gameplay stops at the lock and restarts after the revive', (
      tester,
    ) async {
      final platform = _RewardedPlatform();
      final controller = MergeCampController();
      addTearDown(controller.dispose);
      await _pump(tester, platform, controller);
      _loadLock(controller);
      controller.place(15);
      await tester.pump();
      expect(platform.events.last, 'stop');

      await tester.tap(find.byKey(const ValueKey('second-wind-continue')));
      await tester.pump();
      platform.pending!.complete(true);
      await tester.pump();
      await tester.pump();
      expect(platform.events.last, 'start');
    });

    testWidgets('a revived run that locks again ends without an offer', (
      tester,
    ) async {
      final platform = _RewardedPlatform();
      final controller = MergeCampController();
      addTearDown(controller.dispose);
      await _pump(tester, platform, controller);
      _loadLock(controller);
      controller.place(15);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('second-wind-continue')));
      await tester.pump();
      platform.pending!.complete(true);
      await tester.pump();
      await tester.pump();

      _loadLock(controller, revived: true);
      controller.place(15);
      await tester.pump();
      expect(find.byKey(const ValueKey('second-wind-card')), findsNothing);
      expect(find.text('Play again'), findsOneWidget);
    });
  });

  testWidgets('the card fits 320px wide screens', (tester) async {
    final platform = _RewardedPlatform();
    final controller = MergeCampController();
    addTearDown(controller.dispose);
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: MergeCampScreen(
          platform: platform,
          controller: controller,
          howToPlayStore: const _SeenStore(),
          progressStore: MemoryCampProgressStore(),
          animateArt: false,
        ),
      ),
    );
    await tester.pump();
    _loadLock(controller);
    controller.place(15);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('second-wind-continue')), findsOneWidget);
  });
}
