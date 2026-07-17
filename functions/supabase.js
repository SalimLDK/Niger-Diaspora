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

module.exports = { getFcmTokens, removeFcmTokens, isConfigured };
