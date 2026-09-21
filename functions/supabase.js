// =============================================================================
// Accès Supabase pour les Cloud Functions (lecture/nettoyage des tokens FCM).
//
// Contexte : l'app enregistre les tokens FCM dans Supabase (users.fcm_tokens),
// PAS dans Firestore. Les Cloud Functions historiques lisaient pourtant les
// tokens dans Firestore (users/{id}.fcmTokens) → toujours vides → aucun push
// (appels dans le vide, notifs de message off-app muettes, etc.).
//
// Ce helper lit/écrit les tokens directement via l'API REST Supabase (PostgREST),
// sans embarquer le SDK @supabase/supabase-js (fetch natif de Node 22).
//
// Config requise (env des Cloud Functions — noms libres, pas la contrainte
// SUPABASE_ des secrets Edge) :
//   SUPABASE_URL         = https://<ref>.supabase.co
//   SUPABASE_SERVICE_KEY = clé secrète service_role (accès serveur, RLS bypass)
// La clé n'est JAMAIS renvoyée au client ; elle vit uniquement ici, côté serveur.
// =============================================================================

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY;

function isConfigured() {
  return Boolean(SUPABASE_URL && SUPABASE_SERVICE_KEY);
}

function authHeaders(extra) {
  return Object.assign(
    {
      apikey: SUPABASE_SERVICE_KEY,
      Authorization: `Bearer ${SUPABASE_SERVICE_KEY}`,
    },
    extra || {},
  );
}

/**
 * Récupère les tokens FCM d'un utilisateur depuis Supabase.
 * @param {string} userId Firebase UID (users.id TEXT)
 * @returns {Promise<string[]>} liste de tokens (vide si aucun / non configuré)
 */
async function getFcmTokens(userId) {
  if (!isConfigured()) {
    console.error("Supabase non configuré (SUPABASE_URL / SUPABASE_SERVICE_KEY)");
    return [];
  }
  const url =
    `${SUPABASE_URL}/rest/v1/users` +
    `?id=eq.${encodeURIComponent(userId)}&select=fcm_tokens`;
  const res = await fetch(url, { headers: authHeaders() });
  if (!res.ok) {
    console.error(`Supabase getFcmTokens ${res.status}: ${await res.text()}`);
    return [];
  }
  const rows = await res.json();
  const tokens = rows && rows[0] && rows[0].fcm_tokens;
  return Array.isArray(tokens) ? tokens.filter(Boolean) : [];
}

/**
 * Retire des tokens morts (invalides / désenregistrés) de users.fcm_tokens.
 * @param {string} userId
 * @param {string[]} deadTokens
 */
async function removeFcmTokens(userId, deadTokens) {
  if (!deadTokens || deadTokens.length === 0) return;
  if (!isConfigured()) return;
  // Lire l'état courant puis réécrire filtré (pas d'opérateur array-remove en
  // PostgREST ; la fenêtre de course est négligeable pour un simple nettoyage).
  const current = await getFcmTokens(userId);
  const remaining = current.filter((t) => !deadTokens.includes(t));
  if (remaining.length === current.length) return;
  const url = `${SUPABASE_URL}/rest/v1/users?id=eq.${encodeURIComponent(userId)}`;
  const res = await fetch(url, {
    method: "PATCH",
    headers: authHeaders({
      "Content-Type": "application/json",
      Prefer: "return=minimal",
    }),
    body: JSON.stringify({ fcm_tokens: remaining }),
  });
  if (!res.ok) {
    console.error(`Supabase removeFcmTokens ${res.status}: ${await res.text()}`);
  }
}

/**
 * Récupère une conversation Supabase (métadonnées de notification).
 * @param {string} conversationId
 * @returns {Promise<null|{id,type,participantIds:string[],groupId:string,name:string,imageUrl:string,mutedBy:object}>}
 */
async function getConversation(conversationId) {
  if (!isConfigured()) return null;
  const url =
    `${SUPABASE_URL}/rest/v1/conversations` +
    `?id=eq.${encodeURIComponent(conversationId)}` +
    `&select=id,type,participant_ids,group_id,created_by,data`;
  const res = await fetch(url, { headers: authHeaders() });
  if (!res.ok) {
    console.error(`Supabase getConversation ${res.status}: ${await res.text()}`);
    return null;
  }
  const rows = await res.json();
  const row = rows && rows[0];
  if (!row) return null;
  const data = row.data || {};
  return {
    id: row.id,
    type: row.type || "individual",
    participantIds: Array.isArray(row.participant_ids) ? row.participant_ids : [],
    groupId: row.group_id || "",
    // `created_by` et `data.adminIds` servent à `deleteConversationForEveryone`,
    // qui lisait son autorisation dans un document Firestore que n'importe qui
    // pouvait créer. Ils viennent d'ici parce que c'est ici que vit la
    // conversation depuis la migration.
    createdBy: row.created_by || "",
    adminIds: Array.isArray(data.adminIds) ? data.adminIds : [],
    name: data.name || "",
    imageUrl: data.image_url || "",
    mutedBy: data.muted_by || {},
  };
}

