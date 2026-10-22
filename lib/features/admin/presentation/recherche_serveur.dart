// Recherche textuelle faite par le serveur (PostgREST `or(... ilike ...)`).

/// Motif `ilike` « contient » d'une saisie, ou null si elle est vide.
///
/// Il part dans un filtre `or(...)` de PostgREST, où la virgule, les
/// parenthèses et les guillemets sont de la syntaxe : on les retire plutôt que
/// de laisser une saisie réécrire le filtre. `%` et `_` saisis sont des
/// caractères, pas des jokers.
String? motifRecherche(String saisie) {
  final propre = saisie
      .replaceAll(RegExp(r'[,()"\\*]'), ' ')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_')
      .trim();
  if (propre.isEmpty) return null;
  return '%$propre%';
}

/// Clause `or(...)` qui cherche [motif] dans chacune des [colonnes] (texte).
///
/// Une colonne `uuid` ne s'y prête pas : `ilike` lève sur ce type.
String clauseRecherche(Iterable<String> colonnes, String motif) =>
    colonnes.map((c) => '$c.ilike.$motif').join(',');
