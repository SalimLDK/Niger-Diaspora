/// Un lot rendu par une source : ses lignes, et si elle n'en a plus derrière.
typedef LotPagine<T> = ({List<T> items, bool fini});

/// Pagine plusieurs listes **déjà triées** comme une seule, sans rien
/// recharger : à chaque appel, la page est faite des plus récentes lignes de
/// l'ensemble des sources, et chaque source n'est interrogée que quand son
/// tampon est vide.
///
/// Sert à l'écran Signalements, dont les lignes viennent de deux endroits
/// (Firestore pour ce que l'app signale, Supabase pour les avis) qu'aucune
/// requête ne sait joindre. Chaque source garde son propre curseur : [sources]
/// rend, à chaque appel, le lot SUIVANT de cette source.
class FusionPaginee<T> {
  FusionPaginee({required this.sources, required this.avant})
      : _tampons = [for (final _ in sources) <T>[]],
        _finis = [for (final _ in sources) false],
        _videsDeSuite = List.filled(sources.length, 0);

  /// Lots vides d'affilée au-delà desquels une source est tenue pour finie.
  static const int maxLotsVidesDeSuite = 20;

  /// Une fonction par source : le lot suivant, dans l'ordre de [avant].
  final List<Future<LotPagine<T>> Function()> sources;

  /// Négatif si [a] se range avant [b] (le plus récent d'abord).
  final int Function(T a, T b) avant;

  final List<List<T>> _tampons;
  final List<bool> _finis;
  final List<int> _videsDeSuite;

  /// Reste-t-il, peut-être, des lignes à lire ? Vrai tant qu'un tampon n'est
  /// pas vide ou qu'une source n'a pas dit « fini » : au pire, la page
  /// suivante revient vide et ferme la question.
  bool get encorePlus =>
      _tampons.any((t) => t.isNotEmpty) || _finis.any((f) => !f);

  Future<void> _remplir(int i) async {
    // Un lot vide mais « pas fini » est permis (une source qui filtre peut
    // lire un lot entier sans rien garder) : on la relance, pas à l'infini.
    while (_tampons[i].isEmpty && !_finis[i]) {
      final lot = await sources[i]();
      _tampons[i].addAll(lot.items);
      _videsDeSuite[i] = lot.items.isEmpty ? _videsDeSuite[i] + 1 : 0;
      if (lot.fini || _videsDeSuite[i] >= maxLotsVidesDeSuite) {
        _finis[i] = true;
      }
    }
  }

  /// Les [n] lignes suivantes de l'ensemble.
  Future<List<T>> prochainePage(int n) async {
    final page = <T>[];
    while (page.length < n) {
      // Chaque source dont le tampon est vide doit montrer sa prochaine
      // ligne avant qu'on puisse comparer : sinon une source muette
      // passerait après une plus ancienne.
      for (var i = 0; i < sources.length; i++) {
        await _remplir(i);
      }
      var meilleure = -1;
      for (var i = 0; i < _tampons.length; i++) {
        if (_tampons[i].isEmpty) continue;
        if (meilleure < 0 ||
            avant(_tampons[i].first, _tampons[meilleure].first) < 0) {
          meilleure = i;
        }
      }
      if (meilleure < 0) break;
      page.add(_tampons[meilleure].removeAt(0));
    }
    return page;
  }
}
