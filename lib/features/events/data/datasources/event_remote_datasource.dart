import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../../core/constants/firebase_collections.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/cache_service.dart';
import '../../../../core/services/connectivity_service.dart';
import '../models/event_model.dart';

abstract class EventRemoteDataSource {
  Future<List<EventModel>> getEvents();
  Future<List<EventModel>> getUpcomingEvents();
  Future<List<EventModel>> getPastEvents();
  Future<List<EventModel>> getEventsByCategory(String category);
  Future<List<EventModel>> getEventsByGroup(String groupId);
  Future<EventModel> getEventById(String eventId);
  Future<EventModel> createEvent(EventModel event);
  Future<EventModel> updateEvent(EventModel event);
  Future<void> deleteEvent(String eventId);
  Future<void> attendEvent(String eventId, String userId);
  Future<void> cancelAttendance(String eventId, String userId);
  Future<List<EventModel>> getMyEvents(String userId);
  Future<List<EventModel>> getAttendingEvents(String userId);

  // Photo management
  Future<String> uploadEventPoster(String eventId, String imagePath);
  Future<void> deleteEventPoster(String eventId, String imageUrl);
  Future<String> uploadRecapPhoto(String eventId, String imagePath);
  Future<void> updateEventRecap(
    String eventId,
    List<String> photoUrls,
    String description,
  );
}

class EventRemoteDataSourceImpl implements EventRemoteDataSource {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final CacheService _cache = CacheService.instance;
  final ConnectivityService _connectivity = ConnectivityService.instance;

  EventRemoteDataSourceImpl({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance;

  CollectionReference get _eventsCollection =>
      _firestore.collection(FirebaseCollections.events);

  @override
  Future<List<EventModel>> getEvents() async {
    try {
      // Vérifier la connectivité
      final isConnected = await _connectivity.isConnected();

      if (isConnected) {
        final snapshot =
            await _eventsCollection
                .orderBy('startDate', descending: false)
                .get();

        final events =
            snapshot.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              data['id'] = doc.id;
              return EventModel.fromJson(_convertTimestamps(data));
            }).toList();

        // Mettre en cache les événements
        await _cache.cacheEvents(events.map((e) => e.toJson()).toList());

        return events;
      } else {
        // Mode hors ligne - utiliser le cache
        return _getEventsFromCache();
      }
    } on FirebaseException catch (e) {
      // En cas d'erreur réseau, essayer le cache
      final cached = _getEventsFromCache();
      if (cached.isNotEmpty) return cached;
      throw ServerException(
        e.message ?? 'Erreur lors du chargement des evenements',
      );
    }
  }

  List<EventModel> _getEventsFromCache() {
    final cachedData = _cache.getAllCachedEvents();
    return cachedData.map((data) => EventModel.fromJson(data)).toList();
  }

