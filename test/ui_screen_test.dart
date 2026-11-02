import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_camp/src/art/camp_scenery.dart';
import 'package:merge_camp/src/art/camp_tile_art.dart';
import 'package:merge_camp/src/game/how_to_play.dart';
import 'package:merge_camp/src/game/merge_camp_controller.dart';
import 'package:merge_camp/src/game/merge_camp_screen.dart';
import 'package:merge_camp/src/meta/camp_progress.dart';
import 'package:merge_camp/src/meta/camp_progress_store.dart';
import 'package:merge_camp/src/meta/camp_theme.dart';
import 'package:merge_camp/src/meta/missions.dart';
import 'package:merge_camp/src/platform/game_platform.dart';

class _SeenStore extends HowToPlayStore {
  const _SeenStore();
  @override
  Future<bool> loadSeen() async => true;
  @override
  Future<void> markSeen() async {}
}

/// Always picks index 0, so the first mission set is fixed:
/// makeChain x2, buildTier Supply Shed, bigMerge 4+.
class _ZeroRandom implements Random {
  @override
  int nextInt(int max) => 0;
  @override
  double nextDouble() => 0;
  @override
  bool nextBool() => false;
}

class _RecordingPlatform extends NoopGamePlatform {
  _RecordingPlatform() : super(allowsResultRegistration: false);
  final List<String> events = <String>[];
  @override
  void gameplayStart() => events.add('start');
  @override
  void gameplayStop() => events.add('stop');
}

class _Harness {
  _Harness(this.controller, this.store, this.missions);
  final MergeCampController controller;
  final MemoryCampProgressStore store;
  final MissionBoard missions;
}

Future<_Harness> _pump(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  List<int>? scripted,
  CampProgress progress = const CampProgress.initial(),
  GamePlatform platform = const NoopGamePlatform(
    allowsResultRegistration: false,
  ),
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
  final controller = MergeCampController(
    random: Random(0),
    scriptedTiers: scripted,
  );
  addTearDown(controller.dispose);
  final store = MemoryCampProgressStore(progress);
  final missions = MissionBoard(random: _ZeroRandom());
  await tester.pumpWidget(
    MaterialApp(
      home: MergeCampScreen(
        controller: controller,
        howToPlayStore: const _SeenStore(),
        progressStore: store,
        missions: missions,
        platform: platform,
        animateArt: false,
      ),
    ),
  );
  await tester.pump();
  return _Harness(controller, store, missions);
}

Finder _cell(int index) => find
    .descendant(
      of: find.byType(GridView),
      matching: find.byType(GestureDetector),
    )
    .at(index);

/// Checkerboard of tiers 1 and 2 with the last cell empty: placing a tier-3
/// tile fills the board without merging and ends the run.
void _loadOneMoveFromGameOver(MergeCampController c, {int score = 0}) {
  final board = List<int?>.generate(
    MergeCampController.cellCount,
    (index) => (index ~/ 4 + index % 4).isEven ? 1 : 2,
  );
  board[15] = null;
  c.debugLoadBoard(board, nextTier: 3, trailAxes: 0, score: score);
}

