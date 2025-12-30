import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
// import 'package:flutter/foundation.dart';
import '../../../../core/constants/firebase_collections.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/cache_service.dart';
import '../../../../core/services/connectivity_service.dart';
import '../models/group_model.dart';

abstract class GroupRemoteDataSource {
  Future<List<GroupModel>> getGroups();
  Future<List<GroupModel>> getGroupsByCategory(String category);
  Future<GroupModel> getGroupById(String groupId);
  Stream<GroupModel?> getGroupStream(String groupId);
  Future<GroupModel> createGroup(GroupModel group);
  Future<GroupModel> updateGroup(GroupModel group);
  Future<void> deleteGroup(String groupId);
  Future<void> joinGroup(String groupId, String userId);
  Future<void> leaveGroup(String groupId, String userId);
  Future<void> removeMember(String groupId, String userId);
  Future<List<GroupModel>> getMyGroups(String userId);
  Future<List<GroupModel>> searchGroups(String query);
}

class GroupRemoteDataSourceImpl implements GroupRemoteDataSource {
  final FirebaseFirestore _firestore;
  final CacheService _cache = CacheService.instance;
  final ConnectivityService _connectivity = ConnectivityService.instance;

  GroupRemoteDataSourceImpl({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _groupsCollection =>
      _firestore.collection(FirebaseCollections.groups);

  @override
  Future<List<GroupModel>> getGroups() async {
    try {
      final isConnected = await _connectivity.isConnected();

      if (isConnected) {
        final snapshot =
            await _groupsCollection
                .where('isPrivate', isEqualTo: false)
                .orderBy('createdAt', descending: true)
                .limit(50)
                .get();

        final groups =
            snapshot.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              data['id'] = doc.id;
              return GroupModel.fromJson(_convertTimestamps(data));
            }).toList();

        // Mettre en cache
        await _cache.cacheGroups(groups.map((g) => g.toJson()).toList());

        return groups;
      } else {
        return _getGroupsFromCache();
      }
    } on FirebaseException catch (e) {
      final cached = _getGroupsFromCache();
      if (cached.isNotEmpty) return cached;
      throw ServerException(e.message ?? 'Erreur lors du chargement');
    }
  }

  List<GroupModel> _getGroupsFromCache() {
    final cachedData = _cache.getAllCachedGroups();
    return cachedData.map((data) => GroupModel.fromJson(data)).toList();
  }

