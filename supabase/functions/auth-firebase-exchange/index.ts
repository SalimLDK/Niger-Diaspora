import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = (Deno.env.get('SERVICE_ROLE_KEY') ?? Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'))!
const FIREBASE_PROJECT_ID = Deno.env.get('FIREBASE_PROJECT_ID')!

interface FirebaseTokenPayload {
  sub: string      // Firebase UID (28-char TEXT, NOT a UUID)
  email?: string
  name?: string
  picture?: string
  exp: number
  aud: string
}

/**
 * Décode un segment de JWT (base64url) en UTF-8.
 *
 * ⚠️ NE PAS revenir à `JSON.parse(atob(...))`. `atob` rend une chaîne
 * *binaire* : un caractère JS par octet, c'est-à-dire les octets UTF-8 relus
 * comme du Latin-1. Le claim `name` du jeton Firebase, « Ibrahim Yacouba
 * Maïdaoua » (octets `… 4d 61 c3 af 64 …`), devenait donc la chaîne
 * « Ibrahim Yacouba MaÃ¯daoua », que la ligne `display_name` ci-dessous
 * écrivait telle quelle dans `users`.
 *
 * Constaté en production le 2026-08-23 : la ligne de ce compte portait
 * `4d61 c383 c2af` (« MaÃ¯daoua ») au lieu de `4d61 c3af`, et l'application
 * l'affichait ainsi PARTOUT. Le défaut était intermittent parce que
 * `_upsertUserToSupabase`, côté Dart, réécrit le nom CORRECT depuis le SDK
 * Firebase : les deux écritures se disputaient la ligne, la dernière gagnait.
 */
function decodeJwtPart(part: string): any {
  const base64 = part.replace(/-/g, '+').replace(/_/g, '/')
  const bytes = Uint8Array.from(atob(base64), (c) => c.charCodeAt(0))
  return JSON.parse(new TextDecoder().decode(bytes))
}

/**
 * Vérifie un Firebase ID token via les clés publiques Google (JWKS).
 */
async function verifyFirebaseToken(idToken: string): Promise<FirebaseTokenPayload> {
  const keysRes = await fetch(
    'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com'
  )
  if (!keysRes.ok) throw new Error('Failed to fetch Firebase public keys')

  const jwks: { keys: JsonWebKey[] } = await keysRes.json()
  const [headerB64, payloadB64, sigB64] = idToken.split('.')

  const header = decodeJwtPart(headerB64)
  const kid: string = header.kid

  const jwk = jwks.keys.find((k: JsonWebKey & { kid?: string }) => k.kid === kid)
  if (!jwk) throw new Error(`Firebase public key not found for kid: ${kid}`)

  const cryptoKey = await crypto.subtle.importKey(
    'jwk',
    jwk,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['verify']
  )

  const signature = Uint8Array.from(
    atob(sigB64.replace(/-/g, '+').replace(/_/g, '/')),
    c => c.charCodeAt(0)
  )
  const data = new TextEncoder().encode(`${headerB64}.${payloadB64}`)

  const valid = await crypto.subtle.verify({ name: 'RSASSA-PKCS1-v1_5' }, cryptoKey, signature, data)
  if (!valid) throw new Error('Firebase token signature invalid')

  const payload: FirebaseTokenPayload = decodeJwtPart(payloadB64)

  const now = Math.floor(Date.now() / 1000)
  if (payload.exp < now) throw new Error('Firebase token expired')
  if (payload.aud !== FIREBASE_PROJECT_ID) throw new Error('Firebase token audience mismatch')

  return payload
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'authorization, content-type',
      },
    })
  }

  try {
    const { firebase_token } = await req.json()
    if (!firebase_token) {
      return errorResponse(400, 'firebase_token required')
    }

    // 1. Vérifier le Firebase ID token
    const payload = await verifyFirebaseToken(firebase_token)
    const firebaseUid = payload.sub  // TEXT, ex. "TmJ0Fv3qKhgE1234567890"

    // Email ou email synthétique pour les comptes sans email
    const email = payload.email ?? `firebase_${firebaseUid}@no-reply.diasponiger.app`

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    })

    // 2. generateLink crée l'utilisateur Supabase Auth s'il n'existe pas,
    //    ou retrouve l'existant — remplace getUserByEmail (supprimé en v2).
    //    Retourne user.id + properties.action_link (token du magic link).
    const { data: linkData, error: linkError } = await supabase.auth.admin.generateLink({
      type: 'magiclink',
      email,
    })
    if (linkError) throw linkError

    const supabaseUserId = linkData.user.id

    // 3. Garantir que app_metadata.firebase_uid est dans le JWT.
    //    Doit être fait AVANT verifyOtp pour que le nouveau access_token
    //    l'inclue dans ses claims (Supabase génère le JWT avec les metadata courantes).
    const { error: updateError } = await supabase.auth.admin.updateUserById(supabaseUserId, {
      app_metadata: {
        ...linkData.user.app_metadata,
        firebase_uid: firebaseUid,
      },
    })
    if (updateError) throw new Error(`updateUserById failed: ${updateError.message}`)

    // 4a. Persiste le mapping supabase_id → firebase_uid dans auth_mappings.
    //     firebase_uid() l'utilise comme fallback quand le JWT est rafraîchi
    //     sans le claim app_metadata.firebase_uid (race condition gotrue).
    const { error: mappingError } = await supabase.from('auth_mappings').upsert({
      supabase_id: supabaseUserId,
      firebase_uid: firebaseUid,
      updated_at: new Date().toISOString(),
    }, { onConflict: 'supabase_id' })
    if (mappingError) {
      console.error('auth_mappings upsert failed (non-fatal):', mappingError.message)
    }

    // 4b. Créer la ligne dans la table users publique (idempotent)
    await supabase.from('users').upsert({
      id: firebaseUid,  // users.id TEXT = Firebase UID
      email: payload.email,
      display_name: payload.name ?? email.split('@')[0],
    }, { onConflict: 'id' })

    // 5. Générer une session Supabase via le token du magic link
    const url = new URL(linkData.properties.action_link)
    const token = url.searchParams.get('token')
    if (!token) throw new Error('Failed to extract token from magic link')

    const { data: session, error: sessionError } = await supabase.auth.verifyOtp({
      type: 'magiclink',
      token_hash: token,
    })
    if (sessionError) throw sessionError

    // 6. Verify the issued JWT actually carries firebase_uid in app_metadata.
    //    On first signup, verifyOtp can race with updateUserById and produce a
    //    token that still lacks the claim. If so, generate a fresh link and
    //    exchange it immediately so the caller always receives a valid JWT.
    let accessToken = session.session!.access_token
    let refreshToken = session.session!.refresh_token
    let expiresIn = session.session!.expires_in

    const jwtParts = accessToken.split('.')
    const jwtPayload = decodeJwtPart(jwtParts[1])

    if (!jwtPayload?.app_metadata?.firebase_uid) {
      console.warn('firebase_uid missing from JWT on first attempt — retrying after metadata write')
      const { data: retryLink, error: retryLinkErr } = await supabase.auth.admin.generateLink({
        type: 'magiclink',
        email,
      })
      if (!retryLinkErr && retryLink) {
        const retryUrl = new URL(retryLink.properties.action_link)
        const retryToken = retryUrl.searchParams.get('token')
        if (retryToken) {
          const { data: retrySession } = await supabase.auth.verifyOtp({
            type: 'magiclink',
            token_hash: retryToken,
          })
          if (retrySession?.session) {
            accessToken = retrySession.session.access_token
            refreshToken = retrySession.session.refresh_token
            expiresIn = retrySession.session.expires_in
          }
        }
      }
    }

    return new Response(
      JSON.stringify({
        access_token: accessToken,
        refresh_token: refreshToken,
        expires_in: expiresIn,
        firebase_uid: firebaseUid,
        supabase_user_id: supabaseUserId,
      }),
      {
        status: 200,
        headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
      }
    )
  } catch (err) {
    console.error('auth-firebase-exchange error:', err)
    const message = err instanceof Error ? err.message : 'Unknown error'
    return errorResponse(401, message)
  }
})

function errorResponse(status: number, message: string) {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
  })
}
