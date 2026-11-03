import 'dart:async';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_camp/src/audio/sound_mute_store.dart';
import 'package:merge_camp/src/game/how_to_play.dart';
import 'package:merge_camp/src/game/merge_camp_controller.dart';
import 'package:merge_camp/src/game/merge_camp_screen.dart';
import 'package:merge_camp/src/meta/camp_progress.dart';
import 'package:merge_camp/src/meta/camp_progress_store.dart';
import 'package:merge_camp/src/meta/camp_theme.dart';
import 'package:merge_camp/src/meta/missions.dart';

// Acceptance tests for harness/specs/feature-first-run-resume.md: guided
// practice, starter missions, run resume and placement previews.

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

class _ThrowingProgressStore extends CampProgressStore {
  const _ThrowingProgressStore();
  @override
  Future<CampProgress> load() => Future.error(StateError('read failed'));
  @override
  Future<void> save(CampProgress progress) =>
      Future.error(StateError('write failed'));
}

/// Load completes only when the test says so.
class _GatedStore extends MemoryCampProgressStore {
  final Completer<void> gate = Completer<void>();
  @override
  Future<CampProgress> load() async {
    await gate.future;
    return super.load();
  }
}

class _Screen {
  _Screen(this.controller, this.missions);
  final MergeCampController controller;
  final MissionBoard missions;
}

Future<_Screen> _pump(
  WidgetTester tester, {
  required HowToPlayStore tutorial,
  required CampProgressStore store,
  Size size = const Size(390, 844),
  int seed = 0,
}) async {
  for (final channel in const [
    MethodChannel('merge_camp/audio'),
    SystemChannels.platform,
  ]) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async => null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
  }
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final controller = MergeCampController(random: Random(seed));
  addTearDown(controller.dispose);
  final missions = MissionBoard(random: Random(seed));
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
  return _Screen(controller, missions);
}

Finder _cell(int index) => find
    .descendant(
      of: find.byType(GridView),
      matching: find.byType(GestureDetector),
    )
    .at(index);

final _guided = find.byKey(const ValueKey('guided-plot'));
final _mergePreview = find.byKey(const ValueKey('merge-preview'));
final _placementPreview = find.byKey(const ValueKey('placement-preview'));

Future<void> _finishCardWithPlay(WidgetTester tester) async {
  for (var i = 0; i < 2; i++) {
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pump();
  }
  await tester.tap(find.widgetWithText(FilledButton, 'Play'));
  await tester.pump();
}

List<MissionKind> _kinds(MissionBoard m) => [
  for (final mission in m.active) mission.kind,
];

const _starterKinds = [
  MissionKind.mergeTimes,
  MissionKind.placeTiles,
  MissionKind.buildTier,
];

