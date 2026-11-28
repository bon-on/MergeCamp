import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import 'crazygames_prefs_store.dart';
import 'game_platform.dart';

/// GamePix HTML5 SDK v3 adapter (feature-gamepix-sdk). `tool/build_gamepix.sh`
/// loads the SDK with `lifecycle: 'manual'` before the Flutter bootstrap.
///
/// Any SDK failure downgrades to no-op behaviour so the game stays playable.
class GamePixPlatform extends GamePlatform {
  GamePixPlatform({
    @visibleForTesting Future<void> Function()? firstFrame,
    @visibleForTesting DateTime Function()? now,
    @visibleForTesting Duration adTimeout = const Duration(seconds: 120),
  }) : _firstFrame = firstFrame ?? _waitForFirstFrame,
       _now = now ?? DateTime.now,
       _adTimeout = adTimeout;

  /// Shortest gap between two interstitials, and between the game load and
  /// the first one (GamePix: no ads too often).
  static const Duration adCooldown = Duration(minutes: 2);
  static const Duration _loadedTimeout = Duration(seconds: 10);

  final Future<void> Function() _firstFrame;
  final DateTime Function() _now;
  final Duration _adTimeout;

  _Sdk? _sdk;
  Future<void> _ready = Future<void>.value();
  DateTime? _lastAdAt;
  bool _paused = false;
  bool _adRunning = false;
  void Function()? _muteListener;

  /// Completes after the next drawn frame: the first one once runApp ran.
  /// (`waitUntilFirstFrameRasterized` relies on frame timings, which the web
  /// engine reports only with later frames, so an idle first screen never
  /// completed it.)
  static Future<void> _waitForFirstFrame() {
    final drawn = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) => drawn.complete());
    return drawn.future;
  }

  @override
  Future<void> initialize() async {
    await _useSyncedStorage();
    final sdk = _findSdk();
    if (sdk == null) {
      debugPrint('GamePix SDK not found; running without it.');
      return;
    }
    try {
      sdk.events.on('pause', (() => _setPaused(true)).toJS);
      sdk.events.on('resume', (() => _setPaused(false)).toJS);
    } catch (error) {
      debugPrint('GamePix SDK events failed: $error');
      return;
    }
    _sdk = sdk;
    _lastAdAt = _now();
    // The Player hides its loading bar on loaded(): send it once Flutter has
    // drawn the first frame. Ads and gameplay signals wait for it.
    _ready = _firstFrame()
        .then((_) => sdk.lifecycle.loaded().toDart)
        .timeout(_loadedTimeout)
        .then<void>(
          (_) {},
          onError: (Object error) {
            debugPrint('GamePix loaded() failed: $error');
          },
        );
  }

  /// localStorage prefix of this game's save item. GamePix may serve several
  /// games from one origin, so the item is named per game.
  static const String storagePrefix = 'mergecamp.';

  /// GamePix synchronizes localStorage items read with `getItem` by name;
  /// shared_preferences_web lists keys instead, which misses synced data. Keep
  /// every preference in one named item (`mergecamp.prefs_v1`). The mirror is an
  /// in-memory copy seeded from the old `flutter.` keys, so progress saved
  /// before the SDK carries over and keys other games may share on the same
  /// origin are never cleared. No local stamp: the named item is the source.
  Future<void> _useSyncedStorage() async {
    if (SharedPreferencesStorePlatform.instance is CloudPrefsStore) return;
    try {
      final legacy = await SharedPreferencesStorePlatform.instance.getAll();
      SharedPreferencesStorePlatform.instance = await CloudPrefsStore.load(
        cloud: _LocalStorageData(storagePrefix),
        local: InMemorySharedPreferencesStore.withData(legacy),
        localStamp: _NoStamp(),
        owner: null,
      );
    } catch (error) {
      debugPrint('GamePix storage unavailable: $error');
    }
  }

  @override
  void gameplayStart() {
    final sdk = _sdk;
    if (sdk == null) return;
    _ready.then((_) {
      try {
        sdk.lifecycle.gameStart();
      } catch (error) {
        debugPrint('GamePix gameStart failed: $error');
      }
    });
  }

  @override
  void gameplayStop() {}

  @override
  Future<void> showRunBreakAd() async {
    final sdk = _sdk;
    if (sdk == null || _adRunning) return;
    final last = _lastAdAt;
    if (last != null && _now().difference(last) < adCooldown) return;
    await _runAd(() => sdk.ads.interstitial(), 'interstitial');
  }

  @override
  bool get supportsRewardedAds => _sdk != null;

  @override
  Future<bool> showRewardedAd() async {
    final sdk = _sdk;
    if (sdk == null || _adRunning) return false;
    return _runAd(() => sdk.ads.reward(), 'reward');
  }

  /// True only when the SDK reports success; errors and the timeout complete
  /// with false so callers always continue.
  Future<bool> _runAd(
    JSPromise<_AdResult?> Function() request,
    String kind,
  ) async {
    _adRunning = true;
    try {
      await _ready;
      final result = await request().toDart.timeout(_adTimeout);
      return result?.success ?? false;
    } catch (error) {
      debugPrint('GamePix $kind ad failed: $error');
      return false;
    } finally {
      _adRunning = false;
      _lastAdAt = _now();
      // A lost resume event must not keep the game silent.
      _setPaused(false);
    }
  }

  @override
  bool get isAudioMuted => _paused;

  @override
  void setAudioMuteListener(void Function()? listener) {
    _muteListener = listener;
  }

  @override
  bool get allowsResultRegistration => false;

  @override
  String? get shareLink => null;

  void _setPaused(bool paused) {
    if (paused == _paused) return;
    _paused = paused;
    try {
      _muteListener?.call();
    } catch (error) {
      debugPrint('Audio mute listener failed: $error');
    }
  }

  static _Sdk? _findSdk() {
    final sdk = globalContext.getProperty<JSObject?>('GamePix'.toJS);
    if (sdk == null ||
        !sdk.has('lifecycle') ||
        !sdk.has('events') ||
        !sdk.has('ads')) {
      return null;
    }
    return sdk as _Sdk;
  }
}

extension type _Sdk._(JSObject _) implements JSObject {
  external _Lifecycle get lifecycle;
  external _Events get events;
  external _Ads get ads;
}

extension type _Lifecycle._(JSObject _) implements JSObject {
  external JSPromise<JSAny?> loaded();
  external JSAny? gameStart();
}

extension type _Events._(JSObject _) implements JSObject {
  external JSAny? on(String eventName, JSFunction callback);
}

extension type _Ads._(JSObject _) implements JSObject {
  external JSPromise<_AdResult?> interstitial();
  external JSPromise<_AdResult?> reward();
}

extension type _AdResult._(JSObject _) implements JSObject {
  external bool? get success;
}

class _LocalStorageData implements CloudData {
  _LocalStorageData(this._prefix);

  final String _prefix;

  JSObject get _storage =>
      globalContext.getProperty<JSObject>('localStorage'.toJS);

  @override
  String? getItem(String key) => _storage
      .callMethod<JSString?>('getItem'.toJS, '$_prefix$key'.toJS)
      ?.toDart;

  @override
  void setItem(String key, String value) => _storage.callMethod<JSAny?>(
    'setItem'.toJS,
    '$_prefix$key'.toJS,
    value.toJS,
  );
}

class _NoStamp implements CloudData {
  @override
  String? getItem(String key) => null;

  @override
  void setItem(String key, String value) {}
}
