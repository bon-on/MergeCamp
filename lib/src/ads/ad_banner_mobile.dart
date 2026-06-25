import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_service.dart';

class AdBanner extends StatefulWidget {
  const AdBanner({super.key, required this.enabled});

  final bool enabled;

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _bannerAd;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AdBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) {
      _bannerAd?.dispose();
      _bannerAd = null;
      _loaded = false;
      _load();
    }
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  void _load() {
    if (!widget.enabled || !AdService.instance.canRequestAds) {
      return;
    }

    _bannerAd = AdService.instance.createBannerAd(
      onLoaded: () {
        if (mounted) {
          setState(() => _loaded = true);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final banner = _bannerAd;
    if (!widget.enabled || !_loaded || banner == null) {
      return const SizedBox.shrink();
    }

    return SafeArea(
      top: false,
      child: SizedBox(
        width: banner.size.width.toDouble(),
        height: banner.size.height.toDouble(),
        child: AdWidget(ad: banner),
      ),
    );
  }
}
