import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_camp/src/game/feedback_fx.dart';
import 'package:merge_camp/src/game/web_sound_stub.dart';

class _Call {
  _Call(this.method, this.arguments);

  final String method;
  final Object? arguments;

  @override
  String toString() => '$method($arguments)';
}

List<_Call> _recordChannel() {
  final calls = <_Call>[];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(const MethodChannel('merge_camp/audio'), (
    call,
  ) async {
    calls.add(_Call(call.method, call.arguments));
    return null;
  });
  // Haptics go through the platform channel; answer so awaits complete.
  messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    return null;
  });
  addTearDown(() {
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    messenger.setMockMethodCallHandler(
      const MethodChannel('merge_camp/audio'),
      null,
    );
  });
  return calls;
}

List<String> _methods(List<_Call> calls) =>
    calls.map((c) => c.method).toList();

/// Web double: records calls; loop/resume results are scriptable.
class _FakeWebSound extends WebSound {
  final List<String> log = <String>[];
  bool allowLoop = true;

  @override
  void play(String assetKey, {double volume = 1}) {
    log.add('play $assetKey $volume');
  }

  @override
  Future<bool> loop(String assetKey, {double volume = 1}) async {
    log.add('loop $assetKey $volume');
    return allowLoop;
  }

  @override
  void stopLoop() => log.add('stopLoop');

  @override
  void pauseLoop() => log.add('pauseLoop');

  @override
  Future<bool> resumeLoop() async {
    log.add('resumeLoop');
    return allowLoop;
  }
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('effects', () {
    test('are silent when muted and play otherwise', () async {
      final calls = _recordChannel();
      var muted = true;
      final fx = FeedbackFx(isMuted: () => muted);
      await fx.tap();
      await fx.merge();
      await fx.warning();
      await fx.chain(3);
      await fx.discover();
      await fx.mission();
      await fx.levelUp();
      expect(calls, isEmpty);
      muted = false;
      await fx.tap();
      await fx.merge();
      await fx.warning();
      expect(_methods(calls), ['playTap', 'playMerge', 'playWarning']);
    });

    test('new effects use the generic play method at full volume', () async {
      final calls = _recordChannel();
      final fx = FeedbackFx();
      await fx.chain(2);
      await fx.discover();
      await fx.mission();
      await fx.levelUp();
      expect(_methods(calls), ['play', 'play', 'play', 'play']);
      expect(
        calls.map((c) => (c.arguments as Map)['asset']),
        [
          'assets/audio/chain.wav',
          'assets/audio/discover.wav',
          'assets/audio/mission.wav',
          'assets/audio/level_up.wav',
        ],
      );
      for (final c in calls) {
        expect((c.arguments as Map)['volume'], 1.0);
      }
    });

    test('chain ignores lengths below two', () async {
      final calls = _recordChannel();
      final fx = FeedbackFx();
      await fx.chain(1);
      await fx.chain(0);
      expect(calls, isEmpty);
    });

    test('a missing native channel never throws', () async {
      final fx = FeedbackFx();
      await fx.tap();
      await fx.chain(2);
      await fx.levelUp();
      fx.startMusic();
      fx.stopMusic();
      fx.setAppVisible(false);
      fx.refreshMute();
      fx.onUserInput();
      await fx.dispose();
    });

    test('a throwing mute callback counts as not muted', () async {
      final calls = _recordChannel();
      final fx = FeedbackFx(isMuted: () => throw StateError('boom'));
      await fx.tap();
      expect(_methods(calls), ['playTap']);
    });
  });

