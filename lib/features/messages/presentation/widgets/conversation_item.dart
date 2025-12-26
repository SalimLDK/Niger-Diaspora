import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/conversation_entity.dart';
import '../../domain/entities/message_entity.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../../profile/presentation/widgets/online_status_indicator.dart';

class ConversationItem extends StatelessWidget {
  final ConversationEntity conversation;
  final String currentUserId;
  final String? otherUserName;
  final String? otherUserPhotoUrl;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const ConversationItem({
    super.key,
    required this.conversation,
    required this.currentUserId,
    this.otherUserName,
    this.otherUserPhotoUrl,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final hasUnread = conversation.hasUnreadFor(currentUserId);
    final unreadCount = conversation.getUnreadCountFor(currentUserId);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow:
              context.isDarkMode
                  ? null
                  : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
        ),
        child: Row(
          children: [
            // Avatar
            _buildAvatar(context),
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
                          _getDisplayName(),
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
                      Text(
                        _formatTime(),
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation.lastMessage ?? 'Nouvelle conversation',
                          style: TextStyle(
                            fontSize: 14,
                            color:
                                hasUnread
                                    ? context.textPrimaryColor
                                    : context.textSecondaryColor,
                            fontWeight:
                                hasUnread ? FontWeight.w500 : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (conversation.lastMessageSenderId == currentUserId &&
                          conversation.lastMessageStatus != null) ...[
                        const SizedBox(width: 4),
                        _buildStatusIcon(
                          context,
                          conversation.lastMessageStatus!,
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
                            borderRadius: BorderRadius.circular(12),
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
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    if (conversation.isGroup) {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: AppColors.secondaryGradient,
          borderRadius: BorderRadius.circular(16),
        ),
        child:
            conversation.imageUrl != null
                ? ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    conversation.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (_, __, ___) => const Center(
                          child: Icon(
                            Icons.groups,
                            color: AppColors.white,
                            size: 26,
                          ),
                        ),
                  ),
                )
                : const Center(
                  child: Icon(Icons.groups, color: AppColors.white, size: 26),
                ),
      );
    }

    // Conversation individuelle
    return Stack(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(16),
          ),
          child:
              otherUserPhotoUrl != null
                  ? ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      otherUserPhotoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder:
                          (_, __, ___) => const Center(
                            child: Icon(
                              Icons.person,
                              color: AppColors.white,
                              size: 26,
                            ),
                          ),
                    ),
                  )
                  : const Center(
                    child: Icon(Icons.person, color: AppColors.white, size: 26),
                  ),
        ),
        if (!conversation.isGroup)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).cardColor,
                  width: 2,
                ),
              ),
              child: OnlineStatusIndicator(
                userId: conversation.getOtherParticipantId(currentUserId),
                showText: false,
                dotSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  String _getDisplayName() {
    if (conversation.isGroup) {
      return conversation.name ?? 'Groupe';
    }
    return otherUserName ?? 'Utilisateur';
  }

  String _formatTime() {
    if (conversation.lastMessageAt == null) {
      return '';
    }

    final now = DateTime.now();
    final messageDate = conversation.lastMessageAt!;
    final difference = now.difference(messageDate);

    if (difference.inDays == 0) {
      return DateFormat.Hm().format(messageDate);
    } else if (difference.inDays == 1) {
      return 'Hier';
    } else if (difference.inDays < 7) {
      return DateFormat.E('fr').format(messageDate);
    } else {
      return DateFormat.MMMd('fr').format(messageDate);
    }
  }

  Widget _buildStatusIcon(BuildContext context, MessageStatus status) {
    switch (status) {
      case MessageStatus.sending:
        return Icon(
          Icons.access_time,
          size: 14,
          color: context.textTertiaryColor,
        );
      case MessageStatus.failed:
        return const Icon(Icons.close, size: 14, color: Colors.red);
      case MessageStatus.sent:
        // For conversation list, we might not have readBy info easily available
        // unless we add it to ConversationEntity.
        // If we want read receipts here, we need to check if unreadCount for the OTHER user is 0.
        // But unreadCount is map<userId, int>.
        // If I am sender, and other user's unreadCount is 0, it means they read it.

        bool isRead = false;
        if (conversation.isIndividual) {
          final otherId = conversation.getOtherParticipantId(currentUserId);
          final otherUnread = conversation.unreadCount[otherId] ?? 0;
          isRead = otherUnread == 0;
        } else {
          // For groups, it's harder. Let's simplify: if all others have 0 unread?
          // Or just stick to "Sent" for now for groups unless we have complex logic.
          // Let's try to do it for individuals at least.
          // Actually, unreadCount in ConversationModel is correct.
          isRead = true; // Assume read, then check if anyone has unread > 0?
          // No, unreadCount is per user.
          // If all OTHER participants have unreadCount == 0, then it is read by everyone.
          isRead = true;
          for (final entry in conversation.unreadCount.entries) {
            if (entry.key != currentUserId && entry.value > 0) {
              isRead = false;
              break;
            }
          }
        }

        return Icon(
          isRead ? Icons.done_all : Icons.done,
          size: 14,
          color: isRead ? Colors.blue : context.textTertiaryColor,
        );
    }
  }
}
