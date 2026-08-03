import 'dart:async' show unawaited;
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/verification_badge.dart';
import '../../../../core/services/auto_download_service.dart';
import '../../../../core/services/file_download_service.dart';
import '../../../../shared/widgets/app_icon.dart';
import '../../../../shared/widgets/sheet_handle.dart';
import '../../../../features/messages/domain/entities/message_entity.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../../../core/utils/user_color_utils.dart';
import '../../../../features/reports/domain/entities/report_entity.dart'
    show ReportTargetType, ContentSnapshot;
import '../../../../features/reports/presentation/widgets/report_content_modal.dart';
import '../../../../features/messages/presentation/widgets/audio_file_bubble.dart';
import 'audio_message_bubble.dart';
import '../../../../features/messages/presentation/widgets/blurhash_image.dart';
import '../../../../features/messages/presentation/widgets/data_saver_gate.dart';
import '../../../../features/messages/presentation/widgets/call_message_bubble.dart';
import '../../../../features/messages/presentation/widgets/e2ee_session_required_bubble.dart';
import '../../../../features/messages/presentation/widgets/delete_message_modal.dart';
import '../../../../features/messages/presentation/widgets/full_screen_image_viewer.dart';
import '../../../../features/messages/presentation/widgets/link_preview_bubble.dart';
import '../../../../features/messages/presentation/widgets/message_info_sheet.dart';
import '../../../../features/messages/presentation/widgets/optimized_image_bubble.dart';
import '../../../../features/messages/presentation/widgets/document_bubble.dart';
import '../../../../features/messages/presentation/widgets/video_bubble.dart';
import '../../../../features/messages/presentation/widgets/post_message_card.dart';
import '../../../../features/messages/presentation/widgets/event_message_card.dart';
import '../../../../features/messages/presentation/widgets/product_message_card.dart';
import '../../../../features/messages/presentation/widgets/location_message_bubble.dart';
import '../../../../features/stickers/presentation/widgets/sticker_bubble.dart';

/// Position of a message in a group of consecutive messages from the same sender
enum MessageGroupPosition { first, middle, last, single }

class MessageBubble extends ConsumerStatefulWidget {
  final MessageEntity message;
  final bool isMe;
  final bool showSenderInfo;
  final VoidCallback? onRetry;
  final Function(String userId)? onSenderTap;
  final String? conversationId;
  final String? currentUserId;

  // Linked bubbles support
  final MessageGroupPosition groupPosition;

  // Reply support
  final MessageEntity? replyToMessage;
  final Function(MessageEntity message)? onReply;

  // Reactions support
  final Function(MessageEntity message, String emoji)? onReact;

  // Read receipts for groups
  final List<String>? readByAvatars;

  // Scroll to replied message
  final Function(String messageId)? onScrollToMessage;

  final bool isAdmin;

  /// L'expéditeur de ce message est-il admin/modérateur du groupe ?
  /// (Affiche un badge « Admin » à côté de son nom dans les bulles de groupe.)
  final bool senderIsAdmin;

  // Forward support
  final Function(MessageEntity message)? onForward;

  // Multi-selection support
  final bool isSelectionMode;
  final bool isSelected;
  final Function(MessageEntity message)? onSelect;

  // Star support
  final Function(MessageEntity message)? onToggleStar;

  // Pin support (groupes uniquement, selon les permissions du groupe)
  final bool canPin;
  final Function(MessageEntity message)? onPin;

  /// Message déjà épinglé : le menu propose « Détacher » au lieu d'« Épingler »
  /// (le bandeau d'épinglés ne porte pas de croix).
  final bool isPinned;
  final Function(MessageEntity message)? onUnpin;

  // Edit support
  final Function(MessageEntity message, String newContent)? onEdit;

  // Call back support (for call messages)
  final VoidCallback? onCallBack;

  // Skip animation for existing messages (performance optimization)
  final bool skipAnimation;

  // Hide read/delivered status for pending requests (sender only sees "sent")
  final bool isPendingRequest;

