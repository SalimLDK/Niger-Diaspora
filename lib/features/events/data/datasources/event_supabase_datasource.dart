import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/cache_service.dart';
import '../../../../core/services/connectivity_service.dart';
import '../../../../core/services/supabase_auth_bridge.dart';
import '../../../../core/utils/date_parsing.dart';
import '../models/event_model.dart';
import 'event_remote_datasource.dart';

/// Les événements, lus et écrits sur `public.events`.
///
/// Le module vivait entièrement sur Firestore pendant que le back-office admin
/// écrivait déjà dans `public.events` : un événement créé d'un côté n'existait
/// pas de l'autre, et un lien `/events/<uuid>` ne pouvait pas s'ouvrir.
/// Constaté et mesuré le 2026-09-09.
///
/// Les **photos** restent sur Firebase Storage, délibérément : c'est ce que
/// font déjà les messages depuis leur propre bascule
/// (`message_supabase_datasource.dart`), et rien dans l'app n'utilise Supabase
/// Storage. Déplacer les médias est un autre chantier, avec sa reprise
/// d'URL — le mélanger à celui-ci le rendrait irréversible.
class EventSupabaseDataSource implements EventRemoteDataSource {
  final SupabaseClient _supabase;
  final FirebaseStorage _storage;
  final CacheService _cache = CacheService.instance;
  final ConnectivityService _connectivity = ConnectivityService.instance;

  EventSupabaseDataSource({SupabaseClient? client, FirebaseStorage? storage})
    : _supabase = client ?? Supabase.instance.client,
      _storage = storage ?? FirebaseStorage.instance;

  /// Colonnes de `events` + le nom du groupe, que le modèle expose mais que la
  /// table ne porte pas. L'embed s'appuie sur `events_group_id_fkey`.
  static const String _select = '*, groups(name)';

  // ── Vocabulaire de `status` ────────────────────────────────────────────
  //
  // `events_status_check` accepte draft | upcoming | ongoing | ended |
  // cancelled ; l'enum Dart dit upcoming | ongoing | completed | cancelled.
  // Écrire « completed » violerait la contrainte (23514) ; lire « ended » sans
  // le traduire ferait retomber `EventModel._parseStatus` sur « upcoming », et
  // un événement passé se serait annoncé à venir.
  //
  // `draft` n'a pas d'équivalent Dart. Il reste tel quel côté base et n'arrive
  // ici que pour son organisateur (cf. `events_select`) : le repli d'enum en
  // fait un « upcoming », ce qui est le moins faux des choix disponibles.
  static String _statusVersDart(Object? value) =>
      value == 'ended' ? 'completed' : (value as String? ?? 'upcoming');

  static String _statusVersBase(String value) =>
      value == 'completed' ? 'ended' : value;

  // ── Correspondance ligne ⇄ modèle ──────────────────────────────────────

  Map<String, dynamic> _mapEvent(
    Map<String, dynamic> row,
    List<String> attendeeIds,
  ) => {
    'id': row['id'],
    'title': row['title'] ?? '',
    'description': row['description'] ?? '',
    'startDate': row['starts_at'],
    'endDate': row['ends_at'],
    // `location` du modèle, c'est la ville affichée ; `address` est distincte.
    'location': row['city'] ?? '',
    'address': row['address'],
    'country': row['country_code'],
    'latitude': row['latitude'],
    'longitude': row['longitude'],
    'organizerId': row['organizer_id'],
    'organizerName': row['organizer_name'],
    'organizerPhotoUrl': row['organizer_photo_url'],
    'posterUrls': _listeDeTextes(row['poster_urls'], repli: row['cover_url']),
    'attendeeIds': attendeeIds,
    'maxAttendees': row['max_attendees'] ?? 0,
    'price': (row['price'] as num?)?.toDouble() ?? 0.0,
    'isOnline': row['is_online'] ?? false,
    // Deux colonnes disent la même chose (`online_link` a été ajoutée après
    // `online_url`, sans que l'ancienne parte) : on lit l'une ou l'autre.
    'onlineLink': row['online_link'] ?? row['online_url'] ?? row['meeting_url'],
    'category': row['category'] ?? 'other',
    'status': _statusVersDart(row['status']),
    'createdAt': row['created_at'],
    'recapPhotoUrls': _listeDeTextes(row['recap_photo_urls']),
    'recapDescription': row['recap_description'],
    'recapCreatedAt': row['recap_created_at'],
    'groupId': row['group_id'],
    'groupName': (row['groups'] as Map?)?['name'],
    'conversationId': row['conversation_id'],
    'isPublic': row['is_public'] ?? false,
  };

