import 'package:cloud_firestore/cloud_firestore.dart';

/// Script utilitaire pour nettoyer les conversations dupliquées
///
/// Usage dans un écran de debug ou admin:
/// ```dart
/// final script = ConversationCleanupScript();
/// final result = await script.cleanDuplicateConversations();
/// ```
class ConversationCleanupScript {
  final FirebaseFirestore _firestore;

  ConversationCleanupScript({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Aperçu des duplications sans supprimer
  Future<Map<String, dynamic>> previewDuplicates() async {
    final conversationsRef = _firestore.collection('conversations');
    final snapshot = await conversationsRef.get();

    final Map<String, List<Map<String, dynamic>>> grouped = {};

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final String signature = _createSignature(data);

      grouped.putIfAbsent(signature, () => []);
      grouped[signature]!.add({
        'id': doc.id,
        'name': data['name'],
        'type': data['type'],
        'lastMessage': data['lastMessage'],
        'lastMessageAt': data['lastMessageAt'],
        'participantIds': data['participantIds'],
      });
    }

    final duplicates = <String, dynamic>{};
    int totalDuplicates = 0;

    grouped.forEach((signature, conversations) {
      if (conversations.length > 1) {
        duplicates[signature] = conversations;
        totalDuplicates += conversations.length - 1;
      }
    });

    return {
      'totalConversations': snapshot.docs.length,
      'totalDuplicates': totalDuplicates,
      'duplicateGroups': duplicates,
    };
  }

  /// Nettoie les conversations dupliquées (garde la plus récente)
  Future<Map<String, dynamic>> cleanDuplicateConversations() async {
    final conversationsRef = _firestore.collection('conversations');
    final snapshot = await conversationsRef.get();

    final Map<String, List<DocumentSnapshot>> grouped = {};

    // Grouper par signature
    for (final doc in snapshot.docs) {
      final signature = _createSignature(doc.data());
      grouped.putIfAbsent(signature, () => []);
      grouped[signature]!.add(doc);
    }

    // Identifier et supprimer duplicata
    final batch = _firestore.batch();
    final List<String> deletedIds = [];
    final List<String> keptIds = [];
    int totalDuplicates = 0;

    grouped.forEach((signature, conversations) {
      if (conversations.length > 1) {
        // Trier par lastMessageAt (garder le plus récent)
        conversations.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;

          final aTime = aData['lastMessageAt'] as Timestamp?;
          final bTime = bData['lastMessageAt'] as Timestamp?;

          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;

          return bTime.compareTo(aTime); // Ordre décroissant
        });

        // Garder le premier (plus récent), supprimer les autres
        for (int i = 1; i < conversations.length; i++) {
          batch.delete(conversations[i].reference);
          deletedIds.add(conversations[i].id);
          totalDuplicates++;
        }

        keptIds.add(conversations[0].id);
      }
    });

    // Exécuter suppression
    await batch.commit();

    return {
      'success': true,
      'totalConversations': snapshot.docs.length,
      'totalDuplicatesRemoved': totalDuplicates,
      'totalKept': keptIds.length,
      'deletedIds': deletedIds,
      'keptIds': keptIds,
    };
  }

  /// Crée une signature unique pour identifier les duplicata
  String _createSignature(Map<String, dynamic> data) {
    if (data['type'] == 'individual') {
      // Pour conversations individuelles: participants triés
      final participants = List<String>.from(data['participantIds'] ?? []);
      participants.sort();
      return 'individual_${participants.join('_')}';
    } else {
      // Pour groupes: nom + participants triés
      final participants = List<String>.from(data['participantIds'] ?? []);
      participants.sort();
      final groupName = data['name'] ?? 'unknown';
      return 'group_${groupName}_${participants.join('_')}';
    }
  }
}
