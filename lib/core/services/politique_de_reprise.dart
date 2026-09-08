/// Décide quand il est utile de retenter l'échange de session Supabase.
///
/// Extraite de [SupabaseAuthBridge] pour être testable : le pont lui-même
/// dépend de Firebase et de Supabase, donc d'un vrai réseau.
///
/// Le problème qu'elle résout, vu sur SM A515F le 2026-09-08 (mode avion,
/// cache vide) : l'app retentait l'échange **toutes les ~5 secondes, sans
/// jamais abandonner**, et l'écran des ambassades tournait indéfiniment
/// derrière — spinner encore présent après 85 s, sans message ni bouton.
///
/// Le pont avait pourtant déjà un repli exponentiel (5 s → 80 s). Il était
/// court-circuité de l'extérieur : `auth_remote_datasource.dart` rappelle
/// `syncWithFirebase` à **chaque** émission de `authStateChanges()`, et
/// Firebase en émet une à chaque échec de rafraîchissement. La déduplication
/// existante ne couvrait que les appels **simultanés** (`_inFlightSync`), pas
/// ceux qui arrivent *entre* deux tentatives.
///
/// D'où les deux règles ci-dessous : une fenêtre de calme qui vaut pour
/// **tous** les appelants, et un abandon au bout de [maxTentatives].
class PolitiqueDeReprise {
  PolitiqueDeReprise({DateTime Function()? horloge})
    : _maintenant = horloge ?? DateTime.now;

  /// Injectable pour les tests : sans ça il faudrait attendre vraiment.
  final DateTime Function() _maintenant;

  int _echecs = 0;
  DateTime? _pasAvant;

  /// Au-delà, on cesse de retenter tout seul.
  ///
  /// Six tentatives couvrent 5+10+20+40+80+80 = 235 s de coupure, ce qui
  /// absorbe un tunnel ou un ascenseur. Au-delà, l'appareil est hors ligne
  /// pour de bon et s'acharner ne fait que vider la batterie.
  static const int maxTentatives = 6;

  /// Après l'abandon, on laisse passer une tentative de temps en temps : le
  /// réseau peut revenir sans que rien ne nous le signale.
  static const Duration reposApresAbandon = Duration(minutes: 5);

  /// Vrai si une tentative vaut la peine maintenant.
  ///
  /// Faux pendant la fenêtre de calme — c'est ce qui neutralise les rappels
  /// répétés de `authStateChanges`.
  bool get peutTenter {
    final pasAvant = _pasAvant;
    return pasAvant == null || !_maintenant().isBefore(pasAvant);
  }

  bool get aAbandonne => _echecs >= maxTentatives;

  int get echecsConsecutifs => _echecs;

  /// Enregistre un échec et rend le délai avant la prochaine tentative
  /// programmée, ou `null` si on abandonne (aucun minuteur à poser).
  ///
  /// Même en cas d'abandon, la fenêtre de calme est posée : sans elle, les
  /// rappels externes repartiraient immédiatement toutes les 5 s.
  Duration? enregistrerEchec() {
    _echecs++;
    if (aAbandonne) {
      _pasAvant = _maintenant().add(reposApresAbandon);
      return null;
    }
    // 5, 10, 20, 40, 80, puis plafonné.
    final secondes = 5 * (1 << (_echecs - 1));
    final delai = Duration(seconds: secondes > 80 ? 80 : secondes);
    _pasAvant = _maintenant().add(delai);
    return delai;
  }

  /// L'échange a réussi : on repart de zéro.
  void enregistrerSucces() {
    _echecs = 0;
    _pasAvant = null;
  }

  /// Le réseau est revenu (ou l'app repasse au premier plan) : on autorise
  /// une tentative sans attendre la fin du repos.
  void autoriserUneTentative() => _pasAvant = null;
}
