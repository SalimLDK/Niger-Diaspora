// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conversation_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ConversationModelImpl _$$ConversationModelImplFromJson(
  Map<String, dynamic> json,
) => _$ConversationModelImpl(
  id: json['id'] as String,
  type: json['type'] as String? ?? 'individual',
  name: json['name'] as String?,
  imageUrl: json['imageUrl'] as String?,
  participantIds:
      (json['participantIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  lastMessage: json['lastMessage'] as String?,
  lastMessageSenderId: json['lastMessageSenderId'] as String?,
  lastMessageAt:
      json['lastMessageAt'] == null
          ? null
          : DateTime.parse(json['lastMessageAt'] as String),
  createdAt:
      json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
  createdBy: json['createdBy'] as String,
  unreadCount: json['unreadCount'] as Map<String, dynamic>? ?? const {},
  mutedBy: json['mutedBy'] as Map<String, dynamic>? ?? const {},
  archivedBy: json['archivedBy'] as Map<String, dynamic>? ?? const {},
);

Map<String, dynamic> _$$ConversationModelImplToJson(
  _$ConversationModelImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'type': instance.type,
  'name': instance.name,
  'imageUrl': instance.imageUrl,
  'participantIds': instance.participantIds,
  'lastMessage': instance.lastMessage,
  'lastMessageSenderId': instance.lastMessageSenderId,
  'lastMessageAt': instance.lastMessageAt?.toIso8601String(),
  'createdAt': instance.createdAt?.toIso8601String(),
  'createdBy': instance.createdBy,
  'unreadCount': instance.unreadCount,
  'mutedBy': instance.mutedBy,
  'archivedBy': instance.archivedBy,
};
