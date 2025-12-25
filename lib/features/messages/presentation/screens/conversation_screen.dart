import 'dart:io';

import 'package:flutter/material.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/message_entity.dart';
import '../providers/message_provider.dart';
import '../widgets/conversation_options_modal.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_input.dart';
import '../../../settings/presentation/providers/blocked_users_provider.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ConversationScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final String? conversationName;
  final String? conversationImageUrl;
  final String? otherUserId;
  final bool isGroup;

  const ConversationScreen({
    super.key,
    required this.conversationId,
    this.conversationName,
    this.conversationImageUrl,
    this.otherUserId,
    this.isGroup = false,
  });

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isNearBottom = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Marquer comme lu à l'ouverture
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(markAsReadProvider.notifier).mark(widget.conversationId);
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Check if we're near the top to load more
    if (_scrollController.position.pixels <= 100) {
      final paginationState = ref.read(
        paginatedMessagesProvider(widget.conversationId),
      );
      if (paginationState.canLoadMore) {
        ref
            .read(paginatedMessagesProvider(widget.conversationId).notifier)
            .loadMore();
      }
    }

    // Track if we're near bottom
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    _isNearBottom = (maxScroll - currentScroll) <= 100;
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _showConversationOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (context) => ConversationOptionsModal(
            conversationId: widget.conversationId,
            otherUserName: widget.conversationName,
            otherUserPhotoUrl: widget.conversationImageUrl,
            isGroup: widget.isGroup,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final paginationState = ref.watch(
      paginatedMessagesProvider(widget.conversationId),
    );
    final sendMessageState = ref.watch(sendMessageProvider);

    // Watch conversation stream to detect changes/deletion
    final conversationAsync = ref.watch(
      conversationStreamProvider(widget.conversationId),
    );
    final conversation = conversationAsync.valueOrNull;

    // Watch blocked users
    final blockedUsersAsync = ref.watch(blockedUsersProvider);
    final blockedUsers = blockedUsersAsync.valueOrNull ?? [];

    final l10n = AppLocalizations.of(context)!;

    // Check if conversation exists (it might be null if deleted)
    final isDeleted = !conversationAsync.isLoading && conversation == null;

    // Check if other user is blocked (only for individual chats)
    bool isBlocked = false;
    if (!widget.isGroup && conversation != null) {
      final otherUserId = conversation.getOtherParticipantId(
        currentUser?.id ?? '',
      );
      isBlocked = blockedUsers.any((user) => user.id == otherUserId);
    }

    // Auto-scroll to bottom when new messages arrive
    ref.listen(paginatedMessagesProvider(widget.conversationId), (
      previous,
      next,
    ) {
      if (previous != null &&
          next.messages.length > previous.messages.length &&
          _isNearBottom) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });
      }
    });

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Offline indicator
          if (paginationState.isOffline)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              color: context.adaptivePrimaryColor.withValues(alpha: 0.1),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.wifi_off,
                    size: 14,
                    color: context.adaptivePrimaryColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l10n.offlineMode,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.adaptivePrimaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          // Messages
          Expanded(
            child: _buildMessageList(paginationState, currentUser?.id, l10n),
          ),

          // Input or Blocked/Deleted Message
          if (isDeleted)
            Container(
              padding: const EdgeInsets.all(16),
              color: context.surfaceColor,
              width: double.infinity,
              child: Text(
                "Ce groupe a été supprimé",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color:
                      context.isDarkMode
                          ? AppColors.errorDark
                          : AppColors.error,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          else if (isBlocked)
            Container(
              padding: const EdgeInsets.all(16),
              color: context.surfaceColor,
              width: double.infinity,
              child: Text(
                "Vous avez bloqué cet utilisateur",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color:
                      context.isDarkMode
                          ? AppColors.errorDark
                          : AppColors.error,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          else
            MessageInput(
              isLoading: sendMessageState.isLoading,
              onSendText: (text) async {
                // Generate unique message ID
                final messageId =
                    'temp_${DateTime.now().millisecondsSinceEpoch}';

                // Add optimistic message immediately
                final currentUser = ref.read(currentUserProvider).valueOrNull;
                if (currentUser != null) {
                  final optimisticMessage = MessageEntity(
                    id: messageId,
                    senderId: currentUser.id,
                    senderName: currentUser.displayName ?? 'You',
                    senderPhotoUrl: currentUser.photoUrl,
                    content: text,
                    type: MessageType.text,
                    status: MessageStatus.sending, // Message en cours d'envoi
                    createdAt: DateTime.now(),
                    readBy: [currentUser.id],
                  );

                  ref
                      .read(
                        paginatedMessagesProvider(
                          widget.conversationId,
                        ).notifier,
                      )
                      .addOptimisticMessage(optimisticMessage);
                }

                // Send with retry logic
                final success = await ref
                    .read(sendMessageProvider.notifier)
                    .sendText(
                      conversationId: widget.conversationId,
                      content: text,
                      optimisticMessageId: messageId,
                    );

                // If final failure after all retries, mark as failed
                if (!success) {
                  ref
                      .read(
                        paginatedMessagesProvider(
                          widget.conversationId,
                        ).notifier,
                      )
                      .updateMessageStatus(messageId, MessageStatus.failed);
                }

                if (success) {
                  _scrollToBottom();
                }
              },
              onSendFile: (File file, bool isImage) async {
                final success = await ref
                    .read(sendMessageProvider.notifier)
                    .sendFile(
                      conversationId: widget.conversationId,
                      file: file,
                      type: isImage ? MessageType.image : MessageType.file,
                    );
                if (success) {
                  _scrollToBottom();
                }
              },
            ),
        ],
      ),
    );
  }

  Widget _buildMessageList(
    dynamic paginationState,
    String? currentUserId,
    AppLocalizations l10n,
  ) {
    if (paginationState.isLoadingInitial) {
      return Center(
        child: CircularProgressIndicator(color: context.adaptivePrimaryColor),
      );
    }

    if (paginationState.error != null && paginationState.messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: context.textTertiaryColor,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.loadingError,
              style: TextStyle(color: context.textSecondaryColor, fontSize: 16),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () {
                ref
                    .read(
                      paginatedMessagesProvider(widget.conversationId).notifier,
                    )
                    .refresh();
              },
              icon: const Icon(Icons.refresh),
              label: Text(l10n.retry),
            ),
          ],
        ),
      );
    }

    if (paginationState.messages.isEmpty) {
      return _buildEmptyState();
    }

    final messages = paginationState.messages as List<MessageEntity>;

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: messages.length + (paginationState.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        // Show loading indicator at the top when loading more
        if (paginationState.isLoadingMore && index == 0) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.adaptivePrimaryColor,
                ),
              ),
            ),
          );
        }

        final messageIndex = paginationState.isLoadingMore ? index - 1 : index;
        final message = messages[messageIndex];
        final isMe = message.senderId == currentUserId;
        final showSenderInfo =
            widget.isGroup &&
            !isMe &&
            (messageIndex == 0 ||
                messages[messageIndex - 1].senderId != message.senderId);

        return MessageBubble(
          message: message,
          isMe: isMe,
          showSenderInfo: showSenderInfo,
          onSenderTap: (userId) {
            if (widget.isGroup) {
              context.push('/profile/$userId');
            }
          },
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar() {
    // Stream other user's profile if it's an individual chat
    AsyncValue<dynamic>? otherUserAsync;
    if (!widget.isGroup && widget.otherUserId != null) {
      // Use the profile provider to get real-time updates
      otherUserAsync = ref.watch(userStreamProvider(widget.otherUserId!));
    }

    final otherUser = otherUserAsync?.valueOrNull;

    // Determined displayed name and image
    final displayName =
        widget.isGroup
            ? widget.conversationName
            : otherUser?.displayName ?? widget.conversationName;

    final displayImage =
        widget.isGroup
            ? widget.conversationImageUrl
            : otherUser?.photoUrl ?? widget.conversationImageUrl;

    return AppBar(
      backgroundColor: context.surfaceColor,
      elevation: 0,
      leading: IconButton(
        onPressed: () => Navigator.of(context).pop(),
        icon: Icon(Icons.arrow_back, color: context.textPrimaryColor),
      ),
      title: InkWell(
        onTap: () {
          if (widget.isGroup) {
            context.push('/groups/${widget.conversationId}');
          } else if (widget.otherUserId != null) {
            context.push('/profile/${widget.otherUserId}');
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient:
                      widget.isGroup
                          ? AppColors.secondaryGradient
                          : context.adaptivePrimaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child:
                    displayImage != null
                        ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl: displayImage,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => const SizedBox(),
                            errorWidget:
                                (_, __, ___) => Icon(
                                  widget.isGroup ? Icons.groups : Icons.person,
                                  color: AppColors.white,
                                  size: 20,
                                ),
                          ),
                        )
                        : Icon(
                          widget.isGroup ? Icons.groups : Icons.person,
                          color: AppColors.white,
                          size: 20,
                        ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName ?? AppLocalizations.of(context)!.conversation,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimaryColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.isGroup)
                      Text(
                        AppLocalizations.of(context)!.group,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textTertiaryColor,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        IconButton(
          onPressed: () => _showConversationOptions(),
          icon: _buildMoreValuesIcon(context),
        ),
      ],
    );
  }

  Widget _buildMoreValuesIcon(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: context.surfaceVariantColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(Icons.more_vert, color: context.textPrimaryColor, size: 20),
    );
  }

  Widget _buildEmptyState() {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: context.adaptivePrimaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline,
              size: 48,
              color: context.adaptivePrimaryColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.noMessages,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: context.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.sendFirstMessage,
            style: TextStyle(fontSize: 14, color: context.textSecondaryColor),
          ),
        ],
      ),
    );
  }
}
