import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/verification_badge.dart';
import '../../domain/entities/conversation_entity.dart';
import '../../domain/entities/message_entity.dart';
import '../providers/typing_indicator_provider.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../profile/presentation/widgets/online_status_indicator.dart';
import '../../../settings/presentation/providers/blocked_users_provider.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';

class ConversationItem extends ConsumerStatefulWidget {
  final ConversationEntity conversation;
  final String currentUserId;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isSelectionMode;
  final bool isSelected;
  final ValueChanged<bool>? onSelectionChanged;

  const ConversationItem({
    super.key,
    required this.conversation,
    required this.currentUserId,
    required this.onTap,
    this.onLongPress,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onSelectionChanged,
  });

  @override
  ConsumerState<ConversationItem> createState() => _ConversationItemState();
}

class _ConversationItemState extends ConsumerState<ConversationItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _scaleController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _scaleController.reverse();
  }

  void _onTapCancel() {
    _scaleController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final conversation = widget.conversation;
    final currentUserId = widget.currentUserId;

    // Check for blocked users
    final blockedUsers = ref.watch(blockedUsersProvider).valueOrNull ?? [];
    final blockedUserIds = blockedUsers.map((u) => u.id).toSet();

    // For individual conversations, get other user profile once
    bool isBlocked = false;
    String? otherUserId;
    dynamic otherProfile;

    if (conversation.isIndividual) {
      otherUserId = conversation.getOtherParticipantId(currentUserId);
      // I blocked them
      if (blockedUserIds.contains(otherUserId)) {
        isBlocked = true;
      }
      // Watch profile once and reuse (avoid duplicate provider calls)
      final otherProfileAsync = ref.watch(userStreamProvider(otherUserId));
      otherProfile = otherProfileAsync.valueOrNull;
      // They blocked me
      if (otherProfile != null &&
          otherProfile.blockedByUserIds.contains(currentUserId)) {
        isBlocked = true;
      }
    }

    // Hide unread count if blocked
    final hasUnread =
        isBlocked ? false : conversation.hasUnreadFor(currentUserId);
    final unreadCount =
        isBlocked ? 0 : conversation.getUnreadCountFor(currentUserId);
    final hasMention =
        isBlocked ? false : conversation.hasUnreadMentionFor(currentUserId);

    // Pour les conversations individuelles, récupérer le profil de l'autre utilisateur
    final l10n = AppLocalizations.of(context)!;
    String displayName;
    String? photoUrl;

    if (conversation.isGroup) {
      displayName = conversation.name ?? l10n.group;
      photoUrl = conversation.imageUrl;
    } else {
      if (otherUserId != null && otherUserId.isNotEmpty) {
        // Reuse otherProfile already fetched above (no duplicate provider call)
        displayName =
            otherProfile?.displayName ?? conversation.name ?? l10n.user;
        photoUrl = otherProfile?.photoUrl ?? conversation.imageUrl;
      } else {
        displayName = conversation.name ?? l10n.user;
        photoUrl = conversation.imageUrl;
      }
    }

    // Indicateur de frappe dans la liste (façon WhatsApp/Telegram) : remplace
    // l'aperçu du dernier message tant que l'autre écrit.
    final typingUserIds = isBlocked
        ? const <String>[]
        : (ref
                .watch(typingStatusProvider(conversation.id))
                .whenData(
                  (m) => m.entries
                      .where((e) => e.key != currentUserId && e.value)
                      .map((e) => e.key)
                      .toList(),
                )
                .valueOrNull ??
            const <String>[]);
    final String? typingText = typingUserIds.isEmpty
        ? null
        : (conversation.isGroup
            ? l10n.typingSomeone
            : l10n.typingOneName(displayName));

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder:
          (context, child) =>
              Transform.scale(scale: _scaleAnimation.value, child: child),
      child: GestureDetector(
        onTap:
            widget.isSelectionMode
                ? () => widget.onSelectionChanged?.call(!widget.isSelected)
                : widget.onTap,
        onTapDown: widget.isSelectionMode ? null : _onTapDown,
        onTapUp: widget.isSelectionMode ? null : _onTapUp,
        onTapCancel: widget.isSelectionMode ? null : _onTapCancel,
        onLongPress: widget.onLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color:
                widget.isSelected
                    ? context.adaptivePrimaryColor.withValues(alpha: 0.1)
                    : context.surfaceColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color:
                  widget.isSelected
                      ? context.adaptivePrimaryColor
                      : context.isDarkMode
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.04),
              width: widget.isSelected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color:
                    context.isDarkMode
                        ? Colors.black.withValues(alpha: 0.3)
                        : Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
                spreadRadius: -4,
              ),
            ],
          ),
          child: Row(
            children: [
              // Checkbox en mode selection
              if (widget.isSelectionMode) ...[
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        widget.isSelected
                            ? context.adaptivePrimaryColor
                            : Colors.transparent,
                    border: Border.all(
                      color:
                          widget.isSelected
                              ? context.adaptivePrimaryColor
                              : context.textTertiaryColor,
                      width: 2,
                    ),
                  ),
                  child:
                      widget.isSelected
                          ? const AppIcon(AppIcon.check,
                            size: 16,
                            color: Colors.white,
                          )
                          : null,
                ),
                const SizedBox(width: 12),
              ],
              // Avatar with online indicator
              _buildAvatar(
                context,
                photoUrl,
                displayName,
                otherUserId,
                isVerified: otherProfile?.isVerified ?? false,
              ),
              const SizedBox(width: 14),
              // Contenu
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            displayName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight:
                                  hasUnread ? FontWeight.w700 : FontWeight.w600,
                              color: context.textPrimaryColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Pin indicator
                        if (conversation.isPinnedBy(currentUserId)) ...[
                          Icon(
                            Icons.push_pin,
                            size: 14,
                            color: context.adaptivePrimaryColor,
                          ),
                          const SizedBox(width: 4),
                        ],
                        // Mute indicator
                        if (conversation.isMutedBy(currentUserId)) ...[
                          Icon(
                            Icons.notifications_off_outlined,
                            size: 16,
                            color: context.textTertiaryColor,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          _formatTime(l10n, Localizations.localeOf(context).languageCode),
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                hasUnread
                                    ? context.adaptivePrimaryColor
                                    : context.textTertiaryColor,
                            fontWeight:
                                hasUnread ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Check if this is a pending request
                    _buildMessageContent(
                      context,
                      conversation,
                      currentUserId,
                      hasUnread,
                      unreadCount,
                      hasMention,
                      typingText,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(
    BuildContext context,
    String? photoUrl,
    String displayName,
    String? otherUserId, {
    bool isVerified = false,
  }) {
    // Obtenir les initiales du nom
    String getInitials(String name) {
      if (name.isEmpty) return '?';
      final parts = name.trim().split(' ');
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      return name[0].toUpperCase();
    }

    final initials = getInitials(displayName);

    if (widget.conversation.isGroup) {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: context.adaptiveSecondaryGradient,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: context.adaptiveSecondaryColor.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child:
            photoUrl != null && photoUrl.isNotEmpty
                ? ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: CachedNetworkImage(
                    imageUrl: photoUrl,
                    fit: BoxFit.cover,
                    width: 56,
                    height: 56,
                    placeholder:
                        (_, __) => const Center(
                          child: AppIcon(AppIcon.groups,
                            color: AppColors.white,
                            size: 26,
                          ),
                        ),
                    errorWidget:
                        (_, __, ___) => const Center(
                          child: AppIcon(AppIcon.groups,
                            color: AppColors.white,
                            size: 26,
                          ),
                        ),
                  ),
                )
                : const Center(
                  child: AppIcon(AppIcon.groups, color: AppColors.white, size: 26),
                ),
      );
    }

    // Conversation individuelle avec indicateur en ligne
    final avatarWidget = Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: context.adaptivePrimaryGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: context.adaptivePrimaryColor.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child:
          photoUrl != null && photoUrl.isNotEmpty
              ? ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: CachedNetworkImage(
                  imageUrl: photoUrl,
                  fit: BoxFit.cover,
                  width: 56,
                  height: 56,
                  placeholder:
                      (_, __) => Center(
                        child: Text(
                          initials,
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  errorWidget:
                      (_, __, ___) => Center(
                        child: Text(
                          initials,
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                ),
              )
              : Center(
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
    );

    // Ajouter l'indicateur en ligne et/ou le badge de certification
    if (otherUserId != null && otherUserId.isNotEmpty) {
      return SizedBox(
        width: 60,
        height: 60,
        child: Stack(
          children: [
            avatarWidget,
            if (isVerified)
              const Positioned(
                right: 0,
                bottom: 0,
                child: VerificationBadge(size: VerificationBadgeSize.normal),
              )
            else
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: context.surfaceColor,
                    shape: BoxShape.circle,
                  ),
                  child: OnlineStatusIndicator(
                    userId: otherUserId,
                    showText: false,
                    showDot: true,
                    dotSize: 12,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return avatarWidget;
  }

  /// Build message content
  Widget _buildMessageContent(
    BuildContext context,
    ConversationEntity conversation,
    String currentUserId,
    bool hasUnread,
    int unreadCount,
    bool hasMention,
    String? typingText,
  ) {
    // Always show normal message content - pending request banner is shown in conversation screen
    final isCallMessage = conversation.lastMessageType == MessageType.call;
    return Row(
      children: [
        Expanded(
          child: _buildLastMessageText(
            context,
            conversation,
            currentUserId,
            hasUnread,
            typingText,
          ),
        ),
        // Show status icon only for non-call messages sent by current user
        // (masqué pendant que l'autre écrit)
        if (typingText == null &&
            !isCallMessage &&
            conversation.lastMessageSenderId == currentUserId &&
            conversation.lastMessageStatus != null) ...[
          const SizedBox(width: 4),
          _buildStatusIcon(context, conversation.lastMessageStatus!),
        ],
        if (hasMention) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.error,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              '@',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
        if (hasUnread && unreadCount > 0) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: context.adaptivePrimaryColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: context.adaptivePrimaryColor
                      .withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              unreadCount > 99 ? '99+' : unreadCount.toString(),
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLastMessageText(
    BuildContext context,
    ConversationEntity conversation,
    String currentUserId,
    bool hasUnread,
    String? typingText,
  ) {
    // Priorité au « en train d'écrire… » quand quelqu'un tape.
    if (typingText != null) {
      return Text(
        typingText,
        style: TextStyle(
          fontSize: 14,
          color: context.adaptivePrimaryColor,
          fontWeight: FontWeight.w500,
          fontStyle: FontStyle.italic,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    final l10n = AppLocalizations.of(context)!;
    final formattedMessage = _formatLastMessage(conversation, currentUserId, l10n);
    final isCallMessage = conversation.lastMessageType == MessageType.call;

    Color textColor;
    if (isCallMessage) {
      // Color based on call status in message content
      final lastMessage = conversation.lastMessage ?? '';
      if (lastMessage.contains('missed') || lastMessage.contains('manqué')) {
        textColor = AppColors.error;
      } else if (lastMessage.contains('declined') || lastMessage.contains('refusé')) {
        textColor = Colors.orange;
      } else {
        textColor = AppColors.success;
      }
    } else {
      textColor = hasUnread ? context.textPrimaryColor : context.textSecondaryColor;
    }

    // Show icon for calls
    if (isCallMessage) {
      final lastMessage = conversation.lastMessage ?? '';
      final isVideoCall = lastMessage.contains('video') || lastMessage.contains('vidéo');
      return Row(
        children: [
          AppIcon(isVideoCall ? AppIcon.video : AppIcon.call,
            size: 14,
            color: textColor,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              formattedMessage,
              style: TextStyle(
                fontSize: 14,
                color: textColor,
                fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    // Note vocale : icône micro + libellé (§9a).
    final msgType = conversation.lastMessageType;
    if (msgType == MessageType.audio || msgType == MessageType.voiceNote) {
      final youPrefix = conversation.lastMessageSenderId == currentUserId;
      return Row(
        children: [
          AppIcon(AppIcon.mic, size: 14, color: textColor),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              youPrefix ? l10n.conversationYouPrefix('Note vocale') : 'Note vocale',
              style: TextStyle(
                fontSize: 14,
                color: textColor,
                fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    return Text(
      formattedMessage,
      style: TextStyle(
        fontSize: 14,
        color: textColor,
        fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  String _formatLastMessage(
    ConversationEntity conversation,
    String currentUserId,
    AppLocalizations l10n,
  ) {
    final youPrefix = conversation.lastMessageSenderId == currentUserId;

    // L'aperçu dit son type (§9a) — les notes vocales sont gérées à part
    // (icône micro) dans _buildLastMessageText.
    String? typeLabel;
    switch (conversation.lastMessageType) {
      case MessageType.image:
        typeLabel = '📎 Photo';
        break;
      case MessageType.video:
        typeLabel = '🎥 Vidéo';
        break;
      case MessageType.file:
        typeLabel = '📎 Document';
        break;
      case MessageType.location:
        typeLabel = '📍 Position';
        break;
      case MessageType.sticker:
        typeLabel = '🎨 Sticker';
        break;
      default:
        typeLabel = null;
    }
    if (typeLabel != null) {
      return youPrefix ? l10n.conversationYouPrefix(typeLabel) : typeLabel;
    }

    final lastMessage = conversation.lastMessage;
    if (lastMessage == null || lastMessage.isEmpty) {
      return l10n.newConversation;
    }

    // Ajouter le préfixe "Vous:" si le message a été envoyé par l'utilisateur courant
    if (youPrefix) {
      return l10n.conversationYouPrefix(lastMessage);
    }

    return lastMessage;
  }

  String _formatTime(AppLocalizations l10n, String locale) {
    if (widget.conversation.lastMessageAt == null) {
      return '';
    }

    final now = DateTime.now();
    final messageDate = widget.conversation.lastMessageAt!;
    final difference = now.difference(messageDate);

    if (difference.inDays == 0) {
      return DateFormat.Hm().format(messageDate);
    } else if (difference.inDays == 1) {
      return l10n.yesterday('');
    } else if (difference.inDays < 7) {
      return DateFormat.E(locale).format(messageDate);
    } else {
      return DateFormat.MMMd(locale).format(messageDate);
    }
  }

  Widget _buildStatusIcon(BuildContext context, MessageStatus status) {
    final color = context.textTertiaryColor;

    switch (status) {
      case MessageStatus.sending:
        return Icon(Icons.schedule, size: 14, color: color);
      case MessageStatus.failed:
        return const AppIcon(AppIcon.warning, size: 14, color: Colors.red);
      case MessageStatus.sent:
        final readBy = widget.conversation.lastMessageReadBy;
        final otherId = widget.conversation.getOtherParticipantId(widget.currentUserId);

        final isRead = readBy.contains(otherId);
        final isDelivered = !isRead &&
            widget.conversation.lastMessageDeliveredTo.contains(otherId);

        if (isRead) {
          return const AppIcon(AppIcon.doneAll, size: 16, color: Colors.blue);
        }
        if (isDelivered) {
          return AppIcon(AppIcon.doneAll, size: 16, color: color);
        }
        return AppIcon(AppIcon.check, size: 14, color: color);
    }
  }
}
