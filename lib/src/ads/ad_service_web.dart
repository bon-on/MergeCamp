class AdService {
  AdService._();

  static final AdService instance = AdService._();

  bool get canRequestAds => false;

  Future<void> initialize() async {}

  Future<void> loadInterstitial() async {}

  void showInterstitialIfReady() {}

  void dispose() {}
}
