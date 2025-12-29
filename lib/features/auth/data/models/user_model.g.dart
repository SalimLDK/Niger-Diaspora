// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$UserModelImpl _$$UserModelImplFromJson(Map<String, dynamic> json) =>
    _$UserModelImpl(
      id: json['id'] as String,
      email: json['email'] as String?,
      displayName: json['displayName'] as String?,
      photoUrl: json['photoUrl'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      createdAt: const TimestampConverter().fromJson(json['createdAt']),
      lastLoginAt: const TimestampConverter().fromJson(json['lastLoginAt']),
      isAdmin: json['isAdmin'] as bool? ?? false,
      isBanned: json['isBanned'] as bool? ?? false,
      banReason: json['banReason'] as String?,
      bannedAt: const TimestampConverter().fromJson(json['bannedAt']),
    );

Map<String, dynamic> _$$UserModelImplToJson(_$UserModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'email': instance.email,
      'displayName': instance.displayName,
      'photoUrl': instance.photoUrl,
      'phoneNumber': instance.phoneNumber,
      'createdAt': const TimestampConverter().toJson(instance.createdAt),
      'lastLoginAt': const TimestampConverter().toJson(instance.lastLoginAt),
      'isAdmin': instance.isAdmin,
      'isBanned': instance.isBanned,
      'banReason': instance.banReason,
      'bannedAt': const TimestampConverter().toJson(instance.bannedAt),
    };
