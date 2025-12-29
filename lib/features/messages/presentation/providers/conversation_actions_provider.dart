import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'message_provider.dart';

part 'conversation_actions_provider.g.dart';

@riverpod
class ConversationActionsNotifier extends _$ConversationActionsNotifier {
  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }

  Future<bool> muteConversation(String conversationId, bool mute) async {
    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser == null) return false;

    state = const AsyncValue.loading();

    final result =
        mute
            ? await ref
                .read(messageRepositoryProvider)
                .muteConversation(
                  conversationId: conversationId,
                  userId: currentUser.id,
                )
            : await ref
                .read(messageRepositoryProvider)
                .unmuteConversation(
                  conversationId: conversationId,
                  userId: currentUser.id,
                );

    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        return true;
      },
    );
  }

  Future<bool> archiveConversation(String conversationId, bool archive) async {
    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser == null) return false;

    state = const AsyncValue.loading();

    final result =
        archive
            ? await ref
                .read(messageRepositoryProvider)
                .archiveConversation(
                  conversationId: conversationId,
                  userId: currentUser.id,
                )
            : await ref
                .read(messageRepositoryProvider)
                .unarchiveConversation(
                  conversationId: conversationId,
                  userId: currentUser.id,
                );

    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        return true;
      },
    );
  }

  Future<bool> deleteConversation(
    String conversationId, {
    bool forEveryone = false,
  }) async {
    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser == null) return false;

    state = const AsyncValue.loading();

    final result = await ref
        .read(messageRepositoryProvider)
        .deleteConversation(
          conversationId: conversationId,
          userId: currentUser.id,
          forEveryone: forEveryone,
        );

    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        return true;
      },
    );
  }

  Future<bool> reportConversation({
    required String conversationId,
    required String reason,
    String? description,
  }) async {
    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser == null) return false;

    state = const AsyncValue.loading();

    try {
      // Report functionality might not be in repository yet as it seems specific
      // We can keep it here or move it later. For now, keeping as is but maybe wrapped in repo would be better
      // But repo doesn't have report method. Let's keep direct calls for report or add to repo.
      // Given the scope, let's keep direct call for report or assumes it's fine.
      // Actually plan didn't mention report features.
      // I'll leave report implementation as is (using Firestore directly as exception) or move it.
      // The original code was using FieldValue.
      await FirebaseFirestore.instance.collection('reports').add({
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

  Future<bool> promoteToAdmin({
    required String conversationId,
    required String userId,
  }) async {
    state = const AsyncValue.loading();

    try {
      await ref
          .read(messageRemoteDataSourceProvider)
          .promoteToAdmin(conversationId: conversationId, userId: userId);
      state = const AsyncValue.data(null);
      return true;
    } catch (e) {
      state = AsyncValue.error(e.toString(), StackTrace.current);
      return false;
    }
  }

  Future<bool> demoteFromAdmin({
    required String conversationId,
    required String userId,
  }) async {
    state = const AsyncValue.loading();

    try {
      await ref
          .read(messageRemoteDataSourceProvider)
          .demoteFromAdmin(conversationId: conversationId, userId: userId);
      state = const AsyncValue.data(null);
      return true;
    } catch (e) {
      state = AsyncValue.error(e.toString(), StackTrace.current);
      return false;
    }
  }

  Future<bool> removeUserFromGroup({
    required String conversationId,
    required String userId,
  }) async {
    state = const AsyncValue.loading();

    try {
      await ref
          .read(messageRemoteDataSourceProvider)
          .removeUserFromGroup(conversationId: conversationId, userId: userId);
      state = const AsyncValue.data(null);
      return true;
    } catch (e) {
      state = AsyncValue.error(e.toString(), StackTrace.current);
      return false;
    }
  }

  Future<bool> reportMessage({
    required String conversationId,
    required String messageId,
    required String reason,
  }) async {
    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser == null) return false;

    state = const AsyncValue.loading();

    try {
      await ref
          .read(messageRemoteDataSourceProvider)
          .reportMessage(
            conversationId: conversationId,
            messageId: messageId,
            userId: currentUser.id,
            reason: reason,
          );
      state = const AsyncValue.data(null);
      return true;
    } catch (e) {
      state = AsyncValue.error(e.toString(), StackTrace.current);
      return false;
    }
  }

  Future<bool> reportGroup({
    required String conversationId,
    required String reason,
  }) async {
    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser == null) return false;

    state = const AsyncValue.loading();

    try {
      await ref
          .read(messageRemoteDataSourceProvider)
          .reportGroup(
            conversationId: conversationId,
            userId: currentUser.id,
            reason: reason,
          );
      state = const AsyncValue.data(null);
      return true;
    } catch (e) {
      state = AsyncValue.error(e.toString(), StackTrace.current);
      return false;
    }
  }
}
