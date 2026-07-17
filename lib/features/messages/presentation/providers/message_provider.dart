import 'dart:async';
import 'dart:io';

import 'package:uuid/uuid.dart';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../../../core/services/e2ee/message_crypto_service.dart';
import '../../data/datasources/message_supabase_datasource.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/network_info.dart';
import '../../../../core/providers/connectivity_provider.dart';
import '../../../../core/services/offline_queue_service.dart';
import '../../../../core/utils/rtdb_sync_script.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../settings/presentation/providers/blocked_users_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../../core/services/link_preview_service.dart';
import '../../data/datasources/message_remote_datasource.dart';
import '../../data/repositories/message_repository_impl.dart';
import '../../domain/entities/conversation_entity.dart';
import '../../domain/entities/message_entity.dart';
import '../../domain/repositories/message_repository.dart';
import '../../../../core/errors/failures.dart';
import '../../../feed/domain/entities/post_entity.dart' show MentionedUser;
import 'message_pagination_state.dart';
import 'media_upload_provider.dart';

const int _pageSize = 30;

// ============ Providers de base ============

/// Provider pour le datasource de messages
final messageRemoteDataSourceProvider = Provider<MessageRemoteDataSource>((ref) {
  return MessageSupabaseDataSource(
    cryptoService: ref.watch(messageCryptoServiceProvider),
  );
});

/// Provider pour le repository de messages
final messageRepositoryProvider = Provider<MessageRepository>((ref) {
  return MessageRepositoryImpl(
    remoteDataSource: ref.watch(messageRemoteDataSourceProvider),
    networkInfo: ref.watch(networkInfoProvider),
  );
});

// ============ Stream Providers ============

/// Stream des conversations de l'utilisateur (cache-first)
final conversationsProvider = StreamProvider<List<ConversationEntity>>((ref) async* {
  // Attendre que l'utilisateur soit completement resolu
  // Utiliser .future pour attendre la premiere valeur du stream
  final currentUser = await ref.watch(currentUserProvider.future);

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
});

/// Stream d'une conversation specifique
final conversationStreamProvider = StreamProvider.family<ConversationEntity?, String>((ref, conversationId) {
  return ref
      .watch(messageRepositoryProvider)
      .getConversationStream(conversationId)
      .map(
        (either) => either.fold(
          (failure) => null,
          (conversation) => conversation,
        ),
      );
});

/// Stream des messages d'une conversation
final messagesProvider = StreamProvider.family<List<MessageEntity>, String>((ref, conversationId) {
  return ref
      .watch(messageRepositoryProvider)
      .getMessages(conversationId)
      .map(
        (either) => either.fold(
          (failure) => <MessageEntity>[],
          (messages) => messages,
        ),
      );
});

// ============ Notifiers ============

/// Notifier pour les messages pagines avec support offline
/// autoDispose: libere la memoire quand le provider n'est plus utilise
final paginatedMessagesProvider = StateNotifierProvider.autoDispose.family<
    PaginatedMessagesNotifier, MessagePaginationState, String>(
  (ref, conversationId) {
    // Keep alive briefly to allow preloading before navigation
    final link = ref.keepAlive();

    // Auto-dispose after 5 seconds if no active listeners
    final timer = Timer(const Duration(seconds: 5), () {
      link.close();
    });

    ref.onDispose(() {
      timer.cancel();
    });

    return PaginatedMessagesNotifier(ref, conversationId);
  },
);

class PaginatedMessagesNotifier extends StateNotifier<MessagePaginationState> {
  final Ref _ref;
  final String conversationId;

  StreamSubscription<dynamic>? _newMessagesSubscription;
  StreamSubscription<dynamic>? _messageUpdatesSubscription;
  DateTime? _filterAfterDate;
  final Map<String, Timer> _optimisticTimeouts = {};

  PaginatedMessagesNotifier(this._ref, this.conversationId)
      : super(const MessagePaginationState(isLoadingInitial: true)) {
    // Load cache synchronously for instant display
    _loadCacheSync();
    // Then load network data in background
    Future.microtask(() => _loadNetworkData());
  }

  /// Fire-and-forget: prepare E2EE sessions and Sender Keys for this conversation.
  ///   • 1:1   → pre-establish Signal session with the other participant
  ///   • Group → distribute this user's Sender Key to all members
  void _preEstablishE2EESessions() {
    final currentUser = _ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser == null) return;

    final crypto = _ref.read(messageCryptoServiceProvider);

