import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'encryption_service.dart';

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
class BackgroundReplyService {
  static final BackgroundReplyService _instance =
      BackgroundReplyService._internal();
  factory BackgroundReplyService() => _instance;
  BackgroundReplyService._internal();

  static const String _pendingMessagesKey = 'background_pending_messages';
  static const int _maxRetries = 5;

  /// Envoie une réponse depuis l'isolate background.
  /// En cas d'échec, le message est mis en queue pour réessai ultérieur.
  /// Retourne true en cas de succès, false en cas d'échec.
  static Future<bool> sendReply({
    required String conversationId,
    required String replyText,
  }) async {
    try {
      // 1. S'assurer que Firebase est initialisé
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }

      // 2. Récupérer les infos utilisateur depuis SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('currentUserId');
      final userDisplayName =
          prefs.getString('currentUserDisplayName') ?? 'Utilisateur';
      final userPhotoUrl = prefs.getString('currentUserPhotoUrl');

      if (userId == null || userId.isEmpty) {
        // Mettre en queue pour quand l'utilisateur sera connecté
        await _enqueueMessage(
          prefs: prefs,
          message: BackgroundPendingMessage(
            conversationId: conversationId,
            content: replyText,
            senderId: '',
            senderName: '',
          ),
        );
        return false;
      }

      // 3. Initialiser le service de chiffrement
      await EncryptionService.instance.initialize();
      final encryptedContent = EncryptionService.instance.encryptText(
        replyText,
      );

      // 4. Créer les données du message
      final now = DateTime.now().toUtc().toIso8601String();
      final messageData = {
        'senderId': userId,
        'senderName': userDisplayName,
        'senderPhotoUrl': userPhotoUrl,
        'content': encryptedContent,
        'type': 'text',
        'readBy': [userId],
        'readAt': {userId: now},
        'deliveredTo': [userId],
        'deliveredAt': {userId: now},
        'createdAt': now,
        'sentFromNotificationReply': true, // Flag pour analytics
      };

      // 5. Envoyer à Firebase RTDB
      final database = FirebaseDatabase.instance;
      final messagesRef = database
          .ref()
          .child('messages')
          .child(conversationId);

      final newMessageRef = messagesRef.push();
      await newMessageRef.set(messageData);

      // 6. Mettre à jour les métadonnées de conversation dans Firestore
      await _updateConversationLastMessage(
        conversationId: conversationId,
        lastMessage: replyText,
        senderId: userId,
      );

      return true;
    } catch (e) {
      // En cas d'échec (offline ou autre), mettre en queue
      try {
        final prefs = await SharedPreferences.getInstance();
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
      } catch (_) {
        // Ignorer les erreurs de queue
      }
      return false;
    }
  }

  /// Met à jour les métadonnées de dernière message de la conversation
  static Future<void> _updateConversationLastMessage({
    required String conversationId,
    required String lastMessage,
    required String senderId,
  }) async {
    try {
      await EncryptionService.instance.initialize();
      final encryptedLastMessage = EncryptionService.instance.encryptText(lastMessage);

      final row = await Supabase.instance.client
          .from('conversations')
          .select('data, participant_ids')
          .eq('id', conversationId)
          .maybeSingle();
      if (row == null) return;

      final participants = List<String>.from(row['participant_ids'] as List? ?? []);
      final data = Map<String, dynamic>.from(row['data'] as Map? ?? {});
      final unreadCounts = Map<String, dynamic>.from(data['unread_counts'] as Map? ?? {});
      for (final p in participants) {
        if (p != senderId) {
          unreadCounts[p] = ((unreadCounts[p] as int?) ?? 0) + 1;
        }
      }
      data['last_message'] = encryptedLastMessage;
      data['last_message_sender_id'] = senderId;
      data['last_message_status'] = 'sent';
      data['last_message_at'] = DateTime.now().toUtc().toIso8601String();
      data['unread_counts'] = unreadCounts;

      await Supabase.instance.client
          .from('conversations')
          .update({'data': data, 'updated_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', conversationId);
    } catch (e) {
      // Non critique - le message est déjà envoyé
    }
  }

  /// Marque une conversation comme lue depuis le background
  static Future<bool> markAsRead({required String conversationId}) async {
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('currentUserId');
      if (userId == null || userId.isEmpty) return false;

      final row = await Supabase.instance.client
          .from('conversations')
          .select('data')
          .eq('id', conversationId)
          .maybeSingle();
      if (row == null) return false;

      final data = Map<String, dynamic>.from(row['data'] as Map? ?? {});
      final unreadCounts = Map<String, dynamic>.from(data['unread_counts'] as Map? ?? {});
      unreadCounts[userId] = 0;
      data['unread_counts'] = unreadCounts;

      await Supabase.instance.client
          .from('conversations')
          .update({'data': data, 'updated_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', conversationId);
      return true;
    } catch (e) {
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

  /// Traite les messages en attente (appelé quand online)
  static Future<void> processPendingMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queue = _getQueue(prefs);

      if (queue.isEmpty) return;

      // S'assurer que Firebase est initialisé
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }

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
          // Initialiser le chiffrement
          await EncryptionService.instance.initialize();
          final encryptedContent = EncryptionService.instance.encryptText(
            updatedMessage.content,
          );

          // Créer les données du message
          final now = DateTime.now().toUtc().toIso8601String();
          final messageData = {
            'senderId': updatedMessage.senderId,
            'senderName': updatedMessage.senderName,
            'senderPhotoUrl': updatedMessage.senderPhotoUrl,
            'content': encryptedContent,
            'type': 'text',
            'readBy': [updatedMessage.senderId],
            'readAt': {updatedMessage.senderId: now},
            'deliveredTo': [updatedMessage.senderId],
            'deliveredAt': {updatedMessage.senderId: now},
            'createdAt': now,
            'sentFromNotificationReply': true,
            'wasQueued': true, // Flag pour analytics
          };

          // Envoyer à Firebase RTDB
          final database = FirebaseDatabase.instance;
          final messagesRef = database
              .ref()
              .child('messages')
              .child(updatedMessage.conversationId);
          final newMessageRef = messagesRef.push();
          await newMessageRef.set(messageData);

          // Mettre à jour les métadonnées
          await _updateConversationLastMessage(
            conversationId: updatedMessage.conversationId,
            lastMessage: updatedMessage.content,
            senderId: updatedMessage.senderId,
          );

          // Succès - ne pas remettre en queue
        } catch (e) {
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
      // Ignorer les erreurs globales
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
