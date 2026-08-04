// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'group_invite_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$GroupInviteModelImpl _$$GroupInviteModelImplFromJson(
  Map<String, dynamic> json,
) => _$GroupInviteModelImpl(
  id: json['id'] as String,
  groupId: json['groupId'] as String,
  groupName: json['groupName'] as String,
  groupImageUrl: json['groupImageUrl'] as String?,
  inviterId: json['inviterId'] as String,
  inviterName: json['inviterName'] as String,
  inviteeId: json['inviteeId'] as String,
  inviteeName: json['inviteeName'] as String,
  inviteePhotoUrl: json['inviteePhotoUrl'] as String?,
  status: json['status'] as String? ?? 'pending',
  createdAt: const LocalDateTimeNullableConverter().fromJson(json['createdAt']),
  respondedAt: const LocalDateTimeNullableConverter().fromJson(
    json['respondedAt'],
  ),
);

Map<String, dynamic> _$$GroupInviteModelImplToJson(
  _$GroupInviteModelImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'groupId': instance.groupId,
  'groupName': instance.groupName,
  'groupImageUrl': instance.groupImageUrl,
  'inviterId': instance.inviterId,
  'inviterName': instance.inviterName,
  'inviteeId': instance.inviteeId,
  'inviteeName': instance.inviteeName,
  'inviteePhotoUrl': instance.inviteePhotoUrl,
  'status': instance.status,
  'createdAt': const LocalDateTimeNullableConverter().toJson(
    instance.createdAt,
  ),
  'respondedAt': const LocalDateTimeNullableConverter().toJson(
    instance.respondedAt,
  ),
};
