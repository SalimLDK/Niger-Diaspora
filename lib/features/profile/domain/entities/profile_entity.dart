import 'package:freezed_annotation/freezed_annotation.dart';

part 'profile_entity.freezed.dart';

@freezed
class ProfileEntity with _$ProfileEntity {
  const factory ProfileEntity({
    required String id,
    String? email,
    String? displayName,
    // Poignée publique unique (@handle), §16f/10c. null tant que non choisie.
    String? handle,
    String? photoUrl,
    String? phoneNumber,
    String? bio,
    String? profession,
    String? currentCity,
    String? currentCountry,
    String? currentRegion,
    String? countryCode,
    String? originRegion,
    String? originCity,
    double? latitude,
    double? longitude,
    @Default(true) bool isVisible,
    @Default(true) bool notificationsEnabled,
    @Default(true) bool shareLocation,
    @Default('everyone') String phoneVisibility,
    @Default(false) bool isPhoneVerified,
    @Default(false) bool isVerified,
    @Default([]) List<String> interests,
    @Default([]) List<String> skills,
    @Default([]) List<String> languages,
    @Default(0) int connectionsCount,
    @Default(0) int groupsCount,
    @Default(0) int eventsCount,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    @Default(false) bool isOnline,
    DateTime? lastSeen,
    @Default(true) bool showOnlineStatus,
    DateTime? locationUpdatedAt,
    @Default([]) List<String> blockedByUserIds,
  }) = _ProfileEntity;
}