/**
 * Récupère, en une requête, les infos push de plusieurs utilisateurs.
 * @param {string[]} userIds
 * @returns {Promise<Map<string,{displayName,avatarUrl,fcmTokens:string[],notificationsEnabled:boolean,showMessagePreview:boolean}>>}
 */
async function getUsersForPush(userIds) {
  const map = new Map();
  if (!isConfigured() || !userIds || userIds.length === 0) return map;
  const uniq = [...new Set(userIds.filter(Boolean))];
  if (uniq.length === 0) return map;
  // Les Firebase UID sont alphanumériques → sûrs dans une in-list PostgREST.
  const inList = uniq.map((id) => `"${id}"`).join(",");
  const url =
    `${SUPABASE_URL}/rest/v1/users?id=in.(${inList})` +
    `&select=id,display_name,avatar_url,fcm_tokens,notifications_enabled,show_message_preview`;
  const res = await fetch(url, { headers: authHeaders() });
  if (!res.ok) {
    console.error(`Supabase getUsersForPush ${res.status}: ${await res.text()}`);
    return map;
  }
  const rows = await res.json();
  for (const row of rows) {
    map.set(row.id, {
      displayName: row.display_name || "",
      avatarUrl: row.avatar_url || "",
      fcmTokens: Array.isArray(row.fcm_tokens) ? row.fcm_tokens.filter(Boolean) : [],
      // Défaut permissif (comme l'ancien code Firestore : !== false).
      notificationsEnabled: row.notifications_enabled !== false,
      showMessagePreview: row.show_message_preview !== false,
    });
  }
  return map;
}

/**
 * Crée une ligne `notifications` dans Supabase.
 *
 * Les fonctions planifiées de rappel écrivaient dans la collection **Firestore**
 * `notifications`, que plus personne ne lit depuis que l'app a basculé sur
 * Supabase : les rappels d'événement, de salon audio et de transfert étaient
 * donc muets, sans la moindre erreur. Écrire ici rebranche tout le reste de la
 * chaîne — l'INSERT déclenche `trg_notify_push` → Edge Function send-push → FCM.
 *
 * Accepte la forme Firestore historique pour que les appelants ne changent que
 * d'appel : `{ userId, title, body, type, targetId, data, isRead }`.
 * `targetId` part dans la colonne `data` (il n'y a pas de colonne dédiée), et
 * `createdAt` est ignoré — c'est Postgres qui date la ligne.
 *
 * @param {{userId:string,title:string,body:string,type:string,targetId?:string,
 *          data?:Object,isRead?:boolean}} doc
 * @returns {Promise<boolean>} vrai si la ligne est créée
 */
async function createNotification(doc) {
  if (!isConfigured()) {
    console.error("Supabase non configuré : notification non créée");
    return false;
  }
  if (!doc || !doc.userId || !doc.type) {
    console.error("createNotification : userId et type sont requis");
    return false;
  }

  const data = Object.assign({}, doc.data || {});
  if (doc.targetId && data.targetId === undefined) {
    data.targetId = doc.targetId;
  }
  if (data.type === undefined) {
    data.type = doc.type;
  }

  const res = await fetch(`${SUPABASE_URL}/rest/v1/notifications`, {
    method: "POST",
    headers: authHeaders({
      "Content-Type": "application/json",
      Prefer: "return=minimal",
    }),
    body: JSON.stringify({
      user_id: doc.userId,
      type: doc.type,
      title: doc.title || "Diaspo Niger",
      body: doc.body || "",
      data,
      is_read: doc.isRead === true,
    }),
  });

  if (!res.ok) {
    console.error(`Supabase createNotification ${res.status}: ${await res.text()}`);
    return false;
  }
  return true;
}

/**
 * Destinataires d'un événement local : les profils situés à moins de
 * [radiusKm] du point donné et qui acceptent ces notifications.
 *
 * L'ancienne sélection comparait `users.city` à la ville de l'événement, dans
 * **Firestore**. Double impasse : les profils vivent dans Supabase, et `city`
 * y est vide pour tout le monde. La latitude/longitude, elle, est publiée par
 * la carte « membres autour ».
 *
 * Le filtrage (préférences comprises) est fait par le RPC `users_near_point`,
 * pour ne pas rapatrier la table.
 *
 * @param {number} lat
 * @param {number} lng
 * @param {number} radiusKm
 * @returns {Promise<string[]>} identifiants des destinataires
 */
