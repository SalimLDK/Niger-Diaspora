import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/home_content_model.dart';

/// Source de données distante pour Home
abstract class HomeRemoteDataSource {
  Future<HomeContentModel> getHomeContent({
    required String userId,
    double? latitude,
    double? longitude,
    int nearbyMembersLimit = 10,
    int upcomingEventsLimit = 5,
  });

  Future<HomeStatsModel> getHomeStats({required String userId});

  Future<List<NearbyMemberModel>> getNearbyMembers({
    required String userId,
    required double latitude,
    required double longitude,
    double radiusKm = 50,
    int limit = 20,
  });

  Future<List<UpcomingEventModel>> getUpcomingEvents({
    required String userId,
    int limit = 10,
  });
}

class HomeRemoteDataSourceImpl implements HomeRemoteDataSource {
  final FirebaseFirestore _firestore;

  HomeRemoteDataSourceImpl({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<HomeContentModel> getHomeContent({
    required String userId,
    double? latitude,
    double? longitude,
    int nearbyMembersLimit = 10,
    int upcomingEventsLimit = 5,
  }) async {
    try {
      // Récupérer les données en parallèle
      final results = await Future.wait([
        getHomeStats(userId: userId),
        if (latitude != null && longitude != null)
          getNearbyMembers(
            userId: userId,
            latitude: latitude,
            longitude: longitude,
            limit: nearbyMembersLimit,
          )
        else
          Future.value(<NearbyMemberModel>[]),
        getUpcomingEvents(userId: userId, limit: upcomingEventsLimit),
      ]);

      return HomeContentModel(
        stats: results[0] as HomeStatsModel,
        nearbyMembers: results[1] as List<NearbyMemberModel>,
        upcomingEvents: results[2] as List<UpcomingEventModel>,
        quickActions: _getDefaultQuickActions(),
        lastUpdated: DateTime.now().toUtc().toIso8601String(),
      );
    } catch (e) {
      debugPrint('HomeRemoteDataSource: Error getting home content: $e');
      throw ServerException('Failed to get home content');
    }
  }

  @override
  Future<HomeStatsModel> getHomeStats({required String userId}) async {
    try {
      // Compter les membres totaux
      final membersCount =
          await _firestore
              .collection('users')
              .where('isActive', isEqualTo: true)
              .count()
              .get();

      // Compter les groupes de l'utilisateur
      final groupsCount =
          await _firestore
              .collection('groups')
              .where('memberIds', arrayContains: userId)
              .count()
              .get();

      // Compter les événements à venir
      final eventsCount =
          await _firestore
              .collection('events')
              .where('startDate', isGreaterThan: Timestamp.now())
              .count()
              .get();

      // Compter les messages non lus
      final unreadQuery =
          await _firestore
              .collection('conversations')
              .where('participantIds', arrayContains: userId)
              .get();

      int unreadMessages = 0;
      for (final doc in unreadQuery.docs) {
        final data = doc.data();
        final unreadCounts = data['unreadCounts'] as Map<String, dynamic>?;
        if (unreadCounts != null && unreadCounts[userId] != null) {
          unreadMessages += (unreadCounts[userId] as int?) ?? 0;
        }
      }

      // Compter les demandes d'amis en attente
      final friendRequestsCount =
          await _firestore
              .collection('friendRequests')
              .where('toUserId', isEqualTo: userId)
              .where('status', isEqualTo: 'pending')
              .count()
              .get();

      return HomeStatsModel(
        totalMembers: membersCount.count ?? 0,
        groupsCount: groupsCount.count ?? 0,
        upcomingEventsCount: eventsCount.count ?? 0,
        unreadMessages: unreadMessages,
        pendingFriendRequests: friendRequestsCount.count ?? 0,
      );
    } catch (e) {
      debugPrint('HomeRemoteDataSource: Error getting stats: $e');
      return const HomeStatsModel();
    }
  }

  @override
  Future<List<NearbyMemberModel>> getNearbyMembers({
    required String userId,
    required double latitude,
    required double longitude,
    double radiusKm = 50,
    int limit = 20,
  }) async {
    try {
      // Récupérer les utilisateurs avec localisation récente
      final query =
          await _firestore
              .collection('users')
              .where('isActive', isEqualTo: true)
              .where('locationSharingEnabled', isEqualTo: true)
              .limit(limit * 2) // Récupérer plus pour filtrer ensuite
              .get();

      final members = <NearbyMemberModel>[];

      for (final doc in query.docs) {
        if (doc.id == userId) continue; // Exclure l'utilisateur actuel

        final data = doc.data();
        final location = data['lastLocation'] as Map<String, dynamic>?;

        if (location != null) {
          final memberLat = location['latitude'] as double?;
          final memberLng = location['longitude'] as double?;

          if (memberLat != null && memberLng != null) {
            final distance = _calculateDistance(
              latitude,
              longitude,
              memberLat,
              memberLng,
            );

            if (distance <= radiusKm) {
              members.add(
                NearbyMemberModel(
                  id: doc.id,
                  displayName: data['displayName'] as String? ?? 'Membre',
                  photoUrl: data['photoUrl'] as String?,
                  city: data['city'] as String?,
                  country: data['country'] as String?,
                  distanceKm: distance,
                  lastSeen:
                      (data['lastSeen'] as Timestamp?)
                          ?.toDate()
                          .toUtc().toIso8601String(),
                  isOnline: data['isOnline'] as bool? ?? false,
                ),
              );
            }
          }
        }
      }

      // Trier par distance et limiter
      members.sort((a, b) => (a.distanceKm ?? 0).compareTo(b.distanceKm ?? 0));
      return members.take(limit).toList();
    } catch (e) {
      debugPrint('HomeRemoteDataSource: Error getting nearby members: $e');
      return [];
    }
  }

  @override
  Future<List<UpcomingEventModel>> getUpcomingEvents({
    required String userId,
    int limit = 10,
  }) async {
    try {
      final query =
          await _firestore
              .collection('events')
              .where('startDate', isGreaterThan: Timestamp.now())
              .orderBy('startDate')
              .limit(limit)
              .get();

      return query.docs.map((doc) {
        final data = doc.data();
        final attendees = data['attendeeIds'] as List<dynamic>? ?? [];

        return UpcomingEventModel(
          id: doc.id,
          title: data['title'] as String? ?? '',
          startDate:
              (data['startDate'] as Timestamp).toDate().toUtc().toIso8601String(),
          imageUrl: data['imageUrl'] as String?,
          location: data['location'] as String?,
          attendeesCount: attendees.length,
          isAttending: attendees.contains(userId),
        );
      }).toList();
    } catch (e) {
      debugPrint('HomeRemoteDataSource: Error getting upcoming events: $e');
      return [];
    }
  }

  /// Calcule la distance entre deux points (formule de Haversine simplifiée)
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371; // km
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a =
        _sin(dLat / 2) * _sin(dLat / 2) +
        _cos(_toRadians(lat1)) *
            _cos(_toRadians(lat2)) *
            _sin(dLon / 2) *
            _sin(dLon / 2);

    final c = 2 * _atan2(_sqrt(a), _sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * 3.14159265359 / 180;
  double _sin(double x) => _taylorSin(x);
  double _cos(double x) => _taylorSin(x + 3.14159265359 / 2);
  double _sqrt(double x) => x > 0 ? _babylonianSqrt(x) : 0;
  double _atan2(double y, double x) => _approximateAtan2(y, x);

  double _taylorSin(double x) {
    // Normaliser x entre -π et π
    while (x > 3.14159265359) {
      x -= 2 * 3.14159265359;
    }
    while (x < -3.14159265359) {
      x += 2 * 3.14159265359;
    }

    double result = x;
    double term = x;
    for (int i = 1; i <= 7; i++) {
      term *= -x * x / ((2 * i) * (2 * i + 1));
      result += term;
    }
    return result;
  }

  double _babylonianSqrt(double x) {
    if (x == 0) return 0;
    double guess = x / 2;
    for (int i = 0; i < 10; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }

  double _approximateAtan2(double y, double x) {
    if (x > 0) return _approximateAtan(y / x);
    if (x < 0 && y >= 0) return _approximateAtan(y / x) + 3.14159265359;
    if (x < 0 && y < 0) return _approximateAtan(y / x) - 3.14159265359;
    if (x == 0 && y > 0) return 3.14159265359 / 2;
    if (x == 0 && y < 0) return -3.14159265359 / 2;
    return 0;
  }

  double _approximateAtan(double x) {
    return x / (1 + 0.28 * x * x);
  }

  List<QuickActionModel> _getDefaultQuickActions() {
    return const [
      QuickActionModel(
        id: 'messages',
        label: 'Messages',
        icon: 'chat_bubble',
        route: '/messages',
      ),
      QuickActionModel(
        id: 'events',
        label: 'Événements',
        icon: 'event',
        route: '/events',
      ),
      QuickActionModel(
        id: 'groups',
        label: 'Groupes',
        icon: 'groups',
        route: '/groups',
      ),
      QuickActionModel(
        id: 'marketplace',
        label: 'Marketplace',
        icon: 'store',
        route: '/marketplace',
      ),
      QuickActionModel(
        id: 'transfers',
        label: 'Transferts',
        icon: 'send',
        route: '/transfers',
      ),
      QuickActionModel(
        id: 'businesses',
        label: 'Annuaire',
        icon: 'business',
        route: '/businesses',
      ),
    ];
  }
}
