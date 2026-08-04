// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ProfileModelImpl _$$ProfileModelImplFromJson(
  Map<String, dynamic> json,
) => _$ProfileModelImpl(
  id: json['id'] as String,
  email: json['email'] as String?,
  displayName: json['displayName'] as String?,
  handle: json['handle'] as String?,
  photoUrl: json['photoUrl'] as String?,
  phoneNumber: json['phoneNumber'] as String?,
  bio: json['bio'] as String?,
  profession: json['profession'] as String?,
  currentCity: json['currentCity'] as String?,
  currentCountry: json['currentCountry'] as String?,
  currentRegion: json['currentRegion'] as String?,
  countryCode: json['countryCode'] as String?,
  originRegion: json['originRegion'] as String?,
  originCity: json['originCity'] as String?,
  latitude: (json['latitude'] as num?)?.toDouble(),
  longitude: (json['longitude'] as num?)?.toDouble(),
  isVisible: json['isVisible'] as bool? ?? true,
  notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
  shareLocation: json['shareLocation'] as bool? ?? true,
  phoneVisibility: json['phoneVisibility'] as String? ?? 'everyone',
  isPhoneVerified: json['isPhoneVerified'] as bool? ?? false,
  interests:
      (json['interests'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  skills:
      (json['skills'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  languages:
      (json['languages'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  connectionsCount: (json['connectionsCount'] as num?)?.toInt() ?? 0,
  groupsCount: (json['groupsCount'] as num?)?.toInt() ?? 0,
  eventsCount: (json['eventsCount'] as num?)?.toInt() ?? 0,
  createdAt: const LocalDateTimeNullableConverter().fromJson(json['createdAt']),
  lastLoginAt: const LocalDateTimeNullableConverter().fromJson(
    json['lastLoginAt'],
  ),
  isOnline: json['isOnline'] as bool? ?? false,
  lastSeen: const LocalDateTimeNullableConverter().fromJson(json['lastSeen']),
  showOnlineStatus: json['showOnlineStatus'] as bool? ?? true,
  locationUpdatedAt: const LocalDateTimeNullableConverter().fromJson(
    json['locationUpdatedAt'],
  ),
  blockedByUserIds:
      (json['blockedByUserIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
);

Map<String, dynamic> _$$ProfileModelImplToJson(
  _$ProfileModelImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'email': instance.email,
  'displayName': instance.displayName,
  'handle': instance.handle,
  'photoUrl': instance.photoUrl,
  'phoneNumber': instance.phoneNumber,
  'bio': instance.bio,
  'profession': instance.profession,
  'currentCity': instance.currentCity,
  'currentCountry': instance.currentCountry,
  'currentRegion': instance.currentRegion,
  'countryCode': instance.countryCode,
  'originRegion': instance.originRegion,
  'originCity': instance.originCity,
  'latitude': instance.latitude,
  'longitude': instance.longitude,
  'isVisible': instance.isVisible,
  'notificationsEnabled': instance.notificationsEnabled,
  'shareLocation': instance.shareLocation,
  'phoneVisibility': instance.phoneVisibility,
  'isPhoneVerified': instance.isPhoneVerified,
  'interests': instance.interests,
  'skills': instance.skills,
  'languages': instance.languages,
  'connectionsCount': instance.connectionsCount,
  'groupsCount': instance.groupsCount,
  'eventsCount': instance.eventsCount,
  'createdAt': const LocalDateTimeNullableConverter().toJson(
    instance.createdAt,
  ),
  'lastLoginAt': const LocalDateTimeNullableConverter().toJson(
    instance.lastLoginAt,
  ),
  'isOnline': instance.isOnline,
  'lastSeen': const LocalDateTimeNullableConverter().toJson(instance.lastSeen),
  'showOnlineStatus': instance.showOnlineStatus,
  'locationUpdatedAt': const LocalDateTimeNullableConverter().toJson(
    instance.locationUpdatedAt,
  ),
  'blockedByUserIds': instance.blockedByUserIds,
};
