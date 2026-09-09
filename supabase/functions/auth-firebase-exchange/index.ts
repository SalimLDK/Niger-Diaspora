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
 * Le type d'OTP réellement émis par `generateLink`, à donner tel quel à
 * `verifyOtp`.
 *
 * ⚠️ NE PAS réécrire en dur `'magiclink'`. `generateLink({type:'magiclink'})`
 * ne rend un lien `magiclink` que si l'utilisateur **existe déjà** : sur un
 * compte neuf, gotrue le crée et rend un lien `signup`. Or le jeton d'un lien
 * `signup` est rangé dans `confirmation_token`, tandis qu'un
 * `verifyOtp({type:'magiclink'})` va le chercher dans `recovery_token` — il ne
 * le trouve pas, et répond « Email link is invalid or has expired ».
 *
 * Mesuré le 2026-09-09 en rejouant la séquence contre le gotrue de
 * production : deux `generateLink` de suite sur la même adresse rendent
 * `verification_type` = `signup` puis `magiclink`. C'est ce qui faisait
 * échouer **le premier échange de chaque compte neuf**, et lui seul : la
 * tentative suivante, déclenchée 5 s plus tard par `_scheduleRetry()` côté
 * app, tombait sur l'utilisateur désormais existant et passait. Symptôme
 * visible : ~5 s de session anonyme au tout premier lancement, écrans vides.
 */
function typeEmis(verificationType: string) {
  return verificationType === 'signup' ? ('signup' as const) : ('magiclink' as const)
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

    // 5. Générer une session Supabase via le jeton du lien.
    //    Le type vient de la réponse, jamais d'une constante — cf. [typeEmis].
    //    `hashed_token` est exactement le paramètre `token` du `action_link`
    //    (vérifié le 2026-09-09), sans avoir à re-parser l'URL.
    const token = linkData.properties.hashed_token
    if (!token) throw new Error('Failed to extract token from generated link')

    let { data: session, error: sessionError } = await supabase.auth.verifyOtp({
      type: typeEmis(linkData.properties.verification_type),
      token_hash: token,
    })

    // Reprise sur refus, pour la SECONDE cause du même message.
    //
    // Mesuré le 2026-09-09 : deux `generateLink` de suite sur un compte
    // existant rendent deux jetons `magiclink`, et le second **invalide** le
    // premier — `otp_expired`, mot pour mot le message de [typeEmis]. Deux
    // échanges qui se croisent (deux appareils, deux isolats Edge) se sabotent
    // donc l'un l'autre ; le dédoublonnage `_inFlightSync` du pont Dart, lui,
    // ne couvre que les appels simultanés d'un même processus. Mesuré aussi :
    // sur un compte neuf, deux `generateLink` simultanés font rendre à l'un des
    // deux un `verification_type` vide, que [typeEmis] traduit alors en
    // `magiclink` — soit le mauvais tiroir, et le même refus.
    //
    // Un lien frais, un seul essai de plus, puis on rend la main.
    if (sessionError) {
      console.warn(`verifyOtp refusé (${sessionError.message}) — nouvel essai avec un lien frais`)
      const { data: frais, error: fraisErr } = await supabase.auth.admin.generateLink({
        type: 'magiclink',
        email,
      })
      if (fraisErr) throw sessionError
      const reprise = await supabase.auth.verifyOtp({
        type: typeEmis(frais.properties.verification_type),
        token_hash: frais.properties.hashed_token,
      })
      if (reprise.error) throw reprise.error
      session = reprise.data
    }

    // 6. Verify the issued JWT actually carries firebase_uid in app_metadata.
    //    Filet de sécurité : verifyOtp peut courir avec updateUserById et
    //    rendre un jeton qui n'a pas encore le claim. Le cas échéant, on
    //    régénère un lien et on l'échange tout de suite, pour que l'appelant
    //    reçoive toujours un JWT exploitable.
    //
    //    Ce filet ne couvrait PAS la panne du premier échange d'un compte neuf
    //    (cf. [typeEmis]) : celle-là tombait à l'étape 5, sur `sessionError`,
    //    donc bien avant d'arriver ici. Depuis le correctif du 2026-09-09, la
    //    séquence rejouée sur un compte neuf rend le claim dès la première
    //    tentative — ce bloc ne devrait plus se déclencher.
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
        const retryToken = retryLink.properties.hashed_token
        if (retryToken) {
          const { data: retrySession } = await supabase.auth.verifyOtp({
            type: typeEmis(retryLink.properties.verification_type),
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
