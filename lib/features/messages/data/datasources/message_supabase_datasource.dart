import 'dart:async';
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../core/services/e2ee/message_crypto_service.dart';
import '../../../../core/services/supabase_auth_bridge.dart';

import '../models/conversation_model.dart';
import '../models/message_model.dart';
import 'message_remote_datasource.dart';

/// Supabase implementation of [MessageRemoteDataSource].
///
/// Uses a NoSQL-like schema where minimal typed columns are indexed (id,
/// participant_ids, sender_id, type, created_at) and all other payload lives
/// in a JSONB `data` column. This lets us reuse [ConversationModel.fromJson]
/// and [MessageModel.fromJson] directly with minor key remapping.
class MessageSupabaseDataSource implements MessageRemoteDataSource {
  MessageSupabaseDataSource({SupabaseClient? client, MessageCryptoService? cryptoService})
      : _supabase = client ?? Supabase.instance.client,
        _crypto = cryptoService;

  final SupabaseClient _supabase;
  final MessageCryptoService? _crypto;
  static const _uuid = Uuid();

  // ── Channel registry ─────────────────────────────────────────────────────

  /// Active realtime channels keyed by channel name so we can re-use them
  /// and avoid leaking subscriptions.
  final Map<String, RealtimeChannel> _channels = {};

  RealtimeChannel _channel(String name) {
    return _channels.putIfAbsent(name, () => _supabase.channel(name));
  }

  // ── Row → Model helpers ───────────────────────────────────────────────────

  /// Convert a `conversations` row to a [ConversationModel].
  ///
  /// The row has typed columns (id, type, participant_ids, group_id,
  /// last_message_at, created_at, created_by) plus a JSONB `data` column
  /// that holds everything else. We merge them so [ConversationModel.fromJson]
  /// sees a single flat map.
  ConversationModel _convFromRow(Map<String, dynamic> row) {
    final data = Map<String, dynamic>.from(
      (row['data'] as Map<String, dynamic>?) ?? {},
    );
    return ConversationModel.fromJson({
      ...data,
      'id': row['id'],
      'type': row['type'],
      'participantIds': row['participant_ids'],
      'groupId': row['group_id'],
      'lastMessageAt': row['last_message_at'],
      'createdAt': row['created_at'],
      'createdBy': row['created_by'] ?? '',
    });
  }

  /// Union du `read_by`/`delivered_to` top-level (colonne mise à jour par le
  /// RPC mark_messages_as_read) et de ceux du JSONB `data` (écrits à l'envoi).
  /// Sans cette union, si le backend écrit le « lu » dans la colonne top-level,
  /// la bulle (qui lisait seulement `data`) ne passait jamais au bleu.
  Map<String, dynamic> _mergedReceipts(
    Map<String, dynamic> row,
    Map<String, dynamic> data,
  ) {
    List<String> uni(dynamic a, dynamic b) => {
          ...((a as List?)?.map((e) => e.toString()) ?? const <String>[]),
          ...((b as List?)?.map((e) => e.toString()) ?? const <String>[]),
        }.toList();
    return {
      'readBy': uni(row['read_by'], data['readBy']),
      'deliveredTo': uni(row['delivered_to'], data['deliveredTo']),
    };
  }

  /// Convert a `messages` row to a [MessageModel] (sync, no decryption).
  MessageModel _msgFromRow(Map<String, dynamic> row) {
    final data = Map<String, dynamic>.from(
      (row['data'] as Map<String, dynamic>?) ?? {},
    );
    return MessageModel.fromJson({
      ...data,
      ..._mergedReceipts(row, data),
      'id': row['id'],
      'senderId': row['sender_id'],
      'type': row['type'],
      'createdAt': row['created_at'],
      'deletedForEveryone': row['is_deleted'] ?? false,
    });
  }

  /// Async variant that decrypts E2EE content before building the model.
  Future<MessageModel> _msgFromRowAsync(Map<String, dynamic> row) async {
    final data = Map<String, dynamic>.from(
      (row['data'] as Map<String, dynamic>?) ?? {},
    );

    // Always decrypt when crypto is available — handles all 3 formats:
    //   'e2ee' → Signal (e2eePayloads / senderKeyPayload)
    //   'aes'  → AES-GCM ('gcm:…') or legacy plaintext (returned as-is)
    if (_crypto != null) {
      try {
        final senderId = (row['sender_id'] as String?) ?? '';
        data['content'] = await _crypto.decrypt(
          payload: data,
          senderId: senderId,
        );
      } catch (e) {
        debugPrint('MessageSupabaseDataSource: decrypt error: $e');
        if (data['encryptionLevel'] == 'e2ee') {
          data['content'] = '🔐 Message chiffré';
        }
      }
    }

    return MessageModel.fromJson({
      ...data,
      ..._mergedReceipts(row, data),
      'id': row['id'],
      'senderId': row['sender_id'],
      'type': row['type'],
      'createdAt': row['created_at'],
      'deletedForEveryone': row['is_deleted'] ?? false,
    });
  }

