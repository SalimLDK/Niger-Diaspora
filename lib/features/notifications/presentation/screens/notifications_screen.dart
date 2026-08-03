import 'package:flutter/material.dart';
import '../../../../core/theme/design_kit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

import '../../../../shared/widgets/loading_indicator.dart';
import '../../domain/entities/notification_entity.dart';
import '../providers/notification_provider.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../../settings/presentation/providers/blocked_users_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../friends/domain/entities/friend_request_entity.dart';
import '../../../friends/presentation/providers/friend_provider.dart';

/// Trois filtres (refonte 12c) : Tout / Non lues / Mentions. « Mentions »
/// regroupe les notifications qui vous concernent personnellement (demandes
/// d'ami, abonnements, invitations, présence) — faute d'un type « mention »
/// dédié dans [NotificationType].
enum NotificationFilter { all, unread, mentions }

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final ScrollController _scrollController = ScrollController();
  NotificationFilter _currentFilter = NotificationFilter.all;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(notificationsStreamProvider);
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(notificationsNotifierProvider.notifier).loadMore();
    }
  }

  /// Groupement intelligent style WhatsApp
  /// - Messages: groupés par conversation
  /// - Groupes: groupés par groupe
  /// - Événements: groupés par événement
  /// - Amis: groupés ensemble
  List<dynamic> _groupNotifications(List<NotificationEntity> notifications) {
    if (notifications.isEmpty) return [];

    final groupedMap = <String, List<NotificationEntity>>{};

    // First pass: auto-generate groupKey if not present, then group
    for (var n in notifications) {
      final groupKey = n.groupKey ?? _autoGenerateGroupKey(n);
      groupedMap.putIfAbsent(groupKey, () => []).add(n);
    }

    final result = <dynamic>[];
    final processedGroups = <String>{};

    for (var n in notifications) {
      final groupKey = n.groupKey ?? _autoGenerateGroupKey(n);

      if (!processedGroups.contains(groupKey)) {
        final groupItems = groupedMap[groupKey]!;
        if (groupItems.length > 1) {
          result.add(
            _NotificationGroup(
              key: groupKey,
              notifications: groupItems,
              type: n.type,
            ),
          );
          processedGroups.add(groupKey);
        } else {
          result.add(n);
        }
      }
    }

    return result;
  }

  /// Génère automatiquement un groupKey basé sur le type de notification
  String _autoGenerateGroupKey(NotificationEntity n) {
    switch (n.type) {
      case NotificationType.message:
        // Grouper par conversation (senderId ou targetId)
        return 'messages_${n.senderId ?? n.targetId ?? 'unknown'}';
      case NotificationType.groupInvite:
      case NotificationType.groupJoinRequest:
      case NotificationType.groupRequestApproved:
      case NotificationType.groupRequestRejected:
      case NotificationType.newMember:
        return 'group_${n.targetId ?? 'unknown'}';
      case NotificationType.eventReminder:
      case NotificationType.eventUpdate:
      case NotificationType.eventAttendance:
        return 'event_${n.targetId ?? 'unknown'}';
      case NotificationType.friendRequest:
      case NotificationType.friendRequestAccepted:
      case NotificationType.friendAccepted:
      case NotificationType.newFollower:
        return 'friend_requests';
      case NotificationType.order:
      case NotificationType.newOrder:
      case NotificationType.orderPaid:
      case NotificationType.orderShipped:
      case NotificationType.orderDelivered:
      case NotificationType.orderCancelled:
      case NotificationType.orderCompleted:
        return 'order_${n.targetId ?? 'unknown'}';
      case NotificationType.localEvent:
      case NotificationType.nearbyMember:
      case NotificationType.proximityAlert:
        return 'location_alerts';
      case NotificationType.general:
        return 'general_${n.id}'; // Pas de groupement
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final notificationsAsync = ref.watch(notificationsNotifierProvider);
    final unreadCount =
        notificationsAsync.valueOrNull?.where((n) => !n.isRead).length ?? 0;

    return Scaffold(
      backgroundColor: context.backgroundColor,
      // En-tête plat (§12c) : grand titre serif, compte de non-lues, puis
      // « Tout lire » et les réglages. L'AppBar Material et sa flèche retour
      // disparaissent — l'écran est un onglet, pas une page empilée.
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            DesignScreenHeader(
              title: l10n.notificationsTitle,
              subtitle: unreadCount > 0
                  ? l10n.notificationsUnreadCount(unreadCount)
                  : '',
              actions: [
                if (unreadCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: TextButton(
                      onPressed: () => ref
                          .read(notificationsNotifierProvider.notifier)
                          .markAllAsRead(),
                      style: TextButton.styleFrom(
                        backgroundColor: context.surfaceVariantColor,
                        foregroundColor: context.textPrimaryColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(kDesignPillRadius),
                        ),
                      ),
                      child: Text(
                        l10n.markAllAsRead,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                DesignSquareAction(
                  icon: Icons.tune,
                  tooltip: l10n.settings,
                  onPressed: () => context.push('/notifications/settings'),
                ),
              ],
            ),
            _buildFilterBar(context, l10n, unreadCount),
            Expanded(
              child: _buildNotificationsList(
                context,
                ref,
                notificationsAsync,
                l10n,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Menu « tout supprimer », conservé hors de l'en-tête plat : c'est une
  /// action destructive, elle n'a pas sa place à côté de « Tout lire ».
  Widget buildOverflowMenu(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return PopupMenuButton<String>(
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
    );
  }

  Widget _buildNotificationsList(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<NotificationEntity>> notificationsAsync,
    AppLocalizations l10n,
  ) {
    // Get blocked users data outside the when callback
    final blockedUsers = ref.watch(blockedUsersProvider).valueOrNull ?? [];
    final blockedUserIds = blockedUsers.map((u) => u.id).toSet();
    final currentUserId = ref.watch(currentUserProvider).valueOrNull?.id;

    return notificationsAsync.when(
        skipLoadingOnRefresh: true,
        skipLoadingOnReload: true,
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
          // Notification types that have targetId as a user ID
          const userRelatedTypes = {
            NotificationType.friendRequest,
            NotificationType.friendRequestAccepted,
            NotificationType.friendAccepted,
            NotificationType.newFollower,
            NotificationType.nearbyMember,
            NotificationType.proximityAlert,
          };

          final notificationsWithoutBlocked = notifications.where((n) {
            // Filter message notifications by senderId
            if (n.type == NotificationType.message && n.senderId != null) {
              // If I blocked this user, hide their notifications
              if (blockedUserIds.contains(n.senderId)) return false;

              // Check if sender blocked me
              final senderProfileAsync = ref.watch(userStreamProvider(n.senderId!));
              final senderProfile = senderProfileAsync.valueOrNull;
              if (senderProfile != null && currentUserId != null) {
                if (senderProfile.blockedByUserIds.contains(currentUserId)) {
                  return false;
                }
              }
              return true;
            }

            // Only filter user-related notifications
            if (!userRelatedTypes.contains(n.type)) return true;
            if (n.targetId == null) return true;

            // If I blocked this user, hide their notifications
            if (blockedUserIds.contains(n.targetId)) return false;

            // Check if target user blocked me
            final targetProfileAsync = ref.watch(userStreamProvider(n.targetId!));
            final targetProfile = targetProfileAsync.valueOrNull;
            if (targetProfile != null && currentUserId != null) {
              if (targetProfile.blockedByUserIds.contains(currentUserId)) {
                return false;
              }
            }

            return true;
          }).toList();

          final filteredNotifications = _filterNotifications(notificationsWithoutBlocked);

          if (filteredNotifications.isEmpty) {
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

          final groupedItems = _groupNotifications(filteredNotifications);

          return ListView.separated(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: groupedItems.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (context, index) {
              final item = groupedItems[index];

              if (item is _NotificationGroup) {
                return _NotificationGroupItem(
                  group: item,
                  onTap: (n) => _handleNotificationTap(context, ref, n),
                  onLongPress:
                      () => context.push('/notifications/${item.summary.id}'),
                  onDelete: (n) {
                    ref
                        .read(notificationsNotifierProvider.notifier)
                        .deleteNotification(n.id);
                  },
                  onMarkAsRead: (n) {
                    ref
                        .read(notificationsNotifierProvider.notifier)
                        .markAsRead(n.id);
                  },
                );
              } else if (item is NotificationEntity) {
                return _NotificationItem(
                  notification: item,
                  onTap: () => _handleNotificationTap(context, ref, item),
                  onLongPress: () => context.push('/notifications/${item.id}'),
                  onDelete: () {
                    ref
                        .read(notificationsNotifierProvider.notifier)
                        .deleteNotification(item.id);
                  },
                  onMarkAsRead: () {
                    ref
                        .read(notificationsNotifierProvider.notifier)
                        .markAsRead(item.id);
                  },
                );
              }
              return const SizedBox.shrink();
            },
          );
        },
      );
  }

  /// Types « qui vous concernent » regroupés sous le filtre Mentions.
  static const _mentionTypes = {
    NotificationType.friendRequest,
    NotificationType.friendRequestAccepted,
    NotificationType.friendAccepted,
    NotificationType.newFollower,
    NotificationType.newMember,
    NotificationType.groupInvite,
    NotificationType.groupJoinRequest,
    NotificationType.eventAttendance,
    NotificationType.nearbyMember,
    NotificationType.proximityAlert,
  };

  List<NotificationEntity> _filterNotifications(
    List<NotificationEntity> notifications,
  ) {
    switch (_currentFilter) {
      case NotificationFilter.all:
        return notifications;
      case NotificationFilter.unread:
        return notifications.where((n) => !n.isRead).toList();
      case NotificationFilter.mentions:
        return notifications
            .where((n) => _mentionTypes.contains(n.type))
            .toList();
    }
  }

  /// Barre de trois filtres en puces (remplace les six onglets — refonte 12c).
  PreferredSizeWidget _buildFilterBar(
    BuildContext context,
    AppLocalizations l10n,
    int unreadCount,
  ) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(52),
      child: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Row(
          children: [
            _filterChip(context, l10n.all, NotificationFilter.all),
            const SizedBox(width: 8),
            _filterChip(
              context,
              l10n.filterUnread,
              NotificationFilter.unread,
              badge: unreadCount,
            ),
            const SizedBox(width: 8),
            _filterChip(context, l10n.mentions, NotificationFilter.mentions),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(
    BuildContext context,
    String label,
    NotificationFilter filter, {
    int badge = 0,
  }) {
    final active = _currentFilter == filter;
    return GestureDetector(
      onTap: () => setState(() => _currentFilter = filter),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? context.adaptivePrimaryColor
              : context.surfaceVariantColor,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                color: active ? Colors.white : context.textSecondaryColor,
              ),
            ),
            if (badge > 0) ...[
              const SizedBox(width: 6),
              Container(
                constraints: const BoxConstraints(minWidth: 18),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? Colors.white : context.adaptivePrimaryColor,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  badge > 99 ? '99+' : '$badge',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color:
                        active ? context.adaptivePrimaryColor : Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
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
    switch (notification.type) {
      // Location-based notifications -> navigate to map
      case NotificationType.localEvent:
      case NotificationType.nearbyMember:
      case NotificationType.proximityAlert:
        context.push('/map');
        break;
      case NotificationType.message:
        if (notification.targetId != null) {
          context.push('/messages/${notification.targetId}');
        }
        break;
      case NotificationType.groupInvite:
      case NotificationType.newMember:
      case NotificationType.groupJoinRequest:
      case NotificationType.groupRequestApproved:
      case NotificationType.groupRequestRejected:
        if (notification.targetId != null) {
          context.push('/groups/${notification.targetId}');
        }
        break;
      case NotificationType.eventReminder:
      case NotificationType.eventUpdate:
      case NotificationType.eventAttendance:
        if (notification.targetId != null) {
          context.push('/events/${notification.targetId}');
        }
        break;
      case NotificationType.newFollower:
      case NotificationType.friendRequest:
      case NotificationType.friendRequestAccepted:
      case NotificationType.friendAccepted:
        if (notification.targetId != null) {
          context.push('/profile/${notification.targetId}');
        }
        break;
      case NotificationType.order:
      case NotificationType.newOrder:
      case NotificationType.orderPaid:
      case NotificationType.orderShipped:
      case NotificationType.orderDelivered:
      case NotificationType.orderCancelled:
      case NotificationType.orderCompleted:
        // All order-related notifications go to my orders
        context.push('/marketplace/my-orders');
        break;
      case NotificationType.general:
        // No specific navigation
        break;
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

class _NotificationItem extends ConsumerWidget {
  final NotificationEntity notification;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onDelete;
  final VoidCallback onMarkAsRead;

  const _NotificationItem({
    required this.notification,
    required this.onTap,
    required this.onLongPress,
    required this.onDelete,
    required this.onMarkAsRead,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final timeAgo = _formatTimeAgo(notification.createdAt, l10n);

    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.horizontal,
      background: Container(
        color: Colors.green,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.mark_email_read, color: Colors.white),
      ),
      secondaryBackground: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Swipe Right: Mark as Read
          onMarkAsRead();
          return false; // Don't remove from list immediately (keep item)
          // Actually, if we mark as read, it stays in list but style changes.
          // Returning false keeps the item. Is that UX good?
          // Usually swipe to read logic: item stays but marks read.
        } else {
          // Swipe Left: Delete
          return true;
        }
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) {
          onDelete();
        }
      },
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
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
                        if (notification.priority ==
                            NotificationPriority.urgent) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: Colors.red.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.priority_high,
                                  size: 12,
                                  color: Colors.red,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'URGENT',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else if (notification.priority ==
                            NotificationPriority.high) ...[
                          Icon(
                            Icons.priority_high,
                            size: 16,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 4),
                        ],
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
                    // Actions en ligne pour une demande d'ami (§12c).
                    if (notification.type == NotificationType.friendRequest &&
                        notification.targetId != null) ...[
                      const SizedBox(height: 10),
                      _FriendRequestActions(
                        requesterId: notification.targetId!,
                        onResponded: onMarkAsRead,
                      ),
                    ],
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
      case NotificationType.eventAttendance:
        return Icons.event_available;
      case NotificationType.friendRequest:
        return Icons.person_add_alt;
      case NotificationType.friendRequestAccepted:
      case NotificationType.friendAccepted:
        return Icons.how_to_reg;
      case NotificationType.groupJoinRequest:
        return Icons.group_add;
      case NotificationType.groupRequestApproved:
        return Icons.check_circle_outline;
      case NotificationType.groupRequestRejected:
        return Icons.cancel_outlined;
      case NotificationType.general:
        return Icons.notifications_none;
      case NotificationType.localEvent:
        return Icons.location_on;
      case NotificationType.nearbyMember:
        return Icons.person_pin_circle;
      case NotificationType.proximityAlert:
        return Icons.radar;
      case NotificationType.order:
      case NotificationType.newOrder:
        return Icons.shopping_bag;
      case NotificationType.orderPaid:
        return Icons.payment;
      case NotificationType.orderShipped:
        return Icons.local_shipping;
      case NotificationType.orderDelivered:
        return Icons.check_circle;
      case NotificationType.orderCancelled:
        return Icons.cancel;
      case NotificationType.orderCompleted:
        return Icons.check_circle;
    }
  }

  Color _getIconColor(BuildContext context) {
    if (notification.isRead) {
      return context.textTertiaryColor.withValues(alpha: 0.5);
    }

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
      case NotificationType.eventAttendance:
        return Colors.teal;
      case NotificationType.friendRequest:
        return Colors.indigo;
      case NotificationType.friendRequestAccepted:
      case NotificationType.friendAccepted:
        return Colors.green;
      case NotificationType.groupJoinRequest:
        return Colors.deepPurple;
      case NotificationType.groupRequestApproved:
        return Colors.green;
      case NotificationType.groupRequestRejected:
        return Colors.red;
      case NotificationType.general:
        return context.textSecondaryColor;
      case NotificationType.localEvent:
        return Colors.red;
      case NotificationType.nearbyMember:
        return Colors.orange;
      case NotificationType.proximityAlert:
        return Colors.deepOrange;
      case NotificationType.order:
      case NotificationType.newOrder:
        return Colors.green;
      case NotificationType.orderPaid:
        return Colors.blue;
      case NotificationType.orderShipped:
        return Colors.purple;
      case NotificationType.orderDelivered:
        return Colors.green;
      case NotificationType.orderCancelled:
        return Colors.red;
      case NotificationType.orderCompleted:
        return Colors.green;
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

class _NotificationGroup {
  final String key;
  final List<NotificationEntity> notifications;
  final NotificationType type;

  _NotificationGroup({
    required this.key,
    required this.notifications,
    required this.type,
  });

  NotificationEntity get summary => notifications.first;

  /// Nombre de notifications non lues
  int get unreadCount => notifications.where((n) => !n.isRead).length;

  /// Titre du groupe style WhatsApp
  String getGroupTitle(AppLocalizations l10n) {
    switch (type) {
      case NotificationType.message:
        final senderNames = notifications
            .map((n) => n.title.split(':').first)
            .toSet()
            .toList();
        if (senderNames.length == 1) {
          return senderNames.first;
        }
        return '${notifications.length} messages';
      case NotificationType.groupInvite:
      case NotificationType.groupJoinRequest:
      case NotificationType.groupRequestApproved:
      case NotificationType.groupRequestRejected:
      case NotificationType.newMember:
        return l10n.groupsTitle;
      case NotificationType.eventReminder:
      case NotificationType.eventUpdate:
      case NotificationType.eventAttendance:
        return l10n.eventsTitle;
      case NotificationType.friendRequest:
      case NotificationType.friendRequestAccepted:
      case NotificationType.friendAccepted:
      case NotificationType.newFollower:
        return l10n.filterFriends;
      case NotificationType.order:
      case NotificationType.newOrder:
      case NotificationType.orderPaid:
      case NotificationType.orderShipped:
      case NotificationType.orderDelivered:
      case NotificationType.orderCancelled:
      case NotificationType.orderCompleted:
        return 'Commandes';
      case NotificationType.localEvent:
      case NotificationType.nearbyMember:
      case NotificationType.proximityAlert:
        return l10n.notifGroupProximity;
      case NotificationType.general:
        return 'Notifications';
    }
  }

  /// Sous-titre du groupe style WhatsApp
  String getGroupSubtitle(AppLocalizations l10n) {
    final count = notifications.length;
    switch (type) {
      case NotificationType.message:
        final senderNames = notifications
            .map((n) => n.title.split(':').first)
            .toSet()
            .toList();
        if (senderNames.length == 1) {
          return '$count nouveaux messages';
        }
        return l10n.notificationsGroupedMessages(count, senderNames.length);
      case NotificationType.friendRequest:
      case NotificationType.friendRequestAccepted:
      case NotificationType.friendAccepted:
      case NotificationType.newFollower:
        return '$count demandes d\'ami';
      default:
        return '$count notifications';
    }
  }

  /// Icône du groupe
  IconData getGroupIcon() {
    switch (type) {
      case NotificationType.message:
        return Icons.chat_bubble;
      case NotificationType.groupInvite:
      case NotificationType.groupJoinRequest:
      case NotificationType.groupRequestApproved:
      case NotificationType.groupRequestRejected:
      case NotificationType.newMember:
        return Icons.group;
      case NotificationType.eventReminder:
      case NotificationType.eventUpdate:
      case NotificationType.eventAttendance:
        return Icons.event;
      case NotificationType.friendRequest:
      case NotificationType.friendRequestAccepted:
      case NotificationType.friendAccepted:
      case NotificationType.newFollower:
        return Icons.person_add;
      case NotificationType.order:
      case NotificationType.newOrder:
      case NotificationType.orderPaid:
      case NotificationType.orderShipped:
      case NotificationType.orderDelivered:
      case NotificationType.orderCancelled:
      case NotificationType.orderCompleted:
        return Icons.shopping_bag;
      case NotificationType.localEvent:
      case NotificationType.nearbyMember:
      case NotificationType.proximityAlert:
        return Icons.location_on;
      case NotificationType.general:
        return Icons.notifications;
    }
  }
}

class _NotificationGroupItem extends StatefulWidget {
  final _NotificationGroup group;
  final Function(NotificationEntity) onTap;
  final VoidCallback onLongPress;
  final Function(NotificationEntity) onDelete;
  final Function(NotificationEntity) onMarkAsRead;

  const _NotificationGroupItem({
    required this.group,
    required this.onTap,
    required this.onLongPress,
    required this.onDelete,
    required this.onMarkAsRead,
  });

  @override
  State<_NotificationGroupItem> createState() => _NotificationGroupItemState();
}

class _NotificationGroupItemState extends State<_NotificationGroupItem>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final unreadCount = widget.group.unreadCount;
    final groupTitle = widget.group.getGroupTitle(l10n);
    final groupSubtitle = widget.group.getGroupSubtitle(l10n);
    final groupIcon = widget.group.getGroupIcon();
    final latestNotification = widget.group.notifications.first;

    // Couleur basée sur le type
    final iconColor = _getIconColorForType(context, widget.group.type, unreadCount > 0);

    return Container(
      decoration: BoxDecoration(
        color: unreadCount > 0
            ? context.adaptivePrimaryColor.withValues(alpha: 0.05)
            : context.surfaceColor,
        border: Border(
          bottom: BorderSide(
            color: context.dividerColor.withValues(alpha: 0.5),
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        children: [
          // Header style WhatsApp
          InkWell(
            onTap: _toggleExpanded,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Icône avec badge de compteur (style WhatsApp)
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: iconColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(26),
                        ),
                        child: Icon(
                          groupIcon,
                          color: iconColor,
                          size: 26,
                        ),
                      ),
                      // Badge compteur style WhatsApp
                      if (unreadCount > 0)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF25D366), // Vert WhatsApp
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: context.surfaceColor,
                                width: 2,
                              ),
                            ),
                            constraints: const BoxConstraints(minWidth: 20),
                            child: Text(
                              unreadCount > 99 ? '99+' : unreadCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
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
                                groupTitle,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: unreadCount > 0
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: context.textPrimaryColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              _timeAgo(latestNotification.createdAt),
                              style: TextStyle(
                                fontSize: 12,
                                color: unreadCount > 0
                                    ? const Color(0xFF25D366)
                                    : context.textTertiaryColor,
                                fontWeight: unreadCount > 0
                                    ? FontWeight.w500
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                groupSubtitle,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: context.textSecondaryColor,
                                  fontWeight: unreadCount > 0
                                      ? FontWeight.w500
                                      : FontWeight.normal,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            AnimatedRotation(
                              turns: _isExpanded ? 0.5 : 0,
                              duration: const Duration(milliseconds: 200),
                              child: Icon(
                                Icons.keyboard_arrow_down,
                                color: context.textTertiaryColor,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                        // Aperçu du dernier message (style WhatsApp)
                        const SizedBox(height: 2),
                        Text(
                          latestNotification.body,
                          style: TextStyle(
                            fontSize: 13,
                            color: context.textTertiaryColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Liste expansible avec animation
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: Column(
              children: [
                // Séparateur
                Container(
                  margin: const EdgeInsets.only(left: 82),
                  height: 1,
                  color: context.dividerColor.withValues(alpha: 0.3),
                ),
                // Notifications individuelles
                ...widget.group.notifications.map((notification) {
                  return _CompactNotificationItem(
                    notification: notification,
                    onTap: () => widget.onTap(notification),
                    onDelete: () => widget.onDelete(notification),
                    onMarkAsRead: () => widget.onMarkAsRead(notification),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getIconColorForType(BuildContext context, NotificationType type, bool isUnread) {
    if (!isUnread) {
      return context.textTertiaryColor;
    }
    switch (type) {
      case NotificationType.message:
        return const Color(0xFF25D366); // Vert WhatsApp
      case NotificationType.friendRequest:
      case NotificationType.friendRequestAccepted:
      case NotificationType.friendAccepted:
      case NotificationType.newFollower:
        return Colors.blue;
      case NotificationType.groupInvite:
      case NotificationType.groupJoinRequest:
      case NotificationType.groupRequestApproved:
      case NotificationType.groupRequestRejected:
      case NotificationType.newMember:
        return Colors.purple;
      case NotificationType.eventReminder:
      case NotificationType.eventUpdate:
      case NotificationType.eventAttendance:
        return Colors.orange;
      case NotificationType.order:
      case NotificationType.newOrder:
      case NotificationType.orderPaid:
      case NotificationType.orderShipped:
      case NotificationType.orderDelivered:
      case NotificationType.orderCancelled:
      case NotificationType.orderCompleted:
        return Colors.teal;
      default:
        return context.adaptivePrimaryColor;
    }
  }

  String _timeAgo(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 7) {
      return DateFormat('dd/MM/yyyy').format(date);
    } else if (difference.inDays >= 1) {
      return '${difference.inDays}j';
    } else if (difference.inHours >= 1) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes >= 1) {
      return '${difference.inMinutes}m';
    } else {
      return 'maintenant';
    }
  }
}

/// Widget compact pour les notifications dans un groupe (style WhatsApp)
class _CompactNotificationItem extends ConsumerWidget {
  final NotificationEntity notification;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onMarkAsRead;

  const _CompactNotificationItem({
    required this.notification,
    required this.onTap,
    required this.onDelete,
    required this.onMarkAsRead,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: ValueKey('compact_${notification.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete, color: Colors.white, size: 20),
      ),
      onDismissed: (_) => onDelete(),
      child: InkWell(
        onTap: () {
          if (!notification.isRead) {
            onMarkAsRead();
          }
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          margin: const EdgeInsets.only(left: 66),
          decoration: BoxDecoration(
            color: notification.isRead
                ? Colors.transparent
                : context.adaptivePrimaryColor.withValues(alpha: 0.03),
            border: Border(
              bottom: BorderSide(
                color: context.dividerColor.withValues(alpha: 0.2),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              // Point indicateur non lu
              if (!notification.isRead)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: const BoxDecoration(
                    color: Color(0xFF25D366),
                    shape: BoxShape.circle,
                  ),
                )
              else
                const SizedBox(width: 16),

              // Contenu
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: notification.isRead
                            ? FontWeight.normal
                            : FontWeight.w500,
                        color: context.textPrimaryColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      notification.body,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.textSecondaryColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Actions en ligne pour une demande d'ami (§12c).
                    if (notification.type == NotificationType.friendRequest &&
                        notification.targetId != null) ...[
                      const SizedBox(height: 8),
                      _FriendRequestActions(
                        requesterId: notification.targetId!,
                        onResponded: onMarkAsRead,
                      ),
                    ],
                  ],
                ),
              ),

              // Heure
              Text(
                _formatTime(notification.createdAt),
                style: TextStyle(
                  fontSize: 11,
                  color: context.textTertiaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime? date) {
    if (date == null) return '';
    return DateFormat('HH:mm').format(date);
  }
}

/// Boutons Accepter / Refuser en ligne sur une notification de demande d'ami
/// (§12c). La notification ne porte que l'id de l'expéditeur ([requesterId]) —
/// on retrouve la demande en attente correspondante dans
/// [receivedFriendRequestsProvider] pour obtenir son id. Quand la demande est
/// traitée, elle quitte le flux et les boutons disparaissent d'eux-mêmes.
class _FriendRequestActions extends ConsumerStatefulWidget {
  final String requesterId;
  final VoidCallback onResponded;

  const _FriendRequestActions({
    required this.requesterId,
    required this.onResponded,
  });

  @override
  ConsumerState<_FriendRequestActions> createState() =>
      _FriendRequestActionsState();
}

class _FriendRequestActionsState extends ConsumerState<_FriendRequestActions> {
  bool _busy = false;

  FriendRequestEntity? _pendingRequest(List<FriendRequestEntity> requests) {
    for (final r in requests) {
      if (r.senderId == widget.requesterId &&
          r.status == FriendRequestStatus.pending) {
        return r;
      }
    }
    return null;
  }

  Future<void> _respond(FriendRequestEntity request, bool accept) async {
    if (_busy) return;
    setState(() => _busy = true);

    final notifier = ref.read(friendRequestNotifierProvider.notifier);
    final ok =
        accept
            ? await notifier.acceptRequest(request.id, senderId: request.senderId)
            : await notifier.declineRequest(
              request.id,
              senderId: request.senderId,
            );

    if (!mounted) return;
    setState(() => _busy = false);

    if (ok) {
      widget.onResponded();
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(accept ? l10n.requestAccepted : l10n.requestDeclined),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final requests =
        ref.watch(receivedFriendRequestsProvider).valueOrNull ?? [];
    final request = _pendingRequest(requests);

    // Plus de demande en attente (déjà traitée ailleurs) : rien à afficher.
    if (request == null) return const SizedBox.shrink();

    return Row(
      children: [
        SizedBox(
          height: 34,
          child: ElevatedButton(
            onPressed: _busy ? null : () => _respond(request, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.adaptivePrimaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            child:
                _busy
                    ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                    : Text(
                      l10n.acceptRequest,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 34,
          child: OutlinedButton(
            onPressed: _busy ? null : () => _respond(request, false),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.textSecondaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              side: BorderSide(color: context.borderColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            child: Text(
              l10n.declineRequest,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}