  @override
  Future<List<EventModel>> getUpcomingEvents() async {
    try {
      final isConnected = await _connectivity.isConnected();

      if (isConnected) {
        final now = DateTime.now();
        final snapshot =
            await _eventsCollection
                .where(
                  'startDate',
                  isGreaterThanOrEqualTo: Timestamp.fromDate(now),
                )
                .where('status', isEqualTo: 'upcoming')
                .orderBy('startDate')
                .limit(20)
                .get();

        final events =
            snapshot.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              data['id'] = doc.id;
              return EventModel.fromJson(_convertTimestamps(data));
            }).toList();

        // Mettre en cache individuellement chaque événement
        for (final event in events) {
          await _cache.cacheEvent(event.id, event.toJson());
        }

        return events;
      } else {
        // Mode hors ligne - filtrer les événements à venir du cache
        final cached = _getEventsFromCache();
        final now = DateTime.now();
        return cached
            .where((e) => e.startDate.isAfter(now) && e.status == 'upcoming')
            .take(20)
            .toList();
      }
    } on FirebaseException catch (e) {
      final cached = _getEventsFromCache();
      if (cached.isNotEmpty) {
        final now = DateTime.now();
        return cached
            .where((e) => e.startDate.isAfter(now) && e.status == 'upcoming')
            .take(20)
            .toList();
      }
      throw ServerException(e.message ?? 'Erreur lors du chargement');
    }
  }

  @override
  Future<List<EventModel>> getEventsByCategory(String category) async {
    try {
      final isConnected = await _connectivity.isConnected();

      if (isConnected) {
        final snapshot =
            await _eventsCollection
                .where('category', isEqualTo: category)
                .where('status', isEqualTo: 'upcoming')
                .orderBy('startDate')
                .get();

        final events =
            snapshot.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              data['id'] = doc.id;
              return EventModel.fromJson(_convertTimestamps(data));
            }).toList();

        for (final event in events) {
          await _cache.cacheEvent(event.id, event.toJson());
        }

        return events;
      } else {
        final cached = _getEventsFromCache();
        return cached
            .where((e) => e.category == category && e.status == 'upcoming')
            .toList();
      }
    } on FirebaseException catch (e) {
      final cached = _getEventsFromCache();
      final filtered =
          cached
              .where((e) => e.category == category && e.status == 'upcoming')
              .toList();
      if (filtered.isNotEmpty) return filtered;
      throw ServerException(e.message ?? 'Erreur lors du chargement');
    }
  }

  @override
  Future<List<EventModel>> getEventsByGroup(String groupId) async {
    try {
      final isConnected = await _connectivity.isConnected();
      if (!isConnected) {
        return _getEventsFromCache()
            .where((e) => e.groupId == groupId)
            .toList();
      }
      // Filtre single-field (pas d'index composite requis) ; le tri/filtre
      // « à venir » est fait côté provider.
      final snapshot =
          await _eventsCollection.where('groupId', isEqualTo: groupId).get();
      final events = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return EventModel.fromJson(_convertTimestamps(data));
      }).toList();
      for (final event in events) {
        await _cache.cacheEvent(event.id, event.toJson());
      }
      return events;
    } on FirebaseException catch (e) {
      final cached =
          _getEventsFromCache().where((e) => e.groupId == groupId).toList();
      if (cached.isNotEmpty) return cached;
      throw ServerException(e.message ?? 'Erreur lors du chargement');
    }
  }

  @override
  Future<EventModel> getEventById(String eventId) async {
    try {
      final isConnected = await _connectivity.isConnected();

      if (isConnected) {
        final doc = await _eventsCollection.doc(eventId).get();

        if (!doc.exists) {
          throw ServerException('Evenement non trouve');
        }

        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        final event = EventModel.fromJson(_convertTimestamps(data));

        // Mettre en cache
        await _cache.cacheEvent(eventId, event.toJson());

        return event;
      } else {
        // Mode hors ligne
        final cachedData = _cache.getCachedEvent(eventId);
        if (cachedData != null) {
          return EventModel.fromJson(cachedData);
        }
        throw ServerException('Evenement non disponible hors ligne');
      }
    } on FirebaseException catch (e) {
      final cachedData = _cache.getCachedEvent(eventId);
      if (cachedData != null) {
        return EventModel.fromJson(cachedData);
      }
      throw ServerException(e.message ?? 'Erreur lors du chargement');
    }
  }

  @override
  Future<EventModel> createEvent(EventModel event) async {
    try {
      final data = event.toJson();
      data.remove('id');
      data['createdAt'] = FieldValue.serverTimestamp();
      data['startDate'] = Timestamp.fromDate(event.startDate);
      if (event.endDate != null) {
        data['endDate'] = Timestamp.fromDate(event.endDate!);
      }

      final docRef = await _eventsCollection.add(data);
      return getEventById(docRef.id);
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors de la creation');
    }
  }

  @override
  Future<EventModel> updateEvent(EventModel event) async {
    try {
      final data = event.toJson();
      data.remove('id');
      data['updatedAt'] = FieldValue.serverTimestamp();
      data['startDate'] = Timestamp.fromDate(event.startDate);
      if (event.endDate != null) {
        data['endDate'] = Timestamp.fromDate(event.endDate!);
      }

      await _eventsCollection.doc(event.id).update(data);
      return getEventById(event.id);
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors de la mise a jour');
    }
  }

  @override
  Future<void> deleteEvent(String eventId) async {
    try {
      await _eventsCollection.doc(eventId).delete();
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors de la suppression');
    }
  }

  @override
  Future<void> attendEvent(String eventId, String userId) async {
    try {
      await _eventsCollection.doc(eventId).update({
        'attendeeIds': FieldValue.arrayUnion([userId]),
      });
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors de l\'inscription');
    }
  }

  @override
  Future<void> cancelAttendance(String eventId, String userId) async {
    try {
      await _eventsCollection.doc(eventId).update({
        'attendeeIds': FieldValue.arrayRemove([userId]),
      });
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors de l\'annulation');
    }
  }

  @override
  Future<List<EventModel>> getMyEvents(String userId) async {
    try {
      final isConnected = await _connectivity.isConnected();

      if (isConnected) {
        // Fetch events where user is the organizer
        final organizedSnapshot =
            await _eventsCollection
                .where('organizerId', isEqualTo: userId)
                .orderBy('startDate', descending: true)
                .get();

        // Fetch events where user is an attendee
        final attendingSnapshot =
            await _eventsCollection
                .where('attendeeIds', arrayContains: userId)
                .orderBy('startDate', descending: true)
                .get();

        // Combine and deduplicate events
        final eventMap = <String, EventModel>{};

        for (final doc in organizedSnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          eventMap[doc.id] = EventModel.fromJson(_convertTimestamps(data));
        }

        for (final doc in attendingSnapshot.docs) {
          if (!eventMap.containsKey(doc.id)) {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            eventMap[doc.id] = EventModel.fromJson(_convertTimestamps(data));
          }
        }

        final events = eventMap.values.toList();

        // Sort by start date descending
        events.sort((a, b) => b.startDate.compareTo(a.startDate));

        // Cache all events
        for (final event in events) {
          await _cache.cacheEvent(event.id, event.toJson());
        }

        return events;
      } else {
        final cached = _getEventsFromCache();
        return cached
            .where(
              (e) => e.organizerId == userId || e.attendeeIds.contains(userId),
            )
            .toList();
      }
    } on FirebaseException catch (e) {
      final cached = _getEventsFromCache();
      final filtered =
          cached
              .where(
                (e) =>
                    e.organizerId == userId || e.attendeeIds.contains(userId),
              )
              .toList();
      if (filtered.isNotEmpty) return filtered;
      throw ServerException(e.message ?? 'Erreur lors du chargement');
    }
  }

  @override
  Future<List<EventModel>> getAttendingEvents(String userId) async {
    try {
      final isConnected = await _connectivity.isConnected();

      if (isConnected) {
        final snapshot =
            await _eventsCollection
                .where('attendeeIds', arrayContains: userId)
                .orderBy('startDate')
                .get();

        final events =
            snapshot.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              data['id'] = doc.id;
              return EventModel.fromJson(_convertTimestamps(data));
            }).toList();

        for (final event in events) {
          await _cache.cacheEvent(event.id, event.toJson());
        }

        return events;
      } else {
        final cached = _getEventsFromCache();
        return cached.where((e) => e.attendeeIds.contains(userId)).toList();
      }
    } on FirebaseException catch (e) {
      final cached = _getEventsFromCache();
      final filtered =
          cached.where((e) => e.attendeeIds.contains(userId)).toList();
      if (filtered.isNotEmpty) return filtered;
      throw ServerException(e.message ?? 'Erreur lors du chargement');
    }
  }

  Map<String, dynamic> _convertTimestamps(Map<String, dynamic> data) {
    final result = Map<String, dynamic>.from(data);
    result.forEach((key, value) {
      if (value is Timestamp) {
        result[key] = value.toDate().toUtc().toIso8601String();
      }
    });
    return result;
  }

  @override
  Future<List<EventModel>> getPastEvents() async {
    try {
      final isConnected = await _connectivity.isConnected();

      if (isConnected) {
        final snapshot =
            await _eventsCollection
                .where('status', isEqualTo: 'completed')
                .orderBy('startDate', descending: true)
                .limit(50)
                .get();

        final events =
            snapshot.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              data['id'] = doc.id;
              return EventModel.fromJson(_convertTimestamps(data));
            }).toList();

        for (final event in events) {
          await _cache.cacheEvent(event.id, event.toJson());
        }

        return events;
      } else {
        final cached = _getEventsFromCache();
        return cached.where((e) => e.status == 'completed').take(50).toList();
      }
    } on FirebaseException catch (e) {
      final cached = _getEventsFromCache();
      if (cached.isNotEmpty) {
        return cached.where((e) => e.status == 'completed').take(50).toList();
      }
      throw ServerException(e.message ?? 'Erreur lors du chargement');
    }
  }

  @override
  Future<String> uploadEventPoster(String eventId, String imagePath) async {
    try {
      final file = File(imagePath);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child('events/$eventId/posters/$fileName');

      await ref.putFile(file);
      final url = await ref.getDownloadURL();

      // Update event with new poster URL
      final doc = await _eventsCollection.doc(eventId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final posterUrls = List<String>.from(data['posterUrls'] ?? []);
        posterUrls.add(url);

        await _eventsCollection.doc(eventId).update({'posterUrls': posterUrls});
      }

      return url;
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors de l\'upload');
    } catch (e) {
      throw ServerException('Erreur lors de l\'upload de l\'image');
    }
  }

  @override
  Future<void> deleteEventPoster(String eventId, String imageUrl) async {
    try {
      // Delete from storage
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();

      // Update event to remove URL
      final doc = await _eventsCollection.doc(eventId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final posterUrls = List<String>.from(data['posterUrls'] ?? []);
        posterUrls.remove(imageUrl);

        await _eventsCollection.doc(eventId).update({'posterUrls': posterUrls});
      }
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors de la suppression');
    }
  }

  @override
  Future<String> uploadRecapPhoto(String eventId, String imagePath) async {
    try {
      final file = File(imagePath);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child('events/$eventId/recap/$fileName');

      await ref.putFile(file);
      final url = await ref.getDownloadURL();

      return url;
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors de l\'upload');
    } catch (e) {
      throw ServerException('Erreur lors de l\'upload de la photo');
    }
  }

  @override
  Future<void> updateEventRecap(
    String eventId,
    List<String> photoUrls,
    String description,
  ) async {
    try {
      await _eventsCollection.doc(eventId).update({
        'recapPhotoUrls': photoUrls,
        'recapDescription': description,
        'recapCreatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors de la mise à jour');
    }
  }
}
