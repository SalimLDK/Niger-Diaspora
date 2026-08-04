// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'blocked_user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$BlockedUserModelImpl _$$BlockedUserModelImplFromJson(
  Map<String, dynamic> json,
) => _$BlockedUserModelImpl(
  id: json['id'] as String,
  displayName: json['displayName'] as String,
  photoUrl: json['photoUrl'] as String?,
  blockedAt: const LocalDateTimeConverter().fromJson(json['blockedAt']),
);

Map<String, dynamic> _$$BlockedUserModelImplToJson(
  _$BlockedUserModelImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'displayName': instance.displayName,
  'photoUrl': instance.photoUrl,
  'blockedAt': const LocalDateTimeConverter().toJson(instance.blockedAt),
};
