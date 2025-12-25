import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;

// No need for 'Query' import conflict if we use prefixes or explicit types
// But MessageRemoteDataSource interface used DocumentSnapshot, we changed it to dynamic lastMessageKey
// Let's check imports.

import '../../../../core/constants/firebase_collections.dart';
import '../../../../core/errors/exceptions.dart';
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
}

class MessageRemoteDataSourceImpl implements MessageRemoteDataSource {
  final firestore.FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FirebaseDatabase _database;

  MessageRemoteDataSourceImpl({
    firestore.FirebaseFirestore? firestoreInstance,
    FirebaseStorage? storage,
    FirebaseDatabase? database,
  }) : _firestore = firestoreInstance ?? firestore.FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance,
       _database = database ?? FirebaseDatabase.instance;

  firestore.CollectionReference get _conversationsCollection =>
      _firestore.collection(FirebaseCollections.conversations);

  DatabaseReference _messagesRef(String conversationId) =>
      _database.ref().child('messages').child(conversationId);

  @override
  Stream<List<ConversationModel>> getConversations(String userId) {
    return _conversationsCollection
        .where('participantIds', arrayContains: userId)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return ConversationModel.fromFirestore(doc);
          }).toList();
        });
  }

  @override
  Stream<ConversationModel?> getConversationStream(String conversationId) {
    return _conversationsCollection.doc(conversationId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return ConversationModel.fromFirestore(doc);
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
        final data = Map<String, dynamic>.from(value as Map);
        data['id'] = key;
        messages.add(MessageModel.fromJson(data));
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
        final data = Map<String, dynamic>.from(value as Map);
        data['id'] = key;
        messages.add(MessageModel.fromJson(data));
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

      // If paginating backwards (history), we want oldest at top.
      // This is usually handled by the UI controller.
      // But typically we return List.reversed if user scrolls up.

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
    // RTDB doesn't easily support "after Timestamp" directly without an ID or precise millis.
    // However, onChildAdded is efficient.
    // For simplicity, we can listen to the whole last X messages or use startAt.

    // Convert to ISO string for comparison as stored in JSON (MessageModel.fromJson expects it)
    // Or if stored as millis. MessageModel uses serverTimestamp (Map) stored as string/map in RTDB?
    // Let's assume sending stores ISO string or millis.
    // MessageModel.toFirestore uses FieldValue.serverTimestamp().
    // For RTDB, we should use ServerValue.timestamp or DateTime.now().toIso8601String().

    // Let's implement simpler: just listen to limitToLast(1) and ignore old ones in UI provider?
    // Or query startAt.
    return _messagesRef(conversationId)
        .orderByChild('createdAt')
        .startAt(afterTimestamp.toIso8601String())
        .onValue
        .map((event) {
          if (event.snapshot.value == null) return [];
          final messages = <MessageModel>[];
          final map = event.snapshot.value as Map<dynamic, dynamic>;
          map.forEach((key, value) {
            final data = Map<String, dynamic>.from(value as Map);
            data['id'] = key;
            messages.add(MessageModel.fromJson(data));
          });
          return messages;
        });
  }

  @override
  Future<MessageModel> sendTextMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    String? senderPhotoUrl,
    required String content,
  }) async {
    try {
      final now = DateTime.now().toIso8601String();
      final messageData = {
        'senderId': senderId,
        'senderName': senderName,
        'senderPhotoUrl': senderPhotoUrl,
        'content': content,
        'type': 'text',
        'readBy': [senderId],
        'readAt': {senderId: now},
        'createdAt':
            now, // Use generic time or ServerValue.timestamp (requires converter)
      };

      final newMessageRef = _messagesRef(conversationId).push();
      await newMessageRef.set(messageData);

      // Mettre à jour la conversation avec le dernier message (FIRESTORE)
      await _updateConversationLastMessage(
        conversationId: conversationId,
        lastMessage: content,
        senderId: senderId,
      );

      final snapshot = await newMessageRef.get();
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      data['id'] = snapshot.key;

      return MessageModel.fromJson(data);
    } catch (e) {
      throw ServerException(
        'Erreur lors de l\'envoi du message: ${e.toString()}',
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

      final messageData = {
        'senderId': senderId,
        'senderName': senderName,
        'senderPhotoUrl': senderPhotoUrl,
        'content': caption ?? fileName,
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
        'participantIds': allParticipants,
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

    await _conversationsCollection.doc(conversationId).update({
      'lastMessage': lastMessage,
      'lastMessageSenderId': senderId,
      'lastMessageAt': firestore.FieldValue.serverTimestamp(),
      ...unreadUpdates,
    });
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
      default:
        return 'application/octet-stream';
    }
  }
}
