import 'package:freezed_annotation/freezed_annotation.dart';

part 'notification_entity.freezed.dart';

@freezed
class NotificationEntity with _$NotificationEntity {
  const factory NotificationEntity({
    required String id,
    required String userId,
    required String title,
    required String body,
    @Default(NotificationType.general) NotificationType type,
    @Default(NotificationPriority.normal) NotificationPriority priority,
    String? targetId,
    String? senderId, // ID of the user who triggered this notification
    String? groupKey,
    @Default(false) bool isRead,
    DateTime? createdAt,
  }) = _NotificationEntity;
}

enum NotificationPriority { low, normal, high, urgent }

enum NotificationType {
  general,
  message,
  groupInvite,
  eventReminder,
  eventUpdate,
  // Friend request notifications
  friendRequest,
  friendRequestAccepted,
  friendAccepted, // Alias for friendRequestAccepted from Cloud Functions
  // Group request notifications
  groupJoinRequest,
  groupRequestApproved,
  groupRequestRejected,
  // Location-based notifications. `nearbyMember` et `proximityAlert` en
  // faisaient partie : retirés le 2026-09-16, personne ne les écrivait — pas
  // plus que `newFollower` ni `newMember`, retirés en même temps. Ils
  // occupaient cinq `switch` et trois listes de filtres, et donnaient à lire
  // une liste de types deux fois plus riche que ce que l'app produit.
  localEvent,
  // Event attendance
  eventAttendance,
  // Order notifications
  order, // Generic order notification from Cloud Functions
  newOrder,
  orderPaid,
  orderShipped,
  orderDelivered,
  orderCancelled,
  orderCompleted,
  // Fil d'actualité. Ces types-là étaient écrits en base (déclencheur SQL
  // `notify_on_post_insert`, providers du fil) mais absents de cette énumération :
  // `_parseNotificationType` les repliait donc tous sur `general`, dont le `case`
  // de navigation est vide. Une notification de publication, de mention ou de
  // commentaire ne réagissait à AUCUN appui.
  newPost,
  mentioned,
  groupMention,
  postCommented,
  commentReply,
  // Modération : écrite par `report_remote_datasource` et l'admin.
  reportResolved,
  // Invitation à un appel de groupe (`group_call_provider`).
  groupCallInvitation,
  // Réaction à un de mes messages (`set_message_reaction`).
  messageReaction,
  // Six mois après un changement de pays : quitter le groupe officiel de
  // l'ancien pays ou y rester (`proposer_departs_groupes_officiels`). Ouvre la
  // fiche du groupe, où se fait le choix.
  officialGroupLeave,
  // Trois profils d'une même ville : invitation à rejoindre son groupe
  // officiel (`ouvrir_groupe_de_ville`). Rien n'est ajouté d'office — la
  // fiche du groupe porte le choix.
  cityGroupInvite,
  // ---------------------------------------------------------------------
  // Ajoutés le 2026-09-16. Tous étaient DÉJÀ écrits, par le client, par un
  // déclencheur SQL ou par une Cloud Function, et aucun n'était ici :
  // `_parseNotificationType` les repliait sur `general`. Conséquence visible,
  // sans la moindre erreur nulle part : libellé « Général » dans la liste, et
  // pour ceux qui ont une destination, un appui qui ouvre la fiche de la
  // notification au lieu du contenu.
  //
  // Le banc `notification_types_couverts_test.dart` relit maintenant les
  // écrivains (Dart, migrations, `functions/index.js`) et exige que chaque
  // type émis figure ici. C'est lui qui empêche l'écart de revenir, plus
  // sûrement que cette liste.
  // ---------------------------------------------------------------------
  // Fil : `feed_provider._notifyPostAuthor`.
  postLiked,
  postReposted,
  // Diffusion d'annonce, insérée en SQL. 37 lignes en production le
  // 2026-09-15 — l'annonce « Vos messages bientôt chiffrés » —, toutes
  // affichées « Général ». C'est aussi le seul type qui respecte la bascule
  // « Messages système » côté `send-push`.
  system,
  // Appels.
  missedCall,
  // Salons audio et podcasts.
  audioRoomReminder,
  audioRoomLive,
  audioRoomInvite,
  podcastNewEpisode,
  podcastLiveNow,
  // Transferts d'argent.
  transferReminder,
  transferReceived,
  // Générique, écrit par `onTransferStatusChanged` : le libellé du titre dit
  // s'il a abouti ou non.
  transfer,
  transferCompleted,
  transferFailed,
  // Place de marché et paiements (Stripe).
  orderShippingReminder,
  paymentFailed,
  payout,
  payoutFailed,
  stripeAccountEnabled,
  // Réponse du support.
  supportReply,
  // Mention dans un message d'une conversation MUETTE : le seul cas où la
  // sourdine cède (`notify_recipients_on_message_insert`). Type distinct de
  // `mentioned`, qui appartient au fil et dont l'appui ouvre `/feed/<cible>` —
  // ici la cible est une conversation. ⚠️ Transport en clair seulement : dans
  // une conversation MLS les mentions sont dans la charge chiffrée, le serveur
  // ne peut pas savoir qu'un message vous nomme.
  messageMention,
  // Correction d'une bannière déjà posée après l'édition d'un message. N'est
  // JAMAIS annoncée : `send-push` l'envoie en data-only, l'appareil met sa
  // bannière à jour en place, et la ligne est écrite `is_read` d'emblée. Elle
  // figure donc dans `kTypesHorsEcranNotifications`.
  messageEdited,
}