  /// Encrypt plaintext using Signal Protocol (E2EE mandatory — no AES fallback).
  ///
  /// Guards (checked in order, each throws [ServerException] with a specific
  /// user-visible message on failure):
  ///  1. Crypto service present
  ///  2. E2EE service initialized for the current user
  ///  3. Recipient / group target provided
  ///  4. [1:1 only] Recipient has published pre-keys on Firebase
  ///  5. [1:1 only] Session established locally (fast path if already exists)
  ///  6. Result is actually E2EE — not AES fallback
  Future<Map<String, dynamic>> _encryptContent({
    required String plaintext,
    String? recipientId,
    List<String> participantIds = const [],
    required String conversationId,
    bool selfNote = false,
  }) async {
    if (_crypto == null) {
      throw E2EEException('Service de chiffrement non initialisé.');
    }

    // « Mes notes » : self-chat, donc aucun destinataire par construction — et
    // aucune session Signal possible avec soi-même. On court-circuite AVANT les
    // deux gardes ci-dessous : ni l'initialisation E2EE ni la présence d'un
    // destinataire ne sont pertinentes ici. Chiffrement au repos, clé AES
    // globale — le même repli que les aperçus, la localisation et les médias.
    if (selfNote) {
      final selfResult = _crypto.encryptSelfNote(plaintext);
      unawaited(
        AnalyticsService.instance.logMessageEncryption(
          level: selfResult.encryptionLevel,
          scope: 'self',
          fallbackReason: null,
        ),
      );
      return selfResult.fields;
    }

    if (!_crypto.isE2EEInitialized) {
      throw E2EEException(
        'Chiffrement E2EE non disponible. Reconnectez-vous et réessayez.',
      );
    }

    if (recipientId == null && participantIds.isEmpty) {
      throw E2EEException('Destinataire manquant — chiffrement impossible.');
    }

    try {
      final CryptoResult result;
      bool recipientHadKeys = false;

      if (recipientId != null) {
        // On tente d'établir une session Signal seulement si le destinataire a
        // publié ses pré-clés. Sinon (jamais activé E2EE), on n'attend pas :
        // encrypt1to1() retombe automatiquement sur AES (clé globale), le
        // repli prévu par l'architecture — le message part quand même.
        recipientHadKeys = await _crypto.recipientHasKeys(recipientId);
        if (recipientHadKeys) {
          // Fast path: if a local session already exists, skip X3DH entirely.
          final sessionExists = await _crypto.hasSessionFor(recipientId);
          if (!sessionExists) {
            // No local session — run X3DH with a 10 s safety timeout.
            try {
              await _crypto
                  .preEstablishSessions([recipientId])
                  .timeout(const Duration(seconds: 10));
            } on TimeoutException {
              debugPrint('MessageSupabaseDataSource: Signal session setup timed out');
            }
          }
        }

        result = await _crypto.encrypt1to1(
          plaintext: plaintext,
          recipientId: recipientId,
        );
      } else {
        // Groups: distribute Sender Key to all members before encrypting.
        try {
          await _crypto
              .distributeGroupSenderKey(
                groupId: conversationId,
                memberIds: participantIds,
              )
              .timeout(const Duration(seconds: 10));
        } on TimeoutException {
          debugPrint('MessageSupabaseDataSource: Sender Key setup timed out');
        }
        result = await _crypto.encryptGroup(plaintext, groupId: conversationId);
      }

      // Instrumentation continue du taux de repli AES (fire-and-forget, non
      // bloquant). Ne jamais laisser l'analytics impacter l'envoi.
      final isDirect = recipientId != null;
      String? fallbackReason;
      if (result.encryptionLevel == 'aes') {
        fallbackReason = isDirect
            ? (recipientHadKeys ? 'session_failed' : 'recipient_no_keys')
            : 'sender_key_failed';
      }
      unawaited(
        AnalyticsService.instance.logMessageEncryption(
          level: result.encryptionLevel,
          scope: isDirect ? 'direct' : 'group',
          fallbackReason: fallbackReason,
        ),
      );

      // On accepte le résultat quel que soit son niveau : 'e2ee' si une session
      // Signal a pu être établie, 'aes' (repli clé globale) sinon. Ne jamais
      // bloquer l'envoi ici — le repli AES est le comportement prévu.
      return result.fields;
    } on E2EEException {
      rethrow;
    } on ServerException {
      rethrow;
    } catch (e) {
      throw E2EEException('Erreur de chiffrement : $e');
    }
  }

  // ── Conversation last-message helper ─────────────────────────────────────

  /// Fetch, merge, and update the `data` JSONB of a conversation row.
  Future<void> _updateConversationLastMessage(
    String convId, {
    required String? text,
    required String senderId,
    required String type,
    required String at,
  }) async {
    try {
      // 1. Fetch current data JSONB
      final rows = await _supabase
          .from('conversations')
          .select('data, participant_ids')
          .eq('id', convId)
          .limit(1);

      if (rows.isEmpty) return;

      final current = Map<String, dynamic>.from(
        (rows.first['data'] as Map<String, dynamic>?) ?? {},
      );
      final participantIds =
          List<String>.from(rows.first['participant_ids'] as List? ?? []);

      // 2. Increment unread counts for everyone except the sender
      final unreadCount =
          Map<String, dynamic>.from(current['unreadCount'] as Map? ?? {});
      for (final pid in participantIds) {
        if (pid != senderId) {
          final cur = (unreadCount[pid] as int?) ?? 0;
          unreadCount[pid] = cur + 1;
        }
      }

      // 3. Merge update — reset lastMessageReadBy to sender only
      final updated = {
        ...current,
        if (text != null) 'lastMessage': text,
        'lastMessageSenderId': senderId,
        'lastMessageType': type,
        'lastMessageStatus': 'sent',
        'unreadCount': unreadCount,
        'lastMessageReadBy': [senderId],
        'lastMessageDeliveredTo': [senderId],
      };

      await _supabase.from('conversations').update({
        'last_message_at': at,
        'data': updated,
      }).eq('id', convId);
    } catch (e) {
      // Non-critical: message is already persisted
      debugPrint('MessageSupabaseDataSource: _updateConversationLastMessage error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STREAMS
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Stream<List<ConversationModel>> getConversations(String userId) {
    final controller = StreamController<List<ConversationModel>>.broadcast();

    Future<void> fetch() async {
      try {
        final rows = await _supabase
            .from('conversations')
            .select()
            .contains('participant_ids', [userId])
            .order('last_message_at', ascending: false);
        if (!controller.isClosed) {
          controller.add(rows.map(_convFromRow).toList());
        }
      } catch (e) {
        if (!controller.isClosed) {
          controller.addError(ServerException('getConversations error: $e'));
        }
      }
    }

    // Initial load
    fetch();

    // Real-time updates
    final ch = _channel('conversations:$userId');
    ch
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'conversations',
          callback: (_) => fetch(),
        )
        .subscribe();

    controller.onCancel = () {
      ch.unsubscribe();
      _channels.remove('conversations:$userId');
    };

    return controller.stream;
  }

  @override
  Stream<ConversationModel?> getConversationStream(String conversationId) {
    final controller = StreamController<ConversationModel?>.broadcast();

    Future<void> fetch() async {
      try {
        final rows = await _supabase
            .from('conversations')
            .select()
            .eq('id', conversationId)
            .limit(1);
        if (!controller.isClosed) {
          controller.add(rows.isEmpty ? null : _convFromRow(rows.first));
        }
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      }
    }

    fetch();

    final ch = _channel('conversation:$conversationId');
    ch
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'conversations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: conversationId,
          ),
          callback: (_) => fetch(),
        )
        .subscribe();

    controller.onCancel = () {
      ch.unsubscribe();
      _channels.remove('conversation:$conversationId');
    };

    return controller.stream;
  }

  @override
  Stream<List<MessageModel>> getMessages(
    String conversationId, {
    DateTime? filterAfterDate,
  }) {
    var query = _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at');

    return query.map((rows) {
      var models = rows.map(_msgFromRow).toList();
      if (filterAfterDate != null) {
        models = models
            .where((m) =>
                m.createdAt != null && m.createdAt!.isAfter(filterAfterDate),)
            .toList();
      }
      return models;
    });
  }

  @override
  Stream<Map<String, bool>> getTypingStatusStream(String conversationId) {
    final channelName = 'typing:$conversationId';
    final ch = _channel(channelName);

    final controller = StreamController<Map<String, bool>>.broadcast();

    ch
        .onPresenceSync((_) {
          final presenceList = ch.presenceState();
          final result = <String, bool>{};
          for (final singleState in presenceList) {
            for (final presence in singleState.presences) {
              final payload = presence.payload;
              final userId = payload['user_id'] as String?;
              final isTyping = payload['is_typing'] as bool? ?? false;
              if (userId != null) {
                result[userId] = isTyping;
              }
            }
          }
          if (!controller.isClosed) controller.add(result);
        })
        .subscribe();

    controller.onCancel = () {
      ch.unsubscribe();
      _channels.remove(channelName);
    };

    return controller.stream;
  }

