// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'embassy_message_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$EmbassyMessageModelImpl _$$EmbassyMessageModelImplFromJson(
  Map<String, dynamic> json,
) => _$EmbassyMessageModelImpl(
  id: json['id'] as String,
  userId: json['userId'] as String,
  embassyId: json['embassyId'] as String,
  subject: json['subject'] as String,
  content: json['content'] as String,
  messageType:
      $enumDecodeNullable(_$EmbassyMessageTypeEnumMap, json['messageType']) ??
      EmbassyMessageType.general,
  status:
      $enumDecodeNullable(_$EmbassyMessageStatusEnumMap, json['status']) ??
      EmbassyMessageStatus.pending,
  createdAt: const EmbassyTimestampConverter().fromJson(json['createdAt']),
  readAt: const EmbassyTimestampConverter().fromJson(json['readAt']),
  repliedAt: const EmbassyTimestampConverter().fromJson(json['repliedAt']),
  attachments:
      (json['attachments'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  replyContent: json['replyContent'] as String?,
  repliedBy: json['repliedBy'] as String?,
  userName: json['userName'] as String?,
  userPhotoUrl: json['userPhotoUrl'] as String?,
  userEmail: json['userEmail'] as String?,
  embassyName: json['embassyName'] as String?,
  embassyCountry: json['embassyCountry'] as String?,
);

Map<String, dynamic> _$$EmbassyMessageModelImplToJson(
  _$EmbassyMessageModelImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'userId': instance.userId,
  'embassyId': instance.embassyId,
  'subject': instance.subject,
  'content': instance.content,
  'messageType': _$EmbassyMessageTypeEnumMap[instance.messageType]!,
  'status': _$EmbassyMessageStatusEnumMap[instance.status]!,
  'createdAt': const EmbassyTimestampConverter().toJson(instance.createdAt),
  'readAt': const EmbassyTimestampConverter().toJson(instance.readAt),
  'repliedAt': const EmbassyTimestampConverter().toJson(instance.repliedAt),
  'attachments': instance.attachments,
  'replyContent': instance.replyContent,
  'repliedBy': instance.repliedBy,
  'userName': instance.userName,
  'userPhotoUrl': instance.userPhotoUrl,
  'userEmail': instance.userEmail,
  'embassyName': instance.embassyName,
  'embassyCountry': instance.embassyCountry,
};

const _$EmbassyMessageTypeEnumMap = {
  EmbassyMessageType.general: 'general',
  EmbassyMessageType.request: 'request',
  EmbassyMessageType.complaint: 'complaint',
  EmbassyMessageType.inquiry: 'inquiry',
  EmbassyMessageType.followUp: 'followUp',
};

const _$EmbassyMessageStatusEnumMap = {
  EmbassyMessageStatus.pending: 'pending',
  EmbassyMessageStatus.read: 'read',
  EmbassyMessageStatus.replied: 'replied',
  EmbassyMessageStatus.closed: 'closed',
};