  group('music on native', () {
    test('startMusic and stopMusic send startLoop and stopLoop', () async {
      final calls = _recordChannel();
      final fx = FeedbackFx();
      fx.startMusic();
      await _settle();
      expect(_methods(calls), ['startLoop']);
      expect(calls.single.arguments, {
        'asset': 'assets/audio/music_loop.wav',
        'volume': 0.45,
      });
      expect(fx.isMusicPlaying, isTrue);
      fx.startMusic(); // already playing: no second start
      await _settle();
      expect(calls, hasLength(1));
      fx.stopMusic();
      await _settle();
      expect(_methods(calls), ['startLoop', 'stopLoop']);
      expect(fx.isMusicPlaying, isFalse);
      fx.stopMusic(); // already stopped: nothing more
      await _settle();
      expect(calls, hasLength(2));
    });

    test('muting stops music and unmuting resumes it', () async {
      final calls = _recordChannel();
      var muted = false;
      final fx = FeedbackFx(isMuted: () => muted);
      fx.startMusic();
      muted = true;
      fx.refreshMute();
      muted = false;
      fx.refreshMute();
      await _settle();
      expect(_methods(calls), ['startLoop', 'stopLoop', 'startLoop']);
    });

    test('startMusic while muted waits for unmute', () async {
      final calls = _recordChannel();
      var muted = true;
      final fx = FeedbackFx(isMuted: () => muted);
      fx.startMusic();
      await _settle();
      expect(calls, isEmpty);
      expect(fx.isMusicWanted, isTrue);
      muted = false;
      fx.refreshMute();
      await _settle();
      expect(_methods(calls), ['startLoop']);
    });

    test('hiding the app pauses music and showing resumes it', () async {
      final calls = _recordChannel();
      final fx = FeedbackFx();
      fx.startMusic();
      fx.setAppVisible(false);
      fx.setAppVisible(false); // repeated: ignored
      fx.setAppVisible(true);
      await _settle();
      expect(_methods(calls), ['startLoop', 'stopLoop', 'startLoop']);
    });

    test('hidden app does not resume music nobody wanted', () async {
      final calls = _recordChannel();
      final fx = FeedbackFx();
      fx.setAppVisible(false);
      fx.setAppVisible(true);
      await _settle();
      expect(calls, isEmpty);
      fx.startMusic();
      fx.stopMusic();
      fx.setAppVisible(false);
      fx.setAppVisible(true);
      await _settle();
      expect(_methods(calls), ['startLoop', 'stopLoop']);
    });

    test('user input is not required on native', () async {
      final calls = _recordChannel();
      final fx = FeedbackFx();
      fx.startMusic();
      await _settle();
      expect(_methods(calls), ['startLoop']);
    });

    test('dispose stops music and disposes the native audio', () async {
      final calls = _recordChannel();
      final fx = FeedbackFx();
      fx.startMusic();
      await fx.dispose();
      expect(_methods(calls).last, 'disposeAudio');
      expect(fx.isMusicWanted, isFalse);
    });
  });

