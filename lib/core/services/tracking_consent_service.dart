import 'dart:async';
import 'dart:io' show Platform;

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Consentement publicitaire — RGPD (UMP) + suivi (ATT) — et démarrage d'AdMob.
///
/// Deux consentements DISTINCTS, exigés par deux régulateurs différents :
///
/// - **UMP** (User Messaging Platform de Google) : le consentement RGPD/ePrivacy
///   dans l'EEE, au Royaume-Uni et en Suisse. Sans lui, servir des pubs à un
///   utilisateur de ces zones est illégal, et AdMob refuse de charger. Le
///   message de consentement se configure dans la console AdMob (Confidentialité
///   et messages) ; ce service en déclenche la collecte côté app. **Il manquait
///   entièrement.** Beaucoup de la diaspora vise l'Europe : ce n'était pas
///   optionnel.
/// - **ATT** (App Tracking Transparency, iOS 14+) : lire l'IDFA sans
///   autorisation ATT est un motif de rejet App Store. `NSUserTrackingUsageDescription`
///   est posé dans `Info.plist`, mais l'app ne demandait jamais l'autorisation.
///
/// Ordre imposé par Google sur iOS : **UMP d'abord, ATT ensuite**, puis AdMob —
/// et seulement si le consentement permet de demander des pubs
/// (`canRequestAds`). Sans consentement, `MobileAds` n'est pas initialisé et
/// `NativeAdWidget` retombe sur sa carte interne, comme lorsqu'une annonce
/// échoue.
///
/// À appeler après le premier rendu (pas au démarrage) : le formulaire UMP
/// comme le prompt ATT exigent une app visible.
class TrackingConsentService {
  TrackingConsentService._();

  static final TrackingConsentService instance = TrackingConsentService._();

  bool _initialized = false;

  /// Le consentement recueilli permet-il de demander des annonces ?
  ///
  /// Faux tant que le consentement RGPD requis n'a pas été obtenu ; les widgets
  /// d'annonce doivent alors afficher leur repli plutôt qu'appeler AdMob.
  bool _canRequestAds = false;
  bool get canRequestAds => _canRequestAds;

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

    // 1. UMP (RGPD) EN PREMIER : recueille le consentement et détermine si l'on
    //    peut demander des annonces.
    await _recueillirConsentementUmp();

    // 2. ATT (iOS), après le formulaire UMP comme Google le recommande.
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

    // 3. AdMob, seulement si le consentement permet de demander des pubs.
    if (!_canRequestAds) {
      debugPrint('AdMob: consentement insuffisant, SDK non initialisé');
      return;
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

  /// Recueille le consentement RGPD via UMP et met à jour [_canRequestAds].
  ///
  /// - Met à jour l'info de consentement (géographie, âge, statut en cache) ;
  /// - charge et affiche le formulaire **s'il est requis** (hors EEE/UK/CH il
  ///   ne l'est pas, `canRequestAds` passe alors directement à vrai) ;
  /// - lit `canRequestAds` — vrai quand les pubs sont autorisées.
  ///
  /// Aucune étape ne doit propager : un échec (réseau, message non configuré
  /// en console) laisse `_canRequestAds` à sa valeur en cache — au pire pas de
  /// pubs, jamais un plantage.
  ///
  /// ⚠️ Se teste sur un appareil réel : forcer la géographie EEE avec
  /// `ConsentDebugSettings(debugGeography: DebugGeography.debugGeographyEea,
  /// testIdentifiers: ['<ID de test loggé par le SDK>'])` passé à
  /// `ConsentRequestParameters`, et `ConsentInformation.instance.reset()` pour
  /// rejouer le formulaire. Le message doit d'abord être publié dans la console
  /// AdMob (Confidentialité et messages → GDPR).
  Future<void> _recueillirConsentementUmp() async {
    try {
      final params = ConsentRequestParameters();

      // `requestConsentInfoUpdate` est à callbacks : on l'attend.
      final maj = Completer<void>();
      ConsentInformation.instance.requestConsentInfoUpdate(
        params,
        maj.complete,
        (FormError error) {
          debugPrint('UMP: mise à jour impossible (${error.errorCode}: ${error.message})');
          if (!maj.isCompleted) maj.complete();
        },
      );
      await maj.future;

      // Charge et affiche le formulaire seulement s'il est requis.
      await ConsentForm.loadAndShowConsentFormIfRequired((FormError? error) {
        if (error != null) {
          debugPrint('UMP: formulaire (${error.errorCode}: ${error.message})');
        }
      });

      _canRequestAds = await ConsentInformation.instance.canRequestAds();
    } catch (e) {
      // Erreur de canal (rare) : on retombe sur le comportement d'avant l'UMP,
      // AdMob décidera lui-même du non-personnalisé. Ne bloque pas l'app.
      debugPrint('UMP: consentement indéterminé ($e)');
      _canRequestAds = true;
    }
  }
}
