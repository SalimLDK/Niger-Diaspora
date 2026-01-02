import 'package:freezed_annotation/freezed_annotation.dart';

part 'home_content.freezed.dart';

/// Entité représentant le contenu de la page d'accueil
@freezed
class HomeContent with _$HomeContent {
  const factory HomeContent({
    required HomeStats stats,
    required List<NearbyMember> nearbyMembers,
    required List<UpcomingEvent> upcomingEvents,
    required List<QuickAction> quickActions,
    DateTime? lastUpdated,
  }) = _HomeContent;
}

/// Statistiques affichées sur la page d'accueil
@freezed
class HomeStats with _$HomeStats {
  const factory HomeStats({
    @Default(0) int totalMembers,
    @Default(0) int nearbyMembersCount,
    @Default(0) int upcomingEventsCount,
    @Default(0) int groupsCount,
    @Default(0) int unreadMessages,
    @Default(0) int pendingFriendRequests,
  }) = _HomeStats;
}

/// Membre proche affiché sur la page d'accueil
@freezed
class NearbyMember with _$NearbyMember {
  const factory NearbyMember({
    required String id,
    required String displayName,
    String? photoUrl,
    String? city,
    String? country,
    double? distanceKm,
    DateTime? lastSeen,
    @Default(false) bool isOnline,
  }) = _NearbyMember;
}

/// Événement à venir affiché sur la page d'accueil
@freezed
class UpcomingEvent with _$UpcomingEvent {
  const factory UpcomingEvent({
    required String id,
    required String title,
    required DateTime startDate,
    String? imageUrl,
    String? location,
    @Default(0) int attendeesCount,
    @Default(false) bool isAttending,
  }) = _UpcomingEvent;
}

/// Action rapide sur la page d'accueil
@freezed
class QuickAction with _$QuickAction {
  const factory QuickAction({
    required String id,
    required String label,
    required String icon,
    required String route,
    @Default(0) int badgeCount,
    @Default(true) bool isEnabled,
  }) = _QuickAction;
}
