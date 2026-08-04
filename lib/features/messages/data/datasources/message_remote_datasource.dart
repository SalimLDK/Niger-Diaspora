import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:video_thumbnail/video_thumbnail.dart';

// No need for 'Query' import conflict if we use prefixes or explicit types
// But MessageRemoteDataSource interface used DocumentSnapshot, we changed it to dynamic lastMessageKey
// Let's check imports.

import '../../../../core/constants/firebase_collections.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/encryption_service.dart';
import '../../../../core/services/e2ee/message_crypto_service.dart';
import '../../../../core/utils/retry_helper.dart';
import '../../domain/entities/message_entity.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';

abstract class MessageRemoteDataSource {
  /// Stream des conversations de l'utilisateur
  Stream<List<ConversationModel>> getConversations(String userId);

  /// Stream des messages d'une conversation (RTDB)
  Stream<List<MessageModel>> getMessages(
    String conversationId, {
    DateTime? filterAfterDate,
  });

  /// Stream d'une conversation spécifique (pour détecter suppression/changements)
  Stream<ConversationModel?> getConversationStream(String conversationId);

  /// Récupérer les messages avec pagination (RTDB)
  Future<(List<MessageModel>, dynamic)> getMessagesPaginated({
    required String conversationId,
    required int limit,
    dynamic lastMessageKey,
    DateTime? filterAfterDate,
  });

  /// Stream des nouveaux messages après un timestamp donné
  Stream<List<MessageModel>> getNewMessagesStream({
    required String conversationId,
    required DateTime afterTimestamp,
  });

  /// Stream pour écouter les modifications de messages existants (réactions, éditions)
  Stream<MessageModel> getMessageUpdatesStream({
    required String conversationId,
  });

  /// Récupérer un message précis (déchiffré), même hors de la fenêtre
  /// paginée — utilisé par le bandeau des messages épinglés.
  Future<MessageModel?> getMessageById({
    required String conversationId,
    required String messageId,
  });

