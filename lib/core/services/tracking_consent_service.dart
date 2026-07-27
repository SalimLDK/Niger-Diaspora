import 'dart:io' show Platform;

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Consentement au suivi publicitaire (App Tracking Transparency) + démarrage
/// d'AdMob.
///
/// Sur iOS 14+, lire l'IDFA sans autorisation ATT est un motif de rejet App
/// Store. La clé `NSUserTrackingUsageDescription` était bien posée dans
/// `Info.plist`, mais l'app ne demandait jamais l'autorisation : les annonces
/// natives du fil partaient donc toujours en non-personnalisé au mieux, et le
/// binaire restait exposé à un rejet.
///
/// Android n'a pas d'équivalent ATT : on y initialise simplement AdMob.
class TrackingConsentService {
  TrackingConsentService._();

  static final TrackingConsentService instance = TrackingConsentService._();

  bool _initialized = false;

  /// Statut ATT résolu (toujours [TrackingStatus.notSupported] hors iOS).
  TrackingStatus _status = TrackingStatus.notSupported;

  TrackingStatus get status => _status;

  /// `true` seulement si l'utilisateur a explicitement accepté le suivi.
  /// À utiliser pour décider entre annonces personnalisées et non personnalisées.
  bool get isTrackingAuthorized => _status == TrackingStatus.authorized;

  /// Demande l'autorisation ATT (iOS uniquement) puis initialise AdMob.
  ///
  /// Idempotent : les appels suivants sont sans effet. Ne relance jamais la
  /// boîte de dialogue système — iOS ne la présente qu'une fois, ensuite le
  /// statut ne change que depuis les Réglages.
  ///
  /// À appeler après le premier rendu, pas pendant le démarrage : Apple exige
  /// que l'app soit visible quand le prompt s'affiche, sinon il est ignoré
  /// silencieusement et le statut reste `notDetermined`.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    if (kIsWeb) return;

    try {
      if (Platform.isIOS) {
        _status = await AppTrackingTransparency.trackingAuthorizationStatus;

        // On ne demande que si l'utilisateur n'a pas encore tranché : sinon
        // l'appel est un no-op et on garde le statut existant.
        if (_status == TrackingStatus.notDetermined) {
          _status =
              await AppTrackingTransparency.requestTrackingAuthorization();
        }
      }
    } catch (e) {
      // Un échec ATT ne doit jamais empêcher les annonces de se charger en
      // non-personnalisé : on dégrade au lieu de propager.
      debugPrint('ATT: résolution du statut impossible ($e)');
    }

    try {
      // AdMob n'était initialisé nulle part : NativeAdWidget chargeait des
      // annonces sur un SDK non démarré, qui échouaient et retombaient sur la
      // carte interne de repli.
      await MobileAds.instance.initialize();
    } catch (e) {
      debugPrint('AdMob: initialisation impossible ($e)');
    }
  }
}