  @override
  Stream<List<ConversationModel>> getMessageRequests(String userId) {
    final controller = StreamController<List<ConversationModel>>.broadcast();

    Future<void> fetch() async {
      try {
        final rows = await _supabase
            .from('conversations')
            .select()
            .contains('participant_ids', [userId])
            .eq('type', 'request')
            .order('created_at', ascending: false);

        final requests = rows
            .map(_convFromRow)
            .where((c) =>
                c.requestStatus == 'pending' && c.requesterId != userId,)
            .toList();

        if (!controller.isClosed) controller.add(requests);
      } catch (e) {
        if (!controller.isClosed) {
          controller.addError(ServerException('getMessageRequests error: $e'));
        }
      }
    }

    fetch();

    final ch = _channel('msg_requests:$userId');
    ch
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'conversations',
          callback: (_) => fetch(),
        )
        .subscribe();

    controller.onCancel = () {
      ch.unsubscribe();
      _channels.remove('msg_requests:$userId');
    };

    return controller.stream;
  }

  @override
  Stream<MessageModel> getMessageUpdatesStream({
    required String conversationId,
  }) {
    final controller = StreamController<MessageModel>.broadcast();
    final channelName = 'msg_updates:$conversationId';
    final ch = _channel(channelName);

    ch
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) {
            final newRecord = payload.newRecord;
            if (newRecord.isNotEmpty && !controller.isClosed) {
              controller.add(_msgFromRow(newRecord));
            }
          },
        )
        .subscribe();

    controller.onCancel = () {
      ch.unsubscribe();
      _channels.remove(channelName);
    };

    return controller.stream;
  }

  @override
  Stream<List<MessageModel>> getNewMessagesStream({
    required String conversationId,
    required DateTime afterTimestamp,
  }) {
    final controller = StreamController<List<MessageModel>>.broadcast();
    final channelName = 'new_msgs:$conversationId';
    final ch = _channel(channelName);

    ch
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) async {
            final newRecord = payload.newRecord;
            if (newRecord.isNotEmpty && !controller.isClosed) {
              final msg = await _msgFromRowAsync(newRecord);
              if (msg.createdAt != null &&
                  msg.createdAt!.isAfter(afterTimestamp)) {
                if (!controller.isClosed) controller.add([msg]);
              }
            }
          },
        )
        .subscribe();

    controller.onCancel = () {
      ch.unsubscribe();
      _channels.remove(channelName);
    };

    return controller.stream;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TYPING
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Future<void> setTypingStatus({
    required String conversationId,
    required String userId,
    required bool isTyping,
  }) async {
    try {
      final channelName = 'typing:$conversationId';
      final ch = _channel(channelName);
      if (isTyping) {
        await ch.track({'user_id': userId, 'is_typing': true});
      } else {
        await ch.untrack();
      }
    } catch (e) {
      throw ServerException('setTypingStatus error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SEND MESSAGES
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Future<MessageModel?> getMessageById({
    required String conversationId,
    required String messageId,
  }) async {
    try {
      if (!await SupabaseAuthBridge.instance.ensureAuthenticated()) {
        throw ServerException('Session Supabase non établie – reconnectez-vous');
      }
      final row = await _supabase
          .from('messages')
          .select()
          .eq('id', messageId)
          .eq('conversation_id', conversationId)
          .maybeSingle();
      if (row == null) return null;
      final data = Map<String, dynamic>.from(row['data'] as Map? ?? {});
      data['id'] = row['id'];
      data['conversationId'] = row['conversation_id'];
      data['senderId'] = row['sender_id'];
      data['type'] = row['type'];
      data['createdAt'] = row['created_at'];
      return MessageModel.fromJson(data);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('getMessageById error: $e');
    }
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
    try {
      final msgId = _uuid.v4();
      final now = DateTime.now().toUtc().toIso8601String();

      // Encrypt with Signal Protocol (throws if E2EE unavailable)
      final cryptoFields = await _encryptContent(
        plaintext: content,
        recipientId: recipientId,
        participantIds: participantIds,
        conversationId: conversationId,
        selfNote: selfNote,
      );

      final msgData = <String, dynamic>{
        'senderName': senderName,
        if (senderPhotoUrl != null) 'senderPhotoUrl': senderPhotoUrl,
        'content': content,          // base (overridden by cryptoFields)
        'encryptionLevel': 'aes',    // base (overridden by cryptoFields)
        ...cryptoFields,             // encrypted content + encryptionLevel + e2ee payload
        'status': 'sent',
        'readBy': [senderId],
        'readAt': {senderId: now},
        'deliveredTo': [senderId],
        'deliveredAt': {senderId: now},
        if (replyToId != null) 'replyToId': replyToId,
        if (replyToMessageData != null) 'replyToMessageData': replyToMessageData,
        if (productData != null) 'productData': productData,
        if (postData != null) 'postData': postData,
        if (eventData != null) 'eventData': eventData,
        if (sentWhileBlockedBy.isNotEmpty) 'sentWhileBlockedBy': sentWhileBlockedBy,
        if (linkPreviewData != null) 'linkPreviewData': linkPreviewData,
        if (isForwarded) 'isForwarded': isForwarded,
        if (mentionedUsers.isNotEmpty) 'mentionedUsers': mentionedUsers,
        if (clientMessageId != null) 'clientMessageId': clientMessageId,
        if (selfNote) 'selfNote': selfNote,
      };

      await _supabase.from('messages').insert({
        'id': msgId,
        'conversation_id': conversationId,
        'sender_id': senderId,
        'type': 'text',
        'created_at': now,
        'data': msgData,
      });

      final displayText = postData != null
          ? '📌 ${postData['authorName'] ?? 'Post partagé'}'
          : productData != null
              ? '🛒 ${productData['title'] ?? 'Produit'}'
              : content;

      await _updateConversationLastMessage(
        conversationId,
        text: displayText,
        senderId: senderId,
        type: 'text',
        at: now,
      );

      // Always return plaintext to the sender's local state
      return MessageModel.fromJson({
        ...msgData,
        'content': content,
        'id': msgId,
        'senderId': senderId,
        'type': 'text',
        'createdAt': now,
      });
    } catch (e) {
      throw ServerException('sendTextMessage error: $e');
    }
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
      final msgId = _uuid.v4();
      final now = DateTime.now().toUtc().toIso8601String();

      final msgData = <String, dynamic>{
        'senderName': senderName,
        if (senderPhotoUrl != null) 'senderPhotoUrl': senderPhotoUrl,
        'content': caption ?? '',
        'status': 'sent',
        'fileUrl': fileUrl,
        'fileName': fileName,
        'fileSize': fileSize,
        'mimeType': mimeType,
        'readBy': [senderId],
        'readAt': {senderId: now},
        'deliveredTo': [senderId],
        'deliveredAt': {senderId: now},
        'encryptionLevel': 'aes',
        if (replyToId != null) 'replyToId': replyToId,
        if (replyToMessageData != null) 'replyToMessageData': replyToMessageData,
        if (isForwarded) 'isForwarded': isForwarded,
        if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
        if (videoDuration != null) 'videoDuration': videoDuration,
        if (audioDuration != null) 'audioDuration': audioDuration,
        if (audioWaveform != null) 'audioWaveform': audioWaveform,
        if (blurhash != null) 'blurhash': blurhash,
        'mediaExpiresAt':
            DateTime.now().add(const Duration(days: 15)).toIso8601String(),
        'mediaExpired': false,
      };

      await _supabase.from('messages').insert({
        'id': msgId,
        'conversation_id': conversationId,
        'sender_id': senderId,
        'type': type,
        'created_at': now,
        'data': msgData,
      });

      final String lastMsg;
      switch (type) {
        case 'image':
          lastMsg = '📷 Photo';
        case 'video':
          lastMsg = '🎬 Vidéo';
        case 'audioFile':
          lastMsg = '🎵 Audio';
        default:
          lastMsg = '📎 Fichier';
      }

      await _updateConversationLastMessage(
        conversationId,
        text: lastMsg,
        senderId: senderId,
        type: type,
        at: now,
      );

      return MessageModel.fromJson({
        ...msgData,
        'id': msgId,
        'senderId': senderId,
        'type': type,
        'createdAt': now,
      });
    } catch (e) {
      throw ServerException('sendMediaMessage error: $e');
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
    throw UnimplementedError(
      'sendAudioMessage: upload via Firebase Storage then call sendMediaMessage.',
    );
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
      final msgId = _uuid.v4();
      final now = DateTime.now().toUtc().toIso8601String();

      final msgData = <String, dynamic>{
        'senderName': senderName,
        if (senderPhotoUrl != null) 'senderPhotoUrl': senderPhotoUrl,
        'content': address.isNotEmpty ? address : 'Position partagée',
        'status': 'sent',
        'latitude': latitude,
        'longitude': longitude,
        'locationAddress': address,
        'readBy': [senderId],
        'readAt': {senderId: now},
        'deliveredTo': [senderId],
        'deliveredAt': {senderId: now},
        'encryptionLevel': 'aes',
        if (replyToId != null) 'replyToId': replyToId,
        if (replyToMessageData != null) 'replyToMessageData': replyToMessageData,
      };

      await _supabase.from('messages').insert({
        'id': msgId,
        'conversation_id': conversationId,
        'sender_id': senderId,
        'type': 'location',
        'created_at': now,
        'data': msgData,
      });

      await _updateConversationLastMessage(
        conversationId,
        text: '📍 Position partagée',
        senderId: senderId,
        type: 'location',
        at: now,
      );

      return MessageModel.fromJson({
        ...msgData,
        'id': msgId,
        'senderId': senderId,
        'type': 'location',
        'createdAt': now,
      });
    } catch (e) {
      throw ServerException('sendLocationMessage error: $e');
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
      final msgId = _uuid.v4();
      final now = DateTime.now().toUtc().toIso8601String();

      final msgData = <String, dynamic>{
        'senderName': senderName,
        if (senderPhotoUrl != null) 'senderPhotoUrl': senderPhotoUrl,
        'content': 'Sticker',
        'status': 'sent',
        'fileUrl': stickerUrl,
        'stickerPackId': stickerPackId,
        'stickerId': stickerId,
        'isAnimatedSticker': isAnimated,
        'readBy': [senderId],
        'readAt': {senderId: now},
        'deliveredTo': [senderId],
        'deliveredAt': {senderId: now},
        'encryptionLevel': 'aes',
        if (replyToId != null) 'replyToId': replyToId,
        if (replyToMessageData != null) 'replyToMessageData': replyToMessageData,
      };

      await _supabase.from('messages').insert({
        'id': msgId,
        'conversation_id': conversationId,
        'sender_id': senderId,
        'type': 'sticker',
        'created_at': now,
        'data': msgData,
      });

      await _updateConversationLastMessage(
        conversationId,
        text: '🎭 Sticker',
        senderId: senderId,
        type: 'sticker',
        at: now,
      );

      return MessageModel.fromJson({
        ...msgData,
        'id': msgId,
        'senderId': senderId,
        'type': 'sticker',
        'createdAt': now,
      });
    } catch (e) {
      throw ServerException('sendStickerMessage error: $e');
    }
  }

  @override
  Future<MessageModel> sendSystemMessage({
    required String conversationId,
    required String content,
  }) async {
    try {
      final msgId = _uuid.v4();
      final now = DateTime.now().toUtc().toIso8601String();

      final msgData = <String, dynamic>{
        'senderName': 'Système',
        'content': content,
        'status': 'sent',
        'readBy': <String>[],
        'readAt': <String, dynamic>{},
        'encryptionLevel': 'aes',
      };

      await _supabase.from('messages').insert({
        'id': msgId,
        'conversation_id': conversationId,
        'sender_id': 'system',
        'type': 'system',
        'created_at': now,
        'data': msgData,
      });

      await _updateConversationLastMessage(
        conversationId,
        text: content,
        senderId: 'system',
        type: 'system',
        at: now,
      );

      return MessageModel.fromJson({
        ...msgData,
        'id': msgId,
        'senderId': 'system',
        'type': 'system',
        'createdAt': now,
      });
    } catch (e) {
      throw ServerException('sendSystemMessage error: $e');
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
    throw UnimplementedError(
      'sendFileMessage: upload via Firebase Storage then call sendMediaMessage.',
    );
  }

  @override
  UploadTask uploadMediaFile({
    required File file,
    required String conversationId,
    required String fileName,
  }) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final storagePath = 'messages/$conversationId/${timestamp}_$fileName';
    final ref = FirebaseStorage.instance.ref().child(storagePath);
    return ref.putFile(file);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CONVERSATIONS — CREATE / FIND
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Future<ConversationModel> createIndividualConversation({
    required String currentUserId,
    required String otherUserId,
  }) async {
    try {
      if (!await SupabaseAuthBridge.instance.ensureAuthenticated()) {
        throw ServerException('Supabase session introuvable');
      }

      final existing = await findIndividualConversation(
        userId1: currentUserId,
        userId2: otherUserId,
      );
      if (existing != null) return existing;

      final convId = _uuid.v4();
      final now = DateTime.now().toUtc().toIso8601String();

      final convData = <String, dynamic>{
        'unreadCount': {currentUserId: 0, otherUserId: 0},
        'requestStatus': 'none',
      };

      await _supabase.from('conversations').insert({
        'id': convId,
        'type': 'individual',
        'participant_ids': [currentUserId, otherUserId],
        'created_by': currentUserId,
        'created_at': now,
        'updated_at': now,
        'data': convData,
      });

      return ConversationModel.fromJson({
        ...convData,
        'id': convId,
        'type': 'individual',
        'participantIds': [currentUserId, otherUserId],
        'createdBy': currentUserId,
        'createdAt': now,
      });
    } catch (e) {
      throw ServerException('createIndividualConversation error: $e');
    }
  }

  @override
  Future<ConversationModel> getOrCreateSelfConversation({
    required String userId,
  }) async {
    try {
      if (!await SupabaseAuthBridge.instance.ensureAuthenticated()) {
        throw ServerException('Supabase session introuvable');
      }

      // Cherche une conversation 1:1 dont le seul participant est l'utilisateur.
      final rows = await _supabase
          .from('conversations')
          .select()
          .eq('type', 'individual')
          .contains('participant_ids', [userId])
          .limit(20);

      for (final row in rows as List) {
        final participants = List<String>.from(row['participant_ids'] ?? []);
        if (participants.length == 1 && participants.first == userId) {
          final data = Map<String, dynamic>.from(row['data'] as Map? ?? {});
          return ConversationModel.fromJson({
            ...data,
            'id': row['id'],
            'type': row['type'],
            'participantIds': participants,
            'createdBy': row['created_by'],
            'createdAt': row['created_at'],
          });
        }
      }

      final convId = _uuid.v4();
      final now = DateTime.now().toUtc().toIso8601String();
      final convData = <String, dynamic>{
        'unreadCount': {userId: 0},
        'name': 'Mes notes',
        'requestStatus': 'none',
      };

      await _supabase.from('conversations').insert({
        'id': convId,
        'type': 'individual',
        'participant_ids': [userId],
        'created_by': userId,
        'created_at': now,
        'updated_at': now,
        'data': convData,
      });

      return ConversationModel.fromJson({
        ...convData,
        'id': convId,
        'type': 'individual',
        'participantIds': [userId],
        'createdBy': userId,
        'createdAt': now,
      });
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('getOrCreateSelfConversation error: $e');
    }
  }

  @override
  Future<ConversationModel> createGroupConversation({
    required String creatorId,
    required List<String> participantIds,
    required String groupName,
    String? groupImageUrl,
    String? groupId,
  }) async {
    try {
      if (!await SupabaseAuthBridge.instance.ensureAuthenticated()) {
        throw ServerException('Supabase session introuvable');
      }

      // Priority 1: find by groupId
      if (groupId != null) {
        final existing = await findGroupConversationByGroupId(
          groupId: groupId,
          userId: creatorId,
        );
        if (existing != null) return existing;
      }

      final allParticipants = ({...participantIds, creatorId}).toList()..sort();
      final convId = _uuid.v4();
      final now = DateTime.now().toUtc().toIso8601String();

      final unreadCount = <String, int>{
        for (final id in allParticipants) id: 0,
      };

      final convData = <String, dynamic>{
        'name': groupName,
        if (groupImageUrl != null) 'imageUrl': groupImageUrl,
        if (groupId != null) 'groupId': groupId,
        'adminIds': [creatorId],
        'unreadCount': unreadCount,
        'requestStatus': 'none',
      };

      await _supabase.from('conversations').insert({
        'id': convId,
        'type': 'group',
        'participant_ids': allParticipants,
        'group_id': groupId,
        'created_by': creatorId,
        'created_at': now,
        'updated_at': now,
        'data': convData,
      });

      return ConversationModel.fromJson({
        ...convData,
        'id': convId,
        'type': 'group',
        'participantIds': allParticipants,
        'createdBy': creatorId,
        'createdAt': now,
      });
    } catch (e) {
      throw ServerException('createGroupConversation error: $e');
    }
  }

  @override
  Future<ConversationModel> createIndividualConversationAsRequest({
    required String currentUserId,
    required String otherUserId,
  }) async {
    try {
      if (!await SupabaseAuthBridge.instance.ensureAuthenticated()) {
        throw ServerException('Supabase session introuvable');
      }

      final existing = await findIndividualConversation(
        userId1: currentUserId,
        userId2: otherUserId,
      );

      if (existing != null) {
        if (existing.requestStatus == 'declined') {
          await _mergeConvData(existing.id, {
            'requestStatus': 'pending',
            'requesterId': currentUserId,
            'requestedAt': DateTime.now().toUtc().toIso8601String(),
            'respondedAt': null,
          });
          return existing.copyWith(
            requestStatus: 'pending',
            requesterId: currentUserId,
          );
        }
        return existing;
      }

      final convId = _uuid.v4();
      final now = DateTime.now().toUtc().toIso8601String();

      final convData = <String, dynamic>{
        'unreadCount': {currentUserId: 0, otherUserId: 0},
        'requestStatus': 'pending',
        'requesterId': currentUserId,
        'requestedAt': now,
      };

      await _supabase.from('conversations').insert({
        'id': convId,
        'type': 'request',
        'participant_ids': [currentUserId, otherUserId],
        'created_by': currentUserId,
        'created_at': now,
        'updated_at': now,
        'data': convData,
      });

      return ConversationModel.fromJson({
        ...convData,
        'id': convId,
        'type': 'request',
        'participantIds': [currentUserId, otherUserId],
        'createdBy': currentUserId,
        'createdAt': now,
      });
    } catch (e) {
      throw ServerException('createIndividualConversationAsRequest error: $e');
    }
  }

  @override
  Future<ConversationModel?> findIndividualConversation({
    required String userId1,
    required String userId2,
  }) async {
    try {
      // On cherche parmi les 1:1 « normales » (individual) ET les demandes
      // (request) : une demande acceptée garde type='request', et sans ça
      // getOrCreateIndividualConversation en recréerait une seconde ligne
      // 'individual' → le même contact apparaîtrait deux fois dans la liste.
      final rows = await _supabase
          .from('conversations')
          .select()
          .inFilter('type', ['individual', 'request'])
          .contains('participant_ids', [userId1, userId2]);

      ConversationModel? requestMatch;
      for (final row in rows) {
        final ids = List<String>.from(row['participant_ids'] as List? ?? []);
        if (ids.length == 2 &&
            ids.contains(userId1) &&
            ids.contains(userId2)) {
          // Une vraie conversation 'individual' est prioritaire ; sinon on
          // réutilise la ligne 'request' au lieu d'en créer une nouvelle.
          if (row['type'] == 'individual') {
            return _convFromRow(row);
          }
          requestMatch ??= _convFromRow(row);
        }
      }
      return requestMatch;
    } catch (e) {
      throw ServerException('findIndividualConversation error: $e');
    }
  }

  @override
  Future<ConversationModel?> findGroupConversationByName({
    required String groupName,
    required String userId,
  }) async {
    try {
      final rows = await _supabase
          .from('conversations')
          .select()
          .eq('type', 'group')
          .contains('participant_ids', [userId]);

      for (final row in rows) {
        final data = (row['data'] as Map<String, dynamic>?) ?? {};
        if (data['name'] == groupName) return _convFromRow(row);
      }
      return null;
    } catch (e) {
      throw ServerException('findGroupConversationByName error: $e');
    }
  }

  @override
  Future<ConversationModel?> findGroupConversationByGroupId({
    required String groupId,
    required String userId,
  }) async {
    try {
      if (!await SupabaseAuthBridge.instance.ensureAuthenticated()) {
        throw ServerException('Session Supabase non établie – reconnectez-vous');
      }
      // RPC SECURITY DEFINER : localise la conversation du groupe SANS filtrer
      // par participant_ids (sinon un membre ayant rejoint le groupe après sa
      // création — le cas courant — ne la retrouvait jamais, et
      // createGroupConversation en recréait une par-dessus, en double).
      // La fonction vérifie l'appartenance réelle (group_members) puis
      // (ré)ajoute userId aux participants si besoin.
      final convId = await _supabase.rpc(
        'join_group_conversation',
        params: {'p_group_id': groupId},
      ) as String?;
      if (convId == null) return null;

      final rows = await _supabase
          .from('conversations')
          .select()
          .eq('id', convId)
          .limit(1);
      if (rows.isEmpty) return null;
      return _convFromRow(rows.first);
    } catch (e) {
      throw ServerException('findGroupConversationByGroupId error: $e');
    }
  }

  @override
  Future<ConversationModel?> getConversationById(String conversationId) async {
    try {
      final rows = await _supabase
          .from('conversations')
          .select()
          .eq('id', conversationId)
          .limit(1);

      if (rows.isEmpty) return null;
      return _convFromRow(rows.first);
    } catch (e) {
      throw ServerException('getConversationById error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MARK AS READ / UNREAD MENTIONS
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Future<void> markAsDelivered({
    required String conversationId,
    required String userId,
  }) async {
    try {
      await _supabase.rpc('mark_messages_as_delivered', params: {
        'p_conversation_id': conversationId,
        'p_user_id': userId,
      },);

      // Also update lastMessageDeliveredTo on the conversation
      final rows = await _supabase
          .from('conversations')
          .select('data')
          .eq('id', conversationId)
          .limit(1);
      final current = Map<String, dynamic>.from(
        (rows.isNotEmpty ? rows.first['data'] as Map<String, dynamic>? : null) ?? {},
      );
      final deliveredTo = List<String>.from(current['lastMessageDeliveredTo'] as List? ?? []);
      if (!deliveredTo.contains(userId)) {
        deliveredTo.add(userId);
        await _mergeConvData(conversationId, {
          'lastMessageDeliveredTo': deliveredTo,
        }, merge: true,);
      }
    } catch (e) {
      // Non-critical: delivery tracking best-effort
      debugPrint('markAsDelivered error: $e');
    }
  }

  @override
  Future<void> markAsRead({
    required String conversationId,
    required String userId,
  }) async {
    try {
      // Fetch current lastMessageReadBy to append userId
      final rows = await _supabase
          .from('conversations')
          .select('data')
          .eq('id', conversationId)
          .limit(1);

      final current = Map<String, dynamic>.from(
        (rows.isNotEmpty ? rows.first['data'] as Map<String, dynamic>? : null) ?? {},
      );
      final readBy = List<String>.from(current['lastMessageReadBy'] as List? ?? []);
      if (!readBy.contains(userId)) readBy.add(userId);

      await _mergeConvData(conversationId, {
        'unreadCount': {userId: 0},
        'lastMessageReadBy': readBy,
      }, merge: true,);
    } catch (e) {
      throw ServerException('markAsRead error: $e');
    }
  }

  @override
  Future<void> clearUnreadMentions({
    required String conversationId,
    required String userId,
  }) async {
    try {
      await _mergeConvData(
        conversationId,
        {'unreadMentions': {userId: 0}},
        merge: true,
      );
    } catch (e) {
      throw ServerException('clearUnreadMentions error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CONVERSATION MUTATIONS (archive, mute, pin, delete, restore)
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Future<void> archiveConversation({
    required String conversationId,
    required String userId,
  }) async {
    await _mergeConvData(
      conversationId,
      {'archivedBy': {userId: true}},
      merge: true,
    );
  }

  @override
  Future<void> unarchiveConversation({
    required String conversationId,
    required String userId,
  }) async {
    await _removeNestedConvDataKey(conversationId, 'archivedBy', userId);
  }

  @override
  Future<void> muteConversation({
    required String conversationId,
    required String userId,
    Duration? duration,
  }) async {
    final muteValue = duration == null
        ? 'forever'
        : DateTime.now().add(duration).toIso8601String();
    await _mergeConvData(
      conversationId,
      {'mutedBy': {userId: muteValue}},
      merge: true,
    );
  }

  @override
  Future<void> unmuteConversation({
    required String conversationId,
    required String userId,
  }) async {
    await _removeNestedConvDataKey(conversationId, 'mutedBy', userId);
  }

  @override
  Future<void> pinConversation({
    required String conversationId,
    required String userId,
  }) async {
    final count = await getPinnedConversationCount(userId);
    if (count >= 5) {
      throw ServerException('Vous ne pouvez pas épingler plus de 5 conversations');
    }
    await _mergeConvData(
      conversationId,
      {'pinnedBy': {userId: DateTime.now().toUtc().toIso8601String()}},
      merge: true,
    );
  }

  @override
  Future<void> unpinConversation({
    required String conversationId,
    required String userId,
  }) async {
    await _removeNestedConvDataKey(conversationId, 'pinnedBy', userId);
  }

  @override
  Future<int> getPinnedConversationCount(String userId) async {
    try {
      final rows = await _supabase
          .from('conversations')
          .select('data')
          .contains('participant_ids', [userId]);

      return rows.where((row) {
        final data = (row['data'] as Map<String, dynamic>?) ?? {};
        final pinnedBy = data['pinnedBy'] as Map?;
        return pinnedBy != null && pinnedBy.containsKey(userId);
      }).length;
    } catch (_) {
      return 0;
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
        final conv = await getConversationById(conversationId);
        if (conv == null) return;

        final isAdmin = conv.adminIds.contains(userId);
        final isCreator = conv.createdBy == userId;
        if (!isAdmin && !isCreator) {
          throw ServerException(
            "Seul l'administrateur ou le créateur peut supprimer pour tout le monde.",
          );
        }

        // Hard delete (cascade deletes messages)
        await _supabase
            .from('conversations')
            .delete()
            .eq('id', conversationId);
      } else {
        final now = DateTime.now().toUtc().toIso8601String();
        await _mergeConvData(
          conversationId,
          {
            'deletedBy': {userId: now},
            'unreadCount': {userId: 0},
          },
          merge: true,
        );
      }
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('deleteConversation error: $e');
    }
  }

  @override
  Future<void> restoreConversationForUser({
    required String conversationId,
    required String userId,
  }) async {
    await _removeNestedConvDataKey(conversationId, 'deletedBy', userId);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GROUP ADMIN
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Future<void> promoteToAdmin({
    required String conversationId,
    required String userId,
  }) async {
    try {
      final rows = await _supabase
          .from('conversations')
          .select('data')
          .eq('id', conversationId)
          .limit(1);
      if (rows.isEmpty) return;
      final data =
          Map<String, dynamic>.from((rows.first['data'] as Map?) ?? {});
      final adminIds = List<String>.from(data['adminIds'] as List? ?? []);
      if (!adminIds.contains(userId)) adminIds.add(userId);
      data['adminIds'] = adminIds;
      await _supabase
          .from('conversations')
          .update({'data': data})
          .eq('id', conversationId);
    } catch (e) {
      throw ServerException('promoteToAdmin error: $e');
    }
  }

  @override
  Future<void> demoteFromAdmin({
    required String conversationId,
    required String userId,
  }) async {
    try {
      final rows = await _supabase
          .from('conversations')
          .select('data')
          .eq('id', conversationId)
          .limit(1);
      if (rows.isEmpty) return;
      final data =
          Map<String, dynamic>.from((rows.first['data'] as Map?) ?? {});
      final adminIds = List<String>.from(data['adminIds'] as List? ?? []);
      adminIds.remove(userId);
      data['adminIds'] = adminIds;
      await _supabase
          .from('conversations')
          .update({'data': data})
          .eq('id', conversationId);
    } catch (e) {
      throw ServerException('demoteFromAdmin error: $e');
    }
  }

  @override
  Future<void> removeUserFromGroup({
    required String conversationId,
    required String userId,
  }) async {
    try {
      // Send system message first
      await sendSystemMessage(
        conversationId: conversationId,
        content: 'Un utilisateur a été retiré du groupe',
      );

      final rows = await _supabase
          .from('conversations')
          .select('participant_ids, data')
          .eq('id', conversationId)
          .limit(1);
      if (rows.isEmpty) return;

      final ids = List<String>.from(
          rows.first['participant_ids'] as List? ?? [],);
      ids.remove(userId);

      final data =
          Map<String, dynamic>.from((rows.first['data'] as Map?) ?? {});
      final adminIds = List<String>.from(data['adminIds'] as List? ?? []);
      adminIds.remove(userId);
      data['adminIds'] = adminIds;

      await _supabase.from('conversations').update({
        'participant_ids': ids,
        'data': data,
      }).eq('id', conversationId);
    } catch (e) {
      throw ServerException('removeUserFromGroup error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MESSAGE MUTATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Future<void> deleteMessageForMe({
    required String conversationId,
    required String messageId,
    required String userId,
  }) async {
    try {
      await _mergeMsgData(
        messageId,
        {'deletedFor': userId},
        appendToList: true,
      );
    } catch (e) {
      throw ServerException('deleteMessageForMe error: $e');
    }
  }

  @override
  Future<void> deleteMessageForEveryone({
    required String conversationId,
    required String messageId,
  }) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();

      final rows = await _supabase
          .from('messages')
          .select('data')
          .eq('id', messageId)
          .limit(1);
      if (rows.isEmpty) return;
      final data =
          Map<String, dynamic>.from((rows.first['data'] as Map?) ?? {});
      data['deletedForEveryone'] = true;
      data['deletedAt'] = now;
      data['content'] = '';
      data.remove('fileUrl');
      data.remove('thumbnailUrl');

      await _supabase.from('messages').update({
        'is_deleted': true,
        'data': data,
      }).eq('id', messageId);

      // Retire l'épingle éventuelle : sans ça le bandeau garde une entrée
      // fantôme (« Appuyez pour voir ») vers un message qui n'existe plus.
      // RLS sans droit d'épinglage ⇒ 0 ligne supprimée, sans erreur.
      await _supabase
          .from('group_pinned_items')
          .delete()
          .eq('item_type', 'message')
          .eq('item_id', messageId);
    } catch (e) {
      throw ServerException('deleteMessageForEveryone error: $e');
    }
  }

  @override
  Future<void> addReaction({
    required String conversationId,
    required String messageId,
    required String emoji,
  }) async {
    await _mergeMsgData(messageId, {'reactions': emoji}, appendToList: true);
  }

  @override
  Future<void> removeReaction({
    required String conversationId,
    required String messageId,
    required String emoji,
  }) async {
    try {
      final rows = await _supabase
          .from('messages')
          .select('data')
          .eq('id', messageId)
          .limit(1);
      if (rows.isEmpty) return;
      final data =
          Map<String, dynamic>.from((rows.first['data'] as Map?) ?? {});
      final reactions = List<String>.from(data['reactions'] as List? ?? []);
      reactions.remove(emoji);
      data['reactions'] = reactions;
      await _supabase
          .from('messages')
          .update({'data': data})
          .eq('id', messageId);
    } catch (e) {
      throw ServerException('removeReaction error: $e');
    }
  }

  @override
  Future<void> toggleStarMessage({
    required String conversationId,
    required String messageId,
    required String userId,
  }) async {
    try {
      final rows = await _supabase
          .from('messages')
          .select('data')
          .eq('id', messageId)
          .limit(1);
      if (rows.isEmpty) return;
      final data =
          Map<String, dynamic>.from((rows.first['data'] as Map?) ?? {});
      final starredBy = List<String>.from(data['starredBy'] as List? ?? []);
      if (starredBy.contains(userId)) {
        starredBy.remove(userId);
      } else {
        starredBy.add(userId);
      }
      data['starredBy'] = starredBy;
      await _supabase
          .from('messages')
          .update({'data': data})
          .eq('id', messageId);
    } catch (e) {
      throw ServerException('toggleStarMessage error: $e');
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
      final now = DateTime.now().toUtc().toIso8601String();

      final rows = await _supabase
          .from('messages')
          .select('data')
          .eq('id', messageId)
          .limit(1);
      if (rows.isEmpty) return;
      final data =
          Map<String, dynamic>.from((rows.first['data'] as Map?) ?? {});

      final editHistory =
          List<Map<String, dynamic>>.from(data['editHistory'] as List? ?? []);
      editHistory.add({'content': oldContent, 'editedAt': now});

      data['content'] = newContent;
      data['editedAt'] = now;
      data['editHistory'] = editHistory;

      await _supabase
          .from('messages')
          .update({'data': data})
          .eq('id', messageId);
    } catch (e) {
      throw ServerException('editMessage error: $e');
    }
  }

  @override
  Future<void> reportMessage({
    required String conversationId,
    required String messageId,
    required String userId,
    required String reason,
  }) async {
    await _mergeMsgData(messageId, {'reportedBy': userId}, appendToList: true);
  }

  @override
  Future<void> reportGroup({
    required String conversationId,
    required String userId,
    required String reason,
  }) async {
    try {
      final rows = await _supabase
          .from('conversations')
          .select('data')
          .eq('id', conversationId)
          .limit(1);
      if (rows.isEmpty) return;
      final data =
          Map<String, dynamic>.from((rows.first['data'] as Map?) ?? {});
      final reportedBy =
          List<String>.from(data['reportedBy'] as List? ?? []);
      if (!reportedBy.contains(userId)) reportedBy.add(userId);
      data['reportedBy'] = reportedBy;
      await _supabase
          .from('conversations')
          .update({'data': data})
          .eq('id', conversationId);
    } catch (e) {
      throw ServerException('reportGroup error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PAGINATION
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Future<(List<MessageModel>, dynamic)> getMessagesPaginated({
    required String conversationId,
    required int limit,
    dynamic lastMessageKey,
    DateTime? filterAfterDate,
  }) async {
    try {
      // Build filter query — cursor filter must precede order/limit
      final baseQuery = _supabase
          .from('messages')
          .select()
          .eq('conversation_id', conversationId);

      final filteredQuery = lastMessageKey != null
          ? baseQuery.lt('created_at', lastMessageKey.toString())
          : baseQuery;

      final rows = await filteredQuery
          .order('created_at', ascending: false)
          .limit(limit + 1);

      var messages = await Future.wait(rows.map(_msgFromRowAsync));

      if (filterAfterDate != null) {
        messages = messages
            .where((m) =>
                m.createdAt != null && m.createdAt!.isAfter(filterAfterDate),)
            .toList();
      }

      final hasMore = messages.length > limit;
      if (hasMore) messages.removeLast();

      // Return oldest message's createdAt as cursor for next page
      final newCursor =
          messages.isNotEmpty ? messages.last.createdAt?.toIso8601String() : null;

      // Reverse to oldest-first for display
      return (messages.reversed.toList(), newCursor);
    } catch (e) {
      throw ServerException('getMessagesPaginated error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SEARCH / FETCH
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Future<List<ConversationModel>> searchConversations(
    String userId,
    String query,
  ) async {
    try {
      if (query.trim().isEmpty) return [];

      final rows = await _supabase
          .from('conversations')
          .select()
          .contains('participant_ids', [userId])
          .order('last_message_at', ascending: false)
          .limit(50);

      final lowerQuery = query.toLowerCase();
      return rows
          .map(_convFromRow)
          .where((c) =>
              (c.name ?? '').toLowerCase().contains(lowerQuery) ||
              (c.lastMessage ?? '').toLowerCase().contains(lowerQuery),)
          .take(20)
          .toList();
    } catch (e) {
      throw ServerException('searchConversations error: $e');
    }
  }

  @override
  Future<List<MessageModel>> getMediaMessages({
    required String conversationId,
    int limit = 50,
    String? beforeMessageId,
  }) async {
    try {
      var query = _supabase
          .from('messages')
          .select()
          .eq('conversation_id', conversationId)
          .inFilter('type', ['image', 'file'])
          .order('created_at', ascending: false)
          .limit(limit);

      final rows = await query;
      return rows
          .map(_msgFromRow)
          .where((m) => m.fileUrl != null)
          .toList();
    } catch (e) {
      throw ServerException('getMediaMessages error: $e');
    }
  }

  @override
  Future<List<MessageModel>> getStarredMessages({
    required String conversationId,
    required String userId,
    int limit = 100,
  }) async {
    try {
      final rows = await _supabase
          .from('messages')
          .select()
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: false)
          .limit(500);

      return rows
          .map(_msgFromRow)
          .where((m) => m.starredBy.contains(userId))
          .take(limit)
          .toList();
    } catch (e) {
      throw ServerException('getStarredMessages error: $e');
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

      // Use Postgres ILIKE on the JSONB content field
      final rows = await _supabase
          .from('messages')
          .select()
          .eq('conversation_id', conversationId)
          .ilike('data->>content', '%$query%')
          .order('created_at', ascending: false)
          .limit(limit);

      return rows.map(_msgFromRow).toList();
    } catch (e) {
      throw ServerException('searchMessagesInConversation error: $e');
    }
  }

  @override
  Future<List<MessageModel>> getMessagesSince({
    required String conversationId,
    required DateTime since,
    int limit = 100,
  }) async {
    try {
      final rows = await _supabase
          .from('messages')
          .select()
          .eq('conversation_id', conversationId)
          .gte('created_at', since.toUtc().toIso8601String())
          .order('created_at', ascending: false)
          .limit(limit);

      return rows.map(_msgFromRow).toList();
    } catch (e) {
      throw ServerException('getMessagesSince error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // AUTO-DELETE / EPHEMERAL
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Future<void> setAutoDeleteSettings({
    required String conversationId,
    required int? durationSeconds,
  }) async {
    await _mergeConvData(conversationId, {
      'autoDeleteAfterSeconds': durationSeconds,
    });
  }

  @override
  Future<int?> getAutoDeleteSettings(String conversationId) async {
    try {
      final rows = await _supabase
          .from('conversations')
          .select('data')
          .eq('id', conversationId)
          .limit(1);
      if (rows.isEmpty) return null;
      final data = (rows.first['data'] as Map<String, dynamic>?) ?? {};
      return data['autoDeleteAfterSeconds'] as int?;
    } catch (e) {
      throw ServerException('getAutoDeleteSettings error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MESSAGE REQUESTS
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Future<void> updateRequestStatus({
    required String conversationId,
    required String status,
    required String recipientId,
  }) async {
    await _mergeConvData(conversationId, {
      'requestStatus': status,
      'respondedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PRIVATE HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Merge a partial update into the `data` JSONB of a conversation row.
  ///
  /// If [merge] is true, sub-keys of nested maps are merged rather than
  /// replaced entirely (useful for unreadCount, mutedBy, etc.).
  Future<void> _mergeConvData(
    String conversationId,
    Map<String, dynamic> partial, {
    bool merge = false,
  }) async {
    try {
      final rows = await _supabase
          .from('conversations')
          .select('data')
          .eq('id', conversationId)
          .limit(1);
      if (rows.isEmpty) return;
      final current =
          Map<String, dynamic>.from((rows.first['data'] as Map?) ?? {});

      if (merge) {
        for (final entry in partial.entries) {
          if (current[entry.key] is Map && entry.value is Map) {
            current[entry.key] = {
              ...(current[entry.key] as Map),
              ...(entry.value as Map),
            };
          } else {
            current[entry.key] = entry.value;
          }
        }
      } else {
        current.addAll(partial);
      }

      await _supabase
          .from('conversations')
          .update({'data': current})
          .eq('id', conversationId);
    } catch (e) {
      throw ServerException('_mergeConvData error: $e');
    }
  }

  /// Remove a single key from a nested map inside `data` JSONB.
  Future<void> _removeNestedConvDataKey(
    String conversationId,
    String parentKey,
    String childKey,
  ) async {
    try {
      final rows = await _supabase
          .from('conversations')
          .select('data')
          .eq('id', conversationId)
          .limit(1);
      if (rows.isEmpty) return;
      final current =
          Map<String, dynamic>.from((rows.first['data'] as Map?) ?? {});
      if (current[parentKey] is Map) {
        final nested =
            Map<String, dynamic>.from(current[parentKey] as Map);
        nested.remove(childKey);
        current[parentKey] = nested;
      }
      await _supabase
          .from('conversations')
          .update({'data': current})
          .eq('id', conversationId);
    } catch (e) {
      throw ServerException('_removeNestedConvDataKey error: $e');
    }
  }

  /// Merge a partial update into the `data` JSONB of a message row.
  ///
  /// If [appendToList] is true, [partial] must be `{key: singleValue}` and
  /// the value is appended to the existing list at that key.
  Future<void> _mergeMsgData(
    String messageId,
    Map<String, dynamic> partial, {
    bool appendToList = false,
  }) async {
    try {
      final rows = await _supabase
          .from('messages')
          .select('data')
          .eq('id', messageId)
          .limit(1);
      if (rows.isEmpty) return;
      final current =
          Map<String, dynamic>.from((rows.first['data'] as Map?) ?? {});

      if (appendToList) {
        for (final entry in partial.entries) {
          final existing =
              List<dynamic>.from(current[entry.key] as List? ?? []);
          if (!existing.contains(entry.value)) {
            existing.add(entry.value);
          }
          current[entry.key] = existing;
        }
      } else {
        current.addAll(partial);
      }

      await _supabase
          .from('messages')
          .update({'data': current})
          .eq('id', messageId);
    } catch (e) {
      throw ServerException('_mergeMsgData error: $e');
    }
  }
}