  /// `poster_urls` et `recap_photo_urls` sont des `jsonb` : PostgREST rend une
  /// liste, mais une ligne écrite à la main peut porter une chaîne ou `null`.
  /// `repli` récupère `cover_url` pour les lignes créées par le back-office,
  /// qui ne remplit que celle-là.
  static List<String> _listeDeTextes(Object? value, {Object? repli}) {
    if (value is List) {
      final urls = value.whereType<String>().toList();
      if (urls.isNotEmpty) return urls;
    }
    if (value is String && value.isNotEmpty) return [value];
    if (repli is String && repli.isNotEmpty) return [repli];
    return const [];
  }

  /// Colonnes à écrire. `id`, `created_at` et `attendee_count` sont exclus :
  /// la base les tient (le compteur par le trigger
  /// `event_attendees_count_trigger`), les réécrire depuis le client les
  /// ferait diverger.
  Map<String, dynamic> _versLigne(EventModel event) => {
    'title': event.title,
    'description': event.description,
    'starts_at': toIsoUtc(event.startDate),
    'ends_at': toIsoUtcOrNull(event.endDate),
    'city': event.location,
    'address': event.address,
    'country_code': event.country,
    'latitude': event.latitude,
    'longitude': event.longitude,
    'organizer_id': event.organizerId,
    'organizer_name': event.organizerName,
    'organizer_photo_url': event.organizerPhotoUrl,
    'poster_urls': event.posterUrls,
    'cover_url': event.posterUrls.isEmpty ? null : event.posterUrls.first,
    'max_attendees': event.maxAttendees,
    'price': event.price,
    'is_online': event.isOnline,
    'online_link': event.onlineLink,
    'category': event.category,
    'status': _statusVersBase(event.status),
    'recap_photo_urls': event.recapPhotoUrls,
    'recap_description': event.recapDescription,
    'recap_created_at': toIsoUtcOrNull(event.recapCreatedAt),
    'group_id': event.groupId,
    'conversation_id': event.conversationId,
    'is_public': event.isPublic,
  };

  /// Participants de chaque événement, en une requête.
  ///
  /// La liste entière — pas seulement sa propre ligne : l'app s'en sert pour
  /// décider qu'un événement est complet
  /// (`attendeeIds.length >= maxAttendees`). Ne rapiécer que sa propre
  /// inscription ferait qu'aucun événement ne serait jamais complet, exactement
  /// le défaut corrigé sur les groupes par `20260806190000`.
  ///
  /// Demande la policy `event_attendees_select` de `20260910003000`.
  Future<Map<String, List<String>>> _participantsPour(
    List<String> eventIds,
  ) async {
    if (eventIds.isEmpty) return const {};
    try {
      final rows =
          await _supabase
                  .from('event_attendees')
                  .select('event_id, user_id')
                  .inFilter('event_id', eventIds)
              as List;
      final parEvenement = <String, List<String>>{};
      for (final r in rows) {
        final eid = r['event_id'] as String?;
        final uid = r['user_id'] as String?;
        if (eid == null || uid == null) continue;
        (parEvenement[eid] ??= <String>[]).add(uid);
      }
      return parEvenement;
    } catch (_) {
      // Une inscription illisible ne doit pas emporter l'événement lui-même :
      // mieux vaut une fiche sans liste de participants que pas de fiche.
      return const {};
    }
  }

