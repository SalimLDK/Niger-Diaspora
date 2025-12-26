import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

import '../../../../core/theme/adaptive_colors.dart';
import '../../domain/entities/notification_entity.dart';

import '../providers/notification_provider.dart';
import '../../../../core/services/notification_service.dart';
import 'dart:convert';

class NotificationDetailScreen extends ConsumerWidget {
  final String notificationId;

  const NotificationDetailScreen({super.key, required this.notificationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final notificationsAsync = ref.watch(notificationsNotifierProvider);

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        title: Text(l10n.notificationDetail),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          notificationsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (notifications) {
              try {
                final notification = notifications.firstWhere(
                  (n) => n.id == notificationId,
                );
                return IconButton(
                  icon: const Icon(Icons.alarm),
                  tooltip: 'Me rappeler plus tard',
                  onPressed: () => _showReminderDialog(context, notification),
                );
              } catch (_) {
                return const SizedBox.shrink();
              }
            },
          ),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text(l10n.loadingError)),
        data: (notifications) {
          final notification = notifications.firstWhere(
            (n) => n.id == notificationId,
            orElse: () => throw Exception('Notification not found'),
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with icon and priority
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _getIconColor(
                          context,
                          notification.type,
                        ).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getIcon(notification.type),
                        color: _getIconColor(context, notification.type),
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getTypeLabel(notification.type, l10n),
                            style: TextStyle(
                              fontSize: 14,
                              color: context.textSecondaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (notification.createdAt != null)
                            Text(
                              DateFormat(
                                'dd MMMM yyyy, HH:mm',
                              ).format(notification.createdAt!),
                              style: TextStyle(
                                fontSize: 13,
                                color: context.textTertiaryColor,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (notification.priority == NotificationPriority.urgent ||
                        notification.priority == NotificationPriority.high)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              notification.priority ==
                                      NotificationPriority.urgent
                                  ? Colors.red.withValues(alpha: 0.1)
                                  : Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color:
                                notification.priority ==
                                        NotificationPriority.urgent
                                    ? Colors.red.withValues(alpha: 0.5)
                                    : Colors.orange.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.priority_high,
                              size: 14,
                              color:
                                  notification.priority ==
                                          NotificationPriority.urgent
                                      ? Colors.red
                                      : Colors.orange,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              notification.priority ==
                                      NotificationPriority.urgent
                                  ? 'URGENT'
                                  : 'HIGH',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color:
                                    notification.priority ==
                                            NotificationPriority.urgent
                                        ? Colors.red
                                        : Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),

                // Title
                Text(
                  notification.title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: context.textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 16),

                // Body
                Text(
                  notification.body,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    color: context.textPrimaryColor,
                  ),
                ),

                const SizedBox(height: 32),

                // Actions
                if (notification.targetId != null)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Similar navigation logic as in list
                        _handleNavigation(context, notification);
                      },
                      icon: const Icon(Icons.open_in_new),
                      label: Text(l10n.open),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: context.adaptivePrimaryColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),

                const SizedBox(height: 16),

                if (!notification.isRead)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ref
                            .read(notificationsNotifierProvider.notifier)
                            .markAsRead(notification.id);
                      },
                      icon: const Icon(Icons.mark_email_read),
                      label: Text(l10n.markAsRead),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () {
                      // Confirm deletion
                      ref
                          .read(notificationsNotifierProvider.notifier)
                          .deleteNotification(notification.id);
                      context.pop();
                    },
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    label: Text(
                      l10n.delete,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _handleNavigation(
    BuildContext context,
    NotificationEntity notification,
  ) {
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
          context.push('/profile/${notification.targetId}');
          break;
        case NotificationType.general:
          break;
      }
    }
  }

  IconData _getIcon(NotificationType type) {
    switch (type) {
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

  Color _getIconColor(BuildContext context, NotificationType type) {
    switch (type) {
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

  String _getTypeLabel(NotificationType type, AppLocalizations l10n) {
    // Ideally this should use l10n keys, for now mapping to simple strings or existing keys if available
    // Adding fallbacks or reusing title logic
    return type.name.toUpperCase();
  }

  void _showReminderDialog(
    BuildContext context,
    NotificationEntity notification,
  ) {
    showModalBottomSheet(
      context: context,
      builder:
          (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Me rappeler plus tard',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.timer_outlined),
                  title: const Text('Dans 1 heure'),
                  onTap: () {
                    NotificationService().scheduleNotification(
                      id: notification.hashCode,
                      title: 'Rappel: ${notification.title}',
                      body: notification.body,
                      scheduledDate: DateTime.now().add(
                        const Duration(hours: 1),
                      ),
                      payload: jsonEncode({
                        'type': 'reminder',
                        'targetId': notification.id,
                      }),
                    );
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Rappel programmé')),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.wb_sunny_outlined),
                  title: const Text('Demain matin (9h)'),
                  onTap: () {
                    final now = DateTime.now();
                    var scheduled = DateTime(
                      now.year,
                      now.month,
                      now.day + 1,
                      9,
                      0,
                    );
                    if (scheduled.isBefore(now)) {
                      scheduled = scheduled.add(const Duration(days: 1));
                    }
                    NotificationService().scheduleNotification(
                      id: notification.hashCode,
                      title: 'Rappel: ${notification.title}',
                      body: notification.body,
                      scheduledDate: scheduled,
                      payload: jsonEncode({
                        'type': 'reminder',
                        'targetId': notification.id,
                      }),
                    );
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Rappel programmé')),
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
    );
  }
}
