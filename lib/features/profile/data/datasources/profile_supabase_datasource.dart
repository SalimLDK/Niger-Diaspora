import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/profile_model.dart';
import 'profile_remote_datasource.dart';

Map<String, dynamic> _mapProfile(Map<String, dynamic> row) => {
  'id': row['id'],
  'email': row['email'],
  'displayName': row['display_name'],
  'photoUrl': row['avatar_url'],
  'phoneNumber': row['phone_number'],
  'bio': row['bio'],
  'profession': row['profession'],
  'currentCity': row['city'],
  'currentCountry': row['country_code'],
  'currentRegion': row['current_region'],
  'countryCode': row['country_code'],
  'originRegion': row['origin_region'],
  'originCity': row['origin_city'],
  'latitude': (row['latitude'] as num?)?.toDouble(),
  'longitude': (row['longitude'] as num?)?.toDouble(),
  'isVisible': row['is_visible'] ?? true,
  'notificationsEnabled': row['notifications_enabled'] ?? true,
  'shareLocation': row['share_location'] ?? false,
  'phoneVisibility': row['phone_visibility'] ?? 'private',
  'isPhoneVerified': row['is_phone_verified'] ?? false,
  'interests': (row['interests'] as List?)?.cast<String>() ?? [],
  'skills': (row['skills'] as List?)?.cast<String>() ?? [],
  'languages': (row['languages'] as List?)?.cast<String>() ?? [],
  'connectionsCount': row['connections_count'] ?? 0,
  'groupsCount': row['groups_count'] ?? 0,
  'eventsCount': row['events_count'] ?? 0,
  'isOnline': row['is_online'] ?? false,
  'lastSeen': row['last_seen_at'],
  'showOnlineStatus': row['show_online_status'] ?? true,
  'locationUpdatedAt': row['location_updated_at'],
  'isAdmin': row['is_admin'] ?? false,
  'isVerified': row['is_verified'] ?? false,
  'createdAt': row['created_at'],
  'lastLoginAt': row['last_active_at'],
  'fcmTokens': (row['fcm_tokens'] as List?)?.cast<String>() ?? [],
  'blockedByUserIds': [],
};

class ProfileSupabaseDataSource implements ProfileRemoteDataSource {
  final SupabaseClient? _clientOverride;
  SupabaseClient get _supabase => _clientOverride ?? Supabase.instance.client;
  final Map<String, ProfileModel> _cache = {};

  ProfileSupabaseDataSource({SupabaseClient? supabase}) : _clientOverride = supabase;

  // ═══════════════════════════════════════════
  // READ
  // ═══════════════════════════════════════════

  @override
  Future<ProfileModel> getProfile(String userId) async {
    final data = await _supabase
        .from('users')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (data == null) throw ServerException('Profile not found: $userId');
    final profile = ProfileModel.fromJson(_mapProfile(data));
    _cache[userId] = profile;
    return profile;
  }

  @override
  Stream<ProfileModel> getUserStream(String userId) {
    return _supabase
        .from('users')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .map((rows) {
          // Ligne absente = ressource introuvable (compte supprimé / invisible).
          // NotFoundException est distinct des autres erreurs pour que la couche
          // présentation ne confonde pas « supprimé » avec « échec de chargement ».
          if (rows.isEmpty) throw NotFoundException('User $userId not found');
          final profile = ProfileModel.fromJson(_mapProfile(rows.first));
          _cache[userId] = profile;
          return profile;
        });
  }

  @override
  Future<List<ProfileModel>> searchProfiles(String query) async {
    final data = await _supabase
        .from('users')
        .select()
        .eq('is_visible', true)
        .ilike('display_name', '%$query%')
        .limit(30);
    return (data as List).map((r) => ProfileModel.fromJson(_mapProfile(r))).toList();
  }

