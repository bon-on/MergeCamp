import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_camp/src/game/how_to_play.dart';
import 'package:merge_camp/src/game/merge_camp_controller.dart';
import 'package:merge_camp/src/game/merge_camp_screen.dart';
import 'package:merge_camp/src/platform/game_platform.dart';

class _FakeStore extends HowToPlayStore {
  _FakeStore({this.seen = false});

  bool seen;
  int writes = 0;

  @override
  Future<bool> loadSeen() async => seen;

  @override
  Future<void> markSeen() async {
    seen = true;
    writes += 1;
  }
}

Future<MergeCampController> _pump(
  WidgetTester tester,
  HowToPlayStore store, {
  Size size = const Size(390, 844),
  GamePlatform platform = const NoopGamePlatform(),
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
  final controller = MergeCampController(random: Random(0));
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: MergeCampScreen(
        controller: controller,
        howToPlayStore: store,
        platform: platform,
      ),
    ),
  );
  await tester.pump();
  return controller;
}

final _nextBtn = find.widgetWithText(FilledButton, 'Next');
final _playBtn = find.widgetWithText(FilledButton, 'Play');
final _title = find.text('How to play');
final _cursor = find.byKey(const ValueKey('keyboard-cursor'));

int _filled(MergeCampController c) => c.board.where((t) => t != null).length;

