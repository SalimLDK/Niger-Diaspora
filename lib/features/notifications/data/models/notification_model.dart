import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/notification_entity.dart';

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
    DateTime? createdAt,
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

  static NotificationType _parseNotificationType(String value) {
    return NotificationType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => NotificationType.general,
    );
  }

  static String? _timestampToIso(dynamic timestamp) {
    if (timestamp == null) return null;
    if (timestamp is Timestamp) {
      return timestamp.toDate().toIso8601String();
    }
    if (timestamp is String) return timestamp;
    return null;
  }
}
