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
import 'media_upload_provider.dart';

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

@riverpod
Stream<List<ConversationEntity>> conversations(Ref ref) async* {
  final currentUser = ref.watch(currentUserProvider).valueOrNull;
  if (currentUser == null) {
    yield [];
    return;
  }

  final repository = ref.watch(messageRepositoryProvider);

  // 1. Yield cached conversations immediately (Cache First)
  final cachedResult = repository.getCachedConversations();
  final cachedData = cachedResult.fold(
    (failure) => <ConversationEntity>[],
    (data) => data,
  );

  if (cachedData.isNotEmpty) {
    yield cachedData;
  }

  // 2. Yield from live stream (Network/Live)
  yield* repository
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
  StreamSubscription<dynamic>? _messageUpdatesSubscription;

  @override
  MessagePaginationState build(String conversationId) {
    ref.onDispose(() {
      _newMessagesSubscription?.cancel();
      _messageUpdatesSubscription?.cancel();
    });

    // Load initial messages immediately using microtask
    Future.microtask(() => loadInitial());

    return const MessagePaginationState(isLoadingInitial: true);
  }

  Future<void> loadInitial() async {
    debugPrint('🔄 Loading initial messages for $conversationId');
    try {
      final isOffline = !ref.read(connectivityNotifierProvider);

      // 1. Try to load from cache first (Cache-First Strategy)
      // Always attempt to load from cache to show something immediately
      final cachedResult = ref
          .read(messageRepositoryProvider)
          .getCachedMessages(conversationId: conversationId, limit: _pageSize);

      cachedResult.fold(
        (failure) {
          debugPrint('⚠️ Cache miss or error: ${failure.message}');
          // If offline and cache fails, that's an error state
          if (isOffline) {
            state = MessagePaginationState(
              error: failure.message,
              isOffline: isOffline,
            );
          } else {
            // If online, we continue to network fetch, show loading if no data yet
            state = MessagePaginationState(
              isLoadingInitial: true,
              isOffline: isOffline,
            );
          }
        },
        (cachedMessages) {
          if (cachedMessages.isNotEmpty) {
            debugPrint('✅ Loaded ${cachedMessages.length} cached messages');
            state = MessagePaginationState(
              messages: cachedMessages,
              hasMore: cachedMessages.length >= _pageSize, // Approx
              lastMessageId: cachedMessages.first.id,
              oldestMessageTimestamp: cachedMessages.first.createdAt,
              isOffline: isOffline,
              isLoadingInitial:
                  !isOffline, // Still loading if online (fetching fresh)
            );
          } else {
            // Cache empty
            debugPrint('⚠️ Cache empty');
            state = MessagePaginationState(
              isLoadingInitial: true,
              isOffline: isOffline,
            );
          }
        },
      );

      // 2. Fetch from network (if online)
      if (!isOffline) {
        final result = await ref
            .read(messageRepositoryProvider)
            .getMessagesPaginated(
              conversationId: conversationId,
              limit: _pageSize,
            );

        result.fold(
          (failure) {
            debugPrint(
              '❌ Error fetching fresh messages for $conversationId: ${failure.message}',
            );
            // If we already have cached messages, we keep them and just stop loading
            // Maybe show a snackbar or silent error?
            if (state.messages.isNotEmpty) {
              state = state.copyWith(
                isLoadingInitial: false,
                isOffline: true,
              ); // Treat as offline/error
            } else {
              state = MessagePaginationState(
                error: failure.message,
                isOffline: isOffline,
              );
            }
          },
          (paginatedMessages) {
            debugPrint(
              '✅ Loaded ${paginatedMessages.messages.length} fresh messages for $conversationId',
            );

            state = MessagePaginationState(
              messages: paginatedMessages.messages,
              hasMore: paginatedMessages.hasMore,
              lastMessageId: paginatedMessages.lastMessageId,
              oldestMessageTimestamp: paginatedMessages.oldestMessageTimestamp,
              isOffline: isOffline,
              isLoadingInitial: false,
            );

            // Start listening for new messages and updates
            final lastTimestamp =
                paginatedMessages.messages.isNotEmpty
                    ? paginatedMessages.messages.last.createdAt
                    : DateTime.now().subtract(const Duration(seconds: 10));
            _listenForNewMessages(lastTimestamp);
            _listenForMessageUpdates();
          },
        );
      }
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
                  // Match by senderId, type, and approximate timestamp (within 10 seconds)
                  // Use multiple criteria for more robust matching
                  final optimisticIndex = existingMessages.indexWhere(
                    (m) =>
                        m.id.startsWith('temp_') &&
                        m.senderId == newMessage.senderId &&
                        m.type == newMessage.type &&
                        m.createdAt
                                .difference(newMessage.createdAt)
                                .abs()
                                .inSeconds <
                            10 &&
                        (m.content == newMessage.content ||
                            m.type != MessageType.text), // For media, don't check content
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

  void _listenForMessageUpdates() {
    debugPrint('📡 Starting message updates listener for $conversationId');

    _messageUpdatesSubscription?.cancel();
    _messageUpdatesSubscription = ref
        .read(messageRepositoryProvider)
        .getMessageUpdatesStream(conversationId: conversationId)
        .listen((either) {
          either.fold(
            (failure) {
              debugPrint('❌ Message updates stream error: ${failure.message}');
            },
            (updatedMessage) {
              debugPrint(
                '🔄 Received message update: ${updatedMessage.id} (reactions: ${updatedMessage.reactions.length})',
              );

              final existingMessages = List<MessageEntity>.from(state.messages);
              final index = existingMessages.indexWhere(
                (m) => m.id == updatedMessage.id,
              );

              if (index != -1) {
                // Update the existing message with new data
                existingMessages[index] = updatedMessage;
                state = state.copyWith(messages: existingMessages);
                debugPrint('   ✅ Updated message at index $index');
              }
            },
          );
        });
  }

  Future<void> refresh() async {
    _newMessagesSubscription?.cancel();
    await loadInitial();
  }

  /// Remove a message optimistically (for delete operations)
  void removeMessageOptimistically(String messageId) {
    final existingMessages = List<MessageEntity>.from(state.messages);
    existingMessages.removeWhere((m) => m.id == messageId);
    state = state.copyWith(messages: existingMessages);
    debugPrint('🗑️ Removed message $messageId optimistically');
  }

  /// Mark a message as deleted for current user (optimistic update)
  void markMessageDeletedForMe(String messageId, String userId) {
    final existingMessages = List<MessageEntity>.from(state.messages);
    final index = existingMessages.indexWhere((m) => m.id == messageId);

    if (index != -1) {
      final message = existingMessages[index];
      // Create updated message with user added to deletedFor
      final updatedMessage = MessageEntity(
        id: message.id,
        senderId: message.senderId,
        senderName: message.senderName,
        senderPhotoUrl: message.senderPhotoUrl,
        content: message.content,
        type: message.type,
        status: message.status,
        fileUrl: message.fileUrl,
        fileName: message.fileName,
        fileSize: message.fileSize,
        mimeType: message.mimeType,
        audioDuration: message.audioDuration,
        audioWaveform: message.audioWaveform,
        thumbnailUrl: message.thumbnailUrl,
        videoDuration: message.videoDuration,
        readBy: message.readBy,
        readAt: message.readAt,
        createdAt: message.createdAt,
        deletedFor: [...message.deletedFor, userId],
        deletedForEveryone: message.deletedForEveryone,
        deletedAt: message.deletedAt,
        reportedBy: message.reportedBy,
        reactions: message.reactions,
        replyToId: message.replyToId,
        replyToMessageData: message.replyToMessageData,
      );
      existingMessages[index] = updatedMessage;
      state = state.copyWith(messages: existingMessages);
      debugPrint('🗑️ Marked message $messageId as deleted for $userId');
    }
  }

  /// Mark a message as deleted for everyone (optimistic update)
  void markMessageDeletedForEveryone(String messageId) {
    final existingMessages = List<MessageEntity>.from(state.messages);
    final index = existingMessages.indexWhere((m) => m.id == messageId);

    if (index != -1) {
      final message = existingMessages[index];
      // Create updated message with deletedForEveryone = true
      final updatedMessage = MessageEntity(
        id: message.id,
        senderId: message.senderId,
        senderName: message.senderName,
        senderPhotoUrl: message.senderPhotoUrl,
        content: '🚫 Message supprimé',
        type: message.type,
        status: message.status,
        fileUrl: null,
        fileName: message.fileName,
        fileSize: message.fileSize,
        mimeType: message.mimeType,
        audioDuration: message.audioDuration,
        audioWaveform: null,
        thumbnailUrl: null,
        videoDuration: message.videoDuration,
        readBy: message.readBy,
        readAt: message.readAt,
        createdAt: message.createdAt,
        deletedFor: message.deletedFor,
        deletedForEveryone: true,
        deletedAt: DateTime.now(),
        reportedBy: message.reportedBy,
        reactions: message.reactions,
        replyToId: message.replyToId,
        replyToMessageData: message.replyToMessageData,
      );
      existingMessages[index] = updatedMessage;
      state = state.copyWith(messages: existingMessages);
      debugPrint('🗑️ Marked message $messageId as deleted for everyone');
    }
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

  Future<void> toggleReaction(String messageId, String emoji) async {
    final messageIndex = state.messages.indexWhere((m) => m.id == messageId);
    if (messageIndex == -1) return;

    final message = state.messages[messageIndex];
    final currentReactions = List<String>.from(message.reactions);
    final hasReaction = currentReactions.contains(emoji);

    // Optimistic Update
    if (hasReaction) {
      currentReactions.remove(emoji);
    } else {
      currentReactions.add(emoji);
    }

    // Manual copy since no copyWith
    final updatedMessage = MessageEntity(
      id: message.id,
      senderId: message.senderId,
      senderName: message.senderName,
      senderPhotoUrl: message.senderPhotoUrl,
      content: message.content,
      type: message.type,
      status: message.status,
      fileUrl: message.fileUrl,
      fileName: message.fileName,
      fileSize: message.fileSize,
      mimeType: message.mimeType,
      audioDuration: message.audioDuration,
      audioWaveform: message.audioWaveform,
      thumbnailUrl: message.thumbnailUrl,
      videoDuration: message.videoDuration,
      readBy: message.readBy,
      readAt: message.readAt,
      createdAt: message.createdAt,
      deletedFor: message.deletedFor,
      deletedForEveryone: message.deletedForEveryone,
      deletedAt: message.deletedAt,
      reportedBy: message.reportedBy,
      reactions: currentReactions,
      replyToId: message.replyToId,
      replyToMessageData: message.replyToMessageData,
    );

    final updatedMessages = List<MessageEntity>.from(state.messages);
    updatedMessages[messageIndex] = updatedMessage;
    state = state.copyWith(messages: updatedMessages);

    // Persist
    try {
      if (hasReaction) {
        await ref
            .read(messageRemoteDataSourceProvider)
            .removeReaction(
              conversationId: conversationId,
              messageId: messageId,
              emoji: emoji,
            );
      } else {
        await ref
            .read(messageRemoteDataSourceProvider)
            .addReaction(
              conversationId: conversationId,
              messageId: messageId,
              emoji: emoji,
            );
      }
    } catch (e) {
      // Revert on failure
      debugPrint('❌ Failed to toggle reaction: $e');
      final revertedMessages = List<MessageEntity>.from(state.messages);
      // Ensure we are still looking at the same valid index/message ID
      if (revertedMessages.length > messageIndex &&
          revertedMessages[messageIndex].id == messageId) {
        revertedMessages[messageIndex] = message; // Restore original
        state = state.copyWith(messages: revertedMessages);
      }
    }
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
    MessageEntity? replyToMessage,
  }) async {
    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser == null) return false;

    // Prepare reply data
    Map<String, dynamic>? replyToMessageData;
    if (replyToMessage != null) {
      replyToMessageData = {
        'id': replyToMessage.id,
        'senderId': replyToMessage.senderId,
        'senderName': replyToMessage.senderName,
        'content': replyToMessage.content,
        'type': replyToMessage.type.name,
        'fileUrl': replyToMessage.fileUrl,
        'fileName': replyToMessage.fileName,
      };
    }

    // Generate a temporary ID for optimistic UI if not provided
    final tempId =
        optimisticMessageId ?? 'temp_${DateTime.now().millisecondsSinceEpoch}';

    // Create optimistic message
    final optimisticMessage = MessageEntity(
      id: tempId,
      senderId: currentUser.id,
      senderName: currentUser.displayName ?? 'Utilisateur',
      senderPhotoUrl: currentUser.photoUrl,
      content: content,
      type: MessageType.text,
      status: MessageStatus.sending,
      createdAt: DateTime.now(),
      readBy: [],
      readAt: {},
      replyToId: replyToMessage?.id,
      replyToMessageData: replyToMessageData,
    );

    // Add to UI immediately (only on first attempt)
    if (attempt == 1) {
      ref
          .read(paginatedMessagesProvider(conversationId).notifier)
          .addOptimisticMessage(optimisticMessage);
    }

    // Only show loading on valid state if needed, but we want UI to be non-blocking
    // state = const AsyncValue.loading();

    final result = await ref
        .read(messageRepositoryProvider)
        .sendTextMessage(
          conversationId: conversationId,
          senderId: currentUser.id,
          senderName: currentUser.displayName ?? 'Utilisateur',
          senderPhotoUrl: currentUser.photoUrl,
          content: content,
          replyToId: replyToMessage?.id,
          replyToMessageData: replyToMessageData,
        );

    return result.fold(
      (failure) async {
        // Retry on network failure if not exceeded max attempts
        if (attempt < maxAttempts) {
          debugPrint(
            '⚠️ Message send failed (attempt $attempt/$maxAttempts), retrying...',
          );

          // Exponential backoff: wait 2s, then 4s, etc
          await Future.delayed(Duration(seconds: attempt * 2));

          // Retry recursively
          return await sendText(
            conversationId: conversationId,
            content: content,
            optimisticMessageId: tempId, // Pass the same ID to avoid duplicates
            attempt: attempt + 1,
            maxAttempts: maxAttempts,
            replyToMessage: replyToMessage,
          );
        }

        // Final failure after all retries
        debugPrint('❌ Message send failed after $maxAttempts attempts');

        // Update status to failed in UI
        ref
            .read(paginatedMessagesProvider(conversationId).notifier)
            .updateMessageStatus(tempId, MessageStatus.failed);

        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (message) {
        state = const AsyncValue.data(null);
        // The real-time stream will handle replacing the optimistic message
        // based on content matching in PaginatedMessages._listenForNewMessages
        return true;
      },
    );
  }

  Future<bool> sendFile({
    required String conversationId,
    required File file,
    required MessageType type,
    String? caption,
    MessageEntity? replyToMessage,
  }) async {
    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser == null) return false;

    // Prepare reply data
    Map<String, dynamic>? replyToMessageData;
    if (replyToMessage != null) {
      replyToMessageData = {
        'id': replyToMessage.id,
        'senderId': replyToMessage.senderId,
        'senderName': replyToMessage.senderName,
        'content': replyToMessage.content,
        'type': replyToMessage.type.name,
        'fileUrl': replyToMessage.fileUrl,
        'fileName': replyToMessage.fileName,
      };
    }

    // Initialize upload state
    final uploadNotifier = ref.read(mediaUploadProvider.notifier);
    uploadNotifier.startUpload(
      file: file,
      conversationId: conversationId,
      isImage: type == MessageType.image,
      caption: caption,
    );

    // No longer setting local loading state as we use the dedicated provider
    // state = const AsyncValue.loading();

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
          onProgress: (progress) {
            uploadNotifier.updateProgress(progress);
          },
          checkCancelled: () {
            // Check provider state
            return ref.read(mediaUploadProvider).status ==
                MediaUploadStatus.cancelled;
          },
          replyToId: replyToMessage?.id,
          replyToMessageData: replyToMessageData,
        );

    return result.fold(
      (failure) {
        if (failure.message == 'Envoi annulé') {
          // Already handled visually by the provider state (cancelled)
          // But we might want to reset it or keep it as cancelled
          uploadNotifier.cancel(); // Ensure state is cancelled
        } else {
          uploadNotifier.markError(failure.message);
          state = AsyncValue.error(failure.message, StackTrace.current);
        }
        return false;
      },
      (message) {
        uploadNotifier.markSuccess();
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
    MessageEntity? replyToMessage,
  }) async {
    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser == null) return false;

    // Prepare reply data
    Map<String, dynamic>? replyToMessageData;
    if (replyToMessage != null) {
      replyToMessageData = {
        'id': replyToMessage.id,
        'senderId': replyToMessage.senderId,
        'senderName': replyToMessage.senderName,
        'content': replyToMessage.content,
        'type': replyToMessage.type.name,
        'fileUrl': replyToMessage.fileUrl,
        'fileName': replyToMessage.fileName,
      };
    }

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
          replyToId: replyToMessage?.id,
          replyToMessageData: replyToMessageData,
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
    if (currentUser == null) {
      debugPrint('❌ DeleteMessage: No current user');
      return false;
    }

    // Optimistic update - mark message as deleted for this user immediately
    ref
        .read(paginatedMessagesProvider(conversationId).notifier)
        .markMessageDeletedForMe(messageId, currentUser.id);

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
        debugPrint('❌ DeleteMessage deleteForMe failed: ${failure.message}');
        state = AsyncValue.error(failure.message, StackTrace.current);
        // Revert optimistic update by refreshing
        ref.invalidate(paginatedMessagesProvider(conversationId));
        return false;
      },
      (_) {
        debugPrint('✅ DeleteMessage deleteForMe success');
        state = const AsyncValue.data(null);
        // Message already hidden by optimistic update, no need to refresh
        return true;
      },
    );
  }

  Future<bool> deleteForEveryone({
    required String conversationId,
    required String messageId,
  }) async {
    // Optimistic update - mark message as deleted for everyone immediately
    ref
        .read(paginatedMessagesProvider(conversationId).notifier)
        .markMessageDeletedForEveryone(messageId);

    state = const AsyncValue.loading();

    final result = await ref
        .read(messageRepositoryProvider)
        .deleteMessageForEveryone(
          conversationId: conversationId,
          messageId: messageId,
        );

    return result.fold(
      (failure) {
        debugPrint(
          '❌ DeleteMessage deleteForEveryone failed: ${failure.message}',
        );
        state = AsyncValue.error(failure.message, StackTrace.current);
        // Revert optimistic update by refreshing
        ref.invalidate(paginatedMessagesProvider(conversationId));
        return false;
      },
      (_) {
        debugPrint('✅ DeleteMessage deleteForEveryone success');
        state = const AsyncValue.data(null);
        // Message already updated by optimistic update, no need to refresh
        return true;
      },
    );
  }
}
