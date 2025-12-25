import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/constants/firebase_collections.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

part 'conversation_actions_provider.g.dart';

@riverpod
class ConversationActionsNotifier extends _$ConversationActionsNotifier {
  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  Future<bool> muteConversation(String conversationId, bool mute) async {
    final currentUser = ref.read(currentUserProvider).valueOrNull;
    if (currentUser == null) return false;

    state = const AsyncValue.loading();

    try {
      await _firestore
          .collection(FirebaseCollections.conversations)
          .doc(conversationId)
          .update({
        'mutedBy.${currentUser.id}': mute,
      });

      state = const AsyncValue.data(null);
      return true;
    } catch (e) {
      state = AsyncValue.error(e.toString(), StackTrace.current);
      return false;
    }
  }

  Future<bool> archiveConversation(String conversationId, bool archive) async {
    final currentUser = ref.read(currentUserProvider).valueOrNull;
    if (currentUser == null) return false;

    state = const AsyncValue.loading();

    try {
      await _firestore
          .collection(FirebaseCollections.conversations)
          .doc(conversationId)
          .update({
        'archivedBy.${currentUser.id}': archive,
      });

      state = const AsyncValue.data(null);
      return true;
    } catch (e) {
      state = AsyncValue.error(e.toString(), StackTrace.current);
      return false;
    }
  }

  Future<bool> deleteConversation(String conversationId) async {
    final currentUser = ref.read(currentUserProvider).valueOrNull;
    if (currentUser == null) return false;

    state = const AsyncValue.loading();

    try {
      final batch = _firestore.batch();

      // Delete all messages in the conversation
      final messagesSnapshot = await _firestore
          .collection(FirebaseCollections.conversations)
          .doc(conversationId)
          .collection(FirebaseCollections.messages)
          .get();

      for (final doc in messagesSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete the conversation
      batch.delete(
        _firestore.collection(FirebaseCollections.conversations).doc(conversationId),
      );

      await batch.commit();

      state = const AsyncValue.data(null);
      return true;
    } catch (e) {
      state = AsyncValue.error(e.toString(), StackTrace.current);
      return false;
    }
  }

  Future<bool> reportConversation({
    required String conversationId,
    required String reason,
    String? description,
  }) async {
    final currentUser = ref.read(currentUserProvider).valueOrNull;
    if (currentUser == null) return false;

    state = const AsyncValue.loading();

    try {
      await _firestore.collection('reports').add({
        'type': 'conversation',
        'conversationId': conversationId,
        'reporterId': currentUser.id,
        'reason': reason,
        'description': description,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      state = const AsyncValue.data(null);
      return true;
    } catch (e) {
      state = AsyncValue.error(e.toString(), StackTrace.current);
      return false;
    }
  }
}
