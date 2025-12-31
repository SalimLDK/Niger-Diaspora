import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/firebase_collections.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/blocked_user_model.dart';

abstract class BlockedUsersDataSource {
  Stream<List<BlockedUserModel>> getBlockedUsers(String userId);
  Future<void> blockUser(String currentUserId, String targetUserId, String targetDisplayName, String? targetPhotoUrl);
  Future<void> unblockUser(String currentUserId, String targetUserId);
}

class BlockedUsersDataSourceImpl implements BlockedUsersDataSource {
  final FirebaseFirestore _firestore;

  BlockedUsersDataSourceImpl({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Stream<List<BlockedUserModel>> getBlockedUsers(String userId) {
    return _firestore
        .collection(FirebaseCollections.users)
        .doc(userId)
        .collection('blocked_users')
        .orderBy('blockedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        if (data['blockedAt'] is Timestamp) {
          data['blockedAt'] = (data['blockedAt'] as Timestamp).toDate().toIso8601String();
        }
        return BlockedUserModel.fromJson(data);
      }).toList();
    });
  }

  @override
  Future<void> blockUser(
    String currentUserId,
    String targetUserId,
    String targetDisplayName,
    String? targetPhotoUrl,
  ) async {
    try {
      final batch = _firestore.batch();

      // Add to blocked_users subcollection
      final blockedUserRef = _firestore
          .collection(FirebaseCollections.users)
          .doc(currentUserId)
          .collection('blocked_users')
          .doc(targetUserId);

      batch.set(blockedUserRef, {
        'id': targetUserId,
        'displayName': targetDisplayName,
        'photoUrl': targetPhotoUrl,
        'blockedAt': FieldValue.serverTimestamp(),
      });

      // Add to blockedUserIds array for quick lookup
      final userRef = _firestore.collection(FirebaseCollections.users).doc(currentUserId);
      batch.update(userRef, {
        'blockedUserIds': FieldValue.arrayUnion([targetUserId]),
      });

      // Add currentUserId to target's blockedByUserIds for reverse lookup
      final targetRef = _firestore.collection(FirebaseCollections.users).doc(targetUserId);
      batch.set(targetRef, {
        'blockedByUserIds': FieldValue.arrayUnion([currentUserId]),
      }, SetOptions(merge: true));

      await batch.commit();
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors du blocage');
    }
  }

  @override
  Future<void> unblockUser(String currentUserId, String targetUserId) async {
    try {
      final batch = _firestore.batch();

      // Remove from blocked_users subcollection
      final blockedUserRef = _firestore
          .collection(FirebaseCollections.users)
          .doc(currentUserId)
          .collection('blocked_users')
          .doc(targetUserId);

      batch.delete(blockedUserRef);

      // Remove from blockedUserIds array
      final userRef = _firestore.collection(FirebaseCollections.users).doc(currentUserId);
      batch.update(userRef, {
        'blockedUserIds': FieldValue.arrayRemove([targetUserId]),
      });

      // Remove currentUserId from target's blockedByUserIds
      final targetRef = _firestore.collection(FirebaseCollections.users).doc(targetUserId);
      batch.set(targetRef, {
        'blockedByUserIds': FieldValue.arrayRemove([currentUserId]),
      }, SetOptions(merge: true));

      await batch.commit();
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors du déblocage');
    }
  }
}
