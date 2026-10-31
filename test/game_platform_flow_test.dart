import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_camp/src/game/how_to_play.dart';
import 'package:merge_camp/src/game/merge_camp_controller.dart';
import 'package:merge_camp/src/game/merge_camp_screen.dart';
import 'package:merge_camp/src/platform/game_platform.dart';

class _SeenStore extends HowToPlayStore {
  const _SeenStore();
  @override
  Future<bool> loadSeen() async => true;
  @override
  Future<void> markSeen() async {}
}

class _FakePlatform extends GamePlatform {
  _FakePlatform({this.allowsResultRegistration = false});

  @override
  final bool allowsResultRegistration;

  final List<String> events = <String>[];
  Completer<void>? pendingAd;

  @override
  Future<void> initialize() async {}

  @override
  void gameplayStart() => events.add('start');

  @override
  void gameplayStop() => events.add('stop');

  @override
  Future<void> showRunBreakAd() {
    events.add('ad');
    pendingAd = Completer<void>();
    return pendingAd!.future;
  }

  @override
  bool get isAudioMuted => false;
}

/// Checkerboard of tiers 1 and 2 with the last cell empty, so placing a
/// tier-3 tile fills the board without merging and ends the run.
void _loadOneMoveFromGameOver(MergeCampController controller) {
  final board = List<int?>.generate(
    MergeCampController.cellCount,
    (index) => (index ~/ 4 + index % 4).isEven ? 1 : 2,
  );
  board[15] = null;
  controller.debugLoadBoard(board, nextTier: 3, trailAxes: 0);
}

Future<void> _pumpScreen(
  WidgetTester tester,
  _FakePlatform platform,
  MergeCampController controller,
) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: MergeCampScreen(
        platform: platform,
        controller: controller,
        howToPlayStore: const _SeenStore(),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('gameplay starts after the first frame', (tester) async {
    final platform = _FakePlatform();
    final controller = MergeCampController();
    addTearDown(controller.dispose);

    await _pumpScreen(tester, platform, controller);

    expect(platform.events, <String>['start']);
  });

  testWidgets('game over stops gameplay and restart waits for the break ad', (
    tester,
  ) async {
    final platform = _FakePlatform();
    final controller = MergeCampController();
    addTearDown(controller.dispose);
    await _pumpScreen(tester, platform, controller);

    _loadOneMoveFromGameOver(controller);
    controller.place(15);
    await tester.pump();
    expect(controller.isGameOver, isTrue);
    expect(platform.events, <String>['start', 'stop']);

    await tester.tap(find.text('Restart Run'));
    await tester.pump();
    expect(platform.events, <String>['start', 'stop', 'ad']);
    expect(controller.isGameOver, isTrue, reason: 'run waits for the ad');

    platform.pendingAd!.complete();
    await tester.pump();
    expect(controller.isGameOver, isFalse);
    expect(platform.events, <String>['start', 'stop', 'ad', 'start']);
  });

  testWidgets('result registration prompt follows the platform', (
    tester,
  ) async {
    for (final allowed in <bool>[true, false]) {
      final platform = _FakePlatform(allowsResultRegistration: allowed);
      final controller = MergeCampController();
      addTearDown(controller.dispose);
      await _pumpScreen(tester, platform, controller);

      _loadOneMoveFromGameOver(controller);
      controller.place(15);
      await tester.pumpAndSettle();

      expect(
        find.text('기록을 등록할까요?'),
        allowed ? findsOneWidget : findsNothing,
        reason: 'allowsResultRegistration: $allowed',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('restarting mid-run does not request an ad', (tester) async {
    final platform = _FakePlatform();
    final controller = MergeCampController();
    addTearDown(controller.dispose);
    await _pumpScreen(tester, platform, controller);

    controller.place(0);
    await tester.tap(find.byTooltip('Restart run'));
    await tester.pump();

    expect(platform.events, <String>['start']);
    expect(controller.placements, 0);
  });
}
