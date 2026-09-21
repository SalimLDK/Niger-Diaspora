// =============================================================================
// Appels 1:1 — ce que `onCallCreated` et `onCallUpdated` envoient.
//
// Fonctions PURES (ni Firestore, ni réseau) : testées par
// tools/rules_tests/appel_entrant.mjs.
//
// ── Pourquoi ce module existe (2026-09-21) ────────────────────────────────
//
// `onCallCreated` envoie un push `incoming_call` : c'est lui qui fait sonner le
// téléphone et ouvre l'écran d'appel NATIF, plein écran, même app fermée. Il
// prenait le nom et la photo de l'appelant DANS le document `calls/<id>`, que
// le client écrit. La règle Firestore n'impose que `callerId == auth.uid` :
// l'identifiant de l'appelant ne se falsifie pas, mais son NOM et sa PHOTO,
// si. N'importe quel compte pouvait donc faire sonner n'importe qui sous le
// nom et le visage d'un proche, ou de « Service Sécurité ».
//
// Et rien ne vérifiait le blocage : un compte bloqué pouvait continuer à faire
// sonner celui qui l'avait bloqué.
//
// Le nom et la photo viennent désormais de Supabase (`users`), le blocage est
// respecté, et les identifiants sont vérifiés avant toute requête — ils
// partent tels quels dans une URL PostgREST (`getUsersForPush`), où un `&` ou
// une parenthèse réécrirait le filtre.
// =============================================================================

/** Forme d'un uid Firebase (celle des `users.id`). */
const FORME_UID = /^[A-Za-z0-9_-]{1,128}$/;

function uidValide(id) {
  return typeof id === "string" && FORME_UID.test(id);
}

/**
 * Le push d'un appel entrant, ou `{ rien: true, motif }` s'il ne faut RIEN
 * envoyer — le motif part dans les journaux.
 *
 * @param {{
 *   callId: string,
 *   callData: Object,             // le document `calls/<id>`, tel qu'écrit par le client
 *   utilisateurs: Map<string, {displayName:string, avatarUrl:string, fcmTokens:string[]}>,
 *   bloque: boolean,              // l'appelé a-t-il bloqué l'appelant ?
 * }} e
 * @returns {{rien:true, motif:string} | {tokens:string[], data:Object<string,string>, apns:Object}}
 */
function preparerAppelEntrant(e) {
  const d = e.callData || {};
  if (d.status !== "ringing") return { rien: true, motif: "statut" };

  const appelantId = d.callerId;
  const appeleId = d.calleeId;
  if (!uidValide(appelantId) || !uidValide(appeleId)) {
    return { rien: true, motif: "identifiant invalide" };
  }
  if (appelantId === appeleId) return { rien: true, motif: "appel à soi-même" };
  if (e.bloque) return { rien: true, motif: "bloqué" };

  const appele = e.utilisateurs.get(appeleId);
  if (!appele || appele.fcmTokens.length === 0) {
    return { rien: true, motif: "aucun jeton" };
  }

  // L'IDENTITÉ AFFICHÉE VIENT DE LA BASE, jamais du document. Un appelant
  // inconnu de Supabase sonne sous un libellé neutre, pas sous le nom qu'il
  // s'est donné.
  const appelant = e.utilisateurs.get(appelantId);
  const nom = (appelant && appelant.displayName.trim()) || "Quelqu'un";
  const photo = (appelant && appelant.avatarUrl) || "";
  // Ce qui n'est ni « video » ni « audio » repart en « audio ».
  const type = d.type === "video" ? "video" : "audio";

  const data = {
    type: "incoming_call",
    callId: String(e.callId),
    callerId: appelantId,
    callerName: nom,
    callerPhotoUrl: photo,
    callType: type,
    title: nom,
    body: type === "video" ? "Appel vidéo entrant..." : "Appel vocal entrant...",
    click_action: "FLUTTER_NOTIFICATION_CLICK",
    timestamp: String(Date.now()),
  };

  return {
    tokens: appele.fcmTokens,
    data,
    // Données propres à iOS : les mêmes, jamais d'autres.
    apns: {
      callId: data.callId,
      callerId: data.callerId,
      callerName: data.callerName,
      callerPhotoUrl: data.callerPhotoUrl,
      callType: data.callType,
    },
  };
}

/**
 * Le nom de l'appelé à citer dans « X a refusé votre appel », lu en base.
 *
 * `onCallUpdated` le prenait dans le document (`calleeName`), que l'APPELANT
 * écrit à la création : il pouvait donc se faire annoncer n'importe quoi. Sans
 * gravité — c'est à lui-même —, mais la base connaît le vrai nom.
 */
function nomAppele(utilisateurs, appeleId) {
  const u = uidValide(appeleId) ? utilisateurs.get(appeleId) : null;
  return (u && u.displayName.trim()) || "L'utilisateur";
}

module.exports = { preparerAppelEntrant, nomAppele, uidValide };
