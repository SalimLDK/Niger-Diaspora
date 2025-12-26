import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
// import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

// No need for 'Query' import conflict if we use prefixes or explicit types
// But MessageRemoteDataSource interface used DocumentSnapshot, we changed it to dynamic lastMessageKey
// Let's check imports.

import '../../../../core/constants/firebase_collections.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/encryption_service.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';

abstract class MessageRemoteDataSource {
  /// Stream des conversations de l'utilisateur
  Stream<List<ConversationModel>> getConversations(String userId);

  /// Stream des messages d'une conversation (RTDB)
  Stream<List<MessageModel>> getMessages(String conversationId);

  /// Stream d'une conversation spécifique (pour détecter suppression/changements)
  Stream<ConversationModel?> getConversationStream(String conversationId);

  /// Récupérer les messages avec pagination (RTDB)
  Future<(List<MessageModel>, dynamic)> getMessagesPaginated({
    required String conversationId,
    required int limit,
    dynamic lastMessageKey,
  });

  /// Stream des nouveaux messages après un timestamp donné
  Stream<List<MessageModel>> getNewMessagesStream({
    required String conversationId,
    required DateTime afterTimestamp,
  });

  /// Envoyer un message texte
  Future<MessageModel> sendTextMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    String? senderPhotoUrl,
    required String content,
  });

  /// Envoyer un message avec fichier
  Future<MessageModel> sendFileMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    String? senderPhotoUrl,
    required File file,
    required String type,
    String? caption,
  });

  /// Créer une conversation individuelle
  Future<ConversationModel> createIndividualConversation({
    required String currentUserId,
    required String otherUserId,
  });

  /// Créer une conversation de groupe
  Future<ConversationModel> createGroupConversation({
    required String creatorId,
    required List<String> participantIds,
    required String groupName,
    String? groupImageUrl,
    String? groupId, // Add groupId parameter
  });

  /// Marquer comme lu
  Future<void> markAsRead({
    required String conversationId,
    required String userId,
  });

  /// Supprimer une conversation
  Future<void> deleteConversation(String conversationId);

  /// Trouver une conversation individuelle existante
  Future<ConversationModel?> findIndividualConversation({
    required String userId1,
    required String userId2,
  });

  /// Envoyer un message audio
  Future<MessageModel> sendAudioMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    String? senderPhotoUrl,
    required File audioFile,
    required int duration,
    required List<double> waveform,
  });

  /// Récupérer les médias d'une conversation (images et fichiers, pas audio)
  Future<List<MessageModel>> getMediaMessages({
    required String conversationId,
    int limit = 50,
    String? beforeMessageId,
  });

  /// Trouver une conversation de groupe par nom
  Future<ConversationModel?> findGroupConversationByName({
    required String groupName,
    required String userId,
  });

  /// Supprimer un message pour moi (ajoute l'ID utilisateur à deletedFor)
  Future<void> deleteMessageForMe({
    required String conversationId,
    required String messageId,
    required String userId,
  });

  /// Supprimer un message pour tous (met deletedForEveryone à true)
  Future<void> deleteMessageForEveryone({
    required String conversationId,
    required String messageId,
  });

  /// Archiver une conversation
  Future<void> archiveConversation({
    required String conversationId,
    required String userId,
  });

  /// Désarchiver une conversation
  Future<void> unarchiveConversation({
    required String conversationId,
    required String userId,
  });

  /// Mettre en sourdine une conversation
  Future<void> muteConversation({
    required String conversationId,
    required String userId,
  });

  /// Réactiver les notifications pour une conversation
  Future<void> unmuteConversation({
    required String conversationId,
    required String userId,
  });

  /// Promouvoir un utilisateur comme admin du groupe
  Future<void> promoteToAdmin({
    required String conversationId,
    required String userId,
  });

  /// Retirer les droits d'admin du groupe
  Future<void> demoteFromAdmin({
    required String conversationId,
    required String userId,
  });

  /// Retirer un utilisateur du groupe
  Future<void> removeUserFromGroup({
    required String conversationId,
    required String userId,
  });

  /// Signaler un message
  Future<void> reportMessage({
    required String conversationId,
    required String messageId,
    required String userId,
    required String reason,
  });

  /// Signaler un groupe
  Future<void> reportGroup({
    required String conversationId,
    required String userId,
    required String reason,
  });
}