async function getLocalEventRecipients(lat, lng, radiusKm = 50) {
  if (!isConfigured()) {
    console.error("Supabase non configuré : pas de destinataires locaux");
    return [];
  }
  if (typeof lat !== "number" || typeof lng !== "number") return [];

  const res = await fetch(`${SUPABASE_URL}/rest/v1/rpc/users_near_point`, {
    method: "POST",
    headers: authHeaders({ "Content-Type": "application/json" }),
    body: JSON.stringify({ p_lat: lat, p_lng: lng, p_radius_km: radiusKm }),
  });
  if (!res.ok) {
    console.error(`Supabase users_near_point ${res.status}: ${await res.text()}`);
    return [];
  }
  const rows = await res.json();
  return Array.isArray(rows) ? rows.map((r) => r.id).filter(Boolean) : [];
}

/**
 * Reflète une amitié Firestore dans `public.friends`.
 *
 * Les amitiés vivent dans Firestore (`users/{uid}/friends/{friendId}`), mais
 * c'est Postgres qui décide qui lit une publication ou une story « Amis »
 * (`peut_voir_publication`, `peut_voir_story`, migration 20260912230000). Sans
 * miroir, la table `friends` restait vide et une audience « Amis » ne
 * laissait passer personne.
 *
 * Le miroir est tenu ICI, côté serveur, et pas par l'app : un client qui
 * écrirait lui-même dans `friends` pourrait se déclarer ami de n'importe qui
 * et lire ses publications réservées.
 *
 * @param {string} userId   propriétaire de la liste (l'auteur, pour la RLS)
 * @param {string} friendId l'ami
 * @param {boolean} present vrai = l'amitié existe, faux = retirée
 * @returns {Promise<boolean>} vrai si Supabase a accepté l'écriture
 */
async function setFriendship(userId, friendId, present) {
  if (!isConfigured()) {
    console.error("Supabase non configuré : amitié non reflétée");
    return false;
  }
  if (!userId || !friendId || userId === friendId) return false;

  const filtre = `user_id=eq.${encodeURIComponent(userId)}` +
    `&friend_id=eq.${encodeURIComponent(friendId)}`;

  if (!present) {
    const res = await fetch(`${SUPABASE_URL}/rest/v1/friends?${filtre}`, {
      method: "DELETE",
      headers: authHeaders({ Prefer: "return=minimal" }),
    });
    if (!res.ok) {
      console.error(`Supabase friends DELETE ${res.status}: ${await res.text()}`);
      return false;
    }
    return true;
  }

  // Nom et photo de l'ami, dénormalisés comme le fait la table.
  let friendName = null;
  let friendPhoto = null;
  const u = await fetch(
    `${SUPABASE_URL}/rest/v1/users?select=display_name,avatar_url` +
      `&id=eq.${encodeURIComponent(friendId)}`,
    { headers: authHeaders() },
  );
  if (u.ok) {
    const rows = await u.json();
    if (Array.isArray(rows) && rows.length > 0) {
      friendName = rows[0].display_name ?? null;
      friendPhoto = rows[0].avatar_url ?? null;
    } else {
      // Clé étrangère vers users : un compte absent de Supabase ferait
      // échouer l'insertion. On le dit plutôt que de laisser un 409 muet.
      console.warn(`setFriendship : ${friendId} absent de public.users`);
      return false;
    }
  }

  const res = await fetch(
    `${SUPABASE_URL}/rest/v1/friends?on_conflict=user_id,friend_id`,
    {
      method: "POST",
      headers: authHeaders({
        "Content-Type": "application/json",
        Prefer: "resolution=merge-duplicates,return=minimal",
      }),
      body: JSON.stringify({
        user_id: userId,
        friend_id: friendId,
        friend_name: friendName,
        friend_photo_url: friendPhoto,
      }),
    },
  );
  if (!res.ok) {
    console.error(`Supabase friends UPSERT ${res.status}: ${await res.text()}`);
    return false;
  }
  return true;
}

/**
 * L'amitié `user_id -> friend_id` existe-t-elle déjà dans `public.friends` ?
 *
 * Sert de **preuve de consentement**, et n'en est une que depuis la migration
 * 20260921021300 : cette table n'est plus inscriptible par `anon` ni par
 * `authenticated`, donc une ligne ne peut y être arrivée que par la clé de
 * service — c'est-à-dire par `onFriendRequestAccepted`, après une demande
 * réellement acceptée par son destinataire.
 *
 * Une erreur réseau rend `false` : on ne mire pas dans le doute. Le coût d'un
 * faux négatif est une audience non accordée, réparée à la prochaine écriture ;
 * celui d'un faux positif serait une amitié forcée.
 *
 * @param {string} userId
 * @param {string} friendId
 * @returns {Promise<boolean>}
 */
