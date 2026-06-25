import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_ids.dart';

class AdService {
  AdService._();

  static final AdService instance = AdService._();

  bool _initialized = false;
  InterstitialAd? _interstitialAd;
  bool _loadingInterstitial = false;

  bool get canRequestAds => _initialized;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    try {
      if (kReleaseMode && !AdIds.hasRealAdUnit) {
        debugPrint('AdMob disabled: release build has no real ad unit IDs.');
        return;
      }
      final canRequestAds = await _prepareConsent();
      if (!canRequestAds) {
        return;
      }
      await MobileAds.instance.initialize();
      _initialized = true;
      unawaited(loadInterstitial());
    } catch (error, stackTrace) {
      debugPrint('AdMob initialization failed: $error\n$stackTrace');
    }
  }

  Future<bool> _prepareConsent() {
    final completer = Completer<bool>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(tagForUnderAgeOfConsent: false),
      () async {
        await ConsentForm.loadAndShowConsentFormIfRequired((formError) {
          if (formError != null) {
            debugPrint('Consent form failed: $formError');
          }
        });
        final canRequestAds = await ConsentInformation.instance.canRequestAds();
        if (!completer.isCompleted) {
          completer.complete(canRequestAds);
        }
      },
      (formError) {
        debugPrint('Consent info update failed: $formError');
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      },
    );

    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => false,
    );
  }

  BannerAd createBannerAd({required VoidCallback onLoaded}) {
    if (kReleaseMode && !AdIds.canRequestBanner) {
      throw StateError('Banner ad unit ID is not configured for release.');
    }

    return BannerAd(
      adUnitId: AdIds.bannerUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (_) => onLoaded(),
        onAdFailedToLoad: (ad, error) {
          debugPrint('Banner failed to load: $error');
          ad.dispose();
        },
      ),
    )..load();
  }

  Future<void> loadInterstitial() async {
    if (!_initialized || _loadingInterstitial || _interstitialAd != null) {
      return;
    }
    if (kReleaseMode && !AdIds.canRequestInterstitial) {
      return;
    }

    _loadingInterstitial = true;
    await InterstitialAd.load(
      adUnitId: AdIds.interstitialUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _loadingInterstitial = false;
        },
        onAdFailedToLoad: (error) {
          debugPrint('Interstitial failed to load: $error');
          _loadingInterstitial = false;
        },
      ),
    );
  }

  void showInterstitialIfReady() {
    if (!_initialized) {
      return;
    }

    final ad = _interstitialAd;
    if (ad == null) {
      unawaited(loadInterstitial());
      return;
    }

    _interstitialAd = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        unawaited(loadInterstitial());
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('Interstitial failed to show: $error');
        ad.dispose();
        unawaited(loadInterstitial());
      },
    );
    ad.show();
  }

  void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
  }
}
