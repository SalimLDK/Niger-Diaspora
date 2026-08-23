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
  newFollower,
  newMember,
  eventUpdate,
  // Friend request notifications
  friendRequest,
  friendRequestAccepted,
  friendAccepted, // Alias for friendRequestAccepted from Cloud Functions
  // Group request notifications
  groupJoinRequest,
  groupRequestApproved,
  groupRequestRejected,
  // Location-based notifications
  localEvent,
  nearbyMember,
  proximityAlert,
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
}

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
      case NotificationType.newFollower:
        return 'Nouveau follower';
      case NotificationType.newMember:
        return 'Nouveau membre';
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
      case NotificationType.nearbyMember:
        return 'Membre à proximité';
      case NotificationType.proximityAlert:
        return 'Alerte proximité';
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
      case NotificationType.newFollower:
        return 'person_add';
      case NotificationType.newMember:
        return 'person';
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
      case NotificationType.nearbyMember:
        return 'person_pin';
      case NotificationType.proximityAlert:
        return 'radar';
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
    }
  }
}