  @override
  Future<List<ProfileModel>> getNearbyProfiles(
    double latitude,
    double longitude,
    double radiusKm,
  ) async {
    final delta = radiusKm / 111.0;
    final data = await _supabase
        .from('users')
        .select()
        .eq('is_visible', true)
        .eq('share_location', true)
        .gte('latitude', latitude - delta)
        .lte('latitude', latitude + delta)
        .gte('longitude', longitude - delta)
        .lte('longitude', longitude + delta)
        .limit(50);
    return (data as List).map((r) => ProfileModel.fromJson(_mapProfile(r))).toList();
  }

  @override
  Future<List<ProfileModel>> getProfilesByCountry(String country) async {
    final data = await _supabase
        .from('users')
        .select()
        .eq('country_code', country)
        .eq('is_visible', true)
        .limit(50);
    return (data as List).map((r) => ProfileModel.fromJson(_mapProfile(r))).toList();
  }

  // ═══════════════════════════════════════════
  // WRITE
  // ═══════════════════════════════════════════

  @override
  Future<ProfileModel> updateProfile(ProfileModel profile) async {
    // upsert instead of update: the Supabase users row may not exist yet
    // (user authenticated via Firebase, row created lazily on first profile save).
    final data = await _supabase
        .from('users')
        .upsert({
          'id': profile.id,
          'display_name': profile.displayName,
          'avatar_url': profile.photoUrl,
          'phone_number': profile.phoneNumber,
          'bio': profile.bio,
          'profession': profile.profession,
          'city': profile.currentCity,
          'country_code': profile.currentCountry ?? profile.countryCode,
          'current_region': profile.currentRegion,
          'origin_region': profile.originRegion,
          'origin_city': profile.originCity,
          'is_visible': profile.isVisible,
          'notifications_enabled': profile.notificationsEnabled,
          'share_location': profile.shareLocation,
          'phone_visibility': profile.phoneVisibility,
          'interests': profile.interests,
          'skills': profile.skills,
          'languages': profile.languages,
          'show_online_status': profile.showOnlineStatus,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .select()
        .maybeSingle();
    if (data == null) throw ServerException('Upsert returned no row for: ${profile.id}');
    return ProfileModel.fromJson(_mapProfile(data));
  }

  @override
  Future<String> uploadProfilePhoto(String userId, String filePath) async {
    // Firebase Storage gardé pour les uploads media — retourner le chemin tel quel
    throw UnimplementedError('Photo upload uses Firebase Storage');
  }

  @override
  Future<void> updateLocation(
    String userId,
    double latitude,
    double longitude,
  ) async {
    await _supabase.from('users').update({
      'latitude': latitude,
      'longitude': longitude,
      'location_updated_at': DateTime.now().toIso8601String(),
    }).eq('id', userId);
  }

  @override
  Future<void> updateLastLogin(String userId) async {
    await _supabase.from('users').update({
      'last_active_at': DateTime.now().toIso8601String(),
    }).eq('id', userId);
  }

  @override
  Future<void> updateOnlineStatus(
    String userId,
    bool isOnline,
    DateTime lastSeen,
  ) async {
    await _supabase.from('users').update({
      'is_online': isOnline,
      'last_seen_at': lastSeen.toIso8601String(),
    }).eq('id', userId);
  }

  @override
  Future<void> updateOnlineStatusVisibility(String userId, bool showStatus) async {
    await _supabase.from('users').update({
      'show_online_status': showStatus,
    }).eq('id', userId);
  }

  @override
  Future<void> updateNotifyLocalEvents(String userId, bool enabled) async {
    await _supabase.from('users').update({
      'notify_local_events': enabled,
    }).eq('id', userId);
  }

  @override
  Future<void> updateShowMessagePreview(String userId, bool show) async {
    await _supabase.from('users').update({
      'show_message_preview': show,
    }).eq('id', userId);
  }

  @override
  ProfileModel? getCachedProfile(String userId) => _cache[userId];
}
