/**
 * Registre unique du rôle admin : la logique de la callable `setAdminRole`.
 *
 * **Pourquoi ce module existe.** Jusqu'au 2026-10-14, le rôle admin vivait
 * dans trois registres sans maître — Firestore `users/{uid}.adminRole`,
 * Postgres `users.is_admin` / `users.admin_role`, RTDB `/admins/{uid}` —
 * reliés par une seule écriture CLIENTE *best-effort*
 * (`role_management_provider.dart`, `_syncRoleToBackends`). Mesuré en
 * production : un compte avec `is_admin = true` sans `admin_role`, donc tous
 * les pouvoirs RLS et invisible comme admin dans l'app
 * (docs/deploiement/AUDIT_ADMIN_2026-10-14.md, § 2).
 *
 * Désormais **Postgres `users.admin_role` est la source**, et ce module est
 * le seul chemin qui l'écrit depuis l'application. À chaque appel il pose les
 * trois dérivés dans le même ordre :
 *
 *   1. Postgres `is_admin` ET `admin_role` (les deux, toujours ensemble — c'est
 *      leur divergence qui a produit l'admin fantôme) ;
 *   2. le custom claim Firebase `{ adminRole }` — c'est lui que lisent les
 *      règles Firestore/RTDB et le panneau, plus aucun document Firestore ;
 *   3. RTDB `/admins/{uid}`, conservé pour les lecteurs qui n'ont pas encore
 *      basculé sur le claim.
 *
 * puis journalise dans Supabase `admin_audit_logs` par la clé de service —
 * l'ancien journal était écrit par le client, refusé en silence des deux
 * côtés (Firestore `allow write: if false`, Postgres RLS sans policy).
 *
 * **Ce que la fonction refuse**, et pourquoi dans cet ordre :
 *   - un appelant qui n'est pas superAdmin DANS POSTGRES (`is_admin AND
 *     admin_role = 'superAdmin'`, même test que `is_super_admin()`). Pas le
 *     claim : le premier superAdmin est amorcé par script et n'a de claim que
 *     si l'amorçage l'a posé — Postgres est la vérité, le claim un dérivé ;
 *   - sa propre ligne, même pour un superAdmin : même règle que le
 *     déclencheur `users_guard_admin_flags`, qui empêche l'auto-promotion
 *     comme l'auto-rétrogradation accidentelle ;
 *   - un changement qui laisserait ZÉRO superAdmin. Avec un appelant
 *     superAdmin qui ne peut pas se viser lui-même, ce cas ne survient que par
 *     une course (deux superAdmins qui se rétrogradent l'un l'autre en même
 *     temps) ou un état déjà incohérent : la garde compte dans Postgres au
 *     moment de l'appel, sans verrou — elle réduit la fenêtre, elle ne la
 *     ferme pas. La fermer exigerait une RPC avec `SELECT … FOR UPDATE`.
 *
 * **Ce qui se passe si une étape échoue.** Postgres est écrit en premier :
 * s'il refuse, rien d'autre n'a bougé. Si le claim échoue ensuite, Postgres
 * est REMIS à sa valeur d'avant avant de lever — un rôle présent dans la
 * base mais absent du jeton serait exactement l'incohérence qu'on supprime.
 * Si RTDB échoue après le claim, on lève `internal` en le disant : Postgres
 * et claim sont cohérents entre eux, et rappeler la fonction avec les mêmes
 * arguments rejoue les trois écritures (elle est idempotente).
 *
 * Module séparé d'`index.js` pour être testable sans émulateur ni
 * identifiants : les accès (Postgres, Auth, RTDB, journal) sont INJECTÉS.
 * Banc : `functions/test/roles_admin.test.js` (`npm test` dans `functions/`).
 */

/** Les quatre rôles de l'application (`lib/features/admin/domain/enums/admin_enums.dart`). */
const ROLES_ADMIN = Object.freeze([
  "superAdmin",
  "contentMod",
  "businessMod",
  "financeMod",
]);

/** Même forme que `appels.js` et `supabase.js` : uid Firebase ou id hérité. */
const FORME_UID = /^[A-Za-z0-9_-]{1,128}$/;