async function friendshipExists(userId, friendId) {
  if (!isConfigured() || !userId || !friendId) return false;

  const res = await fetch(
    `${SUPABASE_URL}/rest/v1/friends?select=user_id` +
      `&user_id=eq.${encodeURIComponent(userId)}` +
      `&friend_id=eq.${encodeURIComponent(friendId)}&limit=1`,
    { headers: authHeaders() },
  );
  if (!res.ok) {
    console.error(`Supabase friends SELECT ${res.status}: ${await res.text()}`);
    return false;
  }
  const rows = await res.json();
  return Array.isArray(rows) && rows.length > 0;
}

/**
 * [blockerId] a-t-il bloqué [blockedId] ? (table `blocked_users`)
 *
 * Sert à `onCallCreated` : un compte bloqué ne doit plus faire sonner celui
 * qui l'a bloqué. Dans le doute (base injoignable), on répond OUI — ne pas
 * sonner. Le coût est nul : sans Supabase, les jetons FCM de l'appelé ne se
 * lisent pas non plus, et l'appel ne sonnerait de toute façon pas.
 *
 * @param {string} blockerId
 * @param {string} blockedId
 * @returns {Promise<boolean>}
 */
async function isBlocked(blockerId, blockedId) {
  if (!isConfigured() || !blockerId || !blockedId) return true;

  const res = await fetch(
    `${SUPABASE_URL}/rest/v1/blocked_users?select=blocker_id` +
      `&blocker_id=eq.${encodeURIComponent(blockerId)}` +
      `&blocked_id=eq.${encodeURIComponent(blockedId)}&limit=1`,
    { headers: authHeaders() },
  );
  if (!res.ok) {
    console.error(`Supabase blocked_users SELECT ${res.status}: ${await res.text()}`);
    return true;
  }
  const rows = await res.json();
  return Array.isArray(rows) && rows.length > 0;
}

/**
 * Comptes dont le délai de suppression est échu, ou dont la purge est restée en
 * route depuis plus de 30 minutes (migration 20260918224100).
 *
 * Chaque demande réclamée passe à `deleting` côté base : un second passage ne
 * la reprend pas avant 30 minutes. Un compte devenu bloquant depuis sa demande
 * (compte plateforme, historique financier) passe à `blocked` et n'est PAS
 * rendu — c'est ce qui évite de supprimer son compte Firebase pour rien.
 *
 * @param {number} limit
 * @returns {Promise<string[]|null>} les uid à finaliser ; `null` si la base n'a
 *   pas répondu — à ne jamais confondre avec « personne » (`[]`).
 */
async function claimDueAccountDeletions(limit = 20) {
  if (!isConfigured()) return null;
  const res = await fetch(
    `${SUPABASE_URL}/rest/v1/rpc/claim_due_account_deletions`,
    {
      method: "POST",
      headers: authHeaders({ "Content-Type": "application/json" }),
      body: JSON.stringify({ p_limit: limit }),
    },
  );
  if (!res.ok) {
    console.error(`Supabase claim_due_account_deletions ${res.status}: ${await res.text()}`);
    return null;
  }
  const rows = await res.json();
  return Array.isArray(rows) ? rows.map((r) => r.uid).filter(Boolean) : null;
}

/**
 * Purge un compte réclamé, en une transaction (idempotente).
 *
 * @param {string} uid Firebase UID (users.id TEXT)
 * @returns {Promise<null|{ok:boolean,error?:string,deja_fait?:boolean,summary?:Object}>}
 *   `null` si la base n'a pas répondu ; sinon la réponse de la RPC, qui rend
 *   `ok:false` plutôt que de lever quand la purge échoue (l'erreur est aussi
 *   consignée dans `account_deletion_requests.last_error`).
 */
async function completeAccountDeletion(uid) {
  if (!isConfigured()) return null;
  const res = await fetch(
    `${SUPABASE_URL}/rest/v1/rpc/complete_account_deletion`,
    {
      method: "POST",
      headers: authHeaders({ "Content-Type": "application/json" }),
      body: JSON.stringify({ p_uid: uid }),
    },
  );
  if (!res.ok) {
    console.error(`Supabase complete_account_deletion ${res.status}: ${await res.text()}`);
    return null;
  }
  return res.json();
}

module.exports = {
  claimDueAccountDeletions,
  completeAccountDeletion,
  setFriendship,
  friendshipExists,
  isBlocked,
  getFcmTokens,
  removeFcmTokens,
  getConversation,
  getUsersForPush,
  createNotification,
  getLocalEventRecipients,
  isConfigured,
};
