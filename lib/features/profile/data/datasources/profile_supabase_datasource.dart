import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/constants/colonnes_users.dart';
import '../../../../core/constants/profile_options.dart';
import '../../../../core/utils/position_partagee.dart';
import '../../../../core/services/cache_service.dart';
import '../../../../core/services/ecriture_ligne_users.dart';
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

  /// Identifiant du compte connecté, injectable pour les tests.
  final String? Function()? _uidCourantOverride;

  ProfileSupabaseDataSource({
    SupabaseClient? supabase,
    Future<bool> Function()? ensureAuth,
    Future<bool> Function()? ensureReadableAuth,
    String? Function()? uidCourant,
  }) : _clientOverride = supabase,
       _ensureAuth =
           ensureAuth ?? SupabaseAuthBridge.instance.ensureAuthenticated,
       _ensureReadableAuth =
           ensureReadableAuth ?? SupabaseAuthBridge.instance.ensureReadableSession,
       _uidCourantOverride = uidCourant;

  /// Qui est « moi » ?
  ///
  /// L'uid Firebase, comme partout ailleurs dans l'app — pas un claim du jeton
  /// Supabase : `firebase_uid()` retombe sur la table `auth_mappings` quand le
  /// claim manque, si bien que le client ne peut pas compter le trouver dans
  /// `appMetadata`. Le désaccord éventuel entre les deux est traité par
  /// [_ligne], qui vérifie l'identifiant de la ligne rendue.
  String? _uidCourant() {
    final override = _uidCourantOverride;
    if (override != null) return override();
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      // Firebase non initialisé (tests) : personne n'est « moi ».
      return null;
    }
  }

  /// La ligne `users` de [userId], dans la forme que la fermeture 1.1b de
  /// l'audit autorise (`lib/core/constants/colonnes_users.dart`).
  ///
  /// - **La sienne** : entière, par `mon_profil_prive()` — e-mail, téléphone,
  ///   jetons, préférences. C'est le seul chemin qui les servira une fois les
  ///   colonnes privées retirées au rôle `authenticated`.
  /// - **Celle d'autrui** : les colonnes publiques seulement.
  ///
  /// `mon_profil_prive()` rend la ligne de la session SUPABASE. Si ce n'est
  /// pas celle demandée (session d'un compte précédent pas encore rebasculée),
  /// on ne la sert pas sous un autre nom : on retombe sur la lecture publique.
  Future<Map<String, dynamic>?> _ligne(String userId) async {
    if (userId == _uidCourant()) {
      // Forme liste : une RPC part en POST, et `maybeSingle()` sur un POST ne
      // sait pas rattraper une réponse en tableau (postgrest-dart 2.8.0).
      final lignes = await _supabase.rpc('mon_profil_prive') as List;
      final moi = lignes.isEmpty ? null : lignes.first as Map<String, dynamic>;
      if (moi != null && moi['id'] == userId) return moi;
    }
    return _supabase
        .from('users')
        .select(selectPublicUsers)
        .eq('id', userId)
        .maybeSingle();
  }

  ProfileModel _modeleDepuis(Map<String, dynamic> row) {
    final profile = ProfileModel.fromJson(_mapProfile(row));
    _memoriser(profile);
    return profile;
  }

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
    final data = await _ligne(userId);
    if (data == null) throw ServerException('Profile not found: $userId');
    return _modeleDepuis(data);
  }

  /// Numéro de canal, pour que deux flux sur le même profil (la liste des
  /// discussions et l'écran ouvert) aient chacun le leur.
  static int _prochainCanal = 0;

  @override
  Stream<ProfileModel> getUserStream(String userId) {
    // CE N'EST PLUS UN `.stream()`, et il ne peut pas en être un. `.stream()`
    // commence par un `select()` nu — `SELECT *` —, refusé en 42501 entier une
    // fois les colonnes privées retirées (fermeture 1.1b). Ce flux reproduit
    // son comportement à la main, sur le modèle de
    // `SupabaseStreamBuilder` (supabase 2.16) : lecture immédiate à l'écoute,
    // relecture à chaque reconnexion, erreur sur `timedOut`/`channelError`,
    // fin sur `closed`.
    //
    // Avec UNE différence, voulue. Sur un UPDATE, `.stream()` REMPLACE la ligne
    // par le message temps réel. Or le temps réel retire d'un message les
    // colonnes que l'abonné ne peut pas lire, sans erreur (mesuré :
    // tools/rls_tests/temps_reel_droits_colonnes.sql) : son propre profil
    // perdrait e-mail, téléphone et préférences à la première mise à jour de
    // présence. Ici, le message se SUPERPOSE à la dernière ligne connue ; une
    // clé absente garde sa valeur.
    late final StreamController<ProfileModel> controller;
    RealtimeChannel? canal;
    Map<String, dynamic>? derniere;
    var dejaAbonne = false;

    Future<void> relire() async {
      try {
        final row = await _ligne(userId);
        if (controller.isClosed) return;
        if (row == null) {
          controller.add(await _profilAbsent(userId));
          return;
        }
        derniere = row;
        controller.add(_modeleDepuis(row));
      } catch (e, st) {
        if (!controller.isClosed) controller.addError(e, st);
      }
    }

    controller = StreamController<ProfileModel>(
      onListen: () async {
        // Même garde que [getProfile], et pour une raison plus coûteuse ici :
        // sans session, la lecture partait en anon et ne rendait aucune ligne ;
        // l'absence était lue comme « compte supprimé », et chaque ligne de la
        // liste des discussions affichait « Utilisateur » à la place du
        // correspondant — par intermittence, au gré de la course.
        await _ensureReadableAuth();
        if (controller.isClosed) return;

        canal = _supabase.channel('profil_${userId}_${_prochainCanal++}')
          ..onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'users',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: userId,
            ),
            callback: (payload) {
              if (controller.isClosed) return;
              if (payload.eventType == PostgresChangeEvent.delete) {
                unawaited(relire());
                return;
              }
              final nouveau = payload.newRecord;
              if (nouveau.isEmpty) return;
              final fusion = <String, dynamic>{...?derniere, ...nouveau};
              derniere = fusion;
              try {
                controller.add(_modeleDepuis(fusion));
              } catch (e, st) {
                controller.addError(e, st);
              }
            },
          )
          ..subscribe((statut, [erreur]) {
            if (controller.isClosed) return;
            switch (statut) {
              case RealtimeSubscribeStatus.subscribed:
                // Rejoué à chaque reconnexion : on relit ce qui a pu changer
                // pendant la coupure. La première fois, la lecture ci-dessous
                // est déjà partie.
                if (dejaAbonne) unawaited(relire());
                dejaAbonne = true;
              case RealtimeSubscribeStatus.closed:
                unawaited(controller.close());
              case RealtimeSubscribeStatus.timedOut:
              case RealtimeSubscribeStatus.channelError:
                controller.addError(RealtimeSubscribeException(statut, erreur));
            }
          });

        unawaited(relire());
      },
      onCancel: () async {
        final c = canal;
        canal = null;
        if (c != null) await _supabase.removeChannel(c);
      },
    );
    return controller.stream;
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
      final data = await _ligne(userId);
      if (data != null) return _modeleDepuis(data);
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
        .select(selectPublicUsers)
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
          .select(selectPublicUsers)
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
    // LA POSITION VIENT DU SERVEUR, CONSENTEMENT APPLIQUÉ. Cette lecture
    // demandait autrefois `SELECT *` filtré par `.eq('share_location', true)`
    // — un filtre que le CLIENT posait de lui-même : une requête qui
    // l'omettait obtenait la position des 6 personnes qui avaient coupé le
    // partage (mesuré le 2026-09-21). `positions_partagees()` applique le
    // consentement, la visibilité et le caractère privé en base, et ne rend
    // que l'identifiant et la position ; l'identité se relit ensuite par
    // colonnes publiques.
    //
    // Même boîte, même tri et même troncature qu'avant, côté serveur :
    // `limit(50)` sans ordre rendait 50 lignes arbitraires, et la carte écarte
    // ensuite tout ce qui a plus de 5 minutes — trier par fraîcheur aligne la
    // troncature sur ce filtre.
    final positions = await _supabase.rpc(
      'positions_partagees',
      params: {
        'p_lat_min': latitude - delta,
        'p_lat_max': latitude + delta,
        'p_lng_min': longitude - delta,
        'p_lng_max': longitude + delta,
        'p_limite': 50,
      },
    );
    return _profilsAvecPositions(
      (positions as List).cast<Map<String, dynamic>>(),
    );
  }

  @override
  Future<List<ProfileModel>> getProfilesByCountry(String country) async {
    final data = await _supabase
        .from('users')
        .select(selectPublicUsers)
        .eq('country_code', country)
        .eq('is_visible', true)
        // Une troncature non ordonnée est une loterie. Le tri se faisait sur
        // `location_updated_at`, qui n'est plus une colonne publique (un tri
        // sur une colonne non accordée fait refuser la requête entière). La
        // dernière activité est l'indice le plus proche de « présent sur la
        // carte » qui reste lisible. Elle manque à beaucoup de profils ; ceux-là
        // passent en dernier, ce qui ne coûte rien tant qu'un pays compte
        // moins de 50 membres visibles — 127 profils en tout au 2026-09-21.
        .order('last_active_at', ascending: false, nullsFirst: false)
        .limit(50);
    final profils = (data as List).cast<Map<String, dynamic>>();
    // Utilisée par la carte en mode « pays », qui place des marqueurs : les
    // positions sont jointes par identifiant, consentement appliqué par le
    // serveur. (Aussi utilisée par les mentions, qui les ignorent.)
    final positions = await _positionsParIds([
      for (final p in profils)
        if (p['share_location'] == true) p['id'] as String,
    ]);
    return [
      for (final p in profils) _modeleDepuis({...p, ...?positions[p['id']]}),
    ];
  }

  /// Positions consenties de [ids], par `positions_partagees_par_ids()`.
  ///
  /// Indexées par identifiant, chacune sous la forme d'un fragment de ligne
  /// (`latitude`, `longitude`, `location_updated_at`) à superposer à la ligne
  /// publique. Un identifiant absent du résultat n'a pas de position à
  /// montrer : partage coupé, invisible, privé, ou jamais localisé.
  Future<Map<String, Map<String, dynamic>>> _positionsParIds(
    List<String> ids,
  ) async {
    if (ids.isEmpty) return const {};
    final rows = await _supabase.rpc(
      'positions_partagees_par_ids',
      params: {'p_ids': ids},
    );
    return {
      for (final r in (rows as List).cast<Map<String, dynamic>>())
        r['id'] as String: {
          'latitude': r['latitude'],
          'longitude': r['longitude'],
          'location_updated_at': r['location_updated_at'],
        },
    };
  }

  /// Joint à des positions (id, latitude, longitude, date) l'identité
  /// publique de chacun, dans l'ordre des positions.
  ///
  /// Un identifiant dont la ligne publique ne revient pas (supprimé, devenu
  /// privé entre les deux lectures) est écarté plutôt que montré sans nom.
  Future<List<ProfileModel>> _profilsAvecPositions(
    List<Map<String, dynamic>> positions,
  ) async {
    if (positions.isEmpty) return const [];
    final lignes = await _supabase
        .from('users')
        .select(selectPublicUsers)
        .inFilter('id', [for (final p in positions) p['id'] as String]);
    final parId = {
      for (final l in (lignes as List).cast<Map<String, dynamic>>())
        l['id'] as String: l,
    };
    return [
      for (final p in positions)
        if (parId[p['id']] != null) _modeleDepuis({...parId[p['id']]!, ...p}),
    ];
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
  ///
  /// **Le message temps réel n'est plus qu'un signal.** Il portait la
  /// position, et le rappel la lisait directement. Deux raisons de ne plus le
  /// faire :
  ///
  /// - une fois les colonnes privées retirées (fermeture 1.1b), le temps réel
  ///   retire `latitude`, `longitude` et `location_updated_at` du message,
  ///   SANS erreur (mesuré : tools/rls_tests/temps_reel_droits_colonnes.sql) :
  ///   l'ancien rappel sortait alors tôt, et plus personne ne bougeait à
  ///   l'écran ;
  /// - aujourd'hui déjà, il recevait la position de qui avait coupé le
  ///   partage, et ne l'écartait que parce que la carte refiltrait derrière.
  ///
  /// Le message garde `id`, `share_location` et `is_visible`. Qui partage est
  /// mis en attente ; toutes les [_delaiLot], les positions des identifiants
  /// en attente sont demandées en un appel à `positions_partagees_par_ids()`,
  /// qui applique le consentement en base. Qui a coupé le partage ou s'est
  /// rendu invisible est transmis tout de suite, SANS position : c'est ce qui
  /// permet à la carte de le retirer sans attendre le prochain sondage.
  ///
  /// Coût : un appel au plus par [_delaiLot] et par carte ouverte, et
  /// seulement si un membre qui partage a bougé — pas un par message.
  Stream<ProfileModel> watchProfileLocationUpdates() {
    final channel = _supabase.channel('users_location_updates');
    late final StreamController<ProfileModel> controller;
    final enAttente = <String, Map<String, dynamic>>{};
    Timer? minuterie;

    Future<void> vider() async {
      minuterie = null;
      if (enAttente.isEmpty || controller.isClosed) return;
      final lot = Map<String, Map<String, dynamic>>.of(enAttente);
      enAttente.clear();
      try {
        final positions = await _positionsParIds(lot.keys.toList());
        if (controller.isClosed) return;
        for (final entree in positions.entries) {
          final ligne = lot[entree.key];
          if (ligne == null) continue;
          controller.add(_modeleDepuis({...ligne, ...entree.value}));
        }
      } catch (_) {
        // Le sondage périodique de la carte prend le relais : un lot perdu ne
        // doit pas casser le flux.
      }
    }

    controller = StreamController<ProfileModel>(
      onCancel: () async {
        minuterie?.cancel();
        minuterie = null;
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
            final id = row['id'];
            if (row.isEmpty || id is! String) return;
            try {
              if (row['share_location'] != true || row['is_visible'] == false) {
                // Plus rien à montrer : on le transmet sans position, et la
                // carte le retire s'il y était.
                controller.add(_modeleDepuis(
                  {...row}..removeWhere((k, _) => _clesPosition.contains(k)),
                ));
                return;
              }
            } catch (_) {
              // Ligne inattendue : on ignore plutôt que de casser le flux.
              return;
            }
            // Une ligne `users` bouge pour bien d'autres raisons qu'un
            // déplacement (statut en ligne, compteurs, édition de profil) :
            // le lot absorbe cette rafale.
            enAttente[id] = row;
            minuterie ??= Timer(_delaiLot, () => unawaited(vider()));
          },
        )
        .subscribe();

    return controller.stream;
  }

  /// Fenêtre de regroupement des demandes de position de la carte en direct.
  static const Duration _delaiLot = Duration(milliseconds: 300);

  /// Clés de position d'une ligne `users`. Retirées d'un message temps réel
  /// quand elles ne doivent pas être montrées : aujourd'hui le message les
  /// porte encore, pour tout le monde.
  static const Set<String> _clesPosition = {
    'latitude',
    'longitude',
    'location_updated_at',
  };

  // ═══════════════════════════════════════════
  // WRITE
  // ═══════════════════════════════════════════

  @override
  Future<ProfileModel> updateProfile(ProfileModel profile) async {
    await _requireAuth();
    // La ligne peut ne pas exister encore (compte authentifié par Firebase,
    // ligne créée au premier enregistrement du profil) — d'où une écriture
    // qui crée au besoin. Mais PAS un upsert : voir [ecrireSaLigneUsers], un
    // upsert qui écrit `phone_number` sera refusé en 42501 une fois la
    // fermeture 1.1b appliquée.
    final data = await ecrireSaLigneUsers(_supabase, profile.id, {
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
            });
    // La garde ci-dessus a déjà écarté la cause « pas de session ». Si
    // l'écriture ne rend toujours rien, c'est la RLS qui refuse la ligne
    // elle-même.
    if (data == null) {
      throw ServerException('Écriture refusée pour le profil ${profile.id}');
    }
    // La ligne relue ENTIÈRE (c'est la sienne) : l'écran d'édition affiche
    // ensuite e-mail et téléphone.
    final relue = await _ligne(profile.id);
    if (relue == null) {
      throw ServerException('Profil écrit mais illisible : ${profile.id}');
    }
    return _modeleDepuis(relue);
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
    // Point d'écriture UNIQUE de la position partagée : on l'arrondit ici (~100 m)
    // pour tenir la promesse « position approximative, jamais l'adresse exacte ».
    // Les deux publieurs (avant-plan et service d'arrière-plan) passent par là.
    await _supabase
        .from('users')
        .update({
          'latitude': arrondirPositionPartagee(latitude),
          'longitude': arrondirPositionPartagee(longitude),
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

  @override
  Future<void> updateShowMessagePreview(String userId, bool show) async {
    await _requireAuth();
    final touchees = await _supabase
        .from('users')
        .update({'show_message_preview': show})
        .eq('id', userId)
        .select('id');
    if (touchees.isEmpty) _aucuneLigneTouchee();
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