  Future<List<EventModel>> _modelesDepuis(List rows) async {
    final lignes = rows.cast<Map<String, dynamic>>();
    final ids = lignes
        .map((r) => r['id'])
        .whereType<String>()
        .toList(growable: false);
    final participants = await _participantsPour(ids);
    return lignes
        .map(
          (r) => EventModel.fromJson(
            _mapEvent(r, participants[r['id']] ?? const []),
          ),
        )
        .toList();
  }

  Future<List<EventModel>> _cacher(List<EventModel> events) async {
    for (final event in events) {
      await _cache.cacheEvent(event.id, event.toJson());
    }
    return events;
  }

  /// Oublie les événements du cache qu'une lecture complète n'a pas rendus.
  ///
  /// `_cacher` n'écrit que par-dessus : un événement supprimé — par son
  /// organisateur sur un autre appareil, ou depuis le back-office — restait
  /// donc dans la boîte, et revenait à l'accueil à chaque ouverture par
  /// l'affichage « cache d'abord ». On ne purge que si la réponse est
  /// **complète** (moins de lignes que la limite) et seulement dans le
  /// périmètre de la requête : un événement passé ne disparaît pas parce que
  /// la liste « à venir » ne le contient pas.
  Future<void> _oublierAbsents(
    List<EventModel> recus, {
    required bool complet,
    required bool Function(EventModel) perimetre,
  }) async {
    if (!complet) return;
    final ids = recus.map((e) => e.id).toSet();
    for (final e in _depuisLeCache()) {
      if (perimetre(e) && !ids.contains(e.id)) {
        await _cache.removeCachedEvent(e.id);
      }
    }
  }

  List<EventModel> _depuisLeCache() =>
      _cache.getAllCachedEvents().map(EventModel.fromJson).toList();

  // ── Lectures ───────────────────────────────────────────────────────────

  @override
  Future<List<EventModel>> getEvents() async {
    if (!await _connectivity.isConnected()) return _depuisLeCache();
    try {
      await SupabaseAuthBridge.instance.ensureAuthenticated();
      final rows =
          await _supabase.from('events').select(_select).order('starts_at')
              as List;
      final events = await _modelesDepuis(rows);
      await _cache.cacheEvents(events.map((e) => e.toJson()).toList());
      return events;
    } catch (e) {
      final cached = _depuisLeCache();
      if (cached.isNotEmpty) return cached;
      throw ServerException(
        'Erreur lors du chargement des evenements : ${e.runtimeType}',
      );
    }
  }

  /// Les deux onglets de l'écran Événements PARTITIONNENT, par la date.
  ///
  /// Ils filtraient chacun sur `status` — « À venir » exigeait `upcoming`,
  /// « Passés » exigeait `completed` — et rien ne fait passer un événement de
  /// l'un à l'autre quand sa date arrive. Un événement dont personne n'avait
  /// touché le statut tombait donc entre les deux et devenait invisible :
  /// c'est le cas de « testeur » (2026-08-24, resté `upcoming`), qui m'a fait
  /// croire un moment que la collection Firestore était vide.
  ///
  /// Un brouillon reste hors des deux : la RLS ne le montre qu'à son
  /// organisateur, et l'y afficher comme un événement ordinaire l'induirait en
  /// erreur.
  ///
  /// Un événement **annulé** va dans « Passés », quelle que soit sa date : il
  /// n'est plus à venir, et le laisser dans le premier onglet reviendrait à
  /// proposer d'y participer.
  /// Vocabulaire **Dart** ici : le cache stocke ce que `_mapEvent` a traduit,
  /// donc `completed` et non `ended`. Les deux prédicats sont exactement
  /// complémentaires — c'est ce qui garantit qu'aucun événement ne tombe
  /// entre les deux onglets.
  static bool _estPasse(EventModel e, DateTime maintenant) =>
      e.status == 'cancelled' ||
      e.status == 'completed' ||
      e.startDate.isBefore(maintenant);

  static bool _estAVenir(EventModel e, DateTime maintenant) =>
      !_estPasse(e, maintenant);

