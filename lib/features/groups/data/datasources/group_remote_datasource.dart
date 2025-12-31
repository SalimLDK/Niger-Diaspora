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

  /// System message methods for group events
  Future<void> sendPromotedSystemMessage(String groupId, String userId);
  Future<void> sendDemotedSystemMessage(String groupId, String userId);
  Future<void> sendGroupRenamedSystemMessage(String groupId, String newName);
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

  /// Sends a system message to a group conversation.
  /// This is a non-critical operation that shouldn't block the main action.
  Future<void> _sendGroupSystemMessage({
    required String groupId,
    required String content,
    String? userId,
    bool addUserToParticipants = false,
  }) async {
    try {
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

      // Handle adding user to participants if needed
      if (userId != null && addUserToParticipants) {
        final conversationData = conversationDoc.data();
        final participants = List<String>.from(
          conversationData['participantIds'] ?? [],
        );

        if (!participants.contains(userId)) {
          await _firestore.collection('conversations').doc(conversationId).update({
            'participantIds': FieldValue.arrayUnion([userId]),
          });
          // Sync to RTDB for security rules
          await _syncParticipantsToRTDB(conversationId, [...participants, userId]);
        }
      }

      // Send system message to Firebase RTDB
      final messageData = {
        'senderId': 'system',
        'senderName': 'Système',
        'content': content,
        'type': 'system',
        'readBy': <String>[],
        'readAt': <String, dynamic>{},
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
        'lastMessage': content,
        'lastMessageSenderId': 'system',
        'lastMessageAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Log but don't fail - this is a non-critical operation
      // debugPrint('⚠️ Failed to send system message: $e');
    }
  }

  /// Helper to sync participants to RTDB for security rules
  Future<void> _syncParticipantsToRTDB(String conversationId, List<String> participantIds) async {
    try {
      final participantsMap = <String, bool>{};
      for (final id in participantIds) {
        participantsMap[id] = true;
      }
      await FirebaseDatabase.instance
          .ref()
          .child('conversations')
          .child(conversationId)
          .child('participants')
          .set(participantsMap);
    } catch (e) {
      // Non-critical
    }
  }

  /// Gets user display name from Firestore
  Future<String> _getUserDisplayName(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return 'Un utilisateur';
      return userDoc.data()?['displayName'] as String? ?? 'Un utilisateur';
    } catch (e) {
      return 'Un utilisateur';
    }
  }

  /// Sends a system message when a user joins a group.
  Future<void> _sendJoinSystemMessage(String groupId, String userId) async {
    final userName = await _getUserDisplayName(userId);
    await _sendGroupSystemMessage(
      groupId: groupId,
      content: '$userName a rejoint le groupe',
      userId: userId,
      addUserToParticipants: true,
    );
  }

  /// Sends a system message when a user leaves a group.
  Future<void> _sendLeaveSystemMessage(String groupId, String userId) async {
    final userName = await _getUserDisplayName(userId);
    await _sendGroupSystemMessage(
      groupId: groupId,
      content: '$userName a quitté le groupe',
    );
  }

  /// Sends a system message when a user is removed from a group.
  Future<void> _sendRemovedSystemMessage(String groupId, String userId) async {
    final userName = await _getUserDisplayName(userId);
    await _sendGroupSystemMessage(
      groupId: groupId,
      content: '$userName a été retiré du groupe',
    );
  }

  /// Sends a system message when a user is promoted to admin.
  /// Public method to be called from message provider.
  @override
  Future<void> sendPromotedSystemMessage(String groupId, String userId) async {
    final userName = await _getUserDisplayName(userId);
    await _sendGroupSystemMessage(
      groupId: groupId,
      content: '$userName est maintenant administrateur',
    );
  }

  /// Sends a system message when a user is demoted from admin.
  /// Public method to be called from message provider.
  @override
  Future<void> sendDemotedSystemMessage(String groupId, String userId) async {
    final userName = await _getUserDisplayName(userId);
    await _sendGroupSystemMessage(
      groupId: groupId,
      content: '$userName n\'est plus administrateur',
    );
  }

  /// Sends a system message when group name is changed.
  /// Public method to be called from group provider.
  @override
  Future<void> sendGroupRenamedSystemMessage(String groupId, String newName) async {
    await _sendGroupSystemMessage(
      groupId: groupId,
      content: 'Le groupe a été renommé en $newName',
    );
  }

  @override
  Future<void> leaveGroup(String groupId, String userId) async {
    try {
      // Vérifier si l'utilisateur est le créateur
      final groupDoc = await _groupsCollection.doc(groupId).get();
      if (!groupDoc.exists) {
        throw ServerException('Groupe non trouvé');
      }

      final groupData = groupDoc.data() as Map<String, dynamic>;
      final creatorId = groupData['creatorId'] as String?;
      final adminIds = List<String>.from(groupData['adminIds'] ?? []);

      // Vérifier s'il y a d'autres admins
      final otherAdmins = adminIds.where((id) => id != userId).toList();

      // Le créateur peut quitter seulement s'il y a au moins un autre admin
      if (creatorId == userId) {
        if (otherAdmins.isEmpty) {
          throw ServerException(
            'Vous êtes le créateur et le seul administrateur. Nommez un autre administrateur avant de quitter.',
          );
        }
        // Transférer la propriété au premier admin disponible
        final newCreatorId = otherAdmins.first;
        await _groupsCollection.doc(groupId).update({
          'creatorId': newCreatorId,
        });
        // Envoyer un message système pour le transfert
        final newCreatorName = await _getUserDisplayName(newCreatorId);
        await _sendGroupSystemMessage(
          groupId: groupId,
          content: '$newCreatorName est maintenant le propriétaire du groupe',
        );
      } else if (adminIds.contains(userId)) {
        // Si c'est un admin (pas le créateur), vérifier qu'il reste au moins un admin ou le créateur
        final creatorIsAdmin = creatorId != null && adminIds.contains(creatorId);
        if (otherAdmins.isEmpty && !creatorIsAdmin) {
          throw ServerException(
            'Vous êtes le seul administrateur. Nommez un autre administrateur avant de quitter.',
          );
        }
      }

      // Send system message before removing (so user is still in conversation)
      _sendLeaveSystemMessage(groupId, userId);

      // Retirer l'utilisateur du groupe
      await _groupsCollection.doc(groupId).update({
        'memberIds': FieldValue.arrayRemove([userId]),
        'adminIds': FieldValue.arrayRemove([userId]),
        'memberJoinedAt.$userId': FieldValue.delete(),
      });

      // Retirer l'utilisateur de la conversation du groupe
      await _removeUserFromGroupConversation(groupId, userId);
    } on ServerException {
      rethrow;
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors du depart');
    }
  }

  @override
  Future<void> removeMember(String groupId, String userId) async {
    try {
      // Vérifier si l'utilisateur est le créateur
      final groupDoc = await _groupsCollection.doc(groupId).get();
      if (!groupDoc.exists) {
        throw ServerException('Groupe non trouvé');
      }

      final groupData = groupDoc.data() as Map<String, dynamic>;
      final creatorId = groupData['creatorId'] as String?;

      // On ne peut pas retirer le créateur du groupe
      if (creatorId == userId) {
        throw ServerException(
          'Le créateur ne peut pas être retiré du groupe.',
        );
      }

      // Send system message before removing (so user is still in conversation)
      _sendRemovedSystemMessage(groupId, userId);

      // Retirer l'utilisateur du groupe
      await _groupsCollection.doc(groupId).update({
        'memberIds': FieldValue.arrayRemove([userId]),
        'adminIds': FieldValue.arrayRemove([userId]),
        'memberJoinedAt.$userId': FieldValue.delete(),
      });

      // Retirer l'utilisateur de la conversation du groupe
      await _removeUserFromGroupConversation(groupId, userId);
    } on ServerException {
      rethrow;
    } on FirebaseException catch (e) {
      throw ServerException(
        e.message ?? 'Erreur lors de la suppression du membre',
      );
    }
  }

  /// Retire un utilisateur de la conversation associée au groupe
  Future<void> _removeUserFromGroupConversation(
    String groupId,
    String userId,
  ) async {
    try {
      // Trouver la conversation du groupe
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

      // Retirer l'utilisateur des participants
      await _firestore.collection('conversations').doc(conversationId).update({
        'participantIds': FieldValue.arrayRemove([userId]),
        'unreadCount.$userId': FieldValue.delete(),
      });

      // Retirer des participants RTDB (pour les règles de sécurité)
      await FirebaseDatabase.instance
          .ref()
          .child('conversations')
          .child(conversationId)
          .child('participants')
          .child(userId)
          .remove();
    } catch (e) {
      // Non-critique, ne pas bloquer le départ du groupe
      // debugPrint('⚠️ Failed to remove user from group conversation: $e');
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
      final lowerQuery = query.toLowerCase();

      if (isConnected) {
        // Fetch all public groups and filter locally for case-insensitive search
        final snapshot =
            await _groupsCollection
                .where('isPrivate', isEqualTo: false)
                .orderBy('createdAt', descending: true)
                .limit(100)
                .get();

        final allGroups =
            snapshot.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              data['id'] = doc.id;
              return GroupModel.fromJson(_convertTimestamps(data));
            }).toList();

        // Filter locally for case-insensitive matching
        final groups = allGroups
            .where((g) => g.name.toLowerCase().contains(lowerQuery))
            .take(20)
            .toList();

        for (final group in groups) {
          await _cache.cacheGroup(group.id, group.toJson());
        }

        return groups;
      } else {
        // Recherche locale dans le cache
        final cached = _getGroupsFromCache();
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
