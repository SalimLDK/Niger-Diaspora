// =============================================================================
// send-push — Edge Function
//
// Déclenchée par un Database Webhook / trigger pg_net à chaque INSERT dans la
// table `notifications`. Lit les tokens FCM du destinataire dans `users.fcm_tokens`
// et envoie une notification push via l'API FCM HTTP v1.
//
// Remplace l'ancienne Cloud Function Firestore `sendNotificationOnCreate` et le
// flux RTDB `onMessageCreated` (messages de chat inclus).
//
// Sécurité : la fonction n'est appelable que par le trigger DB, qui présente le
// secret partagé `PUSH_WEBHOOK_SECRET` dans l'en-tête `x-webhook-secret`. Le client
// n'envoie jamais de push directement — il insère seulement une ligne `messages`
// (ou appelle create_user_notification) ; le serveur crée les lignes
// `notifications` (SECURITY DEFINER) → webhook → FCM.
//
// Secrets requis (supabase secrets set ...) :
//   - FCM_SERVICE_ACCOUNT : le JSON complet d'un service account Firebase
//   - PUSH_WEBHOOK_SECRET  : secret partagé avec le trigger DB / Database Webhook
//   - SERVICE_ROLE_KEY     : nouvelle clé secrète Supabase (sb_secret_…) pour
//     l'accès privilégié. Remplace la legacy SUPABASE_SERVICE_ROLE_KEY auto-
//     injectée (désactivée depuis la migration vers les nouvelles API keys).
//   (SUPABASE_URL reste auto-injecté par le runtime)
//
// Déploiement : supabase functions deploy send-push
//   (verify_jwt = false est déclaré dans supabase/config.toml)
// =============================================================================

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = (Deno.env.get('SERVICE_ROLE_KEY') ?? Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'))!
const FCM_SERVICE_ACCOUNT = Deno.env.get('FCM_SERVICE_ACCOUNT')!
const PUSH_WEBHOOK_SECRET = Deno.env.get('PUSH_WEBHOOK_SECRET')!

interface ServiceAccount {
  client_email: string
  private_key: string
  project_id: string
}

// Cache du jeton OAuth d'accès, réutilisé tant qu'il est valide.
let cachedAccessToken: { token: string; expiresAt: number } | null = null

function base64Url(data: Uint8Array | string): string {
  const bytes = typeof data === 'string' ? new TextEncoder().encode(data) : data
  let bin = ''
  for (const b of bytes) bin += String.fromCharCode(b)
  return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const b64 = pem
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s+/g, '')
  const bin = atob(b64)
  const buf = new Uint8Array(bin.length)
  for (let i = 0; i < bin.length; i++) buf[i] = bin.charCodeAt(i)
  return buf.buffer
}

// Construit un jeton d'accès OAuth2 (scope firebase.messaging) à partir du
// service account, en signant un JWT RS256 via Web Crypto.
async function getAccessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  if (cachedAccessToken && cachedAccessToken.expiresAt > now + 60) {
    return cachedAccessToken.token
  }

  const header = { alg: 'RS256', typ: 'JWT' }
  const claim = {
    iss: sa.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  }
  const unsigned = `${base64Url(JSON.stringify(header))}.${base64Url(JSON.stringify(claim))}`

  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToArrayBuffer(sa.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  )
  const sig = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(unsigned),
  )
  const jwt = `${unsigned}.${base64Url(new Uint8Array(sig))}`

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  })
  if (!res.ok) throw new Error(`OAuth token: ${await res.text()}`)
  const data = await res.json()
  cachedAccessToken = {
    token: data.access_token,
    expiresAt: now + (data.expires_in ?? 3600),
  }
  return cachedAccessToken.token
}

