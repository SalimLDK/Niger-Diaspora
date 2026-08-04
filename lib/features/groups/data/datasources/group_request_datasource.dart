import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/firebase_collections.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/group_request_model.dart';
import '../models/group_invite_model.dart';

abstract class GroupRequestDataSource {
  // Group Join Requests
  Future<void> requestToJoinGroup({
    required String groupId,
    required String groupName,
    String? groupImageUrl,
    required String requesterId,
    required String requesterName,
    String? requesterPhotoUrl,
    String? message,
  });

  Future<void> approveJoinRequest(String requestId);
  Future<void> rejectJoinRequest(String requestId);
  Future<void> cancelJoinRequest(String requestId);

  Stream<List<GroupRequestModel>> getPendingRequests(String groupId);
  Stream<List<GroupRequestModel>> getMyGroupRequests(String userId);

  // Group Invites
  Future<void> inviteUserToGroup({
    required String groupId,
    required String groupName,
    String? groupImageUrl,
    required String inviterId,
    required String inviterName,
    required String inviteeId,
    required String inviteeName,
    String? inviteePhotoUrl,
  });

  Future<void> acceptGroupInvite(String inviteId);
  Future<void> declineGroupInvite(String inviteId);
  Future<void> cancelGroupInvite(String inviteId);

  Stream<List<GroupInviteModel>> getReceivedInvites(String userId);
  Stream<List<GroupInviteModel>> getSentInvites(String groupId);
}

class GroupRequestDataSourceImpl implements GroupRequestDataSource {
  final FirebaseFirestore _firestore;

  GroupRequestDataSourceImpl({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  // ==================== GROUP JOIN REQUESTS ====================

  @override
  Future<void> requestToJoinGroup({
    required String groupId,
    required String groupName,
    String? groupImageUrl,
    required String requesterId,
    required String requesterName,
    String? requesterPhotoUrl,
    String? message,
  }) async {
    try {
      // Check if already a member
      final groupDoc = await _firestore
          .collection(FirebaseCollections.groups)
          .doc(groupId)
          .get();

      if (groupDoc.exists) {
        final memberIds =
            List<String>.from(groupDoc.data()?['memberIds'] ?? []);
        if (memberIds.contains(requesterId)) {
          throw ServerException('Vous êtes déjà membre de ce groupe');
        }
      }

      // Check if a request already exists
      final existingRequest = await _firestore
          .collection(FirebaseCollections.groupRequests)
          .where('groupId', isEqualTo: groupId)
          .where('requesterId', isEqualTo: requesterId)
          .where('status', isEqualTo: 'pending')
          .get();

      if (existingRequest.docs.isNotEmpty) {
        throw ServerException('Une demande est déjà en attente');
      }

      // Create the request
      await _firestore.collection(FirebaseCollections.groupRequests).add({
        'groupId': groupId,
        'groupName': groupName,
        'groupImageUrl': groupImageUrl,
        'requesterId': requesterId,
        'requesterName': requesterName,
        'requesterPhotoUrl': requesterPhotoUrl,
        'status': 'pending',
        'message': message,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors de la demande');
    }
  }

  @override
  Future<void> approveJoinRequest(String requestId) async {
    try {
      final requestDoc = await _firestore
          .collection(FirebaseCollections.groupRequests)
          .doc(requestId)
          .get();

      if (!requestDoc.exists) {
        throw ServerException('Demande non trouvée');
      }

      final data = requestDoc.data()!;
      final groupId = data['groupId'] as String;
      final requesterId = data['requesterId'] as String;

      final batch = _firestore.batch();

      // Update request status
      batch.update(requestDoc.reference, {
        'status': 'approved',
        'processedAt': FieldValue.serverTimestamp(),
      });

      // Add user to group members
      final groupRef =
          _firestore.collection(FirebaseCollections.groups).doc(groupId);
      batch.update(groupRef, {
        'memberIds': FieldValue.arrayUnion([requesterId]),
      });

      await batch.commit();
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors de l\'approbation');
    }
  }

  @override
  Future<void> rejectJoinRequest(String requestId) async {
    try {
      await _firestore
          .collection(FirebaseCollections.groupRequests)
          .doc(requestId)
          .update({
        'status': 'rejected',
        'processedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors du refus');
    }
  }

  @override
  Future<void> cancelJoinRequest(String requestId) async {
    try {
      await _firestore
          .collection(FirebaseCollections.groupRequests)
          .doc(requestId)
          .delete();
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors de l\'annulation');
    }
  }

  @override
  Stream<List<GroupRequestModel>> getPendingRequests(String groupId) {
    return _firestore
        .collection(FirebaseCollections.groupRequests)
        .where('groupId', isEqualTo: groupId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        if (data['createdAt'] is Timestamp) {
          data['createdAt'] =
              (data['createdAt'] as Timestamp).toDate().toUtc().toIso8601String();
        }
        if (data['processedAt'] is Timestamp) {
          data['processedAt'] =
              (data['processedAt'] as Timestamp).toDate().toUtc().toIso8601String();
        }
        return GroupRequestModel.fromJson(data);
      }).toList();
    });
  }