void main() {
  testWidgets('first Play starts a guided merge with fixed starter missions', (
    tester,
  ) async {
    final store = MemoryCampProgressStore();
    final s = await _pump(tester, tutorial: _TutorialStore(), store: store);
    await _finishCardWithPlay(tester);

    final c = s.controller;
    expect(c.board[0], 1);
    expect(c.board[1], 1);
    expect(c.placements, 0);
    expect(c.nextTier, 1);
    expect(_guided, findsOneWidget);
    expect(find.text('Skip practice'), findsOneWidget);
    expect(_kinds(s.missions), _starterKinds);
    expect(s.missions.active.first.label, 'Make your first merge');
    expect(store.value.activeRun?['guidedPractice'], isTrue);

    // Only the highlighted plot is accepted: other plots, the axe button and
    // the axe key do nothing.
    await tester.tap(_cell(5));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('trail-axe-button')));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyX);
    await tester.pump();
    expect(c.placements, 0);
    expect(c.board[0], 1);
    expect(c.trailAxes, 1);

    // A one-tap placement on the glowing plot makes a real merge.
    await tester.tap(_cell(2));
    await tester.pump();
    expect(c.board[2], 2);
    expect(c.board[0], isNull);
    expect(c.placements, 1);
    expect(c.mergeCount, 1);
    expect(c.score, 72);
    expect(find.text('New camp discovered!'), findsOneWidget);
    expect(store.value.discoveredTiers, contains(2));
    expect(s.missions.completedThisRun, 1);
    expect(c.trailAxes, 2, reason: 'first mission pays an axe');
    expect(
      find.text('Mission complete: Make your first merge (+1 Trail Axe)'),
      findsOneWidget,
    );
    expect(_guided, findsNothing);
    expect(store.value.activeRun?['guidedPractice'], isFalse);

    // Help during play never restarts the practice or resets the board.
    final before = c.toSnapshot();
    await tester.tap(find.byTooltip('How to play'));
    await tester.pump();
    await _finishCardWithPlay(tester);
    expect(c.toSnapshot(), before);
    expect(_guided, findsNothing);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('keyboard Enter completes the practice on the cursor plot', (
    tester,
  ) async {
    final s = await _pump(
      tester,
      tutorial: _TutorialStore(),
      store: MemoryCampProgressStore(),
    );
    await _finishCardWithPlay(tester);
    expect(find.byKey(const ValueKey('keyboard-cursor')), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(s.controller.placements, 0, reason: 'not the highlighted plot');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(s.controller.board[2], 2);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('Skip practice and Skip on the card bypass the practice', (
    tester,
  ) async {
    var s = await _pump(
      tester,
      tutorial: _TutorialStore(),
      store: MemoryCampProgressStore(),
    );
    await _finishCardWithPlay(tester);
    await tester.tap(find.text('Skip practice'));
    await tester.pump();
    expect(s.controller.occupiedCount, 0);
    expect(_guided, findsNothing);
    expect(_kinds(s.missions), _starterKinds);
    await tester.tap(_cell(9));
    await tester.pump();
    expect(s.controller.placements, 1);

    s = await _pump(
      tester,
      tutorial: _TutorialStore(),
      store: MemoryCampProgressStore(),
    );
    await tester.tap(find.text('Skip'));
    await tester.pump();
    expect(s.controller.occupiedCount, 0);
    expect(_guided, findsNothing);
    expect(_kinds(s.missions), _starterKinds);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('R and Escape on the practice board skip it, keeping missions', (
    tester,
  ) async {
    for (final key in const [
      LogicalKeyboardKey.keyR,
      LogicalKeyboardKey.escape,
    ]) {
      final s = await _pump(
        tester,
        tutorial: _TutorialStore(),
        store: MemoryCampProgressStore(),
      );
      await _finishCardWithPlay(tester);
      expect(_guided, findsOneWidget);
      await tester.sendKeyEvent(key);
      await tester.pump();
      expect(s.controller.occupiedCount, 0, reason: '$key');
      expect(_guided, findsNothing);
      expect(_kinds(s.missions), _starterKinds, reason: '$key');
      await tester.pump(const Duration(seconds: 3));
    }
  });

  testWidgets('closing the card before progress loads keeps the first run', (
    tester,
  ) async {
    // Play before the load: practice and starter missions start on arrival.
    var store = _GatedStore();
    var s = await _pump(tester, tutorial: _TutorialStore(), store: store);
    await _finishCardWithPlay(tester);
    expect(s.controller.occupiedCount, 0);
    store.gate.complete();
    await tester.pump();
    await tester.pump();
    expect(_guided, findsOneWidget);
    expect(_kinds(s.missions), _starterKinds);
    await tester.tap(_cell(2));
    await tester.pump();
    expect(s.missions.completedThisRun, 1);
    expect(s.controller.trailAxes, 2);
    await tester.pump(const Duration(seconds: 3));

    // Skip before the load: no practice, but still the starter missions.
    store = _GatedStore();
    s = await _pump(tester, tutorial: _TutorialStore(), store: store);
    await tester.tap(find.text('Skip'));
    await tester.pump();
    store.gate.complete();
    await tester.pump();
    await tester.pump();
    expect(_guided, findsNothing);
    expect(s.controller.occupiedCount, 0);
    expect(_kinds(s.missions), _starterKinds);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('returning players get no practice and random missions', (
    tester,
  ) async {
    final s = await _pump(
      tester,
      tutorial: _TutorialStore(seen: true),
      store: MemoryCampProgressStore(),
    );
    expect(s.controller.occupiedCount, 0);
    expect(_guided, findsNothing);
    expect(
      _kinds(s.missions),
      _kinds(MissionBoard(random: Random(0))),
      reason: 'existing random mission sets',
    );
  });

  testWidgets('practice survives a reload before the merge', (tester) async {
    final store = MemoryCampProgressStore();
    final tutorial = _TutorialStore();
    await _pump(tester, tutorial: tutorial, store: store);
    await _finishCardWithPlay(tester);
    expect(tutorial.seen, isTrue);

    final s = await _pump(tester, tutorial: tutorial, store: store, seed: 9);
    expect(s.controller.board[0], 1);
    expect(s.controller.board[1], 1);
    expect(_guided, findsOneWidget);
    expect(_kinds(s.missions), _starterKinds);
    await tester.tap(_cell(2));
    await tester.pump();
    expect(s.controller.board[2], 2);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('reloading restores the live run and credits it once', (
    tester,
  ) async {
    final store = MemoryCampProgressStore();
    final tutorial = _TutorialStore();
    var s = await _pump(tester, tutorial: tutorial, store: store);
    await _finishCardWithPlay(tester);
    await tester.tap(_cell(2)); // practice merge, first mission
    await tester.pump();
    for (final cell in const [8, 11, 13]) {
      await tester.tap(_cell(cell));
      await tester.pump();
    }
    // An axe swing is saved too.
    await tester.tap(find.byKey(const ValueKey('trail-axe-button')));
    await tester.pump();
    await tester.tap(_cell(8));
    await tester.pump();
    final controllerState = s.controller.toSnapshot();
    final missionState = s.missions.toSnapshot();
    expect(s.missions.xpEarned, MissionBoard.xpPerMission);
    expect(store.value.activeRun, isNotNull);
    await tester.pump(const Duration(seconds: 3));

    // Reopen: a different seed proves nothing is re-rolled.
    s = await _pump(tester, tutorial: tutorial, store: store, seed: 42);
    expect(s.controller.toSnapshot(), controllerState);
    expect(s.missions.toSnapshot(), missionState);
    expect(s.controller.previewTiers, controllerState['previewTiers']);
    expect(s.missions.xpEarned, MissionBoard.xpPerMission);
    expect(_guided, findsNothing);
    expect(store.value.totalXp, 0, reason: 'nothing settled yet');

    // Restart settles the run once, clearing the old snapshot in that write.
    final score = s.controller.score;
    await tester.tap(find.byTooltip('Restart run'));
    await tester.pump();
    final credited = CampProgress.xpForScore(score) + MissionBoard.xpPerMission;
    expect(store.value.totalXp, credited);
    expect(s.controller.placements, 0);
    final fresh = store.value.activeRun!;
    expect((fresh['controller'] as Map)['placements'], 0);
    await tester.pump(const Duration(seconds: 3));

    // Reopening after the settlement neither restores nor credits it again.
    s = await _pump(tester, tutorial: tutorial, store: store, seed: 3);
    expect(s.controller.placements, 0);
    expect(store.value.totalXp, credited);
    await tester.tap(find.byTooltip('Restart run'));
    await tester.pump();
    expect(store.value.totalXp, credited);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('a finished run is never restored or credited again', (
    tester,
  ) async {
    final store = MemoryCampProgressStore();
    final tutorial = _TutorialStore(seen: true);
    var s = await _pump(tester, tutorial: tutorial, store: store);
    final board = List<int?>.generate(
      16,
      (i) => (i ~/ 4 + i % 4).isEven ? 1 : 2,
    );
    board[15] = null;
    s.controller.debugLoadBoard(
      board,
      // A Supply Shed fits nowhere to merge, so this ends the run.
      nextTier: 3,
      previewTiers: const [3, 1, 1],
      trailAxes: 0,
      highestTier: 2,
      placements: 14,
      lastAwardedAxeAt: 10,
    );
    await tester.tap(_cell(15));
    await tester.pumpAndSettle();
    expect(s.controller.isGameOver, isTrue);
    expect(store.value.activeRun, isNull);
    final xp = store.value.totalXp;
    expect(xp, greaterThan(0));

    s = await _pump(tester, tutorial: tutorial, store: store);
    expect(s.controller.isGameOver, isFalse);
    expect(s.controller.occupiedCount, 0);
    expect(store.value.totalXp, xp);
  });

  testWidgets('malformed run snapshots keep meta progress and allow play', (
    tester,
  ) async {
    for (final bad in <Map<String, dynamic>>[
      {'version': 1, 'controller': 'nope'},
      {
        'version': 1,
        'controller': MergeCampController(random: Random(0)).toSnapshot()
          ..['score'] = -5,
        'missions': MissionBoard(random: Random(0)).toSnapshot(),
        'guidedPractice': false,
      },
      {
        // A guided flag on a board that is not the practice board.
        'version': 1,
        'controller': MergeCampController(random: Random(0)).toSnapshot(),
        'missions': MissionBoard(random: Random(0)).toSnapshot(),
        'guidedPractice': true,
      },
      {'version': 7},
    ]) {
      final store = MemoryCampProgressStore(
        const CampProgress(
          bestScore: 900,
          discoveredTiers: {1, 2, 3},
          totalXp: 700,
          selectedTheme: CampTheme.summer,
        ).withActiveRun(bad),
      );
      final s = await _pump(
        tester,
        tutorial: _TutorialStore(seen: true),
        store: store,
      );
      expect(s.controller.occupiedCount, 0, reason: '$bad');
      expect(_guided, findsNothing);
      expect(store.value.bestScore, 900);
      expect(store.value.totalXp, 700);
      expect(store.value.discoveredTiers, {1, 2, 3});
      await tester.tap(_cell(0));
      await tester.pump();
      expect(s.controller.placements, 1);
      expect(
        (store.value.activeRun!['controller'] as Map)['placements'],
        1,
        reason: 'the bad snapshot was replaced',
      );
      await tester.pump(const Duration(seconds: 3));
    }
  });

  testWidgets('storage errors fall back to a playable first run', (
    tester,
  ) async {
    final s = await _pump(
      tester,
      tutorial: _TutorialStore(),
      store: const _ThrowingProgressStore(),
    );
    await _finishCardWithPlay(tester);
    expect(_guided, findsOneWidget);
    await tester.tap(_cell(2));
    await tester.pump();
    expect(s.controller.board[2], 2);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('cursor and hover preview the merge without changing state', (
    tester,
  ) async {
    final s = await _pump(
      tester,
      tutorial: _TutorialStore(seen: true),
      store: MemoryCampProgressStore(),
    );
    final board = List<int?>.filled(16, null);
    board[1] = 1;
    board[4] = 1;
    s.controller.debugLoadBoard(board, nextTier: 1, previewTiers: [1, 2, 1]);
    await tester.pump();
    final before = s.controller.toSnapshot();

    // The first key reveals the cursor on plot 0: tents 1 and 4 join it.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(_placementPreview, findsOneWidget);
    expect(_mergePreview, findsNWidgets(3));
    expect(find.text('T2 / x1'), findsOneWidget);
    expect(s.controller.toSnapshot(), before);

    // Occupied plot: no preview.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(_placementPreview, findsNothing);
    expect(_mergePreview, findsNothing);

    // Axe mode: no preview.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.tap(find.byKey(const ValueKey('trail-axe-button')));
    await tester.pump();
    expect(_placementPreview, findsNothing);
    expect(_mergePreview, findsNothing);
    await tester.tap(find.byKey(const ValueKey('trail-axe-button')));
    await tester.pump();

    // A mouse hover previews too, and wins over the keyboard cursor.
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(_cell(15)));
    await tester.pump();
    expect(_placementPreview, findsOneWidget);
    expect(_mergePreview, findsNothing, reason: 'plot 15 merges nothing');
    expect(s.controller.toSnapshot(), before);

    // The real placement agrees with the preview.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(s.controller.board[0], 2);
    expect(s.controller.board[1], isNull);
    expect(s.controller.board[4], isNull);
    await tester.pump(const Duration(seconds: 3));
  });

  for (final size in const [
    Size(1280, 720),
    Size(1366, 768),
    Size(390, 844),
    Size(360, 640),
    Size(640, 480),
  ]) {
    testWidgets('practice fits $size without overflow', (tester) async {
      await _pump(
        tester,
        tutorial: _TutorialStore(),
        store: MemoryCampProgressStore(),
        size: size,
      );
      expect(tester.takeException(), isNull);
      await _finishCardWithPlay(tester);
      expect(tester.takeException(), isNull);
      expect(_guided, findsOneWidget);
      final skip = tester.getRect(find.text('Skip practice'));
      expect(skip.bottom, lessThanOrEqualTo(size.height));
      expect(skip.right, lessThanOrEqualTo(size.width));
      final grid = tester.getRect(find.byType(GridView));
      expect(grid.bottom, lessThanOrEqualTo(size.height));
      expect(grid.right, lessThanOrEqualTo(size.width));
    });
  }
}
