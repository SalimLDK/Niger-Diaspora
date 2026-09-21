/**
 * Qui a le droit de supprimer une conversation POUR TOUS.
 *
 * **Pourquoi ce module existe.** `deleteConversationForEveryone` lisait son
 * autorisation dans un document **Firestore** `conversations/<id>` :
 * `createdBy` ou `adminIds`. Or la règle déployée dit
 *
 *   `allow create: if isAuthenticated()
 *                  && request.auth.uid in request.resource.data.participantIds;`
 *
 * et **plus rien n'alimente ces documents depuis la migration vers Supabase**.
 * N'importe quel compte pouvait donc créer `conversations/<id de son choix>`
 * avec lui-même en `participantIds` et en `createdBy`, puis appeler la
 * fonction. Celle-ci relisait ce document, se voyait confirmer que l'appelant
 * est le créateur, et supprimait :
 *
 *   · `messages/<id>` et `conversations/<id>` en base temps réel ;
 *   · **tout `messages/<id>/` dans Storage, par préfixe** — et c'est là que
 *     vivent les médias des conversations VIVANTES (`ImageUploadService`,
 *     `message_supabase_datasource.dart:1558,1927`).
 *
 * Il suffisait de connaître un identifiant de conversation — ce que garde
 * n'importe quel ancien membre — pour effacer ses photos, ses vidéos et ses
 * notes vocales. Le document Firestore n'était pas une preuve : c'était une
 * déclaration de l'attaquant sur lui-même.
 *
 * La vérité vit dans Supabase. On la lit là, et nulle part ailleurs.
 *
 * Module séparé pour être testable sans émulateur ni identifiants :
 * banc `tools/rules_tests/suppression_conversation.mjs`.
 */

/**
 * @typedef {object} Conversation
 * @property {string[]} participantIds
 * @property {string} createdBy
 * @property {string[]} adminIds
 */

/**
 * @param {Conversation|null} conversation telle que rendue par
 *   `getConversation` (Supabase). `null` = inconnue.
 * @param {string} userId l'appelant, pris dans le jeton — jamais dans la requête
 * @returns {{autorise: boolean, motif: string}} `motif` est destiné au
 *   journal et au message d'erreur : il dit POURQUOI, sans livrer la
 *   composition de la conversation.
 */
function peutSupprimerConversationPourTous(conversation, userId) {
    if (!userId) {
        return { autorise: false, motif: "appelant sans identité" };
    }
    if (!conversation) {
        // Inconnue de Supabase : soit elle n'existe pas, soit elle n'existe
        // QUE dans Firestore — c'est-à-dire qu'on vient de la fabriquer.
        return { autorise: false, motif: "conversation inconnue" };
    }

    const participants = Array.isArray(conversation.participantIds)
        ? conversation.participantIds
        : [];
    if (!participants.includes(userId)) {
        return { autorise: false, motif: "appelant non participant" };
    }

    const admins = Array.isArray(conversation.adminIds) ? conversation.adminIds : [];
    if (conversation.createdBy !== userId && !admins.includes(userId)) {
        return { autorise: false, motif: "ni créateur ni administrateur" };
    }

    return { autorise: true, motif: "créateur ou administrateur" };
}

module.exports = { peutSupprimerConversationPourTous };
