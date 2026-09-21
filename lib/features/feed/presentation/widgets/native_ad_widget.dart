import 'dart:async';

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
    // RGPD : sans consentement suffisant (UMP), on NE demande PAS d'annonce —
    // le fil affiche sa carte interne. Demander à AdMob dans ce cas serait à la
    // fois non conforme et voué à l'échec (SDK non initialisé).
    if (!TrackingConsentService.instance.canRequestAds) {
      _failed = true;
      return;
    }

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
            unawaited(ad.dispose());
            return;
          }
          setState(() => _isLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          unawaited(ad.dispose());
          if (mounted) setState(() => _failed = true);
        },
      ),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.medium,
      ),
    );
    unawaited(ad.load());
    _nativeAd = ad;
  }

  @override
  void dispose() {
    unawaited(_nativeAd?.dispose());
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