  // Non-null for group conversations — forwarded to E2EESessionRequiredBubble
  // so it can call fetchPendingDistributions instead of preEstablishSessions.
  final String? groupId;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.showSenderInfo = false,
    this.onRetry,
    this.onSenderTap,
    this.conversationId,
    this.currentUserId,
    this.groupPosition = MessageGroupPosition.single,
    this.replyToMessage,
    this.onReply,
    this.onReact,
    this.readByAvatars,
    this.onScrollToMessage,
    this.isAdmin = false,
    this.senderIsAdmin = false,
    this.onForward,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onSelect,
    this.onToggleStar,
    this.canPin = false,
    this.onPin,
    this.isPinned = false,
    this.onUnpin,
    this.onEdit,
    this.onCallBack,
    this.skipAnimation = false,
    this.isPendingRequest = false,
    this.groupId,
  });

  @override
  ConsumerState<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends ConsumerState<MessageBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  // Swipe to reply
  double _swipeOffset = 0;
  bool _isSwipingToReply = false;

  // Reactions popup
  bool _showReactionsPopup = false;

  /// Révélateur « Autres actions » de la feuille (§27a).
  bool _moreOptionsOpen = false;

  // Cached emoji-only check (computed once)
  late final bool _cachedIsEmojiOnly;

  // Local file path for expired media (null = not downloaded or not yet checked)
  String? _cachedLocalPath;
  bool _localPathChecked = false;

  static const List<String> _quickReactions = [
    '❤️',
    '👍',
    '😂',
    '😮',
    '😢',
    '🙏',
  ];

  /// Horodatage bleu clair pour les messages envoyés (style Telegram/Signal).
  static const Color _kTimestampBlue = Color(0xFFBFD0FF);

  /// Accusé de lecture « lu » : double coche + cercle en bleu.
  static const Color _kReadReceiptBlue = Color(0xFF5B9BFF);

  // ── Bulles opaques (refonte Discussion — contraste AA) ────────────────────
  /// Bulle envoyée : `#1B5E32` (clair) / `#2D7D46` (sombre).
  static const Color _kSentBubbleLight = Color(0xFF1B5E32);
  static const Color _kSentBubbleDark = Color(0xFF2D7D46);

  /// Bulle reçue : `#FFFFFF` (clair) / `#252119` (sombre).
  static const Color _kRecvBubbleLight = Color(0xFFFFFFFF);
  static const Color _kRecvBubbleDark = Color(0xFF252119);

  // Bordure de bulle reçue : c'est la bordure du thème, pas une valeur à
  // part. Elle était figée à `#EFE7DB` / `#3D352C` — le clair était déjà
  // celui du guide de style, le sombre a depuis été resserré à `#2A241E`.

  /// Décoration opaque de la bulle (remplace le glassmorphism).
  BoxDecoration _bubbleDecoration(BuildContext context) {
    final isDark = context.isDarkMode;
    final Color bubbleColor =
        widget.isMe
            ? (isDark ? _kSentBubbleDark : _kSentBubbleLight)
            : (isDark ? _kRecvBubbleDark : _kRecvBubbleLight);
    return BoxDecoration(
      color: bubbleColor,
      borderRadius: _getBorderRadius(),
      // Bordure uniquement sur les bulles reçues (les envoyées sont pleines).
      // Pas d'ombre : la bulle est enveloppée d'un ClipRRect qui la rognerait
      // de toute façon — la définition vient de la bordure et du contraste.
      border:
          widget.isMe
              ? null
              : Border.all(color: context.borderColor, width: 1),
    );
  }

  /// Dernier message d'un groupe (ou message isolé) : porte l'horodatage.
  bool get _isLastInGroup =>
      widget.groupPosition == MessageGroupPosition.last ||
      widget.groupPosition == MessageGroupPosition.single;

  @override
  void initState() {
    super.initState();

    // Cache emoji-only check to avoid repeated regex evaluation
    _cachedIsEmojiOnly = _computeIsEmojiOnly();

    // Fire-and-forget: save media locally before the 15-day TTL expires
    unawaited(AutoDownloadService().tryDownload(widget.message));

    // For expired media, check synchronously whether a local copy exists
    if (widget.message.mediaExpired) {
      unawaited(_checkLocalPath());
    }

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    // Modern bouncy animation for message entry
    _slideAnimation = Tween<double>(
      begin: widget.isMe ? 40 : -40,
      end: 0,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCirc),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutQuart),
    );

    // Only animate new messages, skip for existing ones (performance)
    if (widget.skipAnimation) {
      _animationController.value = 1.0;
    } else {
      _animationController.forward();
    }
  }

  /// Compute emoji-only status once and cache it
  bool _computeIsEmojiOnly() {
    if (widget.message.type != MessageType.text) return false;
    if (widget.message.deletedForEveryone) return false;
    if (widget.replyToMessage != null) return false;
    return _isEmojiOnly(widget.message.content);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  BorderRadius _getBorderRadius() {
    // Rayons 18 avec coin de queue 6 (cf. handoff Discussion).
    const double largeRadius = 18;
    const double smallRadius = 6;
    const double tinyRadius = 6;

    switch (widget.groupPosition) {
      case MessageGroupPosition.first:
        return BorderRadius.only(
          topLeft: const Radius.circular(largeRadius),
          topRight: const Radius.circular(largeRadius),
          bottomLeft: Radius.circular(widget.isMe ? largeRadius : smallRadius),
          bottomRight: Radius.circular(widget.isMe ? smallRadius : largeRadius),
        );
      case MessageGroupPosition.middle:
        return BorderRadius.only(
          topLeft: Radius.circular(widget.isMe ? largeRadius : smallRadius),
          topRight: Radius.circular(widget.isMe ? smallRadius : largeRadius),
          bottomLeft: Radius.circular(widget.isMe ? largeRadius : smallRadius),
          bottomRight: Radius.circular(widget.isMe ? smallRadius : largeRadius),
        );
      case MessageGroupPosition.last:
        return BorderRadius.only(
          topLeft: Radius.circular(widget.isMe ? largeRadius : smallRadius),
          topRight: Radius.circular(widget.isMe ? smallRadius : largeRadius),
          bottomLeft: Radius.circular(widget.isMe ? largeRadius : tinyRadius),
          bottomRight: Radius.circular(widget.isMe ? tinyRadius : largeRadius),
        );
      case MessageGroupPosition.single:
        return BorderRadius.only(
          topLeft: const Radius.circular(largeRadius),
          topRight: const Radius.circular(largeRadius),
          bottomLeft: Radius.circular(widget.isMe ? largeRadius : tinyRadius),
          bottomRight: Radius.circular(widget.isMe ? tinyRadius : largeRadius),
        );
    }
  }

  double _getVerticalPadding() {
    switch (widget.groupPosition) {
      case MessageGroupPosition.first:
        return 4;
      case MessageGroupPosition.middle:
        return 2;
      case MessageGroupPosition.last:
        return 4;
      case MessageGroupPosition.single:
        return 8;
    }
  }

  /// Check if the message contains only emojis
  bool _isEmojiOnly(String text) {
    if (text.isEmpty) return false;
    // Regex to match emojis
    final emojiRegex = RegExp(
      r'^[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\u{1F600}-\u{1F64F}\u{1F680}-\u{1F6FF}\u{1F1E0}-\u{1F1FF}\u{200D}\u{FE0F}\u{20E3}\s]+$',
      unicode: true,
    );
    return emojiRegex.hasMatch(text.trim()) && text.trim().length <= 12;
  }

  /// Check if message is emoji-only text (for bubble-less display)
  /// Uses cached value for performance
  bool _isEmojiOnlyTextMessage() {
    return _cachedIsEmojiOnly;
  }

  /// Build emoji-only content without bubble
  Widget _buildEmojiOnlyContent(BuildContext context) {
    return GestureDetector(
      onLongPress: _onLongPress,
      onDoubleTap: _onDoubleTap,
      child: Column(
        crossAxisAlignment:
            widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sender name for groups
          if (widget.showSenderInfo && !widget.isMe)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: InkWell(
                onTap: () => widget.onSenderTap?.call(widget.message.senderId),
                child: Text(
                  widget.message.senderName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: UserColorUtils.getUserColor(widget.message.senderId),
                  ),
                ),
              ),
            ),
          // Large emoji
          Text(widget.message.content, style: const TextStyle(fontSize: 42)),
          // Time and status below emoji (groupage : dernier du groupe seulement)
          if (_isLastInGroup)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.currentUserId != null &&
                      widget.message.isStarredBy(widget.currentUserId!)) ...[
                    AppIcon(
                      AppIcon.star,
                      size: 12,
                      color: context.textTertiaryColor,
                    ),
                    const SizedBox(width: 2),
                  ],
                  _buildEncryptionIcon(context),
                  const SizedBox(width: 2),
                  Text(
                    _formatTime(widget.message.createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: context.textTertiaryColor,
                    ),
                  ),
                  if (widget.isMe) ...[
                    const SizedBox(width: 3),
                    _buildStatusIcon(context, inline: false),
                    _buildReadReceiptDot(),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // System messages get special treatment - no bubble, no gestures
    if (widget.message.isSystem) {
      return Center(child: _buildSystemMessageContent(context));
    }

    // Call messages get special treatment - aligned based on direction, no swipe gestures
    if (widget.message.isCall) {
      return CallMessageBubble(
        message: widget.message,
        isMe: widget.isMe,
        currentUserId: widget.currentUserId ?? '',
        onCallBack: widget.onCallBack,
      );
    }

    // Check if message is deleted for the current user
    final isDeleted =
        widget.currentUserId != null &&
        widget.message.isDeletedFor(widget.currentUserId!);

    // Don't show messages that are deleted for the current user
    if (isDeleted && !widget.message.deletedForEveryone) {
      return const SizedBox.shrink();
    }

    // Selection mode: wrap with tap-to-select and show checkbox
    if (widget.isSelectionMode) {
      return GestureDetector(
        onTap: () => widget.onSelect?.call(widget.message),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          color:
              widget.isSelected
                  ? context.adaptivePrimaryColor.withValues(alpha: 0.15)
                  : Colors.transparent,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, animation) {
                    return ScaleTransition(scale: animation, child: child);
                  },
                  child: Icon(
                    widget.isSelected
                        ? Icons.check_circle
                        : Icons.circle_outlined,
                    key: ValueKey(widget.isSelected),
                    size: 24,
                    color:
                        widget.isSelected
                            ? context.adaptivePrimaryColor
                            : context.textTertiaryColor,
                  ),
                ),
              ),
              Expanded(child: _buildMainContent(context, isDeleted)),
            ],
          ),
        ),
      );
    }

    return _buildMainContent(context, isDeleted);
  }

  Widget _buildReadReceiptDot() {
    if (!widget.isMe) return const SizedBox.shrink();
    if (widget.isPendingRequest) return const SizedBox.shrink();
    if (widget.message.status == MessageStatus.sending) {
      return const SizedBox.shrink();
    }
    if (widget.message.deletedForEveryone) return const SizedBox.shrink();

    final otherReadersCount =
        widget.message.readBy
            .where((id) => id != widget.message.senderId)
            .length;
    final isRead = otherReadersCount > 0;

    if (!isRead) return const SizedBox.shrink();

    return Container(
      width: 8,
      height: 8,
      margin: const EdgeInsets.only(left: 4),
      decoration: const BoxDecoration(
        color: _kReadReceiptBlue,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildMainContent(BuildContext context, bool isDeleted) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_slideAnimation.value, 0),
          child: Opacity(opacity: _fadeAnimation.value, child: child),
        );
      },
      child: GestureDetector(
        onHorizontalDragStart: widget.onReply != null ? _onSwipeStart : null,
        onHorizontalDragUpdate: widget.onReply != null ? _onSwipeUpdate : null,
        onHorizontalDragEnd: widget.onReply != null ? _onSwipeEnd : null,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Reply indicator
            if (_isSwipingToReply)
              Positioned(
                left: widget.isMe ? 16 : null,
                right: widget.isMe ? null : 16,
                top: 0,
                bottom: 0,
                child: Center(
                  child: AnimatedOpacity(
                    opacity: _swipeOffset.abs() > 52 ? 1 : 0.5,
                    duration: const Duration(milliseconds: 100),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: context.adaptivePrimaryColor.withValues(
                          alpha: 0.2,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.reply,
                        size: 20,
                        color: context.adaptivePrimaryColor,
                      ),
                    ),
                  ),
                ),
              ),

            // Message content
            Transform.translate(
              offset: Offset(_swipeOffset, 0),
              child: Padding(
                padding: EdgeInsets.only(
                  left: widget.isMe ? 64 : (widget.showSenderInfo ? 8 : 16),
                  right: widget.isMe ? 16 : 64,
                  top: _getVerticalPadding(),
                  bottom: _getVerticalPadding(),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Mini-avatar for group messages (non-me)
                    if (widget.showSenderInfo && !widget.isMe)
                      Padding(
                        padding: const EdgeInsets.only(right: 8, bottom: 2),
                        child: GestureDetector(
                          onTap:
                              () => widget.onSenderTap?.call(
                                widget.message.senderId,
                              ),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: UserColorUtils.getUserColor(
                                  widget.message.senderId,
                                ),
                                backgroundImage:
                                    widget.message.senderPhotoUrl != null
                                        ? CachedNetworkImageProvider(
                                          widget.message.senderPhotoUrl!,
                                        )
                                        : null,
                                child:
                                    widget.message.senderPhotoUrl == null
                                        ? Text(
                                          widget.message.senderName.isNotEmpty
                                              ? widget.message.senderName[0]
                                                  .toUpperCase()
                                              : '?',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        )
                                        : null,
                              ),
                              if (widget.message.senderIsVerified)
                                const Positioned(
                                  bottom: -2,
                                  right: -2,
                                  child: VerificationBadge(
                                    size: VerificationBadgeSize.small,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            widget.isMe
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                        children: [
                          // Reactions popup
                          if (_showReactionsPopup)
                            _buildReactionsPopup(context),

                          // Check if this is an emoji-only text message (no bubble)
                          _isEmojiOnlyTextMessage()
                              ? _buildEmojiOnlyContent(context)
                              : GestureDetector(
                                onLongPress: _onLongPress,
                                onDoubleTap: _onDoubleTap,
                                child: ClipRRect(
                                  borderRadius: _getBorderRadius(),
                                  child: Container(
                                    // Surface opaque : plus de BackdropFilter ni
                                    // de dégradé (coûteux sur entrée de gamme) —
                                    // contraste texte AA garanti.
                                    decoration: _bubbleDecoration(context),
                                    child: GestureDetector(
                                      onTap:
                                          widget.message.status ==
                                                      MessageStatus.failed &&
                                                  widget.onRetry != null
                                              ? widget.onRetry
                                              : null,
                                      child: ClipRRect(
                                        borderRadius: _getBorderRadius(),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // Forwarded label
                                            if (widget.message.isForwarded)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  left: 12,
                                                  right: 12,
                                                  top: 8,
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Transform.flip(
                                                      flipX: true,
                                                      child: Icon(
                                                        Icons.reply,
                                                        size: 16,
                                                        color:
                                                            widget.isMe
                                                                ? AppColors
                                                                    .white
                                                                    .withValues(
                                                                      alpha:
                                                                          0.6,
                                                                    )
                                                                : context
                                                                    .textTertiaryColor
                                                                    .withValues(
                                                                      alpha:
                                                                          0.8,
                                                                    ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      AppLocalizations.of(
                                                        context,
                                                      )!.forwarded,
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontStyle:
                                                            FontStyle.italic,
                                                        color:
                                                            widget.isMe
                                                                ? AppColors
                                                                    .white
                                                                    .withValues(
                                                                      alpha:
                                                                          0.6,
                                                                    )
                                                                : context
                                                                    .textTertiaryColor
                                                                    .withValues(
                                                                      alpha:
                                                                          0.8,
                                                                    ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            // Sender name inside bubble for groups
                                            if (widget.showSenderInfo &&
                                                !widget.isMe)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  left: 12,
                                                  right: 12,
                                                  top: 8,
                                                ),
                                                child: InkWell(
                                                  onTap:
                                                      () => widget.onSenderTap
                                                          ?.call(
                                                            widget
                                                                .message
                                                                .senderId,
                                                          ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        widget
                                                            .message
                                                            .senderName,
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color:
                                                              UserColorUtils.getUserColor(
                                                                widget
                                                                    .message
                                                                    .senderId,
                                                              ),
                                                        ),
                                                      ),
                                                      if (widget
                                                          .message
                                                          .senderIsVerified) ...[
                                                        const SizedBox(
                                                          width: 4,
                                                        ),
                                                        const VerificationBadge(
                                                          size:
                                                              VerificationBadgeSize
                                                                  .small,
                                                        ),
                                                      ],
                                                      if (widget
                                                          .senderIsAdmin) ...[
                                                        const SizedBox(
                                                          width: 6,
                                                        ),
                                                        _buildAdminBadge(
                                                          context,
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            // Reply preview
                                            if (widget.replyToMessage != null)
                                              _buildReplyPreview(context),

                                            // Message content
                                            widget.message.deletedForEveryone
                                                ? _buildDeletedContent(context)
                                                : _buildContent(context),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                          // Reactions display
                          if (widget.message.reactions.isNotEmpty)
                            _buildReactionsDisplay(
                              context,
                              widget.message.reactions,
                            ),

                          // Read avatars for groups
                          if (widget.readByAvatars?.isNotEmpty == true &&
                              widget.isMe)
                            _buildReadAvatars(context),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onSwipeStart(DragStartDetails details) {
    setState(() {
      _isSwipingToReply = true;
    });
  }

  void _onSwipeUpdate(DragUpdateDetails details) {
    final newOffset = _swipeOffset + details.delta.dx;

    // Only allow swipe in the correct direction, borné à 90 px.
    if (widget.isMe) {
      // Swipe left for "isMe" messages
      if (newOffset <= 0 && newOffset >= -90) {
        setState(() {
          _swipeOffset = newOffset;
        });
      }
    } else {
      // Swipe right for other's messages
      if (newOffset >= 0 && newOffset <= 90) {
        setState(() {
          _swipeOffset = newOffset;
        });
      }
    }

    // Haptic feedback au franchissement du seuil (52 px).
    if (_swipeOffset.abs() > 52 && _swipeOffset.abs() < 57) {
      HapticFeedback.lightImpact();
    }
  }

  void _onSwipeEnd(DragEndDetails details) {
    if (_swipeOffset.abs() > 52) {
      // Trigger reply
      HapticFeedback.mediumImpact();
      widget.onReply?.call(widget.message);
    }

    setState(() {
      _swipeOffset = 0;
      _isSwipingToReply = false;
    });
  }


  /// Rangée de réactions rapides de la feuille d'actions (§27a).
  ///
  /// Un émoji déjà posé sur le message est mis en avant.
  ///
  /// `MessageEntity.reactions` est une simple `List<String>` sans auteur :
  /// on peut donc dire « cette réaction est présente », mais pas
  /// « c'est la mienne ». Tant que le modèle ne porte pas l'auteur, la
  /// pastille ne le prétend pas.
  Widget _buildQuickReactions(BuildContext sheetContext) {
    const emojis = ['\u{1F44D}', '\u{2764}\u{FE0F}', '\u{1F602}',
        '\u{1F64F}', '\u{1F62E}'];
    final posees = widget.message.reactions.toSet();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final emoji in emojis)
          _QuickReactionButton(
            emoji: emoji,
            selected: posees.contains(emoji),
            onTap: () {
              Navigator.pop(sheetContext);
              HapticFeedback.lightImpact();
              widget.onReact?.call(widget.message, emoji);
            },
          ),
        // Ouvre le sélecteur complet.
        _QuickReactionButton(
          icon: Icons.add,
          onTap: () {
            Navigator.pop(sheetContext);
            setState(() {
              _showReactionsPopup = true;
            });
          },
        ),
      ],
    );
  }

  void _onLongPress() {
    HapticFeedback.mediumImpact();
    // Unfocus any text field to prevent keyboard from appearing after modal closes
    FocusScope.of(context).unfocus();
    _showOptionsModal(context);
  }

  void _onDoubleTap() {
    // debugPrint('👆 Double-tap detected on message: ${widget.message.id}');
    if (widget.onReact != null) {
      HapticFeedback.lightImpact();
      // debugPrint('❤️ Calling onReact with heart emoji');
      widget.onReact?.call(widget.message, '❤️');
    } else {
      // debugPrint('⚠️ onReact callback is null!');
    }
  }

  Widget _buildReactionsPopup(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children:
            _quickReactions.map((emoji) {
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  widget.onReact?.call(widget.message, emoji);
                  setState(() {
                    _showReactionsPopup = false;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(emoji, style: const TextStyle(fontSize: 24)),
                ),
              );
            }).toList(),
      ),
    );
  }

  // Reactions display widget - ready for future use when MessageEntity supports reactions
  Widget _buildReactionsDisplay(BuildContext context, List<String> reactions) {
    final reactionCounts = <String, int>{};
    for (final reaction in reactions) {
      reactionCounts[reaction] = (reactionCounts[reaction] ?? 0) + 1;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 4,
        children:
            reactionCounts.entries.map((entry) {
              // Re-tap sur une réaction = toggle → retire l'emoji déjà posé.
              return GestureDetector(
                onTap:
                    widget.onReact == null
                        ? null
                        : () {
                          HapticFeedback.lightImpact();
                          widget.onReact?.call(widget.message, entry.key);
                        },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: context.surfaceVariantColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: context.outlineColor.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(entry.key, style: const TextStyle(fontSize: 14)),
                      if (entry.value > 1) ...[
                        const SizedBox(width: 4),
                        Text(
                          '${entry.value}',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.textSecondaryColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }

  /// Petit badge « Admin » affiché à côté du nom de l'expéditeur (groupes).
  Widget _buildAdminBadge(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: context.adaptivePrimaryColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(AppIcon.star, size: 9, color: context.adaptivePrimaryColor),
          const SizedBox(width: 3),
          Text(
            'Admin',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: context.adaptivePrimaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadAvatars(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, right: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children:
            (widget.readByAvatars ?? const []).take(3).map((avatarUrl) {
              return Container(
                margin: const EdgeInsets.only(left: 2),
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: context.surfaceColor, width: 1),
                  image:
                      avatarUrl.isNotEmpty
                          ? DecorationImage(
                            image: NetworkImage(avatarUrl),
                            fit: BoxFit.cover,
                          )
                          : null,
                  color:
                      avatarUrl.isEmpty
                          ? context.adaptivePrimaryColor.withValues(alpha: 0.3)
                          : null,
                ),
                child:
                    avatarUrl.isEmpty
                        ? AppIcon(
                          AppIcon.person,
                          size: 10,
                          color: context.adaptivePrimaryColor,
                        )
                        : null,
              );
            }).toList(),
      ),
    );
  }

  bool _canShowDeleteOption() {
    return widget.conversationId != null &&
        widget.currentUserId != null &&
        !widget.message.deletedForEveryone &&
        widget.message.status != MessageStatus.sending;
  }

  /// Ouvre la feuille d'actions (§27a).
  ///
  /// Cinq entrées visibles, les autres derrière « Autres actions » : la
  /// maquette impose la brièveté, mais épingler, modifier, enregistrer et
  /// signaler restent des fonctions réelles qu'on ne fait pas disparaître.
  void _showOptionsModal(BuildContext context) {
    _moreOptionsOpen = false;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (_, setSheetState) {
          final secondaires = _secondaryOptionRows(ctx);
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SheetHandle(),
                  const SizedBox(height: 16),

                  // Réactions rapides : cinq émojis d'un geste, le « + »
                  // ouvre le sélecteur complet. Remplace l'ancienne ligne
                  // « Réagir », qui demandait un écran de plus.
                  if (widget.onReact != null) ...[
                    _buildQuickReactions(ctx),
                    const SizedBox(height: 8),
                    Divider(height: 1, color: context.dividerColor),
                    const SizedBox(height: 8),
                  ] else
                    const SizedBox(height: 4),

                  ..._primaryOptionRows(ctx),

                  if (secondaires.isNotEmpty) ...[
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: context.borderColor,
                    ),
                    if (!_moreOptionsOpen)
                      ListTile(
                        leading: Icon(
                          Icons.more_horiz,
                          color: context.textSecondaryColor,
                        ),
                        title: Text(
                          AppLocalizations.of(context)!.moreActions,
                          style: TextStyle(color: context.textSecondaryColor),
                        ),
                        onTap: () =>
                            setSheetState(() => _moreOptionsOpen = true),
                      )
                    else
                      ...secondaires,
                  ],

                  SizedBox(height: MediaQuery.of(ctx).padding.bottom),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Les cinq entrées de la maquette, dans son ordre.
  List<Widget> _primaryOptionRows(BuildContext ctx) {
    final l10n = AppLocalizations.of(context)!;
    return [
      if (widget.onReply != null)
        ListTile(
          leading: Icon(Icons.reply, color: context.textPrimaryColor),
          title: Text(
            l10n.reply,
            style: TextStyle(color: context.textPrimaryColor),
          ),
          onTap: () {
            Navigator.pop(ctx);
            widget.onReply?.call(widget.message);
          },
        ),

      if (widget.message.type == MessageType.text)
        ListTile(
          leading: Icon(Icons.copy, color: context.textPrimaryColor),
          title: Text(
            l10n.copy,
            style: TextStyle(color: context.textPrimaryColor),
          ),
          onTap: () {
            Navigator.pop(ctx);
            Clipboard.setData(ClipboardData(text: widget.message.content));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.messageCopied),
                backgroundColor: context.adaptivePrimaryColor,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 1),
              ),
            );
          },
        ),

      if (!widget.message.deletedForEveryone)
        ListTile(
          leading: Icon(Icons.shortcut, color: context.textPrimaryColor),
          title: Text(
            l10n.forwardTo,
            style: TextStyle(color: context.textPrimaryColor),
          ),
          onTap: () {
            Navigator.pop(ctx);
            widget.onForward?.call(widget.message);
          },
        ),

      if (widget.onToggleStar != null && !widget.message.deletedForEveryone)
        Builder(
          builder: (_) {
            final isStarred = widget.currentUserId != null &&
                widget.message.isStarredBy(widget.currentUserId!);
            return ListTile(
              leading: isStarred
                  ? const AppIcon(AppIcon.star, color: Colors.amber)
                  : AppIcon(
                      AppIcon.starBorder,
                      color: context.textPrimaryColor,
                    ),
              title: Text(
                isStarred ? l10n.unstarMessage : l10n.starMessage,
                style: TextStyle(color: context.textPrimaryColor),
              ),
              onTap: () {
                Navigator.pop(ctx);
                widget.onToggleStar?.call(widget.message);
              },
            );
          },
        ),

      // Action destructive isolée par un filet.
      if (_canShowDeleteOption()) ...[
        Divider(
          height: 1,
          indent: 16,
          endIndent: 16,
          color: context.borderColor,
        ),
        ListTile(
          leading: AppIcon(AppIcon.delete, color: context.errorColor),
          title: Text(
            l10n.delete,
            style: TextStyle(color: context.errorColor),
          ),
          onTap: () {
            Navigator.pop(ctx);
            _showDeleteModal(context);
          },
        ),
      ],
    ];
  }

  /// Ce que la maquette ne montre pas mais que l'app sait faire.
  List<Widget> _secondaryOptionRows(BuildContext ctx) {
    final l10n = AppLocalizations.of(context)!;
    return [
      if (widget.isMe &&
          !widget.message.deletedForEveryone &&
          widget.conversationId != null)
        ListTile(
          leading: AppIcon(AppIcon.info, color: context.textPrimaryColor),
          title: Text(
            l10n.messageInfoTitle,
            style: TextStyle(color: context.textPrimaryColor),
          ),
          onTap: () {
            Navigator.pop(ctx);
            _showMessageInfoSheet(context);
          },
        ),

      if (widget.canPin && !widget.message.deletedForEveryone)
        if (widget.isPinned && widget.onUnpin != null)
          ListTile(
            leading: AppIcon(
              AppIcon.pin,
              size: 20,
              color: context.textPrimaryColor,
            ),
            title: Text(
              l10n.unpin,
              style: TextStyle(color: context.textPrimaryColor),
            ),
            onTap: () {
              Navigator.pop(ctx);
              widget.onUnpin?.call(widget.message);
            },
          )
        else if (!widget.isPinned && widget.onPin != null)
          ListTile(
            leading: AppIcon(
              AppIcon.pin,
              size: 20,
              color: context.textPrimaryColor,
            ),
            title: Text(
              l10n.pin,
              style: TextStyle(color: context.textPrimaryColor),
            ),
            onTap: () {
              Navigator.pop(ctx);
              widget.onPin?.call(widget.message);
            },
          ),

      if (!widget.message.deletedForEveryone &&
          widget.message.fileUrl != null &&
          (widget.message.type == MessageType.image ||
              widget.message.type == MessageType.video))
        ListTile(
          leading: Icon(
            Icons.download_rounded,
            color: context.textPrimaryColor,
          ),
          title: Text(
            l10n.save,
            style: TextStyle(color: context.textPrimaryColor),
          ),
          onTap: () {
            Navigator.pop(ctx);
            if (widget.message.type == MessageType.image) {
              _saveImageToGallery(widget.message.fileUrl!);
            } else {
              _saveVideoToDevice(widget.message.fileUrl!);
            }
          },
        ),

      if (!widget.message.deletedForEveryone &&
          (widget.message.type == MessageType.text ||
              widget.message.type == MessageType.image ||
              widget.message.type == MessageType.video ||
              widget.message.type == MessageType.file))
        ListTile(
          leading: AppIcon(AppIcon.share, color: context.textPrimaryColor),
          title: Text(
            l10n.share,
            style: TextStyle(color: context.textPrimaryColor),
          ),
          onTap: () {
            Navigator.pop(ctx);
            _shareMessage();
          },
        ),

      if (widget.onSelect != null)
        ListTile(
          leading: AppIcon(
            AppIcon.checkCircle,
            color: context.textPrimaryColor,
          ),
          title: Text(
            l10n.select,
            style: TextStyle(color: context.textPrimaryColor),
          ),
          onTap: () {
            Navigator.pop(ctx);
            widget.onSelect?.call(widget.message);
          },
        ),

      if (widget.isMe &&
          widget.message.type == MessageType.text &&
          !widget.message.deletedForEveryone &&
          widget.onEdit != null &&
          widget.currentUserId != null &&
          widget.message.canEdit(widget.currentUserId!))
        ListTile(
          leading: Icon(Icons.edit_outlined, color: context.textPrimaryColor),
          title: Text(
            l10n.edit,
            style: TextStyle(color: context.textPrimaryColor),
          ),
          onTap: () {
            Navigator.pop(ctx);
            _showEditDialog(context);
          },
        ),

      // Signaler reste accessible : c'est le recours d'une personne
      // harcelée, il ne disparaît pas d'un écran.
      if (!widget.isMe && !widget.message.deletedForEveryone)
        ListTile(
          leading: AppIcon(AppIcon.flag, color: context.warningColor),
          title: Text(
            l10n.report,
            style: TextStyle(color: context.warningColor),
          ),
          onTap: () {
            Navigator.pop(ctx);
            final snapshot = _createMessageSnapshot();
            ReportContentModal.show(
              context,
              targetType: ReportTargetType.message,
              targetId: widget.message.id,
              targetName: widget.message.senderName,
              targetPreview: widget.message.type == MessageType.text
                  ? widget.message.content
                  : null,
              conversationId: widget.conversationId,
              contentSnapshot: snapshot,
              reportedUserId: widget.message.senderId,
            );
          },
        ),
    ];
  }

  void _showMessageInfoSheet(BuildContext context) {
    final conversationId = widget.conversationId;
    if (conversationId == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => MessageInfoSheet(
            message: widget.message,
            conversationId: conversationId,
            currentUserId: widget.currentUserId,
          ),
    );
  }

  void _showDeleteModal(BuildContext context) {
    final conversationId = widget.conversationId;
    final currentUserId = widget.currentUserId;
    if (conversationId == null || currentUserId == null) return;

    DeleteMessageModal.show(
      context,
      message: widget.message,
      conversationId: conversationId,
      currentUserId: currentUserId,
      isAdmin: widget.isAdmin,
    );
  }

  void _showEditDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textController = TextEditingController(text: widget.message.content);

    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(l10n.editMessage),
            content: TextField(
              controller: textController,
              maxLines: 5,
              minLines: 1,
              autofocus: true,
              decoration: InputDecoration(
                hintText: l10n.editMessage,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () {
                  final newContent = textController.text.trim();
                  if (newContent.isNotEmpty &&
                      newContent != widget.message.content) {
                    widget.onEdit?.call(widget.message, newContent);
                  }
                  Navigator.pop(ctx);
                },
                child: Text(l10n.save),
              ),
            ],
          ),
    );
  }

  /// Crée un snapshot du message pour préserver le contenu signalé
  ContentSnapshot _createMessageSnapshot() {
    final message = widget.message;

    switch (message.type) {
      case MessageType.text:
        return ReportContentModal.textMessageSnapshot(message.content);

      case MessageType.image:
        return ReportContentModal.imageSnapshot(
          message.fileUrl ?? '',
          caption:
              message.content.isNotEmpty && message.content != message.fileName
                  ? message.content
                  : null,
        );

      case MessageType.video:
        return ReportContentModal.videoSnapshot(
          message.fileUrl ?? '',
          caption: message.content.isNotEmpty ? message.content : null,
        );

      case MessageType.audio:
      case MessageType.voiceNote:
      case MessageType.file:
        return ReportContentModal.fileSnapshot(
          message.fileUrl ?? '',
          message.fileName ?? 'Fichier',
        );

      case MessageType.system:
        return ReportContentModal.textMessageSnapshot(message.content);
      case MessageType.call:
        final l10n = AppLocalizations.of(context)!;
        return ReportContentModal.textMessageSnapshot(
          '${l10n.call} ${message.callType == 'video' ? l10n.video : l10n.audio}',
        );
      case MessageType.location:
        final l10n = AppLocalizations.of(context)!;
        return ReportContentModal.textMessageSnapshot(
          '${l10n.location}: ${message.locationAddress ?? l10n.sharedLocation}',
        );
      case MessageType.sticker:
        return ReportContentModal.imageSnapshot(message.fileUrl ?? '');
    }
  }

  Widget _buildDeletedContent(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.block,
            size: 16,
            color:
                widget.isMe
                    ? AppColors.white.withValues(alpha: 0.7)
                    : context.textTertiaryColor,
          ),
          const SizedBox(width: 8),
          Text(
            l10n.messageDeleted,
            style: TextStyle(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color:
                  widget.isMe
                      ? AppColors.white.withValues(alpha: 0.7)
                      : context.textTertiaryColor,
            ),
          ),
        ],
      ),
    );
  }

  // Greyscale + alpha-reduced color matrix for expired media ghost effect
  static const ColorFilter _greyFilter = ColorFilter.matrix([
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0,
    0,
    0,
    0.55,
    0,
  ]);

  Widget _buildExpiredBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_clock, color: Colors.white70, size: 12),
          SizedBox(width: 3),
          Text('Expiré', style: TextStyle(color: Colors.white70, fontSize: 10)),
        ],
      ),
    );
  }

  /// Ghost of an image or video — shows the blurhash faded with a dark veil.
  Widget _buildExpiredVisualGhost() {
    final message = widget.message;
    final blurhash = message.blurhash;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 200,
        height: 150,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Ghost background: blurhash if available, grey otherwise
            if (blurhash != null && blurhash.isNotEmpty)
              BlurhashImage(blurhash: blurhash, fit: BoxFit.cover)
            else
              ColoredBox(color: Colors.grey.shade400),
            // Dark veil
            ColoredBox(color: Colors.black.withValues(alpha: 0.55)),
            // Centred icon + label
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  message.type == MessageType.video
                      ? Icons.videocam_off_rounded
                      : Icons.image_not_supported_rounded,
                  color: Colors.white60,
                  size: 32,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Média expiré',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpiredMediaPlaceholder(BuildContext context) {
    // _cachedLocalPath is set by _checkLocalPath() called in initState.
    // Shows ghost immediately, then switches to local media with a single
    // setState — no FutureBuilder re-build cycle, no null assertion needed.
    if (_localPathChecked && _cachedLocalPath != null) {
      return _buildLocalMediaWidget(_cachedLocalPath!);
    }
    return _buildExpiredGhost();
  }

  /// Renders the media from a local file when the Storage URL has expired.
  Widget _buildLocalMediaWidget(String localPath) {
    final message = widget.message;
    final file = File(localPath);

    switch (message.type) {
      case MessageType.image:
        return Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                file,
                width: 200,
                height: 150,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildExpiredGhost(),
              ),
            ),
            Positioned(top: 4, right: 4, child: _buildLocalBadge()),
          ],
        );

      case MessageType.voiceNote:
        // Pass a file:// URI so just_audio can play from local storage.
        // Reset mediaExpired so the bubble renders and plays normally.
        final localEntity = message.copyWith(
          fileUrl: 'file://$localPath',
          mediaExpired: false,
        );
        return Stack(
          children: [
            AudioMessageBubble(message: localEntity, isMe: widget.isMe),
            Positioned(top: 4, right: 4, child: _buildLocalBadge()),
          ],
        );

      case MessageType.audio:
        // Audio file picked from device: render the compact player from local storage.
        final localEntity = message.copyWith(
          fileUrl: 'file://$localPath',
          mediaExpired: false,
        );
        return Stack(
          children: [
            AudioFileBubble(message: localEntity, isMe: widget.isMe),
            Positioned(top: 4, right: 4, child: _buildLocalBadge()),
          ],
        );

      case MessageType.video:
      case MessageType.file:
        // Show the greyed card but with a local badge; user can open from device
        return Stack(
          children: [
            ColorFiltered(
              colorFilter: _greyFilter,
              child: IgnorePointer(
                child: DocumentBubble(
                  fileUrl: '',
                  fileName: message.fileName ?? 'Fichier',
                  fileSize: message.fileSize,
                  isMe: widget.isMe,
                  timestamp: message.createdAt,
                  messageStatus: message.status,
                  readBy: message.readBy,
                  deliveredTo: message.deliveredTo,
                ),
              ),
            ),
            Positioned(top: 4, right: 4, child: _buildLocalBadge()),
          ],
        );

      default:
        return _buildExpiredGhost();
    }
  }

  Widget _buildLocalBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.phone_android, color: Colors.white70, size: 12),
          SizedBox(width: 3),
          Text('Local', style: TextStyle(color: Colors.white70, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildExpiredGhost() {
    final message = widget.message;

    switch (message.type) {
      case MessageType.image:
      case MessageType.video:
        return _buildExpiredVisualGhost();

      case MessageType.voiceNote:
        return Stack(
          children: [
            ColorFiltered(
              colorFilter: _greyFilter,
              child: IgnorePointer(
                child: AudioMessageBubble(message: message, isMe: widget.isMe),
              ),
            ),
            Positioned(top: 4, right: 4, child: _buildExpiredBadge()),
          ],
        );

      case MessageType.audio:
        return Stack(
          children: [
            ColorFiltered(
              colorFilter: _greyFilter,
              child: IgnorePointer(
                child: AudioFileBubble(message: message, isMe: widget.isMe),
              ),
            ),
            Positioned(top: 4, right: 4, child: _buildExpiredBadge()),
          ],
        );

      case MessageType.file:
        return Stack(
          children: [
            ColorFiltered(
              colorFilter: _greyFilter,
              child: IgnorePointer(
                child: DocumentBubble(
                  fileUrl: '',
                  fileName: message.fileName ?? 'Fichier',
                  fileSize: message.fileSize,
                  isMe: widget.isMe,
                  timestamp: message.createdAt,
                  messageStatus: message.status,
                  readBy: message.readBy,
                  deliveredTo: message.deliveredTo,
                ),
              ),
            ),
            Positioned(top: 4, right: 4, child: _buildExpiredBadge()),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildContent(BuildContext context) {
    // Show expired placeholder for any media type whose Storage file was deleted
    if (widget.message.mediaExpired &&
        (widget.message.type == MessageType.image ||
            widget.message.type == MessageType.video ||
            widget.message.type == MessageType.audio ||
            widget.message.type == MessageType.voiceNote ||
            widget.message.type == MessageType.file)) {
      return _buildExpiredMediaPlaceholder(context);
    }

    switch (widget.message.type) {
      case MessageType.image:
        return DataSaverGate(
          messageId: widget.message.id,
          isMe: widget.isMe,
          blurhash: widget.message.blurhash,
          fileSize: widget.message.fileSize,
          builder: (context) => OptimizedImageBubble(
          imageUrl: widget.message.fileUrl ?? '',
          caption:
              widget.message.content == widget.message.fileName ||
                      widget.message.content == widget.message.fileUrl ||
                      widget.message.content.isEmpty
                  ? null
                  : widget.message.content,
          isMe: widget.isMe,
          heroTag: 'message_image_${widget.message.id}',
          timestamp: widget.message.createdAt,
          messageStatus: widget.message.status,
          readBy: widget.message.readBy,
          deliveredTo: widget.message.deliveredTo,
          showSenderInfo: widget.showSenderInfo && !widget.isMe,
          senderName: widget.message.senderName,
          blurhash: widget.message.blurhash,
          onTap:
              () => FullScreenImageViewer.show(
                context,
                imageUrl: widget.message.fileUrl!,
                heroTag: 'message_image_${widget.message.id}',
                senderName: widget.message.senderName,
                sentAt: widget.message.createdAt,
                messageId: widget.message.id,
              ),
          onSave: () => _saveImageToGallery(widget.message.fileUrl!),
          onShare: () => _shareMessage(),
          // Appui long = menu complet (permet d'épingler une photo, etc.).
          onLongPress: _onLongPress,
          ),
        );

      case MessageType.file:
        return DocumentBubble(
          fileUrl: widget.message.fileUrl ?? '',
          fileName: widget.message.fileName ?? 'Fichier',
          fileSize: widget.message.fileSize,
          isMe: widget.isMe,
          timestamp: widget.message.createdAt,
          messageStatus: widget.message.status,
          readBy: widget.message.readBy,
          deliveredTo: widget.message.deliveredTo,
          onTap: () => _openFile(widget.message.fileUrl),
          onShare: () => _shareMessage(),
        );

      case MessageType.video:
        return DataSaverGate(
          messageId: widget.message.id,
          isMe: widget.isMe,
          blurhash: widget.message.blurhash,
          fileSize: widget.message.fileSize,
          builder: (context) => VideoBubble(
          videoUrl: widget.message.fileUrl ?? '',
          thumbnailUrl: widget.message.thumbnailUrl,
          duration: widget.message.videoDuration,
          caption:
              widget.message.content == widget.message.fileName ||
                      widget.message.content == widget.message.fileUrl ||
                      widget.message.content.isEmpty
                  ? null
                  : widget.message.content,
          isMe: widget.isMe,
          timestamp: widget.message.createdAt,
          messageStatus: widget.message.status,
          readBy: widget.message.readBy,
          deliveredTo: widget.message.deliveredTo,
          showSenderInfo: widget.showSenderInfo && !widget.isMe,
          senderName: widget.message.senderName,
          messageId: widget.message.id,
          blurhash: widget.message.blurhash,
          onForward:
              widget.onForward != null
                  ? () => widget.onForward?.call(widget.message)
                  : null,
          onSave:
              widget.message.fileUrl != null
                  ? () => _saveVideoToDevice(widget.message.fileUrl!)
                  : null,
          onShare: () => _shareMessage(),
          // Appui long = menu complet (permet d'épingler une vidéo, etc.).
          onLongPress: _onLongPress,
          ),
        );

      case MessageType.audio:
        return AudioFileBubble(message: widget.message, isMe: widget.isMe);

      case MessageType.voiceNote:
        return AudioMessageBubble(message: widget.message, isMe: widget.isMe);

      case MessageType.text:
        return _buildTextContent(context);

      case MessageType.system:
        return _buildSystemMessageContent(context);
      case MessageType.call:
        return CallMessageBubble(
          message: widget.message,
          isMe: widget.isMe,
          currentUserId: widget.currentUserId ?? '',
          onCallBack: widget.onCallBack,
        );

      case MessageType.location:
        return LocationMessageBubble(
          latitude: widget.message.latitude ?? 0,
          longitude: widget.message.longitude ?? 0,
          address: widget.message.locationAddress ?? '',
          isMe: widget.isMe,
          createdAt: widget.message.createdAt,
          status: widget.message.status,
          readBy: widget.message.readBy,
          deliveredTo: widget.message.deliveredTo,
          senderId: widget.message.senderId,
          onRetry: widget.onRetry,
        );

      case MessageType.sticker:
        return StickerBubble(
          stickerUrl: widget.message.fileUrl ?? '',
          isAnimated: widget.message.isAnimatedSticker,
          isMe: widget.isMe,
          timestamp: widget.message.createdAt,
          messageStatus: widget.message.status,
          readBy: widget.message.readBy,
          deliveredTo: widget.message.deliveredTo,
          onLongPress: _onLongPress,
        );
    }
  }

  Widget _buildReplyPreview(BuildContext context) {
    final reply = widget.replyToMessage;
    if (reply == null) return const SizedBox.shrink();
    final isMe = widget.isMe;
    final isDarkMode = context.isDarkMode;
    final l10n = AppLocalizations.of(context)!;

    // Show "You" if the reply is from the current user
    final isReplyFromMe =
        widget.currentUserId != null && reply.senderId == widget.currentUserId;
    final replyAuthorName = isReplyFromMe ? l10n.you : reply.senderName;

    return GestureDetector(
      onTap: () {
        // Scroll to original message - callback to parent
        widget.onScrollToMessage?.call(reply.id);
      },
      child: Container(
        margin: const EdgeInsets.only(left: 8, right: 8, top: 8, bottom: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color:
              isMe
                  ? Colors.white.withValues(alpha: 0.25)
                  : isDarkMode
                  ? Colors.black.withValues(alpha: 0.35)
                  : Colors.black.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border(
            left: BorderSide(
              color: isMe ? AppColors.white : context.adaptivePrimaryColor,
              width: 4,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              replyAuthorName,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isMe ? AppColors.white : context.adaptivePrimaryColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (reply.type != MessageType.text) ...[
                  Icon(
                    _getMediaIcon(reply.type),
                    size: 14,
                    color:
                        isMe
                            ? AppColors.white.withValues(alpha: 0.8)
                            : context.textSecondaryColor,
                  ),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(
                    reply.type == MessageType.text
                        ? reply.content
                        : _getMediaTypeLabel(reply.type),
                    style: TextStyle(
                      fontSize: 13,
                      color:
                          isMe
                              ? AppColors.white.withValues(alpha: 0.85)
                              : context.textSecondaryColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getMediaIcon(MessageType type) {
    switch (type) {
      case MessageType.image:
        return Icons.image;
      case MessageType.video:
        return Icons.videocam;
      case MessageType.voiceNote:
        return Icons.mic;
      case MessageType.audio:
        return Icons.audiotrack;
      case MessageType.file:
        return Icons.insert_drive_file;
      case MessageType.location:
        return Icons.location_on;
      case MessageType.sticker:
        return Icons.emoji_emotions;
      default:
        return Icons.chat_bubble;
    }
  }

  static final _urlRegex = RegExp(
    r'(?:https?://|www\.)[^\s<>\]\)]+|(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+(?:com|fr|org|net|io|co|app|dev|info|biz|edu|gov|me|tv|uk|de|nl|be|ch|ca|au|nz|ng|sn|ml|bf|ci|tg|bj|ne|gn|cm|cd|cg|ga|td|cf|rw|bi|ug|ke|tz|et|gh|za|ma|dz|tn|eg|ly|sd|mu|mg|mw|zm|zw|mz|ao|na|bw|sz|ls|so|dj|er|ss)(?:/[^\s<>\]\)]*)?',
    caseSensitive: false,
  );

  // Phone number regex supporting international and African formats
  // +227 XX XX XX XX, 00227 XX XX XX XX, 227 XX XX XX XX, local formats
  static final _phoneRegex = RegExp(
    r'(?:\+|00)?(?:227|226|225|224|223|222|221|220|234|233|231|230|229|228|237|236|235|241|240|243|242|244|245|250|251|252|253|254|255|256|257|258|260|261|262|263|264|265|266|267|268|269|27|20|212|213|216|218|1|33|44|49|34|39|31|32|41)?[-.\s]?\(?\d{2,3}\)?[-.\s]?\d{2}[-.\s]?\d{2}[-.\s]?\d{2}[-.\s]?\d{0,2}',
  );

  // Email regex
  static final _emailRegex = RegExp(
    r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
    caseSensitive: false,
  );

  // Rich text formatting regex: *bold*, _italic_, ~strikethrough~, `code`
  static final _richTextRegex = RegExp(
    r'(\*[^*\n]+\*)|(_[^_\n]+_)|(~[^~\n]+~)|(`[^`\n]+`)',
  );

  /// Build a RichText widget with clickable URLs, phone numbers, and emails
  Widget _buildRichTextWithLinks(BuildContext context, String text) {
    // Collect all matches: URLs, phone numbers, and emails
    final allMatches = <_LinkMatch>[];

    // URLs
    for (final match in _urlRegex.allMatches(text)) {
      allMatches.add(
        _LinkMatch(
          start: match.start,
          end: match.end,
          text: match.group(0)!,
          type: _LinkType.url,
        ),
      );
    }

    // Phone numbers
    for (final match in _phoneRegex.allMatches(text)) {
      final phoneText = match.group(0)!;
      // Only include if it has at least 8 digits (valid phone number)
      final digits = phoneText.replaceAll(RegExp(r'\D'), '');
      if (digits.length >= 8) {
        // Check for overlap with existing matches
        final hasOverlap = allMatches.any(
          (m) =>
              (match.start >= m.start && match.start < m.end) ||
              (match.end > m.start && match.end <= m.end) ||
              (match.start <= m.start && match.end >= m.end),
        );
        if (!hasOverlap) {
          allMatches.add(
            _LinkMatch(
              start: match.start,
              end: match.end,
              text: phoneText,
              type: _LinkType.phone,
            ),
          );
        }
      }
    }

    // Emails
    for (final match in _emailRegex.allMatches(text)) {
      final hasOverlap = allMatches.any(
        (m) =>
            (match.start >= m.start && match.start < m.end) ||
            (match.end > m.start && match.end <= m.end) ||
            (match.start <= m.start && match.end >= m.end),
      );
      if (!hasOverlap) {
        allMatches.add(
          _LinkMatch(
            start: match.start,
            end: match.end,
            text: match.group(0)!,
            type: _LinkType.email,
          ),
        );
      }
    }

    // Mentions — highlight @Name for each confirmed mentioned user
    final mentionedUsers = widget.message.mentionedUsers;
    if (mentionedUsers.isNotEmpty) {
      final mentionPattern = RegExp(
        mentionedUsers.map((m) => RegExp.escape('@${m.name}')).join('|'),
      );
      for (final match in mentionPattern.allMatches(text)) {
        final hasOverlap = allMatches.any(
          (m) =>
              (match.start >= m.start && match.start < m.end) ||
              (match.end > m.start && match.end <= m.end) ||
              (match.start <= m.start && match.end >= m.end),
        );
        if (!hasOverlap) {
          allMatches.add(
            _LinkMatch(
              start: match.start,
              end: match.end,
              text: match.group(0)!,
              type: _LinkType.mention,
            ),
          );
        }
      }
    }

    final baseStyle = TextStyle(
      fontSize: 15,
      color: widget.isMe ? AppColors.white : context.textPrimaryColor,
    );

    if (allMatches.isEmpty) {
      // No links, but may have rich text formatting.
      // Text.rich (non-sélectionnable) plutôt que SelectableText : la
      // sélection de texte native captait l'appui long avant le
      // GestureDetector de la bulle, affichant le menu OS (Copier / Partager
      // / Tout sélectionner) au lieu du menu contextuel façon Signal.
      final richSpans = _parseRichText(text, baseStyle);
      return Text.rich(TextSpan(children: richSpans));
    }

    // Sort matches by start position
    allMatches.sort((a, b) => a.start.compareTo(b.start));

    final spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final match in allMatches) {
      // Text before this match (may contain rich text formatting)
      if (match.start > lastEnd) {
        final plainText = text.substring(lastEnd, match.start);
        spans.addAll(_parseRichText(plainText, baseStyle));
      }

      // The link/mention itself
      if (match.type == _LinkType.mention) {
        spans.add(
          TextSpan(
            text: match.text,
            style: TextStyle(
              fontSize: 15,
              color:
                  widget.isMe
                      ? Colors.white
                      : Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      } else {
        final linkColor =
            match.type == _LinkType.phone
                ? (widget.isMe ? Colors.greenAccent : Colors.green)
                : (widget.isMe ? Colors.lightBlueAccent : Colors.blue);

        spans.add(
          TextSpan(
            text: match.text,
            style: TextStyle(
              fontSize: 15,
              color: linkColor,
              decoration: TextDecoration.underline,
              decorationColor: linkColor,
            ),
            recognizer:
                TapGestureRecognizer()..onTap = () => _handleLinkTap(match),
          ),
        );
      }

      lastEnd = match.end;
    }

    // Remaining text after last match (may contain rich text formatting)
    if (lastEnd < text.length) {
      final remainingText = text.substring(lastEnd);
      spans.addAll(_parseRichText(remainingText, baseStyle));
    }

    return Text.rich(TextSpan(children: spans));
  }

  /// Parse text for rich formatting: *bold*, _italic_, ~strikethrough~, `code`
  List<InlineSpan> _parseRichText(String text, TextStyle baseStyle) {
    final matches = _richTextRegex.allMatches(text).toList();

    if (matches.isEmpty) {
      return [TextSpan(text: text, style: baseStyle)];
    }

    final spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final match in matches) {
      // Text before this match
      if (match.start > lastEnd) {
        spans.add(
          TextSpan(
            text: text.substring(lastEnd, match.start),
            style: baseStyle,
          ),
        );
      }

      final matchedText = match.group(0)!;
      final content = matchedText.substring(1, matchedText.length - 1);
      TextStyle style = baseStyle;

      if (matchedText.startsWith('*')) {
        // Bold
        style = style.copyWith(fontWeight: FontWeight.bold);
      } else if (matchedText.startsWith('_')) {
        // Italic
        style = style.copyWith(fontStyle: FontStyle.italic);
      } else if (matchedText.startsWith('~')) {
        // Strikethrough
        style = style.copyWith(decoration: TextDecoration.lineThrough);
      } else if (matchedText.startsWith('`')) {
        // Code
        style = style.copyWith(
          fontFamily: 'monospace',
          backgroundColor:
              widget.isMe
                  ? Colors.black.withValues(alpha: 0.2)
                  : Colors.grey.withValues(alpha: 0.2),
        );
      }

      spans.add(TextSpan(text: content, style: style));
      lastEnd = match.end;
    }

    // Remaining text after last match
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd), style: baseStyle));
    }

    return spans;
  }

  Widget _buildTextContent(BuildContext context) {
    // E2EE session missing — show contextual re-establish UI instead of raw text.
    if (widget.message.content == '[🔐 E2EE — session requise]') {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: E2EESessionRequiredBubble(
          senderId: widget.message.senderId,
          isSentByMe: widget.isMe,
          groupId: widget.groupId,
        ),
      );
    }

    final isEmojiOnly = _isEmojiOnly(widget.message.content);
    final postData = widget.message.postData;
    final productData = widget.message.productData;
    final eventData = widget.message.eventData;
    final linkPreviewData = widget.message.linkPreviewData;
    final hasProduct = productData != null;
    final hasLinkPreview = linkPreviewData != null;

    // Emoji-only messages: larger text, no bubble background
    if (isEmojiOnly && !hasProduct && eventData == null) {
      return Padding(
        padding: const EdgeInsets.only(left: 12, right: 12, top: 8, bottom: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.message.content, style: const TextStyle(fontSize: 42)),
            // Groupage : un seul horodatage sous le dernier message du groupe.
            if (_isLastInGroup) ...[
              const SizedBox(height: 4),
              _buildInlineTimeStatus(context),
            ],
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 12, top: 8, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Post share card if attached
          if (postData != null)
            PostMessageCard(postData: postData, isMe: widget.isMe),
          // Product card if attached
          if (hasProduct)
            ProductMessageCard(productData: productData, isMe: widget.isMe),
          // Event card if attached
          if (eventData != null)
            EventMessageCard(eventData: eventData, isMe: widget.isMe),
          // Message content with inline time (groupage : horodatage seulement
          // sous le dernier message d'un groupe consécutif).
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: _buildRichTextWithLinks(context, widget.message.content),
              ),
              if (_isLastInGroup) ...[
                const SizedBox(width: 8),
                _buildInlineTimeStatus(context),
              ],
            ],
          ),
          // Link preview card
          if (hasLinkPreview)
            LinkPreviewBubble.fromMap(linkPreviewData, isMe: widget.isMe),
        ],
      ),
    );
  }

  Widget _buildInlineTimeStatus(BuildContext context) {
    final isStarred =
        widget.currentUserId != null &&
        widget.message.isStarredBy(widget.currentUserId!);
    final l10n = AppLocalizations.of(context)!;

    // Sur bulle envoyée (fond vert) : texte clair. Sur bulle reçue (fond
    // clair opaque) : gris tertiaire, sinon le blanc serait invisible.
    final metaColor =
        widget.isMe
            ? AppColors.white.withValues(alpha: 0.7)
            : context.textTertiaryColor;

    // « Vu par N » : sur MES messages de groupe lus par au moins un autre
    // membre (info spécifique aux groupes, en plus de la double coche).
    final groupReadCount =
        widget.message.readBy
            .where((id) => id != widget.message.senderId)
            .length;
    final showGroupReadCount =
        widget.isMe &&
        widget.groupId != null &&
        !widget.message.deletedForEveryone &&
        groupReadCount > 0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showGroupReadCount) ...[
          Text(
            'Vu par $groupReadCount',
            style: const TextStyle(
              fontSize: 11,
              color: _kReadReceiptBlue,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 6),
        ],
        if (isStarred) ...[
          AppIcon(AppIcon.star, size: 12, color: metaColor),
          const SizedBox(width: 2),
        ],
        // Edited indicator
        if (widget.message.isEdited) ...[
          Text(
            l10n.edited,
            style: TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: metaColor,
            ),
          ),
          const SizedBox(width: 4),
        ],
        // Ephemeral indicator
        if (widget.message.isEphemeral) ...[
          Icon(Icons.timer_outlined, size: 12, color: metaColor),
          const SizedBox(width: 2),
        ],
        Text(
          _formatTime(widget.message.createdAt),
          style: TextStyle(
            fontSize: 11,
            color: widget.isMe ? _kTimestampBlue : context.textTertiaryColor,
          ),
        ),
        if (widget.isMe && !widget.message.deletedForEveryone) ...[
          const SizedBox(width: 3),
          _buildStatusIcon(context, inline: true),
          _buildReadReceiptDot(),
        ],
      ],
    );
  }

  String _getMediaTypeLabel(MessageType type) {
    final l10n = AppLocalizations.of(context)!;
    switch (type) {
      case MessageType.image:
        return '📷 ${l10n.photo}';
      case MessageType.video:
        return '🎥 ${l10n.video}';
      case MessageType.voiceNote:
        return '🎙️ ${l10n.messageTypeVoiceNote}';
      case MessageType.audio:
        return '🎵 ${l10n.messageTypeAudio}';
      case MessageType.file:
        return '📄 ${l10n.document}';
      case MessageType.text:
        return '';
      case MessageType.system:
        return '💬 ${l10n.systemMessage}';
      case MessageType.call:
        return '📞 ${l10n.call}';
      case MessageType.location:
        return '📍 ${l10n.location}';
      case MessageType.sticker:
        return '🎭 Sticker';
    }
  }

  /// Verifier si le message est en attente dans la queue offline
  bool _isPendingOffline() {
    return widget.message.id.startsWith('pending_') &&
        widget.message.status == MessageStatus.sending;
  }

  /// Small lock icon showing the encryption level of this message.
  ///   🔒 green  = Signal Protocol (E2EE, server cannot read)
  ///   🔒 grey   = AES-256-GCM (encrypted in transit, server key-encrypted)
  Widget _buildEncryptionIcon(BuildContext context) {
    final isE2EE =
        widget.message.encryptionLevel == MessageEncryptionLevel.e2ee;
    return Tooltip(
      message: isE2EE ? 'Chiffré — bout en bout (Signal)' : 'Chiffré',
      child: AppIcon(
        AppIcon.lock,
        size: 10,
        color: isE2EE ? Colors.green.shade600 : context.textTertiaryColor,
      ),
    );
  }

  /// Coche (simple ou double) entourée d'un cercle — accusé de réception.
  /// Gris pour envoyé/reçu, bleu pour lu. Rendu en gras (cercle épais + coche
  /// large) pour être très visible.
  Widget _circledReceipt(String icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      child: AppIcon(icon, size: 13, color: color),
    );
  }

  Widget _buildStatusIcon(BuildContext context, {bool inline = false}) {
    final color =
        inline
            ? (widget.isMe
                ? AppColors.white.withValues(alpha: 0.7)
                : context.textTertiaryColor)
            : context.textTertiaryColor;

    // Gris franc (bien visible) pour les accusés « envoyé » / « reçu ».
    final receiptGrey =
        (inline && widget.isMe)
            ? AppColors.white.withValues(alpha: 0.95)
            : context.textSecondaryColor;

    late final Widget iconWidget;

    switch (widget.message.status) {
      case MessageStatus.sending:
        // Message en attente dans la queue offline
        if (_isPendingOffline()) {
          final l10n = AppLocalizations.of(context)!;
          iconWidget = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.schedule, size: 12, color: Colors.orange),
              const SizedBox(width: 2),
              Text(
                l10n.pending,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.orange[700],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          );
        } else {
          // Message en cours d'envoi normal
          iconWidget = SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          );
        }

      case MessageStatus.failed:
        // Libellé explicite « Non envoyé · Réessayer » (rouge adouci) plutôt
        // qu'un simple triangle — maquette 2d.
        final l10n = AppLocalizations.of(context)!;
        const softRed = Color(0xFFF87171);
        iconWidget = GestureDetector(
          onTap: widget.onRetry,
          behavior: HitTestBehavior.opaque,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 12, color: softRed),
              const SizedBox(width: 3),
              Text(
                '${l10n.messageNotSent} · ${l10n.retry}',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: softRed,
                ),
              ),
            ],
          ),
        );

      case MessageStatus.sent:
        // For pending requests, only show "sent" (single check) - no read/delivered
        if (widget.isPendingRequest) {
          iconWidget = _circledReceipt(AppIcon.check, receiptGrey);
          break;
        }

        // Check delivery and read status
        // readBy contains sender, so > 1 means at least one other person read it
        final otherReadersCount =
            widget.message.readBy
                .where((id) => id != widget.message.senderId)
                .length;
        final isRead = otherReadersCount > 0;

        final otherDeliveredCount =
            widget.message.deliveredTo
                .where((id) => id != widget.message.senderId)
                .length;
        final isDelivered = otherDeliveredCount > 0;

        if (isRead) {
          // Lu : double coche dans un cercle bleu
          iconWidget = _circledReceipt(AppIcon.doneAll, _kReadReceiptBlue);
        } else if (isDelivered) {
          // Reçu : double coche dans un cercle gris
          iconWidget = _circledReceipt(AppIcon.doneAll, receiptGrey);
        } else {
          // Envoyé : simple coche dans un cercle gris
          iconWidget = _circledReceipt(AppIcon.check, receiptGrey);
        }
    }

    // Tap to open message info for sent messages from the current user
    if (widget.isMe &&
        widget.message.status == MessageStatus.sent &&
        widget.conversationId != null) {
      return GestureDetector(
        onTap: () => _showMessageInfoSheet(context),
        child: iconWidget,
      );
    }

    return iconWidget;
  }

  Widget _buildSystemMessageContent(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 32),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color:
            context.isDarkMode
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        widget.message.content,
        style: TextStyle(fontSize: 12, color: context.textSecondaryColor),
        textAlign: TextAlign.center,
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    // Message de moins d'une minute : « À l'instant » / « Just now »,
    // sinon l'heure exacte (12:04). Localisé via AppLocalizations.justNow.
    final diff = DateTime.now().difference(dateTime);
    if (!diff.isNegative && diff.inMinutes < 1) {
      return AppLocalizations.of(context)!.justNow;
    }
    return DateFormat.Hm().format(dateTime);
  }

  Future<void> _checkLocalPath() async {
    final path = await FileDownloadService().getDownloadedPath(
      widget.message.id,
    );
    if (!mounted) return;
    setState(() {
      _cachedLocalPath =
          (path != null && File(path).existsSync()) ? path : null;
      _localPathChecked = true;
    });
  }

  Future<void> _saveImageToGallery(String imageUrl) async {
    final service = FileDownloadService();
    final hasPermission = await service.hasGalleryPermission();
    if (!hasPermission) {
      final granted = await service.requestGalleryPermission();
      if (!granted) return;
    }
    final success = await service.downloadImageToGallery(
      imageUrl,
      messageId: widget.message.id,
    );
    if (mounted) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? l10n.imageSaved : l10n.saveFailed),
          backgroundColor: success ? Colors.green : Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _saveVideoToDevice(String videoUrl) async {
    final msg = widget.message;
    final fileName =
        msg.fileName?.isNotEmpty == true ? msg.fileName! : '${msg.id}.mp4';
    final file = await FileDownloadService().downloadToAppDirectory(
      videoUrl,
      fileName: fileName,
      messageId: msg.id,
    );
    if (mounted) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(file != null ? l10n.videoSaved : l10n.saveFailed),
          backgroundColor: file != null ? Colors.green : Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _openFile(String? url) async {
    if (url == null) return;
    // Add https:// if no protocol is specified
    String normalizedUrl = url;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      normalizedUrl = 'https://$url';
    }
    final uri = Uri.parse(normalizedUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _shareMessage() async {
    final l10n = AppLocalizations.of(context)!;
    final scaffold = ScaffoldMessenger.of(context);
    final message = widget.message;

    try {
      if (message.type == MessageType.text) {
        await SharePlus.instance.share(ShareParams(text: message.content));
        return;
      }

      final url = message.fileUrl;
      if (url == null || url.isEmpty) {
        scaffold.showSnackBar(
          SnackBar(
            content: Text(l10n.shareError),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      scaffold.showSnackBar(
        SnackBar(
          content: Text(l10n.shareDownloadingMedia),
          duration: const Duration(seconds: 1),
        ),
      );

      String fileName = message.fileName ?? '';
      if (fileName.isEmpty) {
        final ext = url.split('.').last.split('?').first;
        final sanitized = ext.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
        fileName =
            'shared_${message.type.name}_${DateTime.now().millisecondsSinceEpoch}.${sanitized.isNotEmpty ? sanitized : 'file'}';
      }

      final file = await FileDownloadService().downloadToTemp(
        url,
        fileName: fileName,
      );

      if (file == null) {
        scaffold.showSnackBar(
          SnackBar(
            content: Text(l10n.shareError),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final caption =
          message.content.isNotEmpty &&
                  message.content != message.fileName &&
                  message.content != message.fileUrl
              ? message.content
              : '';

      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: caption),
      );
    } catch (e) {
      scaffold.showSnackBar(
        SnackBar(
          content: Text(l10n.shareError),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleLinkTap(_LinkMatch match) async {
    switch (match.type) {
      case _LinkType.url:
        final confirmed = await _showUrlConfirmDialog(match.text);
        if (confirmed == true) {
          await _openFile(match.text);
        }
        break;
      case _LinkType.phone:
        final cleanNumber = match.text.replaceAll(RegExp(r'[\s.\-()]'), '');
        final confirmed = await _showPhoneConfirmDialog(cleanNumber);
        if (confirmed == true) {
          final uri = Uri.parse('tel:$cleanNumber');
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri);
          }
        }
        break;
      case _LinkType.email:
        final uri = Uri.parse('mailto:${match.text}');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
        break;
      case _LinkType.mention:
        // No action for mentions
        break;
    }
  }

  Future<bool?> _showPhoneConfirmDialog(String phoneNumber) {
    final l10n = AppLocalizations.of(context)!;
    return showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.phone, color: AppColors.success),
                const SizedBox(width: 8),
                Text(l10n.audioCall),
              ],
            ),
            content: Text('${l10n.callConfirmMessage} $phoneNumber ?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l10n.audioCall),
              ),
            ],
          ),
    );
  }

  Future<bool?> _showUrlConfirmDialog(String url) {
    final l10n = AppLocalizations.of(context)!;
    return showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  Icons.open_in_browser,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(l10n.openLink),
              ],
            ),
            content: Text('${l10n.openLinkConfirmMessage}\n\n$url'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l10n.open),
              ),
            ],
          ),
    );
  }
}

/// Type of detected link in message content
enum _LinkType { url, phone, email, mention }

/// Represents a detected link in message content
class _LinkMatch {
  final int start;
  final int end;
  final String text;
  final _LinkType type;

  const _LinkMatch({
    required this.start,
    required this.end,
    required this.text,
    required this.type,
  });
}


/// Pastille ronde de la rangée de réactions rapides (§27a). Aplat sable au
/// repos, cerclée d'accent quand la réaction est déjà posée.
class _QuickReactionButton extends StatelessWidget {
  final String? emoji;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const _QuickReactionButton({
    this.emoji,
    this.icon,
    this.selected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? context.adaptivePrimaryColor.withValues(alpha: 0.14)
          : context.surfaceVariantColor,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: selected
                ? Border.all(color: context.adaptivePrimaryColor, width: 1.6)
                : null,
          ),
          child: icon != null
              ? Icon(icon, size: 20, color: context.textSecondaryColor)
              : Text(emoji!, style: const TextStyle(fontSize: 21)),
        ),
      ),
    );
  }
}
