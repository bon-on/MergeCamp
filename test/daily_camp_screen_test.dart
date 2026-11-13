import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_camp/src/game/how_to_play.dart';
import 'package:merge_camp/src/game/merge_camp_controller.dart';
import 'package:merge_camp/src/game/merge_camp_screen.dart';
import 'package:merge_camp/src/meta/camp_progress.dart';
import 'package:merge_camp/src/meta/camp_progress_store.dart';
import 'package:merge_camp/src/meta/missions.dart';
import 'package:merge_camp/src/platform/game_platform.dart';

class _SeenStore extends HowToPlayStore {
  const _SeenStore();
  @override
  Future<bool> loadSeen() async => true;
  @override
  Future<void> markSeen() async {}
}

DateTime _date(int day) => DateTime.utc(1970).add(Duration(days: day));

Future<
  ({
    MergeCampController controller,
    MemoryCampProgressStore store,
    List<int> clockDay,
  })
>
_pump(
  WidgetTester tester, {
  CampProgress progress = const CampProgress.initial(),
  Size size = const Size(390, 844),
  int day = 20000,
  MergeCampController? controller,
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
  final c = controller ?? MergeCampController();
  addTearDown(c.dispose);
  final store = MemoryCampProgressStore(progress);
  final clockDay = <int>[day];
  await tester.pumpWidget(
    MaterialApp(
      home: MergeCampScreen(
        controller: c,
        howToPlayStore: const _SeenStore(),
        progressStore: store,
        animateArt: false,
        platform: const NoopGamePlatform(allowsResultRegistration: false),
        clock: () => _date(clockDay.first),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return (controller: c, store: store, clockDay: clockDay);
}

/// Ends the run with a qualifying score: one move from a jammed board.
Future<void> _finishRun(
  WidgetTester tester,
  MergeCampController c, {
  int merges = 0,
}) async {
  final board = List<int?>.generate(
    MergeCampController.cellCount,
    (index) => (index ~/ 4 + index % 4).isEven ? 1 : 2,
  );
  board[15] = null;
  c.debugLoadBoard(
    board,
    nextTier: 3,
    trailAxes: 0,
    score: 120,
    placements: 10,
    lastAwardedAxeAt: 10,
    mergeCount: merges,
  );
  await tester.tap(
    find
        .descendant(
          of: find.byType(GridView),
          matching: find.byType(GestureDetector),
        )
        .at(15),
  );
  await tester.pumpAndSettle();
}

/// Ends the run with a qualifying score: five+ placements and merges.
Future<void> _qualifyingFinish(WidgetTester tester, MergeCampController c) =>
    _finishRun(tester, c, merges: 3);

void main() {
  testWidgets('the daily button shows a dot until today is rewarded', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.byTooltip('Daily camp'), findsOneWidget);
    expect(find.byKey(const ValueKey('daily-badge')), findsOneWidget);
  });

  testWidgets('no dot once today is rewarded', (tester) async {
    final rewarded = const CampProgress.initial().applyRun(
      const RunSummary(
        score: 500,
        highestTier: 3,
        bestChain: 1,
        placements: 20,
        mergeCount: 5,
      ),
      dailyDay: 20000,
    );
    await _pump(tester, progress: rewarded.progress);
    expect(find.byTooltip('Daily camp (streak 1)'), findsOneWidget);
    expect(find.byKey(const ValueKey('daily-badge')), findsNothing);
  });

  testWidgets('the daily button starts today\'s run once', (tester) async {
    final h = await _pump(tester);
    expect(h.controller.dailyDay, isNull);
    await tester.tap(find.byTooltip('Daily camp'));
    await tester.pump();
    expect(h.controller.dailyDay, 20000);
    final dealt = List<int>.of(h.controller.previewTiers);
    expect(
      dealt,
      MergeCampController(dailyDay: 20000).previewTiers,
      reason: 'everyone gets the same first pieces',
    );
    h.controller.place(0);
    await tester.pump();
    final placed = h.controller.placements;
    await tester.tap(find.byTooltip('Daily camp'));
    await tester.pump();
    expect(h.controller.placements, placed, reason: 'a running daily stays');
    await tester.pumpAndSettle(const Duration(seconds: 4));
  });

  testWidgets('a daily run pays the bonus and shows the streak summary', (
    tester,
  ) async {
    final h = await _pump(tester);
    await tester.tap(find.byTooltip('Daily camp'));
    await tester.pump();
    await _qualifyingFinish(tester, h.controller);

    expect(find.byKey(const ValueKey('summary-daily')), findsOneWidget);
    expect(find.textContaining('Daily streak 1'), findsOneWidget);
    expect(find.textContaining('+40 XP'), findsOneWidget);
    expect(find.text('Tomorrow: streak 2, +50 XP'), findsNothing);
    expect(
      find.byKey(const ValueKey('summary-daily-tomorrow')),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Free play'), findsOneWidget);
    expect(h.store.value.daily.streak, 1);
    expect(h.store.value.daily.lastDay, 20000);
  });

  testWidgets('try again replays the camp and free play leaves it', (
    tester,
  ) async {
    final h = await _pump(tester);
    await tester.tap(find.byTooltip('Daily camp'));
    await tester.pump();
    final first = List<int>.of(h.controller.previewTiers);
    await _qualifyingFinish(tester, h.controller);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(h.controller.dailyDay, 20000);
    expect(h.controller.previewTiers, first);

    await _qualifyingFinish(tester, h.controller);
    expect(find.textContaining('Already counted today'), findsOneWidget);
    expect(h.store.value.daily.total, 1, reason: 'one reward per day');

    await tester.tap(find.text('Free play'));
    await tester.pumpAndSettle();
    expect(h.controller.dailyDay, isNull);
  });

  testWidgets('a free play summary offers the daily until it is rewarded', (
    tester,
  ) async {
    final h = await _pump(tester);
    await _qualifyingFinish(tester, h.controller);
    expect(find.byKey(const ValueKey('summary-daily')), findsNothing);
    expect(find.text('Daily camp'), findsOneWidget);
    await tester.tap(find.text('Daily camp'));
    await tester.pumpAndSettle();
    expect(h.controller.dailyDay, 20000);
  });

  testWidgets('a new day brings the dot back and extends the streak', (
    tester,
  ) async {
    final h = await _pump(tester);
    await tester.tap(find.byTooltip('Daily camp'));
    await tester.pump();
    await _qualifyingFinish(tester, h.controller);
    await tester.tap(find.text('Free play'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('daily-badge')), findsNothing);

    h.clockDay[0] = 20001;
    await tester.pump();
    await tester.tap(find.byTooltip('Daily camp (streak 1)'));
    await tester.pump();
    expect(h.controller.dailyDay, 20001);
    await _qualifyingFinish(tester, h.controller);
    expect(find.textContaining('Daily streak 2'), findsOneWidget);
    expect(find.textContaining('+50 XP'), findsWidgets);
  });

  testWidgets('a short daily run does not count', (tester) async {
    final h = await _pump(tester);
    await tester.tap(find.byTooltip('Daily camp'));
    await tester.pump();
    await _finishRun(tester, h.controller);
    expect(find.textContaining('count today'), findsOneWidget);
    expect(h.store.value.daily.total, 0);
  });

  testWidgets('reloading resumes the saved daily run and its sequence', (
    tester,
  ) async {
    final saved = MergeCampController(dailyDay: 20000);
    saved.place(0);
    saved.place(5);
    final progress = const CampProgress.initial().withActiveRun({
      'version': 1,
      'controller': saved.toSnapshot(),
      'missions': MissionBoard().toSnapshot(),
      'guidedPractice': false,
    });
    final h = await _pump(tester, progress: progress);
    await tester.pump();
    expect(h.controller.dailyDay, 20000);
    expect(h.controller.placements, 2);
    expect(h.controller.previewTiers, saved.previewTiers);
    saved.place(9);
    h.controller.place(9);
    expect(h.controller.previewTiers, saved.previewTiers);
  });

  for (final size in const [
    Size(320, 640),
    Size(360, 640),
    Size(390, 844),
    Size(640, 480),
    Size(844, 390),
    Size(1280, 720),
    Size(1366, 768),
  ]) {
    testWidgets('daily summary fits $size', (tester) async {
      final h = await _pump(tester, size: size);
      await tester.tap(find.byTooltip('Daily camp'));
      await tester.pump();
      await _qualifyingFinish(tester, h.controller);
      expect(find.byKey(const ValueKey('summary-daily')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
