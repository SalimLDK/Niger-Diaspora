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
    String? targetId,
    @Default(false) bool isRead,
    DateTime? createdAt,
  }) = _NotificationEntity;
}

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
  // Group request notifications
  groupJoinRequest,
  groupRequestApproved,
  groupRequestRejected,
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
        return 'Demande acceptée';
      case NotificationType.groupJoinRequest:
        return 'Demande d\'adhésion';
      case NotificationType.groupRequestApproved:
        return 'Demande approuvée';
      case NotificationType.groupRequestRejected:
        return 'Demande refusée';
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
        return 'how_to_reg';
      case NotificationType.groupJoinRequest:
        return 'group_add';
      case NotificationType.groupRequestApproved:
        return 'check_circle';
      case NotificationType.groupRequestRejected:
        return 'cancel';
    }
  }
}
