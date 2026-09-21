// Construction du bloc `data` du message FCM.
//
// Sortie de `index.ts` le 2026-09-21 pour pouvoir être testée seule
// (tools/rules_tests/send_push_donnees.mjs) : c'est ici que se décide ce que
// l'app lit en premier à la réception — `data.type`.
//
// LES CLÉS RÉSERVÉES ONT LE DERNIER MOT. Avant, `type`, `title`, `body`,
// `targetId` et `click_action` étaient posées D'ABORD, puis toutes les clés de
// `notifications.data` étaient recopiées PAR-DESSUS. Quiconque contrôlait
// `data` choisissait donc le type que l'app voyait. Or l'app, sur
// `type = incoming_call`, ouvre l'écran d'appel entrant natif avec le
// `callerName` du message (notification_service.dart:568 et :1845). Démontré
// en base le 2026-09-21 via `create_user_notification`, qui recopiait
// `p_data` tel quel — fermé le même jour côté fonction (migration
// 20260921100000, liste blanche). Ce module ferme la même porte pour tous les
// autres écrivains de `notifications`, quels qu'ils soient.
//
// Aucun écrivain légitime ne s'appuyait sur l'écrasement. Mesuré sur 1 511
// notifications réelles le 2026-09-21 : `data.type` présent 1 359 fois et
// TOUJOURS égal au type de la ligne ; `data.title`, `data.body` et
// `click_action` jamais présents ; `targetId` ne peut pas différer de la
// valeur calculée, qui en est tirée.

export type EntreeDonneesFcm = {
  type: string
  title: string
  body: string
  targetId: string
  rawData: Record<string, unknown>
}

/** Clés que l'app interprète, et que `data` ne peut donc pas imposer. */
export const CLES_RESERVEES = [
  'type',
  'title',
  'body',
  'targetId',
  'click_action',
] as const

/**
 * Le bloc `data` du message FCM : toutes les valeurs en chaîne (FCM l'exige),
 * les objets et tableaux en JSON, `null`/`undefined` omis, et les clés
 * réservées posées en DERNIER.
 */
export function construireDonneesFcm(e: EntreeDonneesFcm): Record<string, string> {
  const donnees: Record<string, string> = {}
  for (const [k, v] of Object.entries(e.rawData)) {
    if (v === null || v === undefined) continue
    donnees[k] = typeof v === 'object' ? JSON.stringify(v) : String(v)
  }
  donnees.type = e.type
  donnees.title = e.title
  donnees.body = e.body
  donnees.targetId = e.targetId
  donnees.click_action = 'FLUTTER_NOTIFICATION_CLICK'
  return donnees
}
