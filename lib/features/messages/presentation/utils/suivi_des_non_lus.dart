import '../../data/datasources/lecture_serveur.dart';

/// Tout ce qui était non lu à l'ouverture est-il lu, d'après un relevé pris
/// **après** une avancée du curseur ?
///
/// - plus aucun non-lu : oui ;
/// - sinon, le curseur a-t-il atteint [dernierNonLuALOuverture] ? Un message
///   arrivé pendant la lecture est non lu lui aussi : sans cette borne, le
///   séparateur ne partirait jamais dans une discussion active.
///
/// Les deux dates viennent du serveur (`created_at`), jamais de l'horloge de
/// l'appareil. Sans borne (migration `20260917002300` absente), seul le
/// premier critère vaut.
bool toutEstLu(RepereDeLecture maintenant, {DateTime? dernierNonLuALOuverture}) {
  if (maintenant.nonLus == 0) return true;
  final borne = dernierNonLuALOuverture;
  final curseur = maintenant.curseurA;
  if (borne == null || curseur == null) return false;
  return !curseur.isBefore(borne);
}

/// Ce que deviennent le séparateur « N messages non lus » et le badge du
/// bouton « aller en bas » **après** l'ouverture (étape B du plan).
///
/// À l'ouverture, les deux sont posés par le relevé du repère. Ensuite :
///
/// - **le badge descend** à mesure que les messages sont lus — il affichait le
///   compte d'ouverture jusqu'à la fermeture de l'écran ;
/// - **le séparateur part** quand tout ce qui était non lu est lu, mais jamais
///   sous les yeux : retirer une ligne pendant qu'on la regarde ferait sauter
///   le fil. Il part au moment où il sort de l'écran, ou tout de suite s'il
///   n'y est pas déjà.
/// - une fois parti, **il ne revient pas**, quoi qu'il arrive ensuite.
///
/// Sans Flutter : l'écran lui passe les relevés et les rapports de visibilité,
/// et redessine quand une méthode rend `true`.
class SuiviDesNonLus {
  DateTime? _dernierNonLuALOuverture;
  int? _restants;
  bool _toutLu = false;
  bool _separateurVisible = false;
  bool _separateurRetire = false;

  /// La borne haute des non-lus au relevé d'ouverture.
  void noterOuverture(RepereDeLecture repere) {
    _dernierNonLuALOuverture = repere.dernierNonLuA;
  }

  /// Le nombre à afficher sur le badge : le compte d'ouverture tant qu'aucun
  /// relevé ne l'a remplacé.
  int restants(int alOuverture) => _restants ?? alOuverture;

  bool get toutLu => _toutLu;
  bool get separateurRetire => _separateurRetire;

  /// Un relevé de plus en vaut-il la peine ? Plus rien à faire descendre ni à
  /// faire partir : on arrête d'interroger le serveur.
  bool get doitSuivre => !_toutLu || (_restants ?? 1) > 0;

  /// Relevé pris après une avancée du curseur. Rend `true` si l'affichage
  /// change.
  bool suivre(RepereDeLecture maintenant) {
    final avant = (_restants, _toutLu, _separateurRetire);
    _restants = maintenant.nonLus;
    if (!_toutLu &&
        toutEstLu(maintenant, dernierNonLuALOuverture: _dernierNonLuALOuverture)) {
      _toutLu = true;
      // Pas à l'écran : rien ne sautera, il part maintenant. À l'écran, il
      // attend d'en sortir (voir [signalerSeparateur]).
      if (!_separateurVisible) _separateurRetire = true;
    }
    return avant != (_restants, _toutLu, _separateurRetire);
  }

  /// Rapport de visibilité du séparateur. Rend `true` s'il vient d'être
  /// retiré.
  bool signalerSeparateur(double fraction) {
    _separateurVisible = fraction > 0;
    if (_toutLu && !_separateurVisible && !_separateurRetire) {
      _separateurRetire = true;
      return true;
    }
    return false;
  }
}
