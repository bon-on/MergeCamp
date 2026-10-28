import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';

import 'game_platform.dart';

/// CrazyGames HTML5 SDK v3 adapter. The SDK script is injected into the
/// bundle by `tool/build_crazygames.sh`.
///
/// Any SDK failure downgrades to no-op behaviour so the game stays playable.
class CrazyGamesPlatform extends GamePlatform {
  CrazyGamesPlatform();

  static const Duration _initTimeout = Duration(seconds: 5);
  static const Duration _adTimeout = Duration(seconds: 120);

  _Sdk? _sdk;
  bool _adPlaying = false;
  bool _settingsMuted = false;

  @override
  Future<void> initialize() async {
    final sdk = _findSdk();
    if (sdk == null) {
      debugPrint('CrazyGames SDK not found; running without it.');
      return;
    }
    try {
      // A hung init (blocked SDK requests) must not keep the game from starting.
      await sdk.init().toDart.timeout(_initTimeout);
      final environment = sdk.environment;
      if (environment != 'crazygames' && environment != 'local') {
        debugPrint('CrazyGames SDK environment "$environment"; disabled.');
        return;
      }
      _sdk = sdk;
      _applySettings(sdk.game.settings);
      sdk.game.addSettingsChangeListener(
        ((_Settings settings) => _applySettings(settings)).toJS,
      );
    } catch (error) {
      debugPrint('CrazyGames SDK init failed: $error');
      _sdk = null;
    }
  }

  @override
  void gameplayStart() => _call((sdk) => sdk.game.gameplayStart());

  @override
  void gameplayStop() => _call((sdk) => sdk.game.gameplayStop());

  @override
  Future<void> showRunBreakAd() {
    final sdk = _sdk;
    if (sdk == null) {
      return Future<void>.value();
    }

    final completer = Completer<void>();
    void finish() {
      _adPlaying = false;
      if (!completer.isCompleted) {
        completer.complete();
      }
    }

    try {
      sdk.ad.requestAd(
        'midgame',
        _AdCallbacks(
          adStarted: (() => _adPlaying = true).toJS,
          adFinished: finish.toJS,
          adError: ((JSAny? error) {
            debugPrint('CrazyGames midgame ad error: ${error?.dartify()}');
            finish();
          }).toJS,
        ),
      );
    } catch (error) {
      debugPrint('CrazyGames requestAd failed: $error');
      finish();
    }

    // Safety net if the SDK never calls back: resume play rather than lock the
    // board. A late adStarted would set _adPlaying again until adFinished.
    return completer.future.timeout(_adTimeout, onTimeout: finish);
  }

  @override
  bool get isAudioMuted => _adPlaying || _settingsMuted;

  @override
  bool get allowsResultRegistration => false;

  void _applySettings(_Settings? settings) {
    _settingsMuted = settings?.muteAudio ?? false;
  }

  void _call(void Function(_Sdk sdk) action) {
    final sdk = _sdk;
    if (sdk == null) {
      return;
    }
    try {
      action(sdk);
    } catch (error) {
      debugPrint('CrazyGames SDK call failed: $error');
    }
  }

  static _Sdk? _findSdk() {
    final crazyGames = globalContext.getProperty<JSObject?>('CrazyGames'.toJS);
    return crazyGames?.getProperty<_Sdk?>('SDK'.toJS);
  }
}

extension type _Sdk._(JSObject _) implements JSObject {
  external JSPromise<JSAny?> init();
  external String get environment;
  external _GameModule get game;
  external _AdModule get ad;
}

extension type _GameModule._(JSObject _) implements JSObject {
  external void gameplayStart();
  external void gameplayStop();
  external _Settings? get settings;
  external void addSettingsChangeListener(JSFunction listener);
}

extension type _Settings._(JSObject _) implements JSObject {
  external bool? get muteAudio;
}

extension type _AdModule._(JSObject _) implements JSObject {
  external void requestAd(String adType, _AdCallbacks callbacks);
}

extension type _AdCallbacks._(JSObject _) implements JSObject {
  external factory _AdCallbacks({
    JSFunction adStarted,
    JSFunction adFinished,
    JSFunction adError,
  });
}
