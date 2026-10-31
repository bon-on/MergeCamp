import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_camp/src/audio/sound_mute_store.dart';
import 'package:merge_camp/src/game/feedback_fx.dart';
import 'package:merge_camp/src/game/how_to_play.dart';
import 'package:merge_camp/src/game/merge_camp_controller.dart';
import 'package:merge_camp/src/game/merge_camp_screen.dart';
import 'package:merge_camp/src/platform/game_platform.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SeenStore extends HowToPlayStore {
  @override
  Future<bool> loadSeen() async => true;
}

class _FakeMuteStore extends SoundMuteStore {
  _FakeMuteStore({this.muted = false});

  bool muted;
  int writes = 0;

  @override
  Future<bool> loadMuted() async => muted;

  @override
  Future<void> saveMuted(bool value) async {
    muted = value;
    writes += 1;
  }
}

List<String> _recordChannel(WidgetTester? tester) {
  final calls = <String>[];
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(const MethodChannel('merge_camp/audio'), (
        call,
      ) async {
        calls.add(call.method);
        return null;
      });
  // Haptics go through the platform channel; answer so awaits complete.
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
  addTearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null),
  );
  addTearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('merge_camp/audio'),
          null,
        ),
  );
  return calls;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('FeedbackFx is silent when muted and plays otherwise', () async {
    final calls = _recordChannel(null);
    var muted = true;
    final fx = FeedbackFx(isMuted: () => muted);
    await fx.tap();
    await fx.merge();
    await fx.warning();
    expect(calls, isEmpty);
    muted = false;
    await fx.tap();
    expect(calls, ['playTap']);
  });

  test('FeedbackFx swallows a missing native channel', () async {
    await FeedbackFx().tap();
  });

  test('mute choice persists under sound_muted_v1', () async {
    SharedPreferences.setMockInitialValues({});
    const store = SoundMuteStore();
    expect(await store.loadMuted(), isFalse);
    await store.saveMuted(true);
    expect(await store.loadMuted(), isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('sound_muted_v1'), isTrue);
  });

  test('every audio asset used by FeedbackFx exists on disk', () {
    final source = File('lib/src/game/feedback_fx.dart').readAsStringSync();
    final paths = RegExp(
      r"'(assets/audio/[a-z_]+\.wav)'",
    ).allMatches(source).map((m) => m.group(1)!).toSet();
    expect(paths, isNotEmpty);
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('- assets/audio/'));
    for (final path in paths) {
      expect(File(path).existsSync(), isTrue, reason: path);
    }
  });

  testWidgets('sound toggle flips icon, persists, and mutes playback', (
    tester,
  ) async {
    final calls = _recordChannel(tester);
    final store = _FakeMuteStore();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = MergeCampController(random: Random(0));
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: MergeCampScreen(
          controller: controller,
          howToPlayStore: _SeenStore(),
          soundMuteStore: store,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
    expect(find.byTooltip('Sound on'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.volume_up_rounded));
    await tester.pump();
    expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
    expect(find.byTooltip('Sound off'), findsOneWidget);
    expect(store.muted, isTrue);
    expect(store.writes, 1);

    calls.clear();
    await tester.tapAt(const Offset(60, 400));
    await tester.pump();
    // The tap really placed a tile, just silently.
    expect(controller.placements, 1);
    expect(calls, isEmpty);

    await tester.tap(find.byIcon(Icons.volume_off_rounded));
    await tester.pump();
    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
    expect(store.muted, isFalse);

    await tester.tapAt(const Offset(60, 400));
    await tester.pump(const Duration(milliseconds: 50));
    expect(calls, isNotEmpty);
  });

  testWidgets('stored mute is restored on launch', (tester) async {
    _recordChannel(tester);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = MergeCampController(random: Random(0));
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: MergeCampScreen(
          controller: controller,
          howToPlayStore: _SeenStore(),
          soundMuteStore: _FakeMuteStore(muted: true),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
  });

  testWidgets('platform mute silences sound even when the user is unmuted', (
    tester,
  ) async {
    final calls = _recordChannel(tester);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = MergeCampController(random: Random(0));
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: MergeCampScreen(
          controller: controller,
          howToPlayStore: _SeenStore(),
          soundMuteStore: _FakeMuteStore(),
          platform: const _MutedPlatform(),
        ),
      ),
    );
    await tester.pump();
    await tester.tapAt(const Offset(60, 400));
    await tester.pump(const Duration(milliseconds: 50));
    expect(controller.placements, 1);
    expect(calls, isEmpty);
  });

  testWidgets('toggle returns keyboard focus to the board', (tester) async {
    _recordChannel(tester);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = MergeCampController(random: Random(0));
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: MergeCampScreen(
          controller: controller,
          howToPlayStore: _SeenStore(),
          soundMuteStore: _FakeMuteStore(),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byIcon(Icons.volume_up_rounded));
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'MergeCampBoard');
  });
}

class _MutedPlatform extends NoopGamePlatform {
  const _MutedPlatform();

  @override
  bool get isAudioMuted => true;
}
