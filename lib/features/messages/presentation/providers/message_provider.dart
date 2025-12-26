import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/network/network_info.dart';
import '../../../../core/providers/connectivity_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/services/encryption_service.dart';
import '../../data/datasources/message_remote_datasource.dart';
import '../../data/repositories/message_repository_impl.dart';
import '../../domain/entities/conversation_entity.dart';
import '../../domain/entities/message_entity.dart';
import '../../domain/repositories/message_repository.dart';
import 'message_pagination_state.dart';

part 'message_provider.g.dart';

const int _pageSize = 30;

@riverpod
MessageRemoteDataSource messageRemoteDataSource(Ref ref) {
  return MessageRemoteDataSourceImpl(
    firestoreInstance: FirebaseFirestore.instance,
    storage: FirebaseStorage.instance,
    database: FirebaseDatabase.instance,
    encryptionService: ref.watch(encryptionServiceProvider),
  );
}

@riverpod
MessageRepository messageRepository(Ref ref) {
  return MessageRepositoryImpl(
    remoteDataSource: ref.watch(messageRemoteDataSourceProvider),
    networkInfo: ref.watch(networkInfoProvider),
  );
}

/// Stream des conversations de l'utilisateur actuel
@riverpod
Stream<List<ConversationEntity>> conversations(Ref ref) {
  final currentUser = ref.watch(currentUserProvider).valueOrNull;
  if (currentUser == null) {
    return Stream.value([]);
  }

  return ref
      .watch(messageRepositoryProvider)
      .getConversations(currentUser.id)
      .map(
        (either) => either.fold(
          (failure) => <ConversationEntity>[],
          (conversations) => conversations,
        ),
      );
}

/// Stream d'une conversation spécifique
@riverpod
Stream<ConversationEntity?> conversationStream(Ref ref, String conversationId) {
  return ref
      .watch(messageRepositoryProvider)
      .getConversationStream(conversationId)
      .map(
        (either) => either.fold(
          (failure) =>
              null, // En cas d'erreur, on considère null (ou on pourrait gérer l'erreur)
          (conversation) => conversation,
        ),
      );
}

/// Stream des messages d'une conversation
@riverpod
Stream<List<MessageEntity>> messages(Ref ref, String conversationId) {
  return ref
      .watch(messageRepositoryProvider)
      .getMessages(conversationId)
      .map(
        (either) =>
            either.fold((failure) => <MessageEntity>[], (messages) => messages),
      );
}

/// Notifier pour les messages paginés avec support offline
@Riverpod(keepAlive: true)
class PaginatedMessages extends _$PaginatedMessages {
  StreamSubscription<dynamic>? _newMessagesSubscription;

