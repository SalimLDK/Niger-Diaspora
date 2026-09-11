import 'dart:async';

import '../providers/app_settings_provider.dart';
import '../services/feature_flag_service.dart';

/// Ce que la porte des drapeaux décide pour une destination.
enum DecisionPorte {
  /// Route libre, ou module actif : on y va.
  passer,

  /// Module sous drapeau, drapeaux pas encore lus : on attend sur le splash.
  attendre,

  /// Module désactivé, ou drapeaux illisibles : on renvoie sur l'accueil.
  refuser,
}

/// Routes « phase 2 » et le drapeau qui les ouvre.
///
/// Ce sont des préfixes : `/podcasts` couvre `/podcasts/<id>` et
/// `/podcasts/episodes/<id>`, `/audio-rooms` couvre `/audio-rooms/<id>/replay`.
const routesSousDrapeau = <String, AppFeature>{
  '/transfers': AppFeature.moneyTransfer,
  '/marketplace': AppFeature.marketplace,
  '/podcasts': AppFeature.podcasts,
  '/payment-accounts': AppFeature.moneyTransfer,
  '/payment-history': AppFeature.moneyTransfer,
  '/audio-rooms': AppFeature.audioRooms,
};

/// Drapeau dont dépend [chemin], ou `null` si la route est toujours ouverte.
AppFeature? drapeauDe(String chemin) {
  for (final entree in routesSousDrapeau.entries) {
    if (chemin.startsWith(entree.key)) return entree.value;
  }
  return null;
}

/// La porte des routes sous drapeau, sans état ni effet : tout ce qu'elle
/// sait lui est passé.
///
/// **Trois issues, et non deux.** L'ancienne porte n'avait que « drapeaux
/// chargés → on décide » et « pas encore → on laisse passer » :
///
/// - laisser passer pendant le chargement ouvrait `/podcasts`, `/marketplace`,
///   `/transfers`… pendant les premières secondes de chaque lancement, même
///   désactivés. Mesuré sur SM A515F le 2026-09-10 : le même lien donnait
///   l'écran s'il arrivait tôt, l'accueil s'il arrivait tard ;
/// - refuser pendant le chargement — le sens inverse — a déjà coûté un
///   défaut : les défauts de [FeatureFlagsEntity] mettent podcasts et salons
///   audio à `false`, et renvoyaient ces écrans sur `/home` à chaque
///   démarrage à froid, quoi qu'en dise le back-office.
///
/// D'où la troisième : **attendre**. Et un échec de lecture refuse, parce que
/// le fournisseur des réglages ne réessaie jamais — attendre un échec, c'est
/// attendre pour toujours. L'interface fait le même choix : sans drapeaux
/// chargés, `featureFlagsProvider` rend les défauts de [FeatureFlagsEntity].
DecisionPorte decisionPorte(
  String chemin, {
  required FeatureFlagsEntity? drapeaux,
  required bool enEchec,
}) {
  final drapeau = drapeauDe(chemin);
  if (drapeau == null) return DecisionPorte.passer;
  if (drapeaux != null) {
    return FeatureFlagService.isFeatureEnabled(drapeaux, drapeau)
        ? DecisionPorte.passer
        : DecisionPorte.refuser;
  }
  return enEchec ? DecisionPorte.refuser : DecisionPorte.attendre;
}

/// Borne l'attente de [DecisionPorte.attendre].
///
/// Un `get()` Firestore sur un réseau lent peut ne ni aboutir ni échouer
/// avant longtemps ; sans borne, un lien vers `/marketplace/<id>` laisserait
/// l'utilisateur sur le splash. À l'échéance, l'attente vaut échec — et ne se
/// réarme plus : si les drapeaux arrivent ensuite, ils l'emportent de toute
/// façon sur elle dans [decisionPorte].
class AttenteDrapeaux {
  AttenteDrapeaux(this._delai);

  final Duration _delai;
  Timer? _minuteur;
  bool _echue = false;

  /// L'attente a expiré sans que les drapeaux arrivent.
  bool get echue => _echue;

  /// Démarre l'attente, une seule fois ; [reveil] relance l'évaluation.
  void armer(void Function() reveil) {
    if (_echue || _minuteur != null) return;
    _minuteur = Timer(_delai, () {
      _minuteur = null;
      _echue = true;
      reveil();
    });
  }

  /// Les drapeaux sont arrivés, ou la destination a été rejouée.
  void desarmer() {
    _minuteur?.cancel();
    _minuteur = null;
  }
}
