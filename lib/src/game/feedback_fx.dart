import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'web_sound_stub.dart' if (dart.library.js_interop) 'web_sound_web.dart';

class FeedbackFx {
  FeedbackFx({bool Function()? isMuted}) : _isMuted = isMuted ?? _never;

  static const MethodChannel _channel = MethodChannel('merge_camp/audio');

  final bool Function() _isMuted;
  final WebSound _webSound = WebSound();

  static bool _never() => false;

  Future<void> initialize() async {}

  Future<void> tap() async {
    await _play('playTap', 'assets/audio/place.wav');
    await HapticFeedback.selectionClick();
  }

  Future<void> merge() async {
    await _play('playMerge', 'assets/audio/merge.wav');
    await HapticFeedback.mediumImpact();
  }

  Future<void> warning() async {
    await _play('playWarning', 'assets/audio/warning.wav');
    await HapticFeedback.heavyImpact();
  }

  Future<void> dispose() async {
    await _invoke('disposeAudio');
  }

  Future<void> _play(String method, String assetKey) async {
    if (_isMuted()) {
      return;
    }
    if (kIsWeb) {
      _webSound.play(assetKey);
      return;
    }
    await _invoke(method);
  }

  Future<void> _invoke(String method) async {
    if (kIsWeb) {
      return;
    }
    try {
      await _channel.invokeMethod<void>(method);
    } on MissingPluginException {
      // Audio is optional on platforms where the native channel is unavailable.
    } on PlatformException {
      // Audio failures should not block board interactions.
    }
  }
}
