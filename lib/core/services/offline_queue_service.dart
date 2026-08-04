import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

/// Evenement d'echec de message
class MessageFailureEvent {
  final String messageId;
  final String conversationId;
  final String content;
  final int retryCount;
  final DateTime failedAt;

  MessageFailureEvent({
    required this.messageId,
    required this.conversationId,
    required this.content,
    required this.retryCount,
    required this.failedAt,
  });
}

/// Message en attente d'envoi
class PendingMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String? senderPhotoUrl;
  final String content;
  final String type;
  final String? filePath; // Chemin local du fichier a uploader
  final DateTime createdAt;
  final int retryCount;

  PendingMessage({
    String? id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    this.senderPhotoUrl,
    required this.content,
    this.type = 'text',
    this.filePath,
    DateTime? createdAt,
    this.retryCount = 0,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'conversationId': conversationId,
    'senderId': senderId,
    'senderName': senderName,
    'senderPhotoUrl': senderPhotoUrl,
    'content': content,
    'type': type,
    'filePath': filePath,
    'createdAt': createdAt.toIso8601String(),
    'retryCount': retryCount,
  };

  factory PendingMessage.fromJson(Map<String, dynamic> json) => PendingMessage(
    id: json['id'],
    conversationId: json['conversationId'],
    senderId: json['senderId'],
    senderName: json['senderName'],
    senderPhotoUrl: json['senderPhotoUrl'],
    content: json['content'],
    type: json['type'] ?? 'text',
    filePath: json['filePath'],
    createdAt: DateTime.parse(json['createdAt']).toLocal(),
    retryCount: json['retryCount'] ?? 0,
  );

  PendingMessage copyWith({int? retryCount}) => PendingMessage(
    id: id,
    conversationId: conversationId,
    senderId: senderId,
    senderName: senderName,
    senderPhotoUrl: senderPhotoUrl,
    content: content,
    type: type,
    filePath: filePath,
    createdAt: createdAt,
    retryCount: retryCount ?? this.retryCount,
  );
}

/// Service de gestion de la queue offline
class OfflineQueueService {
  static const String _queueBoxName = 'offline_queue';
  static const String _queueKey = 'pending_messages';
  static const int _maxRetries = 5;

  Box<String>? _box;
  bool _isProcessing = false;
  bool _isInitialized = false;

  /// Stream controller pour les echecs de messages
  final _failureController = StreamController<MessageFailureEvent>.broadcast();

  /// Stream des echecs de messages (pour ecouter et notifier l'utilisateur)
  Stream<MessageFailureEvent> get onMessageFailure => _failureController.stream;

  /// Initialiser le service
  Future<void> init() async {
    if (_isInitialized) return;
    _box = await Hive.openBox<String>(_queueBoxName);
    _isInitialized = true;
  }

  /// Obtenir la queue actuelle
  List<PendingMessage> getQueue() {
    if (_box == null) return [];
    final data = _box!.get(_queueKey);
    if (data == null) return [];

    try {
      final List<dynamic> jsonList = jsonDecode(data);
      return jsonList
          .map((json) => PendingMessage.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('OfflineQueueService: Error parsing queue: $e');
      return [];
    }
  }

  /// Sauvegarder la queue
  Future<void> _saveQueue(List<PendingMessage> queue) async {
    if (_box == null) return;
    final jsonList = queue.map((m) => m.toJson()).toList();
    await _box!.put(_queueKey, jsonEncode(jsonList));
  }

  /// Ajouter un message a la queue
  Future<void> enqueue(PendingMessage message) async {
    await init();
    final queue = getQueue();
    queue.add(message);
    await _saveQueue(queue);
    debugPrint(
      'OfflineQueueService: Message enqueued (${queue.length} pending)',
    );
  }

  /// Retirer un message de la queue
  Future<void> dequeue(String messageId) async {
    final queue = getQueue();
    queue.removeWhere((m) => m.id == messageId);
    await _saveQueue(queue);
  }

  /// Verifier si un message est dans la queue
  bool isInQueue(String messageId) {
    return getQueue().any((m) => m.id == messageId);
  }

  /// Obtenir le nombre de messages en attente
  int get pendingCount => getQueue().length;

  /// Obtenir les messages en attente pour une conversation
  List<PendingMessage> getPendingForConversation(String conversationId) {
    return getQueue().where((m) => m.conversationId == conversationId).toList();
  }

  /// Traiter la queue (appeler quand online)
  Future<void> processQueue({
    required Future<bool> Function(PendingMessage) sendMessage,
  }) async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final queue = getQueue();
      if (queue.isEmpty) return;

      debugPrint(
        'OfflineQueueService: Processing ${queue.length} pending messages',
      );

      for (final message in List.from(queue)) {
        try {
          final success = await sendMessage(message);
          if (success) {
            await dequeue(message.id);
            debugPrint(
              'OfflineQueueService: Message ${message.id} sent successfully',
            );
          } else {
            await _handleFailure(message);
          }
        } catch (e) {
          debugPrint(
            'OfflineQueueService: Error sending message ${message.id}: $e',
          );
          await _handleFailure(message);
        }
      }
    } finally {
      _isProcessing = false;
    }
  }

  /// Gerer l'echec d'envoi
  Future<void> _handleFailure(PendingMessage message) async {
    if (message.retryCount >= _maxRetries) {
      // Trop de retries, marquer comme echoue
      await dequeue(message.id);
      debugPrint(
        'OfflineQueueService: Message ${message.id} failed after $_maxRetries retries',
      );

      // Notifier l'utilisateur via le stream
      _failureController.add(
        MessageFailureEvent(
          messageId: message.id,
          conversationId: message.conversationId,
          content: message.content,
          retryCount: message.retryCount,
          failedAt: DateTime.now(),
        ),
      );
      return;
    }

    // Incrementer le compteur de retry
    final queue = getQueue();
    final index = queue.indexWhere((m) => m.id == message.id);
    if (index != -1) {
      queue[index] = message.copyWith(retryCount: message.retryCount + 1);
      await _saveQueue(queue);
    }
  }

  /// Nettoyer les messages trop anciens (> 24h)
  Future<void> cleanOldMessages() async {
    final queue = getQueue();
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    final filtered = queue.where((m) => m.createdAt.isAfter(cutoff)).toList();

    if (filtered.length != queue.length) {
      await _saveQueue(filtered);
      debugPrint(
        'OfflineQueueService: Cleaned ${queue.length - filtered.length} old messages',
      );
    }
  }

  /// Liberer les ressources
  void dispose() {
    _failureController.close();
  }
}

/// Provider pour le service de queue offline
final offlineQueueServiceProvider = Provider<OfflineQueueService>((ref) {
  final service = OfflineQueueService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provider pour le nombre de messages en attente
final pendingMessagesCountProvider = Provider<int>((ref) {
  return ref.watch(offlineQueueServiceProvider).pendingCount;
});

/// Provider pour les echecs de messages (stream)
final messageFailureStreamProvider = StreamProvider<MessageFailureEvent>((ref) {
  return ref.watch(offlineQueueServiceProvider).onMessageFailure;
});
