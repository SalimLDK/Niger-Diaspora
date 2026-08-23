/// Pseudo de mention du fil : le `@pseudo` inséré dans le texte d'une
/// publication ou d'un commentaire, et enregistré à côté dans
/// `mentioned_users[].name`.
///
/// **Ce qui a changé.** Le pseudo était produit par
/// `displayName.replaceAll(RegExp(r'[^\w]'), '')`. En Dart, `\w` vaut
/// `[A-Za-z0-9_]` — de l'ASCII pur, quelle que soit la locale. Mentionner
/// « Ibrahim Yacouba Maïdaoua » produisait donc `@IbrahimYacoubaMadaoua` : le
/// `ï` était purement supprimé, sans que rien ne le signale. Même chose pour
/// « Aïcha », « Boubé », « N'Djaména », ou tout nom écrit dans un alphabet non
/// latin. Les lettres et chiffres de n'importe quel alphabet sont désormais
/// conservés ; seuls les espaces et la ponctuation sautent, comme avant.
///
/// **Pourquoi les deux conventions cohabitent.** Les publications et les
/// commentaires déjà en base portent l'ANCIEN pseudo, à la fois dans leur
/// texte (`@IbrahimYacoubaMadaoua`) et dans `mentioned_users[].name`. Rien ne
/// les réécrit. [mentionHandleMatches] rapproche donc les deux formes, pour
/// qu'un appui sur une mention ancienne continue d'ouvrir le bon profil.
library;

/// Caractères admis dans un pseudo : lettres et chiffres de n'importe quel
/// alphabet, plus le tiret bas.
const String mentionHandleCharClass = r'[\p{L}\p{N}_]';

final RegExp _nonHandleChars = RegExp(r'[^\p{L}\p{N}_]', unicode: true);

/// L'ancienne classe, ASCII seule — celle qui mangeait les accents.
final RegExp _legacyNonHandleChars = RegExp(r'[^\w]');

/// Pseudo de mention d'un nom affiché.
///
/// « Aïcha N'Diaye » → « AïchaNDiaye ».
String mentionHandle(String displayName) =>
    displayName.replaceAll(_nonHandleChars, '');

/// Ancien pseudo, ASCII seul. Conservé uniquement pour rapprocher les mentions
/// déjà enregistrées — ne jamais s'en servir pour en écrire une nouvelle.
///
/// « Aïcha N'Diaye » → « AchaNDiaye ».
String legacyMentionHandle(String displayName) =>
    displayName.replaceAll(_legacyNonHandleChars, '');

/// Vrai si [written] — le pseudo lu dans le texte — désigne bien [stored], le
/// pseudo enregistré avec la mention, dans l'une ou l'autre convention.
///
/// Le repli compare les deux réduites à l'ASCII : `Maïdaoua` (texte récent) et
/// `Madaoua` (mention enregistrée avant le correctif) se rejoignent ainsi.
bool mentionHandleMatches(String stored, String written) {
  if (stored == written) return true;

  final storedAscii = legacyMentionHandle(stored);
  final writtenAscii = legacyMentionHandle(written);

  // Un nom sans aucune lettre ASCII (« 李明 », « Здравствуй ») se réduit à la
  // chaîne vide. Deux vides ne se ressemblent pas : sans cette garde, toutes
  // les personnes au nom non latin se confondraient entre elles.
  if (storedAscii.isEmpty || writtenAscii.isEmpty) return false;

  return storedAscii == writtenAscii;
}

/// `@pseudo` en fin de chaîne : ce que la personne est en train de taper.
final RegExp mentionTypingPattern = RegExp(
  '@($mentionHandleCharClass*)\$',
  unicode: true,
);

/// `@pseudo` n'importe où dans un texte.
final RegExp mentionTokenPattern = RegExp(
  '@$mentionHandleCharClass+',
  unicode: true,
);

/// Pseudo à écrire derrière le `@` pour désigner quelqu'un.
///
/// La poignée publique (`users.handle`, §16f) quand elle existe — c'est la
/// forme courte et stable, celle que la personne a choisie. Sinon, le pseudo
/// dérivé du nom affiché, pour que tout le monde reste mentionnable : au
/// 2026-08-23, 2 comptes sur 11 seulement avaient choisi une poignée.
String mentionTokenFor({String? handle, required String displayName}) {
  final normalized = handle?.trim();
  if (normalized != null && normalized.isNotEmpty) return normalized;
  return mentionHandle(displayName);
}

/// Replie les diacritiques courants pour la RECHERCHE seulement — jamais pour
/// écrire un pseudo.
///
/// Taper `ï` demande un appui long sur un clavier de téléphone : sans ce repli,
/// `@mai` ne trouverait pas « Maïdaoua » et la personne serait, en pratique,
/// impossible à mentionner. `legacyMentionHandle` ne convient pas ici : il
/// SUPPRIME le caractère (`Maïdaoua` → `Madaoua`) au lieu de le replier.
String foldForMentionSearch(String value) {
  final buffer = StringBuffer();
  for (final unit in value.toLowerCase().split('')) {
    buffer.write(_foldings[unit] ?? unit);
  }
  return buffer.toString();
}

/// Latin-1 courant, plus les lettres haoussa / zarma / peul qu'on croise dans
/// les noms de la diaspora.
const Map<String, String> _foldings = {
  'à': 'a', 'á': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a',
  'ç': 'c',
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
  'ñ': 'n', 'ŋ': 'n', 'ɲ': 'n',
  'ò': 'o', 'ó': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o',
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
  'ý': 'y', 'ÿ': 'y', 'ƴ': 'y',
  'ɓ': 'b', 'ɗ': 'd', 'ƙ': 'k',
  'æ': 'ae', 'œ': 'oe', 'ß': 'ss',
};

/// La saisie [query] (ce qui suit le `@`) désigne-t-elle cette personne ?
///
/// On accepte le début du pseudo, mais aussi le début de **n'importe quel mot**
/// du nom affiché : personne ne tape `@IbrahimYacoubaMaïdaoua` en entier, on
/// tape `@mai`. Comparaison insensible à la casse et aux accents.
bool mentionQueryMatches({
  required String query,
  required String token,
  required String displayName,
}) {
  final needle = foldForMentionSearch(query.trim());
  if (needle.isEmpty) return true;
  if (foldForMentionSearch(token).startsWith(needle)) return true;

  for (final word in displayName.split(RegExp(r'[\s\-_.]+'))) {
    if (word.isEmpty) continue;
    if (foldForMentionSearch(word).startsWith(needle)) return true;
  }
  return false;
}
