import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:url_launcher/url_launcher.dart';

import 'preferences_service.dart';

/// Ce que le service attend du dialogue natif.
///
/// `InAppReview` est une classe concrète assise sur un canal de méthode :
/// aucun banc ne peut l'instancier, et `requestReview()` ne renvoie rien.
/// Passer par cette interface permet de rejouer la décision — inviter ou se
/// taire — sans appareil.
abstract interface class NativeReviewPrompt {
  Future<bool> isAvailable();
  Future<void> requestReview();
  Future<void> openStoreListing({String? appStoreId});
}

class _PluginReviewPrompt implements NativeReviewPrompt {
  const _PluginReviewPrompt();

  @override
  Future<bool> isAvailable() => InAppReview.instance.isAvailable();

  @override
  Future<void> requestReview() => InAppReview.instance.requestReview();

  @override
  Future<void> openStoreListing({String? appStoreId}) =>
      InAppReview.instance.openStoreListing(appStoreId: appStoreId);
}

/// Quand proposer de noter l'app — et quand se taire.
///
/// Décision pure : ni préférences, ni plugin, ni horloge. Tout entre en
/// paramètre, pour que le banc puisse rejouer une année d'usage en quelques
/// lignes.
///
/// Les seuils suivent la contrainte de Google : le dialogue natif est
/// contingenté (de l'ordre d'une fois par utilisateur et par trimestre) et il
/// ne dit jamais s'il s'est affiché. Demander tôt et souvent ne gagne donc
/// rien — ça brûle le quota sur des gens qui n'ont pas encore d'opinion.
abstract final class AppReviewPolicy {
  /// Ouvertures de l'app avant la première invitation.
  static const int ouverturesMinimum = 8;

  /// Ancienneté minimale de l'installation.
  static const Duration anciennete = Duration(days: 3);

  /// Délai avant de retenter. Une tentative avalée par le quota est
  /// indiscernable d'une tentative affichée : ne jamais retenter
  /// condamnerait au silence des gens à qui rien n'a été montré.
  static const Duration entreDeuxInvitations = Duration(days: 120);

  static bool doitInviter({
    required int ouvertures,
    required DateTime? premiereOuverture,
    required DateTime? derniereInvitation,
    required bool ficheDejaOuverte,
    required DateTime maintenant,
  }) {
    // La personne est allée sur le store d'elle-même : ne pas lui repasser
    // par-dessus.
    if (ficheDejaOuverte) return false;
    if (ouvertures < ouverturesMinimum) return false;
    if (premiereOuverture == null) return false;
    if (maintenant.difference(premiereOuverture) < anciennete) return false;
    if (derniereInvitation != null &&
        maintenant.difference(derniereInvitation) < entreDeuxInvitations) {
      return false;
    }
    return true;
  }
}

/// Noter l'application, par les deux chemins qui existent.
///
/// **Le bouton explicite ouvre la fiche du store, jamais le dialogue natif.**
/// Google demande expressément de ne pas câbler un bouton « Noter » sur
/// `requestReview()` : le quota peut l'avaler, et l'utilisateur voit alors un
/// bouton mort. Le dialogue natif est réservé au chemin automatique, où son
/// silence ne se remarque pas.
class AppReviewService {
  /// Les deux liens ont déjà été faux et menaient à « app introuvable » :
  /// `com.diasponiger.app` n'a jamais existé (l'`applicationId` réel est
  /// `com.diasponiger.diasponiger`, cf. `android/app/build.gradle.kts`) et
  /// `id123456789` était inventé. Le vrai identifiant App Store, attribué le
  /// 2026-09-01 à la création de la fiche, est `6807607258`.
  static const String appStoreId = '6807607258';
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.diasponiger.diasponiger';
  static const String appStoreUrl = 'https://apps.apple.com/app/id$appStoreId';

