# AMELIORATIONS - PERSISTANCE DES MESSAGES ET MEDIAS

> Document genere le 2026-02-23
> Ce document propose des ameliorations pour le systeme de persistance des messages et medias.

---

## TABLE DES MATIERES

1. [Queue d'Envoi Offline](#1-queue-denvoi-offline)
2. [Compression Adaptative](#2-compression-adaptative)
3. [Preload et Cache Predictif](#3-preload-et-cache-predictif)
4. [Cache LRU Intelligent](#4-cache-lru-intelligent)
5. [Synchronisation Differentielle](#5-synchronisation-differentielle)
6. [Export des Conversations](#6-export-des-conversations)
7. [Indicateurs de Progression](#7-indicateurs-de-progression)
8. [Retry Automatique](#8-retry-automatique)
9. [Checklist d'Implementation](#9-checklist-dimplementation)

---

## 1. QUEUE D'ENVOI OFFLINE

### Probleme Actuel
Les messages ne peuvent pas etre envoyes hors ligne. L'utilisateur perd son message s'il n'a pas de connexion.

### Impact
- **UX**: Majeur - Les utilisateurs en zones de faible connectivite ne peuvent pas utiliser l'app
- **Priorite**: Haute

### Solution

#### Etape 1: Creer le service de queue

**Creer le fichier:** `lib/core/services/offline_queue_service.dart`

```dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../providers/connectivity_provider.dart';

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
  })  : id = id ?? const Uuid().v4(),
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
        createdAt: DateTime.parse(json['createdAt']),
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

  late Box<String> _box;
  bool _isProcessing = false;

  /// Initialiser le service
  Future<void> init() async {
    _box = await Hive.openBox<String>(_queueBoxName);
  }

  /// Obtenir la queue actuelle
  List<PendingMessage> getQueue() {
    final data = _box.get(_queueKey);
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
    final jsonList = queue.map((m) => m.toJson()).toList();
    await _box.put(_queueKey, jsonEncode(jsonList));
  }

  /// Ajouter un message a la queue
  Future<void> enqueue(PendingMessage message) async {
    final queue = getQueue();
    queue.add(message);
    await _saveQueue(queue);
    debugPrint('OfflineQueueService: Message enqueued (${queue.length} pending)');
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

      debugPrint('OfflineQueueService: Processing ${queue.length} pending messages');

      for (final message in List.from(queue)) {
        try {
          final success = await sendMessage(message);
          if (success) {
            await dequeue(message.id);
            debugPrint('OfflineQueueService: Message ${message.id} sent successfully');
          } else {
            await _handleFailure(message);
          }
        } catch (e) {
          debugPrint('OfflineQueueService: Error sending message ${message.id}: $e');
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
      debugPrint('OfflineQueueService: Message ${message.id} failed after $_maxRetries retries');
      // TODO: Notifier l'utilisateur
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
      debugPrint('OfflineQueueService: Cleaned ${queue.length - filtered.length} old messages');
    }
  }
}

/// Provider pour le service de queue offline
final offlineQueueServiceProvider = Provider<OfflineQueueService>((ref) {
  return OfflineQueueService();
});

/// Provider pour le nombre de messages en attente
final pendingMessagesCountProvider = Provider<int>((ref) {
  return ref.watch(offlineQueueServiceProvider).pendingCount;
});
```

#### Etape 2: Integrer dans le message provider

**Modifier:** `lib/features/messages/presentation/providers/message_provider.dart`

```dart
// Dans SendMessageNotifier, modifier sendText:

Future<void> sendText({
  required String conversationId,
  required String content,
  String? replyToId,
}) async {
  final currentUser = _ref.read(currentUserAsyncProvider).valueOrNull;
  if (currentUser == null) return;

  // Verifier la connectivite
  final isOnline = _ref.read(connectivityNotifierProvider);
  
  if (!isOnline) {
    // Mode offline: ajouter a la queue
    final pendingMessage = PendingMessage(
      conversationId: conversationId,
      senderId: currentUser.id,
      senderName: currentUser.displayName ?? 'Utilisateur',
      senderPhotoUrl: currentUser.photoUrl,
      content: content,
      type: 'text',
    );
    
    await _ref.read(offlineQueueServiceProvider).enqueue(pendingMessage);
    
    // Ajouter un message optimiste local
    _addOptimisticMessage(conversationId, pendingMessage);
    
    return;
  }

  // Mode online: envoyer normalement
  // ... code existant ...
}
```

#### Etape 3: Ecouter la connectivite pour traiter la queue

**Modifier:** `lib/app.dart`

```dart
// Dans _AppState.initState(), ajouter:

@override
void initState() {
  super.initState();
  
  // Initialiser la queue offline
  ref.read(offlineQueueServiceProvider).init();
  
  // Ecouter les changements de connectivite
  ref.listenManual(connectivityNotifierProvider, (previous, next) {
    if (next == true && previous == false) {
      // Reconnecte -> traiter la queue
      _processOfflineQueue();
    }
  });
}

Future<void> _processOfflineQueue() async {
  final queueService = ref.read(offlineQueueServiceProvider);
  final messageRepository = ref.read(messageRepositoryProvider);
  
  await queueService.processQueue(
    sendMessage: (pending) async {
      try {
        await messageRepository.sendTextMessage(
          conversationId: pending.conversationId,
          senderId: pending.senderId,
          senderName: pending.senderName,
          content: pending.content,
        );
        return true;
      } catch (e) {
        return false;
      }
    },
  );
}
```

#### Etape 4: Ajouter l'indicateur visuel

**Modifier:** `lib/features/messages/presentation/widgets/message_bubble.dart`

```dart
// Ajouter dans le build, apres l'icone de statut:

if (widget.message.status == 'pending') ...[
  const SizedBox(width: 4),
  const Icon(
    Icons.schedule,
    size: 12,
    color: Colors.orange,
  ),
  const SizedBox(width: 2),
  Text(
    'En attente',
    style: TextStyle(
      fontSize: 10,
      color: Colors.orange[700],
      fontStyle: FontStyle.italic,
    ),
  ),
],
```

---

## 2. COMPRESSION ADAPTATIVE

### Probleme Actuel
La compression des medias est fixe, sans tenir compte du type de connexion (WiFi vs 3G/4G).

### Impact
- **Performance**: Moyen - Consommation de data inutile sur WiFi, lenteur sur 3G
- **Priorite**: Moyenne

### Solution

#### Creer le service de compression adaptative

**Creer le fichier:** `lib/core/services/adaptive_compression_service.dart`

```dart
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_compress/video_compress.dart';

/// Parametres de compression selon la connexion
class CompressionSettings {
  final int imageQuality;
  final int maxImageWidth;
  final int maxImageHeight;
  final VideoQuality videoQuality;
  final int maxVideoDurationSeconds;

  const CompressionSettings({
    required this.imageQuality,
    required this.maxImageWidth,
    required this.maxImageHeight,
    required this.videoQuality,
    required this.maxVideoDurationSeconds,
  });

  /// Parametres pour WiFi (haute qualite)
  static const wifi = CompressionSettings(
    imageQuality: 85,
    maxImageWidth: 1920,
    maxImageHeight: 1440,
    videoQuality: VideoQuality.HighestQuality,
    maxVideoDurationSeconds: 600, // 10 minutes
  );

  /// Parametres pour 4G (qualite moyenne)
  static const mobile4G = CompressionSettings(
    imageQuality: 70,
    maxImageWidth: 1280,
    maxImageHeight: 960,
    videoQuality: VideoQuality.MediumQuality,
    maxVideoDurationSeconds: 300, // 5 minutes
  );

  /// Parametres pour 3G ou connexion lente (basse qualite)
  static const mobileSlow = CompressionSettings(
    imageQuality: 50,
    maxImageWidth: 800,
    maxImageHeight: 600,
    videoQuality: VideoQuality.LowQuality,
    maxVideoDurationSeconds: 120, // 2 minutes
  );
}

/// Service de compression adaptative
class AdaptiveCompressionService {
  /// Obtenir les parametres optimaux selon la connexion
  Future<CompressionSettings> getOptimalSettings() async {
    final connectivityResult = await Connectivity().checkConnectivity();

    switch (connectivityResult) {
      case ConnectivityResult.wifi:
        return CompressionSettings.wifi;
      case ConnectivityResult.mobile:
        // TODO: Detecter 3G vs 4G/5G si possible
        return CompressionSettings.mobile4G;
      case ConnectivityResult.ethernet:
        return CompressionSettings.wifi;
      default:
        return CompressionSettings.mobileSlow;
    }
  }

  /// Compresser une image avec les parametres adaptatifs
  Future<File?> compressImage(File file) async {
    final settings = await getOptimalSettings();
    final tempDir = await getTemporaryDirectory();
    final targetPath = '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final result = await FlutterImageCompress.compressAndGetFile(
      file.path,
      targetPath,
      quality: settings.imageQuality,
      minWidth: settings.maxImageWidth,
      minHeight: settings.maxImageHeight,
    );

    return result != null ? File(result.path) : null;
  }

  /// Compresser une video avec les parametres adaptatifs
  Future<MediaInfo?> compressVideo(File file) async {
    final settings = await getOptimalSettings();

    // Verifier la duree
    final info = await VideoCompress.getMediaInfo(file.path);
    if (info.duration != null &&
        info.duration! > settings.maxVideoDurationSeconds * 1000) {
      throw Exception(
        'Video trop longue. Maximum: ${settings.maxVideoDurationSeconds ~/ 60} minutes',
      );
    }

    return await VideoCompress.compressVideo(
      file.path,
      quality: settings.videoQuality,
      deleteOrigin: false,
    );
  }

  /// Estimer la taille finale apres compression
  Future<int> estimateCompressedSize(File file, String type) async {
    final settings = await getOptimalSettings();
    final originalSize = await file.length();

    if (type == 'image') {
      // Estimation basee sur le ratio de qualite
      return (originalSize * settings.imageQuality / 100).toInt();
    } else if (type == 'video') {
      // Estimation grossiere basee sur la qualite
      final qualityFactor = settings.videoQuality == VideoQuality.HighestQuality
          ? 0.8
          : settings.videoQuality == VideoQuality.MediumQuality
              ? 0.5
              : 0.3;
      return (originalSize * qualityFactor).toInt();
    }

    return originalSize;
  }
}
```

#### Integrer dans l'upload de medias

**Modifier:** `lib/features/messages/data/datasources/message_remote_datasource.dart`

```dart
// Dans la methode uploadMediaFile ou sendMediaMessage:

Future<String> uploadMediaFile(File file, String type) async {
  final compressionService = AdaptiveCompressionService();
  
  File fileToUpload = file;
  
  // Compresser selon le type
  if (type == 'image') {
    final compressed = await compressionService.compressImage(file);
    if (compressed != null) {
      fileToUpload = compressed;
    }
  } else if (type == 'video') {
    final compressed = await compressionService.compressVideo(file);
    if (compressed?.file != null) {
      fileToUpload = compressed!.file!;
    }
  }
  
  // Uploader le fichier compresse
  // ... reste du code ...
}
```

---

## 3. PRELOAD ET CACHE PREDICTIF

### Probleme Actuel
Les medias sont telecharges uniquement a la demande, causant des temps d'attente.

### Impact
- **UX**: Moyen - Latence visible lors du scroll dans les conversations avec medias
- **Priorite**: Moyenne

### Solution

**Creer le fichier:** `lib/core/services/media_preload_service.dart`

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../../features/messages/domain/entities/message_entity.dart';

/// Service de preload predictif des medias
class MediaPreloadService {
  static final MediaPreloadService _instance = MediaPreloadService._internal();
  factory MediaPreloadService() => _instance;
  MediaPreloadService._internal();

  final _preloadQueue = <String>[];
  final _preloadedUrls = <String>{};
  final _failedUrls = <String>{};
  bool _isProcessing = false;

  /// Nombre de medias a precharger en avance
  static const int _preloadAhead = 5;

  /// Precharger les medias visibles + suivants
  void onMessagesVisible(
    List<MessageEntity> messages,
    int firstVisibleIndex,
    int lastVisibleIndex,
  ) {
    // Selectionner les messages avec medias a precharger
    final mediaMessages = messages
        .skip(firstVisibleIndex)
        .take((lastVisibleIndex - firstVisibleIndex) + _preloadAhead)
        .where((m) => _hasPreloadableMedia(m))
        .toList();

    for (final message in mediaMessages) {
      final url = message.fileUrl ?? message.thumbnailUrl;
      if (url != null && !_preloadedUrls.contains(url) && !_failedUrls.contains(url)) {
        if (!_preloadQueue.contains(url)) {
          _preloadQueue.add(url);
        }
      }
    }

    _processQueue();
  }

  /// Verifier si un message a un media preloadable
  bool _hasPreloadableMedia(MessageEntity message) {
    if (message.deletedForEveryone) return false;
    
    final type = message.type;
    return type == MessageType.image ||
        type == MessageType.video ||
        (type == MessageType.audio && message.fileUrl != null);
  }

  /// Traiter la queue de preload
  Future<void> _processQueue() async {
    if (_isProcessing || _preloadQueue.isEmpty) return;
    _isProcessing = true;

    try {
      while (_preloadQueue.isNotEmpty) {
        final url = _preloadQueue.removeAt(0);
        
        try {
          await DefaultCacheManager().downloadFile(url);
          _preloadedUrls.add(url);
          debugPrint('MediaPreloadService: Preloaded $url');
        } catch (e) {
          _failedUrls.add(url);
          debugPrint('MediaPreloadService: Failed to preload $url: $e');
        }
      }
    } finally {
      _isProcessing = false;
    }
  }

  /// Verifier si un media est deja en cache
  Future<bool> isInCache(String url) async {
    final fileInfo = await DefaultCacheManager().getFileFromCache(url);
    return fileInfo != null;
  }

  /// Nettoyer le cache des URLs echouees (pour retry)
  void clearFailedUrls() {
    _failedUrls.clear();
  }

  /// Statistiques de cache
  Map<String, int> get stats => {
        'preloaded': _preloadedUrls.length,
        'failed': _failedUrls.length,
        'queued': _preloadQueue.length,
      };
}
```

#### Integrer dans l'ecran de conversation

**Modifier:** `lib/features/messages/presentation/screens/conversation_screen.dart`

```dart
// Dans le build du ListView des messages:

NotificationListener<ScrollNotification>(
  onNotification: (scrollInfo) {
    if (scrollInfo is ScrollUpdateNotification) {
      // Calculer les indices visibles
      final firstVisible = _getFirstVisibleIndex();
      final lastVisible = _getLastVisibleIndex();
      
      // Precharger les medias
      MediaPreloadService().onMessagesVisible(
        messages,
        firstVisible,
        lastVisible,
      );
    }
    return false;
  },
  child: ListView.builder(
    // ... configuration existante ...
  ),
),
```

---

## 4. CACHE LRU INTELLIGENT

### Probleme Actuel
Le cache Hive a une limite fixe de 100 messages sans politique d'expiration.

### Impact
- **Performance**: Moyen - Peut manquer de cache ou en avoir trop
- **Priorite**: Moyenne

### Solution

**Modifier:** `lib/core/services/cache_service.dart`

```dart
// Ajouter ces constantes et methodes:

class CacheService {
  static const Duration _cacheExpiration = Duration(days: 7);
  static const int _maxCacheSizeBytes = 50 * 1024 * 1024; // 50 MB
  static const int _maxMessagesPerConversation = 200;

  // Classe pour les entrees de cache avec metadata
  Map<String, dynamic> _createCacheEntry(dynamic data) => {
        'data': data,
        'cachedAt': DateTime.now().toIso8601String(),
        'lastAccessedAt': DateTime.now().toIso8601String(),
      };

  // Mettre a jour le timestamp d'acces
  Future<void> _touchEntry(String boxName, String key) async {
    final box = Hive.box<String>(boxName);
    final data = box.get(key);
    if (data != null) {
      try {
        final entry = jsonDecode(data) as Map<String, dynamic>;
        entry['lastAccessedAt'] = DateTime.now().toIso8601String();
        await box.put(key, jsonEncode(entry));
      } catch (e) {
        // Ignorer les erreurs de format
      }
    }
  }

  /// Cacher les messages avec politique LRU
  Future<void> cacheMessagesLRU(
    String conversationId,
    List<Map<String, dynamic>> messages,
  ) async {
    final box = Hive.box<String>(_messagesBox);
    final key = _messagesKey(conversationId);

    // Recuperer les messages existants
    final existingData = box.get(key);
    List<Map<String, dynamic>> existingMessages = [];

    if (existingData != null) {
      try {
        final entry = jsonDecode(existingData) as Map<String, dynamic>;
        existingMessages = (entry['data'] as List<dynamic>)
            .cast<Map<String, dynamic>>();
      } catch (e) {
        // Cache corrompu, repartir de zero
      }
    }

    // Merger les messages (nouveaux ecrasent anciens par ID)
    final messagesMap = <String, Map<String, dynamic>>{};
    for (final msg in existingMessages) {
      messagesMap[msg['id'] as String] = msg;
    }
    for (final msg in messages) {
      messagesMap[msg['id'] as String] = msg;
    }

    // Convertir en liste et trier par date
    var mergedMessages = messagesMap.values.toList();
    mergedMessages.sort((a, b) {
      final aTime = a['createdAt'] as String? ?? '';
      final bTime = b['createdAt'] as String? ?? '';
      return bTime.compareTo(aTime); // Plus recent en premier
    });

    // Limiter le nombre de messages
    if (mergedMessages.length > _maxMessagesPerConversation) {
      mergedMessages = mergedMessages.take(_maxMessagesPerConversation).toList();
    }

    // Sauvegarder avec metadata
    final entry = _createCacheEntry(mergedMessages);
    await box.put(key, jsonEncode(entry));

    // Verifier la taille totale du cache
    await _enforceMaxCacheSize();
  }

  /// Appliquer la limite de taille du cache (LRU eviction)
  Future<void> _enforceMaxCacheSize() async {
    final box = Hive.box<String>(_messagesBox);

    // Calculer la taille actuelle
    int totalSize = 0;
    final entries = <String, _CacheEntryInfo>{};

    for (final key in box.keys) {
      final data = box.get(key as String);
      if (data != null) {
        totalSize += data.length;
        try {
          final entry = jsonDecode(data) as Map<String, dynamic>;
          entries[key] = _CacheEntryInfo(
            key: key,
            size: data.length,
            lastAccessedAt: DateTime.parse(
              entry['lastAccessedAt'] as String? ?? DateTime.now().toIso8601String(),
            ),
          );
        } catch (e) {
          // Entree corrompue, la supprimer
          await box.delete(key);
          totalSize -= data.length;
        }
      }
    }

    // Si depasse la limite, supprimer les moins recemment accedes
    if (totalSize > _maxCacheSizeBytes) {
      // Trier par dernier acces (plus ancien en premier)
      final sortedEntries = entries.values.toList()
        ..sort((a, b) => a.lastAccessedAt.compareTo(b.lastAccessedAt));

      // Supprimer jusqu'a atteindre 80% de la limite
      final targetSize = (_maxCacheSizeBytes * 0.8).toInt();
      for (final entry in sortedEntries) {
        if (totalSize <= targetSize) break;
        await box.delete(entry.key);
        totalSize -= entry.size;
        debugPrint('CacheService: Evicted ${entry.key} (LRU)');
      }
    }
  }

  /// Nettoyer les entrees expirees
  Future<int> cleanExpiredEntries() async {
    final box = Hive.box<String>(_messagesBox);
    final now = DateTime.now();
    int cleanedCount = 0;

    for (final key in box.keys.toList()) {
      final data = box.get(key as String);
      if (data != null) {
        try {
          final entry = jsonDecode(data) as Map<String, dynamic>;
          final cachedAt = DateTime.parse(
            entry['cachedAt'] as String? ?? DateTime.now().toIso8601String(),
          );

          if (now.difference(cachedAt) > _cacheExpiration) {
            await box.delete(key);
            cleanedCount++;
          }
        } catch (e) {
          // Entree corrompue
          await box.delete(key);
          cleanedCount++;
        }
      }
    }

    if (cleanedCount > 0) {
      debugPrint('CacheService: Cleaned $cleanedCount expired entries');
    }

    return cleanedCount;
  }

  /// Obtenir les statistiques du cache
  Future<Map<String, dynamic>> getCacheStats() async {
    final box = Hive.box<String>(_messagesBox);
    int totalSize = 0;
    int entryCount = 0;

    for (final key in box.keys) {
      final data = box.get(key as String);
      if (data != null) {
        totalSize += data.length;
        entryCount++;
      }
    }

    return {
      'totalSizeBytes': totalSize,
      'totalSizeMB': (totalSize / (1024 * 1024)).toStringAsFixed(2),
      'entryCount': entryCount,
      'maxSizeMB': (_maxCacheSizeBytes / (1024 * 1024)).toStringAsFixed(0),
      'usagePercent': ((totalSize / _maxCacheSizeBytes) * 100).toStringAsFixed(1),
    };
  }
}

class _CacheEntryInfo {
  final String key;
  final int size;
  final DateTime lastAccessedAt;

  _CacheEntryInfo({
    required this.key,
    required this.size,
    required this.lastAccessedAt,
  });
}
```

---

## 5. SYNCHRONISATION DIFFERENTIELLE

### Probleme Actuel
Rechargement complet des messages a chaque ouverture de conversation.

### Impact
- **Performance**: Moyen - Consommation de data et temps de chargement inutiles
- **Priorite**: Moyenne

### Solution

**Modifier:** `lib/features/messages/data/datasources/message_remote_datasource.dart`

```dart
// Ajouter cette methode:

/// Recuperer uniquement les messages depuis un timestamp
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

    if (!snapshot.exists) return [];

    final messages = <MessageModel>[];
    final data = snapshot.value as Map<dynamic, dynamic>;

    for (final entry in data.entries) {
      final messageData = Map<String, dynamic>.from(entry.value as Map);
      messageData['id'] = entry.key;
      messages.add(MessageModel.fromRTDB(messageData));
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
```

**Modifier:** `lib/features/messages/data/repositories/message_repository_impl.dart`

```dart
// Ajouter cette methode:

/// Synchroniser les messages de maniere incrementale
Future<Either<Failure, List<MessageEntity>>> syncMessagesIncremental({
  required String conversationId,
}) async {
  try {
    // 1. Obtenir le dernier timestamp du cache
    final cachedMessages = cacheService.getCachedMessages(conversationId);
    
    DateTime lastTimestamp;
    if (cachedMessages.isNotEmpty) {
      // Prendre le timestamp du message le plus recent
      lastTimestamp = cachedMessages
          .map((m) => m['createdAt'] as String?)
          .where((t) => t != null)
          .map((t) => DateTime.parse(t!))
          .reduce((a, b) => a.isAfter(b) ? a : b);
    } else {
      // Pas de cache, charger les 30 derniers jours
      lastTimestamp = DateTime.now().subtract(const Duration(days: 30));
    }

    // 2. Recuperer seulement les nouveaux messages
    final newMessages = await remoteDataSource.getMessagesSince(
      conversationId: conversationId,
      since: lastTimestamp,
    );

    debugPrint('SyncIncremental: Found ${newMessages.length} new messages since $lastTimestamp');

    // 3. Merger avec le cache
    if (newMessages.isNotEmpty) {
      final newMessagesJson = newMessages.map((m) => m.toJson()).toList();
      await cacheService.cacheMessagesLRU(conversationId, newMessagesJson);
    }

    // 4. Retourner tous les messages du cache
    final allCachedMessages = cacheService.getCachedMessages(conversationId);
    final entities = allCachedMessages
        .map((json) => MessageModel.fromJson(json).toEntity())
        .toList();

    return Right(entities);
  } on ServerException catch (e) {
    return Left(ServerFailure(e.message));
  } catch (e) {
    return Left(ServerFailure('Erreur de synchronisation: $e'));
  }
}
```

---

## 6. EXPORT DES CONVERSATIONS

### Probleme Actuel
Les utilisateurs ne peuvent pas exporter leurs conversations.

### Impact
- **Feature**: Nouveau - Demande frequente des utilisateurs
- **Priorite**: Basse

### Solution

**Creer le fichier:** `lib/features/messages/domain/services/message_export_service.dart`

```dart
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../entities/conversation_entity.dart';
import '../entities/message_entity.dart';

enum ExportFormat { txt, json, html }

/// Service d'export des conversations
class MessageExportService {
  /// Exporter une conversation
  Future<File> exportConversation({
    required ConversationEntity conversation,
    required List<MessageEntity> messages,
    required ExportFormat format,
    bool includeMedia = false,
  }) async {
    switch (format) {
      case ExportFormat.txt:
        return _exportAsText(conversation, messages);
      case ExportFormat.json:
        return _exportAsJson(conversation, messages);
      case ExportFormat.html:
        return _exportAsHtml(conversation, messages, includeMedia);
    }
  }

  /// Export format texte simple
  Future<File> _exportAsText(
    ConversationEntity conversation,
    List<MessageEntity> messages,
  ) async {
    final buffer = StringBuffer();
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    // En-tete
    buffer.writeln('=' * 50);
    buffer.writeln('CONVERSATION DIASPO NIGER');
    buffer.writeln('=' * 50);
    buffer.writeln();
    buffer.writeln('Avec: ${conversation.displayName}');
    buffer.writeln('Exportee le: ${dateFormat.format(DateTime.now())}');
    buffer.writeln('Nombre de messages: ${messages.length}');
    buffer.writeln();
    buffer.writeln('-' * 50);
    buffer.writeln();

    // Messages (du plus ancien au plus recent)
    for (final message in messages.reversed) {
      final time = message.createdAt != null
          ? dateFormat.format(message.createdAt!)
          : 'Date inconnue';
      final sender = message.senderName;

      String content;
      if (message.deletedForEveryone) {
        content = '[Message supprime]';
      } else if (message.type == MessageType.text) {
        content = message.content;
      } else if (message.type == MessageType.image) {
        content = '[Image] ${message.content.isNotEmpty ? message.content : ""}';
      } else if (message.type == MessageType.video) {
        content = '[Video] ${message.content.isNotEmpty ? message.content : ""}';
      } else if (message.type == MessageType.audio) {
        content = '[Message vocal - ${message.audioDuration ?? 0}s]';
      } else if (message.type == MessageType.document) {
        content = '[Document: ${message.fileName ?? "fichier"}]';
      } else {
        content = message.content;
      }

      buffer.writeln('[$time] $sender:');
      buffer.writeln(content);
      buffer.writeln();
    }

    // Sauvegarder le fichier
    final dir = await getTemporaryDirectory();
    final fileName = 'conversation_${conversation.id}_${DateTime.now().millisecondsSinceEpoch}.txt';
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(buffer.toString());

    return file;
  }

  /// Export format JSON
  Future<File> _exportAsJson(
    ConversationEntity conversation,
    List<MessageEntity> messages,
  ) async {
    final export = {
      'conversation': {
        'id': conversation.id,
        'displayName': conversation.displayName,
        'type': conversation.type.name,
        'exportedAt': DateTime.now().toIso8601String(),
      },
      'messages': messages.map((m) => {
        'id': m.id,
        'senderId': m.senderId,
        'senderName': m.senderName,
        'content': m.deletedForEveryone ? '[Message supprime]' : m.content,
        'type': m.type.name,
        'createdAt': m.createdAt?.toIso8601String(),
        'isDeleted': m.deletedForEveryone,
      }).toList(),
    };

    final dir = await getTemporaryDirectory();
    final fileName = 'conversation_${conversation.id}_${DateTime.now().millisecondsSinceEpoch}.json';
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(jsonEncode(export));

    return file;
  }

  /// Export format HTML
  Future<File> _exportAsHtml(
    ConversationEntity conversation,
    List<MessageEntity> messages,
    bool includeMedia,
  ) async {
    final buffer = StringBuffer();
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    buffer.writeln('''
<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Conversation avec ${conversation.displayName}</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; background: #f5f5f5; }
    .header { background: #075E54; color: white; padding: 20px; border-radius: 10px; margin-bottom: 20px; }
    .message { margin: 10px 0; padding: 10px 15px; border-radius: 10px; max-width: 80%; }
    .message.sent { background: #DCF8C6; margin-left: auto; }
    .message.received { background: white; }
    .sender { font-weight: bold; font-size: 0.9em; color: #075E54; }
    .time { font-size: 0.75em; color: #999; margin-top: 5px; }
    .deleted { font-style: italic; color: #999; }
    .media { color: #666; font-style: italic; }
  </style>
</head>
<body>
  <div class="header">
    <h1>Conversation avec ${conversation.displayName}</h1>
    <p>Exportee le ${dateFormat.format(DateTime.now())}</p>
    <p>${messages.length} messages</p>
  </div>
''');

    for (final message in messages.reversed) {
      final time = message.createdAt != null
          ? dateFormat.format(message.createdAt!)
          : '';
      final isSent = message.senderId == conversation.otherParticipantId ? false : true;

      String content;
      if (message.deletedForEveryone) {
        content = '<span class="deleted">Message supprime</span>';
      } else if (message.type == MessageType.image && includeMedia && message.fileUrl != null) {
        content = '<img src="${message.fileUrl}" style="max-width:100%;" alt="Image">';
      } else if (message.type != MessageType.text) {
        content = '<span class="media">[${message.type.name}]</span>';
      } else {
        content = message.content.replaceAll('\n', '<br>');
      }

      buffer.writeln('''
  <div class="message ${isSent ? 'sent' : 'received'}">
    <div class="sender">${message.senderName}</div>
    <div>$content</div>
    <div class="time">$time</div>
  </div>
''');
    }

    buffer.writeln('</body></html>');

    final dir = await getTemporaryDirectory();
    final fileName = 'conversation_${conversation.id}_${DateTime.now().millisecondsSinceEpoch}.html';
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(buffer.toString());

    return file;
  }

  /// Partager le fichier exporte
  Future<void> shareExportedFile(File file) async {
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Export de conversation Diaspo Niger',
    );
  }
}
```

---

## 7. INDICATEURS DE PROGRESSION

### Probleme Actuel
La progression des uploads est basique, sans estimation de temps.

### Impact
- **UX**: Faible - Amelioration mineure
- **Priorite**: Basse

### Solution

**Creer le fichier:** `lib/features/messages/presentation/widgets/upload_progress_widget.dart`

```dart
import 'package:flutter/material.dart';

/// Modele pour la progression d'upload
class UploadProgress {
  final int bytesSent;
  final int totalBytes;
  final DateTime startTime;

  UploadProgress({
    required this.bytesSent,
    required this.totalBytes,
    required this.startTime,
  });

  double get percentage => totalBytes > 0 ? bytesSent / totalBytes : 0;

  int get bytesPerSecond {
    final elapsed = DateTime.now().difference(startTime).inSeconds;
    return elapsed > 0 ? bytesSent ~/ elapsed : 0;
  }

  Duration? get estimatedTimeRemaining {
    if (bytesPerSecond == 0) return null;
    final remaining = totalBytes - bytesSent;
    return Duration(seconds: remaining ~/ bytesPerSecond);
  }

  String get formattedBytesSent => _formatBytes(bytesSent);
  String get formattedTotalBytes => _formatBytes(totalBytes);
  String get formattedSpeed => '${_formatBytes(bytesPerSecond)}/s';

  String get formattedTimeRemaining {
    final remaining = estimatedTimeRemaining;
    if (remaining == null) return '';
    
    if (remaining.inMinutes > 0) {
      return '~${remaining.inMinutes}min ${remaining.inSeconds % 60}s';
    }
    return '~${remaining.inSeconds}s';
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Widget d'affichage de la progression
class UploadProgressWidget extends StatelessWidget {
  final UploadProgress progress;
  final VoidCallback? onCancel;

  const UploadProgressWidget({
    super.key,
    required this.progress,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Barre de progression
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.percentage,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          
          // Infos de progression
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Taille envoyee / totale
              Text(
                '${progress.formattedBytesSent} / ${progress.formattedTotalBytes}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                ),
              ),
              
              // Pourcentage
              Text(
                '${(progress.percentage * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          
          // Vitesse et temps restant
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Vitesse
              Text(
                progress.formattedSpeed,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 10,
                ),
              ),
              
              // Temps restant
              if (progress.formattedTimeRemaining.isNotEmpty)
                Text(
                  progress.formattedTimeRemaining,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 10,
                  ),
                ),
            ],
          ),
          
          // Bouton annuler
          if (onCancel != null) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: onCancel,
              child: const Text(
                'Annuler',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
```

---

## 8. RETRY AUTOMATIQUE

### Probleme Actuel
Pas de retry automatique en cas d'echec d'upload.

### Impact
- **Fiabilite**: Moyen - Les uploads echouent definitivement
- **Priorite**: Moyenne

### Solution

**Creer le fichier:** `lib/core/utils/retry_helper.dart`

```dart
import 'dart:async';
import 'package:flutter/foundation.dart';

/// Configuration pour le retry
class RetryConfig {
  final int maxAttempts;
  final Duration initialDelay;
  final double backoffFactor;
  final Duration maxDelay;
  final bool Function(Exception)? retryIf;

  const RetryConfig({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(seconds: 1),
    this.backoffFactor = 2.0,
    this.maxDelay = const Duration(seconds: 30),
    this.retryIf,
  });

  static const defaultConfig = RetryConfig();

  static const uploadConfig = RetryConfig(
    maxAttempts: 5,
    initialDelay: Duration(seconds: 2),
    backoffFactor: 1.5,
    maxDelay: Duration(minutes: 1),
  );
}

/// Helper pour les operations avec retry automatique
class RetryHelper {
  /// Executer une operation avec retry exponentiel
  static Future<T> withRetry<T>({
    required Future<T> Function() operation,
    RetryConfig config = RetryConfig.defaultConfig,
    void Function(int attempt, Exception error)? onRetry,
  }) async {
    int attempts = 0;
    Duration delay = config.initialDelay;

    while (true) {
      try {
        attempts++;
        return await operation();
      } on Exception catch (e) {
        // Verifier si on doit retry cette exception
        if (config.retryIf != null && !config.retryIf!(e)) {
          rethrow;
        }

        // Verifier si on a atteint le max d'essais
        if (attempts >= config.maxAttempts) {
          debugPrint('RetryHelper: Failed after $attempts attempts');
          rethrow;
        }

        // Notifier le callback
        onRetry?.call(attempts, e);

        debugPrint(
          'RetryHelper: Attempt $attempts failed, retrying in ${delay.inSeconds}s... Error: $e',
        );

        // Attendre avant de retry
        await Future.delayed(delay);

        // Calculer le prochain delai (avec cap)
        delay = Duration(
          milliseconds: (delay.inMilliseconds * config.backoffFactor).toInt(),
        );
        if (delay > config.maxDelay) {
          delay = config.maxDelay;
        }
      }
    }
  }

  /// Executer plusieurs operations en parallele avec retry individuel
  static Future<List<T>> withRetryAll<T>({
    required List<Future<T> Function()> operations,
    RetryConfig config = RetryConfig.defaultConfig,
  }) async {
    return Future.wait(
      operations.map((op) => withRetry(operation: op, config: config)),
    );
  }
}

/// Extension pour simplifier l'utilisation
extension RetryFuture<T> on Future<T> Function() {
  Future<T> withRetry({RetryConfig config = RetryConfig.defaultConfig}) {
    return RetryHelper.withRetry(operation: this, config: config);
  }
}
```

#### Integrer dans les uploads

**Modifier:** `lib/features/messages/data/datasources/message_remote_datasource.dart`

```dart
// Dans uploadMediaFile:

Future<String> uploadMediaFile({
  required File file,
  required String conversationId,
  required String fileName,
}) async {
  return RetryHelper.withRetry(
    operation: () async {
      final ref = _storage.ref('messages/$conversationId/$fileName');
      final uploadTask = ref.putFile(file);
      
      await uploadTask;
      return await ref.getDownloadURL();
    },
    config: RetryConfig.uploadConfig,
    onRetry: (attempt, error) {
      debugPrint('Upload retry $attempt: $error');
    },
  );
}
```

---

## 9. CHECKLIST D'IMPLEMENTATION

### Haute Priorite
- [ ] Implementer la queue d'envoi offline (`offline_queue_service.dart`)
- [ ] Integrer la queue dans `message_provider.dart`
- [ ] Ajouter l'indicateur visuel "En attente" dans `message_bubble.dart`
- [ ] Implementer le retry automatique (`retry_helper.dart`)

### Moyenne Priorite
- [ ] Implementer la compression adaptative (`adaptive_compression_service.dart`)
- [ ] Implementer le preload predictif (`media_preload_service.dart`)
- [ ] Ameliorer le cache avec LRU (`cache_service.dart`)
- [ ] Implementer la sync differentielle

### Basse Priorite
- [ ] Ajouter l'export de conversations (`message_export_service.dart`)
- [ ] Ameliorer les indicateurs de progression (`upload_progress_widget.dart`)

### Tests a Effectuer
- [ ] Tester l'envoi offline puis reconnexion
- [ ] Tester la compression sur differents types de connexion
- [ ] Tester le preload avec conversations riches en medias
- [ ] Tester l'eviction LRU avec cache plein
- [ ] Tester le retry sur echecs reseau

---

## ANNEXE: DEPENDANCES A AJOUTER

Si certaines dependances sont manquantes, les ajouter dans `pubspec.yaml`:

```yaml
dependencies:
  # Pour la compression video
  video_compress: ^3.1.2
  
  # Pour le partage de fichiers
  share_plus: ^7.2.1
  
  # Pour la detection du type de connexion
  connectivity_plus: ^5.0.2
  
  # Deja present normalement:
  hive: ^2.2.3
  flutter_cache_manager: ^3.3.1
  flutter_image_compress: ^2.1.0
```
