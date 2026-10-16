/**
 * Bannissement appliqué par le serveur : la logique de la callable
 * `setUserBanned`.
 *
 * **Pourquoi ce module existe.** Jusqu'au 2026-10-14, bannir était une
 * écriture CLIENTE dans Postgres (`is_banned` + une sentinelle `session_id`)
 * que l'app relisait pour s'éjecter elle-même. Rien côté Firebase ne le
 * savait : aucune règle ne lit `isBanned`, aucun `updateUser({disabled})`,
 * aucun `revokeRefreshTokens`. Un client modifié, ou un ancien APK, gardait
 * un jeton valide et continuait d'écrire dans RTDB, Storage et Firestore
 * (docs/deploiement/AUDIT_ADMIN_2026-10-14.md, § 6.1 et § 7.2).
 *
 * Pourquoi une callable et pas un déclencheur Firestore : le bannissement vit
 * dans Postgres, aucun document Firestore ne bouge quand on bannit — un
 * déclencheur Firestore ne se réveillerait jamais. Et un webhook pg_net sur
 * `users` exigerait un secret partagé de plus ; la callable, elle, porte
 * l'identité de l'appelant dans son jeton.
 *
 * Ce que la fonction fait, dans cet ordre :
 *   1. Postgres : `is_banned`, `ban_reason`, `banned_at`, `banned_by`, et la
 *      sentinelle `session_id` (`banned_<ms>`, préfixe lu par
 *      `SessionService.prefixeBanni`) — ce que le client écrivait, plus
 *      `banned_by` que la colonne attendait sans que personne ne la remplisse.
 *      C'est ce que les builds déjà installés savent lire : ils s'éjectent
 *      comme avant ;
 *   2. Firebase Auth : `updateUser(uid, { disabled })` — plus aucune
 *      connexion possible ; puis, au bannissement, `revokeRefreshTokens` —
 *      le jeton courant expire sans pouvoir être renouvelé (≤ 1 h). Les
 *      règles n'ont rien à lire : un compte désactivé n'obtient plus de jeton.
 *   3. journal `admin_audit_logs` par la clé de service.
 *
 * Si Postgres refuse, rien d'autre n'a bougé. Si Firebase Auth échoue après
 * Postgres, on lève `internal` en le disant : au bannissement, le compte est
 * déjà éjecté par la sentinelle (comme avant) et rappeler la fonction finit
 * le travail ; au débannissement, le compte reste désactivé jusqu'au rappel.
 * Dans les deux cas l'appel est idempotent.
 *
 * Qui peut bannir : un admin dont le rôle porte `banUsers` côté client
 * (`role_permissions.dart` : superAdmin et contentMod) — vérifié DANS
 * POSTGRES, comme pour `setAdminRole`. Jamais soi-même, jamais un
 * superAdmin, et un contentMod ne bannit pas un autre admin : lui retirer
 * son rôle d'abord, par `setAdminRole`.
 *
 * Banc : `functions/test/bannissement.test.js` (`npm test` dans `functions/`).
 */

const { estSuperAdmin } = require("./roles_admin");

/** Rôles qui portent `AdminPermission.banUsers` (role_permissions.dart). */
const ROLES_QUI_BANNISSENT = Object.freeze(["superAdmin", "contentMod"]);

/** Même préfixe que `SessionService.prefixeBanni` (lib/core/services/session_service.dart). */
const PREFIXE_SESSION_BANNIE = "banned_";

const FORME_UID = /^[A-Za-z0-9_-]{1,128}$/;
const LONGUEUR_MAX_MOTIF = 500;

/**
 * @typedef {object} CompteBan
 * @property {string} id
 * @property {string|null} email
 * @property {string|null} displayName
 * @property {boolean} isAdmin
 * @property {string|null} adminRole
 * @property {boolean} isBanned
 */

/**
 * @typedef {object} DependancesSetUserBanned
 * @property {new (code: string, message: string) => Error} HttpsError
 * @property {(uid: string) => Promise<CompteBan|null>} lireCompte
 *   Postgres par la clé de service ; `null` = absent ; lève si injoignable.
 * @property {(uid: string, etat: {banned: boolean, reason: string|null,
 *   by: string|null, sessionId: string|null}) => Promise<boolean>} ecrireBan
 *   Faux si aucune ligne touchée.
 * @property {(uid: string, disabled: boolean) => Promise<void>} desactiverCompte
 * @property {(uid: string) => Promise<void>} revoquerJetons
 * @property {(entree: object) => Promise<boolean>} journaliser
 * @property {() => number} [maintenant] horloge, injectable pour le banc
 */

/**
 * @param {{uid?: unknown, banned?: unknown, reason?: unknown}} data
 * @param {{auth?: {uid: string}}} context
 * @param {DependancesSetUserBanned} deps
 * @returns {Promise<{uid: string, banned: boolean, action: string, journalise: boolean}>}
 */