  static AppReviewService? _instance;
  static AppReviewService get instance =>
      _instance ??= AppReviewService(const _PluginReviewPrompt());

  final NativeReviewPrompt _natif;
  final DateTime Function() _maintenant;

  AppReviewService(this._natif, {DateTime Function()? horloge})
      : _maintenant = horloge ?? DateTime.now;

  PreferencesService get _prefs => PreferencesService.instance;

  /// À appeler une fois par démarrage, avant tout le reste.
  ///
  /// Recale au passage les deux repères de date s'ils sont dans le futur :
  /// une horloge avancée puis remise à l'heure laisserait sinon un
  /// horodatage qui bloque l'invitation pour de bon, sans que rien ne le
  /// signale.
  Future<void> enregistrerOuverture() async {
    final maintenant = _maintenant();

    final premiere = _prefs.reviewPremiereOuverture;
    if (premiere == null || premiere.isAfter(maintenant)) {
      await _prefs.setReviewPremiereOuverture(maintenant);
    }

    final derniere = _prefs.reviewDerniereInvitation;
    if (derniere != null && derniere.isAfter(maintenant)) {
      await _prefs.setReviewDerniereInvitation(maintenant);
    }

    await _prefs.setReviewOuvertures(_prefs.reviewOuvertures + 1);
  }

  /// Le moment est-il opportun ? Lit les compteurs, applique la politique.
  bool momentOpportun() => AppReviewPolicy.doitInviter(
        ouvertures: _prefs.reviewOuvertures,
        premiereOuverture: _prefs.reviewPremiereOuverture,
        derniereInvitation: _prefs.reviewDerniereInvitation,
        ficheDejaOuverte: _prefs.reviewFicheOuverte,
        maintenant: _maintenant(),
      );

  /// Chemin automatique : propose le dialogue natif si le moment s'y prête.
  ///
  /// Renvoie `true` quand la demande a été **transmise** au système — pas
  /// quand un dialogue s'est affiché : ni Play ni l'App Store ne le disent.
  /// N'ouvre jamais de navigateur en repli : une fiche de store qui
  /// surgirait sans qu'on l'ait demandée serait pire que rien.
  Future<bool> inviterSiLeMomentSyPrete() async {
    if (!momentOpportun()) return false;

    try {
      if (!await _natif.isAvailable()) return false;

      // Horodater *avant* d'appeler : si l'appel se perd, le prochain essai
      // doit quand même attendre son tour. Sinon un `requestReview()` muet
      // relancerait la tentative à chaque ouverture.
      await _prefs.setReviewDerniereInvitation(_maintenant());
      await _natif.requestReview();
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('Avis natif indisponible : $e');
      return false;
    }
  }

  /// Chemin explicite : ouvre la fiche du store, sur sa page d'avis.
  ///
  /// Renvoie `false` si rien n'a pu être ouvert — l'appelant doit le dire,
  /// sans quoi le bouton passe pour mort.
  Future<bool> ouvrirLaFicheDuStore() async {
    bool ouvert;
    try {
      // Sur iOS, ajoute `?action=write-review` ; sur Android, passe par
      // `market://` et retombe seul sur le web.
      await _natif.openStoreListing(appStoreId: appStoreId);
      ouvert = true;
    } catch (e) {
      if (kDebugMode) debugPrint('openStoreListing a échoué : $e');
      ouvert = await _ouvrirDansLeNavigateur();
    }

    // Marquer seulement si la fiche s'est vraiment ouverte : un échec
    // couperait l'invitation automatique pour un avis jamais déposé.
    if (ouvert) await _prefs.setReviewFicheOuverte();
    return ouvert;
  }

  Future<bool> _ouvrirDansLeNavigateur() async {
    final uri = Uri.parse(Platform.isIOS ? appStoreUrl : playStoreUrl);
    try {
      if (await canLaunchUrl(uri)) {
        return launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('Ouverture du store impossible : $e');
      return false;
    }
  }
}
