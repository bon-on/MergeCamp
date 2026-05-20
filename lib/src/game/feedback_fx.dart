import 'package:flutter/services.dart';

class FeedbackFx {
  static const MethodChannel _channel = MethodChannel('merge_camp/audio');

  Future<void> initialize() async {}

  Future<void> tap() async {
    await _invoke('playTap');
    await HapticFeedback.selectionClick();
  }

  Future<void> merge() async {
    await _invoke('playMerge');
    await HapticFeedback.mediumImpact();
  }

  Future<void> warning() async {
    await _invoke('playWarning');
    await HapticFeedback.heavyImpact();
  }

  Future<void> dispose() async {
    await _invoke('disposeAudio');
  }

  Future<void> _invoke(String method) async {
    try {
      await _channel.invokeMethod<void>(method);
    } on MissingPluginException {
      // Audio is optional on platforms where the native channel is unavailable.
    } on PlatformException {
      // Audio failures should not block board interactions.
    }
  }
}
