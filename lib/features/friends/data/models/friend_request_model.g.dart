// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'friend_request_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$FriendRequestModelImpl _$$FriendRequestModelImplFromJson(
  Map<String, dynamic> json,
) => _$FriendRequestModelImpl(
  id: json['id'] as String,
  senderId: json['senderId'] as String,
  senderName: json['senderName'] as String,
  senderPhotoUrl: json['senderPhotoUrl'] as String?,
  receiverId: json['receiverId'] as String,
  receiverName: json['receiverName'] as String,
  receiverPhotoUrl: json['receiverPhotoUrl'] as String?,
  status: json['status'] as String? ?? 'pending',
  createdAt: const LocalDateTimeNullableConverter().fromJson(json['createdAt']),
  updatedAt: const LocalDateTimeNullableConverter().fromJson(json['updatedAt']),
);

Map<String, dynamic> _$$FriendRequestModelImplToJson(
  _$FriendRequestModelImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'senderId': instance.senderId,
  'senderName': instance.senderName,
  'senderPhotoUrl': instance.senderPhotoUrl,
  'receiverId': instance.receiverId,
  'receiverName': instance.receiverName,
  'receiverPhotoUrl': instance.receiverPhotoUrl,
  'status': instance.status,
  'createdAt': const LocalDateTimeNullableConverter().toJson(
    instance.createdAt,
  ),
  'updatedAt': const LocalDateTimeNullableConverter().toJson(
    instance.updatedAt,
  ),
};
