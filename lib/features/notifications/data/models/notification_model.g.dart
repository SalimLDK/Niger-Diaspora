// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$NotificationModelImpl _$$NotificationModelImplFromJson(
  Map<String, dynamic> json,
) => _$NotificationModelImpl(
  id: json['id'] as String,
  userId: json['userId'] as String,
  title: json['title'] as String,
  body: json['body'] as String,
  type: json['type'] as String? ?? 'general',
  targetId: json['targetId'] as String?,
  senderId: json['senderId'] as String?,
  isRead: json['isRead'] as bool? ?? false,
  createdAt: const LocalDateTimeNullableConverter().fromJson(json['createdAt']),
);

Map<String, dynamic> _$$NotificationModelImplToJson(
  _$NotificationModelImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'userId': instance.userId,
  'title': instance.title,
  'body': instance.body,
  'type': instance.type,
  'targetId': instance.targetId,
  'senderId': instance.senderId,
  'isRead': instance.isRead,
  'createdAt': const LocalDateTimeNullableConverter().toJson(
    instance.createdAt,
  ),
};