/// Types que l'écran Notifications n'affiche pas, et que la pastille de la
/// cloche ne compte pas : ils appartiennent à la messagerie, qui a déjà sa
/// liste et ses compteurs de non-lus. Les recopier ici doublonnait chaque
/// message reçu — 73 lignes `message` sur 84 non lues, relevé du 2026-09-12.
///
/// Les lignes restent **écrites** en base : c'est leur INSERT qui déclenche le
/// push (`trg_notify_push`), et `mark_messages_as_read` les tient à jour. On
/// les écarte donc à la **lecture**, dans la requête elle-même — voir
/// `NotificationSupabaseDataSource.filtreTypesAffiches`. Un filtre posé après
/// coup sur la liste ne suffirait pas : la limite de 20 porte sur les lignes
/// brutes, et les 20 plus récentes peuvent toutes être des messages.
///
/// Le `name` de chaque valeur est la chaîne exacte stockée dans `type`.
const kTypesHorsEcranNotifications = {
  NotificationType.message,
  NotificationType.messageReaction,
  // Celle-ci n'annonce rien : elle corrige une bannière. L'afficher dans la
  // liste montrerait une entrée pour chaque faute de frappe corrigée.
  NotificationType.messageEdited,
};

extension NotificationTypeExtension on NotificationType {
  String get label {
    switch (this) {
      case NotificationType.general:
        return 'Général';
      case NotificationType.message:
        return 'Message';
      case NotificationType.groupInvite:
        return 'Invitation groupe';
      case NotificationType.eventReminder:
        return 'Rappel événement';
      case NotificationType.eventUpdate:
        return 'Mise à jour événement';
      case NotificationType.friendRequest:
        return 'Demande d\'ami';
      case NotificationType.friendRequestAccepted:
      case NotificationType.friendAccepted:
        return 'Demande acceptée';
      case NotificationType.groupJoinRequest:
        return 'Demande d\'adhésion';
      case NotificationType.groupRequestApproved:
        return 'Demande approuvée';
      case NotificationType.groupRequestRejected:
        return 'Demande refusée';
      case NotificationType.localEvent:
        return 'Événement local';
      case NotificationType.eventAttendance:
        return 'Nouvelle participation';
      case NotificationType.order:
      case NotificationType.newOrder:
        return 'Nouvelle commande';
      case NotificationType.orderPaid:
        return 'Commande payée';
      case NotificationType.orderShipped:
        return 'Commande expédiée';
      case NotificationType.orderDelivered:
        return 'Commande livrée';
      case NotificationType.orderCancelled:
        return 'Commande annulée';
      case NotificationType.orderCompleted:
        return 'Commande terminée';
      case NotificationType.newPost:
        return 'Nouvelle publication';
      case NotificationType.mentioned:
      case NotificationType.groupMention:
        return 'Mention';
      case NotificationType.postCommented:
        return 'Nouveau commentaire';
      case NotificationType.commentReply:
        return 'Réponse à votre commentaire';
      case NotificationType.reportResolved:
        return 'Signalement traité';
      case NotificationType.groupCallInvitation:
        return 'Appel de groupe';
      case NotificationType.messageReaction:
        return 'Réaction';
      case NotificationType.officialGroupLeave:
        return 'Groupe de votre ancien pays';
      case NotificationType.cityGroupInvite:
        return 'Groupe de votre ville';
      case NotificationType.postLiked:
        return 'Nouveau j\'aime';
      case NotificationType.postReposted:
        return 'Repartage';
      case NotificationType.system:
        return 'Message système';
      case NotificationType.missedCall:
        return 'Appel manqué';
      case NotificationType.audioRoomReminder:
      case NotificationType.audioRoomLive:
        return 'Salon audio';
      case NotificationType.audioRoomInvite:
        return 'Invitation à un salon';
      case NotificationType.podcastNewEpisode:
        return 'Nouvel épisode';
      case NotificationType.podcastLiveNow:
        return 'Podcast en direct';
      case NotificationType.transferReminder:
        return 'Rappel de transfert';
      case NotificationType.transferReceived:
        return 'Transfert reçu';
      case NotificationType.transfer:
        return 'Transfert';
      case NotificationType.transferCompleted:
        return 'Transfert effectué';
      case NotificationType.transferFailed:
        return 'Transfert échoué';
      case NotificationType.orderShippingReminder:
        return 'Expédition à faire';
      case NotificationType.paymentFailed:
        return 'Paiement refusé';
      case NotificationType.payout:
        return 'Virement effectué';
      case NotificationType.payoutFailed:
        return 'Virement échoué';
      case NotificationType.stripeAccountEnabled:
        return 'Compte de paiement actif';
      case NotificationType.supportReply:
        return 'Réponse du support';
      case NotificationType.messageMention:
        return 'Mention';
      case NotificationType.messageEdited:
        return 'Message modifié';
    }
  }

