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
  createdAt: DateTime.parse(json['createdAt'] as String),
  expiresAt:
      json['expiresAt'] == null
          ? null
          : DateTime.parse(json['expiresAt'] as String),
  clickCount: (json['clickCount'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$$ProfileShareLinkModelImplToJson(
  _$ProfileShareLinkModelImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'userId': instance.userId,
  'shortCode': instance.shortCode,
  'createdAt': instance.createdAt.toIso8601String(),
  'expiresAt': instance.expiresAt?.toIso8601String(),
  'clickCount': instance.clickCount,
};