    // Try the cached stream value first; if not yet loaded, wait for the first
    // emission so we never skip pre-establishment due to a loading race.
    final cached = _ref.read(conversationStreamProvider(conversationId)).valueOrNull;
    if (cached != null) {
      _doPreEstablish(crypto, cached, currentUser.id);
    } else {
      // Stream not loaded yet — listen for the first value then pre-establish.
      _ref.listen(conversationStreamProvider(conversationId), (_, next) {
        final conv = next.valueOrNull;
        if (conv != null) _doPreEstablish(crypto, conv, currentUser.id);
      });
    }
  }

  void _doPreEstablish(dynamic crypto, dynamic conversation, String currentUserId) {
    if (conversation.isIndividual == true) {
      final recipients = (conversation.participantIds as List<String>)
          .where((id) => id != currentUserId)
          .toList();
      if (recipients.isEmpty) return;
      crypto
          .preEstablishSessions(recipients)
          .catchError((e) => debugPrint('E2EE pre-establish error: $e'));
    } else {
      crypto
          .distributeGroupSenderKey(
            groupId: conversationId,
            memberIds: conversation.participantIds,
          )
          .catchError((e) => debugPrint('Sender Key distribution error: $e'));
    }
  }

  /// Load cached messages synchronously (instant)
  void _loadCacheSync() {
    final cachedResult = _ref
        .read(messageRepositoryProvider)
        .getCachedMessages(conversationId: conversationId, limit: _pageSize);

    cachedResult.fold(
      (failure) {
        // Cache failed, will load from network
      },
      (cachedMessages) {
        if (cachedMessages.isNotEmpty) {
          state = MessagePaginationState(
            messages: cachedMessages,
            hasMore: cachedMessages.length >= _pageSize,
            lastMessageId: cachedMessages.first.id,
            oldestMessageTimestamp: cachedMessages.first.createdAt,
            isOffline: false,
            isLoadingInitial: false,
          );
          // Listeners will be configured in _loadNetworkData() to avoid duplicates
        }
      },
    );
  }

  /// Load data from network (async, background)
  Future<void> _loadNetworkData() async {
    if (!mounted) return;

    final isOffline = !_ref.read(connectivityNotifierProvider);
    if (isOffline) {
      if (state.messages.isEmpty) {
        state = state.copyWith(isOffline: true, isLoadingInitial: false);
      }
      return;
    }

    // Pre-establish Signal sessions eagerly so the first outbound message is
    // already E2EE without waiting for lazy session setup at send time.
    _preEstablishE2EESessions();

    // Sync RTDB in background
    unawaited(RtdbSyncScript().syncConversationToRTDB(conversationId));

    // Load fresh data from network
    final result = await _ref
        .read(messageRepositoryProvider)
        .getMessagesPaginated(
          conversationId: conversationId,
          limit: _pageSize,
          filterAfterDate: _filterAfterDate,
        );

    if (!mounted) return;

    result.fold(
      (failure) {
        if (state.messages.isEmpty) {
          state = MessagePaginationState(
            error: failure.message,
            isOffline: true,
          );
        }
      },
      (paginatedMessages) {
        state = MessagePaginationState(
          messages: paginatedMessages.messages,
          hasMore: paginatedMessages.hasMore,
          lastMessageId: paginatedMessages.lastMessageId,
          oldestMessageTimestamp: paginatedMessages.oldestMessageTimestamp,
          isOffline: false,
          isLoadingInitial: false,
        );

        final lastTimestamp = paginatedMessages.messages.isNotEmpty
            ? paginatedMessages.messages.last.createdAt
            : DateTime.now().subtract(const Duration(seconds: 10));
        _listenForNewMessages(lastTimestamp);
        _listenForMessageUpdates();
      },
    );
  }

  @override
  void dispose() {
    _newMessagesSubscription?.cancel();
    _messageUpdatesSubscription?.cancel();
    for (final timer in _optimisticTimeouts.values) {
      timer.cancel();
    }
    _optimisticTimeouts.clear();
    super.dispose();
  }

  void setFilterDate(DateTime? date) {
    if (_filterAfterDate != date) {
      _filterAfterDate = date;
      loadInitial();
    }
  }

  Future<void> loadInitial() async {
    _loadCacheSync();
    await _loadNetworkData();
  }

  Future<void> loadMore() async {
    if (!mounted || !state.canLoadMore) return;

    state = state.copyWith(isLoadingMore: true);

    final result = await _ref
        .read(messageRepositoryProvider)
        .getMessagesPaginated(
          conversationId: conversationId,
          limit: _pageSize,
          beforeMessageId: state.lastMessageId,
          filterAfterDate: _filterAfterDate,
        );

    if (!mounted) return;

    result.fold(
      (failure) {
        if (mounted) {
          state = state.copyWith(isLoadingMore: false, error: failure.message);
        }
      },
      (paginatedMessages) {
        if (mounted) {
          state = state.copyWith(
            messages: [...paginatedMessages.messages, ...state.messages],
            hasMore: paginatedMessages.hasMore,
            lastMessageId: paginatedMessages.lastMessageId,
            oldestMessageTimestamp: paginatedMessages.oldestMessageTimestamp,
            isLoadingMore: false,
          );
        }
      },
    );
  }

  void _listenForNewMessages(DateTime afterTimestamp) {
    _newMessagesSubscription?.cancel();
    _newMessagesSubscription = _ref
        .read(messageRepositoryProvider)
        .getNewMessagesStream(
          conversationId: conversationId,
          afterTimestamp: afterTimestamp,
        )
        .listen((either) {
          if (!mounted) return;
          either.fold(
            (failure) {},
            (newMessages) {
              if (!mounted) return;
              if (newMessages.isNotEmpty) {
                debugPrint('📥 New messages received: ${newMessages.length}');
                final existingMessages = List<MessageEntity>.from(state.messages);

                for (final newMessage in newMessages) {
                  debugPrint('📨 Processing new message: type=${newMessage.type}, id=${newMessage.id}, lat=${newMessage.latitude}, lng=${newMessage.longitude}');

                  // Priority 1: exact clientMessageId match (deterministic, no false merges)
                  int optimisticIndex = existingMessages.indexWhere(
                    (m) =>
                        m.id.startsWith('temp_') &&
                        newMessage.clientMessageId != null &&
                        m.clientMessageId == newMessage.clientMessageId,
                  );

                  // Priority 2: fall back to temporal+content heuristic for messages
                  // without a clientMessageId (e.g. older clients, other message types)
                  if (optimisticIndex == -1) {
                    optimisticIndex = existingMessages.indexWhere(
                      (m) {
                        final idMatch = m.id.startsWith('temp_');
                        final senderMatch = m.senderId == newMessage.senderId;
                        final typeMatch = m.type == newMessage.type;
                        final timeDiff = m.createdAt.difference(newMessage.createdAt).abs().inSeconds;
                        final timeMatch = timeDiff < 5;
                        final contentMatch = _matchesOptimisticMessage(m, newMessage);
                        // Only use temporal matching when no clientMessageId is available
                        final noClientId = m.clientMessageId == null && newMessage.clientMessageId == null;

                        if (idMatch && senderMatch && typeMatch) {
                          debugPrint('🔍 Checking optimistic match: id=${m.id}, timeDiff=$timeDiff, timeMatch=$timeMatch, contentMatch=$contentMatch');
                        }

                        return idMatch && senderMatch && typeMatch && timeMatch && contentMatch && noClientId;
                      },
                    );
                  }

                  if (optimisticIndex != -1) {
                    debugPrint('✅ Found optimistic match at index $optimisticIndex, replacing with real message');
                    _cancelOptimisticTimeout(existingMessages[optimisticIndex].id);
                    existingMessages[optimisticIndex] = newMessage;
                  } else if (!existingMessages.any((m) => m.id == newMessage.id)) {
                    debugPrint('➕ Adding new message (no optimistic match found)');
                    existingMessages.add(newMessage);
                  } else {
                    debugPrint('⏭️ Message already exists, skipping');
                  }
                }

                existingMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
                state = state.copyWith(messages: existingMessages);
              }
            },
          );
        });
  }

  void _listenForMessageUpdates() {
    _messageUpdatesSubscription?.cancel();
    _messageUpdatesSubscription = _ref
        .read(messageRepositoryProvider)
        .getMessageUpdatesStream(conversationId: conversationId)
        .listen((either) {
          if (!mounted) return;
          either.fold(
            (failure) {},
            (updatedMessage) {
              if (!mounted) return;
              final existingMessages = List<MessageEntity>.from(state.messages);
              final index = existingMessages.indexWhere((m) => m.id == updatedMessage.id);

              if (index != -1) {
                // getMessageUpdatesStream fournit la ligne BRUTE (non déchiffrée) :
                // son `content` est le chiffré au repos. Re-déchiffrer ici est
                // impossible pour Signal — le Double Ratchet a déjà consommé la
                // clé du message au 1er déchiffrement, un 2e échouerait.
                // On conserve donc le contenu déjà déchiffré et on n'applique que
                // les métadonnées mutables portées par l'update (réactions, statut
                // lu/livré, épinglage, etc.). Les vrais changements de contenu
                // (suppression pour tous) passent par des chemins dédiés.
                final existing = existingMessages[index];
                existingMessages[index] = updatedMessage.copyWith(
                  content: existing.content,
                  fileUrl: existing.fileUrl,
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

  void removeMessageOptimistically(String messageId) {
    if (!mounted) return;
    final existingMessages = List<MessageEntity>.from(state.messages);
    existingMessages.removeWhere((m) => m.id == messageId);
    state = state.copyWith(messages: existingMessages);
  }

  void markMessageDeletedForMe(String messageId, String userId) {
    if (!mounted) return;
    final existingMessages = List<MessageEntity>.from(state.messages);
    final index = existingMessages.indexWhere((m) => m.id == messageId);

    if (index != -1) {
      final message = existingMessages[index];
      final updatedMessage = message.copyWith(
        deletedFor: [...message.deletedFor, userId],
      );
      existingMessages[index] = updatedMessage;
      state = state.copyWith(messages: existingMessages);
    }
  }

  void markMessageDeletedForEveryone(String messageId) {
    if (!mounted) return;
    final existingMessages = List<MessageEntity>.from(state.messages);
    final index = existingMessages.indexWhere((m) => m.id == messageId);

    if (index != -1) {
      final message = existingMessages[index];
      final updatedMessage = message.copyWith(
        content: 'Message supprimé',
        fileUrl: null,
        audioWaveform: null,
        thumbnailUrl: null,
        deletedForEveryone: true,
        deletedAt: DateTime.now(),
      );
      existingMessages[index] = updatedMessage;
      state = state.copyWith(messages: existingMessages);
    }
  }

  void addOptimisticMessage(MessageEntity message) {
    if (!mounted) return;
    state = state.copyWith(messages: [...state.messages, message]);

    _optimisticTimeouts[message.id] = Timer(
      const Duration(seconds: 30),
      () => _handleOptimisticTimeout(message.id),
    );
  }

  void _handleOptimisticTimeout(String messageId) {
    _optimisticTimeouts.remove(messageId);
    if (!mounted) return;

    final messages = state.messages;
    final index = messages.indexWhere((m) => m.id == messageId);

    if (index != -1 && messages[index].status == MessageStatus.sending) {
      updateMessageStatus(messageId, MessageStatus.failed);
    }
  }

  void _cancelOptimisticTimeout(String messageId) {
    _optimisticTimeouts[messageId]?.cancel();
    _optimisticTimeouts.remove(messageId);
  }

  /// Check if an optimistic message matches a new message from the server
  /// For location messages, compare coordinates; for others, compare content
  bool _matchesOptimisticMessage(MessageEntity optimistic, MessageEntity newMessage) {
    // For location messages, match by coordinates (more reliable than content)
    if (optimistic.type == MessageType.location && newMessage.type == MessageType.location) {
      final latMatch = optimistic.latitude != null &&
          newMessage.latitude != null &&
          (optimistic.latitude! - newMessage.latitude!).abs() < 0.0001;
      final lngMatch = optimistic.longitude != null &&
          newMessage.longitude != null &&
          (optimistic.longitude! - newMessage.longitude!).abs() < 0.0001;
      return latMatch && lngMatch;
    }

    // For text messages, content must match exactly
    if (optimistic.type == MessageType.text) {
      return optimistic.content == newMessage.content;
    }

    // For other message types (audio, image, video, file), just match by type
    // since they're already filtered by sender, type, and time window
    return true;
  }

  void updateMessageStatus(String messageId, MessageStatus newStatus) {
    if (!mounted) return;
    final messages = state.messages.map((m) {
      if (m.id == messageId) {
        return m.copyWith(status: newStatus);
      }
      return m;
    }).toList();

    state = state.copyWith(messages: messages);
  }

  /// Met à jour le statut du message et remplace l'ID optimiste par l'ID réel
  void updateMessageStatusAndCancelTimeout(
    String optimisticId,
    MessageStatus newStatus,
    String realId,
  ) {
    // Annuler le timer de timeout
    _cancelOptimisticTimeout(optimisticId);

    if (!mounted) return;

    final messages = state.messages.map((m) {
      if (m.id == optimisticId) {
        return m.copyWith(
          id: realId,
          status: newStatus,
        );
      }
      return m;
    }).toList();

    state = state.copyWith(messages: messages);
  }

  Future<void> toggleReaction(String messageId, String emoji) async {
    if (!mounted) return;
    final messageIndex = state.messages.indexWhere((m) => m.id == messageId);
    if (messageIndex == -1) return;

    final message = state.messages[messageIndex];
    final currentReactions = List<String>.from(message.reactions);
    final hasReaction = currentReactions.contains(emoji);

    if (hasReaction) {
      currentReactions.remove(emoji);
    } else {
      currentReactions.add(emoji);
    }

    final updatedMessage = message.copyWith(reactions: currentReactions);
    final updatedMessages = List<MessageEntity>.from(state.messages);
    updatedMessages[messageIndex] = updatedMessage;
    state = state.copyWith(messages: updatedMessages);

    try {
      if (hasReaction) {
        await _ref.read(messageRemoteDataSourceProvider).removeReaction(
          conversationId: conversationId,
          messageId: messageId,
          emoji: emoji,
        );
      } else {
        await _ref.read(messageRemoteDataSourceProvider).addReaction(
          conversationId: conversationId,
          messageId: messageId,
          emoji: emoji,
        );
      }
    } catch (e) {
      if (!mounted) return;
      final revertedMessages = List<MessageEntity>.from(state.messages);
      if (revertedMessages.length > messageIndex &&
          revertedMessages[messageIndex].id == messageId) {
        revertedMessages[messageIndex] = message;
        state = state.copyWith(messages: revertedMessages);
      }
    }
  }

  Future<void> toggleStar(String messageId) async {
    final currentUser = _ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser == null) return;

    final messageIndex = state.messages.indexWhere((m) => m.id == messageId);
    if (messageIndex == -1) return;

    final message = state.messages[messageIndex];
    final isCurrentlyStarred = message.starredBy.contains(currentUser.id);

    final updatedStarredBy = List<String>.from(message.starredBy);
    if (isCurrentlyStarred) {
      updatedStarredBy.remove(currentUser.id);
    } else {
      updatedStarredBy.add(currentUser.id);
    }

    final updatedMessage = message.copyWith(starredBy: updatedStarredBy);
    final updatedMessages = List<MessageEntity>.from(state.messages);
    updatedMessages[messageIndex] = updatedMessage;
    state = state.copyWith(messages: updatedMessages);

    try {
      await _ref.read(messageRemoteDataSourceProvider).toggleStarMessage(
        conversationId: conversationId,
        messageId: messageId,
        userId: currentUser.id,
      );
    } catch (e) {
      final revertedMessages = List<MessageEntity>.from(state.messages);
      if (revertedMessages.length > messageIndex &&
          revertedMessages[messageIndex].id == messageId) {
        revertedMessages[messageIndex] = message;
        state = state.copyWith(messages: revertedMessages);
      }
    }
  }

  /// Mark all messages as read locally for instant UI feedback
  void markAllAsReadLocally(String userId) {
    if (!mounted) return;

    // Avoid any allocation when everything is already marked read.
    final needsUpdate = state.messages.any(
      (m) => !m.readBy.contains(userId) && m.senderId != userId,
    );
    if (!needsUpdate) return;

    final updatedMessages = state.messages.map((message) {
      if (message.readBy.contains(userId) || message.senderId == userId) {
        return message;
      }
      return message.copyWith(
        readBy: [...message.readBy, userId],
        readAt: {...message.readAt, userId: DateTime.now()},
      );
    }).toList();

    state = state.copyWith(messages: updatedMessages);
  }

  /// Edit a text message (within 25 minute time limit)
  Future<bool> editMessage({
    required String messageId,
    required String newContent,
  }) async {
    final currentUser = _ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser == null) return false;

    final messageIndex = state.messages.indexWhere((m) => m.id == messageId);
    if (messageIndex == -1) return false;

    final message = state.messages[messageIndex];

    // Check if user can edit this message
    if (!message.canEdit(currentUser.id)) return false;

    final oldContent = message.content;
    if (newContent == oldContent) return true; // No change

    // Optimistic update
    final updatedMessage = message.copyWith(
      content: newContent,
      editedAt: DateTime.now(),
    );
    final updatedMessages = List<MessageEntity>.from(state.messages);
    updatedMessages[messageIndex] = updatedMessage;
    state = state.copyWith(messages: updatedMessages);

    try {
      await _ref.read(messageRemoteDataSourceProvider).editMessage(
        conversationId: conversationId,
        messageId: messageId,
        newContent: newContent,
        oldContent: oldContent,
      );
      return true;
    } catch (e) {
      // Revert on error
      final revertedMessages = List<MessageEntity>.from(state.messages);
      if (revertedMessages.length > messageIndex &&
          revertedMessages[messageIndex].id == messageId) {
        revertedMessages[messageIndex] = message;
        state = state.copyWith(messages: revertedMessages);
      }
      return false;
    }
  }
}

// ============ Notifier pour envoyer des messages ============

final sendMessageProvider = StateNotifierProvider<SendMessageNotifier, AsyncValue<void>>(
  (ref) => SendMessageNotifier(ref),
);

const _uuid = Uuid();

class SendMessageNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  SendMessageNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<bool> sendText({
    required String conversationId,
    required String content,
    String? optimisticMessageId,
    String? clientMessageId,
    int attempt = 1,
    int maxAttempts = 3,
    MessageEntity? replyToMessage,
    Map<String, dynamic>? productData,
    Map<String, dynamic>? postData,
    List<String> sentWhileBlockedBy = const [],
    Map<String, dynamic>? linkPreviewData,
    bool isForwarded = false,
    List<MentionedUser> mentionedUsers = const [],
  }) async {
    final currentUser = _ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser == null) return false;

    final senderIsVerified = _ref.read(userStreamProvider(currentUser.id)).valueOrNull?.isVerified ?? false;

    // Verifier la connectivite
    final isOnline = _ref.read(connectivityNotifierProvider);

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

    // Mode offline: ajouter a la queue et afficher message optimiste
    if (!isOnline && attempt == 1) {
      final pendingMessage = PendingMessage(
        conversationId: conversationId,
        senderId: currentUser.id,
        senderName: currentUser.displayName ?? 'Utilisateur',
        senderPhotoUrl: currentUser.photoUrl,
        content: content,
        type: 'text',
      );

      await _ref.read(offlineQueueServiceProvider).enqueue(pendingMessage);

      // Ajouter un message optimiste local avec status pending
      final optimisticMessage = MessageEntity(
        id: 'pending_${pendingMessage.id}',
        senderId: currentUser.id,
        senderName: currentUser.displayName ?? 'Utilisateur',
        senderPhotoUrl: currentUser.photoUrl,
        content: content,
        type: MessageType.text,
        status: MessageStatus.sending, // Sera affiche comme "En attente"
        createdAt: DateTime.now(),
        readBy: [],
        readAt: {},
        replyToId: replyToMessage?.id,
        replyToMessageData: replyToMessageData,
        productData: productData,
        postData: postData,
        sentWhileBlockedBy: sentWhileBlockedBy,
      );

      _ref.read(paginatedMessagesProvider(conversationId).notifier).addOptimisticMessage(optimisticMessage);
      return true; // Retourner true car le message est en queue
    }

    if (linkPreviewData == null && attempt == 1 && !isForwarded) {
      final url = LinkPreviewService.extractFirstUrl(content);
      if (url != null) {
        try {
          final preview = await _ref.read(linkPreviewServiceProvider).fetchLinkPreview(url);
          if (preview != null && preview.hasContent) {
            linkPreviewData = preview.toMap();
          }
        } catch (_) {}
      }
    }

    final tempId = optimisticMessageId ?? 'temp_${DateTime.now().millisecondsSinceEpoch}';
    // Generate once on first attempt; preserve across retries for stable matching.
    final cid = clientMessageId ?? _uuid.v4();

    final optimisticMessage = MessageEntity(
      id: tempId,
      senderId: currentUser.id,
      senderName: currentUser.displayName ?? 'Utilisateur',
      senderPhotoUrl: currentUser.photoUrl,
      senderIsVerified: senderIsVerified,
      content: content,
      type: MessageType.text,
      status: MessageStatus.sending,
      createdAt: DateTime.now(),
      readBy: [],
      readAt: {},
      replyToId: replyToMessage?.id,
      replyToMessageData: replyToMessageData,
      productData: productData,
      postData: postData,
      sentWhileBlockedBy: sentWhileBlockedBy,
      linkPreviewData: linkPreviewData,
      isForwarded: isForwarded,
      mentionedUsers: mentionedUsers,
      clientMessageId: cid,
    );

    if (attempt == 1) {
      _ref.read(paginatedMessagesProvider(conversationId).notifier).addOptimisticMessage(optimisticMessage);
    }

    // Resolve E2EE target on every attempt so retries don't lose the recipient.
    String? recipientId;
    List<String> participantIds = const [];
    final conversation = _ref.read(conversationStreamProvider(conversationId)).valueOrNull;
    if (conversation != null) {
      if (conversation.isIndividual) {
        recipientId = conversation.getOtherParticipantId(currentUser.id);
      } else {
        participantIds = conversation.participantIds
            .where((id) => id != currentUser.id)
            .toList();
      }
    }

    final result = await _ref.read(messageRepositoryProvider).sendTextMessage(
      conversationId: conversationId,
      senderId: currentUser.id,
      senderName: currentUser.displayName ?? 'Utilisateur',
      senderPhotoUrl: currentUser.photoUrl,
      senderIsVerified: senderIsVerified,
      content: content,
      replyToId: replyToMessage?.id,
      replyToMessageData: replyToMessageData,
      productData: productData,
      postData: postData,
      sentWhileBlockedBy: sentWhileBlockedBy,
      linkPreviewData: linkPreviewData,
      isForwarded: isForwarded,
      mentionedUsers: mentionedUsers,
      clientMessageId: cid,
      recipientId: recipientId,
      participantIds: participantIds,
    );

    return result.fold(
      (failure) async {
        if (attempt < maxAttempts && failure is! E2EEFailure) {
          await Future.delayed(Duration(seconds: attempt * 2));
          return await sendText(
            conversationId: conversationId,
            content: content,
            optimisticMessageId: tempId,
            clientMessageId: cid,
            attempt: attempt + 1,
            maxAttempts: maxAttempts,
            replyToMessage: replyToMessage,
            productData: productData,
            postData: postData,
            sentWhileBlockedBy: sentWhileBlockedBy,
            linkPreviewData: linkPreviewData,
            isForwarded: isForwarded,
            mentionedUsers: mentionedUsers,
          );
        }

        _ref.read(paginatedMessagesProvider(conversationId).notifier).updateMessageStatus(tempId, MessageStatus.failed);
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (message) {
        // Mettre à jour immédiatement le message optimiste avec l'ID réel
        _ref.read(paginatedMessagesProvider(conversationId).notifier)
            .updateMessageStatusAndCancelTimeout(tempId, MessageStatus.sent, message.id);
        state = const AsyncValue.data(null);
        return true;
      },
    );
  }

  Future<bool> retryFailedMessage({
    required String conversationId,
    required MessageEntity failedMessage,
  }) async {
    _ref.read(paginatedMessagesProvider(conversationId).notifier).removeMessageOptimistically(failedMessage.id);

    MessageEntity? replyToMessage;
    if (failedMessage.replyToId != null && failedMessage.replyToMessageData != null) {
      final replyData = failedMessage.replyToMessageData!;
      replyToMessage = MessageEntity(
        id: replyData['id'] as String? ?? '',
        senderId: replyData['senderId'] as String? ?? '',
        senderName: replyData['senderName'] as String? ?? '',
        content: replyData['content'] as String? ?? '',
        type: MessageType.values.firstWhere(
          (t) => t.name == (replyData['type'] as String? ?? 'text'),
          orElse: () => MessageType.text,
        ),
        createdAt: DateTime.now(),
        readBy: [],
        readAt: {},
        fileUrl: replyData['fileUrl'] as String?,
        fileName: replyData['fileName'] as String?,
      );
    }

    switch (failedMessage.type) {
      case MessageType.text:
        return sendText(
          conversationId: conversationId,
          content: failedMessage.content,
          replyToMessage: replyToMessage,
          productData: failedMessage.productData,
        );
      case MessageType.image:
      case MessageType.file:
      case MessageType.video:
      case MessageType.audio:
      case MessageType.voiceNote:
        state = AsyncValue.error(
          'Impossible de renvoyer ce type de message. Veuillez le renvoyer manuellement.',
          StackTrace.current,
        );
        return false;
      case MessageType.location:
        if (failedMessage.latitude != null && failedMessage.longitude != null) {
          return sendLocation(
            conversationId: conversationId,
            latitude: failedMessage.latitude!,
            longitude: failedMessage.longitude!,
            address: failedMessage.locationAddress ?? '',
            replyToMessage: replyToMessage,
          );
        }
        return false;
      case MessageType.system:
      case MessageType.call:
        return false;
      case MessageType.sticker:
        if (failedMessage.stickerPackId != null && failedMessage.stickerId != null && failedMessage.fileUrl != null) {
          return sendSticker(
            conversationId: conversationId,
            stickerPackId: failedMessage.stickerPackId!,
            stickerId: failedMessage.stickerId!,
            stickerUrl: failedMessage.fileUrl!,
            isAnimated: failedMessage.isAnimatedSticker,
            replyToMessage: replyToMessage,
          );
        }
        return false;
    }
  }

  Future<bool> sendFile({
    required String conversationId,
    required File file,
    required MessageType type,
    String? caption,
    MessageEntity? replyToMessage,
  }) async {
    final currentUser = _ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser == null) return false;

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

    final uploadNotifier = _ref.read(mediaUploadProvider.notifier);
    uploadNotifier.startUpload(
      file: file,
      conversationId: conversationId,
      isImage: type == MessageType.image,
      caption: caption,
    );

    final result = await _ref.read(messageRepositoryProvider).sendFileMessage(
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
        return _ref.read(mediaUploadProvider).status == MediaUploadStatus.cancelled;
      },
      replyToId: replyToMessage?.id,
      replyToMessageData: replyToMessageData,
    );

    return result.fold(
      (failure) {
        if (failure.message == 'Envoi annulé') {
          uploadNotifier.cancel();
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
    final currentUser = _ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser == null) return false;

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

    final tempId = 'temp_audio_${DateTime.now().millisecondsSinceEpoch}';

    final optimisticMessage = MessageEntity(
      id: tempId,
      senderId: currentUser.id,
      senderName: currentUser.displayName ?? 'Utilisateur',
      senderPhotoUrl: currentUser.photoUrl,
      content: '',
      type: MessageType.voiceNote,
      status: MessageStatus.sending,
      audioDuration: duration,
      audioWaveform: waveform,
      createdAt: DateTime.now(),
      readBy: [],
      readAt: {},
      replyToId: replyToMessage?.id,
      replyToMessageData: replyToMessageData,
    );

    _ref.read(paginatedMessagesProvider(conversationId).notifier).addOptimisticMessage(optimisticMessage);

    final result = await _ref.read(messageRepositoryProvider).sendAudioMessage(
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
        _ref.read(paginatedMessagesProvider(conversationId).notifier).updateMessageStatus(tempId, MessageStatus.failed);
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (message) {
        // Mettre à jour immédiatement le message optimiste avec l'ID réel
        _ref.read(paginatedMessagesProvider(conversationId).notifier)
            .updateMessageStatusAndCancelTimeout(tempId, MessageStatus.sent, message.id);
        state = const AsyncValue.data(null);
        return true;
      },
    );
  }

  Future<bool> sendLocation({
    required String conversationId,
    required double latitude,
    required double longitude,
    required String address,
    MessageEntity? replyToMessage,
  }) async {
    final currentUser = _ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser == null) return false;

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

    final tempId = 'temp_location_${DateTime.now().millisecondsSinceEpoch}';

    final optimisticMessage = MessageEntity(
      id: tempId,
      senderId: currentUser.id,
      senderName: currentUser.displayName ?? 'Utilisateur',
      senderPhotoUrl: currentUser.photoUrl,
      content: address.isNotEmpty ? address : 'Position partagée',
      type: MessageType.location,
      status: MessageStatus.sending,
      latitude: latitude,
      longitude: longitude,
      locationAddress: address,
      createdAt: DateTime.now(),
      readBy: [],
      readAt: {},
      replyToId: replyToMessage?.id,
      replyToMessageData: replyToMessageData,
    );

    debugPrint('📍 sendLocation: Adding optimistic message with lat=$latitude, lng=$longitude, tempId=$tempId');
    _ref.read(paginatedMessagesProvider(conversationId).notifier).addOptimisticMessage(optimisticMessage);

    final result = await _ref.read(messageRepositoryProvider).sendLocationMessage(
      conversationId: conversationId,
      senderId: currentUser.id,
      senderName: currentUser.displayName ?? 'Utilisateur',
      senderPhotoUrl: currentUser.photoUrl,
      latitude: latitude,
      longitude: longitude,
      address: address,
      replyToId: replyToMessage?.id,
      replyToMessageData: replyToMessageData,
    );

    return result.fold(
      (failure) {
        debugPrint('❌ sendLocation: Failed - ${failure.message}');
        _ref.read(paginatedMessagesProvider(conversationId).notifier).updateMessageStatus(tempId, MessageStatus.failed);
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (message) {
        debugPrint('✅ sendLocation: Success - real message id=${message.id}, lat=${message.latitude}, lng=${message.longitude}');
        // Mettre à jour immédiatement le message optimiste avec l'ID réel
        _ref.read(paginatedMessagesProvider(conversationId).notifier)
            .updateMessageStatusAndCancelTimeout(tempId, MessageStatus.sent, message.id);
        state = const AsyncValue.data(null);
        return true;
      },
    );
  }

  Future<bool> sendSticker({
    required String conversationId,
    required String stickerPackId,
    required String stickerId,
    required String stickerUrl,
    bool isAnimated = false,
    MessageEntity? replyToMessage,
  }) async {
    final currentUser = _ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser == null) return false;

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

    final tempId = 'temp_sticker_${DateTime.now().millisecondsSinceEpoch}';

    final optimisticMessage = MessageEntity(
      id: tempId,
      senderId: currentUser.id,
      senderName: currentUser.displayName ?? 'Utilisateur',
      senderPhotoUrl: currentUser.photoUrl,
      content: 'Sticker',
      type: MessageType.sticker,
      status: MessageStatus.sending,
      fileUrl: stickerUrl,
      stickerPackId: stickerPackId,
      stickerId: stickerId,
      isAnimatedSticker: isAnimated,
      createdAt: DateTime.now(),
      readBy: [],
      readAt: {},
      replyToId: replyToMessage?.id,
      replyToMessageData: replyToMessageData,
    );

    debugPrint('🎭 sendSticker: Adding optimistic message with packId=$stickerPackId, stickerId=$stickerId, tempId=$tempId');
    _ref.read(paginatedMessagesProvider(conversationId).notifier).addOptimisticMessage(optimisticMessage);

    final result = await _ref.read(messageRepositoryProvider).sendStickerMessage(
      conversationId: conversationId,
      senderId: currentUser.id,
      senderName: currentUser.displayName ?? 'Utilisateur',
      senderPhotoUrl: currentUser.photoUrl,
      stickerPackId: stickerPackId,
      stickerId: stickerId,
      stickerUrl: stickerUrl,
      isAnimated: isAnimated,
      replyToId: replyToMessage?.id,
      replyToMessageData: replyToMessageData,
    );

    return result.fold(
      (failure) {
        debugPrint('❌ sendSticker: Failed - ${failure.message}');
        _ref.read(paginatedMessagesProvider(conversationId).notifier).updateMessageStatus(tempId, MessageStatus.failed);
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (message) {
        debugPrint('✅ sendSticker: Success - real message id=${message.id}');
        _ref.read(paginatedMessagesProvider(conversationId).notifier)
            .updateMessageStatusAndCancelTimeout(tempId, MessageStatus.sent, message.id);
        state = const AsyncValue.data(null);
        return true;
      },
    );
  }

  Future<bool> forwardMessage({
    required String targetConversationId,
    required MessageEntity originalMessage,
  }) async {
    final currentUser = _ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser == null) return false;

    switch (originalMessage.type) {
      case MessageType.text:
        return sendText(
          conversationId: targetConversationId,
          content: originalMessage.content,
          linkPreviewData: originalMessage.linkPreviewData,
          isForwarded: true,
        );

      case MessageType.image:
      case MessageType.video:
      case MessageType.file:
        if (originalMessage.fileUrl == null) return false;
        try {
          await _ref.read(messageRemoteDataSourceProvider).sendMediaMessage(
            conversationId: targetConversationId,
            senderId: currentUser.id,
            senderName: currentUser.displayName ?? 'Utilisateur',
            senderPhotoUrl: currentUser.photoUrl,
            fileUrl: originalMessage.fileUrl!,
            fileName: originalMessage.fileName ?? 'file',
            fileSize: originalMessage.fileSize ?? 0,
            mimeType: originalMessage.mimeType ?? 'application/octet-stream',
            type: originalMessage.type.name,
            caption: originalMessage.content != originalMessage.fileName ? originalMessage.content : null,
            isForwarded: true,
          );
          return true;
        } catch (e) {
          state = AsyncValue.error(e.toString(), StackTrace.current);
          return false;
        }

      case MessageType.audio:
        if (originalMessage.fileUrl == null) return false;
        try {
          await _ref.read(messageRemoteDataSourceProvider).sendMediaMessage(
            conversationId: targetConversationId,
            senderId: currentUser.id,
            senderName: currentUser.displayName ?? 'Utilisateur',
            senderPhotoUrl: currentUser.photoUrl,
            fileUrl: originalMessage.fileUrl!,
            fileName: originalMessage.fileName ?? 'audio',
            fileSize: originalMessage.fileSize ?? 0,
            mimeType: originalMessage.mimeType ?? 'audio/mp4',
            type: 'audioFile',
            audioDuration: originalMessage.audioDuration,
            isForwarded: true,
          );
          return true;
        } catch (e) {
          state = AsyncValue.error(e.toString(), StackTrace.current);
          return false;
        }

      case MessageType.voiceNote:
        if (originalMessage.fileUrl == null) return false;
        try {
          await _ref.read(messageRemoteDataSourceProvider).sendMediaMessage(
            conversationId: targetConversationId,
            senderId: currentUser.id,
            senderName: currentUser.displayName ?? 'Utilisateur',
            senderPhotoUrl: currentUser.photoUrl,
            fileUrl: originalMessage.fileUrl!,
            fileName: originalMessage.fileName ?? 'voice_note.m4a',
            fileSize: originalMessage.fileSize ?? 0,
            mimeType: originalMessage.mimeType ?? 'audio/mp4',
            type: 'voiceNote',
            audioDuration: originalMessage.audioDuration,
            audioWaveform: originalMessage.audioWaveform,
            isForwarded: true,
          );
          return true;
        } catch (e) {
          state = AsyncValue.error(e.toString(), StackTrace.current);
          return false;
        }

      case MessageType.location:
        if (originalMessage.latitude == null || originalMessage.longitude == null) return false;
        return sendLocation(
          conversationId: targetConversationId,
          latitude: originalMessage.latitude!,
          longitude: originalMessage.longitude!,
          address: originalMessage.locationAddress ?? '',
        );

      case MessageType.system:
      case MessageType.call:
        return false;

      case MessageType.sticker:
        if (originalMessage.stickerPackId == null ||
            originalMessage.stickerId == null ||
            originalMessage.fileUrl == null) {
          return false;
        }
        return sendSticker(
          conversationId: targetConversationId,
          stickerPackId: originalMessage.stickerPackId!,
          stickerId: originalMessage.stickerId!,
          stickerUrl: originalMessage.fileUrl!,
          isAnimated: originalMessage.isAnimatedSticker,
        );
    }
  }
}

// ============ Notifier pour creer des conversations ============

final createConversationProvider = StateNotifierProvider<CreateConversationNotifier, AsyncValue<ConversationEntity?>>(
  (ref) => CreateConversationNotifier(ref),
);

class CreateConversationNotifier extends StateNotifier<AsyncValue<ConversationEntity?>> {
  final Ref _ref;

  CreateConversationNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<ConversationEntity?> createIndividual(String otherUserId) async {
    final currentUser = _ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser == null) return null;

    state = const AsyncValue.loading();

    final result = await _ref.read(messageRepositoryProvider).getOrCreateIndividualConversation(
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
    String? groupId,
  }) async {
    final currentUser = _ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser == null) return null;

    state = const AsyncValue.loading();

    final result = await _ref.read(messageRepositoryProvider).createGroupConversation(
      creatorId: currentUser.id,
      participantIds: participantIds,
      groupName: groupName,
      groupImageUrl: groupImageUrl,
      groupId: groupId,
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

// ============ Marquer comme lu ============

final markAsReadProvider = StateNotifierProvider<MarkAsReadNotifier, AsyncValue<void>>(
  (ref) => MarkAsReadNotifier(ref),
);

class MarkAsReadNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  MarkAsReadNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<void> mark(String conversationId) async {
    final currentUser = _ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser == null) return;

    final userId = currentUser.id;

    // Update local state immediately for instant UI feedback
    try {
      final notifier = _ref.read(paginatedMessagesProvider(conversationId).notifier);
      notifier.markAllAsReadLocally(userId);
    } catch (_) {
      // Provider might not be active, that's OK
    }

    // Then sync to server
    await _ref.read(messageRepositoryProvider).markAsRead(
      conversationId: conversationId,
      userId: userId,
    );

    // Sync notification dismiss to other devices
    _syncDismissToOtherDevices(conversationId);
  }

  /// Syncs notification dismiss to other devices via Cloud Function
  /// This is fire-and-forget - we don't wait for the result
  void _syncDismissToOtherDevices(String conversationId) {
    // Run in background without awaiting
    Future(() async {
      try {
        // Get current FCM token
        final currentToken = await FirebaseMessaging.instance.getToken();

        // Call Cloud Function to sync dismiss to other devices
        await FirebaseFunctions.instance
            .httpsCallable('dismissConversationNotifications')
            .call({
          'conversationId': conversationId,
          'currentToken': currentToken,
        });

        debugPrint('MarkAsRead: Synced dismiss to other devices for $conversationId');
      } catch (e) {
        // Silently fail - this is best-effort sync
        debugPrint('MarkAsRead: Failed to sync dismiss: $e');
      }
    });
  }
}

// ============ Marquer comme livré ============

final markAsDeliveredProvider = StateNotifierProvider<MarkAsDeliveredNotifier, AsyncValue<void>>(
  (ref) => MarkAsDeliveredNotifier(ref),
);

class MarkAsDeliveredNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  MarkAsDeliveredNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<void> mark(String conversationId) async {
    final currentUser = _ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser == null) return;

    await _ref.read(messageRepositoryProvider).markAsDelivered(
      conversationId: conversationId,
      userId: currentUser.id,
    );
  }
}