  @override
  Stream<List<GroupRequestModel>> getMyGroupRequests(String userId) {
    return _firestore
        .collection(FirebaseCollections.groupRequests)
        .where('requesterId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        if (data['createdAt'] is Timestamp) {
          data['createdAt'] =
              (data['createdAt'] as Timestamp).toDate().toUtc().toIso8601String();
        }
        return GroupRequestModel.fromJson(data);
      }).toList();
    });
  }

  // ==================== GROUP INVITES ====================

  @override
  Future<void> inviteUserToGroup({
    required String groupId,
    required String groupName,
    String? groupImageUrl,
    required String inviterId,
    required String inviterName,
    required String inviteeId,
    required String inviteeName,
    String? inviteePhotoUrl,
  }) async {
    try {
      // Check if user is already a member
      final groupDoc = await _firestore
          .collection(FirebaseCollections.groups)
          .doc(groupId)
          .get();

      if (groupDoc.exists) {
        final memberIds =
            List<String>.from(groupDoc.data()?['memberIds'] ?? []);
        if (memberIds.contains(inviteeId)) {
          throw ServerException('Cet utilisateur est déjà membre du groupe');
        }
      }

      // Check if invite already exists
      final existingInvite = await _firestore
          .collection(FirebaseCollections.groupInvites)
          .where('groupId', isEqualTo: groupId)
          .where('inviteeId', isEqualTo: inviteeId)
          .where('status', isEqualTo: 'pending')
          .get();

      if (existingInvite.docs.isNotEmpty) {
        throw ServerException('Une invitation est déjà en attente');
      }

      // Create the invite
      await _firestore.collection(FirebaseCollections.groupInvites).add({
        'groupId': groupId,
        'groupName': groupName,
        'groupImageUrl': groupImageUrl,
        'inviterId': inviterId,
        'inviterName': inviterName,
        'inviteeId': inviteeId,
        'inviteeName': inviteeName,
        'inviteePhotoUrl': inviteePhotoUrl,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors de l\'invitation');
    }
  }

  @override
  Future<void> acceptGroupInvite(String inviteId) async {
    try {
      final inviteDoc = await _firestore
          .collection(FirebaseCollections.groupInvites)
          .doc(inviteId)
          .get();

      if (!inviteDoc.exists) {
        throw ServerException('Invitation non trouvée');
      }

      final data = inviteDoc.data()!;
      final groupId = data['groupId'] as String;
      final inviteeId = data['inviteeId'] as String;

      final batch = _firestore.batch();

      // Update invite status
      batch.update(inviteDoc.reference, {
        'status': 'accepted',
        'respondedAt': FieldValue.serverTimestamp(),
      });

      // Add user to group members
      final groupRef =
          _firestore.collection(FirebaseCollections.groups).doc(groupId);
      batch.update(groupRef, {
        'memberIds': FieldValue.arrayUnion([inviteeId]),
      });

      await batch.commit();
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors de l\'acceptation');
    }
  }

  @override
  Future<void> declineGroupInvite(String inviteId) async {
    try {
      await _firestore
          .collection(FirebaseCollections.groupInvites)
          .doc(inviteId)
          .update({
        'status': 'declined',
        'respondedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors du refus');
    }
  }

  @override
  Future<void> cancelGroupInvite(String inviteId) async {
    try {
      await _firestore
          .collection(FirebaseCollections.groupInvites)
          .doc(inviteId)
          .delete();
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors de l\'annulation');
    }
  }

  @override
  Stream<List<GroupInviteModel>> getReceivedInvites(String userId) {
    return _firestore
        .collection(FirebaseCollections.groupInvites)
        .where('inviteeId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        if (data['createdAt'] is Timestamp) {
          data['createdAt'] =
              (data['createdAt'] as Timestamp).toDate().toUtc().toIso8601String();
        }
        if (data['respondedAt'] is Timestamp) {
          data['respondedAt'] =
              (data['respondedAt'] as Timestamp).toDate().toUtc().toIso8601String();
        }
        return GroupInviteModel.fromJson(data);
      }).toList();
    });
  }

  @override
  Stream<List<GroupInviteModel>> getSentInvites(String groupId) {
    return _firestore
        .collection(FirebaseCollections.groupInvites)
        .where('groupId', isEqualTo: groupId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        if (data['createdAt'] is Timestamp) {
          data['createdAt'] =
              (data['createdAt'] as Timestamp).toDate().toUtc().toIso8601String();
        }
        return GroupInviteModel.fromJson(data);
      }).toList();
    });
  }
}
