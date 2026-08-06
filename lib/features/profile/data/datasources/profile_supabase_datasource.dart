import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/models/country.dart';
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
  // ⚠️ TOUJOURS VIDE, ET CE N'EST PAS UN OUBLI À RÉPARER EN LE REMPLISSANT.
  //
  // Il n'existe aucune colonne de blocage sur `users` côté Supabase : le sens
  // « qui m'a bloqué » vit dans la table `blocked_users`. Ce champ n'est
  // conservé que parce que `ProfileModel` le déclare.
  //
  // Ce `[]` a coûté cher : dix endroits de l'app demandaient « cette personne
  // m'a-t-elle bloqué ? » en le lisant, et recevaient donc toujours non —
  // sans erreur, sans log. Le composeur restait actif face à quelqu'un qui
  // vous avait bloqué.
  //
  // Pour poser la question, utiliser `usersWhoBlockedMeProvider`. Ne pas
  // relire ce champ, et ne pas tenter de l'alimenter ici : il faudrait une
  // requête par profil sur `blocked_users`, alors qu'une seule suffit pour
  // toute la liste.
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
    final data =
        await _supabase.from('users').select().eq('id', userId).maybeSingle();
    if (data == null) throw ServerException('Profile not found: $userId');
    final profile = ProfileModel.fromJson(_mapProfile(data));
    _cache[userId] = profile;
    return profile;
  }

  @override
  Stream<ProfileModel> getUserStream(String userId) {
    return _supabase.from('users').stream(primaryKey: ['id']).eq('id', userId).map((
      rows,
    ) {
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
        // Même raison que `getNearbyProfiles` : une troncature sans ordre est
        // une loterie. Passé 30 correspondances, les mêmes personnes
        // pouvaient rester introuvables d'une recherche à l'autre.
        //
        // Tri sur le champ **filtré**, donc garanti présent dans chaque
        // résultat. `last_active_at` aurait paru plus utile — les gens actifs
        // d'abord — mais il manque à 7 profils sur 10 : ceux-là auraient été
        // systématiquement relégués en fin de liste, donc exclus dès que la
        // base dépasse 30 correspondances. Un tri qui écarte toujours les
        // mêmes est le défaut qu'on cherche à corriger, pas à déplacer.
        .order('display_name')
        .limit(30);
    return (data as List)
        .map((r) => ProfileModel.fromJson(_mapProfile(r)))
        .toList();
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
        // `limit(50)` sans `order` renvoyait **50 lignes arbitraires** : sans
        // ORDER BY, Postgres ne promet aucun ordre. Passé 50 membres dans la
        // boîte, on pouvait donc recevoir 50 profils périmés et zéro profil
        // récent — alors que la carte écarte ensuite tout ce qui a plus de
        // 5 minutes. Résultat possible : « aucun membre autour » alors que
        // des membres actifs étaient là.
        //
        // Trier par fraîcheur aligne la troncature sur le filtre qui suit :
        // les 50 rendus sont ceux qui ont le plus de chances d'y survivre.
        // (Trier par distance demanderait un RPC : PostgREST ne sait pas
        // calculer une distance dans un ORDER BY.)
        .order('location_updated_at', ascending: false, nullsFirst: false)
        .limit(50);
    return (data as List)
        .map((r) => ProfileModel.fromJson(_mapProfile(r)))
        .toList();
  }

  @override
  Future<List<ProfileModel>> getProfilesByCountry(String country) async {
    final data = await _supabase
        .from('users')
        .select()
        .eq('country_code', country)
        .eq('is_visible', true)
        // Même raison que `getNearbyProfiles` : une troncature non ordonnée
        // est une loterie, et le filtre de présence qui suit élimine le reste.
        .order('location_updated_at', ascending: false, nullsFirst: false)
        .limit(50);
    return (data as List)
        .map((r) => ProfileModel.fromJson(_mapProfile(r)))
        .toList();
  }

  /// Flux temps réel des profils dont la position vient de changer.
  ///
  /// La carte se contentait d'un sondage toutes les 45 s : un membre qui se
  /// déplaçait mettait jusqu'à trois quarts de minute à bouger sur l'écran des
  /// autres. `users` est déjà dans la publication `supabase_realtime`
  /// (migration `20260716120000`) avec `REPLICA IDENTITY FULL`, et la RLS
  /// s'applique au flux : un abonné ne reçoit que les lignes qu'il a le droit
  /// de lire.
  ///
  /// Aucun filtre serveur n'est posé : les filtres `postgres_changes` de
  /// Supabase sont mono-colonne, ils ne savent pas exprimer une boîte
  /// englobante. Le tri géographique se fait donc côté client. C'est tenable
  /// à l'échelle actuelle, mais **c'est la limite de ce montage** : passé
  /// quelques milliers de comptes actifs, il faudra des canaux `broadcast`
  /// découpés par cellule géographique plutôt qu'un flux table entière.
  ///
  /// Le canal est fermé quand l'abonnement au flux est annulé.
  Stream<ProfileModel> watchProfileLocationUpdates() {
    final channel = _supabase.channel('users_location_updates');
    late final StreamController<ProfileModel> controller;

    controller = StreamController<ProfileModel>(
      onCancel: () async {
        await _supabase.removeChannel(channel);
      },
    );

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'users',
          callback: (payload) {
            final row = payload.newRecord;
            if (row.isEmpty) return;
            // Une ligne `users` bouge pour bien d'autres raisons qu'un
            // déplacement (statut en ligne, compteurs, édition de profil).
            // Sans coordonnées exploitables, il n'y a rien à replacer.
            if (row['latitude'] == null || row['longitude'] == null) return;
            try {
              final profile = ProfileModel.fromJson(_mapProfile(row));
              _cache[profile.id] = profile;
              controller.add(profile);
            } catch (_) {
              // Ligne inattendue : on ignore plutôt que de casser le flux.
            }
          },
        )
        .subscribe();

    return controller.stream;
  }

  // ═══════════════════════════════════════════
  // WRITE
  // ═══════════════════════════════════════════

  @override
  Future<ProfileModel> updateProfile(ProfileModel profile) async {
    await _requireAuth();
    // upsert instead of update: the Supabase users row may not exist yet
    // (user authenticated via Firebase, row created lazily on first profile save).
    final data =
        await _supabase
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
              // La colonne attend un code ISO-2. `currentCountry` arrive du
              // géocodage inverse sous forme de LIBELLÉ (« Canada »), d'où un
              // mélange `CA`/`Canada` en base qui faisait échouer toutes les
              // comparaisons d'égalité — notamment le filtre par pays de la
              // liste des groupes. On normalise, et on ne retient la valeur
              // brute que si le pays n'est pas reconnu (mieux vaut la garder
              // que la perdre).
              'country_code': CountryExtension.toIsoCode(
                    profile.currentCountry ?? profile.countryCode,
                  ) ??
                  profile.currentCountry ??
                  profile.countryCode,
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
    await _supabase
        .from('users')
        .update({
          'latitude': latitude,
          'longitude': longitude,
          'location_updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', userId);
  }

  @override
  Future<void> updateLastLogin(String userId) async {
    await _requireAuth();
    await _supabase
        .from('users')
        .update({'last_active_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', userId);
  }

  @override
  Future<void> updateOnlineStatus(
    String userId,
    bool isOnline,
    DateTime lastSeen,
  ) async {
    await _requireAuth();
    await _supabase
        .from('users')
        .update({
          'is_online': isOnline,
          'last_seen_at': lastSeen.toUtc().toIso8601String(),
        })
        .eq('id', userId);
  }

  @override
  Future<void> updateOnlineStatusVisibility(
    String userId,
    bool showStatus,
  ) async {
    await _requireAuth();
    await _supabase
        .from('users')
        .update({'show_online_status': showStatus})
        .eq('id', userId);
  }

  @override
  Future<void> updateNotifyLocalEvents(String userId, bool enabled) async {
    await _requireAuth();
    await _supabase
        .from('users')
        .update({'notify_local_events': enabled})
        .eq('id', userId);
  }

  @override
  Future<void> updateNotificationPrefs(
    String userId,
    Map<String, bool> prefs,
  ) async {
    await _requireAuth();
    await _supabase
        .from('users')
        .update({'notification_prefs': prefs})
        .eq('id', userId);
  }

  Future<void> updateShowMessagePreview(String userId, bool show) async {
    await _requireAuth();
    await _supabase
        .from('users')
        .update({'show_message_preview': show})
        .eq('id', userId);
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