// ============ Nombre total de messages non lus ============

final totalUnreadCountProvider = Provider<int>((ref) {
  final conversations = ref.watch(conversationsProvider).valueOrNull ?? [];
  final currentUser = ref.watch(currentUserProvider).valueOrNull;
  final blockedUsers = ref.watch(blockedUsersProvider).valueOrNull ?? [];
  final blockedUserIds = blockedUsers.map((u) => u.id).toSet();

  if (currentUser == null) return 0;

  return conversations.fold<int>(0, (total, conv) {
    if (conv.isIndividual) {
      final otherUserId = conv.getOtherParticipantId(currentUser.id);

      if (blockedUserIds.contains(otherUserId)) {
        return total;
      }

      final otherProfileAsync = ref.watch(userStreamProvider(otherUserId));
      final otherProfile = otherProfileAsync.valueOrNull;
      if (otherProfile != null && otherProfile.blockedByUserIds.contains(currentUser.id)) {
        return total;
      }
    }

    return total + conv.getUnreadCountFor(currentUser.id);
  });
});

// ============ Notifier pour supprimer des messages ============

final deleteMessageProvider = StateNotifierProvider<DeleteMessageNotifier, AsyncValue<void>>(
  (ref) => DeleteMessageNotifier(ref),
);

class DeleteMessageNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  DeleteMessageNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<bool> deleteForMe({
    required String conversationId,
    required String messageId,
  }) async {
    final currentUser = _ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser == null) return false;

    _ref.read(paginatedMessagesProvider(conversationId).notifier).markMessageDeletedForMe(messageId, currentUser.id);

    state = const AsyncValue.loading();

    final result = await _ref.read(messageRepositoryProvider).deleteMessageForMe(
      conversationId: conversationId,
      messageId: messageId,
      userId: currentUser.id,
    );

    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        _ref.invalidate(paginatedMessagesProvider(conversationId));
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        return true;
      },
    );
  }

  Future<bool> deleteForEveryone({
    required String conversationId,
    required String messageId,
  }) async {
    _ref.read(paginatedMessagesProvider(conversationId).notifier).markMessageDeletedForEveryone(messageId);

    state = const AsyncValue.loading();

    final result = await _ref.read(messageRepositoryProvider).deleteMessageForEveryone(
      conversationId: conversationId,
      messageId: messageId,
    );

    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        _ref.invalidate(paginatedMessagesProvider(conversationId));
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        return true;
      },
    );
  }
}

