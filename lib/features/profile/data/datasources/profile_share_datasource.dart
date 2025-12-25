import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/firebase_collections.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/profile_share_link_model.dart';

abstract class ProfileShareDataSource {
  Future<ProfileShareLinkModel> generateShareLink(String userId);
  Future<String?> getUserIdByShareCode(String shortCode);
  Future<void> incrementClickCount(String linkId);
  Future<ProfileShareLinkModel?> getShareLinkByUserId(String userId);
}

class ProfileShareDataSourceImpl implements ProfileShareDataSource {
  final FirebaseFirestore _firestore;

  ProfileShareDataSourceImpl({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  String _generateShortCode() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return List.generate(8, (_) => chars[random.nextInt(chars.length)]).join();
  }

  @override
  Future<ProfileShareLinkModel> generateShareLink(String userId) async {
    try {
      // Check if user already has a share link
      final existing = await getShareLinkByUserId(userId);
      if (existing != null) {
        return existing;
      }

      // Generate unique short code
      String shortCode;
      bool isUnique = false;

      do {
        shortCode = _generateShortCode();
        final check = await _firestore
            .collection(FirebaseCollections.profileShareLinks)
            .where('shortCode', isEqualTo: shortCode)
            .get();
        isUnique = check.docs.isEmpty;
      } while (!isUnique);

      // Create the share link
      final docRef = await _firestore
          .collection(FirebaseCollections.profileShareLinks)
          .add({
        'userId': userId,
        'shortCode': shortCode,
        'createdAt': FieldValue.serverTimestamp(),
        'clickCount': 0,
      });

      final doc = await docRef.get();
      final data = doc.data()!;
      data['id'] = doc.id;
      if (data['createdAt'] is Timestamp) {
        data['createdAt'] =
            (data['createdAt'] as Timestamp).toDate().toIso8601String();
      }

      return ProfileShareLinkModel.fromJson(data);
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors de la génération du lien');
    }
  }

  @override
  Future<String?> getUserIdByShareCode(String shortCode) async {
    try {
      final snapshot = await _firestore
          .collection(FirebaseCollections.profileShareLinks)
          .where('shortCode', isEqualTo: shortCode)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      final data = snapshot.docs.first.data();

      // Increment click count
      await incrementClickCount(snapshot.docs.first.id);

      return data['userId'] as String?;
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors de la recherche');
    }
  }

  @override
  Future<void> incrementClickCount(String linkId) async {
    try {
      await _firestore
          .collection(FirebaseCollections.profileShareLinks)
          .doc(linkId)
          .update({
        'clickCount': FieldValue.increment(1),
      });
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors de la mise à jour');
    }
  }

  @override
  Future<ProfileShareLinkModel?> getShareLinkByUserId(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(FirebaseCollections.profileShareLinks)
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      final doc = snapshot.docs.first;
      final data = doc.data();
      data['id'] = doc.id;
      if (data['createdAt'] is Timestamp) {
        data['createdAt'] =
            (data['createdAt'] as Timestamp).toDate().toIso8601String();
      }
      if (data['expiresAt'] is Timestamp) {
        data['expiresAt'] =
            (data['expiresAt'] as Timestamp).toDate().toIso8601String();
      }

      return ProfileShareLinkModel.fromJson(data);
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors de la recherche');
    }
  }
}
