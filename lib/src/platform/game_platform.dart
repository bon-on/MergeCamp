import 'game_platform_factory_stub.dart'
    if (dart.library.js_interop) 'game_platform_factory_web.dart'
    as platform_factory;

/// Hooks a distribution portal needs from the game loop.
///
/// Mobile and plain web builds use [NoopGamePlatform]; CrazyGames web builds
/// (`--dart-define=CRAZYGAMES=true`) use the SDK-backed implementation, and
/// GamePix web builds (`--dart-define=GAMEPIX=true`) use [NoopGamePlatform.gamePix]
/// (no SDK, no external network, no ads).
abstract class GamePlatform {
  const GamePlatform();

  Future<void> initialize();

  void gameplayStart();

  void gameplayStop();

  /// Shows an ad between runs. Completes when the ad ends, fails, or is
  /// unavailable, so callers can always continue afterwards.
  Future<void> showRunBreakAd();

  bool get isAudioMuted;

  /// Whether the post-game prompt to submit scores to the Bon-on leaderboard
  /// may be shown. Portal builds keep players on the portal.
  bool get allowsResultRegistration;
}

class NoopGamePlatform extends GamePlatform {
  const NoopGamePlatform({this.allowsResultRegistration = true});

  /// GamePix portal build: SDK-free, no ads, no result upload.
  const NoopGamePlatform.gamePix() : allowsResultRegistration = false;

  @override
  Future<void> initialize() async {}

  @override
  void gameplayStart() {}

  @override
  void gameplayStop() {}

  @override
  Future<void> showRunBreakAd() async {}

  @override
  bool get isAudioMuted => false;

  @override
  final bool allowsResultRegistration;
}

GamePlatform createGamePlatform() => platform_factory.createGamePlatform();
