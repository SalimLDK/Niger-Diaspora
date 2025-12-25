import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/firebase_collections.dart';
import '../../../../core/errors/exceptions.dart';
import '../../domain/repositories/friend_repository.dart';
import '../models/friend_model.dart';
import '../models/friend_request_model.dart';

abstract class FriendRemoteDataSource {
  // Friend Requests
  Future<void> sendFriendRequest({
    required String senderId,
    required String senderName,
    String? senderPhotoUrl,
    required String receiverId,
    required String receiverName,
    String? receiverPhotoUrl,
  });

  Future<void> acceptFriendRequest(String requestId);
  Future<void> declineFriendRequest(String requestId);
  Future<void> cancelFriendRequest(String requestId);
  Future<FriendRequestModel> getRequestById(String requestId);

  Stream<List<FriendRequestModel>> getReceivedRequests(String userId);
  Stream<List<FriendRequestModel>> getSentRequests(String userId);

  Future<FriendshipStatus> getFriendshipStatus(String userId1, String userId2);

  // Friends List
  Stream<List<FriendModel>> getFriends(String userId);
  Future<void> removeFriend(String userId, String friendId);
  Future<bool> areFriends(String userId1, String userId2);
  Future<List<FriendModel>> searchFriends(String userId, String query);
}

class FriendRemoteDataSourceImpl implements FriendRemoteDataSource {
  final FirebaseFirestore _firestore;