  group('music on web', () {
    test('waits for the first user input', () async {
      final calls = _recordChannel();
      final web = _FakeWebSound();
      final fx = FeedbackFx(webSound: web, isWeb: true);
      fx.startMusic();
      await _settle();
      expect(web.log, isEmpty);
      fx.onUserInput();
      await _settle();
      expect(web.log, ['loop assets/audio/music_loop.wav 0.45']);
      expect(fx.isMusicPlaying, isTrue);
      expect(calls, isEmpty); // never touches the native channel
    });

    test('input before startMusic starts it immediately', () async {
      final web = _FakeWebSound();
      final fx = FeedbackFx(webSound: web, isWeb: true);
      fx.onUserInput();
      fx.startMusic();
      await _settle();
      expect(web.log, ['loop assets/audio/music_loop.wav 0.45']);
    });

    test('hidden tab pauses, visible tab resumes', () async {
      final web = _FakeWebSound();
      final fx = FeedbackFx(webSound: web, isWeb: true);
      fx.onUserInput();
      fx.startMusic();
      await _settle();
      web.log.clear();
      fx.setAppVisible(false);
      expect(web.log, ['pauseLoop']);
      fx.setAppVisible(true);
      await _settle();
      expect(web.log, ['pauseLoop', 'resumeLoop']);
      expect(fx.isMusicPlaying, isTrue);
    });

    test('mute pauses, unmute resumes, stopMusic stops', () async {
      final web = _FakeWebSound();
      var muted = false;
      final fx = FeedbackFx(
        webSound: web,
        isWeb: true,
        isMuted: () => muted,
      );
      fx.onUserInput();
      fx.startMusic();
      await _settle();
      web.log.clear();
      muted = true;
      fx.refreshMute();
      muted = false;
      fx.refreshMute();
      await _settle();
      expect(web.log, ['pauseLoop', 'resumeLoop']);
      web.log.clear();
      fx.stopMusic();
      expect(web.log, ['stopLoop']);
      expect(fx.isMusicPlaying, isFalse);
    });

    test('a refused loop is retried on the next user input', () async {
      final web = _FakeWebSound()..allowLoop = false;
      final fx = FeedbackFx(webSound: web, isWeb: true);
      fx.startMusic();
      fx.onUserInput();
      await _settle();
      expect(fx.isMusicPlaying, isFalse);
      web.allowLoop = true;
      fx.onUserInput();
      await _settle();
      expect(fx.isMusicPlaying, isTrue);
      expect(web.log.where((e) => e.startsWith('loop')), hasLength(2));
    });

    test('muting while the browser is starting playback pauses it', () async {
      final web = _FakeWebSound();
      var muted = false;
      final fx = FeedbackFx(
        webSound: web,
        isWeb: true,
        isMuted: () => muted,
      );
      fx.onUserInput();
      fx.startMusic(); // loop() future pending
      muted = true;
      fx.refreshMute();
      await _settle();
      expect(web.log.last, 'pauseLoop');
      expect(fx.isMusicPlaying, isFalse);
    });

    test('effects pass a volume on web and respect mute', () async {
      final web = _FakeWebSound();
      var muted = true;
      final fx = FeedbackFx(
        webSound: web,
        isWeb: true,
        isMuted: () => muted,
      );
      await fx.chain(2);
      expect(web.log, isEmpty);
      muted = false;
      await fx.chain(2);
      await fx.tap();
      expect(web.log, [
        'play assets/audio/chain.wav 1.0',
        'play assets/audio/place.wav 1.0',
      ]);
    });
  });

  group('assets', () {
    test('every audio asset referenced by FeedbackFx exists and is bundled', () {
      final source = File('lib/src/game/feedback_fx.dart').readAsStringSync();
      final paths = RegExp(
        r"'(assets/audio/[a-z_]+\.wav)'",
      ).allMatches(source).map((m) => m.group(1)!).toSet();
      expect(paths, containsAll(<String>[
        'assets/audio/place.wav',
        'assets/audio/merge.wav',
        'assets/audio/warning.wav',
        'assets/audio/chain.wav',
        'assets/audio/discover.wav',
        'assets/audio/mission.wav',
        'assets/audio/level_up.wav',
        'assets/audio/music_loop.wav',
      ]));
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('- assets/audio/'));
      for (final path in paths) {
        expect(File(path).existsSync(), isTrue, reason: path);
      }
    });

    test('music loop is mono 16-bit 16000 Hz, 24-32 s and at most 1 MB', () {
      final bytes = File('assets/audio/music_loop.wav').readAsBytesSync();
      expect(bytes.length, lessThanOrEqualTo(1024 * 1024));
      final data = ByteData.sublistView(bytes);
      expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
      expect(data.getUint16(22, Endian.little), 1); // mono
      final rate = data.getUint32(24, Endian.little);
      expect(rate, 16000);
      expect(data.getUint16(34, Endian.little), 16);
      final seconds = (bytes.length - 44) / 2 / rate;
      expect(seconds, inInclusiveRange(24, 32));
    });

    test('chain sound stays under 40 KB', () {
      expect(File('assets/audio/chain.wav').lengthSync(), lessThan(40000));
    });
  });
}
