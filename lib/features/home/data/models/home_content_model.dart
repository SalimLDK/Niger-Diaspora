import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/home_content.dart';

part 'home_content_model.freezed.dart';
part 'home_content_model.g.dart';

/// Modèle de données pour le contenu Home
@freezed
class HomeContentModel with _$HomeContentModel {
  const HomeContentModel._();

  const factory HomeContentModel({
    required HomeStatsModel stats,
    @Default([]) List<NearbyMemberModel> nearbyMembers,
    @Default([]) List<UpcomingEventModel> upcomingEvents,
    @Default([]) List<QuickActionModel> quickActions,
    String? lastUpdated,
  }) = _HomeContentModel;

  factory HomeContentModel.fromJson(Map<String, dynamic> json) =>
      _$HomeContentModelFromJson(json);

  /// Convertit en entité domain
  HomeContent toEntity() => HomeContent(
    stats: stats.toEntity(),
    nearbyMembers: nearbyMembers.map((m) => m.toEntity()).toList(),
    upcomingEvents: upcomingEvents.map((e) => e.toEntity()).toList(),
    quickActions: quickActions.map((a) => a.toEntity()).toList(),
    lastUpdated: lastUpdated != null ? DateTime.tryParse(lastUpdated!)?.toLocal() : null,
  );

  /// Crée depuis une entité domain
  factory HomeContentModel.fromEntity(HomeContent entity) => HomeContentModel(
    stats: HomeStatsModel.fromEntity(entity.stats),
    nearbyMembers: entity.nearbyMembers
        .map((m) => NearbyMemberModel.fromEntity(m))
        .toList(),
    upcomingEvents: entity.upcomingEvents
        .map((e) => UpcomingEventModel.fromEntity(e))
        .toList(),
    quickActions: entity.quickActions
        .map((a) => QuickActionModel.fromEntity(a))
        .toList(),
    lastUpdated: entity.lastUpdated?.toUtc().toIso8601String(),
  );
}

@freezed
class HomeStatsModel with _$HomeStatsModel {
  const HomeStatsModel._();

  const factory HomeStatsModel({
    @Default(0) int totalMembers,
    @Default(0) int nearbyMembersCount,
    @Default(0) int upcomingEventsCount,
    @Default(0) int groupsCount,
    @Default(0) int unreadMessages,
    @Default(0) int pendingFriendRequests,
  }) = _HomeStatsModel;

  factory HomeStatsModel.fromJson(Map<String, dynamic> json) =>
      _$HomeStatsModelFromJson(json);

  HomeStats toEntity() => HomeStats(
    totalMembers: totalMembers,
    nearbyMembersCount: nearbyMembersCount,
    upcomingEventsCount: upcomingEventsCount,
    groupsCount: groupsCount,
    unreadMessages: unreadMessages,
    pendingFriendRequests: pendingFriendRequests,
  );

  factory HomeStatsModel.fromEntity(HomeStats entity) => HomeStatsModel(
    totalMembers: entity.totalMembers,
    nearbyMembersCount: entity.nearbyMembersCount,
    upcomingEventsCount: entity.upcomingEventsCount,
    groupsCount: entity.groupsCount,
    unreadMessages: entity.unreadMessages,
    pendingFriendRequests: entity.pendingFriendRequests,
  );
}

@freezed
class NearbyMemberModel with _$NearbyMemberModel {
  const NearbyMemberModel._();

  const factory NearbyMemberModel({
    required String id,
    required String displayName,
    String? photoUrl,
    String? city,
    String? country,
    double? distanceKm,
    String? lastSeen,
    @Default(false) bool isOnline,
  }) = _NearbyMemberModel;

  factory NearbyMemberModel.fromJson(Map<String, dynamic> json) =>
      _$NearbyMemberModelFromJson(json);

  NearbyMember toEntity() => NearbyMember(
    id: id,
    displayName: displayName,
    photoUrl: photoUrl,
    city: city,
    country: country,
    distanceKm: distanceKm,
    lastSeen: lastSeen != null ? DateTime.tryParse(lastSeen!)?.toLocal() : null,
    isOnline: isOnline,
  );

  factory NearbyMemberModel.fromEntity(NearbyMember entity) => NearbyMemberModel(
    id: entity.id,
    displayName: entity.displayName,
    photoUrl: entity.photoUrl,
    city: entity.city,
    country: entity.country,
    distanceKm: entity.distanceKm,
    lastSeen: entity.lastSeen?.toUtc().toIso8601String(),
    isOnline: entity.isOnline,
  );
}

@freezed
class UpcomingEventModel with _$UpcomingEventModel {
  const UpcomingEventModel._();

  const factory UpcomingEventModel({
    required String id,
    required String title,
    required String startDate,
    String? imageUrl,
    String? location,
    @Default(0) int attendeesCount,
    @Default(false) bool isAttending,
  }) = _UpcomingEventModel;

  factory UpcomingEventModel.fromJson(Map<String, dynamic> json) =>
      _$UpcomingEventModelFromJson(json);

  UpcomingEvent toEntity() => UpcomingEvent(
    id: id,
    title: title,
    startDate: DateTime.parse(startDate).toLocal(),
    imageUrl: imageUrl,
    location: location,
    attendeesCount: attendeesCount,
    isAttending: isAttending,
  );

  factory UpcomingEventModel.fromEntity(UpcomingEvent entity) =>
      UpcomingEventModel(
        id: entity.id,
        title: entity.title,
        startDate: entity.startDate.toUtc().toIso8601String(),
        imageUrl: entity.imageUrl,
        location: entity.location,
        attendeesCount: entity.attendeesCount,
        isAttending: entity.isAttending,
      );
}

@freezed
class QuickActionModel with _$QuickActionModel {
  const QuickActionModel._();

  const factory QuickActionModel({
    required String id,
    required String label,
    required String icon,
    required String route,
    @Default(0) int badgeCount,
    @Default(true) bool isEnabled,
  }) = _QuickActionModel;

  factory QuickActionModel.fromJson(Map<String, dynamic> json) =>
      _$QuickActionModelFromJson(json);

  QuickAction toEntity() => QuickAction(
    id: id,
    label: label,
    icon: icon,
    route: route,
    badgeCount: badgeCount,
    isEnabled: isEnabled,
  );

  factory QuickActionModel.fromEntity(QuickAction entity) => QuickActionModel(
    id: entity.id,
    label: entity.label,
    icon: entity.icon,
    route: entity.route,
    badgeCount: entity.badgeCount,
    isEnabled: entity.isEnabled,
  );
}
