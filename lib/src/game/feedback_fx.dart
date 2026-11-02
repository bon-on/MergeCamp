import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'web_sound_stub.dart' if (dart.library.js_interop) 'web_sound_web.dart';

/// Sound effects, haptics and the background music loop.
///
/// Nothing here throws or blocks board input. Effects are no-ops while
/// [isMuted] reports true. Music has a wanted state ([startMusic] /
/// [stopMusic]) that is separate from whether it is actually playing: mute,
/// a hidden app or tab, and (on web) a missing first user input all hold the
/// music back until they clear.
class FeedbackFx {
  FeedbackFx({
    bool Function()? isMuted,
    WebSound? webSound,
    bool? isWeb,
    MethodChannel? channel,
  }) : _isMuted = isMuted ?? _never,
       _webSound = webSound ?? WebSound(),
       _isWeb = isWeb ?? kIsWeb,
       _channel = channel ?? _defaultChannel;

  static const MethodChannel _defaultChannel = MethodChannel(
    'merge_camp/audio',
  );

  static const String musicAsset = 'assets/audio/music_loop.wav';
  static const double musicVolume = 0.45;
  static const double effectVolume = 1.0;

  final bool Function() _isMuted;
  final WebSound _webSound;
  final bool _isWeb;
  final MethodChannel _channel;

  // Music state. _musicWanted is the request; _musicPlaying is what runs.
  bool _musicWanted = false;
  bool _musicPlaying = false;
  bool _musicStarting = false;
  // Web only: the loop element exists (paused or playing).
  bool _webLoopStarted = false;
  bool _appVisible = true;
  // Browsers only allow audio after a user gesture.
  bool _userInteracted = false;

  static bool _never() => false;

  bool get _muted {
    try {
      return _isMuted();
    } catch (_) {
      return false;
    }
  }

  /// True while the music loop is (believed to be) audible.
  bool get isMusicPlaying => _musicPlaying;

  /// True after [startMusic] until [stopMusic], even while held back.
  bool get isMusicWanted => _musicWanted;

  Future<void> initialize() async {}

  Future<void> tap() async {
    await _play('playTap', 'assets/audio/place.wav');
    await _haptic(HapticFeedback.selectionClick);
  }

  Future<void> merge() async {
    await _play('playMerge', 'assets/audio/merge.wav');
    await _haptic(HapticFeedback.mediumImpact);
  }

  Future<void> warning() async {
    await _play('playWarning', 'assets/audio/warning.wav');
    await _haptic(HapticFeedback.heavyImpact);
  }

  /// A chain merge of [chainLength] steps (2 or more).
  Future<void> chain(int chainLength) async {
    if (chainLength < 2) {
      return;
    }
    await _playAsset('assets/audio/chain.wav');
    await _haptic(HapticFeedback.mediumImpact);
  }

  /// A camp tier seen for the first time.
  Future<void> discover() async {
    await _playAsset('assets/audio/discover.wav');
    await _haptic(HapticFeedback.lightImpact);
  }

  /// A mission was completed.
  Future<void> mission() async {
    await _playAsset('assets/audio/mission.wav');
    await _haptic(HapticFeedback.lightImpact);
  }

  /// The camp level went up.
  Future<void> levelUp() async {
    await _playAsset('assets/audio/level_up.wav');
    await _haptic(HapticFeedback.mediumImpact);
  }

  /// Requests background music. It plays once nothing holds it back.
  void startMusic() {
    _musicWanted = true;
    _applyMusic();
  }

  /// Stops the music and forgets the request.
  void stopMusic() {
    _musicWanted = false;
    _applyMusic();
  }

  /// Call when the app or browser tab is hidden or shown again.
  void setAppVisible(bool visible) {
    if (_appVisible == visible) {
      return;
    }
    _appVisible = visible;
    _applyMusic();
  }

  /// Call on pointer or key input. Browsers only allow music after the first
  /// one; a request made earlier starts now.
  void onUserInput() {
    if (_userInteracted) {
      if (_isWeb && _musicWanted && !_musicPlaying) {
        // Retry a loop the browser refused earlier.
        _applyMusic();
      }
      return;
    }
    _userInteracted = true;
    _applyMusic();
  }

  /// Call after the mute state may have changed.
  void refreshMute() => _applyMusic();

  Future<void> dispose() async {
    _musicWanted = false;
    _musicPlaying = false;
    _musicStarting = false;
    _webLoopStarted = false;
    if (_isWeb) {
      _webSound.stopLoop();
    }
    await _invoke('disposeAudio');
  }

  bool get _musicAllowed =>
      _musicWanted &&
      !_muted &&
      _appVisible &&
      (!_isWeb || _userInteracted);

  void _applyMusic() {
    try {
      if (!_musicAllowed) {
        _holdMusicBack();
        return;
      }
      if (_musicPlaying || _musicStarting) {
        return;
      }
      if (_isWeb) {
        _startWebMusic();
      } else {
        _musicPlaying = true;
        _invoke('startLoop', {'asset': musicAsset, 'volume': musicVolume});
      }
    } catch (_) {
      // Music is optional and must never break the game.
    }
  }

  void _holdMusicBack() {
    if (_isWeb) {
      if (!_musicWanted) {
        if (_webLoopStarted) {
          _webSound.stopLoop();
          _webLoopStarted = false;
        }
      } else if (_musicPlaying) {
        _webSound.pauseLoop();
      }
      _musicPlaying = false;
      return;
    }
    if (_musicPlaying) {
      _musicPlaying = false;
      _invoke('stopLoop');
    }
  }

  void _startWebMusic() {
    _musicStarting = true;
    final Future<bool> started = _webLoopStarted
        ? _webSound.resumeLoop()
        : _webSound.loop(musicAsset, volume: musicVolume);
    started
        .then<bool>((ok) => ok, onError: (Object _) => false)
        .then((ok) {
          _musicStarting = false;
          if (!ok) {
            return;
          }
          _webLoopStarted = true;
          _musicPlaying = true;
          // State may have changed while the browser was starting playback.
          _applyMusic();
        });
  }

  Future<void> _play(String method, String assetKey) async {
    if (_muted) {
      return;
    }
    if (_isWeb) {
      _webSound.play(assetKey);
      return;
    }
    await _invoke(method);
  }

  /// Plays an asset through the generic native `play` method.
  Future<void> _playAsset(String assetKey) async {
    if (_muted) {
      return;
    }
    if (_isWeb) {
      _webSound.play(assetKey, volume: effectVolume);
      return;
    }
    await _invoke('play', {'asset': assetKey, 'volume': effectVolume});
  }

  Future<void> _haptic(Future<void> Function() feedback) async {
    try {
      await feedback();
    } catch (_) {
      // Haptics are optional.
    }
  }

  Future<void> _invoke(String method, [Object? arguments]) async {
    if (_isWeb) {
      return;
    }
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } catch (_) {
      // Audio is optional on platforms where the native channel is
      // unavailable, and failures should not block board interactions.
    }
  }
}
