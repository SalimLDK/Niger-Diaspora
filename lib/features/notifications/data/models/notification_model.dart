import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/notification_entity.dart';

import '../../../../core/utils/date_parsing.dart';
part 'notification_model.freezed.dart';
part 'notification_model.g.dart';

@freezed
class NotificationModel with _$NotificationModel {
  const NotificationModel._();

  const factory NotificationModel({
    required String id,
    required String userId,
    required String title,
    required String body,
    @Default('general') String type,
    String? targetId,
    String? senderId, // ID of the user who triggered this notification
    @Default(false) bool isRead,
    @LocalDateTimeNullableConverter() DateTime? createdAt,
  }) = _NotificationModel;

  factory NotificationModel.fromJson(Map<String, dynamic> json) =>
      _$NotificationModelFromJson(json);

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationModel.fromJson({
      ...data,
      'id': doc.id,
      'createdAt': _timestampToIso(data['createdAt']),
      'senderId': data['senderId'] ?? data['fromUserId'], // Support both field names
    });
  }

  Map<String, dynamic> toFirestore() {
    final json = toJson();
    json.remove('id');
    json['createdAt'] = FieldValue.serverTimestamp();
    return json;
  }

  NotificationEntity toEntity() => NotificationEntity(
        id: id,
        userId: userId,
        title: title,
        body: body,
        type: _parseNotificationType(type),
        targetId: targetId,
        senderId: senderId,
        isRead: isRead,
        createdAt: createdAt,
      );

  factory NotificationModel.fromEntity(NotificationEntity entity) =>
      NotificationModel(
        id: entity.id,
        userId: entity.userId,
        title: entity.title,
        body: entity.body,
        type: entity.type.name,
        targetId: entity.targetId,
        senderId: entity.senderId,
        isRead: entity.isRead,
        createdAt: entity.createdAt,
      );

  /// Traduit le `type` stocké en base en [NotificationType].
  ///
  /// La base mélange deux conventions : les déclencheurs SQL écrivent en
  /// serpent (`new_post`, `group_mention`, `report_resolved`), le client en
  /// chameau (`friendRequest`, `groupCallInvitation`). Une comparaison stricte
  /// sur `e.name` ne voyait donc que la moitié des types et repliait l'autre
  /// sur `general` — dont la navigation est un `break` vide : ces
  /// notifications-là ne réagissaient à aucun appui. On normalise les deux
  /// écritures avant de comparer.
  static NotificationType _parseNotificationType(String value) {
    final normalized = _toCamelCase(value.trim());
    for (final type in NotificationType.values) {
      if (type.name.toLowerCase() == normalized.toLowerCase()) return type;
    }
    return NotificationType.general;
  }

  /// `new_post` → `newPost`. Laisse intact ce qui est déjà en chameau.
  static String _toCamelCase(String value) {
    if (!value.contains('_')) return value;
    final parts = value.split('_').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return value;
    return parts.first +
        parts.skip(1).map((p) => p[0].toUpperCase() + p.substring(1)).join();
  }

  static String? _timestampToIso(dynamic timestamp) {
    if (timestamp == null) return null;
    if (timestamp is Timestamp) {
      return timestamp.toDate().toUtc().toIso8601String();
    }
    if (timestamp is String) return timestamp;
    return null;
  }
}
