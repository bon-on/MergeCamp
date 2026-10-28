// Run with: flutter test --platform chrome test/web
@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_camp/src/game/web_sound_web.dart';
import 'package:merge_camp/src/platform/crazygames_platform.dart';

/// Installs a fake `window.CrazyGames.SDK` and records the calls it receives.
class _FakeSdk {
  _FakeSdk({this.environment = 'local', this.initResult, this.onRequestAd}) {
    final game = JSObject()
      ..setProperty(
        'gameplayStart'.toJS,
        (() => calls.add('gameplayStart')).toJS,
      )
      ..setProperty('gameplayStop'.toJS, (() => calls.add('gameplayStop')).toJS)
      ..setProperty('settings'.toJS, _settings(muteAudio: false))
      ..setProperty(
        'addSettingsChangeListener'.toJS,
        ((JSFunction listener) => settingsListener = listener).toJS,
      );
    final ad = JSObject()
      ..setProperty(
        'requestAd'.toJS,
        ((JSString type, JSObject callbacks) {
          calls.add('requestAd:${type.toDart}');
          onRequestAd?.call(callbacks);
        }).toJS,
      );
    final sdk = JSObject()
      ..setProperty('environment'.toJS, environment.toJS)
      ..setProperty('game'.toJS, game)
      ..setProperty('ad'.toJS, ad)
      ..setProperty(
        'init'.toJS,
        (() => (initResult ?? Future<void>.value()).toJS).toJS,
      );
    globalContext.setProperty(
      'CrazyGames'.toJS,
      JSObject()..setProperty('SDK'.toJS, sdk),
    );
  }

  final String environment;
  final Future<void>? initResult;
  final void Function(JSObject callbacks)? onRequestAd;
  final List<String> calls = <String>[];
  JSFunction? settingsListener;

  static JSObject _settings({required bool muteAudio}) =>
      JSObject()..setProperty('muteAudio'.toJS, muteAudio.toJS);

  void pushSettings({required bool muteAudio}) {
    settingsListener!.callAsFunction(null, _settings(muteAudio: muteAudio));
  }
}

void _removeSdk() => globalContext.delete('CrazyGames'.toJS);

void main() {
  tearDown(_removeSdk);

  test('missing SDK falls back to no-op', () async {
    _removeSdk();
    final platform = CrazyGamesPlatform();
    await platform.initialize();

    platform.gameplayStart();
    await platform.showRunBreakAd();
    expect(platform.isAudioMuted, isFalse);
  });

  test('disabled environment never calls the SDK', () async {
    final sdk = _FakeSdk(environment: 'disabled');
    final platform = CrazyGamesPlatform();
    await platform.initialize();

    platform.gameplayStart();
    await platform.showRunBreakAd();
    expect(sdk.calls, isEmpty);
  });

  test('rejected init falls back to no-op', () async {
    final sdk = _FakeSdk(initResult: Future<void>.error('init failed'));
    final platform = CrazyGamesPlatform();
    await platform.initialize();

    platform.gameplayStart();
    expect(sdk.calls, isEmpty);
  });

  test('hung init times out and falls back to no-op', () async {
    final sdk = _FakeSdk(initResult: Completer<void>().future);
    final platform = CrazyGamesPlatform();
    await platform.initialize();

    platform.gameplayStart();
    expect(sdk.calls, isEmpty);
  });

  test('CrazyGames builds never offer leaderboard registration', () {
    expect(CrazyGamesPlatform().allowsResultRegistration, isFalse);
  });

  test('gameplay events reach the SDK', () async {
    final sdk = _FakeSdk();
    final platform = CrazyGamesPlatform();
    await platform.initialize();

    platform.gameplayStart();
    platform.gameplayStop();
    expect(sdk.calls, <String>['gameplayStart', 'gameplayStop']);
  });

  test('midgame ad mutes audio until it finishes', () async {
    late JSObject callbacks;
    final sdk = _FakeSdk(onRequestAd: (value) => callbacks = value);
    final platform = CrazyGamesPlatform();
    await platform.initialize();

    var done = false;
    final ad = platform.showRunBreakAd().then((_) => done = true);
    expect(sdk.calls, <String>['requestAd:midgame']);

    callbacks.callMethod('adStarted'.toJS);
    expect(platform.isAudioMuted, isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(done, isFalse);

    callbacks.callMethod('adFinished'.toJS);
    await ad;
    expect(platform.isAudioMuted, isFalse);
  });

  test('ad error completes the break', () async {
    _FakeSdk(
      onRequestAd: (callbacks) => callbacks.callMethod(
        'adError'.toJS,
        JSObject()..setProperty('code'.toJS, 'unfilled'.toJS),
      ),
    );
    final platform = CrazyGamesPlatform();
    await platform.initialize();

    await platform.showRunBreakAd();
    expect(platform.isAudioMuted, isFalse);
  });

  test('muteAudio setting mutes game audio', () async {
    final sdk = _FakeSdk();
    final platform = CrazyGamesPlatform();
    await platform.initialize();

    sdk.pushSettings(muteAudio: true);
    expect(platform.isAudioMuted, isTrue);
    sdk.pushSettings(muteAudio: false);
    expect(platform.isAudioMuted, isFalse);
  });

  test('web sound constructs a browser Audio element per asset', () {
    final originalAudio = globalContext.getProperty<JSAny?>('Audio'.toJS);
    addTearDown(() => globalContext.setProperty('Audio'.toJS, originalAudio));
    globalContext.callMethod(
      'eval'.toJS,
      '''
      globalThis.__audioSources = [];
      globalThis.__audioPlays = 0;
      globalThis.Audio = class {
        constructor(src) { globalThis.__audioSources.push(src); }
        play() { globalThis.__audioPlays++; return Promise.resolve(); }
      };
      '''
          .toJS,
    );

    final sound = WebSound();
    sound.play('assets/audio/place.wav');
    sound.play('assets/audio/place.wav');

    final sources = globalContext
        .getProperty<JSArray<JSString>>('__audioSources'.toJS)
        .toDart
        .map((source) => source.toDart)
        .toList();
    expect(sources, hasLength(1));
    expect(sources.single, endsWith('assets/audio/place.wav'));
    expect(
      globalContext.getProperty<JSNumber>('__audioPlays'.toJS).toDartInt,
      2,
    );
  });
}
