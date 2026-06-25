import 'package:flutter/foundation.dart';

class AdIds {
  const AdIds._();

  static const _testPublisherId = 'ca-app-pub-3940256099942544';

  static const androidAppId = String.fromEnvironment(
    'ADMOB_ANDROID_APP_ID',
    defaultValue: 'ca-app-pub-9252543133070309~9754796580',
  );
  static const iosAppId = String.fromEnvironment(
    'ADMOB_IOS_APP_ID',
    defaultValue: 'ca-app-pub-9252543133070309~7842647798',
  );

  static const _androidBanner = String.fromEnvironment(
    'ADMOB_ANDROID_BANNER_ID',
    defaultValue: 'ca-app-pub-9252543133070309/2162561262',
  );
  static const _iosBanner = String.fromEnvironment(
    'ADMOB_IOS_BANNER_ID',
    defaultValue: 'ca-app-pub-9252543133070309/8201740445',
  );
  static const _androidInterstitial = String.fromEnvironment(
    'ADMOB_ANDROID_INTERSTITIAL_ID',
    defaultValue: 'ca-app-pub-3940256099942544/1033173712',
  );
  static const _iosInterstitial = String.fromEnvironment(
    'ADMOB_IOS_INTERSTITIAL_ID',
    defaultValue: 'ca-app-pub-3940256099942544/4411468910',
  );

  static String get bannerUnitId {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return _iosBanner;
    }
    return _androidBanner;
  }

  static String get interstitialUnitId {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return _iosInterstitial;
    }
    return _androidInterstitial;
  }

  static bool get canRequestBanner {
    return !bannerUnitId.startsWith(_testPublisherId);
  }

  static bool get canRequestInterstitial {
    return !interstitialUnitId.startsWith(_testPublisherId);
  }

  static bool get hasRealAdUnit {
    return canRequestBanner || canRequestInterstitial;
  }
}