// Mappe un type de notification vers la clé de `users.notification_prefs`.
// Miroir exact du switch de `_shouldShowNotification` côté app — les deux
// doivent bouger ensemble, sinon une bascule coupe au premier plan et laisse
// passer en arrière-plan (le défaut que cette colonne corrige).
// null = type non filtrable par préférence (toujours envoyé).
function prefKeyFor(type: string): string | null {
  switch (type) {
    case 'message':
      return 'messages'
    case 'friendRequest':
    case 'friendRequestAccepted':
    case 'friendAccepted':
    case 'newFollower':
      return 'friend_requests'
    case 'groupInvite':
    case 'groupJoinRequest':
    case 'groupRequestApproved':
    case 'groupRequestRejected':
      return 'groups'
    case 'eventUpdate':
    case 'eventAttendance':
      return 'events'
    case 'eventReminder':
      return 'event_reminders'
    case 'localEvent':
      return 'local_events'
    case 'audioRoomReminder':
    case 'audioRoomLive':
    case 'audioRoomInvite':
    case 'audioRoomSpeakerRequest':
    case 'audioRoomEnded':
      return 'audio_room_reminders'
    case 'podcastNewEpisode':
    case 'podcastLiveStarting':
    case 'podcastLiveNow':
      return 'podcast_episodes'
    case 'transferReminder':
    case 'transferCompleted':
    case 'transferReceived':
    case 'transferFailed':
      return 'transfer_reminders'
    case 'missedCall':
      return 'calls'
    case 'newOrder':
    case 'orderPaid':
    case 'orderShipped':
    case 'orderDelivered':
    case 'orderCancelled':
      return 'orders'
    case 'system':
    case 'systemMessage':
      return 'system_messages'
    default:
      return null
  }
}

