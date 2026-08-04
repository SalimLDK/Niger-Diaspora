import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/firebase_collections.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/connectivity_service.dart';
import '../models/business_model.dart';
import '../models/business_boost_model.dart';
import '../models/business_post_model.dart';

abstract class BusinessRemoteDataSource {
  // Businesses - Read
  Future<List<BusinessModel>> getBusinesses({bool featuredFirst = true, int limit = 20});
  Future<List<BusinessModel>> getBusinessesByCategory(String category);
  Future<List<BusinessModel>> searchBusinesses(String query);
  Future<List<BusinessModel>> getNearbyBusinesses(double lat, double lng, double radiusKm);
  Future<List<BusinessModel>> getBusinessesByLocation({String? country, String? city});
  Future<BusinessModel> getBusinessById(String id);
  Future<BusinessModel?> getMyBusiness(String ownerId);
  Future<List<BusinessModel>> getMyBusinesses(String ownerId);

  // Businesses - Write
  Future<BusinessModel> createBusiness(BusinessModel business);
  Future<BusinessModel> updateBusiness(BusinessModel business);
  Future<void> deleteBusiness(String id);
  Future<void> incrementViewCount(String businessId);

  // Boosts
  Future<BusinessBoostModel> createBoost(BusinessBoostModel boost);
  Future<List<BusinessBoostModel>> getBoostHistory(String businessId);
  Future<BusinessBoostModel?> getActiveBoost(String businessId);
  Future<void> updateBusinessBoostStatus(String businessId, bool isBoosted, DateTime? expiresAt);

  // Posts
  Future<List<BusinessPostModel>> getBusinessPosts(String businessId, {int limit = 20});
  Future<List<BusinessPostModel>> getActiveOffers(String businessId);
  Future<BusinessPostModel> createPost(BusinessPostModel post);
  Future<BusinessPostModel> updatePost(BusinessPostModel post);
  Future<void> deletePost(String postId);
}

class BusinessRemoteDataSourceImpl implements BusinessRemoteDataSource {
  final FirebaseFirestore _firestore;
  final ConnectivityService _connectivity = ConnectivityService.instance;

  BusinessRemoteDataSourceImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _businessesCollection =>
      _firestore.collection(FirebaseCollections.businesses);

  CollectionReference get _boostsCollection =>
      _firestore.collection(FirebaseCollections.businessBoosts);

