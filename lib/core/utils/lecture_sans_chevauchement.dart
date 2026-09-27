import 'dart:async';

/// Relit une liste entière sans jamais lancer deux passes à la fois.
///
/// Un flux qui recharge tout à chaque événement temps réel (la liste des
/// discussions : `callback: (_) => fetch()`) lançait une requête par
/// événement, en parallèle. Un seul message en produit plusieurs — l'envoi
/// réécrit l'aperçu, la réception pose l'accusé, la lecture remet le compteur
/// à zéro — et rien n'ordonnait les réponses : si la plus ancienne revenait
/// la dernière, c'est **elle** que l'écran gardait, jusqu'au changement
/// suivant. La liste restait sur un état périmé, sans erreur nulle part :
/// « ça ne s'actualise pas ».
///
/// Ici, une passe à la fois. Un appel qui tombe pendant une passe ne se perd
/// pas : il en demande une autre, lancée à la fin de celle en cours — ce qui
/// garantit que la dernière lecture faite est postérieure au dernier
/// changement signalé. [planifier] regroupe en plus les rafales.
class LectureSansChevauchement {
  LectureSansChevauchement(
    this._lire, {
    this.regroupement = const Duration(milliseconds: 200),
  });

  final Future<void> Function() _lire;

  /// Fenêtre pendant laquelle les appels à [planifier] n'en font qu'un.
  final Duration regroupement;

  bool _enCours = false;
  bool _aRefaire = false;
  bool _ferme = false;
  Timer? _minuterie;

  /// Lit maintenant — ou, si une passe tourne déjà, juste après elle.
  Future<void> lire() async {
    if (_ferme) return;
    if (_enCours) {
      _aRefaire = true;
      return;
    }
    _enCours = true;
    try {
      do {
        _aRefaire = false;
        await _lire();
      } while (_aRefaire && !_ferme);
    } finally {
      _enCours = false;
    }
  }

  /// Lit après [regroupement] ; les appels rapprochés n'en font qu'un.
  void planifier() {
    if (_ferme) return;
    _minuterie?.cancel();
    _minuterie = Timer(regroupement, () => unawaited(lire()));
  }

  /// Plus aucune lecture : à appeler quand le flux n'a plus d'écouteur.
  void fermer() {
    _ferme = true;
    _minuterie?.cancel();
    _minuterie = null;
  }
}
