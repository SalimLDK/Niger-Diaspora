import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../constants/app_config.dart';
import 'encryption_service.dart';
import 'supabase_auth_bridge.dart';

/// Message en attente d'envoi depuis le background
class BackgroundPendingMessage {
  final String id;
  final String conversationId;
  final String content;
  final String senderId;
  final String senderName;
  final String? senderPhotoUrl;
  final DateTime createdAt;
  final int retryCount;

  BackgroundPendingMessage({
    String? id,
    required this.conversationId,
    required this.content,
    required this.senderId,
    required this.senderName,
    this.senderPhotoUrl,
    DateTime? createdAt,
    this.retryCount = 0,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'conversationId': conversationId,
    'content': content,
    'senderId': senderId,
    'senderName': senderName,
    'senderPhotoUrl': senderPhotoUrl,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'retryCount': retryCount,
  };

  factory BackgroundPendingMessage.fromJson(Map<String, dynamic> json) =>
      BackgroundPendingMessage(
        id: json['id'],
        conversationId: json['conversationId'],
        content: json['content'],
        senderId: json['senderId'],
        senderName: json['senderName'],
        senderPhotoUrl: json['senderPhotoUrl'],
        createdAt: DateTime.parse(json['createdAt']).toLocal(),
        retryCount: json['retryCount'] ?? 0,
      );

  BackgroundPendingMessage copyWithRetry() => BackgroundPendingMessage(
    id: id,
    conversationId: conversationId,
    content: content,
    senderId: senderId,
    senderName: senderName,
    senderPhotoUrl: senderPhotoUrl,
    createdAt: createdAt,
    retryCount: retryCount + 1,
  );
}

/// Service autonome pour envoyer des messages depuis les isolates background.
/// Ne dépend PAS de Riverpod - utilise directement Firebase et SharedPreferences.
/// Gère aussi la mise en queue des messages en cas d'échec (offline).
///
/// Écrit dans la table Supabase `messages` — le même backend que
/// `MessageSupabaseDataSource`, avec le même schéma de colonnes (`data`
/// JSONB en camelCase). Chiffre avec la clé AES globale ([EncryptionService]),
/// pas Signal Protocol : ce dernier suppose Hive et le service E2EE complet
/// initialisés (voir `NotificationDecryptionService`), impossible dans un
/// isolate background éphémère. C'est le même repli 'aes' que le reste de
/// l'app utilise déjà quand Signal n'est pas disponible — le destinataire le
/// déchiffre normalement.
class BackgroundReplyService {
  static final BackgroundReplyService _instance =
      BackgroundReplyService._internal();
  factory BackgroundReplyService() => _instance;
  BackgroundReplyService._internal();

  static const String _pendingMessagesKey = 'background_pending_messages';
  static const int _maxRetries = 5;
  static const _uuid = Uuid();

  static bool _supabaseReady = false;

  /// Prépare un client Supabase propre à cet isolate.
  ///
  /// `Supabase.instance` est un singleton *par isolate* (voir la même note
  /// dans `BackgroundLocationService._initializeSupabaseForIsolate`) : celui
  /// de l'app principale n'existe pas ici. Si l'app principale a déjà
  /// initialisé Supabase dans CET isolate (cas où cette méthode est appelée
  /// depuis l'isolate principal, ex. pour vider la queue au démarrage), on
  /// réutilise ce client tel quel plutôt que d'appeler `Supabase.initialize`
  /// une seconde fois (ce qui lève). Sinon, on initialise avec une clé de
  /// session dédiée pour ne pas se marcher dessus avec l'isolate de
  /// localisation ni avec l'app principale (échange de magic link à usage
  /// unique, invalidé par des échanges concurrents).
  static Future<bool> _initializeSupabaseForIsolate() async {
    if (_supabaseReady) return true;

    try {
      // ignore: unnecessary_statements
      Supabase.instance.client;
      _supabaseReady = true;
      return true;
    } catch (_) {
      // Pas encore initialisé dans cet isolate — on continue ci-dessous.
    }

    try {
      try {
        await dotenv.load(fileName: '.env');
      } catch (_) {
        // Build de production : la configuration vient de --dart-define.
      }
      if (!AppConfig.isSupabaseConfigured) {
        debugPrint(
          'BackgroundReplyService: Supabase non configuré dans cet isolate',
        );
        return false;
      }
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        publishableKey: AppConfig.supabaseAnonKey,
        authOptions: FlutterAuthClientOptions(
          localStorage: SharedPreferencesLocalStorage(
            persistSessionKey: 'supabase.notification_reply.session',
          ),
        ),
      );
      _supabaseReady = true;
      return true;
    } catch (e) {
      debugPrint('BackgroundReplyService: init Supabase échouée ($e)');
      return false;
    }
  }

