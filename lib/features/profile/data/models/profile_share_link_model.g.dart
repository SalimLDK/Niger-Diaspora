// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_share_link_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ProfileShareLinkModelImpl _$$ProfileShareLinkModelImplFromJson(
  Map<String, dynamic> json,
) => _$ProfileShareLinkModelImpl(
  id: json['id'] as String,
  userId: json['userId'] as String,
  shortCode: json['shortCode'] as String,
  createdAt: const LocalDateTimeConverter().fromJson(json['createdAt']),
  expiresAt: const LocalDateTimeNullableConverter().fromJson(json['expiresAt']),
  clickCount: (json['clickCount'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$$ProfileShareLinkModelImplToJson(
  _$ProfileShareLinkModelImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'userId': instance.userId,
  'shortCode': instance.shortCode,
  'createdAt': const LocalDateTimeConverter().toJson(instance.createdAt),
  'expiresAt': const LocalDateTimeNullableConverter().toJson(
    instance.expiresAt,
  ),
  'clickCount': instance.clickCount,
};
