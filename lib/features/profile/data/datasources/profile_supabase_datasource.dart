import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/constants/profile_options.dart';
import '../../../../core/services/cache_service.dart';
import '../../../../core/services/image_upload_service.dart';
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
  'villeId': row['ville_id'],
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

  /// Variante bornée pour les lectures — voir
  /// [SupabaseAuthBridge.ensureReadableSession]. Séparée de [_ensureAuth] :
  /// une écriture doit échouer si la session n'est pas établie, une lecture
  /// doit seulement éviter de partir en anon, pas bloquer l'écran.
  final Future<bool> Function() _ensureReadableAuth;

  ProfileSupabaseDataSource({
    SupabaseClient? supabase,
    Future<bool> Function()? ensureAuth,
    Future<bool> Function()? ensureReadableAuth,
  }) : _clientOverride = supabase,
       _ensureAuth =
           ensureAuth ?? SupabaseAuthBridge.instance.ensureAuthenticated,
       _ensureReadableAuth =
           ensureReadableAuth ?? SupabaseAuthBridge.instance.ensureReadableSession;

  /// Garde obligatoire avant toute écriture.
  ///
  /// Sans session Supabase valide, la RLS rejette l'UPDATE *silencieusement*
  /// (204, 0 ligne modifiée, aucune exception) : le réglage semble enregistré
  /// dans l'UI alors que rien n'a persisté.
  Future<void> _requireAuth() async {
    if (!await _ensureAuth()) {
      throw ServerException('Session non établie – reconnectez-vous');
    }
  }

  // ═══════════════════════════════════════════
  // READ
  // ═══════════════════════════════════════════

  @override
  Future<ProfileModel> getProfile(String userId) async {
    // Session non confirmée (fenêtre `_startFromLocalSession`) : attendre
    // brièvement plutôt que d'interroger en anon. `ProfileNotifier` a déjà un
    // cache-first + repli silencieux sur `_fetchAndRefresh` — cette exception
    // rejoint le chemin d'erreur existant, pas un nouveau.
    if (!await _ensureReadableAuth()) {
      throw ServerException('Session non établie – réessayez');
    }
    final data =
        await _supabase.from('users').select().eq('id', userId).maybeSingle();
    if (data == null) throw ServerException('Profile not found: $userId');
    final profile = ProfileModel.fromJson(_mapProfile(data));
    _memoriser(profile);
    return profile;
  }

  @override
  Stream<ProfileModel> getUserStream(String userId) async* {
    // Même garde que [getProfile], et pour une raison plus coûteuse ici : la
    // policy `users_select` vaut pour le rôle `public`, donc une lecture en
    // anon **réussit** en ne renvoyant simplement aucune ligne dès que le
    // profil est privé. Sans cette attente, le `.stream()` démarrait pendant
    // la fenêtre d'établissement de la session, l'absence était lue comme
    // « compte supprimé », et chaque ligne de la liste des discussions
    // affichait « Utilisateur » avec un avatar à initiale à la place du
    // correspondant — par intermittence, au gré de la course.
    await _ensureReadableAuth();

    yield* _supabase
        .from('users')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .asyncMap((rows) async {
          if (rows.isEmpty) return await _profilAbsent(userId);
          final profile = ProfileModel.fromJson(_mapProfile(rows.first));
          _memoriser(profile);
          return profile;
        });
  }

  /// Le flux n'a renvoyé aucune ligne : tranche entre « compte supprimé » et
  /// « lu sans session ».
  ///
  /// Les deux se ressemblent parfaitement au niveau du `.stream()`, et les
  /// confondre est visible à l'écran : `NotFoundException` devient un
  /// `NotFoundFailure`, que `userStreamProvider` convertit en `null` — soit
  /// une **donnée** qui écrase le nom déjà affiché, là où une erreur l'aurait
  /// laissé en place. On ne conclut donc à l'absence qu'après une relecture
  /// session confirmée.
  Future<ProfileModel> _profilAbsent(String userId) async {
    if (await _ensureReadableAuth()) {
      final data =
          await _supabase.from('users').select().eq('id', userId).maybeSingle();
      if (data != null) {
        final profile = ProfileModel.fromJson(_mapProfile(data));
        _memoriser(profile);
        return profile;
      }
      throw NotFoundException('User $userId not found');
    }
    // Session toujours pas établie : on ne sait rien. Le dernier profil connu
    // vaut mieux qu'un faux « supprimé » ; à défaut, une erreur de chargement,
    // qui laisse l'affichage précédent intact.
    final connu = _cache[userId];
    if (connu != null) return connu;
    throw ServerException('Session non établie – réessayez');
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

  /// Taille d'un lot d'identifiants par requête.
  ///
  /// PostgREST passe le filtre dans l'URL (`id=in.(…)`) : les identifiants
  /// hérités de Firebase font 28 caractères, donc 100 tiennent en ~3 ko, loin
  /// des limites d'un serveur HTTP. Au-delà, le filtre finirait par être
  /// tronqué — et une URL tronquée ne rend pas une erreur, elle rend d'autres
  /// lignes.
  static const int _tailleLotIds = 100;

  @override
  Future<List<ProfileModel>> getProfilesByIds(List<String> ids) async {
    final uniques = <String>{
      for (final id in ids)
        if (id.trim().isNotEmpty) id,
    }.toList();
    if (uniques.isEmpty) return const [];

    // Même garde que [getProfile] : sans session établie, `users_select` vaut
    // pour le rôle `public` et la lecture **réussit** en ne rendant aucune
    // ligne. Tous les profils passeraient alors pour introuvables.
    if (!await _ensureReadableAuth()) {
      throw ServerException('Session non établie – réessayez');
    }

    final profils = <ProfileModel>[];
    for (var debut = 0; debut < uniques.length; debut += _tailleLotIds) {
      final reste = debut + _tailleLotIds;
      final fin = reste < uniques.length ? reste : uniques.length;
      final data = await _supabase
          .from('users')
          .select()
          .inFilter('id', uniques.sublist(debut, fin));
      for (final row in data as List) {
        final profil = ProfileModel.fromJson(
          _mapProfile(row as Map<String, dynamic>),
        );
        _memoriser(profil);
        profils.add(profil);
      }
    }
    return profils;
  }

  @override
  Future<List<ProfileModel>> getNearbyProfiles(
    double latitude,
    double longitude,
    double radiusKm,
  ) async {
    // Session non confirmée (fenêtre `_startFromLocalSession`) : voir
    // getProfile ci-dessus pour le contexte complet.
    if (!await _ensureReadableAuth()) {
      throw ServerException('Session non établie – réessayez');
    }
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
              _memoriser(profile);
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
              // La ligne du référentiel que le profil désigne. `null` =
              // « Autre ville » : `city` reste du texte libre, sans groupe de
              // ville. La cohérence avec `country_code` est tenue par
              // `trg_ville_coherente_avec_pays`, pas ici — une version déjà
              // installée continuerait d'écrire un couple incohérent.
              'ville_id': profile.villeId,
              // La colonne porte le NOM du pays (« Canada », « Algérie »),
              // jamais un code ISO. Elle en mélangeait deux formes : la
              // conversion vers l'ISO ne connaissait que 28 pays, et un pays
              // hors de cette liste (« Angola ») repartait en toutes lettres
              // à côté de `CA` et `NE` — d'où deux groupes officiels possibles
              // pour un même pays. `canonicalCountry` connaît toute la liste
              // du sélecteur, et une valeur vide part à `null`, pas à `''`.
              'country_code': ProfileOptions.canonicalCountry(
                (profile.currentCountry?.trim().isNotEmpty ?? false)
                    ? profile.currentCountry
                    : profile.countryCode,
              ),
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
    // Le média part sur Firebase Storage, comme les photos de groupe,
    // d'événement ou de story — seule l'URL est persistée sur Supabase.
    final url = await ImageUploadService().uploadImage(
      file: File(filePath),
      type: ImageUploadType.profile,
      id: userId,
    );
    if (url == null) {
      throw ServerException("Échec du téléversement de la photo");
    }
    await _requireAuth();
    await _supabase
        .from('users')
        .update({
          'avatar_url': url,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', userId);
    _cache.remove(userId);
    return url;
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

  /// Lève si aucune ligne n'a été touchée.
  ///
  /// PostgREST rend 200 sur un `UPDATE` qui ne matche aucune ligne — RLS qui
  /// cache la ligne, ou ligne pas encore créée. `_requireAuth` n'écarte que la
  /// cause « pas de session ». Sans ce contrôle, `NotificationPreferencesNotifier`
  /// prenait ce faux succès pour une écriture faite : local et serveur
  /// divergeaient, et le back-end continuait d'envoyer.
  Never _aucuneLigneTouchee() =>
      throw ServerException('Réglage non enregistré : aucun compte mis à jour');

  @override
  Future<void> updateNotifyLocalEvents(String userId, bool enabled) async {
    await _requireAuth();
    final touchees = await _supabase
        .from('users')
        .update({'notify_local_events': enabled})
        .eq('id', userId)
        .select('id');
    if (touchees.isEmpty) _aucuneLigneTouchee();
  }

  @override
  Future<void> updateNotificationPrefs(
    String userId,
    Map<String, bool> prefs,
  ) async {
    await _requireAuth();
    final touchees = await _supabase
        .from('users')
        .update({'notification_prefs': prefs})
        .eq('id', userId)
        .select('id');
    if (touchees.isEmpty) _aucuneLigneTouchee();
  }

  Future<void> updateShowMessagePreview(String userId, bool show) async {
    await _requireAuth();
    await _supabase
        .from('users')
        .update({'show_message_preview': show})
        .eq('id', userId);
  }

  @override
  ProfileModel? getCachedProfile(String userId) {
    final enMemoire = _cache[userId];
    if (enMemoire != null) return enMemoire;
    try {
      final json = CacheService.instance.getCachedProfile(userId);
      if (json == null) return null;
      final profile = ProfileModel.fromJson(json);
      _cache[userId] = profile;
      return profile;
    } catch (_) {
      // Boîte Hive absente (test unitaire) ou JSON d'une version antérieure :
      // pas de profil connu, ce que l'appelant sait déjà traiter.
      return null;
    }
  }

  /// Mémorise un profil lu : en mémoire pour la session, **et sur disque** pour
  /// les suivantes.
  ///
  /// La copie disque manquait. La boîte Hive `profiles_cache` existait déjà,
  /// mais aucun profil n'y était écrit — si bien qu'un démarrage à froid hors
  /// ligne n'avait aucun nom à afficher : la liste des discussions montrait
  /// « Utilisateur » et l'en-tête d'une discussion son repli « Conversation »
  /// (avatar « C ») jusqu'au retour du réseau. Mesuré sur SM A515F le
  /// 2026-09-14.
  void _memoriser(ProfileModel profile) {
    _cache[profile.id] = profile;
    try {
      unawaited(
        CacheService.instance.cacheProfile(profile.id, profile.toJson()),
      );
    } catch (_) {
      // Cache disque indisponible : la copie mémoire suffit à la session en
      // cours, et le profil sera relu au prochain démarrage.
    }
  }

  @override
  Future<bool> isHandleAvailable(String handle, {String? excludeUserId}) async {
    final normalized = handle.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    try {
      // Session non confirmée (fenêtre `_startFromLocalSession`, voir
      // SupabaseAuthBridge.ensureReadableSession) : ne pas interroger en
      // anon, la contrainte UNIQUE serveur tranchera au moment du save.
      if (!await _ensureReadableAuth()) {
        return true;
      }
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
