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
  createdAt:
      json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
  lastLoginAt:
      json['lastLoginAt'] == null
          ? null
          : DateTime.parse(json['lastLoginAt'] as String),
  isOnline: json['isOnline'] as bool? ?? false,
  lastSeen:
      json['lastSeen'] == null
          ? null
          : DateTime.parse(json['lastSeen'] as String),
  showOnlineStatus: json['showOnlineStatus'] as bool? ?? true,
  locationUpdatedAt:
      json['locationUpdatedAt'] == null
          ? null
          : DateTime.parse(json['locationUpdatedAt'] as String),
);

Map<String, dynamic> _$$ProfileModelImplToJson(_$ProfileModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'email': instance.email,
      'displayName': instance.displayName,
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
      'createdAt': instance.createdAt?.toIso8601String(),
      'lastLoginAt': instance.lastLoginAt?.toIso8601String(),
      'isOnline': instance.isOnline,
      'lastSeen': instance.lastSeen?.toIso8601String(),
      'showOnlineStatus': instance.showOnlineStatus,
      'locationUpdatedAt': instance.locationUpdatedAt?.toIso8601String(),
    };