// ============ Messages favoris ============

final starredMessagesProvider = FutureProvider.family<List<MessageEntity>, String>((ref, conversationId) async {
  final currentUser = ref.watch(currentUserAsyncProvider).valueOrNull;
  if (currentUser == null) return [];

  final result = await ref.read(messageRepositoryProvider).getStarredMessages(
    conversationId: conversationId,
    userId: currentUser.id,
  );

  return result.fold(
    (failure) => <MessageEntity>[],
    (messages) => messages,
  );
});

// ============ Recherche de messages ============

final messageSearchProvider = FutureProvider.family<List<MessageEntity>, ({String conversationId, String query})>((ref, params) async {
  if (params.query.length < 2) return [];

  final result = await ref.read(messageRepositoryProvider).searchMessagesInConversation(
    conversationId: params.conversationId,
    query: params.query,
  );

  return result.fold(
    (failure) => <MessageEntity>[],
    (messages) => messages,
  );
});

// ============ MESSAGE REQUESTS (Zone Tampon) ============

/// Stream of pending message requests for the current user
final messageRequestsProvider = StreamProvider<List<ConversationEntity>>((ref) {
  final currentUser = ref.watch(currentUserAsyncProvider).valueOrNull;
  if (currentUser == null) {
    return Stream.value([]);
  }

  final repository = ref.watch(messageRepositoryProvider);
  return repository.getMessageRequests(currentUser.id).map((result) {
    return result.fold(
      (failure) => <ConversationEntity>[],
      (requests) => requests,
    );
  });
});

