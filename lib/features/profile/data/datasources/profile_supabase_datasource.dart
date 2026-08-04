import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/supabase_auth_bridge.dart';
import '../models/profile_model.dart';
import 'profile_remote_datasource.dart';

Map<String, dynamic> _mapProfile(Map<String, dynamic> row) => {
  'id': row['id'],
  'email': row['email'],
  'displayName': row['display_name'],
  'handle': row['handle'],
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

  /// Garde d'authentification, injectable pour les tests.
  ///
  /// Une callback plutôt qu'un [SupabaseAuthBridge] : son constructeur est
  /// privé, donc un double de test ne pourrait pas en hériter.
  final Future<bool> Function() _ensureAuth;

  ProfileSupabaseDataSource({
    SupabaseClient? supabase,
    Future<bool> Function()? ensureAuth,
  }) : _clientOverride = supabase,
       _ensureAuth =
           ensureAuth ?? SupabaseAuthBridge.instance.ensureAuthenticated;

  /// Garde obligatoire avant toute écriture.
  ///
  /// Sans session Supabase valide, la RLS rejette l'UPDATE *silencieusement*
  /// (204, 0 ligne modifiée, aucune exception) : le réglage semble enregistré
  /// dans l'UI alors que rien n'a persisté.
  Future<void> _requireAuth() async {
    if (!await _ensureAuth()) {
      throw ServerException('Session Supabase non établie – reconnectez-vous');
    }
  }

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
    await _requireAuth();
    // upsert instead of update: the Supabase users row may not exist yet
    // (user authenticated via Firebase, row created lazily on first profile save).
    final data = await _supabase
        .from('users')
        .upsert({
          'id': profile.id,
          'display_name': profile.displayName,
          if (profile.handle != null) 'handle': profile.handle,
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
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .select()
        .maybeSingle();
    // La garde ci-dessus a déjà écarté la cause « pas de session ». Si l'upsert
    // ne renvoie toujours rien, c'est la RLS qui refuse la ligne elle-même.
    if (data == null) {
      throw ServerException('Écriture refusée pour le profil ${profile.id}');
    }
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
    await _requireAuth();
    await _supabase.from('users').update({
      'latitude': latitude,
      'longitude': longitude,
      'location_updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', userId);
  }

  @override
  Future<void> updateLastLogin(String userId) async {
    await _requireAuth();
    await _supabase.from('users').update({
      'last_active_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', userId);
  }

  @override
  Future<void> updateOnlineStatus(
    String userId,
    bool isOnline,
    DateTime lastSeen,
  ) async {
    await _requireAuth();
    await _supabase.from('users').update({
      'is_online': isOnline,
      'last_seen_at': lastSeen.toUtc().toIso8601String(),
    }).eq('id', userId);
  }

  @override
  Future<void> updateOnlineStatusVisibility(String userId, bool showStatus) async {
    await _requireAuth();
    await _supabase.from('users').update({
      'show_online_status': showStatus,
    }).eq('id', userId);
  }

  @override
  Future<void> updateNotifyLocalEvents(String userId, bool enabled) async {
    await _requireAuth();
    await _supabase.from('users').update({
      'notify_local_events': enabled,
    }).eq('id', userId);
  }

  Future<void> updateShowMessagePreview(String userId, bool show) async {
    await _requireAuth();
    await _supabase.from('users').update({
      'show_message_preview': show,
    }).eq('id', userId);
  }

  @override
  ProfileModel? getCachedProfile(String userId) => _cache[userId];

  @override
  Future<bool> isHandleAvailable(String handle, {String? excludeUserId}) async {
    final normalized = handle.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    try {
      // ilike insensible à la casse ; on ne récupère que l'id pour le test.
      final rows = await _supabase
          .from('users')
          .select('id')
          .ilike('handle', normalized)
          .limit(1);
      if ((rows as List).isEmpty) return true;
      return (rows.first as Map)['id'] == excludeUserId;
    } catch (_) {
      // Erreur réseau : ne pas bloquer, la contrainte UNIQUE serveur tranchera.
      return true;
    }
  }
}
