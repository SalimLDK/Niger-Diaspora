import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
// import 'package:flutter/foundation.dart';
import '../../../../core/constants/firebase_collections.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/cache_service.dart';
import '../../../../core/services/connectivity_service.dart';
import '../models/profile_model.dart';

abstract class ProfileRemoteDataSource {
  Future<ProfileModel> getProfile(String userId);
  Future<ProfileModel> updateProfile(ProfileModel profile);
  Future<String> uploadProfilePhoto(String userId, String filePath);
  Future<void> updateLocation(String userId, double latitude, double longitude);
  Future<List<ProfileModel>> getNearbyProfiles(
    double latitude,
    double longitude,
    double radiusKm,
  );
  Future<List<ProfileModel>> getProfilesByCountry(String country);
  Future<List<ProfileModel>> searchProfiles(String query);
  Stream<ProfileModel> getUserStream(String userId);
  Future<void> updateLastLogin(String userId);
  Future<void> updateOnlineStatus(
    String userId,
    bool isOnline,
    DateTime lastSeen,
  );
  Future<void> updateOnlineStatusVisibility(String userId, bool showStatus);
  Future<void> updateNotifyLocalEvents(String userId, bool enabled);
  ProfileModel? getCachedProfile(String userId);
}

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final CacheService _cache = CacheService.instance;
  final ConnectivityService _connectivity = ConnectivityService.instance;

  ProfileRemoteDataSourceImpl({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance;

  @override
  Future<ProfileModel> getProfile(String userId) async {
    try {
      final isConnected = await _connectivity.isConnected();

      if (isConnected) {
        final doc =
            await _firestore
                .collection(FirebaseCollections.users)
                .doc(userId)
                .get();

        if (!doc.exists) {
          throw ServerException('Profil non trouvé');
        }

        final data = doc.data()!;
        data['id'] = doc.id;

        // Ensure count fields have default values
        data['connectionsCount'] ??= 0;
        data['groupsCount'] ??= 0;
        data['eventsCount'] ??= 0;

        final profile = ProfileModel.fromJson(_convertTimestamps(data));

        // Mettre en cache
        await _cache.cacheProfile(userId, profile.toJson());

        return profile;
      } else {
        // Mode hors ligne
        final cachedData = _cache.getCachedProfile(userId);
        if (cachedData != null) {
          return ProfileModel.fromJson(cachedData);
        }
        throw ServerException('Profil non disponible hors ligne');
      }
    } on FirebaseException catch (e) {
      final cachedData = _cache.getCachedProfile(userId);
      if (cachedData != null) {
        return ProfileModel.fromJson(cachedData);
      }
      throw ServerException(e.message ?? 'Erreur Firebase');
    }
  }

  @override
  Future<ProfileModel> updateProfile(ProfileModel profile) async {
    try {
      final data = profile.toJson();
      data.remove('id');
      data['updatedAt'] = FieldValue.serverTimestamp();

      // Si photoUrl est null, utiliser FieldValue.delete() pour supprimer le champ
      if (profile.photoUrl == null) {
        data['photoUrl'] = FieldValue.delete();
      }

      // Update Firestore document
      await _firestore
          .collection(FirebaseCollections.users)
          .doc(profile.id)
          .set(data, SetOptions(merge: true));

      // Also update Firebase Auth profile for displayName and photoUrl sync
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && currentUser.uid == profile.id) {
        await currentUser.updateDisplayName(profile.displayName);
        // Mettre à jour photoURL même si null (pour supprimer)
        await currentUser.updatePhotoURL(profile.photoUrl);
        // Reload user to ensure changes are reflected
        await currentUser.reload();
      }

      return getProfile(profile.id);
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors de la mise à jour');
    }
  }

  @override
  Future<String> uploadProfilePhoto(String userId, String filePath) async {
    try {
      final file = File(filePath);
      final ref = _storage.ref().child('profiles/$userId/photo.jpg');

      await ref.putFile(file);
      final url = await ref.getDownloadURL();

      // Update Firestore (use set with merge to create document if it doesn't exist)
      await _firestore.collection(FirebaseCollections.users).doc(userId).set({
        'photoUrl': url,
      }, SetOptions(merge: true));

      // Also update Firebase Auth photo URL
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && currentUser.uid == userId) {
        await currentUser.updatePhotoURL(url);
        await currentUser.reload();
      }

      return url;
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors du téléchargement');
    }
  }

  @override
  Future<void> updateLocation(
    String userId,
    double latitude,
    double longitude,
  ) async {
    try {
      // Use set with merge to create document if it doesn't exist
      await _firestore.collection(FirebaseCollections.users).doc(userId).set({
        'latitude': latitude,
        'longitude': longitude,
        'locationUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw ServerException(
        e.message ?? 'Erreur lors de la mise à jour de la localisation',
      );
    }
  }

  @override
  Future<List<ProfileModel>> getNearbyProfiles(
    double latitude,
    double longitude,
    double radiusKm,
  ) async {
    try {
      final isConnected = await _connectivity.isConnected();
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;

      // debugPrint('🗺️ getNearbyProfiles called:');
      // debugPrint('  📍 Position: ($latitude, $longitude)');
      // debugPrint('  📏 Radius: ${radiusKm}km');
      // debugPrint('  👤 Current user: $currentUserId');

      if (isConnected) {
        // Simple bounding box calculation for nearby search
        final latDelta = radiusKm / 111.0; // ~111km per degree latitude
        final lonDelta = radiusKm / (111.0 * _cos(latitude));

        // debugPrint('  🔍 Query bounds:');
        // debugPrint('    Lat: ${latitude - latDelta} to ${latitude + latDelta}');
        // debugPrint(
        //   '    Lon: ${longitude - lonDelta} to ${longitude + lonDelta}',
        // );

        // First try with isVisible filter
        var query =
            await _firestore
                .collection(FirebaseCollections.users)
                .where('isVisible', isEqualTo: true)
                .where('latitude', isGreaterThan: latitude - latDelta)
                .where('latitude', isLessThan: latitude + latDelta)
                .limit(50)
                .get();

        // debugPrint(
        //   '  📊 Query with isVisible=true returned: ${query.docs.length} docs',
        // );

        // If no results, try without isVisible filter
        if (query.docs.isEmpty) {
          // debugPrint('  🔄 Retrying without isVisible filter...');
          query =
              await _firestore
                  .collection(FirebaseCollections.users)
                  .where('latitude', isGreaterThan: latitude - latDelta)
                  .where('latitude', isLessThan: latitude + latDelta)
                  .limit(50)
                  .get();
          // debugPrint(
          //   '  📊 Query without isVisible returned: ${query.docs.length} docs',
          // );
        }

        final profiles =
            query.docs
                .map((doc) {
                  final data = doc.data();
                  data['id'] = doc.id;
                  return ProfileModel.fromJson(_convertTimestamps(data));
                })
                .where((profile) {
                  // Exclude current user
                  if (currentUserId != null && profile.id == currentUserId) {
                    return false;
                  }
                  if (profile.longitude == null) return false;
                  return profile.longitude! > longitude - lonDelta &&
                      profile.longitude! < longitude + lonDelta;
                })
                .toList();

        // debugPrint(
        //   '  ✅ After filtering (excluding current user): ${profiles.length} profiles',
        // );

        // Log details of each profile for debugging
        // for (var i = 0; i < profiles.length && i < 5; i++) {
        //   final p = profiles[i];
        //   debugPrint(
        //     '    👤 ${p.displayName ?? "Unknown"} - '
        //     'Visible: ${p.isVisible}, '
        //     'Coords: (${p.latitude}, ${p.longitude})',
        //   );
        // }
        // if (profiles.length > 5) {
        //   debugPrint('    ... and ${profiles.length - 5} more profiles');
        // }

        // Mettre en cache les profils
        await _cache.cacheProfiles(profiles.map((p) => p.toJson()).toList());

        return profiles;
      } else {
        // debugPrint('  📴 Offline mode - returning cached profiles');
        // Mode hors ligne - retourner les profils en cache
        return _getProfilesFromCache();
      }
    } on FirebaseException catch (e) {
      // debugPrint('  ❌ Firebase error: ${e.message}');
      final cached = _getProfilesFromCache();
      if (cached.isNotEmpty) return cached;
      throw ServerException(e.message ?? 'Erreur lors de la recherche');
    }
  }

  List<ProfileModel> _getProfilesFromCache() {
    final cachedData = _cache.getAllCachedProfiles();
    return cachedData.map((data) => ProfileModel.fromJson(data)).toList();
  }

  @override
  Future<List<ProfileModel>> getProfilesByCountry(String country) async {
    try {
      final isConnected = await _connectivity.isConnected();
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;

      // debugPrint('🌍 getProfilesByCountry called for: $country');
      // debugPrint('  👤 Current user: $currentUserId');

      if (isConnected) {
        // First try with isVisible filter
        var query =
            await _firestore
                .collection(FirebaseCollections.users)
                .where('isVisible', isEqualTo: true)
                .where('currentCountry', isEqualTo: country)
                .limit(100)
                .get();

        // debugPrint(
        //   '  📊 Query with isVisible=true returned: ${query.docs.length} docs',
        // );

        // If no results, try without isVisible filter
        if (query.docs.isEmpty) {
          // debugPrint('  🔄 Retrying without isVisible filter...');
          query =
              await _firestore
                  .collection(FirebaseCollections.users)
                  .where('currentCountry', isEqualTo: country)
                  .limit(100)
                  .get();
          // debugPrint(
          //   '  📊 Query without isVisible returned: ${query.docs.length} docs',
          // );
        }

        final profiles =
            query.docs
                .map((doc) {
                  final data = doc.data();
                  data['id'] = doc.id;
                  return ProfileModel.fromJson(_convertTimestamps(data));
                })
                .where((profile) {
                  // Exclude current user
                  return currentUserId == null || profile.id != currentUserId;
                })
                .toList();

        // debugPrint(
        //   '  ✅ Found ${profiles.length} profiles in $country (excluding current user)',
        // );

        // Mettre en cache les profils
        await _cache.cacheProfiles(profiles.map((p) => p.toJson()).toList());

        return profiles;
      } else {
        // debugPrint('  📴 Offline mode - filtering cached profiles');
        // Mode hors ligne - filtrer les profils en cache par pays
        final cached = _getProfilesFromCache();
        return cached.where((p) => p.currentCountry == country).toList();
      }
    } on FirebaseException catch (e) {
      // debugPrint('  ❌ Firebase error: ${e.message}');
      final cached = _getProfilesFromCache();
      final filtered =
          cached.where((p) => p.currentCountry == country).toList();
      if (filtered.isNotEmpty) return filtered;
      throw ServerException(
        e.message ?? 'Erreur lors de la recherche par pays',
      );
    }
  }

  @override
  Future<List<ProfileModel>> searchProfiles(String query) async {
    try {
      final isConnected = await _connectivity.isConnected();

      if (isConnected) {
        final lowerQuery = query.toLowerCase();

        // Search by display name
        final results =
            await _firestore
                .collection(FirebaseCollections.users)
                .where('isVisible', isEqualTo: true)
                .orderBy('displayName')
                .startAt([lowerQuery])
                .endAt(['$lowerQuery\uf8ff'])
                .limit(20)
                .get();

        final profiles =
            results.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return ProfileModel.fromJson(_convertTimestamps(data));
            }).toList();

        for (final profile in profiles) {
          await _cache.cacheProfile(profile.id, profile.toJson());
        }

        return profiles;
      } else {
        // Recherche locale dans le cache
        final cached = _getProfilesFromCache();
        final lowerQuery = query.toLowerCase();
        return cached
            .where(
              (p) => (p.displayName ?? '').toLowerCase().contains(lowerQuery),
            )
            .take(20)
            .toList();
      }
    } on FirebaseException catch (e) {
      final cached = _getProfilesFromCache();
      final lowerQuery = query.toLowerCase();
      final filtered =
          cached
              .where(
                (p) => (p.displayName ?? '').toLowerCase().contains(lowerQuery),
              )
              .take(20)
              .toList();
      if (filtered.isNotEmpty) return filtered;
      throw ServerException(e.message ?? 'Erreur lors de la recherche');
    }
  }

  double _cos(double degrees) {
    return _cosDegrees(degrees);
  }

  double _cosDegrees(double degrees) {
    return _cosRadians(degrees * 3.14159265359 / 180);
  }

  double _cosRadians(double radians) {
    // Simple cosine approximation
    double x = radians % (2 * 3.14159265359);
    if (x < 0) x += 2 * 3.14159265359;

    double sign = 1;
    if (x > 3.14159265359) {
      x -= 3.14159265359;
      sign = -1;
    }
    if (x > 3.14159265359 / 2) {
      x = 3.14159265359 - x;
      sign *= -1;
    }

    double x2 = x * x;
    return sign * (1 - x2 / 2 + x2 * x2 / 24 - x2 * x2 * x2 / 720);
  }

  @override
  Stream<ProfileModel> getUserStream(String userId) {
    return _firestore
        .collection(FirebaseCollections.users)
        .doc(userId)
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists) {
            throw ServerException('Profil non trouvé');
          }
          final data = snapshot.data()!;
          data['id'] = snapshot.id;
          return ProfileModel.fromJson(_convertTimestamps(data));
        });
  }

  @override
  Future<void> updateLastLogin(String userId) async {
    try {
      await _firestore.collection(FirebaseCollections.users).doc(userId).update(
        {'lastLoginAt': FieldValue.serverTimestamp(), 'isOnline': true},
      );
    } on FirebaseException catch (_) {
      // On ne lance pas d'exception bloquante pour une mise à jour de log
      // debugPrint('Erreur lors de la mise à jour de lastLoginAt: ${e.message}');
    }
  }

  @override
  Future<void> updateOnlineStatus(
    String userId,
    bool isOnline,
    DateTime lastSeen,
  ) async {
    try {
      await _firestore.collection(FirebaseCollections.users).doc(userId).update(
        {'isOnline': isOnline, 'lastSeen': Timestamp.fromDate(lastSeen)},
      );
    } on FirebaseException {
      // debugPrint('Erreur lors de la mise à jour du statut: ${e.message}');
    }
  }

  @override
  Future<void> updateOnlineStatusVisibility(
    String userId,
    bool showStatus,
  ) async {
    try {
      await _firestore.collection(FirebaseCollections.users).doc(userId).update(
        {'showOnlineStatus': showStatus},
      );
    } on FirebaseException catch (e) {
      throw ServerException(
        e.message ?? 'Erreur lors de la mise à jour de la confidentialité',
      );
    }
  }

  @override
  Future<void> updateNotifyLocalEvents(String userId, bool enabled) async {
    try {
      await _firestore.collection(FirebaseCollections.users).doc(userId).update(
        {'notifyLocalEvents': enabled},
      );
    } on FirebaseException {
      // debugPrint(
      //   'Erreur lors de la mise à jour notifyLocalEvents: ${e.message}',
      // );
    }
  }

  Map<String, dynamic> _convertTimestamps(Map<String, dynamic> data) {
    final result = Map<String, dynamic>.from(data);

    result.forEach((key, value) {
      if (value is Timestamp) {
        result[key] = value.toDate().toIso8601String();
      }
    });

    return result;
  }

  @override
  ProfileModel? getCachedProfile(String userId) {
    try {
      final cachedData = _cache.getCachedProfile(userId);
      if (cachedData != null) {
        return ProfileModel.fromJson(cachedData);
      }
    } catch (e) {
      // debugPrint('Erreur lors de la récupération du profil en cache: $e');
    }
    return null;
  }
}
