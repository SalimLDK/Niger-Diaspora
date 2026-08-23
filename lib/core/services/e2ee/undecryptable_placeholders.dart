/// Textes que la couche crypto pose à la place du contenu quand un
/// déchiffrement échoue, et la règle qui décide quoi garder à l'écran.
///
/// **Une seule source.** Cette liste vivait en trois exemplaires et a déjà
/// divergé : `_reconcileEcho` (message_provider) n'en connaissait qu'un des
/// deux. Conséquence, vue sur appareil le 2026-08-23 : le premier message
/// envoyé dans un groupe devenait illisible **par son propre auteur** une
/// seconde après l'envoi. La bulle optimiste affichait bien le texte clair,
/// puis l'écho temps réel arrivait avec `[🔐 E2EE — session requise]` — que le
/// filtre ne reconnaissait pas — et l'écrasait.
///
/// **Pourquoi l'expéditeur ne peut pas déchiffrer son propre message.** Ce
/// n'est pas un défaut : Signal (1:1) comme Sender Key (groupes) font avancer
/// le ratchet à l'émission et ne conservent pas la clé du message envoyé. Le
/// texte clair de nos propres messages n'existe que dans l'état local et dans
/// le cache — d'où l'importance de ne jamais l'écraser par un placeholder.
library;

/// Déchiffrement impossible faute de session Signal (1:1) ou de Sender Key
/// (groupe) sur cet appareil. Posé par `MessageCryptoService.decrypt`.
const String kE2EESessionRequiredPlaceholder = '[🔐 E2EE — session requise]';

/// Contenu chiffré qu'on refuse d'afficher brut (ancien format AES-GCM,
/// erreur de déchiffrement sur un message marqué `e2ee`).
const String kEncryptedMessagePlaceholder = '🔐 Message chiffré';

/// Tous les placeholders, pour les tests d'appartenance.
const Set<String> kUndecryptablePlaceholders = {
  kE2EESessionRequiredPlaceholder,
  kEncryptedMessagePlaceholder,
};

/// Vrai si [content] ne porte aucun texte lisible : vide, ou placeholder.
bool isUndecryptableContent(String content) =>
    content.isEmpty || kUndecryptablePlaceholders.contains(content);

/// Contenu à conserver quand l'écho temps réel d'un message qu'on vient
/// d'envoyer revient du serveur.
///
/// Le serveur ne peut pas nous rendre notre propre texte (voir l'en-tête) :
/// s'il revient illisible et qu'on a mieux en local, on garde le local.
String reconcileEchoContent({
  required String local,
  required String incoming,
}) =>
    isUndecryptableContent(incoming) && local.isNotEmpty ? local : incoming;