  @override
  Future<List<BusinessModel>> getBusinesses({
    bool featuredFirst = true,
    int limit = 20,
  }) async {
    try {
      final isConnected = await _connectivity.isConnected();
      if (!isConnected) {
        throw ServerException('Pas de connexion internet');
      }

      Query query = _businessesCollection;

      if (featuredFirst) {
        // Les businesses boostés en premier, puis par date de création
        query = query
            .orderBy('isBoosted', descending: true)
            .orderBy('createdAt', descending: true);
      } else {
        query = query.orderBy('createdAt', descending: true);
      }

      final snapshot = await query.limit(limit).get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return BusinessModel.fromJson(_convertTimestamps(data));
      }).toList();
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors du chargement des entreprises');
    }
  }

  @override
  Future<List<BusinessModel>> getBusinessesByCategory(String category) async {
    try {
      final isConnected = await _connectivity.isConnected();
      if (!isConnected) {
        throw ServerException('Pas de connexion internet');
      }

      final snapshot = await _businessesCollection
          .where('category', isEqualTo: category)
          .orderBy('isBoosted', descending: true)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return BusinessModel.fromJson(_convertTimestamps(data));
      }).toList();
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors du chargement');
    }
  }

  @override
  Future<List<BusinessModel>> searchBusinesses(String query) async {
    try {
      final isConnected = await _connectivity.isConnected();
      if (!isConnected) {
        throw ServerException('Pas de connexion internet');
      }

      final lowerQuery = query.toLowerCase();

      final snapshot = await _businessesCollection
          .orderBy('name')
          .startAt([lowerQuery])
          .endAt(['$lowerQuery\uf8ff'])
          .limit(20)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return BusinessModel.fromJson(_convertTimestamps(data));
      }).toList();
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors de la recherche');
    }
  }

  @override
  Future<List<BusinessModel>> getNearbyBusinesses(
    double lat,
    double lng,
    double radiusKm,
  ) async {
    try {
      final isConnected = await _connectivity.isConnected();
      if (!isConnected) {
        throw ServerException('Pas de connexion internet');
      }

      // Calcul du bounding box approximatif
      final latDelta = radiusKm / 111.0; // ~111km par degré de latitude
      final lonDelta = radiusKm / (111.0 * _cos(lat));

      final snapshot = await _businessesCollection
          .where('latitude', isGreaterThan: lat - latDelta)
          .where('latitude', isLessThan: lat + latDelta)
          .limit(50)
          .get();

      // Filtrer par longitude côté client
      final businesses = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return BusinessModel.fromJson(_convertTimestamps(data));
      }).where((b) {
        if (b.longitude == null) return false;
        return b.longitude! >= lng - lonDelta && b.longitude! <= lng + lonDelta;
      }).toList();

      return businesses;
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors de la recherche');
    }
  }

  double _cos(double degrees) {
    return degrees * 3.14159265359 / 180.0;
  }

  @override
  Future<BusinessModel> getBusinessById(String id) async {
    try {
      final isConnected = await _connectivity.isConnected();
      if (!isConnected) {
        throw ServerException('Pas de connexion internet');
      }

      final doc = await _businessesCollection.doc(id).get();

      if (!doc.exists) {
        throw ServerException('Entreprise non trouvee');
      }

      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return BusinessModel.fromJson(_convertTimestamps(data));
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors du chargement');
    }
  }

  @override
  Future<BusinessModel?> getMyBusiness(String ownerId) async {
    try {
      final isConnected = await _connectivity.isConnected();
      if (!isConnected) {
        throw ServerException('Pas de connexion internet');
      }

      final snapshot = await _businessesCollection
          .where('ownerId', isEqualTo: ownerId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      final doc = snapshot.docs.first;
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return BusinessModel.fromJson(_convertTimestamps(data));
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors du chargement');
    }
  }

  @override
  Future<List<BusinessModel>> getMyBusinesses(String ownerId) async {
    try {
      final isConnected = await _connectivity.isConnected();
      if (!isConnected) {
        throw ServerException('Pas de connexion internet');
      }

      // Pas de .limit(1) : un propriétaire peut avoir plusieurs entreprises.
      final snapshot = await _businessesCollection
          .where('ownerId', isEqualTo: ownerId)
          .get();

      final businesses = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return BusinessModel.fromJson(_convertTimestamps(data));
      }).toList();

      // Les plus récentes en premier (tri client pour éviter un index composite).
      businesses.sort((a, b) {
        final da = a.createdAt;
        final db = b.createdAt;
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return db.compareTo(da);
      });
      return businesses;
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors du chargement');
    }
  }

  @override
  Future<List<BusinessModel>> getBusinessesByLocation({
    String? country,
    String? city,
  }) async {
    try {
      final isConnected = await _connectivity.isConnected();
      if (!isConnected) {
        throw ServerException('Pas de connexion internet');
      }

      Query query = _businessesCollection;

      // Appliquer les filtres de localisation
      if (country != null && country.isNotEmpty) {
        query = query.where('country', isEqualTo: country);
      }
      if (city != null && city.isNotEmpty) {
        query = query.where('city', isEqualTo: city);
      }

      // Trier par boost puis par date
      query = query
          .orderBy('isBoosted', descending: true)
          .orderBy('createdAt', descending: true)
          .limit(50);

      final snapshot = await query.get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return BusinessModel.fromJson(_convertTimestamps(data));
      }).toList();
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors du chargement');
    }
  }

  @override
  Future<BusinessModel> createBusiness(BusinessModel business) async {
    try {
      final data = business.toJson();
      data.remove('id');
      data['createdAt'] = FieldValue.serverTimestamp();
      data['updatedAt'] = FieldValue.serverTimestamp();
      data['viewCount'] = 0;
      data['averageRating'] = 0.0;
      data['reviewCount'] = 0;
      data['isBoosted'] = false;
      data['isVerified'] = false;

      final docRef = await _businessesCollection.add(data);
      return getBusinessById(docRef.id);
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors de la creation');
    }
  }

  @override
  Future<BusinessModel> updateBusiness(BusinessModel business) async {
    try {
      final data = business.toJson();
      data.remove('id');
      data['updatedAt'] = FieldValue.serverTimestamp();

      await _businessesCollection.doc(business.id).update(data);
      return getBusinessById(business.id);
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors de la mise a jour');
    }
  }

  @override
  Future<void> deleteBusiness(String id) async {
    try {
      await _businessesCollection.doc(id).delete();
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors de la suppression');
    }
  }

  @override
  Future<void> incrementViewCount(String businessId) async {
    try {
      await _businessesCollection.doc(businessId).update({
        'viewCount': FieldValue.increment(1),
      });
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors de la mise a jour');
    }
  }

  // Boosts

  @override
  Future<BusinessBoostModel> createBoost(BusinessBoostModel boost) async {
    try {
      final data = boost.toJson();
      data.remove('id');
      data['createdAt'] = FieldValue.serverTimestamp();

      final docRef = await _boostsCollection.add(data);

      // Mettre à jour le statut du business
      await updateBusinessBoostStatus(boost.businessId, true, boost.endDate);

      // Récupérer le boost créé
      final doc = await docRef.get();
      final boostData = doc.data() as Map<String, dynamic>;
      boostData['id'] = doc.id;
      return BusinessBoostModel.fromJson(_convertTimestamps(boostData));
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors de l\'achat du boost');
    }
  }

  @override
  Future<List<BusinessBoostModel>> getBoostHistory(String businessId) async {
    try {
      final snapshot = await _boostsCollection
          .where('businessId', isEqualTo: businessId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return BusinessBoostModel.fromJson(_convertTimestamps(data));
      }).toList();
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors du chargement');
    }
  }

  @override
  Future<BusinessBoostModel?> getActiveBoost(String businessId) async {
    try {
      final now = DateTime.now();
      final snapshot = await _boostsCollection
          .where('businessId', isEqualTo: businessId)
          .where('status', isEqualTo: 'active')
          .where('endDate', isGreaterThan: Timestamp.fromDate(now))
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      final doc = snapshot.docs.first;
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return BusinessBoostModel.fromJson(_convertTimestamps(data));
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors du chargement');
    }
  }

  @override
  Future<void> updateBusinessBoostStatus(
    String businessId,
    bool isBoosted,
    DateTime? expiresAt,
  ) async {
    try {
      await _businessesCollection.doc(businessId).update({
        'isBoosted': isBoosted,
        'boostExpiresAt': expiresAt != null
            ? Timestamp.fromDate(expiresAt)
            : FieldValue.delete(),
      });
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors de la mise a jour');
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

  // ============ POSTS ============

  CollectionReference get _postsCollection =>
      _firestore.collection(FirebaseCollections.businessPosts);

  @override
  Future<List<BusinessPostModel>> getBusinessPosts(
    String businessId, {
    int limit = 20,
  }) async {
    try {
      final isConnected = await _connectivity.isConnected();
      if (!isConnected) {
        throw ServerException('Pas de connexion internet');
      }

      final snapshot = await _postsCollection
          .where('businessId', isEqualTo: businessId)
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return BusinessPostModel.fromJson(_convertTimestamps(data));
      }).toList();
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors du chargement des posts');
    }
  }

  @override
  Future<List<BusinessPostModel>> getActiveOffers(String businessId) async {
    try {
      final isConnected = await _connectivity.isConnected();
      if (!isConnected) {
        throw ServerException('Pas de connexion internet');
      }

      final now = DateTime.now();
      final snapshot = await _postsCollection
          .where('businessId', isEqualTo: businessId)
          .where('type', isEqualTo: 'offer')
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .get();

      // Filtrer côté client les offres encore valides
      final posts = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return BusinessPostModel.fromJson(_convertTimestamps(data));
      }).where((post) {
        if (post.offerEndDate == null) return true;
        final endDate = DateTime.tryParse(post.offerEndDate!);
        return endDate == null || endDate.isAfter(now);
      }).toList();

      return posts;
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors du chargement des offres');
    }
  }

  @override
  Future<BusinessPostModel> createPost(BusinessPostModel post) async {
    try {
      final data = post.toJson();
      data.remove('id');
      data['createdAt'] = FieldValue.serverTimestamp();
      data['updatedAt'] = FieldValue.serverTimestamp();
      data['viewCount'] = 0;
      data['likeCount'] = 0;
      data['isActive'] = true;

      final docRef = await _postsCollection.add(data);

      final doc = await docRef.get();
      final postData = doc.data() as Map<String, dynamic>;
      postData['id'] = doc.id;
      return BusinessPostModel.fromJson(_convertTimestamps(postData));
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors de la creation du post');
    }
  }

  @override
  Future<BusinessPostModel> updatePost(BusinessPostModel post) async {
    try {
      final data = post.toJson();
      data.remove('id');
      data['updatedAt'] = FieldValue.serverTimestamp();

      await _postsCollection.doc(post.id).update(data);

      final doc = await _postsCollection.doc(post.id).get();
      final postData = doc.data() as Map<String, dynamic>;
      postData['id'] = doc.id;
      return BusinessPostModel.fromJson(_convertTimestamps(postData));
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors de la mise a jour du post');
    }
  }

  @override
  Future<void> deletePost(String postId) async {
    try {
      await _postsCollection.doc(postId).delete();
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors de la suppression du post');
    }
  }
}
