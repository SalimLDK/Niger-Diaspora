import 'dart:io';

import 'package:flutter/material.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/message_entity.dart';
import '../providers/message_provider.dart';
import '../providers/typing_indicator_provider.dart';
import '../providers/media_upload_provider.dart';
import '../widgets/conversation_options_modal.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_input.dart';
import '../widgets/typing_indicator_widget.dart';
import '../widgets/uploading_media_skeleton.dart';
import '../../../settings/presentation/providers/blocked_users_provider.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../groups/presentation/providers/group_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../profile/presentation/widgets/online_status_indicator.dart';
import '../../../../core/services/preferences_service.dart';
import '../../../settings/data/models/chat_background_model.dart';
import '../../../settings/domain/entities/chat_background_entity.dart';
import '../widgets/chat_background_picker_modal.dart';
import 'dart:convert';

class ConversationScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final String? conversationName;
  final String? conversationImageUrl;
  final String? otherUserId;
  final bool isGroup;
  final String? groupId;

  const ConversationScreen({
    super.key,
    required this.conversationId,
    this.conversationName,
    this.conversationImageUrl,
    this.otherUserId,
    this.isGroup = false,
    this.groupId,
  });

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  bool _isNearBottom = true;

  // Use ValueNotifier for scroll button visibility to avoid full rebuilds
  final ValueNotifier<bool> _showScrollToBottomButton = ValueNotifier(false);

  // Reply state
  MessageEntity? _replyToMessage;

  // Animation for scroll button
  late AnimationController _scrollButtonController;
  late Animation<double> _scrollButtonAnimation;

  // Chat background
  ChatBackgroundEntity? _chatBackground;

  // For highlighting a message when scrolling to it
  String? _highlightedMessageId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // debugPrint('🔍 ConversationScreen initialized:');
    // debugPrint('   conversationId: ${widget.conversationId}');
    // debugPrint('   isGroup: ${widget.isGroup}');
    // debugPrint('   groupId: ${widget.groupId}');
    // debugPrint('   otherUserId: ${widget.otherUserId}');

    _scrollController.addListener(_onScroll);

    _scrollButtonController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scrollButtonAnimation = CurvedAnimation(
      parent: _scrollButtonController,
      curve: Curves.easeOut,
    );

    // Mark as read on open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(markAsReadProvider.notifier).mark(widget.conversationId);
      _loadChatBackground();
      _setupPrivateGroupFilter();
    });
  }

  /// Configure le filtre de messages pour les groupes privés
  /// Les nouveaux membres ne voient pas les messages envoyés avant leur adhésion
  Future<void> _setupPrivateGroupFilter() async {
    if (!widget.isGroup || widget.groupId == null) return;

    final currentUser = ref.read(currentUserProvider).valueOrNull;
    if (currentUser == null) return;

    try {
      // Récupérer les informations du groupe via le repository
      final repository = ref.read(groupRepositoryProvider);
      final result = await repository.getGroupById(widget.groupId!);

      final group = result.fold((failure) => null, (group) => group);
      if (group == null) return;

      // Vérifier si c'est un groupe privé
      if (!group.isPrivate) return;

      // Récupérer la date d'adhésion de l'utilisateur
      final joinedAt = group.memberJoinedAt[currentUser.id];

      if (joinedAt != null) {
        // Appliquer le filtre pour ne montrer que les messages après l'adhésion
        ref
            .read(paginatedMessagesProvider(widget.conversationId).notifier)
            .setFilterDate(joinedAt);
      }
    } catch (e) {
      // En cas d'erreur, ne pas appliquer de filtre (fail-safe)
      // debugPrint('⚠️ Error setting up private group filter: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _scrollButtonController.dispose();
    _showScrollToBottomButton.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Refresh date separators when app resumes from background
    if (state == AppLifecycleState.resumed) {
      setState(() {
        // Force rebuild to update date labels like "Aujourd'hui", "Hier"
      });
    }
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

    // Show/hide scroll to bottom button (using ValueNotifier to avoid setState)
    final shouldShowButton = (maxScroll - currentScroll) > 300;
    if (shouldShowButton != _showScrollToBottomButton.value) {
      _showScrollToBottomButton.value = shouldShowButton;
      if (shouldShowButton) {
        _scrollButtonController.forward();
      } else {
        _scrollButtonController.reverse();
      }
    }
  }

  /// Scroll to a specific message by ID
  void _scrollToMessage(String messageId) {
    final paginationState = ref.read(
      paginatedMessagesProvider(widget.conversationId),
    );
    final messages = paginationState.messages;
    final index = messages.indexWhere((m) => m.id == messageId);

    if (index != -1 && _scrollController.hasClients) {
      // Estimate position - each message is roughly 80 pixels
      // This is approximate, for exact positioning we'd need GlobalKey per message
      final estimatedPosition = index * 80.0;
      _scrollController.animateTo(
        estimatedPosition.clamp(0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );

      // Highlight the message temporarily
      setState(() {
        _highlightedMessageId = messageId;
      });

      // Remove highlight after animation
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          setState(() {
            _highlightedMessageId = null;
          });
        }
      });
    }
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

  MessageEntity? _getReplyEntity(MessageEntity message) {
    // Check for null or empty replyToMessageData
    if (message.replyToMessageData == null ||
        message.replyToMessageData!.isEmpty) {
      return null;
    }
    final data = message.replyToMessageData!;

    // Validate required fields exist
    if (data['id'] == null || data['senderId'] == null) {
      // debugPrint(
      //   '⚠️ Invalid reply data: missing id or senderId. Data: $data',
      // );
      return null;
    }

    try {
      return MessageEntity(
        id: data['id'] as String? ?? '',
        senderId: data['senderId'] as String? ?? '',
        senderName: data['senderName'] as String? ?? 'Utilisateur',
        content: data['content'] as String? ?? '',
        type: MessageType.values.firstWhere(
          (e) => e.name == data['type'],
          orElse: () => MessageType.text,
        ),
        createdAt: DateTime.now(),
        readBy: const [],
        readAt: const {},
        fileUrl: data['fileUrl'] as String?,
        fileName: data['fileName'] as String?,
      );
    } catch (e) {
      // debugPrint('❌ Error parsing reply entity: $e');
      // debugPrint('   Data: $data');
      return null;
    }
  }

  void _handleReply(MessageEntity message) {
    setState(() {
      _replyToMessage = message;
    });
  }

  void _cancelReply() {
    setState(() {
      _replyToMessage = null;
    });
  }

  Future<void> _loadChatBackground() async {
    try {
      final prefs = PreferencesService.instance;

      // Try to load conversation-specific background first
      final customBgJson = prefs.getConversationBackground(
        widget.conversationId,
      );

      if (customBgJson != null && customBgJson.isNotEmpty) {
        final model = ChatBackgroundModel.fromJson(jsonDecode(customBgJson));
        setState(() {
          _chatBackground = model.toEntity();
        });
        return;
      }

      // Fall back to default background
      final defaultBgJson = prefs.defaultChatBackground;
      if (defaultBgJson != null && defaultBgJson.isNotEmpty) {
        final model = ChatBackgroundModel.fromJson(jsonDecode(defaultBgJson));
        setState(() {
          _chatBackground = model.toEntity();
        });
      }
    } catch (e) {
      // debugPrint('Error loading chat background: $e');
    }
  }

  Future<void> _showBackgroundPicker() async {
    final result = await ChatBackgroundPickerModal.show(
      context,
      conversationId: widget.conversationId,
      currentBackground: _chatBackground,
    );

    if (result != null) {
      setState(() {
        _chatBackground = result;
      });
    }
  }

  Future<void> _handleReact(MessageEntity message, String emoji) async {
    // debugPrint('🎭 _handleReact called');
    try {
      await ref
          .read(paginatedMessagesProvider(widget.conversationId).notifier)
          .toggleReaction(message.id, emoji);
      // debugPrint('   ✅ Reaction toggled (optimistic)');
    } catch (e) {
      // debugPrint('  ❌ Error toggling reaction: $e');
    }
  }

  void _showConversationOptions() {
    final conversation =
        ref.read(conversationStreamProvider(widget.conversationId)).valueOrNull;
    final currentUser = ref.read(currentUserProvider).valueOrNull;

    final isAdmin =
        conversation != null &&
        currentUser != null &&
        (conversation.createdBy == currentUser.id ||
            conversation.adminIds.contains(currentUser.id));

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (context) => ConversationOptionsModal(
            conversationId: widget.conversationId,
            otherUserId: widget.otherUserId,
            otherUserName: widget.conversationName,
            otherUserPhotoUrl: widget.conversationImageUrl,
            isGroup: widget.isGroup,
            isAdmin: isAdmin,
            onChangeBackground: _showBackgroundPicker,
          ),
    );
  }

  // Get date separator label
  String _getDateLabel(DateTime date, AppLocalizations l10n) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return "Aujourd'hui";
    } else if (messageDate == yesterday) {
      return 'Hier';
    } else if (now.difference(date).inDays < 7) {
      // Show day name for last week
      return DateFormat.EEEE('fr').format(date);
    } else {
      return DateFormat.yMMMd('fr').format(date);
    }
  }

  // Check if we need a date separator
  bool _needsDateSeparator(List<MessageEntity> messages, int index) {
    // debugPrint(
    //   '📅 _needsDateSeparator called: index=$index, total=${messages.length}',
    // );

    if (index == 0) {
      // debugPrint('   ✅ First message, showing separator');
      return true;
    }

    final currentMessage = messages[index];
    final previousMessage = messages[index - 1];

    final currentDate = DateTime(
      currentMessage.createdAt.year,
      currentMessage.createdAt.month,
      currentMessage.createdAt.day,
    );
    final previousDate = DateTime(
      previousMessage.createdAt.year,
      previousMessage.createdAt.month,
      previousMessage.createdAt.day,
    );

    final needsSeparator = currentDate != previousDate;
    // debugPrint('   Current: $currentDate, Previous: $previousDate');
    // debugPrint(
    //   '   ${needsSeparator ? "✅ Different dates" : "❌ Same date"} -> needsSeparator=$needsSeparator',
    // );

    return needsSeparator;
  }

  // Get message group position
  MessageGroupPosition _getMessageGroupPosition(
    List<MessageEntity> messages,
    int index,
    String? currentUserId,
  ) {
    final message = messages[index];

    final hasPreviousSameSender =
        index > 0 && messages[index - 1].senderId == message.senderId;
    final hasNextSameSender =
        index < messages.length - 1 &&
        messages[index + 1].senderId == message.senderId;

    // Check for date separator break
    final hasDateBreak = _needsDateSeparator(messages, index);
    final hasNextDateBreak =
        index < messages.length - 1 && _needsDateSeparator(messages, index + 1);

    if (hasDateBreak) {
      // After date separator, treat as first message
      if (hasNextSameSender && !hasNextDateBreak) {
        return MessageGroupPosition.first;
      }
      return MessageGroupPosition.single;
    }

    if (!hasPreviousSameSender && !hasNextSameSender) {
      return MessageGroupPosition.single;
    } else if (!hasPreviousSameSender &&
        hasNextSameSender &&
        !hasNextDateBreak) {
      return MessageGroupPosition.first;
    } else if (hasPreviousSameSender &&
        hasNextSameSender &&
        !hasNextDateBreak) {
      return MessageGroupPosition.middle;
    } else {
      return MessageGroupPosition.last;
    }
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

    // Check if conversation exists
    final isDeleted = !conversationAsync.isLoading && conversation == null;

    // Check if other user is blocked (I blocked them)
    bool isBlocked = false;
    if (!widget.isGroup && conversation != null) {
      final otherUserId = conversation.getOtherParticipantId(
        currentUser?.id ?? '',
      );
      isBlocked = blockedUsers.any((user) => user.id == otherUserId);
    }

    // Check if I am blocked by the other user
    bool isBlockedByOther = false;
    if (!widget.isGroup && currentUser != null && widget.otherUserId != null) {
      final currentUserProfileAsync = ref.watch(
        userStreamProvider(currentUser.id),
      );
      final currentUserProfile = currentUserProfileAsync.valueOrNull;
      if (currentUserProfile != null) {
        isBlockedByOther = currentUserProfile.blockedByUserIds.contains(
          widget.otherUserId,
        );
      }
    }

    // Stream other user's profile if it's an individual chat
    AsyncValue<dynamic>? otherUserAsync;
    if (!widget.isGroup && widget.otherUserId != null) {
      otherUserAsync = ref.watch(userStreamProvider(widget.otherUserId!));
    }

    final otherUser = otherUserAsync?.valueOrNull;

    // Determine display name for typing indicator
    final displayName =
        widget.isGroup
            ? widget.conversationName
            : otherUser?.displayName ?? widget.conversationName;

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
      backgroundColor:
          _chatBackground?.isDefault ?? true ? context.backgroundColor : null,
      extendBodyBehindAppBar:
          _chatBackground != null && !_chatBackground!.isDefault,
      appBar: _buildAppBar(otherUser),
      body: Container(
        decoration:
            _chatBackground != null && !_chatBackground!.isDefault
                ? BoxDecoration(
                  color:
                      _chatBackground!.isColor ? _chatBackground!.color : null,
                  image:
                      _chatBackground!.isImage &&
                              _chatBackground!.imageUrl != null
                          ? DecorationImage(
                            image: NetworkImage(_chatBackground!.imageUrl!),
                            fit: BoxFit.cover,
                          )
                          : _chatBackground!.isImage &&
                              _chatBackground!.localImagePath != null
                          ? DecorationImage(
                            image: FileImage(
                              File(_chatBackground!.localImagePath!),
                            ),
                            fit: BoxFit.cover,
                          )
                          : null,
                )
                : null,
        child: Stack(
          children: [
            // Semi-transparent overlay for readability
            if (_chatBackground != null && !_chatBackground!.isDefault)
              Container(
                color:
                    context.isDarkMode
                        ? Colors.black.withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.3),
              ),
            Column(
              children: [
                // Offline indicator
                if (paginationState.isOffline)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 16,
                    ),
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
                  child: _buildMessageList(
                    paginationState,
                    currentUser?.id,
                    l10n,
                    blockedUsers.map((u) => u.id).toSet(),
                  ),
                ),

                // Typing indicator
                if (!isDeleted && !isBlocked)
                  TypingIndicatorWidget(
                    conversationId: widget.conversationId,
                    currentUserId: currentUser?.id,
                    userNames:
                        widget.otherUserId != null
                            ? {
                              widget.otherUserId!:
                                  displayName ??
                                  widget.conversationName ??
                                  'Utilisateur',
                            }
                            : null,
                  ),

                // Input or Blocked/Deleted Message
                if (isDeleted ||
                    (otherUser != null &&
                        otherUser.displayName == 'Utilisateur supprimé'))
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: context.surfaceColor,
                    width: double.infinity,
                    child: Text(
                      isDeleted
                          ? "Ce groupe a été supprimé"
                          : "Cet utilisateur a été supprimé",
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
                    replyToMessage: _replyToMessage,
                    onCancelReply: _cancelReply,
                    onTyping: () {
                      ref
                          .read(typingIndicatorNotifierProvider.notifier)
                          .onUserTyping(widget.conversationId);
                    },
                    onSendText: (text) async {
                      // Stop typing indicator when sending
                      ref
                          .read(typingIndicatorNotifierProvider.notifier)
                          .stopTyping();

                      // Clear reply
                      final replyTo = _replyToMessage;
                      _cancelReply();

                      // Generate unique message ID for tracking
                      final messageId =
                          'temp_${DateTime.now().millisecondsSinceEpoch}';

                      // Send with retry logic
                      // If blocked by other user, include their ID in sentWhileBlockedBy
                      final blockedByList = isBlockedByOther && widget.otherUserId != null
                          ? [widget.otherUserId!]
                          : <String>[];

                      final success = await ref
                          .read(sendMessageProvider.notifier)
                          .sendText(
                            conversationId: widget.conversationId,
                            content: text,
                            optimisticMessageId: messageId,
                            replyToMessage: replyTo,
                            sentWhileBlockedBy: blockedByList,
                          );

                      if (!mounted) return;

                      if (!success) {
                        ref
                            .read(
                              paginatedMessagesProvider(
                                widget.conversationId,
                              ).notifier,
                            )
                            .updateMessageStatus(
                              messageId,
                              MessageStatus.failed,
                            );
                      }

                      if (success) {
                        AnalyticsService.instance.logEvent(
                          name: 'send_message',
                          parameters: {
                            'type': 'text',
                            'conversation_id': widget.conversationId,
                            'is_group': widget.isGroup ? 'true' : 'false',
                            'is_reply': replyTo != null ? 'true' : 'false',
                          },
                        );
                        _scrollToBottom();
                        if (_replyToMessage != null) _cancelReply();
                      }
                    },
                    onSendFile: (
                      File file,
                      bool isImage, {
                      String? caption,
                    }) async {
                      // If blocked, don't send file (file messages don't support sentWhileBlockedBy yet)
                      if (isBlockedByOther) {
                        _scrollToBottom();
                        if (_replyToMessage != null) _cancelReply();
                        return;
                      }

                      final success = await ref
                          .read(sendMessageProvider.notifier)
                          .sendFile(
                            conversationId: widget.conversationId,
                            file: file,
                            type:
                                isImage ? MessageType.image : MessageType.file,
                            caption: caption,
                            replyToMessage: _replyToMessage,
                          );

                      if (!mounted) return;

                      if (success) {
                        AnalyticsService.instance.logEvent(
                          name: 'send_message',
                          parameters: {
                            'type': isImage ? 'image' : 'file',
                            'conversation_id': widget.conversationId,
                            'is_group': widget.isGroup ? 'true' : 'false',
                          },
                        );
                        _scrollToBottom();
                        if (_replyToMessage != null) _cancelReply();
                      }
                    },
                    onSendAudio: (
                      File audioFile,
                      int duration,
                      List<double> waveform,
                    ) async {
                      // If blocked, don't send audio (audio messages don't support sentWhileBlockedBy yet)
                      if (isBlockedByOther) {
                        _scrollToBottom();
                        if (_replyToMessage != null) _cancelReply();
                        return;
                      }

                      final success = await ref
                          .read(sendMessageProvider.notifier)
                          .sendAudio(
                            conversationId: widget.conversationId,
                            audioFile: audioFile,
                            duration: duration,
                            waveform: waveform,
                            replyToMessage: _replyToMessage,
                          );

                      if (!mounted) return;

                      if (success) {
                        AnalyticsService.instance.logEvent(
                          name: 'send_message',
                          parameters: {
                            'type': 'audio',
                            'conversation_id': widget.conversationId,
                            'is_group': widget.isGroup ? 'true' : 'false',
                            'duration': duration,
                          },
                        );
                        _scrollToBottom();
                        if (_replyToMessage != null) _cancelReply();
                      }
                    },
                  ),
              ],
            ),

            // Scroll to bottom FAB
            ValueListenableBuilder<bool>(
              valueListenable: _showScrollToBottomButton,
              builder: (context, showButton, child) {
                if (!showButton) return const SizedBox.shrink();
                return Positioned(
                  bottom: 100,
                  right: 16,
                  child: ScaleTransition(
                    scale: _scrollButtonAnimation,
                    child: FloatingActionButton.small(
                      onPressed: _scrollToBottom,
                      backgroundColor: context.surfaceColor,
                      elevation: 4,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: context.textPrimaryColor,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList(
    dynamic paginationState,
    String? currentUserId,
    AppLocalizations l10n,
    Set<String> blockedUserIds,
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

    final allMessages = paginationState.messages as List<MessageEntity>;
    // Filter out deleted messages, messages from blocked users, and messages sent while blocked
    final messages =
        currentUserId != null
            ? allMessages
                .where(
                  (m) =>
                      !m.isDeletedFor(currentUserId) &&
                      !blockedUserIds.contains(m.senderId) &&
                      !m.sentWhileBlockedBy.contains(currentUserId),
                )
                .toList()
            : allMessages
                .where((m) => !blockedUserIds.contains(m.senderId))
                .toList();

    if (messages.isEmpty) {
      return _buildEmptyState();
    }

    final uploadState = ref.watch(mediaUploadProvider);
    final isUploadingHere =
        uploadState.isUploading &&
        uploadState.conversationId == widget.conversationId;
    final totalCount =
        messages.length +
        (paginationState.isLoadingMore ? 1 : 0) +
        (isUploadingHere ? 1 : 0);

    // Calculate top padding - add extra when body extends behind app bar
    final topPadding =
        (_chatBackground != null && !_chatBackground!.isDefault)
            ? MediaQuery.of(context).padding.top + kToolbarHeight + 16
            : 16.0;

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.only(top: topPadding, bottom: 16),
      itemCount: totalCount,
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

        // Show uploading skeleton at the bottom
        if (isUploadingHere && index == totalCount - 1) {
          return const UploadingMediaSkeleton();
        }

        // Calculate message index
        final messageIndex = paginationState.isLoadingMore ? index - 1 : index;

        // Safety check
        if (messageIndex < 0 || messageIndex >= messages.length) {
          return const SizedBox.shrink();
        }

        final message = messages[messageIndex];
        final isMe = message.senderId == currentUserId;

        // Get group position for linked bubbles
        final groupPosition = _getMessageGroupPosition(
          messages,
          messageIndex,
          currentUserId,
        );

        // Only show sender info for the first message in a group (first or single)
        // This avoids redundant display of sender name for consecutive messages
        final showSenderInfo =
            widget.isGroup &&
            !isMe &&
            (groupPosition == MessageGroupPosition.first ||
                groupPosition == MessageGroupPosition.single);

        // Check if we need a date separator
        final needsSeparator = _needsDateSeparator(messages, messageIndex);
        // debugPrint('🔹 Message $messageIndex: needsSeparator=$needsSeparator');

        final conversation =
            ref
                .watch(conversationStreamProvider(widget.conversationId))
                .valueOrNull;
        final isAdmin =
            conversation != null &&
            currentUserId != null &&
            (conversation.createdBy == currentUserId ||
                conversation.adminIds.contains(currentUserId));

        return Column(
          children: [
            // Date separator
            if (needsSeparator) _buildDateSeparator(message.createdAt, l10n),

            // Message bubble with highlight animation
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                color:
                    _highlightedMessageId == message.id
                        ? context.adaptivePrimaryColor.withValues(alpha: 0.15)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Align(
                alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                child: MessageBubble(
                  message: message,
                  isMe: isMe,
                  showSenderInfo: showSenderInfo,
                  groupPosition: groupPosition,
                  conversationId: widget.conversationId,
                  currentUserId: currentUserId,
                  isAdmin: isAdmin,
                  onReply: _handleReply,
                  onReact: _handleReact,
                  onRetry:
                      message.status == MessageStatus.failed
                          ? () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final success = await ref
                                .read(sendMessageProvider.notifier)
                                .retryFailedMessage(
                                  conversationId: widget.conversationId,
                                  failedMessage: message,
                                );
                            if (!success && mounted) {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Échec du renvoi du message'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                          : null,
                  onSenderTap: (userId) {
                    if (widget.isGroup) {
                      context.push('/profile/$userId');
                    }
                  },
                  replyToMessage: _getReplyEntity(message),
                  onScrollToMessage: _scrollToMessage,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDateSeparator(DateTime date, AppLocalizations l10n) {
    // final label = _getDateLabel(date, l10n);
    // debugPrint(
    //   '🔷 _buildDateSeparator: Building separator with label="$label" for date=$date',
    // );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: context.outlineColor.withValues(alpha: 0.1),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: context.surfaceVariantColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _getDateLabel(date, l10n),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: context.textSecondaryColor,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: context.outlineColor.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }

  void _showCallComingSoon({required bool isVideo}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isVideo ? Icons.videocam : Icons.call,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              isVideo
                  ? 'Appel vidéo - Bientôt disponible'
                  : 'Appel vocal - Bientôt disponible',
            ),
          ],
        ),
        backgroundColor: context.adaptivePrimaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Obtenir les initiales du nom
  String _getInitials(String? name) {
    if (name == null || name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  PreferredSizeWidget _buildAppBar(dynamic otherUser) {
    final displayName =
        widget.isGroup
            ? widget.conversationName
            : otherUser?.displayName ?? widget.conversationName;

    final displayImage =
        widget.isGroup
            ? widget.conversationImageUrl
            : otherUser?.photoUrl ?? widget.conversationImageUrl;

    final initials = _getInitials(displayName);

    // Check if user is deleted
    final isDeletedUser =
        otherUser != null && otherUser.displayName == 'Utilisateur supprimé';

    return AppBar(
      backgroundColor: context.surfaceColor,
      elevation: 0,
      titleSpacing: 0,
      leadingWidth: 40,
      leading: IconButton(
        padding: EdgeInsets.zero,
        onPressed: () => Navigator.of(context).pop(),
        icon: Icon(Icons.arrow_back, color: context.textPrimaryColor),
      ),
      title: InkWell(
        onTap: () async {
          // debugPrint('🔘 Tapped conversation header:');
          // debugPrint('   isGroup: ${widget.isGroup}');
          // debugPrint('   groupId: ${widget.groupId}');
          // debugPrint('   otherUserId: ${widget.otherUserId}');

          if (widget.isGroup) {
            String? groupIdToUse = widget.groupId;

            if (groupIdToUse == null && widget.conversationName != null) {
              // debugPrint(
              //   '   🔍 groupId is null, searching by name: ${widget.conversationName}',
              // );
              final group = await ref.read(
                groupByNameProvider(widget.conversationName!).future,
              );
              groupIdToUse = group?.id;
              // debugPrint('   📍 Found groupId: $groupIdToUse');
            }

            if (mounted) {
              // debugPrint('   ➡️ Navigating to /groups/$groupIdToUse');
              context.push('/groups/$groupIdToUse');
            } else {
              // debugPrint(
              //   '   ⚠️ Cannot navigate: groupId is null and group not found!',
              // );
            }
          } else if (widget.otherUserId != null) {
            if (isDeletedUser) {
              return;
            }
            // debugPrint('   ➡️ Navigating to /profile/${widget.otherUserId}');
            context.push('/profile/${widget.otherUserId}');
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              // Avatar
              Stack(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient:
                          widget.isGroup
                              ? context.adaptiveSecondaryGradient
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
                                placeholder:
                                    (_, __) => Center(
                                      child:
                                          widget.isGroup
                                              ? const Icon(
                                                Icons.groups,
                                                color: AppColors.white,
                                                size: 20,
                                              )
                                              : Text(
                                                initials,
                                                style: const TextStyle(
                                                  color: AppColors.white,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                    ),
                                errorWidget:
                                    (_, __, ___) => Center(
                                      child:
                                          widget.isGroup
                                              ? const Icon(
                                                Icons.groups,
                                                color: AppColors.white,
                                                size: 20,
                                              )
                                              : Text(
                                                initials,
                                                style: const TextStyle(
                                                  color: AppColors.white,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                    ),
                              ),
                            )
                            : Center(
                              child:
                                  widget.isGroup
                                      ? const Icon(
                                        Icons.groups,
                                        color: AppColors.white,
                                        size: 20,
                                      )
                                      : Text(
                                        initials,
                                        style: const TextStyle(
                                          color: AppColors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                            ),
                  ),
                  // Online indicator dot on avatar (only for individual chats)
                  if (!widget.isGroup &&
                      widget.otherUserId != null &&
                      !isDeletedUser)
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: context.surfaceColor,
                          shape: BoxShape.circle,
                        ),
                        child: OnlineStatusIndicator(
                          userId: widget.otherUserId!,
                          showText: false,
                          dotSize: 10,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Name
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
                    // Status text below name
                    if (widget.isGroup)
                      Text(
                        AppLocalizations.of(context)!.group,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textTertiaryColor,
                        ),
                      )
                    else if (!widget.isGroup &&
                        widget.otherUserId != null &&
                        !isDeletedUser)
                      // Online status text for individual chats
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: OnlineStatusIndicator(
                          key: ValueKey(widget.otherUserId),
                          userId: widget.otherUserId!,
                          showText: true,
                          showDot: false,
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
        // Call buttons for individual chats only
        if (!widget.isGroup && !isDeletedUser) ...[
          IconButton(
            onPressed: () => _showCallComingSoon(isVideo: false),
            icon: Icon(Icons.call_outlined, color: context.textPrimaryColor),
            tooltip: 'Appel vocal',
          ),
          IconButton(
            onPressed: () => _showCallComingSoon(isVideo: true),
            icon: Icon(
              Icons.videocam_outlined,
              color: context.textPrimaryColor,
            ),
            tooltip: 'Appel vidéo',
          ),
        ],
        // More options button
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
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated chat illustration
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    context.adaptivePrimaryColor.withValues(alpha: 0.15),
                    context.adaptiveSecondaryColor.withValues(alpha: 0.1),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 48,
                    color: context.adaptivePrimaryColor,
                  ),
                  // Small decorative elements
                  Positioned(
                    top: 20,
                    right: 20,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: context.adaptiveSecondaryColor.withValues(
                          alpha: 0.5,
                        ),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 25,
                    left: 18,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: context.adaptivePrimaryColor.withValues(
                          alpha: 0.5,
                        ),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text(
              l10n.noMessages,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: context.textPrimaryColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.isGroup
                  ? "Soyez le premier à envoyer un message dans ce groupe !"
                  : l10n.sendFirstMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: context.textSecondaryColor,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            // Subtle hint with arrow
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.arrow_downward_rounded,
                  size: 16,
                  color: context.textTertiaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  "Tapez votre message ci-dessous",
                  style: TextStyle(
                    fontSize: 13,
                    color: context.textTertiaryColor,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
