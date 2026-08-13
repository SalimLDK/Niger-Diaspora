import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/firebase_collections.dart';
import '../../../../core/errors/app_error_messages.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/connectivity_service.dart';
import '../models/review_model.dart';

abstract class ReviewRemoteDataSource {
  // Reviews - Read
  Future<List<ReviewModel>> getReviewsForBusiness(
    String businessId, {
    int limit = 20,
    String? lastReviewId,
  });
  Future<ReviewModel?> getUserReviewForBusiness(String userId, String businessId);
  Future<List<ReviewModel>> getUserReviews(String userId);

  // Reviews - Write
  Future<ReviewModel> createReview(ReviewModel review);
  Future<ReviewModel> updateReview(ReviewModel review);
  Future<void> deleteReview(String reviewId);

  // Reviews - Actions
  Future<void> markHelpful(String reviewId, String userId);
  Future<void> unmarkHelpful(String reviewId, String userId);
  Future<void> reportReview(String reviewId, String reason, String reporterId);
}

class ReviewRemoteDataSourceImpl implements ReviewRemoteDataSource {
  final FirebaseFirestore _firestore;
  final ConnectivityService _connectivity = ConnectivityService.instance;

  ReviewRemoteDataSourceImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _reviewsCollection =>
      _firestore.collection(FirebaseCollections.businessReviews);

  CollectionReference get _reportsCollection =>
      _firestore.collection(FirebaseCollections.reports);

  @override
  Future<List<ReviewModel>> getReviewsForBusiness(
    String businessId, {
    int limit = 20,
    String? lastReviewId,
  }) async {
    try {
      final isConnected = await _connectivity.isConnected();
      if (!isConnected) {
        throw ServerException(AppErrorMessages.networkError);
      }

      Query query = _reviewsCollection
          .where('businessId', isEqualTo: businessId)
          .where('status', isEqualTo: 'published')
          .orderBy('createdAt', descending: true);

      if (lastReviewId != null) {
        final lastDoc = await _reviewsCollection.doc(lastReviewId).get();
        if (lastDoc.exists) {
          query = query.startAfterDocument(lastDoc);
        }
      }

      final snapshot = await query.limit(limit).get();

      return snapshot.docs.map((doc) => ReviewModel.fromFirestore(doc)).toList();
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors du chargement des avis');
    }
  }

  @override
  Future<ReviewModel?> getUserReviewForBusiness(
    String userId,
    String businessId,
  ) async {
    try {
      final isConnected = await _connectivity.isConnected();
      if (!isConnected) {
        throw ServerException(AppErrorMessages.networkError);
      }

      final snapshot = await _reviewsCollection
          .where('userId', isEqualTo: userId)
          .where('businessId', isEqualTo: businessId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      return ReviewModel.fromFirestore(snapshot.docs.first);
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors du chargement');
    }
  }

  @override
  Future<List<ReviewModel>> getUserReviews(String userId) async {
    try {
      final isConnected = await _connectivity.isConnected();
      if (!isConnected) {
        throw ServerException(AppErrorMessages.networkError);
      }

      final snapshot = await _reviewsCollection
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => ReviewModel.fromFirestore(doc)).toList();
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors du chargement des avis');
    }
  }

  @override
  Future<ReviewModel> createReview(ReviewModel review) async {
    try {
      final isConnected = await _connectivity.isConnected();
      if (!isConnected) {
        throw ServerException(AppErrorMessages.networkError);
      }

      // Verifier si l'utilisateur a deja laisse un avis pour ce business
      final existingReview = await getUserReviewForBusiness(
        review.userId,
        review.businessId,
      );

      if (existingReview != null) {
        throw ServerException('Vous avez deja laisse un avis pour ce business');
      }

      final data = review.toJson();
      data.remove('id');
      data['createdAt'] = FieldValue.serverTimestamp();
      data['updatedAt'] = FieldValue.serverTimestamp();
      data['helpfulCount'] = 0;
      data['helpfulByUserIds'] = [];
      data['status'] = 'published';

      final docRef = await _reviewsCollection.add(data);
      final doc = await docRef.get();
      return ReviewModel.fromFirestore(doc);
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors de la creation de l\'avis');
    }
  }

  @override
  Future<ReviewModel> updateReview(ReviewModel review) async {
    try {
      final isConnected = await _connectivity.isConnected();
      if (!isConnected) {
        throw ServerException(AppErrorMessages.networkError);
      }

      final data = review.toJson();
      data.remove('id');
      data.remove('createdAt');
      data.remove('helpfulCount');
      data.remove('helpfulByUserIds');
      data['updatedAt'] = FieldValue.serverTimestamp();

      await _reviewsCollection.doc(review.id).update(data);
      final doc = await _reviewsCollection.doc(review.id).get();
      return ReviewModel.fromFirestore(doc);
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors de la mise a jour de l\'avis');
    }
  }

  @override
  Future<void> deleteReview(String reviewId) async {
    try {
      final isConnected = await _connectivity.isConnected();
      if (!isConnected) {
        throw ServerException(AppErrorMessages.networkError);
      }

      await _reviewsCollection.doc(reviewId).delete();
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors de la suppression de l\'avis');
    }
  }

  @override
  Future<void> markHelpful(String reviewId, String userId) async {
    try {
      final isConnected = await _connectivity.isConnected();
      if (!isConnected) {
        throw ServerException(AppErrorMessages.networkError);
      }

      await _reviewsCollection.doc(reviewId).update({
        'helpfulCount': FieldValue.increment(1),
        'helpfulByUserIds': FieldValue.arrayUnion([userId]),
      });
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur');
    }
  }

  @override
  Future<void> unmarkHelpful(String reviewId, String userId) async {
    try {
      final isConnected = await _connectivity.isConnected();
      if (!isConnected) {
        throw ServerException(AppErrorMessages.networkError);
      }

      await _reviewsCollection.doc(reviewId).update({
        'helpfulCount': FieldValue.increment(-1),
        'helpfulByUserIds': FieldValue.arrayRemove([userId]),
      });
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur');
    }
  }

  @override
  Future<void> reportReview(
    String reviewId,
    String reason,
    String reporterId,
  ) async {
    try {
      final isConnected = await _connectivity.isConnected();
      if (!isConnected) {
        throw ServerException(AppErrorMessages.networkError);
      }

      // Creer un rapport
      await _reportsCollection.add({
        'targetType': 'business_review',
        'targetId': reviewId,
        'reason': reason,
        'reporterId': reporterId,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Marquer l'avis comme signale si plusieurs rapports
      final reports = await _reportsCollection
          .where('targetId', isEqualTo: reviewId)
          .where('targetType', isEqualTo: 'business_review')
          .get();

      if (reports.docs.length >= 3) {
        await _reviewsCollection.doc(reviewId).update({
          'status': 'flagged',
        });
      }
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors du signalement');
    }
  }
}
