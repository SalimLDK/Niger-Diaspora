import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/conversation_entity.dart';
import '../../../../core/theme/adaptive_colors.dart';

class ConversationItem extends StatelessWidget {
  final ConversationEntity conversation;
  final String currentUserId;
  final String? otherUserName;
  final String? otherUserPhotoUrl;
  final VoidCallback onTap;

  const ConversationItem({
    super.key,
    required this.conversation,
    required this.currentUserId,
    this.otherUserName,
    this.otherUserPhotoUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasUnread = conversation.hasUnreadFor(currentUserId);
    final unreadCount = conversation.getUnreadCountFor(currentUserId);

    return GestureDetector(
      onTap: onTap,
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
            _buildAvatar(),
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

  Widget _buildAvatar() {
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
    return Container(
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
}
