import { createClient, type SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'

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

/** Ce que `generateLink` rend d'utile ici. */
interface LienGenere {
  properties: {
    action_link: string
    hashed_token?: string
    verification_type?: string
  }
}

/**
 * Le type de vérification à passer à `verifyOtp` pour ce lien-ci.
 *
 * ⚠️ NE PAS remettre `'magiclink'` en dur. `generateLink({type:'magiclink'})`
 * sur un email inconnu **crée** le compte, et le lien qu'il rend alors est de
 * type **`signup`** — `properties.verification_type` le dit. GoTrue range ce
 * jeton-là dans `confirmation_token` ; `verifyOtp({type:'magiclink'})`, lui,
 * le cherche dans `recovery_token`, ne l'y trouve pas, et répond 403
 * `otp_expired` « Email link is invalid or has expired ». Le message parle
 * d'expiration, mais rien n'a expiré : c'est le mauvais tiroir.
 *
 * Mesuré hors app le 2026-09-09 sur des comptes Supabase neufs : le MÊME
 * jeton, à la même seconde, est refusé en `magiclink` et accepté en `signup`.
 * C'était l'échec **systématique du tout premier échange de chaque compte**
 * (401 côté client), et il n'avait rien d'une course : la séquence échoue
 * aussi bien sans `updateUserById` entre les deux — cette étape ne touche que
 * `updated_at`. La 2e tentative passait simplement parce que le compte
 * existait désormais, ce qui fait rendre à `generateLink` un lien `magiclink`.
 * Conséquence dans l'app : tout compte neuf démarrait sur ~5 s de session
 * anonyme, le temps de la première reprise de `SupabaseAuthBridge`.
 *
 * Le type émis vaut aussi mieux que `'magiclink'` sur le fond : vérifier un
 * lien `signup` renseigne `email_confirmed_at`, que le compte a de toute façon
 * déjà mérité côté Firebase.
 */
function typeDeVerification(props: LienGenere['properties']): 'magiclink' | 'signup' {
  const type = props.verification_type ??
    new URL(props.action_link).searchParams.get('type') ??
    'magiclink'
  return type === 'signup' ? 'signup' : 'magiclink'
}

/**
 * Échange un lien d'authentification contre une session Supabase.
 *
 * Sans `lien`, en génère un frais pour `email`. Rend `null` sur échec — à
 * l'appelant de décider s'il retente ; c'est ce qui permet à l'étape 5 de
 * distinguer « ce jeton-ci a été refusé » de « l'échange est perdu ».
 */
async function echangerContreSession(
  supabase: SupabaseClient,
  email: string,
  lien?: LienGenere,
) {
  if (!lien) {
    const { data, error } = await supabase.auth.admin.generateLink({ type: 'magiclink', email })
    if (error || !data) {
      console.error('generateLink failed:', error?.message)
      return null
    }
    lien = data as unknown as LienGenere
  }

  const token = lien.properties.hashed_token ??
    new URL(lien.properties.action_link).searchParams.get('token')
  if (!token) {
    console.error('Failed to extract token from magic link')
    return null
  }

  const type = typeDeVerification(lien.properties)
  const { data, error } = await supabase.auth.verifyOtp({ type, token_hash: token })
  if (error || !data.session) {
    console.warn(`verifyOtp(${type}) failed: ${error?.message ?? 'no session'}`)
    return null
  }
  return data.session
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

    // 5. Échanger le lien de l'étape 2 contre une session Supabase.
    let session = await echangerContreSession(supabase, email, linkData)

    // Reprise. Le jeton est à usage unique, et `generateLink` invalide celui
    // que le même compte venait de recevoir : deux échanges qui se croisent
    // (deux appareils, deux isolats Edge) se sabotent l'un l'autre, avec le
    // même 403 que celui décrit sur `typeDeVerification`. Un lien frais, un
    // seul essai de plus — puis on rend la main.
    if (!session) {
      console.warn('échange refusé, nouvelle tentative avec un lien frais')
      session = await echangerContreSession(supabase, email)
    }
    if (!session) throw new Error('Email link exchange failed twice')

    // 6. Filet : le JWT émis doit porter firebase_uid dans app_metadata.
    //    L'étape 3 l'écrit avant l'échange, donc il ne devrait plus servir —
    //    il reste parce qu'un JWT sans le claim fait dépendre `firebase_uid()`
    //    du seul repli `auth_mappings` (étape 4a), et qu'un échange frais coûte
    //    moins cher que ce doute.
    let accessToken = session.access_token
    let refreshToken = session.refresh_token
    let expiresIn = session.expires_in

    const jwtParts = accessToken.split('.')
    const jwtPayload = decodeJwtPart(jwtParts[1])

    if (!jwtPayload?.app_metadata?.firebase_uid) {
      console.warn('firebase_uid missing from JWT on first attempt — retrying after metadata write')
      const frais = await echangerContreSession(supabase, email)
      if (frais) {
        accessToken = frais.access_token
        refreshToken = frais.refresh_token
        expiresIn = frais.expires_in
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
