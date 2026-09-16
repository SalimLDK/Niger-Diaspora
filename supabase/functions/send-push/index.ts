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

// Quelle bascule de réglages commande quel type de notification.
//
// **Reflet exact de `kClePreferenceParType`** (lib/core/services/
// notification_pref_keys.dart), qui fait foi. Cette table décide de l'ENVOI,
// la table Dart décide de l'AFFICHAGE au premier plan : quand les deux
// divergent, une bascule coupe d'un côté seulement, et l'utilisateur voit un
// réglage qui « marche à moitié » selon que son téléphone était sur l'app ou
// non. C'est arrivé à sept endroits, dans les deux sens, jusqu'au 2026-09-16.
//
// `test/core/services/notification_prefs_parite_test.dart` compare les deux
// fichiers : ils ne peuvent plus bouger l'un sans l'autre.
//
// Un type absent d'ici n'est pas filtrable — il part toujours.
const CLE_PREFERENCE_PAR_TYPE: Record<string, string> = {

  // Messagerie.
  'message': 'messages',
  'messageReaction': 'messages',
  // La sourdine d'une conversation cède sur mention, l'interrupteur global
  // non : une mention reste un message.
  'messageMention': 'messages',

  // Les gens.
  'friendRequest': 'friend_requests',
  'friendRequestAccepted': 'friend_requests',
  'friendAccepted': 'friend_requests',
  // Plus aucun écrivain depuis le 2026-09-16, et la valeur a quitté
  // `NotificationType` pour cette raison. L'entrée reste : cette table est
  // indexée par la chaîne du champ `type`, pas par l'énumération, et une
  // vieille ligne en base doit continuer d'obéir à la bascule.
  'newFollower': 'friend_requests',

  // Groupes. Les deux derniers proposent un choix dans la fiche du groupe :
  // ils appartiennent bien à cette famille-là.
  'groupInvite': 'groups',
  'groupJoinRequest': 'groups',
  'groupRequestApproved': 'groups',
  'groupRequestRejected': 'groups',
  'officialGroupLeave': 'groups',
  'cityGroupInvite': 'groups',

  // Événements.
  'eventUpdate': 'events',
  'eventAttendance': 'events',
  'eventReminder': 'event_reminders',
  'localEvent': 'local_events',

  // Salons audio et podcasts.
  'audioRoomReminder': 'audio_room_reminders',
  'audioRoomLive': 'audio_room_reminders',
  'audioRoomInvite': 'audio_room_reminders',
  'audioRoomSpeakerRequest': 'audio_room_reminders',
  'audioRoomEnded': 'audio_room_reminders',
  'podcastNewEpisode': 'podcast_episodes',
  'podcastLiveStarting': 'podcast_episodes',
  'podcastLiveNow': 'podcast_episodes',

  // Transferts d'argent.
  'transferReminder': 'transfer_reminders',
  'transferCompleted': 'transfer_reminders',
  'transferReceived': 'transfer_reminders',
  'transferFailed': 'transfer_reminders',
  'transfer': 'transfer_reminders',

  // Appels.
  'missedCall': 'calls',

  // Place de marché.
  'order': 'orders',
  'newOrder': 'orders',
  'orderPaid': 'orders',
  'orderShipped': 'orders',
  'orderDelivered': 'orders',
  'orderCancelled': 'orders',
  'orderCompleted': 'orders',
  'orderShippingReminder': 'orders',

  // Annonces. `system` respecte la bascule ; `general`, volontairement, non —
  // c'est le type de repli, et il ne doit pas pouvoir être éteint par erreur.
  'system': 'system_messages',
  'systemMessage': 'system_messages',

}

function prefKeyFor(type: string): string | null {
  return CLE_PREFERENCE_PAR_TYPE[type] ?? null
}

// Mappe un type de notification vers un canal Android (créés côté app dans
// notification_service.dart). Repli sûr : general_channel.
function channelFor(type: string): string {
  if (type === 'message' || type === 'messageReaction') return 'messages'
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

    // `mutable-content: 1` est la SEULE chose qui autorise iOS à invoquer une
    // Notification Service Extension. Sans ce drapeau, l'extension peut
    // exister, être signée et installée : elle ne sera jamais appelée, et la
    // bannière restera le repli générique.
    //
    // Posé uniquement quand la charge porte un ciphertext MLS, c'est-à-dire
    // quand une extension aurait effectivement quelque chose à déchiffrer.
    // L'élargir à tous les messages est un `if` de moins, le jour où
    // l'extension saura faire autre chose.
    //
    // Android n'en a que faire : là-bas c'est l'isolate Dart qui reconstruit
    // l'aperçu, et ce drapeau lui est indifférent.
    if (dataMap.protocol === 'mls' && dataMap.mlsCiphertext) {
      aps['mutable-content'] = 1
    }

    const dead: string[] = []

    // Les messages sont envoyés en **data-only** (pas de bloc `notification`
    // top-level) : sur Android, un bloc `notification` présent fait que le
    // système affiche lui-même la bannière dès que l'app est en
    // arrière-plan, SANS jamais invoquer `onBackgroundMessage` côté Dart —
    // vérifié sur SM A515F le 2026-08-13 (`adb logcat` : la notification est
    // postée directement par le `NotificationService` système à
    // l'horodatage du push, aucune ligne Flutter ne s'exécute). Résultat :
    // le client ne peut jamais construire la notification lui-même, donc
    // jamais lui attacher les actions Répondre/Marquer comme lu. Tous les
    // autres types de notification gardent le bloc `notification` classique
    // (affichage natif suffisant, pas d'action requise).
    //
    // `content-available: 1` (déjà dans `aps`) reste nécessaire pour réveiller
    // l'app iOS en arrière-plan ; sans bloc `notification` top-level, l'alerte
    // iOS doit être reconstruite explicitement dans `aps.alert`, sinon aucune
    // bannière ne s'affiche côté iOS.
    const isMessageType = type === 'message'
    const fcmMessage: Record<string, unknown> = isMessageType
      ? {
          data: dataMap,
          android: { priority: 'high' },
          apns: {
            headers: apnsHeaders,
            payload: { aps: { ...aps, alert: { title, body } } },
          },
        }
      : {
          notification: { title, body },
          data: dataMap,
          android: { priority: 'high', notification: androidNotification },
          apns: { headers: apnsHeaders, payload: { aps } },
        }

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
              message: { token, ...fcmMessage },
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