  FriendRemoteDataSourceImpl({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<void> sendFriendRequest({
    required String senderId,
    required String senderName,
    String? senderPhotoUrl,
    required String receiverId,
    required String receiverName,
    String? receiverPhotoUrl,
  }) async {
    try {
      // Check if a request already exists
      final existingRequest =
          await _firestore
              .collection(FirebaseCollections.friendRequests)
              .where('senderId', isEqualTo: senderId)
              .where('receiverId', isEqualTo: receiverId)
              .where('status', isEqualTo: 'pending')
              .get();

      if (existingRequest.docs.isNotEmpty) {
        throw ServerException('Une demande est déjà en attente');
      }

      // Check if reverse request exists
      final reverseRequest =
          await _firestore
              .collection(FirebaseCollections.friendRequests)
              .where('senderId', isEqualTo: receiverId)
              .where('receiverId', isEqualTo: senderId)
              .where('status', isEqualTo: 'pending')
              .get();

      if (reverseRequest.docs.isNotEmpty) {
        // Auto-accept if the other person already sent a request
        await acceptFriendRequest(reverseRequest.docs.first.id);
        return;
      }

      // Check if already friends
      final alreadyFriends = await areFriends(senderId, receiverId);
      if (alreadyFriends) {
        throw ServerException('Vous êtes déjà amis');
      }

      // Create the friend request
      await _firestore.collection(FirebaseCollections.friendRequests).add({
        'senderId': senderId,
        'senderName': senderName,
        'senderPhotoUrl': senderPhotoUrl,
        'receiverId': receiverId,
        'receiverName': receiverName,
        'receiverPhotoUrl': receiverPhotoUrl,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw ServerException(
        e.message ?? 'Erreur lors de l\'envoi de la demande',
      );
    }
  }

  @override
  Future<void> acceptFriendRequest(String requestId) async {
    try {
      final requestDoc =
          await _firestore
              .collection(FirebaseCollections.friendRequests)
              .doc(requestId)
              .get();

      if (!requestDoc.exists) {
        throw ServerException('Demande non trouvée');
      }

      final data = requestDoc.data()!;
      final senderId = data['senderId'] as String;
      final senderName = data['senderName'] as String;
      final senderPhotoUrl = data['senderPhotoUrl'] as String?;
      final receiverId = data['receiverId'] as String;
      final receiverName = data['receiverName'] as String;
      final receiverPhotoUrl = data['receiverPhotoUrl'] as String?;

      final batch = _firestore.batch();

      // Update request status
      batch.update(requestDoc.reference, {
        'status': 'accepted',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Add friend to sender's friends list
      final senderFriendRef = _firestore
          .collection(FirebaseCollections.users)
          .doc(senderId)
          .collection(FirebaseCollections.friends)
          .doc(receiverId);

      batch.set(senderFriendRef, {
        'id': receiverId,
        'displayName': receiverName,
        'photoUrl': receiverPhotoUrl,
        'addedAt': FieldValue.serverTimestamp(),
      });

      // Add friend to receiver's friends list
      final receiverFriendRef = _firestore
          .collection(FirebaseCollections.users)
          .doc(receiverId)
          .collection(FirebaseCollections.friends)
          .doc(senderId);

      batch.set(receiverFriendRef, {
        'id': senderId,
        'displayName': senderName,
        'photoUrl': senderPhotoUrl,
        'addedAt': FieldValue.serverTimestamp(),
      });

      // Update friend counts
      final senderRef = _firestore
          .collection(FirebaseCollections.users)
          .doc(senderId);
      batch.update(senderRef, {
        'friendIds': FieldValue.arrayUnion([receiverId]),
      });

      final receiverRef = _firestore
          .collection(FirebaseCollections.users)
          .doc(receiverId);
      batch.update(receiverRef, {
        'friendIds': FieldValue.arrayUnion([senderId]),
      });

      await batch.commit();
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors de l\'acceptation');
    }
  }

  @override
  Future<void> declineFriendRequest(String requestId) async {
    try {
      await _firestore
          .collection(FirebaseCollections.friendRequests)
          .doc(requestId)
          .update({
            'status': 'declined',
            'updatedAt': FieldValue.serverTimestamp(),
          });
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors du refus');
    }
  }

  @override
  Future<void> cancelFriendRequest(String requestId) async {
    try {
      await _firestore
          .collection(FirebaseCollections.friendRequests)
          .doc(requestId)
          .delete();
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors de l\'annulation');
    }
  }

  @override
  Future<FriendRequestModel> getRequestById(String requestId) async {
    try {
      final doc =
          await _firestore
              .collection(FirebaseCollections.friendRequests)
              .doc(requestId)
              .get();

      if (!doc.exists) {
        throw ServerException('Demande non trouvée');
      }

      final data = doc.data()!;
      data['id'] = doc.id;
      if (data['createdAt'] is Timestamp) {
        data['createdAt'] =
            (data['createdAt'] as Timestamp).toDate().toIso8601String();
      }
      if (data['updatedAt'] is Timestamp) {
        data['updatedAt'] =
            (data['updatedAt'] as Timestamp).toDate().toIso8601String();
      }
      return FriendRequestModel.fromJson(data);
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors de la récupération');
    }
  }

  @override
  Stream<List<FriendRequestModel>> getReceivedRequests(String userId) {
    return _firestore
        .collection(FirebaseCollections.friendRequests)
        .where('receiverId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            if (data['createdAt'] is Timestamp) {
              data['createdAt'] =
                  (data['createdAt'] as Timestamp).toDate().toIso8601String();
            }
            if (data['updatedAt'] is Timestamp) {
              data['updatedAt'] =
                  (data['updatedAt'] as Timestamp).toDate().toIso8601String();
            }
            return FriendRequestModel.fromJson(data);
          }).toList();
        });
  }