void main() {
  testWidgets('tiles render as camp art, empty plots as plots', (tester) async {
    final h = await _pump(tester);
    final inGrid = find.descendant(
      of: find.byType(GridView),
      matching: find.byType(CampTileArt),
    );
    expect(inGrid, findsNothing);
    await tester.tap(_cell(5));
    // First frame starts the effect clock, the second finishes the drop.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(h.controller.board[5], isNotNull);
    expect(inGrid, findsOneWidget);
    expect(find.text('T1'), findsNothing);
  });

  testWidgets('a scripted chain plays the effect layer and the banner', (
    tester,
  ) async {
    final h = await _pump(tester);
    // Placing a 1 at cell 0 merges {0,1,2} into a 2, which merges with the
    // 2s at cells 4 and 8 into a 3: a x2 chain.
    final board = List<int?>.filled(16, null);
    board[1] = 1;
    board[2] = 1;
    board[4] = 2;
    board[8] = 2;
    h.controller.debugLoadBoard(board, nextTier: 1, highestTier: 2);
    await tester.pump();

    await tester.tap(_cell(0));
    await tester.pump(const Duration(milliseconds: 16));
    expect(h.controller.board[0], 3, reason: 'rules apply instantly');
    expect(h.controller.lastMergeChain, 2);
    expect(find.byKey(const ValueKey('fx-origin')), findsOneWidget);
    expect(find.text('Chain x2!'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 700));
    // Both merges have landed: two score popups are flying.
    for (final step in h.controller.lastMergeSteps) {
      expect(find.text('+${step.points}'), findsOneWidget);
    }

    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(const ValueKey('fx-origin')), findsNothing);
    expect(find.text('Chain x2!'), findsNothing);
  });

  testWidgets('effects are skipped when animations are disabled', (
    tester,
  ) async {
    final h = await _pump(tester);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pump();
    final board = List<int?>.filled(16, null);
    board[1] = 1;
    board[2] = 1;
    h.controller.debugLoadBoard(board, nextTier: 1);
    await tester.tap(_cell(0));
    await tester.pump(const Duration(milliseconds: 16));
    expect(h.controller.board[0], 2);
    expect(find.byKey(const ValueKey('fx-origin')), findsNothing);
  });

  testWidgets('missions: three are shown; completing one grants an axe', (
    tester,
  ) async {
    final h = await _pump(tester);
    expect(find.byKey(const ValueKey('mission-row')), findsNWidgets(3));
    expect(find.text('Merge 4+ tiles at once'), findsOneWidget);

    final board = List<int?>.filled(16, null);
    board[1] = 1;
    board[2] = 1;
    board[3] = 1;
    h.controller.debugLoadBoard(board, nextTier: 1, trailAxes: 1);
    await tester.tap(_cell(0));
    await tester.pump();

    expect(h.missions.completedThisRun, 1);
    expect(h.controller.trailAxes, 2);
    expect(
      find.text('Mission complete: Merge 4+ tiles at once (+1 Trail Axe)'),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 3));
    expect(find.textContaining('Mission complete'), findsNothing);
  });

  testWidgets('a mission at the axe cap pays bonus score instead', (
    tester,
  ) async {
    final h = await _pump(tester);
    final board = List<int?>.filled(16, null);
    board[1] = 1;
    board[2] = 1;
    board[3] = 1;
    h.controller.debugLoadBoard(board, nextTier: 1, trailAxes: 2);
    await tester.tap(_cell(0));
    await tester.pump();
    // 4 tiles * 12 * tier 2 = 96 points, plus the 150 mission bonus.
    expect(h.controller.score, 96 + 150);
    expect(h.controller.trailAxes, 2);
    expect(find.textContaining('(+150)'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('a first-time camp shows the banner and is saved at once', (
    tester,
  ) async {
    final h = await _pump(tester);
    final board = List<int?>.filled(16, null);
    board[1] = 1;
    board[2] = 1;
    h.controller.debugLoadBoard(board, nextTier: 1);
    await tester.tap(_cell(0));
    await tester.pump();

    expect(find.text('New camp discovered!'), findsOneWidget);
    expect(h.store.value.discoveredTiers, containsAll(<int>[1, 2]));
    // The banner never blocks the board.
    await tester.tap(_cell(15));
    await tester.pump();
    expect(h.controller.board[15], isNotNull);

    await tester.pump(const Duration(seconds: 3));
    expect(find.text('New camp discovered!'), findsNothing);
  });

  testWidgets('game over summary: score, best, new best; Enter replays', (
    tester,
  ) async {
    final h = await _pump(
      tester,
      progress: const CampProgress(
        bestScore: 100,
        discoveredTiers: {1, 2, 3},
        totalXp: 0,
        selectedTheme: CampTheme.summer,
      ),
    );
    _loadOneMoveFromGameOver(h.controller, score: 500);
    await tester.tap(_cell(15));
    await tester.pumpAndSettle();

    expect(h.controller.isGameOver, isTrue);
    expect(find.text('Camp jammed!'), findsOneWidget);
    expect(find.byKey(const ValueKey('summary-score')), findsOneWidget);
    // The last placement built a Supply Shed, which completes the "Build a
    // Supply Shed" mission; at game over that pays +150 instead of an axe.
    expect(h.missions.completedThisRun, 1);
    expect(h.controller.score, 650);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('summary-score'))).data,
      '650',
    );
    expect(find.text('Best 650'), findsWidgets);
    expect(find.text('New best!'), findsOneWidget);
    expect(find.text('Supply Shed'), findsOneWidget);
    expect(h.store.value.bestScore, 650);
    // 650 / 10 + 30 mission XP + 20 participation.
    expect(h.store.value.totalXp, 115);
    expect(find.text('+115 XP'), findsOneWidget);

    // The board ignores input while the summary is open.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(find.byKey(const ValueKey('keyboard-cursor')), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(h.controller.isGameOver, isFalse);
    expect(h.controller.placements, 0);
    expect(find.text('Camp jammed!'), findsNothing);
    expect(h.store.value.totalXp, 115, reason: 'the run is applied once');
  });

  testWidgets('Play again button and R both start a new run', (tester) async {
    final h = await _pump(tester);
    _loadOneMoveFromGameOver(h.controller);
    await tester.tap(_cell(15));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Play again'));
    await tester.pumpAndSettle();
    expect(h.controller.isGameOver, isFalse);

    _loadOneMoveFromGameOver(h.controller);
    await tester.tap(_cell(15));
    await tester.pumpAndSettle();
    expect(h.controller.isGameOver, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await tester.pumpAndSettle();
    expect(h.controller.isGameOver, isFalse);
  });

  testWidgets('restarting mid-run applies the run to camp progress', (
    tester,
  ) async {
    final h = await _pump(tester);
    await tester.tap(_cell(0));
    await tester.pump();
    expect(h.store.value.totalXp, 0);
    await tester.tap(find.byTooltip('Restart run'));
    await tester.pump();
    expect(h.controller.placements, 0);
    expect(h.store.value.totalXp, CampProgress.participationXp);
    await tester.pump(const Duration(seconds: 3));

    // An empty run gives nothing.
    await tester.tap(find.byTooltip('Restart run'));
    await tester.pump();
    expect(h.store.value.totalXp, CampProgress.participationXp);
  });

  testWidgets('album: silhouettes for unknown camps, locked themes', (
    tester,
  ) async {
    final platform = _RecordingPlatform();
    final h = await _pump(tester, platform: platform);
    expect(platform.events, ['start']);
    await tester.tap(find.byTooltip('Camp album'));
    await tester.pump();
    expect(find.text('Camp Album'), findsOneWidget);
    expect(platform.events, ['start', 'stop']);
    expect(find.text('???'), findsNWidgets(7));
    expect(find.text('Trail Tent'), findsOneWidget);
    final silhouettes = tester
        .widgetList<CampTileArt>(find.byType(CampTileArt))
        .where((art) => art.silhouette);
    expect(silhouettes.length, 7);

    await tester.tap(find.byKey(const ValueKey('theme-chip-autumn')));
    await tester.pump();
    expect(h.store.value.selectedTheme, CampTheme.summer);
    expect(find.text('Lv 3'), findsOneWidget);

    // Escape closes the album, resumes gameplay and refocuses the board.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.text('Camp Album'), findsNothing);
    expect(platform.events, ['start', 'stop', 'start']);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'MergeCampBoard');
    expect(h.controller.placements, 0);
  });

  testWidgets('selecting an unlocked theme repaints and persists', (
    tester,
  ) async {
    final h = await _pump(
      tester,
      progress: const CampProgress(
        bestScore: 0,
        discoveredTiers: {1},
        totalXp: 600, // level 3
        selectedTheme: CampTheme.summer,
      ),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Camp album'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('theme-chip-autumn')));
    await tester.pump();
    expect(h.store.value.selectedTheme, CampTheme.autumn);
    expect(
      tester.widget<CampScenery>(find.byType(CampScenery)).theme,
      CampTheme.autumn,
    );
    await tester.tap(find.byTooltip('Close album'));
    await tester.pump();
    expect(find.text('Camp Album'), findsNothing);
  });

  testWidgets('danger glow turns on at 13 occupied and off at 12', (
    tester,
  ) async {
    final h = await _pump(tester);
    final danger = find.byKey(const ValueKey('danger-vignette'));
    // 12 occupied cells without any matching group of 3.
    final board = <int?>[
      1, 2, 3, 4, //
      2, 3, 4, 1, //
      3, 4, 1, 2, //
      null, null, null, null,
    ];
    h.controller.debugLoadBoard(board, nextTier: 5, trailAxes: 1);
    await tester.pump();
    expect(danger, findsNothing);

    await tester.tap(_cell(12));
    await tester.pump(const Duration(milliseconds: 500));
    expect(h.controller.occupiedCount, 13);
    expect(danger, findsOneWidget);

    h.controller.useTrailAxe(12);
    await tester.pump();
    expect(h.controller.occupiedCount, 12);
    expect(danger, findsNothing);
  });

  for (final size in const [
    Size(1280, 720),
    Size(1280, 672),
    Size(1366, 768),
    Size(390, 844),
    Size(390, 796),
    Size(844, 390),
    Size(320, 640),
  ]) {
    testWidgets('layout fits $size without overflow', (tester) async {
      final h = await _pump(tester, size: size);
      expect(tester.takeException(), isNull);
      final grid = tester.getRect(find.byType(GridView));
      expect(grid.bottom, lessThanOrEqualTo(size.height));
      expect(grid.right, lessThanOrEqualTo(size.width));
      // Game over summary and album fit too.
      _loadOneMoveFromGameOver(h.controller);
      await tester.tap(_cell(15));
      await tester.pumpAndSettle();
      expect(find.text('Camp jammed!'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Album'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Album'));
      await tester.pumpAndSettle();
      expect(find.text('Camp Album'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
