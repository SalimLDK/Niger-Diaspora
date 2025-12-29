// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$MessageModelImpl _$$MessageModelImplFromJson(
  Map<String, dynamic> json,
) => _$MessageModelImpl(
  id: json['id'] as String,
  senderId: json['senderId'] as String,
  senderName: json['senderName'] as String,
  senderPhotoUrl: json['senderPhotoUrl'] as String?,
  content: json['content'] as String,
  type: json['type'] as String? ?? 'text',
  fileUrl: json['fileUrl'] as String?,
  fileName: json['fileName'] as String?,
  fileSize: (json['fileSize'] as num?)?.toInt(),
  mimeType: json['mimeType'] as String?,
  audioDuration: (json['audioDuration'] as num?)?.toInt(),
  audioWaveform:
      (json['audioWaveform'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList() ??
      const [],
  thumbnailUrl: json['thumbnailUrl'] as String?,
  videoDuration: (json['videoDuration'] as num?)?.toInt(),
  readBy:
      (json['readBy'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  readAt: json['readAt'] as Map<String, dynamic>? ?? const {},
  createdAt:
      json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
  deletedFor:
      (json['deletedFor'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  deletedForEveryone: json['deletedForEveryone'] as bool? ?? false,
  deletedAt:
      json['deletedAt'] == null
          ? null
          : DateTime.parse(json['deletedAt'] as String),
  reportedBy:
      (json['reportedBy'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  reactions:
      (json['reactions'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  replyToId: json['replyToId'] as String?,
  replyToMessageData: json['replyToMessageData'] as Map<String, dynamic>?,
  productData: json['productData'] as Map<String, dynamic>?,
);

Map<String, dynamic> _$$MessageModelImplToJson(_$MessageModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'senderId': instance.senderId,
      'senderName': instance.senderName,
      'senderPhotoUrl': instance.senderPhotoUrl,
      'content': instance.content,
      'type': instance.type,
      'fileUrl': instance.fileUrl,
      'fileName': instance.fileName,
      'fileSize': instance.fileSize,
      'mimeType': instance.mimeType,
      'audioDuration': instance.audioDuration,
      'audioWaveform': instance.audioWaveform,
      'thumbnailUrl': instance.thumbnailUrl,
      'videoDuration': instance.videoDuration,
      'readBy': instance.readBy,
      'readAt': instance.readAt,
      'createdAt': instance.createdAt?.toIso8601String(),
      'deletedFor': instance.deletedFor,
      'deletedForEveryone': instance.deletedForEveryone,
      'deletedAt': instance.deletedAt?.toIso8601String(),
      'reportedBy': instance.reportedBy,
      'reactions': instance.reactions,
      'replyToId': instance.replyToId,
      'replyToMessageData': instance.replyToMessageData,
      'productData': instance.productData,
    };
