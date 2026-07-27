import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../../core/constants/ad_config.dart';
import '../../../../core/services/tracking_consent_service.dart';
import 'internal_ad_card.dart';

class NativeAdWidget extends StatefulWidget {
  const NativeAdWidget({required this.adIndex, super.key});

  final int adIndex;

  @override
  State<NativeAdWidget> createState() => _NativeAdWidgetState();
}

class _NativeAdWidgetState extends State<NativeAdWidget> {
  NativeAd? _nativeAd;
  bool _isLoaded = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    final ad = NativeAd(
      adUnitId: AdConfig.nativeAdUnitId,
      // Sans consentement ATT explicite (iOS) on demande des annonces non
      // personnalisées : c'est ce qui rend le prompt ATT utile plutôt que
      // décoratif.
      request: AdRequest(
        nonPersonalizedAds:
            !TrackingConsentService.instance.isTrackingAuthorized,
      ),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() => _isLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (mounted) setState(() => _failed = true);
        },
      ),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.medium,
      ),
    );
    ad.load();
    _nativeAd = ad;
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed || (!_isLoaded && _nativeAd == null)) {
      return InternalAdCard(adIndex: widget.adIndex);
    }

    if (!_isLoaded) {
      // Placeholder shimmer-like while loading
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        height: 120,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      height: 320,
      child: AdWidget(ad: _nativeAd!),
    );
  }
}