  @override
  Future<List<EventModel>> getUpcomingEvents() async {
    final now = DateTime.now();
    List<EventModel> repli() => _depuisLeCache()
        .where((e) => e.status != 'draft' && _estAVenir(e, now))
        .take(20)
        .toList();

    if (!await _connectivity.isConnected()) return repli();
    try {
      await SupabaseAuthBridge.instance.ensureAuthenticated();
      final rows =
          await _supabase
                  .from('events')
                  .select(_select)
                  .gte('starts_at', toIsoUtc(now))
                  .not('status', 'in', '("draft","cancelled")')
                  .order('starts_at')
                  .limit(20)
              as List;
      final events = await _modelesDepuis(rows);
      await _oublierAbsents(
        events,
        complet: rows.length < 20,
        perimetre: (e) => e.status != 'draft' && _estAVenir(e, now),
      );
      return _cacher(events);
    } catch (e) {
      final cached = repli();
      if (cached.isNotEmpty) return cached;
      throw ServerException('Erreur lors du chargement : ${e.runtimeType}');
    }
  }

  @override
  Future<List<EventModel>> getPastEvents() async {
    final now = DateTime.now();
    List<EventModel> repli() => _depuisLeCache()
        .where((e) => e.status != 'draft' && _estPasse(e, now))
        .take(50)
        .toList();

    if (!await _connectivity.isConnected()) return repli();
    try {
      await SupabaseAuthBridge.instance.ensureAuthenticated();
      // Complément exact de `getUpcomingEvents` : date dépassée **ou**
      // annulé. `ended` reste accepté sans condition de date — c'est le
      // vocabulaire de la base pour « terminé », et une donnée saisie à la
      // main pourrait le porter sans que la date suive.
      final rows =
          await _supabase
                  .from('events')
                  .select(_select)
                  .neq('status', 'draft')
                  .or(
                    'starts_at.lt.${toIsoUtc(now)},'
                    'status.eq.cancelled,status.eq.ended',
                  )
                  .order('starts_at', ascending: false)
                  .limit(50)
              as List;
      final events = await _modelesDepuis(rows);
      await _oublierAbsents(
        events,
        complet: rows.length < 50,
        perimetre: (e) => e.status != 'draft' && _estPasse(e, now),
      );
      return _cacher(events);
    } catch (e) {
      final cached = repli();
      if (cached.isNotEmpty) return cached;
      throw ServerException('Erreur lors du chargement : ${e.runtimeType}');
    }
  }

  @override
  Future<List<EventModel>> getEventsByCategory(String category) async {
    List<EventModel> repli() => _depuisLeCache()
        .where((e) => e.category == category && e.status == 'upcoming')
        .toList();

    if (!await _connectivity.isConnected()) return repli();
    try {
      await SupabaseAuthBridge.instance.ensureAuthenticated();
      final rows =
          await _supabase
                  .from('events')
                  .select(_select)
                  .eq('category', category)
                  .eq('status', 'upcoming')
                  .order('starts_at')
              as List;
      return _cacher(await _modelesDepuis(rows));
    } catch (e) {
      final cached = repli();
      if (cached.isNotEmpty) return cached;
      throw ServerException('Erreur lors du chargement : ${e.runtimeType}');
    }
  }

  @override
  Future<List<EventModel>> getEventsByGroup(String groupId) async {
    List<EventModel> repli() =>
        _depuisLeCache().where((e) => e.groupId == groupId).toList();

    if (!await _connectivity.isConnected()) return repli();
    try {
      await SupabaseAuthBridge.instance.ensureAuthenticated();
      final rows =
          await _supabase.from('events').select(_select).eq('group_id', groupId)
              as List;
      return _cacher(await _modelesDepuis(rows));
    } catch (e) {
      final cached = repli();
      if (cached.isNotEmpty) return cached;
      throw ServerException('Erreur lors du chargement : ${e.runtimeType}');
    }
  }