  @override
  MessagePaginationState build(String conversationId) {
    ref.onDispose(() {
      _newMessagesSubscription?.cancel();
    });

    // Load initial messages - using WidgetsBinding instead of microtask
    // to ensure it runs after the widget tree is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (state.isLoadingInitial) {
        loadInitial();
      }
    });

    return const MessagePaginationState(isLoadingInitial: true);
  }

  Future<void> loadInitial() async {
    debugPrint('🔄 Loading initial messages for $conversationId');
    try {
      final isOffline = !ref.read(connectivityNotifierProvider);
      state = MessagePaginationState(
        isLoadingInitial: true,
        isOffline: isOffline,
      );

      final result = await ref
          .read(messageRepositoryProvider)
          .getMessagesPaginated(
            conversationId: conversationId,
            limit: _pageSize,
          );

      result.fold(
        (failure) {
          debugPrint(
            '❌ Error loading messages for $conversationId: ${failure.message}',
          );
          state = MessagePaginationState(
            error: failure.message,
            isOffline: isOffline,
          );
        },
        (paginatedMessages) {
          debugPrint(
            '✅ Loaded ${paginatedMessages.messages.length} initial messages for $conversationId',
          );
          // Log first few message IDs for debugging
          if (paginatedMessages.messages.isNotEmpty) {
            final sampleIds = paginatedMessages.messages
                .take(3)
                .map((m) => m.id)
                .join(', ');
            debugPrint('   Sample message IDs: $sampleIds');
          }

          state = MessagePaginationState(
            messages: paginatedMessages.messages,
            hasMore: paginatedMessages.hasMore,
            lastMessageId: paginatedMessages.lastMessageId,
            oldestMessageTimestamp: paginatedMessages.oldestMessageTimestamp,
            isOffline: isOffline,
          );

          // Start listening for new messages if online
          // Use the LAST message (most recent) to listen for newer ones
          // If no messages, listen for messages after NOW (or slightly before to catch concurrents)
          if (!isOffline) {
            final lastTimestamp =
                paginatedMessages.messages.isNotEmpty
                    ? paginatedMessages.messages.last.createdAt
                    : DateTime.now().subtract(const Duration(seconds: 10));
            _listenForNewMessages(lastTimestamp);
          }
        },
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Exception loading messages: $e');
      debugPrint(stackTrace.toString());
      state = MessagePaginationState(error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (!state.canLoadMore) return;

    state = state.copyWith(isLoadingMore: true);

    final result = await ref
        .read(messageRepositoryProvider)
        .getMessagesPaginated(
          conversationId: conversationId,
          limit: _pageSize,
          beforeMessageId: state.lastMessageId,
        );

    result.fold(
      (failure) {
        state = state.copyWith(isLoadingMore: false, error: failure.message);
      },
      (paginatedMessages) {
        state = state.copyWith(
          messages: [...paginatedMessages.messages, ...state.messages],
          hasMore: paginatedMessages.hasMore,
          lastMessageId: paginatedMessages.lastMessageId,
          oldestMessageTimestamp: paginatedMessages.oldestMessageTimestamp,
          isLoadingMore: false,
        );
      },
    );
  }

  void _listenForNewMessages(DateTime afterTimestamp) {
    debugPrint('📡 Starting real-time message listener for $conversationId');
    debugPrint('   Listening for messages after: $afterTimestamp');

    _newMessagesSubscription?.cancel();
    _newMessagesSubscription = ref
        .read(messageRepositoryProvider)
        .getNewMessagesStream(
          conversationId: conversationId,
          afterTimestamp: afterTimestamp,
        )
        .listen((either) {
          either.fold(
            (failure) {
              debugPrint('❌ Real-time stream error: ${failure.message}');
            },
            (newMessages) {
              if (newMessages.isNotEmpty) {
                debugPrint(
                  '📨 Received ${newMessages.length} new messages from stream',
                );
                final existingMessages = List<MessageEntity>.from(
                  state.messages,
                );
                debugPrint(
                  '   Current message count: ${existingMessages.length}',
                );

                int replaced = 0;
                int added = 0;
                int skipped = 0;

                // Since newMessages are sorted (Oldest -> Newest), we can append them
                for (final newMessage in newMessages) {
                  // Check if this message replaces an optimistic message
                  // Match by content and approximate timestamp (within 5 seconds)
                  final optimisticIndex = existingMessages.indexWhere(
                    (m) =>
                        m.id.startsWith('temp_') &&
                        m.content == newMessage.content &&
                        m.senderId == newMessage.senderId &&
                        m.createdAt
                                .difference(newMessage.createdAt)
                                .abs()
                                .inSeconds <
                            5,
                  );

                  if (optimisticIndex != -1) {
                    // Replace optimistic message with real one
                    debugPrint(
                      '   🔄 Replacing optimistic message ${existingMessages[optimisticIndex].id} with ${newMessage.id}',
                    );
                    existingMessages[optimisticIndex] = newMessage;
                    replaced++;
                  } else if (!existingMessages.any(
                    (m) => m.id == newMessage.id,
                  )) {
                    // Add new message if it doesn't exist
                    debugPrint('   ➕ Adding new message: ${newMessage.id}');
                    existingMessages.add(newMessage);
                    added++;
                  } else {
                    debugPrint(
                      '   ⏭️  Skipping duplicate message: ${newMessage.id}',
                    );
                    skipped++;
                  }
                }

                debugPrint(
                  '   Summary: $replaced replaced, $added added, $skipped skipped',
                );

                // Re-sort to be safe, though appending sorted new messages to sorted existing should work
                existingMessages.sort(
                  (a, b) => a.createdAt.compareTo(b.createdAt),
                );

                debugPrint(
                  '   Final message count: ${existingMessages.length}',
                );
                state = state.copyWith(messages: existingMessages);
              }
            },
          );
        });
  }

  Future<void> refresh() async {
    _newMessagesSubscription?.cancel();
    await loadInitial();
  }

  void addOptimisticMessage(MessageEntity message) {
    debugPrint('➕ Adding optimistic message: ${message.id}');
    debugPrint(
      '   Current count: ${state.messages.length} -> ${state.messages.length + 1}',
    );
    state = state.copyWith(messages: [...state.messages, message]);
  }

  void updateMessageStatus(String messageId, MessageStatus newStatus) {
    final messages =
        state.messages.map((m) {
          if (m.id == messageId) {
            return MessageEntity(
              id: m.id,
              senderId: m.senderId,
              senderName: m.senderName,
              senderPhotoUrl: m.senderPhotoUrl,
              content: m.content,
              type: m.type,
              status: newStatus,
              fileUrl: m.fileUrl,
              fileName: m.fileName,
              fileSize: m.fileSize,
              mimeType: m.mimeType,
              readBy: m.readBy,
              readAt: m.readAt,
              createdAt: m.createdAt,
            );
          }
          return m;
        }).toList();

    state = state.copyWith(messages: messages);
  }
}

/// Notifier pour envoyer des messages
@riverpod
class SendMessage extends _$SendMessage {
  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }

  Future<bool> sendText({
    required String conversationId,
    required String content,
    String? optimisticMessageId,
    int attempt = 1,
    int maxAttempts = 3,
  }) async {
    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser == null) return false;

    // Only show loading on first attempt
    if (attempt == 1) {
      state = const AsyncValue.loading();
    }

    final result = await ref
        .read(messageRepositoryProvider)
        .sendTextMessage(
          conversationId: conversationId,
          senderId: currentUser.id,
          senderName: currentUser.displayName ?? 'Utilisateur',
          senderPhotoUrl: currentUser.photoUrl,
          content: content,
        );

    return result.fold(
      (failure) async {
        // Retry on network failure if not exceeded max attempts
        if (attempt < maxAttempts) {
          debugPrint(
            '⚠️ Message send failed (attempt $attempt/$maxAttempts), retrying...',
          );

          // Exponential backoff: wait 2s, then 4s
          await Future.delayed(Duration(seconds: attempt * 2));

          // Retry recursively and return the result
          return await sendText(
            conversationId: conversationId,
            content: content,
            optimisticMessageId: optimisticMessageId,
            attempt: attempt + 1,
            maxAttempts: maxAttempts,
          );
        }

        // Final failure after all retries
        debugPrint('❌ Message send failed after $maxAttempts attempts');
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (message) {
        state = const AsyncValue.data(null);
        return true;
      },
    );
  }

  Future<bool> sendFile({
    required String conversationId,
    required File file,
    required MessageType type,
    String? caption,
  }) async {
    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser == null) return false;

    state = const AsyncValue.loading();

    final result = await ref
        .read(messageRepositoryProvider)
        .sendFileMessage(
          conversationId: conversationId,
          senderId: currentUser.id,
          senderName: currentUser.displayName ?? 'Utilisateur',
          senderPhotoUrl: currentUser.photoUrl,
          file: file,
          type: type,
          caption: caption,
        );

    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (message) {
        state = const AsyncValue.data(null);
        return true;
      },
    );
  }

  Future<bool> sendAudio({
    required String conversationId,
    required File audioFile,
    required int duration,
    required List<double> waveform,
  }) async {
    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser == null) return false;

    state = const AsyncValue.loading();

    final result = await ref
        .read(messageRepositoryProvider)
        .sendAudioMessage(
          conversationId: conversationId,
          senderId: currentUser.id,
          senderName: currentUser.displayName ?? 'Utilisateur',
          senderPhotoUrl: currentUser.photoUrl,
          audioFile: audioFile,
          duration: duration,
          waveform: waveform,
        );

    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (message) {
        state = const AsyncValue.data(null);
        return true;
      },
    );
  }
}

