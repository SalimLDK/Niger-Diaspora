import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

/// Script utilitaire pour synchroniser les participants des conversations
/// de Firestore vers Realtime Database (nécessaire pour les règles de sécurité)
///
/// Usage dans un écran de debug ou admin:
/// ```dart
/// final script = RtdbSyncScript();
/// final result = await script.syncAllConversationsToRTDB();
/// ```
class RtdbSyncScript {
  final FirebaseFirestore _firestore;
  final FirebaseDatabase _database;

  RtdbSyncScript({FirebaseFirestore? firestore, FirebaseDatabase? database})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _database = database ?? FirebaseDatabase.instance;

  /// Sync all conversation participants to Realtime Database
  Future<Map<String, dynamic>> syncAllConversationsToRTDB() async {
    final conversationsRef = _firestore.collection('conversations');
    final snapshot = await conversationsRef.get();

    int syncedCount = 0;
    int errorCount = 0;
    final List<String> syncedIds = [];
    final List<String> errorIds = [];

    for (final doc in snapshot.docs) {
      try {
        final data = doc.data();
        final participantIds = List<String>.from(data['participantIds'] ?? []);

        if (participantIds.isNotEmpty) {
          // Create participants map for RTDB
          final participantsMap = <String, bool>{};
          for (final id in participantIds) {
            participantsMap[id] = true;
          }

          // Sync to RTDB
          await _database
              .ref()
              .child('conversations')
              .child(doc.id)
              .child('participants')
              .set(participantsMap);

          syncedCount++;
          syncedIds.add(doc.id);
        }
      } catch (e) {
        errorCount++;
        errorIds.add(doc.id);
      }
    }

    return {
      'success': true,
      'totalConversations': snapshot.docs.length,
      'syncedCount': syncedCount,
      'errorCount': errorCount,
      'syncedIds': syncedIds,
      'errorIds': errorIds,
    };
  }

  /// Sync a single conversation to RTDB
  Future<bool> syncConversationToRTDB(String conversationId) async {
    try {
      final doc =
          await _firestore.collection('conversations').doc(conversationId).get();

      if (!doc.exists) return false;

      final data = doc.data()!;
      final participantIds = List<String>.from(data['participantIds'] ?? []);

      if (participantIds.isEmpty) return false;

      final participantsMap = <String, bool>{};
      for (final id in participantIds) {
        participantsMap[id] = true;
      }

      await _database
          .ref()
          .child('conversations')
          .child(conversationId)
          .child('participants')
          .set(participantsMap);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Preview what will be synced without actually syncing
  Future<Map<String, dynamic>> previewSync() async {
    final conversationsRef = _firestore.collection('conversations');
    final snapshot = await conversationsRef.get();

    final List<Map<String, dynamic>> toSync = [];

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final participantIds = List<String>.from(data['participantIds'] ?? []);

      if (participantIds.isNotEmpty) {
        toSync.add({
          'id': doc.id,
          'type': data['type'],
          'name': data['name'],
          'participantCount': participantIds.length,
        });
      }
    }

    return {
      'totalConversations': snapshot.docs.length,
      'conversationsToSync': toSync.length,
      'conversations': toSync,
    };
  }
}