  @override
  Future<EventModel> getEventById(String eventId) async {
    if (!await _connectivity.isConnected()) {
      final cached = _cache.getCachedEvent(eventId);
      if (cached != null) return EventModel.fromJson(cached);
      throw ServerException('Evenement non disponible hors ligne');
    }
    await SupabaseAuthBridge.instance.ensureAuthenticated();
    // `.single()` et non `.maybeSingle()` : l'absence de ligne — supprimé,
    // brouillon d'un autre, identifiant d'une autre base — doit remonter
    // comme un échec, pas comme un `null` que l'écran prendrait pour un
    // chargement en cours.
    final row = await _supabase
        .from('events')
        .select(_select)
        .eq('id', eventId)
        .single();
    final participants = await _participantsPour([eventId]);
    final event = EventModel.fromJson(
      _mapEvent(row, participants[eventId] ?? const []),
    );
    await _cache.cacheEvent(eventId, event.toJson());
    return event;
  }

  @override
  Future<List<EventModel>> getMyEvents(String userId) async {
    List<EventModel> repli() => _depuisLeCache()
        .where(
          (e) => e.organizerId == userId || e.attendeeIds.contains(userId),
        )
        .toList();

    if (!await _connectivity.isConnected()) return repli();
    try {
      await SupabaseAuthBridge.instance.ensureAuthenticated();
      final organises =
          await _supabase
                  .from('events')
                  .select(_select)
                  .eq('organizer_id', userId)
                  .order('starts_at')
              as List;
      final inscrits = await getAttendingEvents(userId);

      final tous = <String, EventModel>{
        for (final e in await _modelesDepuis(organises)) e.id: e,
        for (final e in inscrits) e.id: e,
      };
      final events = tous.values.toList()
        ..sort((a, b) => a.startDate.compareTo(b.startDate));
      return _cacher(events);
    } catch (e) {
      final cached = repli();
      if (cached.isNotEmpty) return cached;
      throw ServerException('Erreur lors du chargement : ${e.runtimeType}');
    }
  }

  @override
  Future<List<EventModel>> getAttendingEvents(String userId) async {
    List<EventModel> repli() =>
        _depuisLeCache().where((e) => e.attendeeIds.contains(userId)).toList();

    if (!await _connectivity.isConnected()) return repli();
    try {
      await SupabaseAuthBridge.instance.ensureAuthenticated();
      final inscriptions =
          await _supabase
                  .from('event_attendees')
                  .select('event_id')
                  .eq('user_id', userId)
              as List;
      final ids = inscriptions
          .map((r) => r['event_id'])
          .whereType<String>()
          .toList(growable: false);
      if (ids.isEmpty) return const [];

      final rows =
          await _supabase
                  .from('events')
                  .select(_select)
                  .inFilter('id', ids)
                  .order('starts_at')
              as List;
      return _cacher(await _modelesDepuis(rows));
    } catch (e) {
      final cached = repli();
      if (cached.isNotEmpty) return cached;
      throw ServerException('Erreur lors du chargement : ${e.runtimeType}');
    }
  }

  // ── Écritures ──────────────────────────────────────────────────────────

  @override
  Future<EventModel> createEvent(EventModel event) async {
    await SupabaseAuthBridge.instance.ensureAuthenticated();
    try {
      final row = await _supabase
          .from('events')
          .insert(_versLigne(event))
          .select('id')
          .single();
      final id = row['id'] as String;

      // L'organisateur compte parmi les participants — c'est ce que faisait
      // `attendeeIds: [currentUser.id]` à la création côté Firestore, où la
      // liste vivait dans le document. Ici elle vit dans une autre table :
      // sans cette ligne, le créateur n'apparaît nulle part et son propre
      // événement ne sort pas de « Mes événements » par la voie des
      // inscriptions.
      await _supabase.from('event_attendees').insert({
        'event_id': id,
        'user_id': event.organizerId,
      });

      return getEventById(id);
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    }
  }