async function executerSetUserBanned(data, context, deps) {
  const { HttpsError } = deps;
  const maintenant = deps.maintenant || Date.now;

  if (!context || !context.auth || !context.auth.uid) {
    throw new HttpsError("unauthenticated", "Authentification requise");
  }
  const appelantUid = context.auth.uid;

  const uid = data && data.uid;
  if (typeof uid !== "string" || !FORME_UID.test(uid)) {
    throw new HttpsError("invalid-argument", "uid requis (identifiant de compte)");
  }
  if (!data || typeof data.banned !== "boolean") {
    throw new HttpsError("invalid-argument", "banned (booléen) requis");
  }
  const banned = data.banned;
  let reason = null;
  if (banned) {
    reason = typeof data.reason === "string" ? data.reason.trim() : "";
    if (reason.length === 0) {
      throw new HttpsError("invalid-argument", "reason requis pour bannir");
    }
    if (reason.length > LONGUEUR_MAX_MOTIF) {
      throw new HttpsError("invalid-argument", `reason : ${LONGUEUR_MAX_MOTIF} caractères au plus`);
    }
  }

  if (uid === appelantUid) {
    throw new HttpsError("permission-denied", "Impossible de se bannir soi-même");
  }

  let appelant;
  let cible;
  try {
    [appelant, cible] = await Promise.all([deps.lireCompte(appelantUid), deps.lireCompte(uid)]);
  } catch (e) {
    console.error(`[setUserBanned] Postgres injoignable : ${e && e.message}`);
    throw new HttpsError("unavailable", "Base de données injoignable");
  }

  const roleAppelant = appelant && appelant.isAdmin === true ? appelant.adminRole : null;
  if (!roleAppelant || !ROLES_QUI_BANNISSENT.includes(roleAppelant)) {
    console.warn(`[setUserBanned] refusé : ${appelantUid} (${roleAppelant || "aucun rôle"})`);
    throw new HttpsError("permission-denied", "Rôle insuffisant pour bannir");
  }
  if (!cible) {
    throw new HttpsError("not-found", "Compte introuvable");
  }
  if (estSuperAdmin(cible)) {
    throw new HttpsError("permission-denied", "Un superAdmin ne se bannit pas : lui retirer son rôle d'abord");
  }
  if (cible.isAdmin === true && !estSuperAdmin(appelant)) {
    throw new HttpsError("permission-denied", "Seul un superAdmin peut bannir un administrateur");
  }

  // 1. Postgres — ce que les builds installés lisent pour s'éjecter.
  const etat = banned
    ? {
        banned: true,
        reason,
        by: appelantUid,
        sessionId: `${PREFIXE_SESSION_BANNIE}${maintenant()}`,
      }
    : { banned: false, reason: null, by: null, sessionId: null };
  let ecrit;
  try {
    ecrit = await deps.ecrireBan(uid, etat);
  } catch (e) {
    console.error(`[setUserBanned] écriture Postgres : ${e && e.message}`);
    throw new HttpsError("internal", "Écriture refusée par la base");
  }
  if (!ecrit) {
    throw new HttpsError("not-found", "Compte introuvable");
  }

  // 2. Firebase Auth — plus de connexion, plus de renouvellement de jeton.
  try {
    await deps.desactiverCompte(uid, banned);
    if (banned) await deps.revoquerJetons(uid);
  } catch (e) {
    console.error(`[setUserBanned] Firebase Auth : ${e && e.message}`);
    throw new HttpsError(
      "internal",
      banned
        ? "Compte banni en base (éjecté) mais pas encore désactivé côté Firebase : relancer l'appel"
        : "Compte débanni en base mais toujours désactivé côté Firebase : relancer l'appel",
    );
  }

  const action = banned ? "ban_user" : "unban_user";
  const journalise = await deps.journaliser({
    adminId: appelantUid,
    adminName: appelant.displayName || appelant.email || null,
    action,
    targetType: "user",
    targetId: uid,
    details: {
      reason,
      targetEmail: cible.email || null,
      targetName: cible.displayName || null,
      wasBanned: cible.isBanned === true,
    },
  });
  if (!journalise) {
    console.error(`[setUserBanned] ${action} ${uid} par ${appelantUid} NON journalisé`);
  }

  return { uid, banned, action, journalise };
}

/**
 * @param {typeof import("firebase-functions")} functions
 * @param {Omit<DependancesSetUserBanned, "HttpsError">} deps
 */
function creerCallableSetUserBanned(functions, deps) {
  const complet = Object.assign({ HttpsError: functions.https.HttpsError }, deps);
  return functions.https.onCall((data, context) =>
    executerSetUserBanned(data, context, complet),
  );
}

module.exports = {
  ROLES_QUI_BANNISSENT,
  PREFIXE_SESSION_BANNIE,
  executerSetUserBanned,
  creerCallableSetUserBanned,
};