/**
 * Normalise la valeur reçue du client.
 *
 * `null`, `""`, `undefined` et `"none"` (le nom de `AdminRole.none` côté
 * Dart) signifient tous « révoquer ». Tout le reste doit être l'un des quatre
 * rôles, tel quel — pas de casse tolérée, pas d'alias : le client envoie
 * `AdminRole.name`.
 *
 * @param {unknown} valeur
 * @returns {{ok: boolean, role: string|null}}
 */
function normaliserRole(valeur) {
  if (valeur === undefined || valeur === null || valeur === "" || valeur === "none") {
    return { ok: true, role: null };
  }
  if (typeof valeur === "string" && ROLES_ADMIN.includes(valeur)) {
    return { ok: true, role: valeur };
  }
  return { ok: false, role: null };
}

/** Même test que `is_super_admin()` côté Postgres : les DEUX colonnes. */
function estSuperAdmin(compte) {
  return Boolean(compte && compte.isAdmin === true && compte.adminRole === "superAdmin");
}

/**
 * Nom de l'action dans `admin_audit_logs`. `assign_role` et `change_role`
 * sont les noms que le panneau écrivait déjà ; `revoke_role` et `sync_role`
 * (rôle inchangé, dérivés reposés) sont nouveaux.
 */
function actionJournal(avant, apres) {
  if (avant === apres) return "sync_role";
  if (!avant) return "assign_role";
  if (!apres) return "revoke_role";
  return "change_role";
}

/**
 * @typedef {object} CompteAdmin
 * @property {string} id
 * @property {string|null} email
 * @property {string|null} displayName
 * @property {boolean} isAdmin
 * @property {string|null} adminRole
 */

/**
 * @typedef {object} DependancesSetAdminRole
 * @property {new (code: string, message: string) => Error} HttpsError
 *   `functions.https.HttpsError` — injecté pour que le module ne dépende pas
 *   de `firebase-functions`.
 * @property {(uid: string) => Promise<CompteAdmin|null>} lireCompte
 *   Postgres, par la clé de service. `null` = ligne absente. Lève si la base
 *   n'a pas répondu — jamais `null` dans ce cas, le doute n'est pas un refus
 *   de rôle.
 * @property {() => Promise<number>} compterSuperAdmins
 * @property {(uid: string, role: string|null) => Promise<boolean>} ecrireRoleAdmin
 *   Pose `is_admin = (role != null)` ET `admin_role = role`. Faux si aucune
 *   ligne n'a été touchée.
 * @property {(uid: string, role: string|null) => Promise<void>} poserClaim
 *   `setCustomUserClaims(uid, role ? {adminRole: role} : null)`.
 * @property {(uid: string, present: boolean) => Promise<void>} ecrireAdminsRtdb
 *   `/admins/{uid} = true` ou retrait du nœud.
 * @property {(entree: object) => Promise<boolean>} journaliser
 *   Insertion dans `admin_audit_logs`. Faux si refusée ; ne lève pas.
 */

/**
 * Le corps de la callable. `data` et `context` sont ceux de
 * `functions.https.onCall` (API v1).
 *
 * @param {{uid?: unknown, adminRole?: unknown}} data
 * @param {{auth?: {uid: string, token?: object}}} context
 * @param {DependancesSetAdminRole} deps
 * @returns {Promise<{uid: string, previousRole: string, adminRole: string,
 *   action: string, journalise: boolean}>}
 */
