/// Quelle bascule de réglages commande quel type de notification.
///
/// **Pourquoi cette table existe.** La règle vivait en double : un `switch`
/// Dart dans `_shouldShowNotification`, qui décide de l'AFFICHAGE au premier
/// plan, et un `switch` TypeScript `prefKeyFor` dans `send-push`, qui décide
/// de l'ENVOI. Deux copies d'une même règle finissent toujours par diverger, et
/// celles-ci l'avaient fait à sept endroits, dans les deux sens — relevé le
/// 2026-09-16 :
///
/// - `friendAccepted`, `newFollower`, `eventAttendance`, `localEvent` et
///   `system` n'étaient filtrés que côté serveur : couper la bascule les
///   coupait app fermée, et les laissait passer app ouverte ;
/// - `officialGroupLeave` et `cityGroupInvite`, l'inverse : l'app les masquait
///   quand « Groupes » était coupé, le serveur les envoyait quand même.
///
/// Aucun des deux comportements n'est une erreur visible. L'utilisateur voit
/// une bascule qui « marche à moitié », selon que son téléphone était allumé
/// sur l'app ou non — le genre de chose qu'on n'arrive pas à reproduire.
///
/// La table Dart ci-dessous fait foi. Le `switch` TypeScript en est le reflet,
/// et `test/core/services/notification_prefs_parite_test.dart` compare les deux
/// fichiers ligne à ligne : ils ne peuvent plus bouger l'un sans l'autre.
///
/// **Les clés sont celles de `users.notification_prefs`** — c'est-à-dire celles
/// des SharedPreferences sans le préfixe `notify_`. Voir
/// `PreferencesService.notificationTypePrefs`, qui recopie la carte entière sur
/// le serveur à chaque bascule.
///
/// Un type absent de cette table n'est **pas** filtrable : il part toujours.
/// C'est le cas voulu pour les paiements (`paymentFailed`, `payout`,
/// `payoutFailed`, `stripeAccountEnabled`), la modération (`reportResolved`) et
/// le fil (`postLiked`, `postCommented`, `mentioned`…), qui n'ont pas de
/// bascule dédiée.
library;

const Map<String, String> kClePreferenceParType = {
  // Messagerie.
  'message': 'messages',
  'messageReaction': 'messages',
  // La sourdine d'une conversation cède sur mention, l'interrupteur global
  // non : une mention reste un message.
  'messageMention': 'messages',
  // Couper « Messages » coupe aussi les corrections : sans bannière à
  // corriger, elles n'ont plus d'objet.
  'messageEdited': 'messages',
  // Idem pour le retrait d'un message supprimé de la bannière.
  'messageDeleted': 'messages',

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
};