  @override
  Future<EventModel> updateEvent(EventModel event) async {
    await SupabaseAuthBridge.instance.ensureAuthenticated();
    try {
      await _supabase.from('events').update(_versLigne(event)).eq(
        'id',
        event.id,
      );
      return getEventById(event.id);
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    }
  }

  @override
  Future<void> deleteEvent(String eventId) async {
    await SupabaseAuthBridge.instance.ensureAuthenticated();
    final List<dynamic> supprimes;
    try {
      // `.select()` rend les lignes réellement effacées. Une suppression que
      // la RLS refuse ne lève **aucune** erreur : elle efface zéro ligne.
      // L'écran annonçait alors « Événement supprimé » et l'événement restait
      // en base — et à l'accueil (2026-09-12).
      supprimes = await _supabase
          .from('events')
          .delete()
          .eq('id', eventId)
          .select('id');
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    }
    if (supprimes.isEmpty) {
      throw ServerException(
        "L'événement n'a pas été supprimé (droits insuffisants ou déjà supprimé)",
      );
    }
    // Le cache d'abord relu par `EventsNotifier` : sans ce retrait,
    // l'événement réapparaissait au prochain affichage.
    await _cache.removeCachedEvent(eventId);
  }

  @override
  Future<void> attendEvent(String eventId, String userId) async {
    await SupabaseAuthBridge.instance.ensureAuthenticated();
    try {
      // `upsert` et non `insert` : la clé primaire est (event_id, user_id), un
      // double tap sur « Participer » lèverait sinon un 23505 que l'écran
      // afficherait comme un échec alors que l'inscription est acquise.
      await _supabase.from('event_attendees').upsert({
        'event_id': eventId,
        'user_id': userId,
      }, onConflict: 'event_id,user_id');
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    }
  }

  @override
  Future<void> cancelAttendance(String eventId, String userId) async {
    await SupabaseAuthBridge.instance.ensureAuthenticated();
    try {
      await _supabase
          .from('event_attendees')
          .delete()
          .eq('event_id', eventId)
          .eq('user_id', userId);
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    }
  }

  // ── Photos — Firebase Storage, comme les messages ──────────────────────

  @override
  Future<String> uploadEventPoster(String eventId, String imagePath) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child('events/$eventId/posters/$fileName');
      await ref.putFile(File(imagePath));
      final url = await ref.getDownloadURL();

      final event = await getEventById(eventId);
      final urls = [...event.posterUrls, url];
      await SupabaseAuthBridge.instance.ensureAuthenticated();
      await _supabase
          .from('events')
          .update({'poster_urls': urls, 'cover_url': urls.first})
          .eq('id', eventId);
      return url;
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors de l\'upload');
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    }
  }

  @override
  Future<void> deleteEventPoster(String eventId, String imageUrl) async {
    try {
      await _storage.refFromURL(imageUrl).delete();
    } on FirebaseException {
      // Le fichier a pu disparaître d'un côté sans l'autre : retirer l'URL de
      // la fiche reste la bonne chose à faire.
    }
    try {
      final event = await getEventById(eventId);
      final urls = event.posterUrls.where((u) => u != imageUrl).toList();
      await SupabaseAuthBridge.instance.ensureAuthenticated();
      await _supabase
          .from('events')
          .update({
            'poster_urls': urls,
            'cover_url': urls.isEmpty ? null : urls.first,
          })
          .eq('id', eventId);
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    }
  }

  @override
  Future<String> uploadRecapPhoto(String eventId, String imagePath) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child('events/$eventId/recap/$fileName');
      await ref.putFile(File(imagePath));
      return await ref.getDownloadURL();
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors de l\'upload');
    }
  }

  @override
  Future<void> updateEventRecap(
    String eventId,
    List<String> photoUrls,
    String description,
  ) async {
    await SupabaseAuthBridge.instance.ensureAuthenticated();
    try {
      await _supabase
          .from('events')
          .update({
            'recap_photo_urls': photoUrls,
            'recap_description': description,
            'recap_created_at': toIsoUtc(DateTime.now()),
          })
          .eq('id', eventId);
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    }
  }
}
