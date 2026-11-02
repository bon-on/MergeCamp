class AdService {
  AdService._();

  static final AdService instance = AdService._();

  bool get canRequestAds => false;

  Future<void> initialize() async {}

  Future<void> loadInterstitial() async {}

  /// Web builds have no interstitials; returns false (nothing shown).
  bool showInterstitialIfReady({void Function()? onClosed}) => false;

  void dispose() {}
}
