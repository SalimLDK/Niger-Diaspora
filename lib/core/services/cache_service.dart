import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Service de cache pour le mode offline
class CacheService {
  static const String _profilesBox = 'profiles_cache';
  static const String _eventsBox = 'events_cache';
  static const String _groupsBox = 'groups_cache';
  static const String _conversationsBox = 'conversations_cache';
  static const String _messagesBox = 'messages_cache';
  static const String _legalBox = 'legal_cache';
  static const String _feedBox = 'feed_cache';
  static const String _metadataBox = 'cache_metadata';

  static CacheService? _instance;
  static CacheService get instance => _instance ??= CacheService._();

  CacheService._();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    await Hive.openBox<String>(_profilesBox);
    await Hive.openBox<String>(_eventsBox);
    await Hive.openBox<String>(_groupsBox);
    await Hive.openBox<String>(_conversationsBox);
    await Hive.openBox<String>(_messagesBox);
    await Hive.openBox<String>(_legalBox);
    await Hive.openBox<String>(_feedBox);
    await Hive.openBox<String>(_metadataBox);

    _isInitialized = true;
  }

  // ==================== Profile Cache ====================

  Future<void> cacheProfile(String id, Map<String, dynamic> data) async {
    final box = Hive.box<String>(_profilesBox);
    await box.put(id, jsonEncode(data));
    await _updateTimestamp(_profilesBox, id);
  }

  Map<String, dynamic>? getCachedProfile(String id) {
    final box = Hive.box<String>(_profilesBox);
    final data = box.get(id);
    if (data == null) return null;
    try {
      return jsonDecode(data) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('CacheService: Error decoding cached profile $id: $e');
      return null;
    }
  }

  Future<void> cacheProfiles(List<Map<String, dynamic>> profiles) async {
    final box = Hive.box<String>(_profilesBox);
    for (final profile in profiles) {
      final id = profile['id'] as String?;
      if (id != null) {
        await box.put(id, jsonEncode(profile));
      }
    }
    await _updateTimestamp(_profilesBox, 'all');
  }

  List<Map<String, dynamic>> getAllCachedProfiles() {
    final box = Hive.box<String>(_profilesBox);
    final results = <Map<String, dynamic>>[];
    for (final data in box.values) {
      try {
        results.add(jsonDecode(data) as Map<String, dynamic>);
      } catch (e) {
        debugPrint('CacheService: Error decoding cached profile: $e');
      }
    }
    return results;
  }

  // ==================== Events Cache ====================

  Future<void> cacheEvent(String id, Map<String, dynamic> data) async {
    final box = Hive.box<String>(_eventsBox);
    await box.put(id, jsonEncode(data));
    await _updateTimestamp(_eventsBox, id);
  }

  Map<String, dynamic>? getCachedEvent(String id) {
    final box = Hive.box<String>(_eventsBox);
    final data = box.get(id);
    if (data == null) return null;
    try {
      return jsonDecode(data) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('CacheService: Error decoding cached event $id: $e');
      return null;
    }
  }

  Future<void> cacheEvents(List<Map<String, dynamic>> events) async {
    final box = Hive.box<String>(_eventsBox);
    // Clear old events first
    await box.clear();
    for (final event in events) {
      final id = event['id'] as String?;
      if (id != null) {
        await box.put(id, jsonEncode(event));
      }
    }
    await _updateTimestamp(_eventsBox, 'all');
  }

  List<Map<String, dynamic>> getAllCachedEvents() {
    final box = Hive.box<String>(_eventsBox);
    final results = <Map<String, dynamic>>[];
    for (final data in box.values) {
      try {
        results.add(jsonDecode(data) as Map<String, dynamic>);
      } catch (e) {
        debugPrint('CacheService: Error decoding cached event: $e');
      }
    }
    return results;
  }

  // ==================== Groups Cache ====================

  Future<void> cacheGroup(String id, Map<String, dynamic> data) async {
    final box = Hive.box<String>(_groupsBox);
    await box.put(id, jsonEncode(data));
    await _updateTimestamp(_groupsBox, id);
  }

  Map<String, dynamic>? getCachedGroup(String id) {
    final box = Hive.box<String>(_groupsBox);
    final data = box.get(id);
    if (data == null) return null;
    try {
      return jsonDecode(data) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('CacheService: Error decoding cached group $id: $e');
      return null;
    }
  }

  Future<void> cacheGroups(List<Map<String, dynamic>> groups) async {
    final box = Hive.box<String>(_groupsBox);
    await box.clear();
    for (final group in groups) {
      final id = group['id'] as String?;
      if (id != null) {
        await box.put(id, jsonEncode(group));
      }
    }
    await _updateTimestamp(_groupsBox, 'all');
  }

  List<Map<String, dynamic>> getAllCachedGroups() {
    final box = Hive.box<String>(_groupsBox);
    final results = <Map<String, dynamic>>[];
    for (final data in box.values) {
      try {
        results.add(jsonDecode(data) as Map<String, dynamic>);
      } catch (e) {
        debugPrint('CacheService: Error decoding cached group: $e');
      }
    }
    return results;
  }

  // ==================== Conversations Cache ====================

  Future<void> cacheConversation(String id, Map<String, dynamic> data) async {
    final box = Hive.box<String>(_conversationsBox);
    await box.put(id, jsonEncode(data));
    await _updateTimestamp(_conversationsBox, id);
  }

  Map<String, dynamic>? getCachedConversation(String id) {
    final box = Hive.box<String>(_conversationsBox);
    final data = box.get(id);
    if (data == null) return null;
    try {
      return jsonDecode(data) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('CacheService: Error decoding cached conversation $id: $e');
      return null;
    }
  }

  Future<void> cacheConversations(
    List<Map<String, dynamic>> conversations,
  ) async {
    final box = Hive.box<String>(_conversationsBox);
    await box.clear();
    for (final conv in conversations) {
      final id = conv['id'] as String?;
      if (id != null) {
        await box.put(id, jsonEncode(conv));
      }
    }
    await _updateTimestamp(_conversationsBox, 'all');
  }

  List<Map<String, dynamic>> getAllCachedConversations() {
    final box = Hive.box<String>(_conversationsBox);
    final results = <Map<String, dynamic>>[];
    for (final data in box.values) {
      try {
        results.add(jsonDecode(data) as Map<String, dynamic>);
      } catch (e) {
        debugPrint('CacheService: Error decoding cached conversation: $e');
      }
    }
    return results;
  }

  // ==================== Messages Cache ====================

  String _messagesKey(String conversationId) => 'messages_$conversationId';

  Future<void> cacheMessages(
    String conversationId,
    List<Map<String, dynamic>> messages,
  ) async {
    final box = Hive.box<String>(_messagesBox);
    final key = _messagesKey(conversationId);

    // Store as a list of messages
    final existingData = box.get(key);
    List<Map<String, dynamic>> existingMessages = [];

    if (existingData != null) {
      try {
        final decoded = jsonDecode(existingData) as List;
        existingMessages = decoded.cast<Map<String, dynamic>>();
      } catch (e) {
        debugPrint('CacheService: Error decoding existing messages: $e');
      }
    }

    // Merge new messages with existing ones (avoid duplicates by id)
    final messageMap = <String, Map<String, dynamic>>{};
    for (final msg in existingMessages) {
      final id = msg['id'] as String?;
      if (id != null) messageMap[id] = msg;
    }
    for (final msg in messages) {
      final id = msg['id'] as String?;
      if (id != null) messageMap[id] = msg;
    }

    // Sort by timestamp (oldest first)
    final sortedMessages =
        messageMap.values.toList()..sort((a, b) {
          final aTime =
              DateTime.tryParse(a['createdAt'] as String? ?? '') ??
              DateTime.now();
          final bTime =
              DateTime.tryParse(b['createdAt'] as String? ?? '') ??
              DateTime.now();
          return aTime.compareTo(bTime);
        });

    await box.put(key, jsonEncode(sortedMessages));
    await _updateTimestamp(_messagesBox, key);
  }

  Future<void> cacheMessage(
    String conversationId,
    Map<String, dynamic> message,
  ) async {
    await cacheMessages(conversationId, [message]);
  }

  List<Map<String, dynamic>> getCachedMessages(
    String conversationId, {
    int? limit,
    String? beforeMessageId,
  }) {
    final box = Hive.box<String>(_messagesBox);
    final key = _messagesKey(conversationId);
    final data = box.get(key);

    if (data == null) return [];

    try {
      final decoded = jsonDecode(data) as List;
      var messages = decoded.cast<Map<String, dynamic>>().toList();

      // If beforeMessageId is provided, filter messages before that ID
      if (beforeMessageId != null) {
        final index = messages.indexWhere((m) => m['id'] == beforeMessageId);
        if (index > 0) {
          messages = messages.sublist(0, index);
        } else if (index == 0) {
          return [];
        }
      }

      // Apply limit (get the last N messages)
      if (limit != null && messages.length > limit) {
        messages = messages.sublist(messages.length - limit);
      }

      return messages;
    } catch (e) {
      debugPrint('CacheService: Error decoding cached messages: $e');
      return [];
    }
  }

  int getCachedMessagesCount(String conversationId) {
    final box = Hive.box<String>(_messagesBox);
    final key = _messagesKey(conversationId);
    final data = box.get(key);

    if (data == null) return 0;

    try {
      final decoded = jsonDecode(data) as List;
      return decoded.length;
    } catch (e) {
      debugPrint('CacheService: Error counting cached messages: $e');
      return 0;
    }
  }

  Future<void> clearMessagesCache(String conversationId) async {
    final box = Hive.box<String>(_messagesBox);
    final key = _messagesKey(conversationId);
    await box.delete(key);
  }

  Future<void> cacheMessagesLRU(
    String conversationId,
    List<Map<String, dynamic>> messages, {
    int maxMessages = 500,
  }) async {
    if (messages.length > maxMessages) {
      await cacheMessages(
        conversationId,
        messages.sublist(messages.length - maxMessages),
      );
      return;
    }
    await cacheMessages(conversationId, messages);
  }

  Future<void> clearAllMessagesCache() async {
    await Hive.box<String>(_messagesBox).clear();
  }

  // ==================== Legal Content Cache ====================

  Future<void> cacheLegalContent(String key, Map<String, dynamic> data) async {
    final box = Hive.box<String>(_legalBox);
    await box.put(key, jsonEncode(data));
    await _updateTimestamp(_legalBox, key);
  }

  Map<String, dynamic>? getCachedLegalContent(String key) {
    final box = Hive.box<String>(_legalBox);
    final data = box.get(key);
    if (data == null) return null;
    try {
      return jsonDecode(data) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('CacheService: Error decoding cached legal content $key: $e');
      return null;
    }
  }

  // ==================== Feed Cache ====================

  /// Clé unique par mode/filtre : le fil « Pour vous », « Abonnements » et un
  /// fil filtré par hashtag n'ont pas le même contenu et ne doivent pas se
  /// recouvrir en cache.
  static String feedKey({required String mode, String? hashtagFilter}) =>
      hashtagFilter == null ? mode : '$mode#$hashtagFilter';

  /// Mémorise la dernière page de fil reçue, pour pouvoir la réafficher hors
  /// connexion au lieu d'un écran d'erreur.
  Future<void> cacheFeed(String key, List<Map<String, dynamic>> posts) async {
    final box = Hive.box<String>(_feedBox);
    await box.put(key, jsonEncode(posts));
    await _updateTimestamp(_feedBox, key);
  }

  List<Map<String, dynamic>> getCachedFeed(String key) {
    final box = Hive.box<String>(_feedBox);
    final data = box.get(key);
    if (data == null) return const [];
    try {
      return (jsonDecode(data) as List)
          .cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('CacheService: Error decoding cached feed $key: $e');
      return const [];
    }
  }

  /// Quand la page en cache a été reçue — l'écran l'affiche pour que
  /// l'utilisateur sache à quel point ce qu'il lit est vieux.
  DateTime? getFeedCachedAt(String key) => getLastUpdateTime(_feedBox, key);

  Future<void> clearFeedCache() async => Hive.box<String>(_feedBox).clear();

  // ==================== Cache Metadata ====================

  Future<void> _updateTimestamp(String boxName, String key) async {
    final metaBox = Hive.box<String>(_metadataBox);
    await metaBox.put(
      '${boxName}_${key}_timestamp',
      DateTime.now().toIso8601String(),
    );
  }

  DateTime? getLastUpdateTime(String boxName, String key) {
    final metaBox = Hive.box<String>(_metadataBox);
    final timestamp = metaBox.get('${boxName}_${key}_timestamp');
    if (timestamp == null) return null;
    return DateTime.parse(timestamp).toLocal();
  }

  bool isCacheValid(
    String boxName,
    String key, {
    Duration maxAge = const Duration(hours: 1),
  }) {
    final lastUpdate = getLastUpdateTime(boxName, key);
    if (lastUpdate == null) return false;
    return DateTime.now().difference(lastUpdate) < maxAge;
  }

  // ==================== Clear Cache ====================

  Future<void> clearAllCache() async {
    await Hive.box<String>(_profilesBox).clear();
    await Hive.box<String>(_eventsBox).clear();
    await Hive.box<String>(_groupsBox).clear();
    await Hive.box<String>(_conversationsBox).clear();
    await Hive.box<String>(_messagesBox).clear();
    await Hive.box<String>(_metadataBox).clear();
  }

  Future<void> clearProfileCache() async {
    await Hive.box<String>(_profilesBox).clear();
  }

  Future<void> clearEventsCache() async {
    await Hive.box<String>(_eventsBox).clear();
  }

  Future<void> clearGroupsCache() async {
    await Hive.box<String>(_groupsBox).clear();
  }

  Future<void> clearConversationsCache() async {
    await Hive.box<String>(_conversationsBox).clear();
  }
}
