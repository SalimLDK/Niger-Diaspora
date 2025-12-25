// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'group_request_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$GroupRequestModelImpl _$$GroupRequestModelImplFromJson(
  Map<String, dynamic> json,
) => _$GroupRequestModelImpl(
  id: json['id'] as String,
  groupId: json['groupId'] as String,
  groupName: json['groupName'] as String,
  groupImageUrl: json['groupImageUrl'] as String?,
  requesterId: json['requesterId'] as String,
  requesterName: json['requesterName'] as String,
  requesterPhotoUrl: json['requesterPhotoUrl'] as String?,
  status: json['status'] as String? ?? 'pending',
  message: json['message'] as String?,
  createdAt:
      json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
  processedAt:
      json['processedAt'] == null
          ? null
          : DateTime.parse(json['processedAt'] as String),
  processedBy: json['processedBy'] as String?,
);

Map<String, dynamic> _$$GroupRequestModelImplToJson(
  _$GroupRequestModelImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'groupId': instance.groupId,
  'groupName': instance.groupName,
  'groupImageUrl': instance.groupImageUrl,
  'requesterId': instance.requesterId,
  'requesterName': instance.requesterName,
  'requesterPhotoUrl': instance.requesterPhotoUrl,
  'status': instance.status,
  'message': instance.message,
  'createdAt': instance.createdAt?.toIso8601String(),
  'processedAt': instance.processedAt?.toIso8601String(),
  'processedBy': instance.processedBy,
};
