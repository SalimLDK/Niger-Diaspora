// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'home_content_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$HomeContentModelImpl _$$HomeContentModelImplFromJson(
  Map<String, dynamic> json,
) => _$HomeContentModelImpl(
  stats: HomeStatsModel.fromJson(json['stats'] as Map<String, dynamic>),
  nearbyMembers:
      (json['nearbyMembers'] as List<dynamic>?)
          ?.map((e) => NearbyMemberModel.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  upcomingEvents:
      (json['upcomingEvents'] as List<dynamic>?)
          ?.map((e) => UpcomingEventModel.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  quickActions:
      (json['quickActions'] as List<dynamic>?)
          ?.map((e) => QuickActionModel.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  lastUpdated: json['lastUpdated'] as String?,
);

Map<String, dynamic> _$$HomeContentModelImplToJson(
  _$HomeContentModelImpl instance,
) => <String, dynamic>{
  'stats': instance.stats,
  'nearbyMembers': instance.nearbyMembers,
  'upcomingEvents': instance.upcomingEvents,
  'quickActions': instance.quickActions,
  'lastUpdated': instance.lastUpdated,
};

_$HomeStatsModelImpl _$$HomeStatsModelImplFromJson(Map<String, dynamic> json) =>
    _$HomeStatsModelImpl(
      totalMembers: (json['totalMembers'] as num?)?.toInt() ?? 0,
      nearbyMembersCount: (json['nearbyMembersCount'] as num?)?.toInt() ?? 0,
      upcomingEventsCount: (json['upcomingEventsCount'] as num?)?.toInt() ?? 0,
      groupsCount: (json['groupsCount'] as num?)?.toInt() ?? 0,
      unreadMessages: (json['unreadMessages'] as num?)?.toInt() ?? 0,
      pendingFriendRequests:
          (json['pendingFriendRequests'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$$HomeStatsModelImplToJson(
  _$HomeStatsModelImpl instance,
) => <String, dynamic>{
  'totalMembers': instance.totalMembers,
  'nearbyMembersCount': instance.nearbyMembersCount,
  'upcomingEventsCount': instance.upcomingEventsCount,
  'groupsCount': instance.groupsCount,
  'unreadMessages': instance.unreadMessages,
  'pendingFriendRequests': instance.pendingFriendRequests,
};

_$NearbyMemberModelImpl _$$NearbyMemberModelImplFromJson(
  Map<String, dynamic> json,
) => _$NearbyMemberModelImpl(
  id: json['id'] as String,
  displayName: json['displayName'] as String,
  photoUrl: json['photoUrl'] as String?,
  city: json['city'] as String?,
  country: json['country'] as String?,
  distanceKm: (json['distanceKm'] as num?)?.toDouble(),
  lastSeen: json['lastSeen'] as String?,
  isOnline: json['isOnline'] as bool? ?? false,
);

Map<String, dynamic> _$$NearbyMemberModelImplToJson(
  _$NearbyMemberModelImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'displayName': instance.displayName,
  'photoUrl': instance.photoUrl,
  'city': instance.city,
  'country': instance.country,
  'distanceKm': instance.distanceKm,
  'lastSeen': instance.lastSeen,
  'isOnline': instance.isOnline,
};

_$UpcomingEventModelImpl _$$UpcomingEventModelImplFromJson(
  Map<String, dynamic> json,
) => _$UpcomingEventModelImpl(
  id: json['id'] as String,
  title: json['title'] as String,
  startDate: json['startDate'] as String,
  imageUrl: json['imageUrl'] as String?,
  location: json['location'] as String?,
  attendeesCount: (json['attendeesCount'] as num?)?.toInt() ?? 0,
  isAttending: json['isAttending'] as bool? ?? false,
);

Map<String, dynamic> _$$UpcomingEventModelImplToJson(
  _$UpcomingEventModelImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'startDate': instance.startDate,
  'imageUrl': instance.imageUrl,
  'location': instance.location,
  'attendeesCount': instance.attendeesCount,
  'isAttending': instance.isAttending,
};

_$QuickActionModelImpl _$$QuickActionModelImplFromJson(
  Map<String, dynamic> json,
) => _$QuickActionModelImpl(
  id: json['id'] as String,
  label: json['label'] as String,
  icon: json['icon'] as String,
  route: json['route'] as String,
  badgeCount: (json['badgeCount'] as num?)?.toInt() ?? 0,
  isEnabled: json['isEnabled'] as bool? ?? true,
);

Map<String, dynamic> _$$QuickActionModelImplToJson(
  _$QuickActionModelImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'label': instance.label,
  'icon': instance.icon,
  'route': instance.route,
  'badgeCount': instance.badgeCount,
  'isEnabled': instance.isEnabled,
};
