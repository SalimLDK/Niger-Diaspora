import 'dart:io';

import 'package:flutter/material.dart';
import '../../../../core/theme/design_kit.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/locale_helper.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/conversation_entity.dart';
import '../../domain/entities/message_entity.dart';
import '../providers/message_provider.dart';
import '../providers/typing_indicator_provider.dart';
import '../providers/media_upload_provider.dart';
import '../widgets/conversation_options_modal.dart';
import '../widgets/forward_conversation_picker.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_input.dart';
import '../widgets/note_poll_draft_sheet.dart';
import '../widgets/typing_indicator_widget.dart';
import '../widgets/uploading_media_skeleton.dart';
import '../../../settings/presentation/providers/blocked_users_provider.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../groups/domain/entities/group_pinned_item_entity.dart';
import '../../../groups/presentation/providers/group_provider.dart';
import '../../../groups/presentation/providers/group_pinned_providers.dart';
import '../../../groups/presentation/widgets/group_pinned_banner.dart';
import '../../../../core/extensions/profile_entity_extensions.dart';
import '../../../polls/domain/entities/poll_entity.dart';
import '../../../polls/presentation/widgets/create_poll_sheet.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../profile/presentation/widgets/online_status_indicator.dart';
import '../../../../core/services/preferences_service.dart';
import '../../../settings/data/models/chat_background_model.dart';
import '../../../settings/domain/entities/chat_background_entity.dart';
import '../widgets/chat_background_picker_modal.dart';
import '../widgets/chat_wallpapers.dart';
import 'dart:convert';
import '../../../../core/errors/failure_mapper.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/providers/in_app_notification_provider.dart';
import '../../domain/services/message_deletion_service.dart';
import '../../../calls/domain/entities/call_entity.dart';
import '../../../calls/presentation/providers/call_provider.dart';
import '../../../group_calls/domain/entities/group_call_entity.dart';
import '../../../group_calls/presentation/providers/group_call_provider.dart';
import '../../../calls/presentation/screens/call_screen.dart';
import '../../../gifs/domain/entities/gif_entity.dart';
import '../../../stickers/domain/entities/sticker_entity.dart';
import '../../../feed/domain/entities/post_entity.dart' show MentionedUser;
import 'package:diaspo_niger/shared/widgets/app_icon.dart';

class ConversationScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final String? conversationName;
  final String? conversationImageUrl;
  final String? otherUserId;
  final bool isGroup;
  final String? groupId;

  /// « Mes notes » : conversation avec soi-même (brouillon/scratchpad).
  final bool isSelfNotes;

  const ConversationScreen({
    super.key,
    required this.conversationId,
    this.conversationName,
    this.conversationImageUrl,
    this.otherUserId,
    this.isGroup = false,
    this.groupId,
    this.isSelfNotes = false,
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

  // Unread messages separator
  int? _firstUnreadMessageIndex;
  int _unreadCountOnOpen = 0;
  bool _hasCalculatedUnread = false;
  bool _hasScrolledToInitialPosition = false;

  // Multi-selection mode
  bool _isSelectionMode = false;
  final Set<String> _selectedMessageIds = {};

  // Search mode
  bool _isSearchMode = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Track app lifecycle state to prevent marking as read when in background
  bool _isAppInForeground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _scrollController.addListener(_onScroll);

    _scrollButtonController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scrollButtonAnimation = CurvedAnimation(
      parent: _scrollButtonController,
      curve: Curves.easeOut,
    );

    // Mark as read and load background after frame is built
    // Note: _calculateUnreadOnOpen() is called via ref.listen in build() when messages are loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(markAsDeliveredProvider.notifier).mark(widget.conversationId);
      ref.read(markAsReadProvider.notifier).mark(widget.conversationId);
      _loadChatBackground();
      _setupPrivateGroupFilter();

      // Clear unread mention badge when opening a group conversation
      if (widget.isGroup) {
        final userId = ref.read(currentUserProvider).valueOrNull?.id;
        if (userId != null) {
          ref
              .read(messageRepositoryProvider)
              .clearUnreadMentions(
                conversationId: widget.conversationId,
                userId: userId,
              );
        }
      }

      // Signal this conversation is open to prevent in-app notifications
      NotificationService().setCurrentConversation(widget.conversationId);
      ref
          .read(inAppNotificationProvider.notifier)
          .setCurrentConversation(widget.conversationId);
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

  /// Calculate unread messages count and first unread index on conversation open
  void _calculateUnreadOnOpen() {
    if (_hasCalculatedUnread) return;

    final currentUser = ref.read(currentUserProvider).valueOrNull;
    if (currentUser == null) return;

    final paginationState = ref.read(
      paginatedMessagesProvider(widget.conversationId),
    );
    final messages = paginationState.messages;

    if (messages.isEmpty) return;

    int unreadCount = 0;
    int? firstUnreadIndex;

    for (int i = 0; i < messages.length; i++) {
      final message = messages[i];
      // Skip own messages
      if (message.senderId == currentUser.id) continue;
      // Check if message is unread
      if (!message.readBy.contains(currentUser.id)) {
        unreadCount++;
        // Track the first unread message index
        firstUnreadIndex ??= i;
      }
    }

    if (unreadCount > 0 && firstUnreadIndex != null) {
      setState(() {
        _unreadCountOnOpen = unreadCount;
        _firstUnreadMessageIndex = firstUnreadIndex;
        _hasCalculatedUnread = true;
      });
      _scrollToUnreadOrBottom(firstUnreadIndex, messages.length);
    } else {
      _hasCalculatedUnread = true;
      _scrollToUnreadOrBottom(null, messages.length);
    }
  }

  /// Scroll vers le premier message non lu (si nécessaire)
  /// Avec reverse: true, la liste démarre déjà au bas (position 0 = messages récents)
  void _scrollToUnreadOrBottom(int? unreadIndex, int totalMessages) {
    if (_hasScrolledToInitialPosition) return;
    _hasScrolledToInitialPosition = true;

    // Avec reverse: true, la liste démarre au bas (position 0)
    // Donc pas besoin de scroll si pas de messages non lus
    if (unreadIndex == null) return;

    // Attendre que le ListView soit complètement rendu
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;

      final maxExtent = _scrollController.position.maxScrollExtent;
      if (maxExtent <= 0) return;

      // Avec reverse: true, l'index dans la liste inversée est:
      // reversedIndex = totalMessages - 1 - unreadIndex
      // Position = (reversedIndex / totalMessages) * maxExtent
      final reversedIndex = totalMessages - 1 - unreadIndex;
      final ratio = reversedIndex / totalMessages;
      final targetPosition = (maxExtent * ratio).clamp(0.0, maxExtent);

      _scrollController.jumpTo(targetPosition);
    });
  }

  @override
  void dispose() {
    // Clear current conversation to re-enable in-app notifications
    NotificationService().setCurrentConversation(null);
    // Note: We don't clear the provider here because dispose() may be called
    // after the widget is unmounted, and ref may no longer be valid.
    // The provider will be cleared when navigating to a new conversation.

    WidgetsBinding.instance.removeObserver(this);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _scrollButtonController.dispose();
    _showScrollToBottomButton.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Track foreground state to prevent marking messages as read when in background
    if (state == AppLifecycleState.resumed) {
      _isAppInForeground = true;
      ref.read(markAsDeliveredProvider.notifier).mark(widget.conversationId);
      ref.read(markAsReadProvider.notifier).mark(widget.conversationId);
      setState(() {
        // Force rebuild to update date labels like "Aujourd'hui", "Hier"
      });
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _isAppInForeground = false;
    }
  }

  void _onScroll() {
    // With reverse: true, maxScrollExtent is at the TOP (oldest messages)
    // and pixels = 0 is at the BOTTOM (newest messages)
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    // Check if we're near the top (oldest messages) to load more
    if ((maxScroll - currentScroll) <= 100) {
      final paginationState = ref.read(
        paginatedMessagesProvider(widget.conversationId),
      );
      if (paginationState.canLoadMore) {
        ref
            .read(paginatedMessagesProvider(widget.conversationId).notifier)
            .loadMore();
      }
    }

    // Track if we're near bottom (newest messages = near pixels 0)
    _isNearBottom = currentScroll <= 100;

    // Show/hide scroll to bottom button (show when scrolled up from bottom)
    final shouldShowButton = currentScroll > 300;
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
      // With reverse: true, convert to reversed index
      final reversedIndex = messages.length - 1 - index;
      // Estimate position - each message is roughly 80 pixels
      final estimatedPosition = reversedIndex * 80.0;
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
    // With reverse: true, position 0 is at the bottom (newest messages)
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
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
        senderName:
            data['senderName'] as String? ?? AppLocalizations.of(context)!.user,
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

  // --- Multi-selection & Forward ---

  void _handleForward(MessageEntity message) {
    ForwardConversationPicker.show(context, messages: [message]);
  }

  Future<void> _pinMessage(MessageEntity message) async {
    final currentUserId = ref.read(currentUserProvider).valueOrNull?.id;
    if (currentUserId == null) return;

    // widget.groupId peut être absent (notification/deep link sans extra
    // complet) : widget.conversationId N'EST PAS un groupId valide, l'utiliser
    // en repli garantissait l'échec de l'insertion (violation de clé
    // étrangère group_pinned_items.group_id → groups.id). On retombe plutôt
    // sur le group_id connu de la conversation elle-même.
    final effectiveGroupId =
        widget.groupId ??
        ref
            .read(conversationStreamProvider(widget.conversationId))
            .valueOrNull
            ?.groupId;

    if (widget.isGroup && effectiveGroupId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d\'épingler ce message')),
        );
      }
      return;
    }

    final success = await ref
        .read(groupPinActionsNotifierProvider.notifier)
        .pinItem(
          groupId: widget.isGroup ? effectiveGroupId : null,
          conversationId: widget.isGroup ? null : widget.conversationId,
          itemType: GroupPinnedItemType.message,
          itemId: message.id,
          pinnedBy: currentUserId,
        );

    // Rafraîchit le bandeau immédiatement : le stream Supabase ne reçoit pas
    // toujours l'insert en temps réel (réplication realtime pas garantie sur
    // `group_pinned_items`), donc sans ça le bandeau ne s'affichait qu'au
    // prochain ouverture de la conversation.
    if (success) _refreshPinnedBanner(effectiveGroupId);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Message épinglé' : 'Impossible d\'épingler ce message',
          ),
        ),
      );
    }
  }

  /// Force le re-fetch de la liste des épingles (auto-dispose StreamProvider),
  /// pour un affichage immédiat après épinglage/désépinglage local.
  void _refreshPinnedBanner(String? effectiveGroupId) {
    if (widget.isGroup && effectiveGroupId != null) {
      ref.invalidate(groupPinnedItemsProvider(effectiveGroupId));
    } else {
      ref.invalidate(conversationPinnedItemsProvider(widget.conversationId));
    }
  }

  /// Détache un message épinglé depuis son menu contextuel : le bandeau ne
  /// porte plus de croix, c'est le seul chemin de désépinglage (comme Telegram).
  Future<void> _unpinMessage(MessageEntity message) async {
    final effectiveGroupId =
        widget.groupId ??
        ref
            .read(conversationStreamProvider(widget.conversationId))
            .valueOrNull
            ?.groupId;
    final items =
        (widget.isGroup && effectiveGroupId != null
                ? ref.read(groupPinnedItemsProvider(effectiveGroupId))
                : ref.read(
                  conversationPinnedItemsProvider(widget.conversationId),
                ))
            .valueOrNull;
    final pin =
        items
            ?.where(
              (i) =>
                  i.itemType == GroupPinnedItemType.message &&
                  i.itemId == message.id,
            )
            .firstOrNull;
    if (pin == null) {
      // La liste d'épingles locale (ref.read, snapshot synchrone) ne
      // contenait pas ce message : sans ce retour explicite, l'utilisateur
      // tapait « Détacher » et rien ne se passait, sans le moindre signal.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de détacher ce message')),
        );
      }
      return;
    }

    final success = await ref
        .read(groupPinActionsNotifierProvider.notifier)
        .unpinItem(pin.id);

    // Idem épinglage : rafraîchit le bandeau immédiatement (le retrait n'est
    // pas garanti en temps réel via le stream Supabase).
    if (success) _refreshPinnedBanner(effectiveGroupId);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Message détaché' : 'Impossible de détacher ce message',
          ),
        ),
      );
    }
  }

  void _handleSelect(MessageEntity message) {
    setState(() {
      if (!_isSelectionMode) {
        // Enter selection mode with this message
        _isSelectionMode = true;
        _selectedMessageIds.clear();
        _selectedMessageIds.add(message.id);
      } else if (_selectedMessageIds.contains(message.id)) {
        _selectedMessageIds.remove(message.id);
        if (_selectedMessageIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedMessageIds.add(message.id);
      }
    });
  }

  /// Handle call back from a call message bubble
  Future<void> _handleCallBack(MessageEntity message) async {
    // Only allow call back in 1:1 conversations
    if (widget.isGroup || widget.otherUserId == null) {
      return;
    }

    // Determine call type from the message
    final callType =
        message.callType == 'video' ? CallType.video : CallType.audio;

    // Initiate call
    final l10n = AppLocalizations.of(context)!;
    final call = await ref
        .read(currentCallProvider.notifier)
        .initiateCall(
          calleeId: widget.otherUserId!,
          calleeName: widget.conversationName ?? l10n.user,
          calleePhotoUrl: widget.conversationImageUrl,
          type: callType,
        );

    if (call != null && mounted) {
      // Navigate to call screen
      context.push('/calls/${call.id}');
    } else if (mounted) {
      final callState = ref.read(currentCallProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(callState.error ?? l10n.callError),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  /// Démarre un appel de groupe (audio/vidéo) avec tous les membres.
  Future<void> _startGroupCall({required bool isVideo}) async {
    final l10n = AppLocalizations.of(context)!;
    final gid =
        widget.groupId ??
        ref
            .read(conversationStreamProvider(widget.conversationId))
            .valueOrNull
            ?.groupId;
    if (gid == null) return;
    final group = ref.read(groupStreamProvider(gid)).valueOrNull;
    if (group == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.loadingError)));
      return;
    }
    final call = await ref
        .read(currentGroupCallProvider.notifier)
        .createGroupCall(
          name: group.name,
          participantIds: group.memberIds,
          type: isVideo ? GroupCallType.video : GroupCallType.audio,
        );
    if (call != null && mounted) {
      context.push('/group-calls/${call.id}');
    } else if (mounted) {
      final st = ref.read(currentGroupCallProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(st.error ?? l10n.callError),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedMessageIds.clear();
    });
  }

  List<MessageEntity> _getSelectedMessages(List<MessageEntity> allMessages) {
    return allMessages.where((m) => _selectedMessageIds.contains(m.id)).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  Future<void> _forwardSelectedMessages(List<MessageEntity> allMessages) async {
    final selected = _getSelectedMessages(allMessages);
    if (selected.isEmpty) return;

    final result = await ForwardConversationPicker.show(
      context,
      messages: selected,
    );

    if (result == true && mounted) {
      _exitSelectionMode();
    }
  }

  Future<void> _deleteSelectedMessages(List<MessageEntity> allMessages) async {
    final selected = _getSelectedMessages(allMessages);
    if (selected.isEmpty) return;

    final currentUserId = ref.read(currentUserProvider).valueOrNull?.id;
    if (currentUserId == null) return;

    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: ctx.surfaceColor,
            title: Text(
              l10n.deleteSelectedMessages(selected.length),
              style: TextStyle(color: ctx.textPrimaryColor),
            ),
            content: Text(
              l10n.messagesDeletedForYou,
              style: TextStyle(color: ctx.textSecondaryColor),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  l10n.cancel,
                  style: TextStyle(color: ctx.textSecondaryColor),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  l10n.delete,
                  style: TextStyle(
                    color:
                        ctx.isDarkMode ? AppColors.errorDark : AppColors.error,
                  ),
                ),
              ),
            ],
          ),
    );

    if (confirmed == true && mounted) {
      // Utiliser la suppression batch pour de meilleures performances
      final service = ref.read(messageDeletionServiceProvider);
      final result = await service.deleteMultipleForMe(
        conversationId: widget.conversationId,
        messageIds: selected.map((m) => m.id).toList(),
        userId: currentUserId,
      );

      result.fold(
        (failure) {
          // Afficher un message d'erreur user-friendly
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  FailureMapper.toUserFriendlyString(failure.message, context),
                ),
                backgroundColor:
                    context.isDarkMode ? AppColors.errorDark : AppColors.error,
              ),
            );
          }
        },
        (deletedCount) {
          // Mettre à jour l'UI localement pour chaque message supprimé
          final notifier = ref.read(
            paginatedMessagesProvider(widget.conversationId).notifier,
          );
          for (final message in selected) {
            notifier.markMessageDeletedForMe(message.id, currentUserId);
          }
          // Afficher confirmation
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.messagesDeletedSuccess(deletedCount)),
                backgroundColor: AppColors.secondary,
              ),
            );
          }
        },
      );
      _exitSelectionMode();
    }
  }

  void _starSelectedMessages(List<MessageEntity> allMessages) {
    final selected = _getSelectedMessages(allMessages);
    if (selected.isEmpty) return;

    final notifier = ref.read(
      paginatedMessagesProvider(widget.conversationId).notifier,
    );
    for (final message in selected) {
      notifier.toggleStar(message.id);
    }
    _exitSelectionMode();
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

    bool isAdmin =
        conversation != null &&
        currentUser != null &&
        (conversation.createdBy == currentUser.id ||
            conversation.adminIds.contains(currentUser.id));

    // Get fallback data from providers if widget params are null
    String? displayName = widget.conversationName;
    String? displayImage = widget.conversationImageUrl;
    bool canPostEvents = false;
    bool canPostPolls = false;

    if (widget.isGroup && widget.groupId != null) {
      final groupData =
          ref.read(groupStreamProvider(widget.groupId!)).valueOrNull;
      displayName ??= groupData?.name;
      displayImage ??= groupData?.imageUrl;
      // Le rôle admin/modérateur (group_members.role, source de vérité côté
      // RLS) prime sur conversation.adminIds : ce dernier n'est qu'un
      // instantané figé au moment de la création de la conversation, jamais
      // mis à jour lors d'une promotion/rétrogradation dans le groupe.
      isAdmin =
          currentUser != null &&
          groupData != null &&
          (groupData.creatorId == currentUser.id ||
              groupData.adminIds.contains(currentUser.id));
      canPostEvents =
          groupData?.permissions.canPostEvents(isAdmin: isAdmin) ?? false;
      canPostPolls =
          groupData?.permissions.canPostPolls(isAdmin: isAdmin) ?? false;
    } else if (!widget.isGroup && widget.otherUserId != null) {
      final otherUser =
          ref.read(userStreamProvider(widget.otherUserId!)).valueOrNull;
      displayName ??= otherUser?.displayName;
      displayImage ??= otherUser?.photoUrl;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (context) => ConversationOptionsModal(
            conversationId: widget.conversationId,
            otherUserId: widget.otherUserId,
            otherUserName: displayName,
            otherUserPhotoUrl: displayImage,
            isGroup: widget.isGroup,
            isAdmin: isAdmin,
            groupId: widget.groupId,
            canPostEvents: canPostEvents,
            canPostPolls: canPostPolls,
            onChangeBackground: _showBackgroundPicker,
            onSearch: () {
              setState(() {
                _isSearchMode = true;
              });
            },
          ),
    );
  }

  // Get date separator label
  String _getDateLabel(DateTime date, AppLocalizations l10n) {
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return l10n.today('');
    } else if (messageDate == yesterday) {
      return l10n.yesterday('');
    } else if (now.difference(date).inDays < 7) {
      return DateFormat.EEEE(
        LocaleHelper.getDateFormatLocale(context),
      ).format(date);
    } else {
      return DateFormat.yMMMd(
        LocaleHelper.getDateFormatLocale(context),
      ).format(date);
    }
  }

  // Check if we need a date separator for reversed list
  // In reversed list, index 0 = newest, higher index = older
  // Date separator should appear ABOVE (after in reversed index) the first message of a new date
  bool _needsDateSeparatorReversed(List<MessageEntity> messages, int index) {
    // Last item (oldest message) always needs separator
    if (index == messages.length - 1) {
      return true;
    }

    final currentMessage = messages[index];
    final olderMessage = messages[index + 1]; // Next index = older message

    final currentDate = DateTime(
      currentMessage.createdAt.year,
      currentMessage.createdAt.month,
      currentMessage.createdAt.day,
    );
    final olderDate = DateTime(
      olderMessage.createdAt.year,
      olderMessage.createdAt.month,
      olderMessage.createdAt.day,
    );

    return currentDate != olderDate;
  }

  // Get message group position for reversed list
  MessageGroupPosition _getMessageGroupPositionReversed(
    List<MessageEntity> messages,
    int index,
    String? currentUserId, {
    required bool hasDateBreak,
    required bool hasNextDateBreak,
  }) {
    final message = messages[index];

    // In reversed list: lower index = newer, higher index = older
    // "Previous" visually (below) = index - 1 (newer)
    // "Next" visually (above) = index + 1 (older)
    final hasNewerSameSender =
        index > 0 && messages[index - 1].senderId == message.senderId;
    final hasOlderSameSender =
        index < messages.length - 1 &&
        messages[index + 1].senderId == message.senderId;

    if (hasDateBreak) {
      // After date separator (visually), treat as last message of group
      if (hasNewerSameSender && !hasNextDateBreak) {
        return MessageGroupPosition.last;
      }
      return MessageGroupPosition.single;
    }

    if (!hasNewerSameSender && !hasOlderSameSender) {
      return MessageGroupPosition.single;
    } else if (!hasNewerSameSender && hasOlderSameSender) {
      return MessageGroupPosition.first;
    } else if (hasNewerSameSender && hasOlderSameSender) {
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

    // Check if this is a pending request from current user (hide read/delivered status)
    final isPendingRequestFromMe =
        conversation != null &&
        conversation.requestStatus == ConversationRequestStatus.pending &&
        conversation.requesterId == currentUser?.id;

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

    // Stream group data if it's a group chat and we have groupId
    // This ensures we can display group name/image even when navigating from notifications
    dynamic groupData;
    if (widget.isGroup && widget.groupId != null) {
      final groupAsync = ref.watch(groupStreamProvider(widget.groupId!));
      groupData = groupAsync.valueOrNull;
    }

    final currentUserId = ref.read(currentUserProvider).valueOrNull?.id;
    final List<MentionedUser> groupMembers =
        widget.isGroup && groupData != null
            ? ref
                    .watch(
                      groupMemberNamesProvider(
                        (groupData.memberIds as List<String>)
                            .where((id) => id != currentUserId)
                            .toList(),
                      ),
                    )
                    .valueOrNull ??
                []
            : [];

    // Création événement/sondage depuis le menu « + » du composer.
    // DM : événement toujours possible ; groupe : selon les permissions.
    // Sondage : groupes uniquement (PollContextType ne couvre pas les DM).
    final isConvAdmin =
        widget.isGroup
            ? (currentUserId != null &&
                groupData != null &&
                (groupData.creatorId == currentUserId ||
                    (groupData.adminIds as List<String>).contains(
                      currentUserId,
                    )))
            : (conversation != null &&
                currentUser != null &&
                (conversation.createdBy == currentUser.id ||
                    conversation.adminIds.contains(currentUser.id)));
    final canCreateEvent =
        widget.isSelfNotes
            ? false
            : widget.isGroup
            ? (widget.groupId != null &&
                ((groupData?.permissions.canPostEvents(isAdmin: isConvAdmin)
                        as bool?) ??
                    false))
            : true;
    // Sondage : dans « Mes notes », on autorise un brouillon de sondage (note
    // structurée) ; dans un groupe, un vrai sondage votable selon permissions.
    final canCreatePoll =
        widget.isSelfNotes ||
        (widget.isGroup &&
            widget.groupId != null &&
            ((groupData?.permissions.canPostPolls(isAdmin: isConvAdmin)
                    as bool?) ??
                false));

    // Determine display name for typing indicator
    // For groups: use passed name, fallback to loaded group data, then default
    // For individual: use loaded user profile, fallback to passed name, then default
    final displayName =
        widget.isGroup
            ? (widget.conversationName ?? groupData?.name ?? l10n.group)
            : (otherUser?.displayName ?? widget.conversationName ?? l10n.user);

    // Typing users for the in-list bubble
    final typingStatusValue = ref.watch(
      typingStatusProvider(widget.conversationId),
    );
    final typingUserIds =
        typingStatusValue
            .whenData(
              (map) =>
                  map.entries
                      .where((e) => e.key != currentUser?.id && e.value)
                      .map((e) => e.key)
                      .toList(),
            )
            .valueOrNull ??
        <String>[];
    final Map<String, String>? typingNames =
        widget.isGroup
            ? {for (final m in groupMembers) m.id: m.name}
            : (widget.otherUserId != null
                ? {widget.otherUserId!: displayName}
                : null);

    // Auto-scroll to bottom when new messages arrive & calculate unread on first load
    ref.listen(paginatedMessagesProvider(widget.conversationId), (
      previous,
      next,
    ) {
      // Calculate unread count and scroll to initial position when messages are first loaded
      if (!_hasCalculatedUnread &&
          next.messages.isNotEmpty &&
          !next.isLoadingInitial) {
        _calculateUnreadOnOpen();
      }

      // Mark new messages as read only if app is in foreground
      if (previous != null &&
          next.messages.length > previous.messages.length &&
          _isAppInForeground) {
        final currentUserId = currentUser?.id;
        if (currentUserId != null) {
          // Check if there are new messages from other users
          final newMessagesFromOthers = next.messages
              .where((m) => !previous.messages.any((pm) => pm.id == m.id))
              .any((m) => m.senderId != currentUserId);

          if (newMessagesFromOthers) {
            ref
                .read(markAsDeliveredProvider.notifier)
                .mark(widget.conversationId);
            ref.read(markAsReadProvider.notifier).mark(widget.conversationId);
          }
        }
      }

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
      appBar:
          _isSelectionMode
              ? _buildSelectionAppBar(paginationState.messages)
              : _isSearchMode
              ? _buildSearchAppBar()
              : _buildAppBar(otherUser, groupData),
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
            // Fond d'écran nommé (§21c) rendu procéduralement, sous l'overlay.
            if (_chatBackground != null &&
                _chatBackground!.isPattern &&
                ChatWallpaper.byId(_chatBackground!.patternId) != null)
              ChatWallpaper.byId(_chatBackground!.patternId)!
                  .fill(context.isDarkMode),
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
                // Message request banner (pending request)
                if (conversation != null &&
                    conversation.isPendingRequest &&
                    currentUser != null)
                  _buildMessageRequestBanner(
                    l10n,
                    conversation,
                    currentUser.id,
                  ),
                // Bandeau des éléments épinglés (event/poll/message), façon
                // Telegram : ligne fine fixée sous l'en-tête, toujours visible.
                // Le widget porte sa propre marge : il ne laisse aucun espace
                // quand rien n'est épinglé.
                // Repli sur conversation?.groupId : widget.groupId peut être
                // absent (notification/deep link sans extra complet) alors que
                // la conversation elle-même connaît son group_id — sans ce
                // repli, le bandeau (et donc les messages épinglés) restait
                // invisible en permanence pour cette conversation.
                if (widget.isGroup &&
                    (widget.groupId ?? conversation?.groupId) != null)
                  GroupPinnedBanner(
                    groupId: (widget.groupId ?? conversation?.groupId)!,
                    messageConversationId: widget.conversationId,
                    onOpenMessage: _scrollToMessage,
                  )
                else if (!widget.isGroup)
                  GroupPinnedBanner(
                    conversationId: widget.conversationId,
                    messageConversationId: widget.conversationId,
                    onOpenMessage: _scrollToMessage,
                  ),
                // Sous-barre : raccourci Médias + bascule ÉCO (données réduites).
                if (!widget.isSelfNotes &&
                    !(conversation?.isPendingRequest ?? false))
                  _buildQuickSubBar(context),
                // Invitation a restaurer les cles, quand des messages de ce
                // fil ne sont pas dechiffrables sur cet appareil.
                _buildE2eeRestoreBanner(context, paginationState.messages),
                // Messages
                Expanded(
                  child: _buildMessageList(
                    paginationState,
                    currentUser?.id,
                    l10n,
                    blockedUsers.map((u) => u.id).toSet(),
                    isPendingRequestFromMe,
                    (!isDeleted && !isBlocked) ? typingUserIds : const [],
                    typingNames,
                  ),
                ),

                // Input or Blocked/Deleted Message
                if (isDeleted ||
                    (otherUser != null &&
                        otherUser.displayName == l10n.deletedUser))
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: context.surfaceColor,
                    width: double.infinity,
                    child: Text(
                      isDeleted
                          ? l10n.thisGroupWasDeleted
                          : l10n.thisUserWasDeleted,
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
                      l10n.youBlockedThisUser,
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
                    conversationId: widget.conversationId,
                    isLoading: sendMessageState.isLoading,
                    replyToMessage: _replyToMessage,
                    onCancelReply: _cancelReply,
                    groupMembers: groupMembers,
                    onCreateEvent:
                        canCreateEvent
                            ? () => context.push(
                              widget.isGroup
                                  ? '/groups/${widget.groupId}/events/create'
                                  : '/conversations/${widget.conversationId}/events/create',
                            )
                            : null,
                    onCreatePoll:
                        !canCreatePoll
                            ? null
                            : widget.isSelfNotes
                            ? () => _createPollDraft()
                            : () => showCreatePollSheet(
                              context,
                              contextType: PollContextType.group,
                              contextId: widget.groupId!,
                            ),
                    onTyping: () {
                      ref
                          .read(typingIndicatorNotifierProvider.notifier)
                          .onUserTyping(widget.conversationId);
                    },
                    onSendText: (text, mentions) async {
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
                      final blockedByList =
                          isBlockedByOther && widget.otherUserId != null
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
                            mentionedUsers: mentions,
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
                    onSendAudioFile: (File file, {String? caption}) async {
                      // If blocked, don't send audio file.
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
                            type: MessageType.audio,
                            caption: caption,
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
                    onSendLocation: (
                      double latitude,
                      double longitude,
                      String address,
                    ) async {
                      // If blocked, don't send location
                      if (isBlockedByOther) {
                        _scrollToBottom();
                        if (_replyToMessage != null) _cancelReply();
                        return;
                      }

                      final success = await ref
                          .read(sendMessageProvider.notifier)
                          .sendLocation(
                            conversationId: widget.conversationId,
                            latitude: latitude,
                            longitude: longitude,
                            address: address,
                            replyToMessage: _replyToMessage,
                          );

                      if (!mounted) return;

                      if (success) {
                        AnalyticsService.instance.logEvent(
                          name: 'send_message',
                          parameters: {
                            'type': 'location',
                            'conversation_id': widget.conversationId,
                            'is_group': widget.isGroup ? 'true' : 'false',
                          },
                        );
                        _scrollToBottom();
                        if (_replyToMessage != null) _cancelReply();
                      }
                    },
                    onSendSticker: (StickerEntity sticker) async {
                      // If blocked, don't send sticker
                      if (isBlockedByOther) {
                        _scrollToBottom();
                        if (_replyToMessage != null) _cancelReply();
                        return;
                      }

                      final success = await ref
                          .read(sendMessageProvider.notifier)
                          .sendSticker(
                            conversationId: widget.conversationId,
                            stickerPackId: sticker.packId,
                            stickerId: sticker.id,
                            stickerUrl: sticker.url,
                            isAnimated: sticker.isAnimated,
                            replyToMessage: _replyToMessage,
                          );

                      if (!mounted) return;

                      if (success) {
                        AnalyticsService.instance.logEvent(
                          name: 'send_message',
                          parameters: {
                            'type': 'sticker',
                            'sticker_pack': sticker.packId,
                            'conversation_id': widget.conversationId,
                            'is_group': widget.isGroup ? 'true' : 'false',
                          },
                        );
                        _scrollToBottom();
                        if (_replyToMessage != null) _cancelReply();
                      }
                    },
                    onSendGif: (GifEntity gif) async {
                      if (isBlockedByOther) {
                        _scrollToBottom();
                        if (_replyToMessage != null) _cancelReply();
                        return;
                      }

                      // Un GIF distant est un média flottant identifié par une
                      // URL : il réutilise le transport « sticker », en portant
                      // le fournisseur (tenor/giphy) comme identifiant de pack.
                      final success = await ref
                          .read(sendMessageProvider.notifier)
                          .sendSticker(
                            conversationId: widget.conversationId,
                            stickerPackId: gif.packId,
                            stickerId: gif.id,
                            stickerUrl: gif.url,
                            isAnimated: true,
                            replyToMessage: _replyToMessage,
                          );

                      if (!mounted) return;

                      if (success) {
                        AnalyticsService.instance.logEvent(
                          name: 'send_message',
                          parameters: {
                            'type': 'gif',
                            'gif_provider': gif.provider.name,
                            'conversation_id': widget.conversationId,
                            'is_group': widget.isGroup ? 'true' : 'false',
                          },
                        );
                        _scrollToBottom();
                        if (_replyToMessage != null) _cancelReply();
                      }
                    },
                  ),
              ],
            ),

            // Search results overlay
            if (_isSearchMode && _searchQuery.length >= 2)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                bottom: 0,
                child: _buildSearchResults(),
              ),

            // Scroll to bottom FAB with unread badge
            ValueListenableBuilder<bool>(
              valueListenable: _showScrollToBottomButton,
              builder: (context, showButton, child) {
                if (!showButton) return const SizedBox.shrink();
                return Positioned(
                  bottom: 100,
                  right: 16,
                  child: ScaleTransition(
                    scale: _scrollButtonAnimation,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        FloatingActionButton.small(
                          onPressed: _scrollToBottom,
                          backgroundColor: context.surfaceColor,
                          elevation: 4,
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: context.textPrimaryColor,
                          ),
                        ),
                        // Unread count badge
                        if (_unreadCountOnOpen > 0)
                          Positioned(
                            top: -4,
                            right: -4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: context.adaptivePrimaryColor,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 18,
                                minHeight: 18,
                              ),
                              child: Text(
                                _unreadCountOnOpen > 99
                                    ? '99+'
                                    : _unreadCountOnOpen.toString(),
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
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
    bool isPendingRequestFromMe,
    List<String> typingUserIds,
    Map<String, String>? typingNames,
  ) {
    if (paginationState.isLoadingInitial) {
      return const SizedBox.shrink();
    }

    if (paginationState.error != null && paginationState.messages.isEmpty) {
      // Convertir l'erreur technique en message user-friendly
      final userFriendlyError = FailureMapper.toUserFriendlyString(
        paginationState.error!,
        context,
      );
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppIcon(AppIcon.error, size: 48, color: context.textTertiaryColor),
            const SizedBox(height: 16),
            Text(
              userFriendlyError,
              style: TextStyle(color: context.textSecondaryColor, fontSize: 16),
              textAlign: TextAlign.center,
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
              icon: const AppIcon(AppIcon.refresh, color: AppColors.white),
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
    final typingCount = typingUserIds.isNotEmpty ? 1 : 0;
    final totalCount =
        messages.length +
        (paginationState.isLoadingMore ? 1 : 0) +
        (isUploadingHere ? 1 : 0) +
        typingCount;

    // Calculate top padding - add extra when body extends behind app bar
    final topPadding =
        (_chatBackground != null && !_chatBackground!.isDefault)
            ? MediaQuery.of(context).padding.top + kToolbarHeight + 16
            : 16.0;

    // Reverse messages so newest is at index 0 (for reverse: true ListView)
    final reversedMessages = messages.reversed.toList();

    return ListView.builder(
      controller: _scrollController,
      reverse: true, // Start from bottom (newest messages)
      padding: EdgeInsets.only(top: 16, bottom: topPadding),
      itemCount: totalCount,
      itemBuilder: (context, index) {
        // Typing bubble at index 0 (bottom of reversed list = nearest to input)
        if (typingUserIds.isNotEmpty && index == 0) {
          return TypingBubble(
            typingUserIds: typingUserIds,
            userNames: typingNames,
          );
        }

        // Show uploading skeleton just above the typing bubble
        if (isUploadingHere && index == typingCount) {
          return const UploadingMediaSkeleton();
        }

        // Show loading indicator at the top when loading more (last index in reversed list)
        if (paginationState.isLoadingMore && index == totalCount - 1) {
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

        // Calculate message index in reversed list (accounting for typing + upload offsets)
        final messageIndex = index - typingCount - (isUploadingHere ? 1 : 0);

        // Safety check
        if (messageIndex < 0 || messageIndex >= reversedMessages.length) {
          return const SizedBox.shrink();
        }

        final message = reversedMessages[messageIndex];
        final isMe = message.senderId == currentUserId;

        // For reversed list, date separators appear AFTER the message (visually above)
        // Check if the NEXT message (older, higher index) has a different date
        final needsSeparator = _needsDateSeparatorReversed(
          reversedMessages,
          messageIndex,
        );
        final hasNextDateBreak =
            messageIndex > 0
                ? _needsDateSeparatorReversed(
                  reversedMessages,
                  messageIndex - 1,
                )
                : false;

        // Get group position for linked bubbles (pass pre-computed values)
        final groupPosition = _getMessageGroupPositionReversed(
          reversedMessages,
          messageIndex,
          currentUserId,
          hasDateBreak: needsSeparator,
          hasNextDateBreak: hasNextDateBreak,
        );

        // Only show sender info for the first message in a group (first or single)
        // In reversed list, "first" visually means the bottom-most of a group
        final showSenderInfo =
            widget.isGroup &&
            !isMe &&
            (groupPosition == MessageGroupPosition.first ||
                groupPosition == MessageGroupPosition.single);

        final conversation =
            ref
                .watch(conversationStreamProvider(widget.conversationId))
                .valueOrNull;
        // widget.groupId peut être absent (notification/deep link sans extra
        // complet) alors que la conversation connaît son group_id : sans ce
        // repli, canPin/pinnedMessageIds retombaient sur
        // conversationPinnedItemsProvider — qui ne renvoie jamais rien pour un
        // groupe (les épingles de groupe sont indexées par group_id, pas
        // conversation_id) — et les messages épinglés semblaient absents.
        final effectiveGroupId = widget.groupId ?? conversation?.groupId;
        // Le rôle admin/modérateur (group_members.role) est la source de
        // vérité côté RLS ; conversation.adminIds n'est qu'un instantané figé
        // à la création de la conversation (jamais mis à jour lors d'une
        // promotion), d'où un décrochage sinon entre ce que montre l'UI et ce
        // que les RLS Supabase autorisent réellement pour épingler/détacher.
        final groupForAdminCheck =
            effectiveGroupId != null
                ? ref.watch(groupStreamProvider(effectiveGroupId)).valueOrNull
                : null;
        final isAdmin =
            widget.isGroup
                ? (currentUserId != null &&
                    groupForAdminCheck != null &&
                    (groupForAdminCheck.creatorId == currentUserId ||
                        groupForAdminCheck.adminIds.contains(currentUserId)))
                : (conversation != null &&
                    currentUserId != null &&
                    (conversation.createdBy == currentUserId ||
                        conversation.adminIds.contains(currentUserId)));

        // L'expéditeur de CE message est-il admin/créateur du groupe ?
        // (Badge « Admin » à côté de son nom.)
        final senderIsAdmin =
            widget.isGroup &&
            !isMe &&
            groupForAdminCheck != null &&
            (groupForAdminCheck.creatorId == message.senderId ||
                groupForAdminCheck.adminIds.contains(message.senderId));

        // En 1-a-1, les deux participants peuvent epingler ; en groupe, selon
        // les permissions du groupe.
        final canPin =
            !widget.isGroup
                ? true
                : (groupForAdminCheck?.permissions.canPin(isAdmin: isAdmin) ??
                    false);

        // Ids des messages déjà épinglés : le menu contextuel bascule alors
        // « Épingler » en « Détacher » (le bandeau n'a plus de croix).
        final pinnedMessageIds =
            ((widget.isGroup && effectiveGroupId != null
                            ? ref.watch(
                              groupPinnedItemsProvider(effectiveGroupId),
                            )
                            : ref.watch(
                              conversationPinnedItemsProvider(
                                widget.conversationId,
                              ),
                            ))
                        .valueOrNull ??
                    const [])
                .where((i) => i.itemType == GroupPinnedItemType.message)
                .map((i) => i.itemId)
                .toSet();

        // Check if we need to show unread separator
        // In reversed list, first unread is at a different index
        final originalIndex = reversedMessages.length - 1 - messageIndex;
        final showUnreadSeparator =
            _firstUnreadMessageIndex != null &&
            originalIndex == _firstUnreadMessageIndex &&
            _unreadCountOnOpen > 0;

        // With reverse: true, separators go BEFORE the message in the Column
        // so they appear visually ABOVE (Column still renders top-to-bottom within each item)
        return Column(
          children: [
            // Date separator (appears ABOVE message visually)
            if (needsSeparator) _buildDateSeparator(message.createdAt, l10n),

            // Unread messages separator (appears ABOVE message visually)
            if (showUnreadSeparator) _buildUnreadSeparator(_unreadCountOnOpen),

            // Message bubble with highlight animation
            // RepaintBoundary isolates repaints for better performance
            RepaintBoundary(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  color:
                      _highlightedMessageId == message.id
                          ? context.adaptivePrimaryColor.withValues(alpha: 0.15)
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Align(
                  alignment:
                      isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child:
                      widget.isGroup && !isMe
                          ? Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // Mini avatar for group messages
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 4,
                                  bottom: 4,
                                ),
                                child:
                                    showSenderInfo
                                        ? CircleAvatar(
                                          radius: 12,
                                          backgroundImage:
                                              message.senderPhotoUrl != null
                                                  ? CachedNetworkImageProvider(
                                                    message.senderPhotoUrl!,
                                                  )
                                                  : null,
                                          backgroundColor:
                                              context.surfaceVariantColor,
                                          child:
                                              message.senderPhotoUrl == null
                                                  ? Text(
                                                    message
                                                            .senderName
                                                            .isNotEmpty
                                                        ? message.senderName[0]
                                                            .toUpperCase()
                                                        : '?',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color:
                                                          context
                                                              .textSecondaryColor,
                                                    ),
                                                  )
                                                  : null,
                                        )
                                        : const SizedBox(
                                          width: 24,
                                        ), // Spacing for alignment
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: MessageBubble(
                                  key: ValueKey(message.id),
                                  message: message,
                                  isMe: isMe,
                                  showSenderInfo: showSenderInfo,
                                  senderIsAdmin: senderIsAdmin,
                                  groupPosition: groupPosition,
                                  conversationId: widget.conversationId,
                                  currentUserId: currentUserId,
                                  isAdmin: isAdmin,
                                  canPin: canPin,
                                  isPinned: pinnedMessageIds.contains(
                                    message.id,
                                  ),
                                  onPin: canPin ? _pinMessage : null,
                                  onUnpin: canPin ? _unpinMessage : null,
                                  onReply: _handleReply,
                                  onReact: _handleReact,
                                  onForward: _handleForward,
                                  onToggleStar: (msg) {
                                    ref
                                        .read(
                                          paginatedMessagesProvider(
                                            widget.conversationId,
                                          ).notifier,
                                        )
                                        .toggleStar(msg.id);
                                  },
                                  onEdit: (msg, newContent) async {
                                    final l10n = AppLocalizations.of(context)!;
                                    final messenger = ScaffoldMessenger.of(
                                      context,
                                    );
                                    final success = await ref
                                        .read(
                                          paginatedMessagesProvider(
                                            widget.conversationId,
                                          ).notifier,
                                        )
                                        .editMessage(
                                          messageId: msg.id,
                                          newContent: newContent,
                                        );
                                    if (mounted) {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            success
                                                ? l10n.messageEdited
                                                : l10n.editTimeExpired,
                                          ),
                                          backgroundColor:
                                              success
                                                  ? Colors.green
                                                  : Colors.red,
                                        ),
                                      );
                                    }
                                  },
                                  isSelectionMode: _isSelectionMode,
                                  isSelected: _selectedMessageIds.contains(
                                    message.id,
                                  ),
                                  onSelect: _handleSelect,
                                  // Call back support for call messages (1:1 conversations only)
                                  onCallBack:
                                      (!widget.isGroup &&
                                              widget.otherUserId != null &&
                                              message.isCall)
                                          ? () => _handleCallBack(message)
                                          : null,
                                  // Skip animation for existing messages (performance)
                                  skipAnimation: true,
                                  // Hide read/delivered status for pending requests
                                  isPendingRequest: isPendingRequestFromMe,
                                  onRetry:
                                      message.status == MessageStatus.failed
                                          ? () async {
                                            final messenger =
                                                ScaffoldMessenger.of(context);
                                            final l10nMsg =
                                                AppLocalizations.of(context)!;
                                            final success = await ref
                                                .read(
                                                  sendMessageProvider.notifier,
                                                )
                                                .retryFailedMessage(
                                                  conversationId:
                                                      widget.conversationId,
                                                  failedMessage: message,
                                                );
                                            if (!success && mounted) {
                                              messenger.showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    l10nMsg.messageResendFailed,
                                                  ),
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
                                  groupId:
                                      widget.isGroup
                                          ? (widget.groupId ??
                                              widget.conversationId)
                                          : null,
                                ),
                              ),
                            ],
                          )
                          : MessageBubble(
                            key: ValueKey(message.id),
                            message: message,
                            isMe: isMe,
                            showSenderInfo: showSenderInfo,
                            senderIsAdmin: senderIsAdmin,
                            groupPosition: groupPosition,
                            conversationId: widget.conversationId,
                            currentUserId: currentUserId,
                            isAdmin: isAdmin,
                            canPin: canPin,
                            isPinned: pinnedMessageIds.contains(message.id),
                            onPin: canPin ? _pinMessage : null,
                            onUnpin: canPin ? _unpinMessage : null,
                            onReply: _handleReply,
                            onReact: _handleReact,
                            onForward: _handleForward,
                            onToggleStar: (msg) {
                              ref
                                  .read(
                                    paginatedMessagesProvider(
                                      widget.conversationId,
                                    ).notifier,
                                  )
                                  .toggleStar(msg.id);
                            },
                            onEdit: (msg, newContent) async {
                              final l10n = AppLocalizations.of(context)!;
                              final messenger = ScaffoldMessenger.of(context);
                              final success = await ref
                                  .read(
                                    paginatedMessagesProvider(
                                      widget.conversationId,
                                    ).notifier,
                                  )
                                  .editMessage(
                                    messageId: msg.id,
                                    newContent: newContent,
                                  );
                              if (mounted) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      success
                                          ? l10n.messageEdited
                                          : l10n.editTimeExpired,
                                    ),
                                    backgroundColor:
                                        success ? Colors.green : Colors.red,
                                  ),
                                );
                              }
                            },
                            isSelectionMode: _isSelectionMode,
                            isSelected: _selectedMessageIds.contains(
                              message.id,
                            ),
                            onSelect: _handleSelect,
                            onCallBack:
                                (!widget.isGroup &&
                                        widget.otherUserId != null &&
                                        message.isCall)
                                    ? () => _handleCallBack(message)
                                    : null,
                            skipAnimation: true,
                            isPendingRequest: isPendingRequestFromMe,
                            onRetry:
                                message.status == MessageStatus.failed
                                    ? () async {
                                      final messenger = ScaffoldMessenger.of(
                                        context,
                                      );
                                      final l10nMsg =
                                          AppLocalizations.of(context)!;
                                      final success = await ref
                                          .read(sendMessageProvider.notifier)
                                          .retryFailedMessage(
                                            conversationId:
                                                widget.conversationId,
                                            failedMessage: message,
                                          );
                                      if (!success && mounted) {
                                        messenger.showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              l10nMsg.messageResendFailed,
                                            ),
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
                            groupId:
                                widget.isGroup
                                    ? (widget.groupId ?? widget.conversationId)
                                    : null,
                          ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Séparateur de jour : filet plein et pastille plate.
  ///
  /// Les dégradés en fondu, la bordure et l'ombre portée ont sauté : le fil de
  /// discussion est posé sur le fond crème, un repère de date n'a pas à se
  /// détacher du fond comme un élément cliquable.
  Widget _buildDateSeparator(DateTime date, AppLocalizations l10n) {
    return _buildThreadSeparator(
      label: _getDateLabel(date, l10n),
      background: context.surfaceVariantColor,
      foreground: context.textSecondaryColor,
      rule: context.dividerColor,
    );
  }

  /// Gabarit commun aux repères posés dans le fil (date, non-lus) : un filet
  /// de part et d'autre, une pastille au centre.
  Widget _buildThreadSeparator({
    required String label,
    required Color background,
    required Color foreground,
    required Color rule,
  }) {
    final trait = Expanded(child: Container(height: 1, color: rule));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        children: [
          trait,
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(kDesignPillRadius),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: foreground,
                letterSpacing: 0.3,
              ),
            ),
          ),
          trait,
        ],
      ),
    );
  }

  Widget _buildUnreadSeparator(int unreadCount) {
    final label =
        unreadCount == 1 ? '1 message non lu' : '$unreadCount messages non lus';

    // Même gabarit que le séparateur de date, mais en terracotta plein : c'est
    // le seul repère du fil qui doit accrocher l'œil.
    return _buildThreadSeparator(
      label: label,
      background: context.adaptivePrimaryColor,
      foreground: context.onPrimaryColor,
      rule: context.adaptivePrimaryColor.withValues(alpha: 0.35),
    );
  }

  /// Start a call with the other user
  Future<void> _startCall({required bool isVideo}) async {
    if (widget.otherUserId == null) return;

    final l10n = AppLocalizations.of(context)!;

    // Get other user info from watched data
    final otherUserAsync = ref.read(userStreamProvider(widget.otherUserId!));
    final otherUser = otherUserAsync.valueOrNull;

    final calleeName =
        otherUser?.displayName ?? widget.conversationName ?? l10n.user;
    final calleePhotoUrl = otherUser?.photoUrl ?? widget.conversationImageUrl;

    // Vérifier si le destinataire peut recevoir des notifications (en ligne OU a un token FCM)
    final isCalleeOnline = otherUser?.canReceiveNotifications ?? false;

    // Create the call in Firestore via CurrentCall provider
    final call = await ref
        .read(currentCallProvider.notifier)
        .initiateCall(
          calleeId: widget.otherUserId!,
          calleeName: calleeName,
          calleePhotoUrl: calleePhotoUrl,
          type: isVideo ? CallType.video : CallType.audio,
        );

    if (call == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.unableToStartCall),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Navigate to call screen with the real call ID from Firestore
    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder:
              (context) => CallScreen(
                callId: call.id,
                isInitiator: true,
                isVideo: isVideo,
                calleeName: calleeName,
                calleePhotoUrl: calleePhotoUrl,
                isCalleeOnline: isCalleeOnline,
              ),
        ),
      );
    }

    // Log analytics
    AnalyticsService.instance.logEvent(
      name: 'start_call',
      parameters: {
        'call_type': isVideo ? 'video' : 'audio',
        'callee_id': widget.otherUserId!,
      },
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

  PreferredSizeWidget _buildSelectionAppBar(List<MessageEntity> allMessages) {
    return AppBar(
      backgroundColor: context.adaptivePrimaryColor,
      elevation: 0,
      leading: IconButton(
        onPressed: _exitSelectionMode,
        icon: const AppIcon(AppIcon.close, color: AppColors.white),
      ),
      title: Text(
        '${_selectedMessageIds.length} sélectionné${_selectedMessageIds.length > 1 ? 's' : ''}',
        style: const TextStyle(
          color: AppColors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        // Select all
        IconButton(
          onPressed: () {
            setState(() {
              if (_selectedMessageIds.length == allMessages.length) {
                _selectedMessageIds.clear();
              } else {
                _selectedMessageIds
                  ..clear()
                  ..addAll(allMessages.map((m) => m.id));
              }
            });
          },
          icon: Icon(
            _selectedMessageIds.length == allMessages.length
                ? Icons.deselect
                : Icons.select_all,
            color: AppColors.white,
          ),
          tooltip:
              _selectedMessageIds.length == allMessages.length
                  ? AppLocalizations.of(context)!.deselectAll
                  : AppLocalizations.of(context)!.selectAll,
        ),
        // Star selected
        IconButton(
          onPressed: () => _starSelectedMessages(allMessages),
          icon: const AppIcon(AppIcon.starBorder, color: AppColors.white),
          tooltip: AppLocalizations.of(context)!.favorites,
        ),
        // Forward selected
        IconButton(
          onPressed: () => _forwardSelectedMessages(allMessages),
          icon: const Icon(Icons.shortcut, color: AppColors.white),
          tooltip: AppLocalizations.of(context)!.forward,
        ),
        // Delete selected
        IconButton(
          onPressed: () => _deleteSelectedMessages(allMessages),
          icon: const AppIcon(AppIcon.delete, color: AppColors.white),
          tooltip: AppLocalizations.of(context)!.delete,
        ),
      ],
    );
  }

  PreferredSizeWidget _buildSearchAppBar() {
    return AppBar(
      backgroundColor: context.surfaceColor,
      elevation: 0,
      leading: IconButton(
        onPressed: () {
          setState(() {
            _isSearchMode = false;
            _searchQuery = '';
            _searchController.clear();
          });
        },
        icon: AppIcon(AppIcon.arrowBack, color: context.textPrimaryColor),
      ),
      title: TextField(
        controller: _searchController,
        autofocus: true,
        style: TextStyle(color: context.textPrimaryColor, fontSize: 16),
        decoration: InputDecoration(
          hintText: AppLocalizations.of(context)!.searchMessages,
          hintStyle: TextStyle(color: context.textTertiaryColor, fontSize: 16),
          border: InputBorder.none,
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value.trim();
          });
        },
      ),
      actions: [
        if (_searchController.text.isNotEmpty)
          IconButton(
            onPressed: () {
              _searchController.clear();
              setState(() {
                _searchQuery = '';
              });
            },
            icon: AppIcon(AppIcon.close, color: context.textTertiaryColor),
          ),
      ],
    );
  }

  Widget _buildSearchResults() {
    return Consumer(
      builder: (context, ref, _) {
        final resultsAsync = ref.watch(
          messageSearchProvider((
            conversationId: widget.conversationId,
            query: _searchQuery,
          )),
        );

        return GestureDetector(
          onTap: () {
            // Dismiss search on tap outside
            setState(() {
              _isSearchMode = false;
              _searchQuery = '';
              _searchController.clear();
            });
          },
          child: Container(
            color: context.surfaceColor.withValues(alpha: 0.95),
            child: resultsAsync.when(
              loading:
                  () => Center(
                    child: CircularProgressIndicator(
                      color: context.adaptivePrimaryColor,
                    ),
                  ),
              error:
                  (_, __) => Center(
                    child: Text(
                      AppLocalizations.of(context)!.searchError,
                      style: TextStyle(color: context.textSecondaryColor),
                    ),
                  ),
              data: (results) {
                if (results.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppIcon(
                          AppIcon.searchOff,
                          size: 48,
                          color: context.textTertiaryColor.withValues(
                            alpha: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          AppLocalizations.of(context)!.noSearchResults,
                          style: TextStyle(color: context.textSecondaryColor),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: results.length,
                  separatorBuilder:
                      (_, __) => Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: context.dividerColor,
                      ),
                  itemBuilder: (context, index) {
                    final message = results[index];
                    return ListTile(
                      onTap: () {
                        setState(() {
                          _isSearchMode = false;
                          _searchQuery = '';
                          _searchController.clear();
                        });
                        _scrollToMessage(message.id);
                      },
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: context.adaptivePrimaryColor
                            .withValues(alpha: 0.15),
                        child: Text(
                          message.senderName.isNotEmpty
                              ? message.senderName[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: context.adaptivePrimaryColor,
                          ),
                        ),
                      ),
                      title: Text(
                        message.senderName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.textPrimaryColor,
                        ),
                      ),
                      subtitle: _buildHighlightedText(
                        context,
                        message.content,
                        _searchQuery,
                      ),
                      trailing: Text(
                        DateFormat.Hm().format(message.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: context.textTertiaryColor,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildHighlightedText(
    BuildContext context,
    String text,
    String query,
  ) {
    if (query.isEmpty) {
      return Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 13, color: context.textSecondaryColor),
      );
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final matchIndex = lowerText.indexOf(lowerQuery);

    if (matchIndex == -1) {
      return Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 13, color: context.textSecondaryColor),
      );
    }

    // Show context around the match
    final start = (matchIndex - 20).clamp(0, text.length);
    final end = (matchIndex + query.length + 40).clamp(0, text.length);
    final snippet = text.substring(start, end);
    final snippetMatchStart = matchIndex - start;

    return Text.rich(
      TextSpan(
        children: [
          if (start > 0) const TextSpan(text: '...'),
          TextSpan(
            text: snippet.substring(0, snippetMatchStart),
            style: TextStyle(fontSize: 13, color: context.textSecondaryColor),
          ),
          TextSpan(
            text: snippet.substring(
              snippetMatchStart,
              snippetMatchStart + query.length,
            ),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: context.adaptivePrimaryColor,
            ),
          ),
          TextSpan(
            text: snippet.substring(snippetMatchStart + query.length),
            style: TextStyle(fontSize: 13, color: context.textSecondaryColor),
          ),
          if (end < text.length) const TextSpan(text: '...'),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// Compose un brouillon de sondage dans « Mes notes » et l'envoie comme note
  /// texte structurée (question + options). Pas de vote — c'est un aide-mémoire
  /// à recopier/publier ailleurs.
  Future<void> _createPollDraft() async {
    final draft = await showNotePollDraftSheet(context);
    if (draft == null || draft.isEmpty || !mounted) return;

    final success = await ref
        .read(sendMessageProvider.notifier)
        .sendText(conversationId: widget.conversationId, content: draft);
    if (mounted && success) _scrollToBottom();
  }

  /// Sous-barre sous l'en-tête : tuiles « Médias » (galerie partagée) et
  /// « ÉCO » (mode données réduites, lié à `PreferencesService.dataSaverMode`).
  /// Placeholder pose par `message_supabase_datasource.dart` quand le
  /// dechiffrement echoue. Duplique ici faute de constante partagee —
  /// `message_provider.dart` fait deja le meme test.
  static const String _kUndecryptable = '🔐 Message chiffré';

  /// Bandeau d'invitation a restaurer les cles (§3b).
  ///
  /// Sans lui, un fil dont les cles ont ete perdues n'affiche qu'une suite de
  /// « Message chiffre », sans dire pourquoi ni quoi faire. Les deux
  /// chaines existaient dans l'ARB mais n'etaient branchees nulle part.
  Widget _buildE2eeRestoreBanner(
    BuildContext context,
    List<MessageEntity> messages,
  ) {
    if (!messages.any((m) => m.content == _kUndecryptable)) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: context.warningBackgroundColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.key_outlined, size: 18, color: context.warningColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.e2eeRestoreNudgeMessage,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.35,
                color: context.textPrimaryColor,
              ),
            ),
          ),
          const SizedBox(width: 6),
          TextButton(
            onPressed: () => context.push('/settings/security/backup'),
            child: Text(
              l10n.e2eeRestoreNudgeAction,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: context.adaptivePrimaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickSubBar(BuildContext context) {
    final eco = PreferencesService.instance.dataSaverMode;
    final tileBg =
        context.isDarkMode ? const Color(0xFF252119) : const Color(0xFFF5F0E8);
    // Repère (épinglé/éco) : #B85E24 clair / #F4A574 sombre.
    final repere =
        context.isDarkMode ? const Color(0xFFF4A574) : const Color(0xFFB85E24);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Row(
        children: [
          _SubBarTile(
            bg: tileBg,
            icon: AppIcon(
              AppIcon.image,
              size: 15,
              color: context.textSecondaryColor,
            ),
            label: 'Médias',
            labelColor: context.textSecondaryColor,
            onTap:
                () => context.push('/messages/${widget.conversationId}/media'),
          ),
          const SizedBox(width: 8),
          _SubBarTile(
            bg: eco ? repere.withValues(alpha: 0.15) : tileBg,
            icon: Icon(
              Icons.data_saver_on,
              size: 15,
              color: eco ? repere : context.textSecondaryColor,
            ),
            label: 'ÉCO',
            labelColor: eco ? repere : context.textSecondaryColor,
            onTap: () async {
              await PreferencesService.instance.setDataSaverMode(!eco);
              if (mounted) setState(() {});
            },
          ),
          const Spacer(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(dynamic otherUser, dynamic groupData) {
    final l10n = AppLocalizations.of(context)!;
    // For groups: use passed name, fallback to loaded group data, then default
    // For individual: use loaded user profile, fallback to passed name, then default
    final displayName =
        widget.isSelfNotes
            ? 'Mes notes'
            : widget.isGroup
            ? (widget.conversationName ?? groupData?.name ?? l10n.group)
            : (otherUser?.displayName ?? widget.conversationName ?? l10n.user);

    final displayImage =
        widget.isSelfNotes
            ? null
            : widget.isGroup
            ? (widget.conversationImageUrl ?? groupData?.imageUrl)
            : (otherUser?.photoUrl ?? widget.conversationImageUrl);

    final initials = _getInitials(displayName);

    // Check if user is deleted
    final isDeletedUser =
        otherUser != null && otherUser.displayName == l10n.deletedUser;

    return AppBar(
      backgroundColor: context.surfaceColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleSpacing: 0,
      toolbarHeight: 58,
      leadingWidth: 40,
      leading: IconButton(
        padding: EdgeInsets.zero,
        onPressed: () => Navigator.of(context).pop(),
        icon: AppIcon(AppIcon.arrowBack, color: context.textPrimaryColor),
      ),
      title: InkWell(
        onTap: () async {
          // debugPrint('🔘 Tapped conversation header:');
          // debugPrint('   isGroup: ${widget.isGroup}');
          // debugPrint('   groupId: ${widget.groupId}');
          // debugPrint('   otherUserId: ${widget.otherUserId}');

          if (widget.isGroup) {
            // Use passed groupId, fallback to loaded groupData, then search by name
            String? groupIdToUse = widget.groupId ?? groupData?.id;

            if (groupIdToUse == null && widget.conversationName != null) {
              final group = await ref.read(
                groupByNameProvider(widget.conversationName!).future,
              );
              groupIdToUse = group?.id;
            }

            if (!mounted) return;
            if (groupIdToUse != null) {
              context.push('/groups/$groupIdToUse');
            } else {
              final l10n = AppLocalizations.of(context)!;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(l10n.loadingError)));
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
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  // Aplat, plus de dégradé : vert pour un groupe, terracotta
                  // pour une personne (§3b, §3c).
                  color:
                      widget.isGroup
                          ? context.adaptiveSecondaryColor
                          : context.adaptivePrimaryColor,
                  borderRadius: BorderRadius.circular(13),
                ),
                child:
                    displayImage != null
                        ? ClipRRect(
                          borderRadius: BorderRadius.circular(13),
                          child: CachedNetworkImage(
                            imageUrl: displayImage,
                            fit: BoxFit.cover,
                            placeholder:
                                (_, __) => Center(
                                  child:
                                      widget.isGroup
                                          ? const AppIcon(
                                            AppIcon.groups,
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
                                          ? const AppIcon(
                                            AppIcon.groups,
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
                              widget.isSelfNotes
                                  ? const Icon(
                                    Icons.bookmark_rounded,
                                    color: AppColors.white,
                                    size: 22,
                                  )
                                  : widget.isGroup
                                  ? const AppIcon(
                                    AppIcon.groups,
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
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Nom de la conversation, en serif comme tous les
                    // titres de la série (§3b, §4a).
                    DesignSectionTitle(
                      displayName ?? AppLocalizations.of(context)!.conversation,
                      size: 17,
                    ),
                    // Status text below name + cadenas chiffrement (§4a) —
                    // jamais affiché pour un compte supprimé, rien à protéger.
                    if (widget.isSelfNotes)
                      _buildStatusWithLock(
                        Text(
                          'Notes personnelles',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.textTertiaryColor,
                          ),
                        ),
                      )
                    else if (widget.isGroup)
                      Builder(
                        builder: (_) {
                          final count = groupData?.memberCount as int?;
                          final label =
                              (count != null && count > 0)
                                  ? '$count ${count > 1 ? 'membres' : 'membre'}'
                                  : AppLocalizations.of(context)!.group;
                          return _buildStatusWithLock(
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 12,
                                color: context.textTertiaryColor,
                              ),
                            ),
                          );
                        },
                      )
                    else if (!widget.isGroup &&
                        widget.otherUserId != null &&
                        !isDeletedUser)
                      // Online status text for individual chats
                      _buildStatusWithLock(
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: OnlineStatusIndicator(
                            key: ValueKey(widget.otherUserId),
                            userId: widget.otherUserId!,
                            showText: true,
                            showDot: false,
                          ),
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
        // Call buttons for individual chats only (not for « Mes notes »)
        if (!widget.isGroup && !isDeletedUser && !widget.isSelfNotes) ...[
          IconButton(
            onPressed: () => _startCall(isVideo: false),
            icon: AppIcon(
              AppIcon.call,
              size: 21,
              color: context.textPrimaryColor,
            ),
            tooltip: l10n.voiceCall,
          ),
          IconButton(
            onPressed: () => _startCall(isVideo: true),
            icon: AppIcon(
              AppIcon.video,
              size: 21,
              color: context.textPrimaryColor,
            ),
            tooltip: l10n.videoCall,
          ),
        ],
        // Appels de groupe (comme en 1-a-1, mais pour tout le groupe)
        if (widget.isGroup && !widget.isSelfNotes) ...[
          IconButton(
            onPressed: () => _startGroupCall(isVideo: false),
            icon: AppIcon(
              AppIcon.call,
              size: 21,
              color: context.textPrimaryColor,
            ),
            tooltip: l10n.voiceCall,
          ),
          IconButton(
            onPressed: () => _startGroupCall(isVideo: true),
            icon: AppIcon(
              AppIcon.video,
              size: 21,
              color: context.textPrimaryColor,
            ),
            tooltip: l10n.videoCall,
          ),
        ],
        // More options button — icône nue, sans conteneur gris (§4a).
        IconButton(
          onPressed: () => _showConversationOptions(),
          icon: Icon(
            Icons.more_vert,
            color: context.textPrimaryColor,
            size: 21,
          ),
        ),
      ],
    );
  }

  /// Statut + cadenas chiffrement (§4a) : Signal pour 1-à-1/groupes, AES
  /// local pour « Mes notes » — jamais affiché pour un compte supprimé
  /// (géré en amont, cette méthode n'est pas appelée dans ce cas).
  Widget _buildStatusWithLock(Widget status) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: status),
        const SizedBox(width: 4),
        AppIcon(AppIcon.lock, size: 11, color: context.textTertiaryColor),
      ],
    );
  }

  Widget _buildEmptyState() {
    final l10n = AppLocalizations.of(context)!;
    // Scrollable : en paysage (ou clavier ouvert) la hauteur restante tombe
    // sous les ~317 px de l'illustration + textes → RenderFlex overflow.
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated chat illustration
            Container(
              width: 120,
              height: 120,
              // Pastille plate : le système n'utilise plus de dégradé
              // décoratif, l'illustration d'état vide est un aplat teinté.
              decoration: BoxDecoration(
                color: context.surfaceVariantColor,
                shape: BoxShape.circle,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AppIcon(
                    AppIcon.chatBubble,
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
                  ? l10n.sendFirstMessageGroup
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
                  l10n.typeYourMessageBelow,
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

  Widget _buildMessageRequestBanner(
    AppLocalizations l10n,
    ConversationEntity conversation,
    String currentUserId,
  ) {
    final isRecipient = conversation.isRequestRecipient(currentUserId);

    if (isRecipient) {
      // Show accept/decline banner for recipient
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.adaptivePrimaryColor.withValues(alpha: 0.1),
          border: Border(
            bottom: BorderSide(
              color: context.adaptivePrimaryColor.withValues(alpha: 0.2),
            ),
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  Icons.mark_email_unread_outlined,
                  color: context.adaptivePrimaryColor,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.wantsToMessageYou,
                    style: TextStyle(
                      color: context.adaptivePrimaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _handleDeclineRequest(conversation.id),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    child: Text(l10n.declineRequest),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleAcceptRequest(conversation.id),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.adaptivePrimaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(l10n.acceptRequest),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Sender sees nothing special - conversation looks normal
    return const SizedBox.shrink();
  }

  Future<void> _handleAcceptRequest(String conversationId) async {
    final l10n = AppLocalizations.of(context)!;
    final notifier = ref.read(messageRequestActionsProvider.notifier);
    final success = await notifier.acceptRequest(conversationId);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.requestAccepted)));
        // Refresh conversation
        ref.invalidate(conversationStreamProvider(conversationId));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorOccurred),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleDeclineRequest(String conversationId) async {
    final l10n = AppLocalizations.of(context)!;
    final notifier = ref.read(messageRequestActionsProvider.notifier);
    final success = await notifier.declineRequest(conversationId);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.requestDeclined)));
        // Go back after declining
        context.pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorOccurred),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// Tuile de la sous-barre de conversation (rayon 12, fond #F5F0E8 / #252119).
class _SubBarTile extends StatelessWidget {
  final Color bg;
  final Widget icon;
  final String label;
  final Color labelColor;
  final VoidCallback onTap;

  const _SubBarTile({
    required this.bg,
    required this.icon,
    required this.label,
    required this.labelColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              icon,
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: labelColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
