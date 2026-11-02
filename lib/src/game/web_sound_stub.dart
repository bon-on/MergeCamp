/// Non-web builds play sounds through the native shell audio channel.
class WebSound {
  void play(String assetKey, {double volume = 1}) {}

  /// Starts [assetKey] on repeat. Completes with false when playback could not
  /// start (the stub never plays).
  Future<bool> loop(String assetKey, {double volume = 1}) async => false;

  void stopLoop() {}

  void pauseLoop() {}

  /// Resumes a paused loop. Completes with false when the browser refuses.
  Future<bool> resumeLoop() async => false;
}
