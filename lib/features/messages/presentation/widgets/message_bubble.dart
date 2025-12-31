import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/message_entity.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../../../core/utils/user_color_utils.dart';
import '../../../reports/domain/entities/report_entity.dart'
    show ReportTargetType, ContentSnapshot;
import '../../../reports/presentation/widgets/report_content_modal.dart';
import 'audio_message_bubble.dart';
import 'delete_message_modal.dart';
import 'full_screen_image_viewer.dart';
import 'optimized_image_bubble.dart';
import 'document_bubble.dart';
import 'video_bubble.dart';
import 'product_message_card.dart';

/// Position of a message in a group of consecutive messages from the same sender
enum MessageGroupPosition { first, middle, last, single }

class MessageBubble extends StatefulWidget {
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
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  // Swipe to reply
  double _swipeOffset = 0;
  bool _isSwipingToReply = false;

  // Reactions popup
  bool _showReactionsPopup = false;

  static const List<String> _quickReactions = [
    '❤️',
    '👍',
    '😂',
    '😮',
    '😢',
    '🙏',
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    _slideAnimation = Tween<double>(
      begin: widget.isMe ? 30 : -30,
      end: 0,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    // Start animation
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  BorderRadius _getBorderRadius() {
    const double largeRadius = 20;
    const double smallRadius = 6;
    const double tinyRadius = 4;

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
  bool _isEmojiOnlyTextMessage() {
    return widget.message.type == MessageType.text &&
        !widget.message.deletedForEveryone &&
        widget.replyToMessage == null &&
        _isEmojiOnly(widget.message.content);
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
          Text(
            widget.message.content,
            style: const TextStyle(fontSize: 42),
          ),
          // Time and status below emoji
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
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

    // Check if message is deleted for the current user
    final isDeleted =
        widget.currentUserId != null &&
        widget.message.isDeletedFor(widget.currentUserId!);

    // Don't show messages that are deleted for the current user
    if (isDeleted && !widget.message.deletedForEveryone) {
      return const SizedBox.shrink();
    }

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
                    opacity: _swipeOffset.abs() > 40 ? 1 : 0.5,
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
                  left: widget.isMe ? 64 : 16,
                  right: widget.isMe ? 16 : 64,
                  top: _getVerticalPadding(),
                  bottom: _getVerticalPadding(),
                ),
                child: Column(
                  crossAxisAlignment:
                      widget.isMe
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                  children: [
                    // Reactions popup
                    if (_showReactionsPopup) _buildReactionsPopup(context),

                    // Check if this is an emoji-only text message (no bubble)
                    _isEmojiOnlyTextMessage()
                        ? _buildEmojiOnlyContent(context)
                        : GestureDetector(
                          onLongPress: _onLongPress,
                          onDoubleTap: _onDoubleTap,
                          child: Container(
                            decoration: BoxDecoration(
                              color:
                                  widget.isMe
                                      ? context.adaptiveSecondaryColor
                                          .withValues(alpha: 0.85)
                                      : context.isDarkMode
                                      ? context.adaptivePrimaryColor.withValues(
                                        alpha: 0.65,
                                      )
                                      : context.adaptivePrimaryColor.withValues(
                                        alpha: 0.55,
                                      ),
                              borderRadius: _getBorderRadius(),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      context.isDarkMode
                                          ? Colors.black.withValues(alpha: 0.4)
                                          : Colors.black.withValues(
                                            alpha: 0.15,
                                          ),
                                  blurRadius: context.isDarkMode ? 6 : 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                              border: Border.all(
                                color:
                                    widget.isMe
                                        ? Colors.white.withValues(alpha: 0.1)
                                        : Colors.white.withValues(alpha: 0.15),
                                width: 1,
                              ),
                            ),
                            child: GestureDetector(
                              onTap:
                                  widget.message.status == MessageStatus.failed &&
                                          widget.onRetry != null
                                      ? widget.onRetry
                                      : null,
                              child: ClipRRect(
                                borderRadius: _getBorderRadius(),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Sender name inside bubble for groups
                                    if (widget.showSenderInfo && !widget.isMe)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          left: 12,
                                          right: 12,
                                          top: 8,
                                        ),
                                        child: InkWell(
                                          onTap:
                                              () => widget.onSenderTap?.call(
                                                widget.message.senderId,
                                              ),
                                          child: Text(
                                            widget.message.senderName,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: UserColorUtils.getUserColor(
                                                widget.message.senderId,
                                              ),
                                            ),
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

                    // Reactions display
                    if (widget.message.reactions.isNotEmpty)
                      _buildReactionsDisplay(context, widget.message.reactions),

                    // Read avatars for groups
                    if (widget.readByAvatars != null &&
                        widget.readByAvatars!.isNotEmpty &&
                        widget.isMe)
                      _buildReadAvatars(context),
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

    // Only allow swipe in the correct direction
    if (widget.isMe) {
      // Swipe left for "isMe" messages
      if (newOffset <= 0 && newOffset >= -80) {
        setState(() {
          _swipeOffset = newOffset;
        });
      }
    } else {
      // Swipe right for other's messages
      if (newOffset >= 0 && newOffset <= 80) {
        setState(() {
          _swipeOffset = newOffset;
        });
      }
    }

    // Haptic feedback when threshold is reached
    if (_swipeOffset.abs() > 60 && _swipeOffset.abs() < 65) {
      HapticFeedback.lightImpact();
    }
  }

  void _onSwipeEnd(DragEndDetails details) {
    if (_swipeOffset.abs() > 60) {
      // Trigger reply
      HapticFeedback.mediumImpact();
      widget.onReply?.call(widget.message);
    }

    setState(() {
      _swipeOffset = 0;
      _isSwipingToReply = false;
    });
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
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
              );
            }).toList(),
      ),
    );
  }

  Widget _buildReadAvatars(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, right: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children:
            widget.readByAvatars!.take(3).map((avatarUrl) {
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
                        ? Icon(
                          Icons.person,
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

  void _showOptionsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.textTertiaryColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),

                // Reply option
                if (widget.onReply != null)
                  ListTile(
                    leading: Icon(Icons.reply, color: context.textPrimaryColor),
                    title: Text(
                      'Répondre',
                      style: TextStyle(color: context.textPrimaryColor),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      widget.onReply?.call(widget.message);
                    },
                  ),

                // React option
                if (widget.onReact != null)
                  ListTile(
                    leading: Icon(
                      Icons.add_reaction_outlined,
                      color: context.textPrimaryColor,
                    ),
                    title: Text(
                      'Réagir',
                      style: TextStyle(color: context.textPrimaryColor),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _showReactionsPopup = true;
                      });
                    },
                  ),

                // Copy option (for text messages)
                if (widget.message.type == MessageType.text)
                  ListTile(
                    leading: Icon(Icons.copy, color: context.textPrimaryColor),
                    title: Text(
                      'Copier',
                      style: TextStyle(color: context.textPrimaryColor),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      Clipboard.setData(
                        ClipboardData(text: widget.message.content),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Message copié'),
                          backgroundColor: context.adaptivePrimaryColor,
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                  ),

                // Delete option
                if (_canShowDeleteOption())
                  ListTile(
                    leading: const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                    ),
                    title: const Text(
                      'Supprimer',
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showDeleteModal(context);
                    },
                  ),

                // Report option (for messages from other users)
                if (!widget.isMe && !widget.message.deletedForEveryone)
                  ListTile(
                    leading: const Icon(
                      Icons.flag_outlined,
                      color: Colors.orange,
                    ),
                    title: const Text(
                      'Signaler',
                      style: TextStyle(color: Colors.orange),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      // Créer le snapshot du contenu
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

                SizedBox(height: MediaQuery.of(ctx).padding.bottom),
              ],
            ),
          ),
    );
  }

  void _showDeleteModal(BuildContext context) {
    if (widget.conversationId == null || widget.currentUserId == null) return;

    DeleteMessageModal.show(
      context,
      message: widget.message,
      conversationId: widget.conversationId!,
      currentUserId: widget.currentUserId!,
      isAdmin: widget.isAdmin,
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
          caption: message.content.isNotEmpty && message.content != message.fileName
              ? message.content
              : null,
        );

      case MessageType.video:
        return ReportContentModal.videoSnapshot(
          message.fileUrl ?? '',
          caption: message.content.isNotEmpty ? message.content : null,
        );

      case MessageType.audio:
      case MessageType.file:
        return ReportContentModal.fileSnapshot(
          message.fileUrl ?? '',
          message.fileName ?? 'Fichier',
        );

      case MessageType.system:
        return ReportContentModal.textMessageSnapshot(message.content);
    }
  }

  Widget _buildDeletedContent(BuildContext context) {
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
            'Message supprimé',
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

  Widget _buildContent(BuildContext context) {
    switch (widget.message.type) {
      case MessageType.image:
        return OptimizedImageBubble(
          imageUrl: widget.message.fileUrl ?? '',
          caption:
              widget.message.content == widget.message.fileName ||
                      widget.message.content.isEmpty
                  ? null
                  : widget.message.content,
          isMe: widget.isMe,
          heroTag: 'message_image_${widget.message.id}',
          timestamp: widget.message.createdAt,
          messageStatus: widget.message.status,
          showSenderInfo: widget.showSenderInfo && !widget.isMe,
          senderName: widget.message.senderName,
          onTap:
              () => FullScreenImageViewer.show(
                context,
                imageUrl: widget.message.fileUrl!,
                heroTag: 'message_image_${widget.message.id}',
                senderName: widget.message.senderName,
                sentAt: widget.message.createdAt,
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
          onTap: () => _openFile(widget.message.fileUrl),
        );

      case MessageType.video:
        return VideoBubble(
          videoUrl: widget.message.fileUrl ?? '',
          thumbnailUrl: widget.message.thumbnailUrl,
          duration: widget.message.videoDuration,
          caption: widget.message.content,
          isMe: widget.isMe,
          timestamp: widget.message.createdAt,
          messageStatus: widget.message.status,
          showSenderInfo: widget.showSenderInfo && !widget.isMe,
          senderName: widget.message.senderName,
          onTap: () => _openFile(widget.message.fileUrl),
        );

      case MessageType.audio:
        return AudioMessageBubble(message: widget.message, isMe: widget.isMe);

      case MessageType.text:
        return _buildTextContent(context);

      case MessageType.system:
        return _buildSystemMessageContent(context);
    }
  }

  Widget _buildReplyPreview(BuildContext context) {
    final isMe = widget.isMe;
    final reply = widget.replyToMessage!;
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
      case MessageType.audio:
        return Icons.mic;
      case MessageType.file:
        return Icons.insert_drive_file;
      default:
        return Icons.chat_bubble;
    }
  }

  Widget _buildTextContent(BuildContext context) {
    final isEmojiOnly = _isEmojiOnly(widget.message.content);
    final hasProduct = widget.message.hasProduct;

    // Emoji-only messages: larger text, no bubble background
    if (isEmojiOnly && !hasProduct) {
      return Padding(
        padding: const EdgeInsets.only(left: 12, right: 12, top: 8, bottom: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.message.content,
              style: const TextStyle(fontSize: 42),
            ),
            const SizedBox(height: 4),
            _buildInlineTimeStatus(context),
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
          // Product card if attached
          if (hasProduct)
            ProductMessageCard(
              productData: widget.message.productData!,
              isMe: widget.isMe,
            ),
          // Message content with inline time
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  widget.message.content,
                  style: TextStyle(
                    fontSize: 15,
                    color:
                        widget.isMe
                            ? AppColors.white
                            : context.textPrimaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Time and status inline
              _buildInlineTimeStatus(context),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInlineTimeStatus(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _formatTime(widget.message.createdAt),
          style: TextStyle(
            fontSize: 11,
            color: AppColors.white.withValues(alpha: 0.7),
          ),
        ),
        if (widget.isMe && !widget.message.deletedForEveryone) ...[
          const SizedBox(width: 3),
          _buildStatusIcon(context, inline: true),
        ],
      ],
    );
  }

  String _getMediaTypeLabel(MessageType type) {
    switch (type) {
      case MessageType.image:
        return '📷 Photo';
      case MessageType.video:
        return '🎥 Vidéo';
      case MessageType.audio:
        return '🎵 Audio';
      case MessageType.file:
        return '📄 Document';
      case MessageType.text:
        return '';
      case MessageType.system:
        return '💬 Message système';
    }
  }

  Widget _buildStatusIcon(BuildContext context, {bool inline = false}) {
    final color =
        inline
            ? (widget.isMe
                ? AppColors.white.withValues(alpha: 0.7)
                : context.textTertiaryColor)
            : context.textTertiaryColor;

    switch (widget.message.status) {
      case MessageStatus.sending:
        return SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        );

      case MessageStatus.failed:
        return GestureDetector(
          onTap: widget.onRetry,
          child: const Icon(
            Icons.warning_amber_rounded,
            size: 14,
            color: Colors.red,
          ),
        );

      case MessageStatus.sent:
        final isRead = widget.message.readBy.length > 1;
        return Icon(
          isRead ? Icons.done_all : Icons.check,
          size: 14,
          color:
              isRead
                  ? (inline && widget.isMe ? Colors.white : Colors.blue)
                  : color,
        );
    }
  }

  Widget _buildSystemMessageContent(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 32),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: context.isDarkMode
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        widget.message.content,
        style: TextStyle(
          fontSize: 12,
          color: context.textSecondaryColor,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    return DateFormat.Hm().format(dateTime);
  }

  Future<void> _openFile(String? url) async {
    if (url == null) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