  @override
  Future<List<GroupModel>> getGroupsByCategory(String category) async {
    try {
      final isConnected = await _connectivity.isConnected();

      if (isConnected) {
        final snapshot =
            await _groupsCollection
                .where('category', isEqualTo: category)
                .orderBy('createdAt', descending: true)
                .get();

        final groups =
            snapshot.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              data['id'] = doc.id;
              return GroupModel.fromJson(_convertTimestamps(data));
            }).toList();

        for (final group in groups) {
          await _cache.cacheGroup(group.id, group.toJson());
        }

        return groups;
      } else {
        final cached = _getGroupsFromCache();
        return cached.where((g) => g.category == category).toList();
      }
    } on FirebaseException catch (e) {
      final cached = _getGroupsFromCache();
      final filtered = cached.where((g) => g.category == category).toList();
      if (filtered.isNotEmpty) return filtered;
      throw ServerException(e.message ?? 'Erreur lors du chargement');
    }
  }

  @override
  Future<GroupModel> getGroupById(String groupId) async {
    try {
      final isConnected = await _connectivity.isConnected();

      if (isConnected) {
        final doc = await _groupsCollection.doc(groupId).get();

        if (!doc.exists) {
          throw ServerException('Groupe non trouve');
        }

        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        final group = GroupModel.fromJson(_convertTimestamps(data));

        await _cache.cacheGroup(groupId, group.toJson());

        return group;
      } else {
        final cachedData = _cache.getCachedGroup(groupId);
        if (cachedData != null) {
          return GroupModel.fromJson(cachedData);
        }
        throw ServerException('Groupe non disponible hors ligne');
      }
    } on FirebaseException catch (e) {
      final cachedData = _cache.getCachedGroup(groupId);
      if (cachedData != null) {
        return GroupModel.fromJson(cachedData);
      }
      throw ServerException(e.message ?? 'Erreur lors du chargement');
    }
  }

  @override
  Stream<GroupModel?> getGroupStream(String groupId) {
    return _groupsCollection.doc(groupId).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;

      final data = snapshot.data() as Map<String, dynamic>;
      data['id'] = snapshot.id;
      final group = GroupModel.fromJson(_convertTimestamps(data));

      // Cache in background
      _cache.cacheGroup(groupId, group.toJson());

      return group;
    });
  }

  @override
  Future<GroupModel> createGroup(GroupModel group) async {
    try {
      final data = group.toJson();
      data.remove('id');
      data['createdAt'] = FieldValue.serverTimestamp();
      data['memberIds'] = [group.creatorId];
      data['adminIds'] = [group.creatorId];

      final docRef = await _groupsCollection.add(data);
      return getGroupById(docRef.id);
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors de la creation');
    }
  }

  @override
  Future<GroupModel> updateGroup(GroupModel group) async {
    try {
      final data = group.toJson();
      data.remove('id');
      data['updatedAt'] = FieldValue.serverTimestamp();

      await _groupsCollection.doc(group.id).update(data);
      return getGroupById(group.id);
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors de la mise a jour');
    }
  }

  @override
  Future<void> deleteGroup(String groupId) async {
    try {
      await _groupsCollection.doc(groupId).delete();
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors de la suppression');
    }
  }

  @override
  Future<void> joinGroup(String groupId, String userId) async {
    try {
      // Use a transaction for atomic group update
      await _firestore.runTransaction((transaction) async {
        // Get current group data
        final groupDoc = await transaction.get(_groupsCollection.doc(groupId));

        if (!groupDoc.exists) {
          throw ServerException('Groupe non trouvé');
        }

        final groupData = groupDoc.data() as Map<String, dynamic>;

        // Check if group is private - requires approval
        final isPrivate = groupData['isPrivate'] as bool? ?? false;
        if (isPrivate) {
          throw ServerException(
            'Ce groupe est privé. Vous devez envoyer une demande d\'adhésion.',
          );
        }

        final currentMembers = List<String>.from(groupData['memberIds'] ?? []);

        // Check if user is already a member
        if (currentMembers.contains(userId)) {
          throw ServerException('Vous êtes déjà membre de ce groupe');
        }

        // Update group with new member
        transaction.update(_groupsCollection.doc(groupId), {
          'memberIds': FieldValue.arrayUnion([userId]),
          'memberJoinedAt.$userId': FieldValue.serverTimestamp(),
        });
      });

      // Post-transaction: Send system message (non-critical, can fail)
      _sendJoinSystemMessage(groupId, userId);
    } on ServerException {
      rethrow;
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors de l\'inscription');
    }
  }

  /// Sends a system message when a user joins a group.
  /// This is a non-critical operation that shouldn't block the join.
  Future<void> _sendJoinSystemMessage(String groupId, String userId) async {
    try {
      // Get user's profile to display their name
      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (!userDoc.exists) return;

      final userName =
          userDoc.data()?['displayName'] as String? ?? 'Un utilisateur';

      // Find the group's conversation
      final conversationsQuery =
          await _firestore
              .collection('conversations')
              .where('type', isEqualTo: 'group')
              .where('groupId', isEqualTo: groupId)
              .limit(1)
              .get();

      if (conversationsQuery.docs.isEmpty) return;

      final conversationDoc = conversationsQuery.docs.first;
      final conversationId = conversationDoc.id;

      // Add user to conversation participants if not already
      final conversationData = conversationDoc.data();
      final participants = List<String>.from(
        conversationData['participantIds'] ?? [],
      );

      if (!participants.contains(userId)) {
        await _firestore.collection('conversations').doc(conversationId).update(
          {
            'participantIds': FieldValue.arrayUnion([userId]),
          },
        );
      }

      // Send system message to Firebase RTDB
      final messageData = {
        'senderId': 'system',
        'senderName': 'Système',
        'content': '$userName a rejoint le groupe',
        'type': 'system',
        'readBy': [],
        'readAt': {},
        'createdAt': DateTime.now().toIso8601String(),
      };

      await FirebaseDatabase.instance
          .ref()
          .child('messages')
          .child(conversationId)
          .push()
          .set(messageData);

      // Update conversation last message
      await _firestore.collection('conversations').doc(conversationId).update({
        'lastMessage': '$userName a rejoint le groupe',
        'lastMessageSenderId': 'system',
        'lastMessageAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Log but don't fail - this is a non-critical operation
      // debugPrint('⚠️ Failed to send system message for group join: $e');
    }
  }

  @override
  Future<void> leaveGroup(String groupId, String userId) async {
    try {
      await _groupsCollection.doc(groupId).update({
        'memberIds': FieldValue.arrayRemove([userId]),
      });
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors du depart');
    }
  }

  @override
  Future<void> removeMember(String groupId, String userId) async {
    try {
      await _groupsCollection.doc(groupId).update({
        'memberIds': FieldValue.arrayRemove([userId]),
        'adminIds': FieldValue.arrayRemove([userId]),
      });
    } on FirebaseException catch (e) {
      throw ServerException(
        e.message ?? 'Erreur lors de la suppression du membre',
      );
    }
  }

  @override
  Future<List<GroupModel>> getMyGroups(String userId) async {
    try {
      final isConnected = await _connectivity.isConnected();

      if (isConnected) {
        final snapshot =
            await _groupsCollection
                .where('memberIds', arrayContains: userId)
                .orderBy('createdAt', descending: true)
                .get();

        final groups =
            snapshot.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              data['id'] = doc.id;
              return GroupModel.fromJson(_convertTimestamps(data));
            }).toList();

        for (final group in groups) {
          await _cache.cacheGroup(group.id, group.toJson());
        }

        return groups;
      } else {
        final cached = _getGroupsFromCache();
        return cached.where((g) => g.memberIds.contains(userId)).toList();
      }
    } on FirebaseException catch (e) {
      final cached = _getGroupsFromCache();
      final filtered =
          cached.where((g) => g.memberIds.contains(userId)).toList();
      if (filtered.isNotEmpty) return filtered;
      throw ServerException(e.message ?? 'Erreur lors du chargement');
    }
  }

  @override
  Future<List<GroupModel>> searchGroups(String query) async {
    try {
      final isConnected = await _connectivity.isConnected();

      if (isConnected) {
        final lowerQuery = query.toLowerCase();

        final snapshot =
            await _groupsCollection
                .where('isPrivate', isEqualTo: false)
                .orderBy('name')
                .startAt([lowerQuery])
                .endAt(['$lowerQuery\uf8ff'])
                .limit(20)
                .get();

        final groups =
            snapshot.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              data['id'] = doc.id;
              return GroupModel.fromJson(_convertTimestamps(data));
            }).toList();

        for (final group in groups) {
          await _cache.cacheGroup(group.id, group.toJson());
        }

        return groups;
      } else {
        // Recherche locale dans le cache
        final cached = _getGroupsFromCache();
        final lowerQuery = query.toLowerCase();
        return cached
            .where((g) => g.name.toLowerCase().contains(lowerQuery))
            .take(20)
            .toList();
      }
    } on FirebaseException catch (e) {
      final cached = _getGroupsFromCache();
      final lowerQuery = query.toLowerCase();
      final filtered =
          cached
              .where((g) => g.name.toLowerCase().contains(lowerQuery))
              .take(20)
              .toList();
      if (filtered.isNotEmpty) return filtered;
      throw ServerException(e.message ?? 'Erreur lors de la recherche');
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
}