  /// Envoie une réponse depuis l'isolate background.
  /// En cas d'échec, le message est mis en queue pour réessai ultérieur.
  /// Retourne true en cas de succès, false en cas d'échec.
  static Future<bool> sendReply({
    required String conversationId,
    required String replyText,
  }) async {
    SharedPreferences? prefs;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }

      if (!await _initializeSupabaseForIsolate()) {
        throw StateError('Supabase indisponible dans cet isolate');
      }
      if (!await SupabaseAuthBridge.instance.ensureAuthenticated()) {
        throw StateError('Session Supabase non établie');
      }

      prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('currentUserId');
      final userDisplayName =
          prefs.getString('currentUserDisplayName') ?? 'Utilisateur';
      final userPhotoUrl = prefs.getString('currentUserPhotoUrl');

      if (userId == null || userId.isEmpty) {
        throw StateError('currentUserId absent du cache background');
      }

      await _persistMessage(
        conversationId: conversationId,
        content: replyText,
        senderId: userId,
        senderName: userDisplayName,
        senderPhotoUrl: userPhotoUrl,
        wasQueued: false,
      );

      return true;
    } catch (e) {
      debugPrint('BackgroundReplyService: sendReply error: $e');
      // En cas d'échec (offline, session absente...), mettre en queue pour
      // que processPendingMessages() réessaie plus tard.
      try {
        prefs ??= await SharedPreferences.getInstance();
        final userId = prefs.getString('currentUserId') ?? '';
        final userDisplayName =
            prefs.getString('currentUserDisplayName') ?? 'Utilisateur';
        final userPhotoUrl = prefs.getString('currentUserPhotoUrl');

        await _enqueueMessage(
          prefs: prefs,
          message: BackgroundPendingMessage(
            conversationId: conversationId,
            content: replyText,
            senderId: userId,
            senderName: userDisplayName,
            senderPhotoUrl: userPhotoUrl,
          ),
        );
      } catch (queueError) {
        debugPrint('BackgroundReplyService: enqueue error: $queueError');
      }
      return false;
    }
  }

  /// Écrit le message dans `messages` puis met à jour l'aperçu de la
  /// conversation — même schéma que `MessageSupabaseDataSource.sendTextMessage`
  /// et `_updateConversationLastMessage` (clés `data` en camelCase, colonne
  /// top-level `last_message_at`), pour que la liste des conversations et le
  /// fil de discussion affichent correctement ce message.
  static Future<void> _persistMessage({
    required String conversationId,
    required String content,
    required String senderId,
    required String senderName,
    String? senderPhotoUrl,
    required bool wasQueued,
  }) async {
    await EncryptionService.instance.initialize();
    final encryptedContent = EncryptionService.instance.encryptText(content);

    final msgId = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    final msgData = <String, dynamic>{
      'senderName': senderName,
      if (senderPhotoUrl != null) 'senderPhotoUrl': senderPhotoUrl,
      'content': encryptedContent,
      'encryptionLevel': 'aes',
      'status': 'sent',
      'readBy': [senderId],
      'readAt': {senderId: now},
      'deliveredTo': [senderId],
      'deliveredAt': {senderId: now},
      'sentFromNotificationReply': true,
      if (wasQueued) 'wasQueued': true,
    };

    await Supabase.instance.client.from('messages').insert({
      'id': msgId,
      'conversation_id': conversationId,
      'sender_id': senderId,
      'type': 'text',
      'created_at': now,
      'data': msgData,
    });

    await _updateConversationLastMessage(
      conversationId: conversationId,
      lastMessage: content,
      senderId: senderId,
      at: now,
    );
  }

  /// Met à jour l'aperçu de dernier message de la conversation.
  /// Reflète exactement `MessageSupabaseDataSource._updateConversationLastMessage`
  /// (mêmes clés `data`, même colonne `last_message_at`) — un ancien jeu de
  /// clés snake_case ici (`last_message`, `unread_counts`...) écrivait dans
  /// des champs que l'UI ne lisait jamais.
  static Future<void> _updateConversationLastMessage({
    required String conversationId,
    required String lastMessage,
    required String senderId,
    required String at,
  }) async {
    try {
      final rows = await Supabase.instance.client
          .from('conversations')
          .select('data, participant_ids')
          .eq('id', conversationId)
          .limit(1);
      if (rows.isEmpty) return;

      final current = Map<String, dynamic>.from(
        (rows.first['data'] as Map<String, dynamic>?) ?? {},
      );
      final participantIds = List<String>.from(
        rows.first['participant_ids'] as List? ?? [],
      );

      final unreadCount = Map<String, dynamic>.from(
        current['unreadCount'] as Map? ?? {},
      );
      for (final pid in participantIds) {
        if (pid != senderId) {
          final cur = (unreadCount[pid] as int?) ?? 0;
          unreadCount[pid] = cur + 1;
        }
      }

      final updated = {
        ...current,
        'lastMessage': lastMessage,
        'lastMessageSenderId': senderId,
        'lastMessageType': 'text',
        'lastMessageStatus': 'sent',
        'unreadCount': unreadCount,
        'lastMessageReadBy': [senderId],
        'lastMessageDeliveredTo': [senderId],
      };

      await Supabase.instance.client
          .from('conversations')
          .update({'last_message_at': at, 'data': updated})
          .eq('id', conversationId);
    } catch (e) {
      // Non critique - le message est déjà envoyé
      debugPrint(
        'BackgroundReplyService: _updateConversationLastMessage error: $e',
      );
    }
  }

  /// Marque une conversation comme lue depuis le background.
  /// Reflète `MessageSupabaseDataSource.markAsRead` : RPC `mark_messages_as_read`
  /// (accusés par message) + fusion `unreadCount`/`lastMessageReadBy` dans
  /// `conversations.data` (aperçu de la liste).
  static Future<bool> markAsRead({required String conversationId}) async {
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      if (!await _initializeSupabaseForIsolate()) return false;
      if (!await SupabaseAuthBridge.instance.ensureAuthenticated()) {
        return false;
      }

      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('currentUserId');
      if (userId == null || userId.isEmpty) return false;

      try {
        await Supabase.instance.client.rpc(
          'mark_messages_as_read',
          params: {'p_conversation_id': conversationId, 'p_user_id': userId},
        );
      } catch (e) {
        debugPrint('BackgroundReplyService: mark_messages_as_read RPC error: $e');
      }

      final rows = await Supabase.instance.client
          .from('conversations')
          .select('data')
          .eq('id', conversationId)
          .limit(1);
      final current = Map<String, dynamic>.from(
        (rows.isNotEmpty ? rows.first['data'] as Map<String, dynamic>? : null) ??
            {},
      );
      final readBy = List<String>.from(
        current['lastMessageReadBy'] as List? ?? [],
      );
      if (!readBy.contains(userId)) readBy.add(userId);

      final unreadCount = Map<String, dynamic>.from(
        current['unreadCount'] as Map? ?? {},
      )..[userId] = 0;

      final updated = {
        ...current,
        'unreadCount': unreadCount,
        'lastMessageReadBy': readBy,
      };

      await Supabase.instance.client
          .from('conversations')
          .update({'data': updated})
          .eq('id', conversationId);
      return true;
    } catch (e) {
      debugPrint('BackgroundReplyService: markAsRead error: $e');
      return false;
    }
  }

  // ================== OFFLINE QUEUE MANAGEMENT ==================

  /// Ajoute un message à la queue
  static Future<void> _enqueueMessage({
    required SharedPreferences prefs,
    required BackgroundPendingMessage message,
  }) async {
    final queue = _getQueue(prefs);
    queue.add(message);
    await _saveQueue(prefs, queue);
  }

  /// Récupère la queue depuis SharedPreferences
  static List<BackgroundPendingMessage> _getQueue(SharedPreferences prefs) {
    final data = prefs.getString(_pendingMessagesKey);
    if (data == null || data.isEmpty) return [];

    try {
      final List<dynamic> jsonList = jsonDecode(data);
      return jsonList
          .map(
            (json) =>
                BackgroundPendingMessage.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Sauvegarde la queue dans SharedPreferences
  static Future<void> _saveQueue(
    SharedPreferences prefs,
    List<BackgroundPendingMessage> queue,
  ) async {
    final jsonList = queue.map((m) => m.toJson()).toList();
    await prefs.setString(_pendingMessagesKey, jsonEncode(jsonList));
  }

  /// Récupère les messages en attente (appelé depuis l'app au démarrage)
  static Future<List<BackgroundPendingMessage>> getPendingMessages() async {
    final prefs = await SharedPreferences.getInstance();
    return _getQueue(prefs);
  }

  /// Traite les messages en attente (appelé quand online, ex. au démarrage
  /// de l'app une fois l'utilisateur connu — voir
  /// `NotificationService.saveTokenForUser`).
  static Future<void> processPendingMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queue = _getQueue(prefs);

      if (queue.isEmpty) return;

      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      if (!await _initializeSupabaseForIsolate()) return;
      if (!await SupabaseAuthBridge.instance.ensureAuthenticated()) return;

      final userId = prefs.getString('currentUserId');
      if (userId == null || userId.isEmpty) return;

      final userDisplayName =
          prefs.getString('currentUserDisplayName') ?? 'Utilisateur';
      final userPhotoUrl = prefs.getString('currentUserPhotoUrl');

      final newQueue = <BackgroundPendingMessage>[];

      for (final message in queue) {
        // Mettre à jour les infos utilisateur si manquantes
        final updatedMessage = BackgroundPendingMessage(
          id: message.id,
          conversationId: message.conversationId,
          content: message.content,
          senderId: message.senderId.isEmpty ? userId : message.senderId,
          senderName:
              message.senderName.isEmpty ? userDisplayName : message.senderName,
          senderPhotoUrl: message.senderPhotoUrl ?? userPhotoUrl,
          createdAt: message.createdAt,
          retryCount: message.retryCount,
        );

        try {
          await _persistMessage(
            conversationId: updatedMessage.conversationId,
            content: updatedMessage.content,
            senderId: updatedMessage.senderId,
            senderName: updatedMessage.senderName,
            senderPhotoUrl: updatedMessage.senderPhotoUrl,
            wasQueued: true,
          );
          // Succès - ne pas remettre en queue
        } catch (e) {
          debugPrint('BackgroundReplyService: retry failed: $e');
          // Échec - remettre en queue si pas trop de retries
          if (updatedMessage.retryCount < _maxRetries) {
            newQueue.add(updatedMessage.copyWithRetry());
          }
          // Sinon, le message est abandonné
        }
      }

      // Sauvegarder la nouvelle queue
      await _saveQueue(prefs, newQueue);
    } catch (e) {
      debugPrint('BackgroundReplyService: processPendingMessages error: $e');
    }
  }

  /// Nettoie les messages trop anciens (> 24h)
  static Future<void> cleanOldMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queue = _getQueue(prefs);

      final cutoff = DateTime.now().subtract(const Duration(hours: 24));
      final filtered = queue.where((m) => m.createdAt.isAfter(cutoff)).toList();

      if (filtered.length != queue.length) {
        await _saveQueue(prefs, filtered);
      }
    } catch (e) {
      // Ignorer les erreurs
    }
  }

  /// Obtient le nombre de messages en attente
  static Future<int> getPendingCount() async {
    final prefs = await SharedPreferences.getInstance();
    return _getQueue(prefs).length;
  }
}