  @override
  Stream<List<FriendRequestModel>> getSentRequests(String userId) {
    return _firestore
        .collection(FirebaseCollections.friendRequests)
        .where('senderId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            if (data['createdAt'] is Timestamp) {
              data['createdAt'] =
                  (data['createdAt'] as Timestamp).toDate().toIso8601String();
            }
            if (data['updatedAt'] is Timestamp) {
              data['updatedAt'] =
                  (data['updatedAt'] as Timestamp).toDate().toIso8601String();
            }
            return FriendRequestModel.fromJson(data);
          }).toList();
        });
  }

  @override
  Future<FriendshipStatus> getFriendshipStatus(
    String userId1,
    String userId2,
  ) async {
    try {
      // Check if already friends
      final friendDoc =
          await _firestore
              .collection(FirebaseCollections.users)
              .doc(userId1)
              .collection(FirebaseCollections.friends)
              .doc(userId2)
              .get();

      if (friendDoc.exists) {
        return FriendshipStatus.friends;
      }

      // Check for pending request sent by userId1
      final sentRequest =
          await _firestore
              .collection(FirebaseCollections.friendRequests)
              .where('senderId', isEqualTo: userId1)
              .where('receiverId', isEqualTo: userId2)
              .where('status', isEqualTo: 'pending')
              .get();

      if (sentRequest.docs.isNotEmpty) {
        return FriendshipStatus.pendingSent;
      }

      // Check for pending request received by userId1
      final receivedRequest =
          await _firestore
              .collection(FirebaseCollections.friendRequests)
              .where('senderId', isEqualTo: userId2)
              .where('receiverId', isEqualTo: userId1)
              .where('status', isEqualTo: 'pending')
              .get();

      if (receivedRequest.docs.isNotEmpty) {
        return FriendshipStatus.pendingReceived;
      }

      return FriendshipStatus.none;
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors de la vérification');
    }
  }

  @override
  Stream<List<FriendModel>> getFriends(String userId) {
    return _firestore
        .collection(FirebaseCollections.users)
        .doc(userId)
        .collection(FirebaseCollections.friends)
        .orderBy('addedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            if (data['addedAt'] is Timestamp) {
              data['addedAt'] =
                  (data['addedAt'] as Timestamp).toDate().toIso8601String();
            }
            return FriendModel.fromJson(data);
          }).toList();
        });
  }

  @override
  Future<void> removeFriend(String userId, String friendId) async {
    try {
      final batch = _firestore.batch();

      // Remove from user's friends list
      final userFriendRef = _firestore
          .collection(FirebaseCollections.users)
          .doc(userId)
          .collection(FirebaseCollections.friends)
          .doc(friendId);
      batch.delete(userFriendRef);

      // Remove from friend's friends list
      final friendFriendRef = _firestore
          .collection(FirebaseCollections.users)
          .doc(friendId)
          .collection(FirebaseCollections.friends)
          .doc(userId);
      batch.delete(friendFriendRef);

      // Update friendIds arrays
      final userRef = _firestore
          .collection(FirebaseCollections.users)
          .doc(userId);
      batch.update(userRef, {
        'friendIds': FieldValue.arrayRemove([friendId]),
      });

      final friendRef = _firestore
          .collection(FirebaseCollections.users)
          .doc(friendId);
      batch.update(friendRef, {
        'friendIds': FieldValue.arrayRemove([userId]),
      });

      await batch.commit();
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors de la suppression');
    }
  }

  @override
  Future<bool> areFriends(String userId1, String userId2) async {
    try {
      final doc =
          await _firestore
              .collection(FirebaseCollections.users)
              .doc(userId1)
              .collection(FirebaseCollections.friends)
              .doc(userId2)
              .get();

      return doc.exists;
    } on FirebaseException {
      return false;
    }
  }

  @override
  Future<List<FriendModel>> searchFriends(String userId, String query) async {
    try {
      final snapshot =
          await _firestore
              .collection(FirebaseCollections.users)
              .doc(userId)
              .collection(FirebaseCollections.friends)
              .orderBy('displayName')
              .startAt([query.toLowerCase()])
              .endAt(['${query.toLowerCase()}\uf8ff'])
              .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        if (data['addedAt'] is Timestamp) {
          data['addedAt'] =
              (data['addedAt'] as Timestamp).toDate().toIso8601String();
        }
        return FriendModel.fromJson(data);
      }).toList();
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors de la recherche');
    }
  }
}