class MessageRemoteDataSourceImpl implements MessageRemoteDataSource {
  final firestore.FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FirebaseDatabase _database;
  final EncryptionService _encryptionService; // New dependency

  MessageRemoteDataSourceImpl({
    firestore.FirebaseFirestore? firestoreInstance,
    FirebaseStorage? storage,
    FirebaseDatabase? database,
    EncryptionService? encryptionService,
  }) : _firestore = firestoreInstance ?? firestore.FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance,
       _database = database ?? FirebaseDatabase.instance,
       _encryptionService =
           encryptionService ?? EncryptionService(); // Default or injected

  firestore.CollectionReference get _conversationsCollection =>
      _firestore.collection(FirebaseCollections.conversations);

  DatabaseReference _messagesRef(String conversationId) =>
      _database.ref().child('messages').child(conversationId);

  ConversationModel _fromFirestoreEncrypted(firestore.DocumentSnapshot doc) {
    final model = ConversationModel.fromFirestore(doc);
    if (model.lastMessage != null && model.lastMessage!.isNotEmpty) {
      return model.copyWith(
        lastMessage: _encryptionService.decryptText(model.lastMessage!),
      );
    }
    return model;
  }

  @override
  Stream<List<ConversationModel>> getConversations(String userId) {
    return _conversationsCollection
        .where('participantIds', arrayContains: userId)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return _fromFirestoreEncrypted(doc);
          }).toList();
        });
  }

  @override
  Stream<ConversationModel?> getConversationStream(String conversationId) {
    return _conversationsCollection.doc(conversationId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return _fromFirestoreEncrypted(doc);
    });
  }

  @override
  Stream<List<MessageModel>> getMessages(String conversationId) {
    return _messagesRef(
      conversationId,
    ).orderByChild('createdAt').limitToLast(100).onValue.map((event) {
      if (event.snapshot.value == null) return [];

      final messages = <MessageModel>[];
      final map = event.snapshot.value as Map<dynamic, dynamic>;

      map.forEach((key, value) {
        if (value is Map) {
          final data = _safeMap(value);
          data['id'] = key;
          if (data['content'] is String) {
            data['content'] = _encryptionService.decryptText(data['content']);
          }
          messages.add(MessageModel.fromJson(data));
        }
      });

      // Sort by creation time
      messages.sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aTime.compareTo(bTime);
      });

      return messages;
    });
  }

  @override
  Future<(List<MessageModel>, dynamic)> getMessagesPaginated({
    required String conversationId,
    required int limit,
    dynamic lastMessageKey,
  }) async {
    try {
      // RTDB endAt is inclusive, so we ask for limit + 1 to handle the cursor
      final effectiveLimit = lastMessageKey != null ? limit + 1 : limit;

      Query query = _messagesRef(
        conversationId,
      ).orderByChild('createdAt').limitToLast(effectiveLimit);

      if (lastMessageKey != null) {
        query = query.endAt(null, key: lastMessageKey);
      }

      final snapshot = await query.get();

      if (snapshot.value == null) {
        return (<MessageModel>[], null);
      }

      final messages = <MessageModel>[];
      final map = snapshot.value as Map<dynamic, dynamic>;

      map.forEach((key, value) {
        if (value is Map) {
          final data = _safeMap(value);
          data['id'] = key;
          if (data['content'] is String) {
            data['content'] = _encryptionService.decryptText(data['content']);
          }
          messages.add(MessageModel.fromJson(data));
        }
      });

      // RTDB returns order by key/child if we iterate correctly, but raw Map is unordered.
      messages.sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aTime.compareTo(bTime);
      });

      // If we used a cursor, the last item (newest in this batch) is the cursor itself.
      // We should remove it to avoid duplication.
      if (lastMessageKey != null && messages.isNotEmpty) {
        messages.removeWhere((m) => m.id == lastMessageKey);
      }

      final newLastKey = messages.isNotEmpty ? messages.first.id : null;

      return (messages, newLastKey);
    } catch (e) {
      throw ServerException(
        'Erreur lors de la récupération des messages: ${e.toString()}',
      );
    }
  }

  @override
  Stream<List<MessageModel>> getNewMessagesStream({
    required String conversationId,
    required DateTime afterTimestamp,
  }) {
    return _messagesRef(conversationId)
        .orderByChild('createdAt')
        .startAt(afterTimestamp.toIso8601String())
        .onValue
        .map((event) {
          if (event.snapshot.value == null) return [];
          final messages = <MessageModel>[];
          final map = event.snapshot.value as Map<dynamic, dynamic>;
          map.forEach((key, value) {
            if (value is Map) {
              final data = _safeMap(value);
              data['id'] = key;
              if (data['content'] is String) {
                data['content'] = _encryptionService.decryptText(
                  data['content'],
                );
              }
              messages.add(MessageModel.fromJson(data));
            }
          });

          // Sort by creation time (Oldest to Newest)
          messages.sort((a, b) {
            final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return aTime.compareTo(bTime);
          });

          return messages;
        });
  }

  /// Helper to safe convert `Map<Object?, Object?>` to `Map<String, dynamic>` recursively
  Map<String, dynamic> _safeMap(Object? data) {
    if (data is Map) {
      final Map<String, dynamic> result = {};
      data.forEach((key, value) {
        result[key.toString()] = _safeValue(value);
      });
      return result;
    }
    return {};
  }

  dynamic _safeValue(Object? value) {
    if (value is Map) {
      return _safeMap(value);
    } else if (value is List) {
      return value.map((e) => _safeValue(e)).toList();
    }
    return value;
  }

  @override
  Future<MessageModel> sendTextMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    String? senderPhotoUrl,
    required String content,
  }) async {
    final now = DateTime.now().toIso8601String();
    final encryptedContent = _encryptionService.encryptText(content);
    final messageData = {
      'senderId': senderId,
      'senderName': senderName,
      'senderPhotoUrl': senderPhotoUrl,
      'content': encryptedContent,
      'type': 'text',
      'readBy': [senderId],
      'readAt': {senderId: now},
      'createdAt': now,
    };

    // Create message in RTDB - this is the critical operation
    final newMessageRef = _messagesRef(conversationId).push();
    await newMessageRef.set(messageData);

    // Try to update conversation metadata (non-critical)
    await _updateConversationLastMessage(
      conversationId: conversationId,
      lastMessage: content,
      senderId: senderId,
    );

    // Try to get the created message, but don't fail if it doesn't work
    try {
      final snapshot = await newMessageRef.get();
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      data['id'] = snapshot.key;
      return MessageModel.fromJson(data);
    } catch (e) {
      // If we can't retrieve it, create a minimal model
      debugPrint('⚠️ Could not retrieve created message, using minimal model');
      return MessageModel(
        id: newMessageRef.key!,
        senderId: senderId,
        senderName: senderName,
        senderPhotoUrl: senderPhotoUrl,
        content: content,
        type: 'text',
        createdAt: DateTime.parse(now),
        readBy: [senderId],
        readAt: {senderId: DateTime.parse(now)},
      );
    }
  }

  @override
  Future<void> archiveConversation({
    required String conversationId,
    required String userId,
  }) async {
    try {
      await _conversationsCollection.doc(conversationId).update({
        'archivedBy': firestore.FieldValue.arrayUnion([userId]),
      });
    } on firestore.FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors de l\'archivage');
    }
  }

  @override
  Future<void> unarchiveConversation({
    required String conversationId,
    required String userId,
  }) async {
    try {
      await _conversationsCollection.doc(conversationId).update({
        'archivedBy': firestore.FieldValue.arrayRemove([userId]),
      });
    } on firestore.FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors du désarchivage');
    }
  }

  @override
  Future<void> muteConversation({
    required String conversationId,
    required String userId,
  }) async {
    try {
      await _conversationsCollection.doc(conversationId).update({
        'mutedBy': firestore.FieldValue.arrayUnion([userId]),
      });
    } on firestore.FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors de la mise en sourdine');
    }
  }

  @override
  Future<void> unmuteConversation({
    required String conversationId,
    required String userId,
  }) async {
    try {
      await _conversationsCollection.doc(conversationId).update({
        'mutedBy': firestore.FieldValue.arrayRemove([userId]),
      });
    } on firestore.FirebaseException catch (e) {
      throw ServerException(
        e.message ?? 'Erreur lors de la réactivation des notifications',
      );
    }
  }

  @override
  Future<MessageModel> sendFileMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    String? senderPhotoUrl,
    required File file,
    required String type,
    String? caption,
  }) async {
    try {
      // Upload du fichier
      final fileName = path.basename(file.path);
      final fileExtension = path.extension(file.path);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storagePath = 'messages/$conversationId/${timestamp}_$fileName';

      final ref = _storage.ref().child(storagePath);
      final uploadTask = await ref.putFile(file);
      final fileUrl = await uploadTask.ref.getDownloadURL();

      // Déterminer le type MIME
      final mimeType = _getMimeType(fileExtension);
      final fileSize = await file.length();
      final now = DateTime.now().toIso8601String();

      final encryptedContent = _encryptionService.encryptText(
        caption ?? fileName,
      );

      final messageData = {
        'senderId': senderId,
        'senderName': senderName,
        'senderPhotoUrl': senderPhotoUrl,
        'content': encryptedContent,
        'type': type,
        'fileUrl': fileUrl,
        'fileName': fileName,
        'fileSize': fileSize,
        'mimeType': mimeType,
        'readBy': [senderId],
        'readAt': {senderId: now},
        'createdAt': now,
      };

      final newMessageRef = _messagesRef(conversationId).push();
      await newMessageRef.set(messageData);

      // Mettre à jour la conversation (FIRESTORE)
      final lastMessageText = type == 'image' ? '📷 Photo' : '📎 $fileName';
      await _updateConversationLastMessage(
        conversationId: conversationId,
        lastMessage: lastMessageText,
        senderId: senderId,
      );

      final snapshot = await newMessageRef.get();
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      data['id'] = snapshot.key;

      return MessageModel.fromJson(data);
    } catch (e) {
      throw ServerException(
        'Erreur lors de l\'envoi du fichier: ${e.toString()}',
      );
    }
  }

  @override
  Future<ConversationModel> createIndividualConversation({
    required String currentUserId,
    required String otherUserId,
  }) async {
    try {
      // Vérifier si une conversation existe déjà
      final existing = await findIndividualConversation(
        userId1: currentUserId,
        userId2: otherUserId,
      );

      if (existing != null) {
        return existing;
      }

      final conversationData = {
        'type': 'individual',
        'participantIds': [currentUserId, otherUserId],
        'createdBy': currentUserId,
        'createdAt': firestore.FieldValue.serverTimestamp(),
        'lastMessageAt': firestore.FieldValue.serverTimestamp(),
        'unreadCount': {currentUserId: 0, otherUserId: 0},
      };

      final docRef = await _conversationsCollection.add(conversationData);
      final doc = await docRef.get();
      return ConversationModel.fromFirestore(doc);
    } on firestore.FirebaseException catch (e) {
      throw ServerException(
        e.message ?? 'Erreur lors de la création de la conversation',
      );
    }
  }

  @override
  Future<ConversationModel> createGroupConversation({
    required String creatorId,
    required List<String> participantIds,
    required String groupName,
    String? groupImageUrl,
    String? groupId, // Add groupId parameter
  }) async {
    try {
      // S'assurer que le créateur est dans la liste des participants
      final allParticipants = {...participantIds, creatorId}.toList();
      allParticipants.sort(); // Trier pour comparaison consistante

      // Vérifier si un groupe avec le même nom et les mêmes participants existe déjà
      final existingSnapshot =
          await _conversationsCollection
              .where('type', isEqualTo: 'group')
              .where('name', isEqualTo: groupName)
              .get();

      // Vérifier si les participants correspondent exactement
      for (final doc in existingSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final existingParticipants = List<String>.from(
          data['participantIds'] ?? [],
        );
        existingParticipants.sort();

        // Si même nom ET mêmes participants, retourner la conversation existante
        if (_listsEqual(allParticipants, existingParticipants)) {
          return ConversationModel.fromFirestore(doc);
        }
      }

      // Si aucune conversation existante trouvée, en créer une nouvelle
      final unreadCount = <String, int>{};
      for (final id in allParticipants) {
        unreadCount[id] = 0;
      }

      final conversationData = {
        'type': 'group',
        'name': groupName,
        'imageUrl': groupImageUrl,
        'groupId': groupId, // Store groupId
        'participantIds': allParticipants,
        'adminIds': [creatorId], // Set creator as admin
        'createdBy': creatorId,
        'createdAt': firestore.FieldValue.serverTimestamp(),
        'lastMessageAt': firestore.FieldValue.serverTimestamp(),
        'unreadCount': unreadCount,
      };

      final docRef = await _conversationsCollection.add(conversationData);
      final doc = await docRef.get();
      return ConversationModel.fromFirestore(doc);
    } on firestore.FirebaseException catch (e) {
      throw ServerException(
        e.message ?? 'Erreur lors de la création du groupe',
      );
    }
  }

  // Helper pour comparer deux listes
  bool _listsEqual(List<String> list1, List<String> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (list1[i] != list2[i]) return false;
    }
    return true;
  }

  @override
  Future<void> markAsRead({
    required String conversationId,
    required String userId,
  }) async {
    try {
      // Note: Updating RTDB message read status one by one or in batch.
      // RTDB batch update is just update() with map.
      // Fetch unread from RTDB is hard without index 'readBy'.
      // For now, let's just reset Firestore unreadCount.
      // Real "read" status on individual messages in RTDB might be expensive to query/update without proper indexing.
      // We'll skip updating each message's 'readBy' for now to keep it simple, or iterate if needed.
      // To strictly follow clean architecture, we should update unreadCount in Firestore.

      await _conversationsCollection.doc(conversationId).update({
        'unreadCount.$userId': 0,
      });
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors du marquage comme lu');
    }
  }

  @override
  Future<void> deleteConversation(String conversationId) async {
    try {
      // Supprimer tous les messages (RTDB)
      await _messagesRef(conversationId).remove();

      // Supprimer la conversation (FIRESTORE)
      await _conversationsCollection.doc(conversationId).delete();
    } on FirebaseException catch (e) {
      throw ServerException(
        e.message ?? 'Erreur lors de la suppression de la conversation',
      );
    }
  }

  @override
  Future<ConversationModel?> findIndividualConversation({
    required String userId1,
    required String userId2,
  }) async {
    try {
      // Search for conversations where both users are participants
      // We need to check both userId1 and userId2 are in participantIds
      final snapshot =
          await _conversationsCollection
              .where('type', isEqualTo: 'individual')
              .where('participantIds', arrayContains: userId1)
              .get();

      // Filter to find the conversation with both users
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final participants = List<String>.from(data['participantIds'] ?? []);

        // Check if it's a 1-on-1 conversation with exactly these 2 users
        if (participants.length == 2 &&
            participants.contains(userId1) &&
            participants.contains(userId2)) {
          return ConversationModel.fromFirestore(doc);
        }
      }

      return null;
    } on FirebaseException catch (e) {
      throw ServerException(
        e.message ?? 'Erreur lors de la recherche de conversation',
      );
    }
  }

  Future<void> _updateConversationLastMessage({
    required String conversationId,
    required String lastMessage,
    required String senderId,
  }) async {
    try {
      // Récupérer les participants pour incrémenter leurs compteurs
      final conversationDoc =
          await _conversationsCollection.doc(conversationId).get();
      final data = conversationDoc.data() as Map<String, dynamic>;
      final participants = List<String>.from(data['participantIds'] ?? []);

      final unreadUpdates = <String, dynamic>{};
      for (final participantId in participants) {
        if (participantId != senderId) {
          unreadUpdates['unreadCount.$participantId'] = firestore
              .FieldValue.increment(1);
        }
      }

      final encryptedLastMessage = _encryptionService.encryptText(lastMessage);

      await _conversationsCollection.doc(conversationId).update({
        'lastMessage': encryptedLastMessage,
        'lastMessageSenderId': senderId,
        'lastMessageStatus': 'sent', // Always sent initially
        'lastMessageAt': firestore.FieldValue.serverTimestamp(),
        ...unreadUpdates,
      });
    } catch (e) {
      // Don't throw - message is already created in RTDB
      // Just log the error to avoid retry creating duplicate messages
      debugPrint('⚠️ Failed to update conversation metadata: $e');
    }
  }

  String _getMimeType(String extension) {
    switch (extension.toLowerCase()) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.pdf':
        return 'application/pdf';
      case '.doc':
        return 'application/msword';
      case '.docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case '.xls':
        return 'application/vnd.ms-excel';
      case '.xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case '.m4a':
        return 'audio/mp4';
      case '.aac':
        return 'audio/aac';
      case '.mp3':
        return 'audio/mpeg';
      case '.wav':
        return 'audio/wav';
      case '.ogg':
        return 'audio/ogg';
      default:
        return 'application/octet-stream';
    }
  }

  firestore.CollectionReference get _reportsCollection =>
      _firestore.collection('reports');

  @override
  Future<void> promoteToAdmin({
    required String conversationId,
    required String userId,
  }) async {
    try {
      await _conversationsCollection.doc(conversationId).update({
        'adminIds': firestore.FieldValue.arrayUnion([userId]),
      });
    } on firestore.FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors de la promotion admin');
    }
  }

  @override
  Future<void> demoteFromAdmin({
    required String conversationId,
    required String userId,
  }) async {
    try {
      await _conversationsCollection.doc(conversationId).update({
        'adminIds': firestore.FieldValue.arrayRemove([userId]),
      });
    } on firestore.FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors de la destitution admin');
    }
  }

  @override
  Future<void> removeUserFromGroup({
    required String conversationId,
    required String userId,
  }) async {
    try {
      await _conversationsCollection.doc(conversationId).update({
        'participantIds': firestore.FieldValue.arrayRemove([userId]),
        'adminIds': firestore.FieldValue.arrayRemove([userId]),
        // Also remove from unreadCount map if possible, but Firestore map update delete is tricky
        // 'unreadCount.$userId': firestore.FieldValue.delete(), // Requires FieldValue.delete()
      });
      // Try to remove unread count field
      await _conversationsCollection.doc(conversationId).update({
        'unreadCount.$userId': firestore.FieldValue.delete(),
      });
    } on firestore.FirebaseException catch (e) {
      throw ServerException(
        e.message ?? 'Erreur lors de la suppression du membre',
      );
    }
  }

  @override
  Future<void> reportMessage({
    required String conversationId,
    required String messageId,
    required String userId,
    required String reason,
  }) async {
    try {
      // 1. Add to reports collection for Global Admin
      await _reportsCollection.add({
        'type': 'message',
        'targetId': messageId,
        'conversationId': conversationId,
        'reportedBy': userId,
        'reason': reason,
        'createdAt': firestore.FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      // 2. Mark message as reported (Optional, if we want to show it in UI)
      // RTDB update
      // We can't easily do arrayUnion in RTDB without reading first or using a transactional update or child list.
      // For simplicity, let's just use the reports collection for now.
      // If we really need to show "Reported by you" on the message, we can check the reports collection or update the message.
      // Given RTDB structure, let's skip modifying the partial message for now to avoid complexity/race conditions
      // unless strictly required. The request "report" implies notifying admin.

      // WAIT, I added reportedBy to MessageModel (RTDB). I should update it.
      // RTDB: messages/$conversationId/$messageId/reportedBy
      // It's a list.
      final messageRef = _messagesRef(conversationId).child(messageId);
      final snapshot = await messageRef.child('reportedBy').get();
      List<String> currentReports = [];
      if (snapshot.value != null) {
        currentReports = List<String>.from(snapshot.value as List);
      }
      if (!currentReports.contains(userId)) {
        currentReports.add(userId);
        await messageRef.update({'reportedBy': currentReports});
      }
    } on Exception catch (e) {
      throw ServerException('Erreur lors du signalement du message: $e');
    }
  }

  @override
  Future<void> reportGroup({
    required String conversationId,
    required String userId,
    required String reason,
  }) async {
    try {
      // 1. Add to reports collection
      await _reportsCollection.add({
        'type': 'group',
        'targetId': conversationId,
        'conversationId': conversationId,
        'reportedBy': userId,
        'reason': reason,
        'createdAt': firestore.FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      // 2. Update conversation doc
      await _conversationsCollection.doc(conversationId).update({
        'reportedBy': firestore.FieldValue.arrayUnion([userId]),
      });
    } on firestore.FirebaseException catch (e) {
      throw ServerException(
        e.message ?? 'Erreur lors du signalement du groupe',
      );
    }
  }

  @override
  Future<MessageModel> sendAudioMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    String? senderPhotoUrl,
    required File audioFile,
    required int duration,
    required List<double> waveform,
  }) async {
    try {
      // Upload audio file
      final fileName = path.basename(audioFile.path);
      final fileExtension = path.extension(audioFile.path);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storagePath =
          'messages/$conversationId/audio_$timestamp$fileExtension';

      final ref = _storage.ref().child(storagePath);
      final uploadTask = await ref.putFile(audioFile);
      final fileUrl = await uploadTask.ref.getDownloadURL();

      final mimeType = _getMimeType(fileExtension);
      final fileSize = await audioFile.length();
      final now = DateTime.now().toIso8601String();

      final messageData = {
        'senderId': senderId,
        'senderName': senderName,
        'senderPhotoUrl': senderPhotoUrl,
        'content': '',
        'type': 'audio',
        'fileUrl': fileUrl,
        'fileName': fileName,
        'fileSize': fileSize,
        'mimeType': mimeType,
        'audioDuration': duration,
        'audioWaveform': waveform,
        'readBy': [senderId],
        'readAt': {senderId: now},
        'createdAt': now,
      };

      final newMessageRef = _messagesRef(conversationId).push();
      await newMessageRef.set(messageData);

      // Update conversation last message
      await _updateConversationLastMessage(
        conversationId: conversationId,
        lastMessage: '🎤 Message vocal',
        senderId: senderId,
      );

      final snapshot = await newMessageRef.get();
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      data['id'] = snapshot.key;

      return MessageModel.fromJson(data);
    } catch (e) {
      throw ServerException(
        'Erreur lors de l\'envoi du message vocal: ${e.toString()}',
      );
    }
  }

  @override
  Future<List<MessageModel>> getMediaMessages({
    required String conversationId,
    int limit = 50,
    String? beforeMessageId,
  }) async {
    try {
      Query query = _messagesRef(conversationId)
          .orderByChild('createdAt')
          .limitToLast(limit * 3); // Fetch more to filter

      if (beforeMessageId != null) {
        query = query.endAt(null, key: beforeMessageId);
      }

      final snapshot = await query.get();

      if (snapshot.value == null) {
        return [];
      }

      final messages = <MessageModel>[];
      final map = snapshot.value as Map<dynamic, dynamic>;

      map.forEach((key, value) {
        final data = Map<String, dynamic>.from(value as Map);
        data['id'] = key;
        final message = MessageModel.fromJson(data);

        // Filter: only images and files (not text, not audio)
        if (message.type == 'image' || message.type == 'file') {
          messages.add(message);
        }
      });

      // Sort by creation time descending (newest first)
      messages.sort((a, b) {
        final aTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aTime.compareTo(bTime);
      });

      // Limit the results
      if (messages.length > limit) {
        return messages.sublist(0, limit);
      }

      return messages;
    } catch (e) {
      throw ServerException(
        'Erreur lors de la récupération des médias: ${e.toString()}',
      );
    }
  }

  @override
  Future<ConversationModel?> findGroupConversationByName({
    required String groupName,
    required String userId,
  }) async {
    try {
      final snapshot =
          await _conversationsCollection
              .where('type', isEqualTo: 'group')
              .where('name', isEqualTo: groupName)
              .where('participantIds', arrayContains: userId)
              .limit(1)
              .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      return ConversationModel.fromFirestore(snapshot.docs.first);
    } on firestore.FirebaseException catch (e) {
      throw ServerException(
        e.message ?? 'Erreur lors de la recherche du groupe',
      );
    }
  }

  @override
  Future<void> deleteMessageForMe({
    required String conversationId,
    required String messageId,
    required String userId,
  }) async {
    try {
      final messageRef = _messagesRef(conversationId).child(messageId);
      final snapshot = await messageRef.get();

      if (!snapshot.exists) {
        throw ServerException('Message non trouvé');
      }

      // Get current deletedFor list and add the user
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final deletedFor = List<String>.from(data['deletedFor'] ?? []);

      if (!deletedFor.contains(userId)) {
        deletedFor.add(userId);
        await messageRef.update({'deletedFor': deletedFor});
      }
    } on FirebaseException catch (e) {
      throw ServerException(
        e.message ?? 'Erreur lors de la suppression du message',
      );
    }
  }

  @override
  Future<void> deleteMessageForEveryone({
    required String conversationId,
    required String messageId,
  }) async {
    try {
      final messageRef = _messagesRef(conversationId).child(messageId);
      final snapshot = await messageRef.get();

      if (!snapshot.exists) {
        throw ServerException('Message non trouvé');
      }

      // Update message to mark as deleted for everyone
      await messageRef.update({
        'deletedForEveryone': true,
        'deletedAt': DateTime.now().toIso8601String(),
        'content': '', // Clear content
        'fileUrl': null, // Clear file URL if any
      });
    } on FirebaseException catch (e) {
      throw ServerException(
        e.message ?? 'Erreur lors de la suppression du message pour tous',
      );
    }
  }
}
