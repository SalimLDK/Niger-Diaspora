// Quand une réponse de FCM veut dire « ce jeton est mort ».
//
// Sorti de `index.ts` le 2026-10-14 pour être testé seul
// (tools/rules_tests/send_push_jeton_mort.mjs).
//
// `send-push` retirait de `users.fcm_tokens` tout jeton dont l'envoi revenait
// en INVALID_ARGUMENT. Or FCM répond INVALID_ARGUMENT à bien d'autres choses
// qu'un jeton invalide : un message de plus de 4 Ko, un champ mal formé. Un
// nom de groupe ou un titre démesuré faisait donc effacer TOUS les jetons du
// destinataire — plus aucune notification, sans un signe, jusqu'à ce que
// l'app se réenregistre (audit des notifications, constat n° 6).
//
// Un jeton n'est mort que si FCM le dit de lui : 404, UNREGISTERED, ou un
// INVALID_ARGUMENT qui nomme le jeton (« The registration token is not a
// valid FCM registration token », ou une violation sur `message.token`).

export function estJetonMort(statut: number, reponse: string): boolean {
  if (statut === 404) return true
  if (/UNREGISTERED/.test(reponse)) return true
  if (/INVALID_ARGUMENT/.test(reponse)) {
    return /registration token|message\.token/i.test(reponse)
  }
  return false
}
