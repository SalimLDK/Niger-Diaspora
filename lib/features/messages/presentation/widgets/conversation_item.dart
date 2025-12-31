import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/conversation_entity.dart';
import '../../domain/entities/message_entity.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../profile/presentation/widgets/online_status_indicator.dart';
import '../../../settings/presentation/providers/blocked_users_provider.dart';

class ConversationItem extends ConsumerWidget {
  final ConversationEntity conversation;
  final String currentUserId;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const ConversationItem({
    super.key,
    required this.conversation,
    required this.currentUserId,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Check for blocked users
    final blockedUsers = ref.watch(blockedUsersProvider).valueOrNull ?? [];
    final blockedUserIds = blockedUsers.map((u) => u.id).toSet();

    // For individual conversations, check if blocked
    bool isBlocked = false;
    String? otherUserId;
    if (conversation.isIndividual) {
      otherUserId = conversation.getOtherParticipantId(currentUserId);
      // I blocked them
      if (blockedUserIds.contains(otherUserId)) {
        isBlocked = true;
      }
      // They blocked me
      final otherProfileAsync = ref.watch(userStreamProvider(otherUserId));
      final otherProfile = otherProfileAsync.valueOrNull;
      if (otherProfile != null && otherProfile.blockedByUserIds.contains(currentUserId)) {
        isBlocked = true;
      }
    }

    // Hide unread count if blocked
    final hasUnread = isBlocked ? false : conversation.hasUnreadFor(currentUserId);
    final unreadCount = isBlocked ? 0 : conversation.getUnreadCountFor(currentUserId);

    // Pour les conversations individuelles, récupérer le profil de l'autre utilisateur
    String displayName;
    String? photoUrl;

    if (conversation.isGroup) {
      displayName = conversation.name ?? 'Groupe';
      photoUrl = conversation.imageUrl;
    } else {
      if (otherUserId != null && otherUserId.isNotEmpty) {
        // Utiliser userStreamProvider pour les données en temps réel depuis Firestore
        final profileAsync = ref.watch(userStreamProvider(otherUserId));
        final profile = profileAsync.valueOrNull;
        displayName = profile?.displayName ?? conversation.name ?? 'Utilisateur';
        photoUrl = profile?.photoUrl ?? conversation.imageUrl;
      } else {
        displayName = conversation.name ?? 'Utilisateur';
        photoUrl = conversation.imageUrl;
      }
    }

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
            _buildAvatar(context, photoUrl, displayName),
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

  Widget _buildAvatar(BuildContext context, String? photoUrl, String displayName) {
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

    if (conversation.isGroup) {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: context.adaptiveSecondaryGradient,
          borderRadius: BorderRadius.circular(16),
        ),
        child:
            photoUrl != null && photoUrl.isNotEmpty
                ? ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CachedNetworkImage(
                    imageUrl: photoUrl,
                    fit: BoxFit.cover,
                    width: 56,
                    height: 56,
                    placeholder: (_, __) => const Center(
                      child: Icon(
                        Icons.groups,
                        color: AppColors.white,
                        size: 26,
                      ),
                    ),
                    errorWidget:
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
            gradient: context.adaptivePrimaryGradient,
            borderRadius: BorderRadius.circular(16),
          ),
          child:
              photoUrl != null && photoUrl.isNotEmpty
                  ? ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CachedNetworkImage(
                      imageUrl: photoUrl,
                      fit: BoxFit.cover,
                      width: 56,
                      height: 56,
                      placeholder: (_, __) => Center(
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
        bool isRead = false;
        if (conversation.isIndividual) {
          final otherId = conversation.getOtherParticipantId(currentUserId);
          final otherUnread = conversation.unreadCount[otherId] ?? 0;
          isRead = otherUnread == 0;
        } else {
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
