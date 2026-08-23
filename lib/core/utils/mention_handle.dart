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