  String get icon {
    switch (this) {
      case NotificationType.general:
        return 'notifications';
      case NotificationType.message:
        return 'chat';
      case NotificationType.groupInvite:
        return 'group_add';
      case NotificationType.eventReminder:
        return 'event';
      case NotificationType.eventUpdate:
        return 'update';
      case NotificationType.friendRequest:
        return 'person_add';
      case NotificationType.friendRequestAccepted:
      case NotificationType.friendAccepted:
        return 'how_to_reg';
      case NotificationType.groupJoinRequest:
        return 'group_add';
      case NotificationType.groupRequestApproved:
        return 'check_circle';
      case NotificationType.groupRequestRejected:
        return 'cancel';
      case NotificationType.localEvent:
        return 'location_on';
      case NotificationType.eventAttendance:
        return 'event_available';
      case NotificationType.order:
      case NotificationType.newOrder:
        return 'shopping_bag';
      case NotificationType.orderPaid:
        return 'payment';
      case NotificationType.orderShipped:
        return 'local_shipping';
      case NotificationType.orderDelivered:
        return 'inventory';
      case NotificationType.orderCancelled:
        return 'cancel';
      case NotificationType.orderCompleted:
        return 'check_circle';
      case NotificationType.newPost:
        return 'article';
      case NotificationType.mentioned:
      case NotificationType.groupMention:
        return 'alternate_email';
      case NotificationType.postCommented:
      case NotificationType.commentReply:
        return 'chat_bubble_outline';
      case NotificationType.reportResolved:
        return 'gavel';
      case NotificationType.groupCallInvitation:
        return 'groups';
      case NotificationType.messageReaction:
        return 'add_reaction';
      case NotificationType.officialGroupLeave:
        return 'groups';
      case NotificationType.cityGroupInvite:
        return 'groups';
      case NotificationType.postLiked:
        return 'favorite';
      case NotificationType.postReposted:
        return 'repeat';
      case NotificationType.system:
        return 'campaign';
      case NotificationType.missedCall:
        return 'call_missed';
      case NotificationType.audioRoomReminder:
      case NotificationType.audioRoomLive:
      case NotificationType.audioRoomInvite:
        return 'mic';
      case NotificationType.podcastNewEpisode:
      case NotificationType.podcastLiveNow:
        return 'podcasts';
      case NotificationType.transferReminder:
      case NotificationType.transferReceived:
      case NotificationType.transferCompleted:
      case NotificationType.transfer:
        return 'payments';
      case NotificationType.transferFailed:
      case NotificationType.paymentFailed:
      case NotificationType.payoutFailed:
        return 'error_outline';
      case NotificationType.orderShippingReminder:
        return 'local_shipping';
      case NotificationType.payout:
        return 'account_balance';
      case NotificationType.stripeAccountEnabled:
        return 'verified';
      case NotificationType.supportReply:
        return 'support_agent';
      case NotificationType.messageMention:
        return 'alternate_email';
      case NotificationType.messageEdited:
        return 'edit';
    }
  }
}