async function executerSetAdminRole(data, context, deps) {
  const { HttpsError } = deps;

  if (!context || !context.auth || !context.auth.uid) {
    throw new HttpsError("unauthenticated", "Authentification requise");
  }
  const appelantUid = context.auth.uid;

  const uid = data && data.uid;
  if (typeof uid !== "string" || !FORME_UID.test(uid)) {
    throw new HttpsError("invalid-argument", "uid requis (identifiant de compte)");
  }
  const { ok: roleValide, role } = normaliserRole(data.adminRole);
  if (!roleValide) {
    throw new HttpsError(
      "invalid-argument",
      `adminRole doit être l'un de ${ROLES_ADMIN.join(", ")}, ou none`,
    );
  }

  // Avant même de lire la base : la règle ne dépend de rien d'autre, et un
  // superAdmin qui se vise lui-même ne doit pas apprendre au passage s'il
  // l'est encore.
  if (uid === appelantUid) {
    throw new HttpsError(
      "permission-denied",
      "Modification de ses propres droits admin interdite",
    );
  }

  let appelant;
  let cible;
  try {
    [appelant, cible] = await Promise.all([
      deps.lireCompte(appelantUid),
      deps.lireCompte(uid),
    ]);
  } catch (e) {
    console.error(`[setAdminRole] Postgres injoignable : ${e && e.message}`);
    throw new HttpsError("unavailable", "Base de données injoignable");
  }

  if (!estSuperAdmin(appelant)) {
    console.warn(`[setAdminRole] refusé : ${appelantUid} n'est pas superAdmin`);
    throw new HttpsError(
      "permission-denied",
      "Seul un superAdmin peut modifier les droits admin",
    );
  }
  if (!cible) {
    throw new HttpsError("not-found", "Compte introuvable");
  }

  const roleAvant = cible.adminRole || null;

  // Garde « dernier superAdmin ». Voir l'en-tête : réduit la fenêtre de
  // course, ne la ferme pas.
  if (roleAvant === "superAdmin" && role !== "superAdmin") {
    let n;
    try {
      n = await deps.compterSuperAdmins();
    } catch (e) {
      console.error(`[setAdminRole] comptage impossible : ${e && e.message}`);
      throw new HttpsError("unavailable", "Base de données injoignable");
    }
    if (n - 1 < 1) {
      throw new HttpsError(
        "failed-precondition",
        "Impossible de retirer le dernier superAdmin",
      );
    }
  }

  // 1. Postgres — la source. Rien d'autre n'a bougé s'il refuse.
  let ecrit;
  try {
    ecrit = await deps.ecrireRoleAdmin(uid, role);
  } catch (e) {
    console.error(`[setAdminRole] écriture Postgres : ${e && e.message}`);
    throw new HttpsError("internal", "Écriture du rôle refusée par la base");
  }
  if (!ecrit) {
    throw new HttpsError("not-found", "Compte introuvable");
  }

  // 2. Le claim — ce que lisent les règles et le panneau.
  try {
    await deps.poserClaim(uid, role);
  } catch (e) {
    console.error(`[setAdminRole] claim : ${e && e.message}`);
    let remis = false;
    try {
      remis = await deps.ecrireRoleAdmin(uid, roleAvant);
    } catch (e2) {
      console.error(`[setAdminRole] remise de Postgres impossible : ${e2 && e2.message}`);
    }
    throw new HttpsError(
      "internal",
      remis
        ? "Jeton non mis à jour ; le rôle n'a pas été modifié"
        : "Jeton non mis à jour ET base laissée modifiée : relancer l'appel",
    );
  }

  // 3. RTDB — dérivé secondaire. Postgres et claim sont cohérents ici.
  try {
    await deps.ecrireAdminsRtdb(uid, role !== null);
  } catch (e) {
    console.error(`[setAdminRole] RTDB : ${e && e.message}`);
    throw new HttpsError(
      "internal",
      "Rôle posé (base et jeton) mais non propagé à la Realtime Database : relancer l'appel",
    );
  }

  const action = actionJournal(roleAvant, role);
  const journalise = await deps.journaliser({
    adminId: appelantUid,
    adminName: appelant.displayName || appelant.email || null,
    action,
    targetType: "user",
    targetId: uid,
    details: {
      previousRole: roleAvant || "none",
      newRole: role || "none",
      targetEmail: cible.email || null,
      targetName: cible.displayName || null,
    },
  });
  if (!journalise) {
    console.error(`[setAdminRole] ${action} ${uid} par ${appelantUid} NON journalisé`);
  }

  return {
    uid,
    previousRole: roleAvant || "none",
    adminRole: role || "none",
    action,
    journalise,
  };
}

/**
 * Fabrique la callable à partir du module `firebase-functions` (v1) et des
 * dépendances réelles. `index.js` l'appelle une fois ; le banc l'appelle avec
 * des doublures pour vérifier le câblage `context.auth` à travers
 * `firebase-functions-test`.
 *
 * @param {typeof import("firebase-functions")} functions
 * @param {Omit<DependancesSetAdminRole, "HttpsError">} deps
 */
function creerCallableSetAdminRole(functions, deps) {
  const complet = Object.assign({ HttpsError: functions.https.HttpsError }, deps);
  return functions.https.onCall((data, context) =>
    executerSetAdminRole(data, context, complet),
  );
}

module.exports = {
  ROLES_ADMIN,
  normaliserRole,
  estSuperAdmin,
  actionJournal,
  executerSetAdminRole,
  creerCallableSetAdminRole,
};
