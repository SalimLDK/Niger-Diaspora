import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

import '../../../../shared/widgets/loading_indicator.dart';
import '../../domain/entities/notification_entity.dart';
import '../providers/notification_provider.dart';
import '../../../../core/theme/adaptive_colors.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final notificationsAsync = ref.watch(notificationsNotifierProvider);

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        title: Text(l10n.notificationsTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'mark_all':
                  ref
                      .read(notificationsNotifierProvider.notifier)
                      .markAllAsRead();
                  break;
                case 'delete_all':
                  _confirmDeleteAll(context, ref);
                  break;
              }
            },
            itemBuilder:
                (ctx) => [
                  PopupMenuItem(
                    value: 'mark_all',
                    child: Row(
                      children: [
                        const Icon(Icons.done_all, size: 20),
                        const SizedBox(width: 12),
                        Text(l10n.markAllAsRead),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete_all',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.delete_sweep,
                          size: 20,
                          color: Colors.red,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          l10n.deleteAll,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ],
          ),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const Center(child: LoadingIndicator()),
        error:
            (error, _) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: context.textTertiaryColor.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.loadingError,
                    style: TextStyle(color: context.textTertiaryColor),
                  ),
                ],
              ),
            ),
        data: (notifications) {
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 80,
                    color: context.textTertiaryColor.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.noNotifications,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: context.textTertiaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.noNotificationsHint,
                    style: TextStyle(
                      fontSize: 14,
                      color: context.textTertiaryColor,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return _NotificationItem(
                notification: notification,
                onTap: () => _handleNotificationTap(context, ref, notification),
                onDismiss: () {
                  ref
                      .read(notificationsNotifierProvider.notifier)
                      .deleteNotification(notification.id);
                },
              );
            },
          );
        },
      ),
    );
  }

  void _handleNotificationTap(
    BuildContext context,
    WidgetRef ref,
    NotificationEntity notification,
  ) {
    // Mark as read
    if (!notification.isRead) {
      ref
          .read(notificationsNotifierProvider.notifier)
          .markAsRead(notification.id);
    }

    // Navigate based on type
    if (notification.targetId != null) {
      switch (notification.type) {
        case NotificationType.message:
          context.push('/messages/${notification.targetId}');
          break;
        case NotificationType.groupInvite:
        case NotificationType.newMember:
        case NotificationType.groupJoinRequest:
        case NotificationType.groupRequestApproved:
        case NotificationType.groupRequestRejected:
          context.push('/groups/${notification.targetId}');
          break;
        case NotificationType.eventReminder:
        case NotificationType.eventUpdate:
          context.push('/events/${notification.targetId}');
          break;
        case NotificationType.newFollower:
        case NotificationType.friendRequest:
        case NotificationType.friendRequestAccepted:
          // Navigate to profile
          context.push('/profile/${notification.targetId}');
          break;
        case NotificationType.general:
          // No specific navigation
          break;
      }
    }
  }

  void _confirmDeleteAll(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(l10n.deleteAllNotifications),
            content: Text(l10n.deleteAllNotificationsConfirm),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.cancel),
              ),
              ElevatedButton(
                onPressed: () {
                  ref
                      .read(notificationsNotifierProvider.notifier)
                      .deleteAllNotifications();
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: Text(l10n.delete),
              ),
            ],
          ),
    );
  }
}

class _NotificationItem extends StatelessWidget {
  final NotificationEntity notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _NotificationItem({
    required this.notification,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final timeAgo = _formatTimeAgo(notification.createdAt, l10n);

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color:
                notification.isRead
                    ? Colors.transparent
                    : context.adaptivePrimaryColor.withValues(alpha: 0.05),
            border: Border(
              bottom: BorderSide(
                color: context.surfaceVariantColor.withValues(alpha: 0.5),
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _getIconColor(context).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _getIcon(),
                  color: _getIconColor(context),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight:
                                  notification.isRead
                                      ? FontWeight.normal
                                      : FontWeight.w600,
                              color: context.textPrimaryColor,
                            ),
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: context.adaptivePrimaryColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.textSecondaryColor,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      timeAgo,
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
    );
  }

  IconData _getIcon() {
    switch (notification.type) {
      case NotificationType.message:
        return Icons.chat_bubble_outline;
      case NotificationType.groupInvite:
        return Icons.group_add;
      case NotificationType.eventReminder:
        return Icons.event;
      case NotificationType.newFollower:
        return Icons.person_add;
      case NotificationType.newMember:
        return Icons.person;
      case NotificationType.eventUpdate:
        return Icons.update;
      case NotificationType.friendRequest:
        return Icons.person_add_alt;
      case NotificationType.friendRequestAccepted:
        return Icons.how_to_reg;
      case NotificationType.groupJoinRequest:
        return Icons.group_add;
      case NotificationType.groupRequestApproved:
        return Icons.check_circle_outline;
      case NotificationType.groupRequestRejected:
        return Icons.cancel_outlined;
      case NotificationType.general:
        return Icons.notifications_none;
    }
  }

  Color _getIconColor(BuildContext context) {
    switch (notification.type) {
      case NotificationType.message:
        return context.adaptivePrimaryColor;
      case NotificationType.groupInvite:
        return Colors.purple;
      case NotificationType.eventReminder:
        return context.adaptiveSecondaryColor;
      case NotificationType.newFollower:
        return Colors.blue;
      case NotificationType.newMember:
        return Colors.teal;
      case NotificationType.eventUpdate:
        return Colors.amber;
      case NotificationType.friendRequest:
        return Colors.indigo;
      case NotificationType.friendRequestAccepted:
        return Colors.green;
      case NotificationType.groupJoinRequest:
        return Colors.deepPurple;
      case NotificationType.groupRequestApproved:
        return Colors.green;
      case NotificationType.groupRequestRejected:
        return Colors.red;
      case NotificationType.general:
        return context.textSecondaryColor;
    }
  }

  String _formatTimeAgo(DateTime? dateTime, AppLocalizations l10n) {
    if (dateTime == null) return '';

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return l10n.justNow;
    } else if (difference.inMinutes < 60) {
      return l10n.minutesAgo(difference.inMinutes);
    } else if (difference.inHours < 24) {
      return l10n.hoursAgo(difference.inHours);
    } else if (difference.inDays < 7) {
      return l10n.daysAgo(difference.inDays);
    } else {
      return DateFormat('dd/MM/yyyy').format(dateTime);
    }
  }
}