void main() {
  testWidgets('first launch shows the overlay and blocks game input', (
    tester,
  ) async {
    final controller = await _pump(tester, _FakeStore());
    expect(_title, findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(_nextBtn, findsOneWidget);

    await tester.tapAt(const Offset(60, 400));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyX);
    await tester.pump();
    expect(_filled(controller), 0);
    expect(controller.placements, 0);
    expect(_cursor, findsNothing);
    expect(_title, findsOneWidget);
  });

  testWidgets('Next walks the steps; Play closes and stores the flag', (
    tester,
  ) async {
    final store = _FakeStore();
    await _pump(tester, store);
    for (var i = 0; i < 2; i++) {
      expect(_nextBtn, findsOneWidget);
      await tester.tap(_nextBtn);
      await tester.pump();
    }
    expect(_nextBtn, findsNothing);
    expect(_playBtn, findsOneWidget);
    await tester.tap(_playBtn);
    await tester.pump();
    expect(_title, findsNothing);
    expect(store.seen, isTrue);
  });

  testWidgets('Skip closes and stores the flag', (tester) async {
    final store = _FakeStore();
    await _pump(tester, store);
    await tester.tap(find.text('Skip'));
    await tester.pump();
    expect(_title, findsNothing);
    expect(store.seen, isTrue);
  });

  testWidgets('Escape skips; Enter/Space and arrows navigate', (tester) async {
    final store = _FakeStore();
    final controller = await _pump(tester, store);
    final text = find.byKey(const ValueKey('how-to-play-text'));
    final first = tester.widget<Text>(text).data;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    final second = tester.widget<Text>(text).data;
    expect(second, isNot(first));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(tester.widget<Text>(text).data, first);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(tester.widget<Text>(text).data, second);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(_playBtn, findsOneWidget);
    expect(controller.placements, 0);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(_title, findsNothing);
    expect(store.seen, isTrue);
  });

  testWidgets('does not appear when the flag is already set', (tester) async {
    await _pump(tester, _FakeStore(seen: true));
    expect(_title, findsNothing);
  });

  testWidgets('? reopens at step 1 without resetting the game', (tester) async {
    final controller = await _pump(tester, _FakeStore(seen: true));
    controller.place(0);
    await tester.pump();
    final placements = controller.placements;
    expect(placements, 1);

    await tester.tap(find.byTooltip('How to play'));
    await tester.pump();
    expect(_title, findsOneWidget);
    final step1 = tester.widget<Text>(
      find.byKey(const ValueKey('how-to-play-text')),
    );
    expect(step1.data, startsWith('Match 3'));
    expect(controller.placements, placements);
    expect(_filled(controller), 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(_title, findsNothing);
    // Game keys work again after closing.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(_cursor, findsOneWidget);
  });

  testWidgets('storage failures do not break play', (tester) async {
    await _pump(tester, const _ThrowingStore());
    expect(_title, findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pump();
    expect(_title, findsNothing);
  });

  testWidgets('gameplayStart fires only after the first-run tutorial closes', (
    tester,
  ) async {
    final platform = _RecordingPlatform();
    await _pump(tester, _FakeStore(), platform: platform);
    expect(platform.events, isEmpty);
    await tester.tap(find.text('Skip'));
    await tester.pump();
    expect(platform.events, ['start']);
  });

  testWidgets('? stops gameplay and closing restarts it without doubles', (
    tester,
  ) async {
    final platform = _RecordingPlatform();
    await _pump(tester, _FakeStore(seen: true), platform: platform);
    expect(platform.events, ['start']);

    await tester.tap(find.byTooltip('How to play'));
    await tester.pump();
    expect(platform.events, ['start', 'stop']);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(platform.events, ['start', 'stop']);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(platform.events, ['start', 'stop', 'start']);

    await tester.tap(find.byTooltip('How to play'));
    await tester.pump();
    await tester.tap(find.text('Skip'));
    await tester.pump();
    expect(platform.events, ['start', 'stop', 'start', 'stop', 'start']);
  });

  testWidgets('holding Enter on Play does not place a tile after close', (
    tester,
  ) async {
    final controller = await _pump(tester, _FakeStore());
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(_playBtn, findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(_title, findsNothing);
    for (var i = 0; i < 3; i++) {
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
      await tester.pump();
    }
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(seconds: 1));
    expect(_filled(controller), 0);
  });

  testWidgets('board taps are ignored while the seen flag is loading', (
    tester,
  ) async {
    final controller = await _pump(tester, _PendingStore());
    expect(_title, findsNothing);
    await tester.tap(find.byType(GridView), warnIfMissed: false);
    await tester.pump(const Duration(seconds: 1));
    expect(_filled(controller), 0);
  });

  testWidgets('F5 and shortcuts stay unhandled while the card has focus', (
    tester,
  ) async {
    await _pump(tester, _FakeStore());
    await tester.pump();
    expect(
      FocusManager.instance.primaryFocus?.toString(),
      contains('HowToPlayOverlay'),
    );
    expect(await tester.sendKeyEvent(LogicalKeyboardKey.f5), isFalse);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    expect(await tester.sendKeyEvent(LogicalKeyboardKey.keyR), isFalse);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(_title, findsOneWidget);
  });

  testWidgets('Tab stays inside the card and Escape still closes it', (
    tester,
  ) async {
    await _pump(tester, _FakeStore());
    await tester.pump();
    for (var i = 0; i < 4; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final focused = FocusManager.instance.primaryFocus!.context!;
      expect(
        focused.findAncestorWidgetOfExactType<HowToPlayOverlay>(),
        isNotNull,
        reason: "Tab $i left the card: ${FocusManager.instance.primaryFocus}",
      );
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(_title, findsNothing);
  });

  for (final size in const [Size(390, 844), Size(844, 390), Size(1280, 720)]) {
    testWidgets('overlay fits without overflow at $size', (tester) async {
      await _pump(tester, _FakeStore(), size: size);
      expect(_title, findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

class _RecordingPlatform extends GamePlatform {
  final List<String> events = <String>[];

  @override
  Future<void> initialize() async {}

  @override
  void gameplayStart() => events.add('start');

  @override
  void gameplayStop() => events.add('stop');

  @override
  Future<void> showRunBreakAd() async {}

  @override
  bool get isAudioMuted => false;

  @override
  bool get allowsResultRegistration => false;
}

class _ThrowingStore extends HowToPlayStore {
  const _ThrowingStore();

  @override
  Future<bool> loadSeen() async => false;

  @override
  Future<void> markSeen() async => throw StateError('disk full');
}

class _PendingStore extends HowToPlayStore {
  _PendingStore();

  final Completer<bool> _never = Completer<bool>();

  @override
  Future<bool> loadSeen() => _never.future;

  @override
  Future<void> markSeen() async {}
}