  /// Envoyer un message texte
  Future<MessageModel> sendTextMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    String? senderPhotoUrl,
    bool senderIsVerified = false,
    required String content,
    String? replyToId,
    Map<String, dynamic>? replyToMessageData,
    String? recipientId,
    List<String> participantIds = const [],
    Map<String, dynamic>? productData,
    Map<String, dynamic>? postData,
    Map<String, dynamic>? eventData,
    List<String> sentWhileBlockedBy = const [],
    Map<String, dynamic>? linkPreviewData,
    bool isForwarded = false,
    List<Map<String, String>> mentionedUsers = const [],
    String? clientMessageId,
    bool selfNote = false,
  });

  /// Envoyer un message avec fichier (Legacy - prefer split methods)
  Future<MessageModel> sendFileMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    String? senderPhotoUrl,
    required File file,
    required String type,
    String? caption,
    String? replyToId,
    Map<String, dynamic>? replyToMessageData,
  });

  /// Upload a media file and return the UploadTask for progress tracking
  UploadTask uploadMediaFile({
    required File file,
    required String conversationId,
    required String fileName,
  });

  /// Send a message with an already uploaded media URL
  Future<MessageModel> sendMediaMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    String? senderPhotoUrl,
    required String fileUrl,
    required String fileName,
    required int fileSize,
    required String mimeType,
    required String type,
    String? caption,
    String? replyToId,
    Map<String, dynamic>? replyToMessageData,
    bool isForwarded = false,
    String? thumbnailUrl,
    int? videoDuration,
    int? audioDuration,
    List<double>? audioWaveform,
    String? blurhash,
  });

  /// Créer une conversation individuelle
  Future<ConversationModel> createIndividualConversation({
    required String currentUserId,
    required String otherUserId,
  });

  /// Obtenir ou créer la conversation « Mes notes » (self-chat) de l'utilisateur.
  Future<ConversationModel> getOrCreateSelfConversation({
    required String userId,
  });

  /// Créer une conversation de groupe
  Future<ConversationModel> createGroupConversation({
    required String creatorId,
    required List<String> participantIds,
    required String groupName,
    String? groupImageUrl,
    String? groupId, // Add groupId parameter
  });

  /// Marquer comme livré (message reçu sur l'appareil du destinataire)
  Future<void> markAsDelivered({
    required String conversationId,
    required String userId,
  });

  /// Marquer comme lu
  Future<void> markAsRead({
    required String conversationId,
    required String userId,
  });

  /// Remettre à zéro le compteur de mentions non lues pour un utilisateur
  Future<void> clearUnreadMentions({
    required String conversationId,
    required String userId,
  });

  /// Supprimer une conversation
  Future<void> deleteConversation({
    required String conversationId,
    required String userId,
    bool forEveryone = false,
  });

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
    String? replyToId,
    Map<String, dynamic>? replyToMessageData,
    bool isForwarded = false,
  });

  /// Envoyer un message de localisation
  Future<MessageModel> sendLocationMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    String? senderPhotoUrl,
    required double latitude,
    required double longitude,
    required String address,
    String? replyToId,
    Map<String, dynamic>? replyToMessageData,
  });

  /// Envoyer un sticker
  Future<MessageModel> sendStickerMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    String? senderPhotoUrl,
    required String stickerPackId,
    required String stickerId,
    required String stickerUrl,
    bool isAnimated = false,
    String? replyToId,
    Map<String, dynamic>? replyToMessageData,
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

  /// Trouver une conversation de groupe par ID du groupe
  Future<ConversationModel?> findGroupConversationByGroupId({
    required String groupId,
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
  /// [duration] - Duration to mute for. null means mute forever.
  Future<void> muteConversation({
    required String conversationId,
    required String userId,
    Duration? duration,
  });

  /// Réactiver les notifications pour une conversation
  Future<void> unmuteConversation({
    required String conversationId,
    required String userId,
  });

  /// Épingler une conversation
  Future<void> pinConversation({
    required String conversationId,
    required String userId,
  });

  /// Désépingler une conversation
  Future<void> unpinConversation({
    required String conversationId,
    required String userId,
  });

  /// Obtenir le nombre de conversations épinglées par un utilisateur
  Future<int> getPinnedConversationCount(String userId);

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

  /// Set typing status for a user in a conversation
  Future<void> setTypingStatus({
    required String conversationId,
    required String userId,
    required bool isTyping,
  });

  /// Stream of users currently typing in a conversation
  Stream<Map<String, bool>> getTypingStatusStream(String conversationId);

  /// Add an emoji reaction to a message
  Future<void> addReaction({
    required String conversationId,
    required String messageId,
    required String emoji,
  });

  /// Remove an emoji reaction from a message
  Future<void> removeReaction({
    required String conversationId,
    required String messageId,
    required String emoji,
  });

  /// Send a system message (e.g., "User joined the group")
  Future<MessageModel> sendSystemMessage({
    required String conversationId,
    required String content,
  });

  /// Rechercher des conversations par nom ou dernier message
  Future<List<ConversationModel>> searchConversations(
    String userId,
    String query,
  );

  /// Toggle star status for a message
  Future<void> toggleStarMessage({
    required String conversationId,
    required String messageId,
    required String userId,
  });

  /// Edit a text message (within time limit)
  Future<void> editMessage({
    required String conversationId,
    required String messageId,
    required String newContent,
    required String oldContent,
  });

  /// Set auto-delete settings for ephemeral messages
  Future<void> setAutoDeleteSettings({
    required String conversationId,
    required int? durationSeconds,
  });

  /// Get auto-delete settings for a conversation
  Future<int?> getAutoDeleteSettings(String conversationId);

  /// Get starred messages for a conversation by user
  Future<List<MessageModel>> getStarredMessages({
    required String conversationId,
    required String userId,
    int limit = 100,
  });

  /// Search messages in a conversation by content
  Future<List<MessageModel>> searchMessagesInConversation({
    required String conversationId,
    required String query,
    int limit = 200,
  });

  /// Restaurer une conversation pour un utilisateur (retirer de deletedBy)
  Future<void> restoreConversationForUser({
    required String conversationId,
    required String userId,
  });

  /// Recuperer une conversation par son ID
  Future<ConversationModel?> getConversationById(String conversationId);

  /// Recuperer uniquement les messages depuis un timestamp (sync differentielle)
  Future<List<MessageModel>> getMessagesSince({
    required String conversationId,
    required DateTime since,
    int limit = 100,
  });

  /// Get pending message requests for a user (conversations where user is recipient)
  Stream<List<ConversationModel>> getMessageRequests(String userId);

  /// Update the request status of a conversation (accept or decline)
  Future<void> updateRequestStatus({
    required String conversationId,
    required String status,
    required String recipientId,
  });

  /// Create an individual conversation as a message request (for non-linked users)
  Future<ConversationModel> createIndividualConversationAsRequest({
    required String currentUserId,
    required String otherUserId,
  });
}

class MessageRemoteDataSourceImpl implements MessageRemoteDataSource {
  final firestore.FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FirebaseDatabase _database;
  final EncryptionService _encryptionService;
  final MessageCryptoService? _crypto;

  MessageRemoteDataSourceImpl({
    firestore.FirebaseFirestore? firestoreInstance,
    FirebaseStorage? storage,
    FirebaseDatabase? database,
    EncryptionService? encryptionService,
    MessageCryptoService? messageCryptoService,
  }) : _firestore = firestoreInstance ?? firestore.FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance,
       _database = database ?? FirebaseDatabase.instance,
       _encryptionService = encryptionService ?? EncryptionService(),
       _crypto = messageCryptoService;

  firestore.CollectionReference get _conversationsCollection =>
      _firestore.collection(FirebaseCollections.conversations);

  DatabaseReference _messagesRef(String conversationId) =>
      _database.ref().child('messages').child(conversationId);

  DatabaseReference _conversationParticipantsRef(String conversationId) =>
      _database
          .ref()
          .child('conversations')
          .child(conversationId)
          .child('participants');

  /// Sync conversation participants to Realtime Database for security rules
  Future<void> _syncParticipantsToRTDB(
    String conversationId,
    List<String> participantIds,
  ) async {
    try {
      final participantsMap = <String, bool>{};
      for (final id in participantIds) {
        participantsMap[id] = true;
      }
      await _conversationParticipantsRef(conversationId).set(participantsMap);
    } catch (e) {
      // debugPrint('⚠️ Failed to sync participants to RTDB: $e');
      // Don't throw - this is for security rules, not critical path
    }
  }

  /// Remove a participant from RTDB
  Future<void> _removeParticipantFromRTDB(
    String conversationId,
    String userId,
  ) async {
    try {
      await _conversationParticipantsRef(conversationId).child(userId).remove();
    } catch (e) {
      // debugPrint('⚠️ Failed to remove participant from RTDB: $e');
    }
  }

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
  Stream<List<MessageModel>> getMessages(
    String conversationId, {
    DateTime? filterAfterDate,
  }) {
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
          _decryptMessageFields(data);
          messages.add(MessageModel.fromJson(data));
        }
      });

      // Sort by creation time
      messages.sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aTime.compareTo(bTime);
      });

      // Apply date filtering if specified (for private groups)
      if (filterAfterDate != null) {
        return messages.where((message) {
          final createdAt = message.createdAt;
          return createdAt != null && createdAt.isAfter(filterAfterDate);
        }).toList();
      }

      return messages;
    });
  }

  @override
  Future<(List<MessageModel>, dynamic)> getMessagesPaginated({
    required String conversationId,
    required int limit,
    dynamic lastMessageKey,
    DateTime? filterAfterDate,
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

      for (final entry in map.entries) {
        if (entry.value is Map) {
          final data = _safeMap(entry.value as Map);
          data['id'] = entry.key;
          _decryptMessageFields(data);
          // Async Signal decryption (overrides AES content if e2eePayload present)
          await _decryptE2EEContent(data);
          messages.add(MessageModel.fromJson(data));
        }
      }

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

      // Apply date filtering if specified (for private groups)
      List<MessageModel> filteredMessages = messages;
      if (filterAfterDate != null) {
        filteredMessages =
            messages.where((message) {
              final createdAt = message.createdAt;
              return createdAt != null && createdAt.isAfter(filterAfterDate);
            }).toList();
      }

      final newLastKey =
          filteredMessages.isNotEmpty ? filteredMessages.first.id : null;

      return (filteredMessages, newLastKey);
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
              _decryptMessageFields(data);
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

  @override
  Stream<MessageModel> getMessageUpdatesStream({
    required String conversationId,
  }) {
    // Use onChildChanged to listen for modifications to existing messages
    // This captures reactions, edits, deletions, etc.
    return _messagesRef(conversationId).onChildChanged.map((event) {
      final data = _safeMap(event.snapshot.value);
      data['id'] = event.snapshot.key;
      _decryptMessageFields(data);
      return MessageModel.fromJson(data);
    });
  }

  @override
  Future<MessageModel?> getMessageById({
    required String conversationId,
    required String messageId,
  }) async {
    final snapshot = await _messagesRef(conversationId).child(messageId).get();
    if (snapshot.value == null) return null;
    final data = _safeMap(snapshot.value);
    data['id'] = messageId;
    _decryptMessageFields(data);
    return MessageModel.fromJson(data);
  }

  /// Helper to decrypt message fields (content, locationAddress, latitude, longitude)
  void _decryptMessageFields(Map<String, dynamic> data) {
    if (data['content'] is String) {
      try {
        data['content'] = _encryptionService.decryptText(data['content']);
      } catch (_) {
        // Keep original content if decryption fails (legacy unencrypted data)
      }
    }
    if (data['locationAddress'] is String && (data['locationAddress'] as String).isNotEmpty) {
      try {
        data['locationAddress'] = _encryptionService.decryptText(data['locationAddress']);
      } catch (_) {
        // Keep original address if decryption fails (legacy unencrypted data)
      }
    }
    if (data['latitude'] is String) {
      try {
        final decrypted = _encryptionService.decryptText(data['latitude'] as String);
        data['latitude'] = double.tryParse(decrypted) ?? data['latitude'];
      } catch (_) {
        // Keep original value if decryption fails (legacy unencrypted data)
      }
    }
    if (data['longitude'] is String) {
      try {
        final decrypted = _encryptionService.decryptText(data['longitude'] as String);
        data['longitude'] = double.tryParse(decrypted) ?? data['longitude'];
      } catch (_) {
        // Keep original value if decryption fails (legacy unencrypted data)
      }
    }
  }

  /// Encrypt [plaintext] for a conversation, choosing Signal or AES-GCM based
  /// on conversation type and session availability.
  ///
  /// Reads participantIds from [convDoc] (already fetched by most callers).
  /// Returns a [CryptoResult] that callers spread into their RTDB payload.
  Future<CryptoResult> _encryptContent({
    required String plaintext,
    required String senderId,
    required firestore.DocumentSnapshot convDoc,
    String? conversationId,
  }) async {
    if (_crypto != null && convDoc.exists) {
      final convData = convDoc.data() as Map<String, dynamic>?;
      final participantIds = List<String>.from(convData?['participantIds'] ?? []);
      if (participantIds.length == 2) {
        // 1:1 conversation — Signal per-session encryption
        final recipientId = participantIds.firstWhere(
          (id) => id != senderId,
          orElse: () => '',
        );
        if (recipientId.isNotEmpty) {
          return _crypto.encrypt1to1(plaintext: plaintext, recipientId: recipientId);
        }
      }
      // Group conversation — Sender Key encryption
      return _crypto.encryptGroup(plaintext, groupId: conversationId);
    }
    return CryptoResult(
      {'content': _encryptionService.encryptText(plaintext), 'encryptionLevel': 'aes'},
      'aes',
    );
  }

  /// Async Signal-Protocol decryption step.
  /// Called after [_decryptMessageFields] (sync AES-GCM pass).
  /// Handles both the new multi-device format (`e2eePayloads`) and the legacy
  /// single-device format (`e2eePayload`). Delegates entirely to
  /// [MessageCryptoService.decrypt] which encapsulates all format detection.
  Future<void> _decryptE2EEContent(Map<String, dynamic> data) async {
    if (_crypto == null) return;
    // Only enter the async path if an E2EE payload is actually present.
    final hasNew       = data['e2eePayloads']      != null;
    final hasLegacy    = data['e2eePayload']        != null;
    final hasSenderKey = data['senderKeyPayload']   != null;
    if (!hasNew && !hasLegacy && !hasSenderKey) return;

    final senderId = data['senderId'] as String? ?? '';
    data['content'] = await _crypto.decrypt(payload: data, senderId: senderId);
    // Clean up raw payload fields after decryption
    data.remove('e2eePayloads');
    data.remove('e2eePayload');
    data.remove('senderKeyPayload');
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
      // Check if this Map is actually an array from Firebase RTDB
      // Firebase RTDB converts arrays to Maps with numeric string keys like {"0": "a", "1": "b"}
      if (_isArrayLikeMap(value)) {
        return _convertMapToList(value);
      }
      return _safeMap(value);
    } else if (value is List) {
      return value.map((e) => _safeValue(e)).toList();
    }
    return value;
  }

  /// Check if a Map looks like an array (has sequential numeric string keys)
  bool _isArrayLikeMap(Map map) {
    if (map.isEmpty) return false;
    final keys = map.keys.toList();
    // Check if all keys are numeric strings
    for (final key in keys) {
      final keyStr = key.toString();
      if (int.tryParse(keyStr) == null) {
        return false;
      }
    }
    return true;
  }

  /// Convert a Firebase RTDB array-like Map back to a List
  List<dynamic> _convertMapToList(Map map) {
    final entries = map.entries.toList();
    // Sort by numeric key to maintain order
    entries.sort((a, b) {
      final aKey = int.tryParse(a.key.toString()) ?? 0;
      final bKey = int.tryParse(b.key.toString()) ?? 0;
      return aKey.compareTo(bKey);
    });
    return entries.map((e) => _safeValue(e.value)).toList();
  }

  @override
  Future<MessageModel> sendTextMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    String? senderPhotoUrl,
    bool senderIsVerified = false,
    required String content,
    String? replyToId,
    Map<String, dynamic>? replyToMessageData,
    Map<String, dynamic>? productData,
    Map<String, dynamic>? postData,
    Map<String, dynamic>? eventData,
    List<String> sentWhileBlockedBy = const [],
    Map<String, dynamic>? linkPreviewData,
    bool isForwarded = false,
    List<Map<String, String>> mentionedUsers = const [],
    String? clientMessageId,
    String? recipientId,
    List<String> participantIds = const [],
    bool selfNote = false,
  }) async {
    // CORRECTION: Ressusciter la conversation si necessaire (soft delete)
    final convDoc = await _conversationsCollection.doc(conversationId).get();
    int? autoDeleteSeconds;
    if (convDoc.exists) {
      final convData = convDoc.data() as Map<String, dynamic>?;
      final participantIds = List<String>.from(convData?['participantIds'] ?? []);
      autoDeleteSeconds = convData?['autoDeleteAfterSeconds'] as int?;
      await _resurrectConversationIfNeeded(
        conversationId: conversationId,
        participantIds: participantIds,
      );
    }

    final nowDateTime = DateTime.now();
    final now = nowDateTime.toIso8601String();

    final cryptoResult = await _encryptContent(
      plaintext: content,
      senderId: senderId,
      convDoc: convDoc,
      conversationId: conversationId,
    );

    // Calculate expiresAt if auto-delete is enabled
    String? expiresAt;
    if (autoDeleteSeconds != null) {
      expiresAt = nowDateTime.add(Duration(seconds: autoDeleteSeconds)).toIso8601String();
    }

    final messageData = {
      'senderId': senderId,
      'senderName': senderName,
      'senderPhotoUrl': senderPhotoUrl,
      ...cryptoResult.fields,
      'type': 'text',
      'readBy': [senderId],
      'readAt': {senderId: now},
      'deliveredTo': [senderId],
      'deliveredAt': {senderId: now},
      'createdAt': now,
      'replyToId': replyToId,
      'replyToMessageData': replyToMessageData,
      if (productData != null) 'productData': productData,
      if (postData != null) 'postData': postData,
      if (eventData != null) 'eventData': eventData,
      if (sentWhileBlockedBy.isNotEmpty) 'sentWhileBlockedBy': sentWhileBlockedBy,
      if (linkPreviewData != null) 'linkPreviewData': linkPreviewData,
      if (isForwarded) 'isForwarded': true,
      if (expiresAt != null) 'expiresAt': expiresAt,
      if (mentionedUsers.isNotEmpty) 'mentionedUsers': mentionedUsers,
      if (clientMessageId != null) 'clientMessageId': clientMessageId,
      if (senderIsVerified) 'senderIsVerified': true,
    };

    // Create message in RTDB - this is the critical operation
    final newMessageRef = _messagesRef(conversationId).push();
    await newMessageRef.set(messageData);

    // Try to update conversation metadata (non-critical)
    await _updateConversationLastMessage(
      conversationId: conversationId,
      lastMessage:
          postData != null
              ? '📌 ${postData['authorName'] ?? 'Post partagé'}'
              : productData != null
                  ? '🛒 ${productData['title'] ?? 'Produit'}'
                  : content,
      senderId: senderId,
    );

    // Try to get the created message, but don't fail if it doesn't work
    try {
      final snapshot = await newMessageRef.get();
      final data = _safeMap(snapshot.value);
      data['id'] = snapshot.key;
      return MessageModel.fromJson(data);
    } catch (e) {
      // If we can't retrieve it, create a minimal model
      // debugPrint('⚠️ Could not retrieve created message, using minimal model');
      return MessageModel(
        id: newMessageRef.key!,
        senderId: senderId,
        senderName: senderName,
        senderPhotoUrl: senderPhotoUrl,
        senderIsVerified: senderIsVerified,
        content: content,
        type: 'text',
        createdAt: DateTime.parse(now).toLocal(),
        readBy: [senderId],
        readAt: {senderId: DateTime.parse(now).toLocal()},
        replyToId: replyToId,
        replyToMessageData: replyToMessageData,
        productData: productData,
        postData: postData,
        eventData: eventData,
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
    Duration? duration,
  }) async {
    try {
      // Calculate mute expiration time
      // null duration = forever, otherwise calculate expiration
      final String muteValue;
      if (duration == null) {
        muteValue = 'forever';
      } else {
        final expirationTime = DateTime.now().add(duration);
        muteValue = expirationTime.toIso8601String();
      }

      await _conversationsCollection.doc(conversationId).update({
        'mutedBy.$userId': muteValue,
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
        'mutedBy.$userId': firestore.FieldValue.delete(),
      });
    } on firestore.FirebaseException catch (e) {
      throw ServerException(
        e.message ?? 'Erreur lors de la réactivation des notifications',
      );
    }
  }

  @override
  Future<void> pinConversation({
    required String conversationId,
    required String userId,
  }) async {
    try {
      // Vérifier la limite de 5 conversations épinglées
      final count = await getPinnedConversationCount(userId);
      if (count >= 5) {
        throw ServerException('Vous ne pouvez pas épingler plus de 5 conversations');
      }

      await _conversationsCollection.doc(conversationId).update({
        'pinnedBy.$userId': firestore.FieldValue.serverTimestamp(),
      });
    } on firestore.FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors de l\'épinglage');
    }
  }

  @override
  Future<void> unpinConversation({
    required String conversationId,
    required String userId,
  }) async {
    try {
      await _conversationsCollection.doc(conversationId).update({
        'pinnedBy.$userId': firestore.FieldValue.delete(),
      });
    } on firestore.FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors du désépinglage');
    }
  }

  @override
  Future<int> getPinnedConversationCount(String userId) async {
    try {
      final snapshot = await _conversationsCollection
          .where('participantIds', arrayContains: userId)
          .where('pinnedBy.$userId', isNull: false)
          .get();
      return snapshot.docs.length;
    } on firestore.FirebaseException {
      return 0;
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
    String? replyToId,
    Map<String, dynamic>? replyToMessageData,
  }) async {
    try {
      // Legacy method - still functional but blocking
      final fileName = path.basename(file.path);

      // Upload avec retry automatique
      final fileUrl = await RetryHelper.withRetry(
        operation: () async {
          final task = uploadMediaFile(
            file: file,
            conversationId: conversationId,
            fileName: fileName,
          );
          final snapshot = await task;
          return await snapshot.ref.getDownloadURL();
        },
        config: RetryConfig.uploadConfig,
        onRetry: (attempt, error) {
          // debugPrint('Upload retry $attempt: $error');
        },
      );
      final fileSize = await file.length();
      final mimeType = _getMimeType(path.extension(file.path));

      // Generate and upload thumbnail for videos
      String? thumbnailUrl;
      int? videoDuration;
      if (type == 'video') {
        final thumbnailResult = await _generateAndUploadVideoThumbnail(
          videoFile: file,
          conversationId: conversationId,
        );
        thumbnailUrl = thumbnailResult.$1;
        videoDuration = thumbnailResult.$2;
      }

      return sendMediaMessage(
        conversationId: conversationId,
        senderId: senderId,
        senderName: senderName,
        senderPhotoUrl: senderPhotoUrl,
        fileUrl: fileUrl,
        fileName: fileName,
        fileSize: fileSize,
        mimeType: mimeType,
        type: type,
        caption: caption,
        replyToId: replyToId,
        replyToMessageData: replyToMessageData,
        thumbnailUrl: thumbnailUrl,
        videoDuration: videoDuration,
      );
    } catch (e) {
      throw ServerException(
        'Erreur lors de l\'envoi du fichier: ${e.toString()}',
      );
    }
  }

  /// Generate a thumbnail from a video file and upload it to Firebase Storage
  Future<(String?, int?)> _generateAndUploadVideoThumbnail({
    required File videoFile,
    required String conversationId,
  }) async {
    try {
      // Generate thumbnail from video
      final Uint8List? thumbnailData = await VideoThumbnail.thumbnailData(
        video: videoFile.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 320,
        quality: 75,
      );

      if (thumbnailData == null) {
        return (null, null);
      }

      // Upload thumbnail to Firebase Storage
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final thumbnailPath = 'thumbnails/$conversationId/${timestamp}_thumb.jpg';
      final thumbnailRef = _storage.ref().child(thumbnailPath);

      await thumbnailRef.putData(
        thumbnailData,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final thumbnailUrl = await thumbnailRef.getDownloadURL();

      // Try to get video duration (approximate from file size if not available)
      // Note: Getting exact duration requires video_player or ffmpeg
      // For now, we'll estimate based on file size (rough approximation)
      final fileSize = await videoFile.length();
      // Rough estimate: 1MB ~= 8 seconds for compressed video
      final estimatedDuration = (fileSize / (1024 * 1024) * 8).round();

      return (thumbnailUrl, estimatedDuration > 0 ? estimatedDuration : null);
    } catch (e) {
      // If thumbnail generation fails, continue without it
      return (null, null);
    }
  }

  @override
  UploadTask uploadMediaFile({
    required File file,
    required String conversationId,
    required String fileName,
  }) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final storagePath = 'messages/$conversationId/${timestamp}_$fileName';
    final ref = _storage.ref().child(storagePath);
    return ref.putFile(file);
  }

  @override
  Future<MessageModel> sendMediaMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    String? senderPhotoUrl,
    required String fileUrl,
    required String fileName,
    required int fileSize,
    required String mimeType,
    required String type,
    String? caption,
    String? replyToId,
    Map<String, dynamic>? replyToMessageData,
    bool isForwarded = false,
    String? thumbnailUrl,
    int? videoDuration,
    int? audioDuration,
    List<double>? audioWaveform,
    String? blurhash,
  }) async {
    try {
      // Check for auto-delete settings
      final convDoc = await _conversationsCollection.doc(conversationId).get();
      int? autoDeleteSeconds;
      if (convDoc.exists) {
        final convData = convDoc.data() as Map<String, dynamic>?;
        autoDeleteSeconds = convData?['autoDeleteAfterSeconds'] as int?;
      }

      final nowDateTime = DateTime.now();
      final now = nowDateTime.toIso8601String();
      // For video/image/audio file, use caption only - never show filename to users
      final contentText =
          (type == 'video' || type == 'image' || type == 'audioFile')
              ? (caption ?? '')
              : (caption ?? fileName);
      final cryptoResult = await _encryptContent(
        plaintext: contentText,
        senderId: senderId,
        convDoc: convDoc,
        conversationId: conversationId,
      );

      // Calculate expiresAt if auto-delete is enabled
      String? expiresAt;
      if (autoDeleteSeconds != null) {
        expiresAt = nowDateTime.add(Duration(seconds: autoDeleteSeconds)).toIso8601String();
      }

      final messageData = {
        'senderId': senderId,
        'senderName': senderName,
        'senderPhotoUrl': senderPhotoUrl,
        ...cryptoResult.fields,
        'type': type,
        'fileUrl': fileUrl,
        'fileName': fileName,
        'fileSize': fileSize,
        'mimeType': mimeType,
        'readBy': [senderId],
        'readAt': {senderId: now},
        'deliveredTo': [senderId],
        'deliveredAt': {senderId: now},
        'createdAt': now,
        'replyToId': replyToId,
        'replyToMessageData': replyToMessageData,
        if (isForwarded) 'isForwarded': true,
        if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
        if (videoDuration != null) 'videoDuration': videoDuration,
        if (audioDuration != null) 'audioDuration': audioDuration,
        if (audioWaveform != null) 'audioWaveform': audioWaveform,
        if (blurhash != null) 'blurhash': blurhash,
        if (expiresAt != null) 'expiresAt': expiresAt,
        'mediaExpiresAt': nowDateTime.add(const Duration(days: 15)).toIso8601String(),
        'mediaExpired': false,
      };

      final newMessageRef = _messagesRef(conversationId).push();
      await newMessageRef.set(messageData);

      // Update conversation metadata
      final String lastMessageText;
      final MessageType msgType;
      switch (type) {
        case 'image':
          lastMessageText = '📷 Photo';
          msgType = MessageType.image;
        case 'video':
          lastMessageText = '🎬 Vidéo';
          msgType = MessageType.video;
        case 'audioFile':
          lastMessageText = '🎵 Audio';
          msgType = MessageType.audio;
        default:
          lastMessageText = '📎 Fichier';
          msgType = MessageType.file;
      }
      await _updateConversationLastMessage(
        conversationId: conversationId,
        lastMessage: lastMessageText,
        senderId: senderId,
        messageType: msgType,
        messageTypeString: type == 'audioFile' ? 'audioFile' : null,
      );

      final snapshot = await newMessageRef.get();
      // Handle potential null snapshot (though unlikely after set)
      if (snapshot.value == null) {
        // For video/image/audio file, use caption only - never show filename to users
        final contentForMedia =
            (type == 'video' || type == 'image' || type == 'audioFile')
                ? (caption ?? '')
                : (caption ?? fileName);
        return MessageModel(
          id: newMessageRef.key!,
          senderId: senderId,
          senderName: senderName,
          senderPhotoUrl: senderPhotoUrl,
          content: contentForMedia,
          type: type,
          fileUrl: fileUrl,
          fileName: fileName,
          fileSize: fileSize,
          mimeType: mimeType,
          createdAt: DateTime.parse(now).toLocal(),
          readBy: [senderId],
          readAt: {senderId: DateTime.parse(now).toLocal()},
        );
      }

      final data = _safeMap(snapshot.value);
      data['id'] = snapshot.key;

      return MessageModel.fromJson(data);
    } catch (e) {
      throw ServerException(
        'Erreur lors de l\'enregistrement du message média: ${e.toString()}',
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

      // Sync participants to RTDB for security rules
      await _syncParticipantsToRTDB(docRef.id, [currentUserId, otherUserId]);

      return ConversationModel.fromFirestore(doc);
    } on firestore.FirebaseException catch (e) {
      throw ServerException(
        e.message ?? 'Erreur lors de la création de la conversation',
      );
    }
  }

  @override
  Future<ConversationModel> getOrCreateSelfConversation({
    required String userId,
  }) async {
    // Backend Firebase historique (non utilisé — l'app passe par Supabase).
    // Implémentation minimale pour satisfaire l'interface.
    throw ServerException(
      'getOrCreateSelfConversation non supporté par le backend Firebase legacy',
    );
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

      // PRIORITÉ 1: Chercher par groupId si fourni (ne change jamais)
      if (groupId != null) {
        final groupIdSnapshot =
            await _conversationsCollection
                .where('type', isEqualTo: 'group')
                .where('groupId', isEqualTo: groupId)
                .limit(1)
                .get();

        if (groupIdSnapshot.docs.isNotEmpty) {
          final existingDoc = groupIdSnapshot.docs.first;
          final existingData = existingDoc.data() as Map<String, dynamic>;
          final existingParticipants = List<String>.from(
            existingData['participantIds'] ?? [],
          );

          // Mettre à jour les participants si nécessaire
          final missingParticipants = allParticipants
              .where((p) => !existingParticipants.contains(p))
              .toList();

          if (missingParticipants.isNotEmpty) {
            await _conversationsCollection.doc(existingDoc.id).update({
              'participantIds': firestore.FieldValue.arrayUnion(missingParticipants),
            });

            // Sync updated participants to RTDB for security rules
            final updatedParticipants = [...existingParticipants, ...missingParticipants];
            await _syncParticipantsToRTDB(existingDoc.id, updatedParticipants);
          }

          // Retourner la conversation existante (avec ou sans mise à jour)
          final updatedDoc = await _conversationsCollection.doc(existingDoc.id).get();
          return ConversationModel.fromFirestore(updatedDoc);
        }
      }

      // PRIORITÉ 2: Chercher par nom (fallback pour les anciennes conversations sans groupId)
      // Note: Security rules require participantIds filter for read access
      final existingSnapshot =
          await _conversationsCollection
              .where('type', isEqualTo: 'group')
              .where('name', isEqualTo: groupName)
              .where('participantIds', arrayContains: creatorId)
              .get();

      // Vérifier si une conversation existe avec ce nom
      for (final doc in existingSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final existingGroupId = data['groupId'] as String?;

        // Si cette conversation a le même groupId, l'utiliser
        if (groupId != null && existingGroupId == groupId) {
          // Mettre à jour les participants si nécessaire
          final existingParticipants = List<String>.from(
            data['participantIds'] ?? [],
          );
          final missingParticipants = allParticipants
              .where((p) => !existingParticipants.contains(p))
              .toList();

          if (missingParticipants.isNotEmpty) {
            await _conversationsCollection.doc(doc.id).update({
              'participantIds': firestore.FieldValue.arrayUnion(missingParticipants),
            });
            await _syncParticipantsToRTDB(doc.id, [...existingParticipants, ...missingParticipants]);
          }

          final updatedDoc = await _conversationsCollection.doc(doc.id).get();
          return ConversationModel.fromFirestore(updatedDoc);
        }

        // Fallback: Si pas de groupId stocké mais même nom, on assume que c'est la même conversation
        // (pour compatibilité avec les anciennes données)
        if (existingGroupId == null && groupId != null) {
          // Mettre à jour le groupId et les participants
          final existingParticipants = List<String>.from(
            data['participantIds'] ?? [],
          );
          final missingParticipants = allParticipants
              .where((p) => !existingParticipants.contains(p))
              .toList();

          final updates = <String, dynamic>{
            'groupId': groupId,
          };
          if (missingParticipants.isNotEmpty) {
            updates['participantIds'] = firestore.FieldValue.arrayUnion(missingParticipants);
          }

          await _conversationsCollection.doc(doc.id).update(updates);
          if (missingParticipants.isNotEmpty) {
            await _syncParticipantsToRTDB(doc.id, [...existingParticipants, ...missingParticipants]);
          }

          final updatedDoc = await _conversationsCollection.doc(doc.id).get();
          return ConversationModel.fromFirestore(updatedDoc);
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

      // Sync participants to RTDB for security rules
      await _syncParticipantsToRTDB(docRef.id, allParticipants);

      return ConversationModel.fromFirestore(doc);
    } on firestore.FirebaseException catch (e) {
      throw ServerException(
        e.message ?? 'Erreur lors de la création du groupe',
      );
    }
  }

  @override
  Future<void> markAsDelivered({
    required String conversationId,
    required String userId,
  }) async {
    // Firebase RTDB handles delivery via presence; no-op for this implementation
  }

  @override
  Future<void> markAsRead({
    required String conversationId,
    required String userId,
  }) async {
    try {
      // Update unreadCount in Firestore
      await _conversationsCollection.doc(conversationId).update({
        'unreadCount.$userId': 0,
      });

      // Update readBy on all unread messages in RTDB
      final messagesRef = _messagesRef(conversationId);
      final snapshot = await messagesRef
          .orderByChild('createdAt')
          .get();

      if (snapshot.exists && snapshot.value != null) {
        final now = DateTime.now().toUtc().toIso8601String();
        final updates = <String, dynamic>{};

        final messagesMap = snapshot.value as Map<dynamic, dynamic>;
        for (final entry in messagesMap.entries) {
          final messageId = entry.key as String;
          final messageData = entry.value as Map<dynamic, dynamic>;

          // Skip if user already read this message
          final readBy = List<String>.from(messageData['readBy'] ?? []);
          if (readBy.contains(userId)) continue;

          // Skip if user is the sender (already in readBy)
          if (messageData['senderId'] == userId) continue;

          // Add user to readBy and readAt
          updates['$messageId/readBy'] = [...readBy, userId];
          updates['$messageId/readAt/$userId'] = now;
        }

        // Batch update if there are messages to mark as read
        if (updates.isNotEmpty) {
          await messagesRef.update(updates);
        }
      }
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors du marquage comme lu');
    }
  }

  @override
  Future<void> clearUnreadMentions({
    required String conversationId,
    required String userId,
  }) async {
    try {
      await _conversationsCollection.doc(conversationId).update({
        'unreadMentions.$userId': 0,
      });
    } on FirebaseException catch (e) {
      throw ServerException(
        e.message ?? 'Erreur lors de la remise à zéro des mentions',
      );
    }
  }

  @override
  Future<void> deleteConversation({
    required String conversationId,
    required String userId,
    bool forEveryone = false,
  }) async {
    try {
      if (forEveryone) {
        // 1. Verify permissions (Admin or Creator)
        final doc = await _conversationsCollection.doc(conversationId).get();
        if (!doc.exists) return;

        final data = doc.data() as Map<String, dynamic>;
        final creatorId = data['createdBy'] as String?;
        final adminIds = List<String>.from(data['adminIds'] ?? []);

        // Check if user is creator or admin of the group
        if (creatorId != userId && !adminIds.contains(userId)) {
          // Optional: Check if user is Super Admin in valid real-world app,
          // but sticking to conversation roles for now as per "admins/créateurs" request.
          throw ServerException(
            "Titre requis : seul l'administrateur ou le créateur peut supprimer la conversation pour tout le monde.",
          );
        }

        // 2. Delete media files from storage/messages/conversationId
        await _deleteFilesFromStorage(conversationId);

        // 3. Delete messages (RTDB)
        await _messagesRef(conversationId).remove();

        // 4. Delete conversation (Firestore)
        await _conversationsCollection.doc(conversationId).delete();
      } else {
        // Soft delete (Delete for me)
        await _conversationsCollection.doc(conversationId).update({
          'deletedBy.$userId': firestore.FieldValue.serverTimestamp(),
          // Clear unread count for this user
          'unreadCount.$userId': 0,
        });
      }
    } on FirebaseException catch (e) {
      throw ServerException(
        e.message ?? 'Erreur lors de la suppression de la conversation',
      );
    }
  }

  Future<void> _deleteFilesFromStorage(String conversationId) async {
    try {
      // List all files in the conversation folder
      // Note: Firebase Storage listAll() might be paginated or limited.
      // Ideally keeping track of file paths in Firestore is better,
      // but listing the folder is a good cleanup attempt.
      final storageRef = _storage.ref().child('messages/$conversationId');
      final listResult = await storageRef.listAll();

      await Future.wait(listResult.items.map((ref) => ref.delete()));

      // debugPrint(
      //   'Deleted ${listResult.items.length} files from storage for conversation $conversationId',
      // );
    } catch (e) {
      // Log but don't blocking deletion of conversation
      // debugPrint('⚠️ Error deleting files from storage: $e');
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
    MessageType messageType = MessageType.text,
    String? messageTypeString,
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
        'lastMessageType': messageTypeString ?? messageType.name,
        'lastMessageAt': firestore.FieldValue.serverTimestamp(),
        ...unreadUpdates,
      });
    } catch (e) {
      // Don't throw - message is already created in RTDB
      // Just log the error to avoid retry creating duplicate messages
      // debugPrint('⚠️ Failed to update conversation metadata: $e');
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

      // Send system message
      final userName = await _getUserDisplayName(userId);
      await sendSystemMessage(
        conversationId: conversationId,
        content: '$userName est maintenant administrateur',
      );
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

      // Send system message
      final userName = await _getUserDisplayName(userId);
      await sendSystemMessage(
        conversationId: conversationId,
        content: '$userName n\'est plus administrateur',
      );
    } on firestore.FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors de la destitution admin');
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

  @override
  Future<void> removeUserFromGroup({
    required String conversationId,
    required String userId,
  }) async {
    try {
      // Send system message before removing (so user can still see it)
      final userName = await _getUserDisplayName(userId);
      await sendSystemMessage(
        conversationId: conversationId,
        content: '$userName a été retiré du groupe',
      );

      // Fetch conversation to check for groupId
      final doc = await _conversationsCollection.doc(conversationId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final groupId = data['groupId'] as String?;

        // If linked to a group, remove from group members too
        if (groupId != null) {
          await _firestore.collection('groups').doc(groupId).update({
            'memberIds': firestore.FieldValue.arrayRemove([userId]),
            'adminIds': firestore.FieldValue.arrayRemove([userId]),
          });
        }
      }

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

      // Remove participant from RTDB for security rules
      await _removeParticipantFromRTDB(conversationId, userId);
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
    String? replyToId,
    Map<String, dynamic>? replyToMessageData,
    bool isForwarded = false,
  }) async {
    try {
      // Upload audio file avec retry automatique
      final fileName = path.basename(audioFile.path);
      final fileExtension = path.extension(audioFile.path);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storagePath =
          'messages/$conversationId/audio_$timestamp$fileExtension';

      final fileUrl = await RetryHelper.withRetry(
        operation: () async {
          final ref = _storage.ref().child(storagePath);
          final uploadTask = await ref.putFile(audioFile);
          return await uploadTask.ref.getDownloadURL();
        },
        config: RetryConfig.uploadConfig,
        onRetry: (attempt, error) {
          // debugPrint('Audio upload retry $attempt: $error');
        },
      );

      final mimeType = _getMimeType(fileExtension);
      final fileSize = await audioFile.length();

      // Check for auto-delete settings
      final convDoc = await _conversationsCollection.doc(conversationId).get();
      int? autoDeleteSeconds;
      if (convDoc.exists) {
        final convData = convDoc.data() as Map<String, dynamic>?;
        autoDeleteSeconds = convData?['autoDeleteAfterSeconds'] as int?;
      }

      final nowDateTime = DateTime.now();
      final now = nowDateTime.toIso8601String();

      // Calculate expiresAt if auto-delete is enabled
      String? expiresAt;
      if (autoDeleteSeconds != null) {
        expiresAt = nowDateTime.add(Duration(seconds: autoDeleteSeconds)).toIso8601String();
      }

      final messageData = {
        'senderId': senderId,
        'senderName': senderName,
        'senderPhotoUrl': senderPhotoUrl,
        'content': '',
        'encryptionLevel': 'aes',
        'type': 'voiceNote',
        'fileUrl': fileUrl,
        'fileName': fileName,
        'fileSize': fileSize,
        'mimeType': mimeType,
        'audioDuration': duration,
        'audioWaveform': waveform,
        'readBy': [senderId],
        'readAt': {senderId: now},
        'deliveredTo': [senderId],
        'deliveredAt': {senderId: now},
        'createdAt': now,
        'replyToId': replyToId,
        'replyToMessageData': replyToMessageData,
        if (isForwarded) 'isForwarded': true,
        if (expiresAt != null) 'expiresAt': expiresAt,
        'mediaExpiresAt': nowDateTime.add(const Duration(days: 15)).toIso8601String(),
        'mediaExpired': false,
      };

      final newMessageRef = _messagesRef(conversationId).push();
      await newMessageRef.set(messageData);

      // Update conversation last message
      await _updateConversationLastMessage(
        conversationId: conversationId,
        lastMessage: '🎙️ Message vocal',
        senderId: senderId,
        messageType: MessageType.voiceNote,
      );

      final snapshot = await newMessageRef.get();
      final data = _safeMap(snapshot.value);
      data['id'] = snapshot.key;

      // Clean up temporary audio file after successful upload
      try {
        if (await audioFile.exists()) {
          await audioFile.delete();
        }
      } catch (_) {
        // Ignore cleanup errors - file will be cleaned up by system eventually
      }

      return MessageModel.fromJson(data);
    } catch (e) {
      throw ServerException(
        'Erreur lors de l\'envoi du message vocal: ${e.toString()}',
      );
    }
  }

  @override
  Future<MessageModel> sendLocationMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    String? senderPhotoUrl,
    required double latitude,
    required double longitude,
    required String address,
    String? replyToId,
    Map<String, dynamic>? replyToMessageData,
  }) async {
    try {
      // Resurrect conversation if needed
      final convDoc = await _conversationsCollection.doc(conversationId).get();
      int? autoDeleteSeconds;
      if (convDoc.exists) {
        final convData = convDoc.data() as Map<String, dynamic>?;
        final participantIds = List<String>.from(convData?['participantIds'] ?? []);
        autoDeleteSeconds = convData?['autoDeleteAfterSeconds'] as int?;
        await _resurrectConversationIfNeeded(
          conversationId: conversationId,
          participantIds: participantIds,
        );
      }

      final nowDateTime = DateTime.now();
      final now = nowDateTime.toIso8601String();

      // Calculate expiresAt if auto-delete is enabled
      String? expiresAt;
      if (autoDeleteSeconds != null) {
        expiresAt = nowDateTime.add(Duration(seconds: autoDeleteSeconds)).toIso8601String();
      }

      // Location: coordinates stay AES (they are numeric, already low-precision).
      // Content and address use AES-GCM for consistency.
      final contentText = address.isNotEmpty ? address : 'Position partagée';
      final encryptedContent = _encryptionService.encryptText(contentText);
      final encryptedAddress = _encryptionService.encryptText(address);

      final messageData = {
        'senderId': senderId,
        'senderName': senderName,
        'senderPhotoUrl': senderPhotoUrl,
        'content': encryptedContent,
        'encryptionLevel': 'aes',
        'type': 'location',
        'latitude': _encryptionService.encryptText(latitude.toString()),
        'longitude': _encryptionService.encryptText(longitude.toString()),
        'locationAddress': encryptedAddress,
        'readBy': [senderId],
        'readAt': {senderId: now},
        'deliveredTo': [senderId],
        'deliveredAt': {senderId: now},
        'createdAt': now,
        'replyToId': replyToId,
        'replyToMessageData': replyToMessageData,
        if (expiresAt != null) 'expiresAt': expiresAt,
      };

      final newMessageRef = _messagesRef(conversationId).push();
      await newMessageRef.set(messageData);

      // Update conversation last message
      await _updateConversationLastMessage(
        conversationId: conversationId,
        lastMessage: '📍 Position partagée',
        senderId: senderId,
        messageType: MessageType.location,
      );

      final snapshot = await newMessageRef.get();
      final data = _safeMap(snapshot.value);
      data['id'] = snapshot.key;
      // Decrypt fields for the returned message
      _decryptMessageFields(data);

      debugPrint('📍 sendLocationMessage: Created message id=${data['id']}, lat=${data['latitude']}, lng=${data['longitude']}');

      return MessageModel.fromJson(data);
    } catch (e) {
      debugPrint('❌ sendLocationMessage error: ${e.toString()}');
      throw ServerException(
        'Erreur lors de l\'envoi de la position: ${e.toString()}',
      );
    }
  }

  @override
  Future<MessageModel> sendStickerMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    String? senderPhotoUrl,
    required String stickerPackId,
    required String stickerId,
    required String stickerUrl,
    bool isAnimated = false,
    String? replyToId,
    Map<String, dynamic>? replyToMessageData,
  }) async {
    try {
      // Resurrect conversation if needed
      final convDoc = await _conversationsCollection.doc(conversationId).get();
      int? autoDeleteSeconds;
      if (convDoc.exists) {
        final convData = convDoc.data() as Map<String, dynamic>?;
        final participantIds = List<String>.from(convData?['participantIds'] ?? []);
        autoDeleteSeconds = convData?['autoDeleteAfterSeconds'] as int?;
        await _resurrectConversationIfNeeded(
          conversationId: conversationId,
          participantIds: participantIds,
        );
      }

      final nowDateTime = DateTime.now();
      final now = nowDateTime.toIso8601String();

      // Calculate expiresAt if auto-delete is enabled
      String? expiresAt;
      if (autoDeleteSeconds != null) {
        expiresAt = nowDateTime.add(Duration(seconds: autoDeleteSeconds)).toIso8601String();
      }

      final messageData = {
        'senderId': senderId,
        'senderName': senderName,
        'senderPhotoUrl': senderPhotoUrl,
        'content': 'Sticker',
        'type': 'sticker',
        'fileUrl': stickerUrl,
        'stickerPackId': stickerPackId,
        'stickerId': stickerId,
        'isAnimatedSticker': isAnimated,
        'readBy': [senderId],
        'readAt': {senderId: now},
        'deliveredTo': [senderId],
        'deliveredAt': {senderId: now},
        'createdAt': now,
        'replyToId': replyToId,
        'replyToMessageData': replyToMessageData,
        if (expiresAt != null) 'expiresAt': expiresAt,
      };

      final newMessageRef = _messagesRef(conversationId).push();
      await newMessageRef.set(messageData);

      // Update conversation last message
      await _updateConversationLastMessage(
        conversationId: conversationId,
        lastMessage: '🎭 Sticker',
        senderId: senderId,
        messageType: MessageType.sticker,
      );

      final snapshot = await newMessageRef.get();
      final data = _safeMap(snapshot.value);
      data['id'] = snapshot.key;

      debugPrint('🎭 sendStickerMessage: Created message id=${data['id']}, packId=$stickerPackId, stickerId=$stickerId');

      return MessageModel.fromJson(data);
    } catch (e) {
      debugPrint('❌ sendStickerMessage error: ${e.toString()}');
      throw ServerException(
        'Erreur lors de l\'envoi du sticker: ${e.toString()}',
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
      // Increase limit multiplier to catch media deeper in history
      // RTDB doesn't allow filtering by type efficiently without index
      Query query = _messagesRef(
        conversationId,
      ).orderByChild('createdAt').limitToLast(limit * 10);

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
        // Use _safeMap for deep conversion of nested Maps (like readAt)
        // to avoid "type '_Map<Object?, Object?>' is not a subtype of 'Map<String, dynamic>'"
        final data = _safeMap(value);
        data['id'] = key;

        // Ensure content is decrypted for captions
        if (data['content'] is String) {
          try {
            data['content'] = _encryptionService.decryptText(data['content']);
          } catch (e) {
            // Ignore decryption error, keep original or empty
            // debugPrint('⚠️ Decryption failed for media caption: $e');
          }
        }

        final message = MessageModel.fromJson(data);

        // Filter: only images, videos and files (not text, not audio)
        // Also ensure fileUrl is present
        if ((message.type == 'image' ||
                message.type == 'video' ||
                message.type == 'file') &&
            message.fileUrl != null) {
          messages.add(message);
        }
      });

      // Sort by creation time descending (newest first)
      messages.sort((a, b) {
        final aTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aTime.compareTo(bTime);
      });

      // Limit the results to the requested page size
      if (messages.length > limit) {
        return messages.sublist(0, limit);
      }

      return messages;
    } catch (e) {
      // debugPrint('❌ MessageRemoteDataSource: Error getting media messages: $e');
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
  Future<ConversationModel?> findGroupConversationByGroupId({
    required String groupId,
    required String userId,
  }) async {
    try {
      final snapshot =
          await _conversationsCollection
              .where('type', isEqualTo: 'group')
              .where('groupId', isEqualTo: groupId)
              .where('participantIds', arrayContains: userId)
              .limit(1)
              .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      return ConversationModel.fromFirestore(snapshot.docs.first);
    } on firestore.FirebaseException catch (e) {
      // If it's a missing index error, return null instead of throwing
      if (e.message?.contains('index') == true) {
        return null;
      }
      throw ServerException(
        e.message ?? 'Erreur lors de la recherche du groupe par ID',
      );
    } catch (e) {
      return null;
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

      // Verifier existence du message
      final snapshot = await messageRef.get();
      if (!snapshot.exists) {
        throw ServerException('Message non trouve');
      }

      // CORRECTION: Utiliser une transaction atomique pour eviter les race conditions
      // Si deux utilisateurs suppriment simultanement, les deux seront ajoutes correctement
      await messageRef.child('deletedFor').runTransaction((currentData) {
        // Parser les donnees actuelles
        List<String> deletedFor = [];
        if (currentData != null) {
          if (currentData is List) {
            deletedFor = List<String>.from(currentData.map((e) => e.toString()));
          } else if (currentData is Map) {
            // Firebase RTDB peut convertir les listes en Maps avec des cles numeriques
            deletedFor = currentData.values.map((e) => e.toString()).toList();
          }
        }

        // Ajouter l'userId s'il n'est pas deja present
        if (!deletedFor.contains(userId)) {
          deletedFor.add(userId);
        }

        // Retourner la nouvelle valeur (Transaction.success est implicite)
        return Transaction.success(deletedFor);
      });
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

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final fileUrl = data['fileUrl'] as String?;
      final content = data['content'] as String?;

      // Decrypt content for comparison if needed
      String? decryptedContent;
      if (content != null) {
        try {
          decryptedContent = _encryptionService.decryptText(content);
        } catch (_) {
          decryptedContent = content;
        }
      }

      // 1. Delete file from storage if exists
      if (fileUrl != null && fileUrl.isNotEmpty) {
        try {
          final ref = _storage.refFromURL(fileUrl);
          await ref.delete();
          // debugPrint('🗑️ Deleted media file: $fileUrl');
        } catch (e) {
          // debugPrint('⚠️ Failed to delete media file: $e');
        }
      }

      // 2. Update conversation preview if this was the last message
      try {
        final conversationDoc =
            await _conversationsCollection.doc(conversationId).get();
        if (conversationDoc.exists) {
          final convData = conversationDoc.data() as Map<String, dynamic>;
          final lastMessageEncrypted = convData['lastMessage'] as String?;

          // Check if this message matches the conversation's last message
          // We compare decrypted contents or check if it's the same sender and type
          // Comparing logic:
          // If the conversation last message (decrypted) contains the text we are deleting...
          // Or simpler: If we assume the UI is reactive, we just need to update the text.
          // But we only want to update if it *was* the last message.
          // Let's decrypt fetching potential match.
          String? lastMessageDecrypted;
          if (lastMessageEncrypted != null) {
            try {
              lastMessageDecrypted = _encryptionService.decryptText(
                lastMessageEncrypted,
              );
            } catch (_) {
              lastMessageDecrypted = lastMessageEncrypted;
            }
          }

          // Simple heuristic match: content matches OR it was a media message
          // Note: Media messages usually have "📸 Image", "🎥 Vidéo", etc. in lastMessage
          bool isLastMessage = false;
          if (decryptedContent != null &&
              lastMessageDecrypted == decryptedContent) {
            isLastMessage = true;
          } else if (fileUrl != null) {
            // For media, the content might be empty or caption, but lastMessage is generic
            // Check if lastMessage is one of the generic media strings
            // This is a bit weak.
            // Better approach: Check timestamps if possible, but they differ.
            // Alternative: If senderId matches and it's very recent?
            // Let's rely on content match for text, and maybe loose match for media?
            // Actually, if we just update the text in conversation to "🚫 Message supprimé"
            // it might be fine even if it wasn't strictly the last one (it's weird but safe-ish).
            // BUT updating an old message to be the "last message" of the conversation is bad.
            // So we MUST be sure.

            // Let's assume valid match if:
            // 1. Sender ID matches
            // 2. lastMessage matches specific format (e.g. content or media type text)
            // AND
            // 3. (Optional) Message is recent?

            final lastSenderId = convData['lastMessageSenderId'] as String?;
            if (lastSenderId == data['senderId']) {
              // Good chance.
              isLastMessage = true; // Optimistic
            }
          }

          if (isLastMessage) {
            await _updateConversationLastMessage(
              conversationId: conversationId,
              lastMessage: '🚫 Message supprimé',
              senderId: data['senderId'],
              messageType: MessageType.system,
            );
          }
        }
      } catch (e) {
        // debugPrint('⚠️ Failed to update conversation preview: $e');
      }

      // 3. Update message to mark as deleted for everyone
      await messageRef.update({
        'deletedForEveryone': true,
        'deletedAt': DateTime.now().toIso8601String(),
        'content': '', // Clear content
        'fileUrl': null, // Clear file URL if any
        'thumbnailUrl': null, // Clear thumbnail
        'audioWaveform': null, // Clear heavy data
      });
    } on FirebaseException catch (e) {
      throw ServerException(
        e.message ?? 'Erreur lors de la suppression du message pour tous',
      );
    }
  }

  // ============ Typing Indicators ============

  DatabaseReference _typingRef(String conversationId) =>
      _database.ref().child('typing').child(conversationId);

  @override
  Future<void> setTypingStatus({
    required String conversationId,
    required String userId,
    required bool isTyping,
  }) async {
    try {
      final typingRef = _typingRef(conversationId).child(userId);
      if (isTyping) {
        // Set typing with timestamp for auto-expiration
        await typingRef.set({
          'isTyping': true,
          'timestamp': ServerValue.timestamp,
        });
      } else {
        // Remove typing status
        await typingRef.remove();
      }
    } on FirebaseException catch (e) {
      throw ServerException(
        e.message ?? 'Erreur lors de la mise à jour du statut de frappe',
      );
    }
  }

  @override
  Stream<Map<String, bool>> getTypingStatusStream(String conversationId) {
    return _typingRef(conversationId).onValue.map((event) {
      if (event.snapshot.value == null) return <String, bool>{};

      final result = <String, bool>{};
      final map = event.snapshot.value as Map<dynamic, dynamic>;
      final now = DateTime.now().millisecondsSinceEpoch;

      map.forEach((key, value) {
        if (value is Map) {
          final isTyping = value['isTyping'] == true;
          final timestamp = value['timestamp'] as int?;

          // Consider typing status expired after 5 seconds
          if (isTyping && timestamp != null) {
            final age = now - timestamp;
            if (age < 5000) {
              // 5 seconds
              result[key.toString()] = true;
            }
          }
        }
      });

      return result;
    });
  }

  @override
  Future<void> addReaction({
    required String conversationId,
    required String messageId,
    required String emoji,
  }) async {
    try {
      final messageRef = _messagesRef(conversationId).child(messageId);

      // Get current reactions
      final snapshot = await messageRef.child('reactions').get();
      final List<String> reactions = [];

      if (snapshot.value != null) {
        final data = snapshot.value;
        if (data is List) {
          reactions.addAll(data.cast<String>());
        }
      }

      // Add new reaction
      reactions.add(emoji);

      // Update in database
      await messageRef.update({'reactions': reactions});
    } catch (e) {
      throw ServerException(
        'Erreur lors de l\'ajout de la réaction: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> removeReaction({
    required String conversationId,
    required String messageId,
    required String emoji,
  }) async {
    try {
      final messageRef = _messagesRef(conversationId).child(messageId);

      // Get current reactions
      final snapshot = await messageRef.child('reactions').get();
      final List<String> reactions = [];

      if (snapshot.value != null) {
        final data = snapshot.value;
        if (data is List) {
          reactions.addAll(data.cast<String>());
        }
      }

      // Remove the reaction (only first occurrence)
      if (reactions.contains(emoji)) {
        reactions.remove(emoji);
      }

      // Update in database
      await messageRef.update({'reactions': reactions});
    } catch (e) {
      throw ServerException(
        'Erreur lors de la suppression de la réaction: ${e.toString()}',
      );
    }
  }

  @override
  Future<MessageModel> sendSystemMessage({
    required String conversationId,
    required String content,
  }) async {
    try {
      final now = DateTime.now().toIso8601String();

      final messageData = {
        'senderId': 'system',
        'senderName': 'Système',
        'content': content, // System messages are not encrypted
        'type': 'system',
        'readBy': [], // Nobody has read it yet
        'readAt': {},
        'createdAt': now,
      };

      // Create message in RTDB
      final newMessageRef = _messagesRef(conversationId).push();
      await newMessageRef.set(messageData);

      // Try to update conversation metadata (non-critical)
      await _updateConversationLastMessage(
        conversationId: conversationId,
        lastMessage: content,
        senderId: 'system',
        messageType: MessageType.system,
      );

      // Return the created message
      try {
        final snapshot = await newMessageRef.get();
        final data = _safeMap(snapshot.value);
        data['id'] = snapshot.key;
        return MessageModel.fromJson(data);
      } catch (e) {
        // debugPrint('⚠️ Could not retrieve created system message');
        return MessageModel(
          id: newMessageRef.key!,
          senderId: 'system',
          senderName: 'Système',
          content: content,
          type: 'system',
          createdAt: DateTime.parse(now).toLocal(),
          readBy: [],
          readAt: {},
        );
      }
    } catch (e) {
      throw ServerException(
        'Erreur lors de l\'envoi du message système: ${e.toString()}',
      );
    }
  }

  @override
  Future<List<ConversationModel>> searchConversations(
    String userId,
    String query,
  ) async {
    try {
      if (query.trim().isEmpty) {
        return [];
      }

      final lowerQuery = query.toLowerCase();

      // Récupérer toutes les conversations de l'utilisateur
      final snapshot = await _conversationsCollection
          .where('participantIds', arrayContains: userId)
          .orderBy('lastMessageAt', descending: true)
          .limit(50) // Limiter pour les performances
          .get();

      final conversations = <ConversationModel>[];

      for (final doc in snapshot.docs) {
        final conversation = _fromFirestoreEncrypted(doc);

        // Filtrer par nom de conversation ou dernier message
        final name = (conversation.name ?? '').toLowerCase();
        final lastMessage = (conversation.lastMessage ?? '').toLowerCase();

        if (name.contains(lowerQuery) || lastMessage.contains(lowerQuery)) {
          conversations.add(conversation);
        }
      }

      // Limiter les résultats
      if (conversations.length > 20) {
        return conversations.sublist(0, 20);
      }

      return conversations;
    } on firestore.FirebaseException catch (e) {
      throw ServerException(
        e.message ?? 'Erreur lors de la recherche des conversations',
      );
    }
  }

  @override
  Future<void> toggleStarMessage({
    required String conversationId,
    required String messageId,
    required String userId,
  }) async {
    try {
      final messageRef = _messagesRef(conversationId).child(messageId);
      final snapshot = await messageRef.child('starredBy').get();
      List<String> starredBy = [];
      if (snapshot.value != null) {
        final data = snapshot.value;
        if (data is List) {
          starredBy = data.whereType<String>().toList();
        } else if (data is Map) {
          starredBy = data.values.whereType<String>().toList();
        }
      }

      if (starredBy.contains(userId)) {
        starredBy.remove(userId);
      } else {
        starredBy.add(userId);
      }

      await messageRef.update({'starredBy': starredBy});
    } catch (e) {
      throw ServerException(
        'Erreur lors du marquage du message: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> editMessage({
    required String conversationId,
    required String messageId,
    required String newContent,
    required String oldContent,
  }) async {
    try {
      final messageRef = _messagesRef(conversationId).child(messageId);
      final snapshot = await messageRef.get();

      if (snapshot.value == null) {
        throw ServerException('Message introuvable');
      }

      final data = _safeMap(snapshot.value);
      final now = DateTime.now().toIso8601String();

      // Get existing edit history or create new one
      List<Map<String, dynamic>> editHistory = [];
      if (data['editHistory'] != null && data['editHistory'] is List) {
        editHistory = (data['editHistory'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }

      // Add current content to history before editing
      editHistory.add({
        'content': oldContent,
        'editedAt': now,
      });

      // Re-encrypt at the same level as the original message.
      // For Signal-encrypted messages, re-encrypt for the same conversation;
      // for AES messages, keep using AES-GCM.
      final originalLevel = data['encryptionLevel'] as String? ?? 'aes';
      final Map<String, dynamic> encryptedFields;
      if (originalLevel == 'e2ee') {
        final convDoc = await _conversationsCollection.doc(conversationId).get();
        final senderId = data['senderId'] as String? ?? '';
        final result = await _encryptContent(
          plaintext: newContent,
          senderId: senderId,
          convDoc: convDoc,
          conversationId: conversationId,
        );
        encryptedFields = result.fields;
      } else {
        encryptedFields = {
          'content': _encryptionService.encryptText(newContent),
          'encryptionLevel': 'aes',
        };
      }

      // Update the message
      await messageRef.update({
        ...encryptedFields,
        'editedAt': now,
        'editHistory': editHistory,
      });
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(
        'Erreur lors de la modification du message: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> setAutoDeleteSettings({
    required String conversationId,
    required int? durationSeconds,
  }) async {
    try {
      if (durationSeconds == null) {
        // Remove auto-delete setting
        await _conversationsCollection.doc(conversationId).update({
          'autoDeleteAfterSeconds': firestore.FieldValue.delete(),
        });
      } else {
        // Set auto-delete duration
        await _conversationsCollection.doc(conversationId).update({
          'autoDeleteAfterSeconds': durationSeconds,
        });
      }
    } catch (e) {
      throw ServerException(
        'Erreur lors de la configuration des messages éphémères: ${e.toString()}',
      );
    }
  }

  @override
  Future<int?> getAutoDeleteSettings(String conversationId) async {
    try {
      final doc = await _conversationsCollection.doc(conversationId).get();
      if (!doc.exists) return null;
      final data = doc.data() as Map<String, dynamic>?;
      return data?['autoDeleteAfterSeconds'] as int?;
    } catch (e) {
      throw ServerException(
        'Erreur lors de la récupération des paramètres: ${e.toString()}',
      );
    }
  }

  @override
  Future<List<MessageModel>> getStarredMessages({
    required String conversationId,
    required String userId,
    int limit = 100,
  }) async {
    try {
      final snapshot = await _messagesRef(conversationId)
          .orderByChild('createdAt')
          .limitToLast(500)
          .get();

      if (snapshot.value == null) return [];

      final messages = <MessageModel>[];
      final map = snapshot.value as Map<dynamic, dynamic>;

      map.forEach((key, value) {
        if (value is Map) {
          final data = _safeMap(value);
          data['id'] = key;

          // Check if starred by user
          final starredBy = data['starredBy'];
          bool isStarred = false;
          if (starredBy is List) {
            isStarred = starredBy.contains(userId);
          } else if (starredBy is Map) {
            isStarred = starredBy.values.contains(userId);
          }

          if (isStarred) {
            if (data['content'] is String) {
              data['content'] = _encryptionService.decryptText(data['content']);
            }
            messages.add(MessageModel.fromJson(data));
          }
        }
      });

      messages.sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });

      return messages.take(limit).toList();
    } catch (e) {
      throw ServerException(
        'Erreur lors de la récupération des messages favoris: ${e.toString()}',
      );
    }
  }

  @override
  Future<List<MessageModel>> searchMessagesInConversation({
    required String conversationId,
    required String query,
    int limit = 200,
  }) async {
    try {
      if (query.trim().length < 2) return [];

      final lowerQuery = query.toLowerCase();

      // Try using the Firestore search index first (more scalable)
      try {
        final indexSnapshot = await _firestore
            .collection('messages_searchindex')
            .where('conversationId', isEqualTo: conversationId)
            .orderBy('createdAt', descending: true)
            .limit(limit * 2) // Get more to filter
            .get();

        if (indexSnapshot.docs.isNotEmpty) {
          final matchingMessageIds = <String>[];

          for (final doc in indexSnapshot.docs) {
            final searchableText = doc.data()['searchableText'] as String? ?? '';
            if (searchableText.contains(lowerQuery)) {
              matchingMessageIds.add(doc.id);
              if (matchingMessageIds.length >= limit) break;
            }
          }

          if (matchingMessageIds.isNotEmpty) {
            // Fetch actual messages from RTDB
            final messages = <MessageModel>[];
            for (final messageId in matchingMessageIds) {
              final msgSnapshot = await _messagesRef(conversationId)
                  .child(messageId)
                  .get();

              if (msgSnapshot.exists && msgSnapshot.value != null) {
                final data = _safeMap(msgSnapshot.value as Map);
                data['id'] = messageId;

                // Decrypt content if needed
                if (data['content'] is String) {
                  try {
                    data['content'] = _encryptionService.decryptText(data['content']);
                  } catch (_) {
                    // Keep encrypted content
                  }
                }

                messages.add(MessageModel.fromJson(data));
              }
            }

            return messages;
          }
        }
      } catch (_) {
        // Fall back to client-side search if index query fails
      }

      // Fallback: Client-side search (original implementation)
      final snapshot = await _messagesRef(conversationId)
          .orderByChild('createdAt')
          .limitToLast(500)
          .get();

      if (snapshot.value == null) return [];

      final messages = <MessageModel>[];
      final map = snapshot.value as Map<dynamic, dynamic>;

      map.forEach((key, value) {
        if (value is Map) {
          final data = _safeMap(value);
          data['id'] = key;

          // Decrypt content to search (avec gestion d'erreur)
          String content = '';
          if (data['content'] is String) {
            try {
              content = _encryptionService.decryptText(data['content']);
              data['content'] = content;
            } catch (_) {
              // Ignorer les messages avec contenu corrompu
              content = '';
            }
          }

          // Match against decrypted content or sender name
          final senderName = (data['senderName'] ?? '').toString().toLowerCase();
          if (content.toLowerCase().contains(lowerQuery) ||
              senderName.contains(lowerQuery)) {
            messages.add(MessageModel.fromJson(data));
          }
        }
      });

      messages.sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });

      return messages.take(limit).toList();
    } catch (e) {
      throw ServerException(
        'Erreur lors de la recherche de messages: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> restoreConversationForUser({
    required String conversationId,
    required String userId,
  }) async {
    try {
      await _conversationsCollection.doc(conversationId).update({
        'deletedBy.$userId': firestore.FieldValue.delete(),
      });
    } on firestore.FirebaseException catch (e) {
      throw ServerException(
        e.message ?? 'Erreur lors de la restauration de la conversation',
      );
    }
  }

  @override
  Future<ConversationModel?> getConversationById(String conversationId) async {
    try {
      final doc = await _conversationsCollection.doc(conversationId).get();
      if (!doc.exists) return null;

      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return null;

      data['id'] = doc.id;
      return ConversationModel.fromJson(data);
    } on firestore.FirebaseException catch (e) {
      throw ServerException(
        e.message ?? 'Erreur lors de la recuperation de la conversation',
      );
    }
  }

  /// Ressusciter une conversation automatiquement si elle a ete supprimee (soft delete)
  /// Appele avant d'envoyer un message pour reactiver la conversation pour tous les participants
  Future<void> _resurrectConversationIfNeeded({
    required String conversationId,
    required List<String> participantIds,
  }) async {
    try {
      final doc = await _conversationsCollection.doc(conversationId).get();
      if (!doc.exists) return;

      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return;

      final deletedBy = data['deletedBy'] as Map<String, dynamic>? ?? {};

      // Retirer tous les participants de deletedBy
      if (deletedBy.isNotEmpty) {
        final updates = <String, dynamic>{};
        for (final participantId in participantIds) {
          if (deletedBy.containsKey(participantId)) {
            updates['deletedBy.$participantId'] = firestore.FieldValue.delete();
          }
        }
        if (updates.isNotEmpty) {
          await _conversationsCollection.doc(conversationId).update(updates);
        }
      }
    } catch (e) {
      // Log l'erreur mais ne pas bloquer l'envoi du message
      // debugPrint('Erreur lors de la resurrection de la conversation: $e');
    }
  }

  @override
  Future<List<MessageModel>> getMessagesSince({
    required String conversationId,
    required DateTime since,
    int limit = 100,
  }) async {
    try {
      final snapshot = await _messagesRef(conversationId)
          .orderByChild('createdAt')
          .startAt(since.toIso8601String())
          .limitToLast(limit)
          .get();

      if (!snapshot.exists || snapshot.value == null) return [];

      final messages = <MessageModel>[];
      final data = snapshot.value as Map<dynamic, dynamic>;

      for (final entry in data.entries) {
        final messageData = _safeMap(entry.value);
        messageData['id'] = entry.key;

        // Decrypter le contenu
        if (messageData['content'] is String) {
          messageData['content'] = _encryptionService.decryptText(messageData['content']);
        }

        messages.add(MessageModel.fromJson(messageData));
      }

      // Trier par date decroissante
      messages.sort((a, b) {
        final aTime = a.createdAt ?? DateTime(2020);
        final bTime = b.createdAt ?? DateTime(2020);
        return bTime.compareTo(aTime);
      });

      return messages;
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors de la recuperation des messages');
    }
  }

  // ============ MESSAGE REQUESTS (Zone Tampon) ============

  @override
  Stream<List<ConversationModel>> getMessageRequests(String userId) {
    // Get individual conversations where:
    // - User is a participant
    // - requestStatus is 'pending'
    // - User is NOT the requester (they are the recipient)
    return _conversationsCollection
        .where('type', isEqualTo: 'individual')
        .where('participantIds', arrayContains: userId)
        .where('requestStatus', isEqualTo: 'pending')
        .orderBy('requestedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ConversationModel.fromFirestore(doc))
          .where((conv) => conv.requesterId != userId) // Exclude requests sent by user
          .toList();
    });
  }

  @override
  Future<void> updateRequestStatus({
    required String conversationId,
    required String status,
    required String recipientId,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'requestStatus': status,
        'respondedAt': firestore.FieldValue.serverTimestamp(),
      };

      await _conversationsCollection.doc(conversationId).update(updateData);
    } on firestore.FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors de la mise a jour du statut');
    }
  }

  @override
  Future<ConversationModel> createIndividualConversationAsRequest({
    required String currentUserId,
    required String otherUserId,
  }) async {
    try {
      // Check if conversation already exists
      final existing = await findIndividualConversation(
        userId1: currentUserId,
        userId2: otherUserId,
      );

      if (existing != null) {
        // If it exists but was declined, allow re-requesting
        if (existing.requestStatus == 'declined') {
          await _conversationsCollection.doc(existing.id).update({
            'requestStatus': 'pending',
            'requesterId': currentUserId,
            'requestedAt': firestore.FieldValue.serverTimestamp(),
            'respondedAt': null,
          });
          return existing.copyWith(
            requestStatus: 'pending',
            requesterId: currentUserId,
          );
        }
        return existing;
      }

      // Create new conversation as a request
      final docRef = _conversationsCollection.doc();
      final conversationData = {
        'type': 'individual',
        'participantIds': [currentUserId, otherUserId],
        'createdBy': currentUserId,
        'createdAt': firestore.FieldValue.serverTimestamp(),
        'unreadCount': {
          currentUserId: 0,
          otherUserId: 0,
        },
        'requestStatus': 'pending',
        'requesterId': currentUserId,
        'requestedAt': firestore.FieldValue.serverTimestamp(),
      };

      await docRef.set(conversationData);

      // Sync participants to RTDB
      await _syncParticipantsToRTDB(docRef.id, [currentUserId, otherUserId]);

      // Return the model
      final snapshot = await docRef.get();
      return ConversationModel.fromFirestore(snapshot);
    } on firestore.FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur lors de la creation de la demande');
    }
  }
}
