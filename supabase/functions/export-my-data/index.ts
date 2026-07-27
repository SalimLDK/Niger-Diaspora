// Export des données personnelles (RGPD art. 20 — droit à la portabilité).
//
// Authentification : Firebase ID token vérifié via les clés publiques Google,
// exactement comme `auth-firebase-exchange`. La service_role key ne quitte
// jamais le serveur : le client n'envoie que son propre token, et la fonction
// n'exporte QUE les lignes rattachées au firebase_uid de ce token.
//
// Deux choix délibérés, documentés dans la réponse elle-même (`_notes`) :
//
//  1. Contenu des messages — l'app est chiffrée de bout en bout. Le serveur
//     n'a jamais les clés, donc `content` sort tel qu'il est stocké : chiffré.
//     C'est irréductible, pas un oubli.
//  2. Messages des autres — seuls les messages DONT L'UTILISATEUR EST L'AUTEUR
//     sont exportés. Exporter toute la conversation ferait fuiter les données
//     personnelles des tiers, ce que la portabilité n'autorise pas.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = (Deno.env.get('SERVICE_ROLE_KEY') ??
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'))!
const FIREBASE_PROJECT_ID = Deno.env.get('FIREBASE_PROJECT_ID')!

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type',
}

interface FirebaseTokenPayload {
  sub: string
  email?: string
  exp: number
  aud: string
}

/** Vérifie un Firebase ID token via les clés publiques Google (JWKS). */
async function verifyFirebaseToken(idToken: string): Promise<FirebaseTokenPayload> {
  const keysRes = await fetch(
    'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com'
  )
  if (!keysRes.ok) throw new Error('Failed to fetch Firebase public keys')

  const jwks: { keys: JsonWebKey[] } = await keysRes.json()
  const [headerB64, payloadB64, sigB64] = idToken.split('.')
  if (!headerB64 || !payloadB64 || !sigB64) throw new Error('Malformed token')

  const header = JSON.parse(atob(headerB64.replace(/-/g, '+').replace(/_/g, '/')))
  const jwk = jwks.keys.find((k: JsonWebKey & { kid?: string }) => k.kid === header.kid)
  if (!jwk) throw new Error(`Firebase public key not found for kid: ${header.kid}`)

  const cryptoKey = await crypto.subtle.importKey(
    'jwk',
    jwk,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['verify']
  )

  const signature = Uint8Array.from(
    atob(sigB64.replace(/-/g, '+').replace(/_/g, '/')),
    (c) => c.charCodeAt(0)
  )
  const data = new TextEncoder().encode(`${headerB64}.${payloadB64}`)

  const valid = await crypto.subtle.verify(
    { name: 'RSASSA-PKCS1-v1_5' },
    cryptoKey,
    signature,
    data
  )
  if (!valid) throw new Error('Firebase token signature invalid')

  const payload: FirebaseTokenPayload = JSON.parse(
    atob(payloadB64.replace(/-/g, '+').replace(/_/g, '/'))
  )

  const now = Math.floor(Date.now() / 1000)
  if (payload.exp < now) throw new Error('Firebase token expired')
  if (payload.aud !== FIREBASE_PROJECT_ID) throw new Error('Firebase token audience mismatch')

  return payload
}

/**
 * Tables à exporter, avec les colonnes candidates portant l'identifiant de
 * l'utilisateur. Plusieurs candidats parce que le schéma distant a dérivé du
 * dépôt : une colonne absente fait passer au candidat suivant, et une table
 * absente est signalée dans `_skipped` au lieu de faire échouer tout l'export.
 */