// Mappe un type de notification vers un canal Android (créés côté app dans
// notification_service.dart). Repli sûr : general_channel.
function channelFor(type: string): string {
  if (type === 'message') return 'messages'
  if (type.startsWith('order')) return 'orders_channel'
  if (type.startsWith('event') || type === 'localEvent') return 'events_channel'
  if (type.startsWith('audioRoom')) return 'audio_rooms_reminders_channel'
  if (type.startsWith('podcast')) return 'podcast_reminders_channel'
  if (type.startsWith('transfer')) return 'transfer_reminders_channel'
  if (type === 'friendRequest' || type === 'friendAccepted' || type === 'newFollower') {
    return 'friends_channel'
  }
  return 'general_channel'
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') return json(405, { error: 'Method not allowed' })

  // Authentification par secret partagé présenté par le trigger DB.
  if (req.headers.get('x-webhook-secret') !== PUSH_WEBHOOK_SECRET) {
    return json(401, { error: 'Unauthorized' })
  }

  try {
    const payload = await req.json()
    // Database Webhook / pg_net : { type, table, record, ... }
    // Compat : accepter aussi un record passé à la racine.
    const record = payload?.record ?? payload
    if (!record?.user_id) return json(200, { skipped: 'no user_id' })

    const type = String(record.type ?? 'general')

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    })

    const { data: userRow } = await supabase
      .from('users')
      .select('fcm_tokens, notifications_enabled, show_message_preview')
      .eq('id', record.user_id)
      .maybeSingle()

    // Préférence globale push désactivée → pas d'envoi FCM (la ligne
    // notifications reste visible in-app).
    if (userRow?.notifications_enabled === false) {
      return json(200, { skipped: 'notifications disabled' })
    }

    // Préférence par type. Clé absente = autorisé ; seul un false explicite
    // coupe. C'est ce qui rend la bascule effective app fermée, là où
    // `_shouldShowNotification` ne mordait qu'au premier plan.
    //
    // Lecture SÉPARÉE et tolérante à l'absence de la colonne : déployer cette
    // fonction avant la migration 20260805233000 ferait échouer un select qui
    // la mentionne, `userRow` serait null, et PLUS AUCUN push ne partirait —
    // y compris ceux qui marchaient. L'ordre déploiement/migration ne doit pas
    // pouvoir casser l'envoi.
    const prefKey = prefKeyFor(type)
    if (prefKey) {
      const { data: prefRow, error: prefErr } = await supabase
        .from('users')
        .select('notification_prefs')
        .eq('id', record.user_id)
        .maybeSingle()
      if (prefErr) {
        console.warn('notification_prefs indisponible, envoi autorisé:', prefErr.message)
      } else {
        const prefs = (prefRow?.notification_prefs ?? {}) as Record<string, unknown>
        if (prefs[prefKey] === false) {
          return json(200, { skipped: `type disabled: ${prefKey}` })
        }
      }
    }

    const tokens: string[] = (userRow?.fcm_tokens as string[] | null) ?? []
    if (tokens.length === 0) return json(200, { skipped: 'no tokens' })

    const sa = JSON.parse(FCM_SERVICE_ACCOUNT) as ServiceAccount
    const accessToken = await getAccessToken(sa)

    const rawData = (record.data && typeof record.data === 'object')
      ? (record.data as Record<string, unknown>)
      : {}

    let title = String(record.title ?? 'Diaspo Niger')
    let body = String(record.body ?? '')

    // Aligné sur l'ancien onMessageCreated CF + notification_service.dart :
    // sans aperçu → titre = senderName, body générique.
    if (type === 'message' && userRow?.show_message_preview === false) {
      title = String(rawData.senderName ?? title)
      body = 'Nouveau message'
    }

    const conversationId = String(
      rawData.conversationId ?? record.target_id ?? rawData.target_id ?? '',
    )
    const targetId = String(
      record.target_id ?? rawData.targetId ?? rawData.target_id ?? conversationId,
    )

    // Payload data attendu par notification_service.dart (tous les champs string).
    const dataMap: Record<string, string> = {
      type,
      title,
      body,
      targetId,
      click_action: 'FLUTTER_NOTIFICATION_CLICK',
    }
    for (const [k, v] of Object.entries(rawData)) {
      if (v === null || v === undefined) continue
      // JSON objects/arrays → string JSON ; scalaires → String()
      dataMap[k] = typeof v === 'object' ? JSON.stringify(v) : String(v)
    }
    // Garantit les clés camelCase utilisées par le client message.
    if (type === 'message') {
      if (conversationId) dataMap.conversationId = conversationId
      if (!dataMap.targetId && conversationId) dataMap.targetId = conversationId
      dataMap.showMessagePreview =
        userRow?.show_message_preview === false ? 'false' : 'true'
    }

    const channelId = channelFor(type)
    const androidNotification: Record<string, string> = {
      channel_id: channelId,
      sound: 'default',
    }
    // Groupement Android / iOS par conversation (comme l'ancien CF).
    if (type === 'message' && conversationId) {
      androidNotification.tag = `msg_${conversationId}`
    }

    const apnsHeaders: Record<string, string> = { 'apns-push-type': 'alert' }
    const aps: Record<string, unknown> = {
      sound: 'default',
      badge: 1,
      'content-available': 1,
    }
    if (type === 'message' && conversationId) {
      apnsHeaders['apns-collapse-id'] = conversationId
      aps['thread-id'] = conversationId
    }

    const dead: string[] = []

    await Promise.all(
      tokens.map(async (token) => {
        const res = await fetch(
          `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`,
          {
            method: 'POST',
            headers: {
              Authorization: `Bearer ${accessToken}`,
              'Content-Type': 'application/json',
            },
            body: JSON.stringify({
              message: {
                token,
                notification: { title, body },
                data: dataMap,
                android: {
                  priority: 'high',
                  notification: androidNotification,
                },
                apns: {
                  headers: apnsHeaders,
                  payload: { aps },
                },
              },
            }),
          },
        )
        if (!res.ok) {
          const errText = await res.text()
          // Retire uniquement les tokens définitivement invalides.
          if (res.status === 404 || /UNREGISTERED|INVALID_ARGUMENT/.test(errText)) {
            dead.push(token)
          } else {
            console.error('FCM send error', res.status, errText)
          }
        }
      }),
    )

    if (dead.length > 0) {
      const remaining = tokens.filter((t) => !dead.includes(t))
      await supabase
        .from('users')
        .update({ fcm_tokens: remaining })
        .eq('id', record.user_id)
    }

    return json(200, { sent: tokens.length - dead.length, removed: dead.length })
  } catch (e) {
    console.error('send-push:', e)
    return json(500, { error: e instanceof Error ? e.message : 'Erreur interne' })
  }
})

function json(status: number, data: unknown) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })
}
