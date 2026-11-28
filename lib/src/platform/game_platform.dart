import 'game_platform_factory_stub.dart'
    if (dart.library.js_interop) 'game_platform_factory_web.dart'
    as platform_factory;

/// Hooks a distribution portal needs from the game loop.
///
/// Mobile and plain web builds use [NoopGamePlatform]; CrazyGames web builds
/// (`--dart-define=CRAZYGAMES=true`) use the CrazyGames SDK adapter, and
/// GamePix web builds (`--dart-define=GAMEPIX=true`) the GamePix SDK adapter
/// (feature-gamepix-sdk).
abstract class GamePlatform {
  const GamePlatform();

  Future<void> initialize();

  void gameplayStart();

  void gameplayStop();

  /// Shows an ad between runs. Completes when the ad ends, fails, or is
  /// unavailable, so callers can always continue afterwards.
  Future<void> showRunBreakAd();

  /// Whether [showRewardedAd] can ever pay out (feature-second-wind).
  bool get supportsRewardedAds => false;

  /// Shows a rewarded ad. Completes true only when the player watched it to
  /// the end; false on skip, error, no fill or timeout.
  Future<bool> showRewardedAd() async => false;

  bool get isAudioMuted;

  /// Registers a callback for when [isAudioMuted] may have changed (portal
  /// mute setting, ad start/end). Platforms without such events ignore it.
  void setAudioMuteListener(void Function()? listener) {}

  /// Whether the post-game prompt to submit scores to the Bon-on leaderboard
  /// may be shown. Portal builds keep players on the portal.
  bool get allowsResultRegistration;

  /// Public game page put into shared results (feature-next-goal-share);
  /// null hides every share action. It is only text in the shared message:
  /// the game never opens it.
  String? get shareLink => null;
}

/// GitHub Pages (and mobile) game page used in shared results.
const String pagesShareLink = 'https://bon-on.github.io/MergeCamp/';

class NoopGamePlatform extends GamePlatform {
  const NoopGamePlatform({
    this.allowsResultRegistration = true,
    this.shareLink = pagesShareLink,
  });

  /// Portal behaviour without an SDK: no ads, no result upload and no share
  /// actions (GamePix forbids outbound links). The GamePix adapter falls back
  /// to the same behaviour when its SDK is missing.
  const NoopGamePlatform.gamePix()
    : allowsResultRegistration = false,
      shareLink = null;

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

  @override
  final String? shareLink;
}

GamePlatform createGamePlatform() => platform_factory.createGamePlatform();