/// Notifier pour créer des conversations
@riverpod
class CreateConversation extends _$CreateConversation {
  @override
  AsyncValue<ConversationEntity?> build() {
    return const AsyncValue.data(null);
  }

  Future<ConversationEntity?> createIndividual(String otherUserId) async {
    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser == null) return null;

    state = const AsyncValue.loading();

    final result = await ref
        .read(messageRepositoryProvider)
        .getOrCreateIndividualConversation(
          currentUserId: currentUser.id,
          otherUserId: otherUserId,
        );

    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return null;
      },
      (conversation) {
        state = AsyncValue.data(conversation);
        return conversation;
      },
    );
  }

  Future<ConversationEntity?> createGroup({
    required List<String> participantIds,
    required String groupName,
    String? groupImageUrl,
    String? groupId, // Add groupId parameter
  }) async {
    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser == null) return null;

    state = const AsyncValue.loading();

    final result = await ref
        .read(messageRepositoryProvider)
        .createGroupConversation(
          creatorId: currentUser.id,
          participantIds: participantIds,
          groupName: groupName,
          groupImageUrl: groupImageUrl,
          groupId: groupId, // Pass groupId
        );

    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return null;
      },
      (conversation) {
        state = AsyncValue.data(conversation);
        return conversation;
      },
    );
  }
}