/// Count of pending message requests
final messageRequestsCountProvider = Provider<int>((ref) {
  final requests = ref.watch(messageRequestsProvider).valueOrNull ?? [];
  return requests.length;
});

/// Notifier for message request actions (accept/decline)
final messageRequestActionsProvider =
    StateNotifierProvider<MessageRequestActionsNotifier, AsyncValue<void>>((ref) {
  return MessageRequestActionsNotifier(ref);
});

class MessageRequestActionsNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  MessageRequestActionsNotifier(this._ref) : super(const AsyncValue.data(null));

  /// Accept a message request
  Future<bool> acceptRequest(String conversationId) async {
    final currentUser = _ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser == null) return false;

    state = const AsyncValue.loading();

    final result = await _ref.read(messageRepositoryProvider).acceptMessageRequest(
      conversationId: conversationId,
      recipientId: currentUser.id,
    );

    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        // Invalidate conversations to refresh the list
        _ref.invalidate(conversationsProvider);
        return true;
      },
    );
  }

  /// Decline a message request
  Future<bool> declineRequest(String conversationId) async {
    final currentUser = _ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser == null) return false;

    state = const AsyncValue.loading();

    final result = await _ref.read(messageRepositoryProvider).declineMessageRequest(
      conversationId: conversationId,
      recipientId: currentUser.id,
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
}