const EXPORTS: Array<{ table: string; columns: string[] }> = [
  { table: 'users', columns: ['id'] },
  { table: 'posts', columns: ['author_id'] },
  { table: 'post_comments', columns: ['author_id'] },
  { table: 'post_likes', columns: ['user_id'] },
  { table: 'post_bookmarks', columns: ['user_id'] },
  { table: 'post_reposts', columns: ['user_id'] },
  { table: 'post_poll_votes', columns: ['user_id'] },
  { table: 'user_follows', columns: ['follower_id'] },
  { table: 'group_members', columns: ['user_id'] },
  { table: 'groups', columns: ['creator_id', 'created_by', 'owner_id'] },
  { table: 'group_requests', columns: ['user_id', 'requester_id'] },
  { table: 'events', columns: ['organizer_id', 'creator_id', 'created_by'] },
  { table: 'notifications', columns: ['user_id'] },
  { table: 'transactions', columns: ['sender_id'] },
  { table: 'payment_accounts', columns: ['user_id'] },
  { table: 'orders', columns: ['buyer_id', 'user_id'] },
  { table: 'businesses', columns: ['owner_id', 'user_id'] },
  { table: 'products', columns: ['seller_id', 'owner_id'] },
  { table: 'creator_profiles', columns: ['user_id'] },
  { table: 'support_tickets', columns: ['user_id'] },
  { table: 'reports', columns: ['reporter_id', 'user_id'] },
  { table: 'tips', columns: ['sender_id'] },
  { table: 'room_tickets', columns: ['buyer_id'] },
  { table: 'podcast_subscriptions', columns: ['user_id'] },
  { table: 'heritage_user_data', columns: ['user_id'] },
  { table: 'legal_acceptances', columns: ['user_id'] },
]

/** Codes PostgREST signifiant « table ou colonne inexistante ». */
const MISSING_CODES = new Set(['42P01', '42703', 'PGRST205', 'PGRST204'])

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: CORS_HEADERS })
  }
  if (req.method !== 'POST') {
    return json(405, { error: 'Method not allowed' })
  }

  try {
    const { firebase_token } = await req.json()
    if (!firebase_token) return json(400, { error: 'firebase_token required' })

    const payload = await verifyFirebaseToken(firebase_token)
    const uid = payload.sub

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    })

    const data: Record<string, unknown> = {}
    const skipped: Record<string, string> = {}

    for (const { table, columns } of EXPORTS) {
      let lastError = 'aucune colonne candidate'
      let done = false

      for (const column of columns) {
        const { data: rows, error } = await supabase.from(table).select('*').eq(column, uid)

        if (!error) {
          data[table] = rows ?? []
          done = true
          break
        }
        lastError = `${error.code ?? '?'}: ${error.message}`
        // Colonne/table absente → on tente le candidat suivant. Toute autre
        // erreur est réelle et doit être remontée telle quelle.
        if (!MISSING_CODES.has(error.code ?? '')) break
      }

      if (!done) skipped[table] = lastError
    }

    // Conversations : seulement celles où l'utilisateur est participant, et
    // sans le contenu des autres — on ne garde que la coquille.
    const { data: conversations, error: convError } = await supabase
      .from('conversations')
      .select('id, type, created_at, group_id')
      .contains('participant_ids', [uid])

    if (convError) {
      skipped['conversations'] = `${convError.code ?? '?'}: ${convError.message}`
    } else {
      data['conversations'] = conversations ?? []
    }

    // Messages : uniquement ceux dont l'utilisateur est l'auteur.
    const { data: messages, error: msgError } = await supabase
      .from('messages')
      .select('*')
      .eq('sender_id', uid)

    if (msgError) {
      skipped['messages'] = `${msgError.code ?? '?'}: ${msgError.message}`
    } else {
      data['messages'] = messages ?? []
    }

    const counts: Record<string, number> = {}
    for (const [key, value] of Object.entries(data)) {
      if (Array.isArray(value)) counts[key] = value.length
    }

    return json(200, {
      _meta: {
        firebase_uid: uid,
        generated_at: new Date().toISOString(),
        format_version: 1,
        counts,
      },
      _notes: [
        "Le contenu des messages est chiffré de bout en bout : le serveur n'a pas les clés et ne peut pas le déchiffrer. Les messages apparaissent donc tels qu'ils sont stockés.",
        "Seuls vos propres messages sont exportés. Les messages écrits par d'autres ne vous appartiennent pas au sens du droit à la portabilité.",
        'Les fichiers envoyés (photos, vidéos, notes vocales) ne sont pas inclus : seules leurs URL de stockage le sont.',
      ],
      _skipped: skipped,
      data,
    })
  } catch (e) {
    // Message générique côté client, détail seulement dans les logs serveur.
    console.error('export-my-data failed:', e instanceof Error ? e.message : e)
    return json(401, { error: 'Unauthorized or export failed' })
  }
})

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
  })
}