/// Marquer une conversation comme lue
@riverpod
class MarkAsRead extends _$MarkAsRead {
  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }

  Future<void> mark(String conversationId) async {
    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser == null) return;

    await ref
        .read(messageRepositoryProvider)
        .markAsRead(conversationId: conversationId, userId: currentUser.id);
  }
}

/// Nombre total de messages non lus
@riverpod
int totalUnreadCount(Ref ref) {
  final conversations = ref.watch(conversationsProvider).valueOrNull ?? [];
  final currentUser = ref.watch(currentUserProvider).valueOrNull;

  if (currentUser == null) return 0;

  return conversations.fold<int>(
    0,
    (total, conv) => total + conv.getUnreadCountFor(currentUser.id),
  );
}

/// Notifier pour supprimer des messages
@riverpod
class DeleteMessage extends _$DeleteMessage {
  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }

  Future<bool> deleteForMe({
    required String conversationId,
    required String messageId,
  }) async {
    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser == null) return false;

    state = const AsyncValue.loading();

    final result = await ref
        .read(messageRepositoryProvider)
        .deleteMessageForMe(
          conversationId: conversationId,
          messageId: messageId,
          userId: currentUser.id,
        );

    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        // Refresh the messages list to reflect the deletion
        ref.invalidate(paginatedMessagesProvider(conversationId));
        return true;
      },
    );
  }

  Future<bool> deleteForEveryone({
    required String conversationId,
    required String messageId,
  }) async {
    state = const AsyncValue.loading();

    final result = await ref
        .read(messageRepositoryProvider)
        .deleteMessageForEveryone(
          conversationId: conversationId,
          messageId: messageId,
        );

    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        // Refresh the messages list to reflect the deletion
        ref.invalidate(paginatedMessagesProvider(conversationId));
        return true;
      },
    );
  }
}
