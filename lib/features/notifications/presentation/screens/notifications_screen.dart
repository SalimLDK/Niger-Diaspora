import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

import '../../../../shared/widgets/loading_indicator.dart';
import '../../domain/entities/notification_entity.dart';
import '../providers/notification_provider.dart';
import '../../../../core/theme/adaptive_colors.dart';

enum NotificationFilter { all, unread, messages, events, friends, groups }

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  NotificationFilter _currentFilter = NotificationFilter.all;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _currentFilter = NotificationFilter.values[_tabController.index];
        });
      }
    });

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

  List<dynamic> _groupNotifications(List<NotificationEntity> notifications) {
    if (notifications.isEmpty) return [];

    final groupedMap = <String, List<NotificationEntity>>{};

    // First pass: key-based grouping
    for (var n in notifications) {
      if (n.groupKey != null) {
        groupedMap.putIfAbsent(n.groupKey!, () => []).add(n);
      }
    }

    final result = <dynamic>[];
    final processedGroups = <String>{};

    for (var n in notifications) {
      if (n.groupKey != null) {
        if (!processedGroups.contains(n.groupKey)) {
          final groupItems = groupedMap[n.groupKey!]!;
          if (groupItems.length > 1) {
            result.add(
              _NotificationGroup(key: n.groupKey!, notifications: groupItems),
            );
            processedGroups.add(n.groupKey!);
          } else {
            result.add(n);
          }
        }
      } else {
        result.add(n);
      }
    }

    return result;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/notifications/settings'),
            tooltip: l10n.settings,
          ),
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
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: context.adaptivePrimaryColor,
          labelColor: context.adaptivePrimaryColor,
          unselectedLabelColor: context.textSecondaryColor,
          tabs: [
            Tab(text: l10n.all),
            Tab(text: l10n.filterUnread),
            Tab(text: l10n.messagesTitle),
            Tab(text: l10n.eventsTitle),
            Tab(text: l10n.filterFriends),
            Tab(text: l10n.groupsTitle),
          ],
        ),
      ),
      body: notificationsAsync.when(
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
          final filteredNotifications = _filterNotifications(notifications);

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
      ),
    );
  }

  List<NotificationEntity> _filterNotifications(
    List<NotificationEntity> notifications,
  ) {
    switch (_currentFilter) {
      case NotificationFilter.all:
        return notifications;
      case NotificationFilter.unread:
        return notifications.where((n) => !n.isRead).toList();
      case NotificationFilter.messages:
        return notifications
            .where((n) => n.type == NotificationType.message)
            .toList();
      case NotificationFilter.events:
        return notifications
            .where(
              (n) =>
                  n.type == NotificationType.eventReminder ||
                  n.type == NotificationType.eventUpdate,
            )
            .toList();
      case NotificationFilter.friends:
        return notifications
            .where(
              (n) =>
                  n.type == NotificationType.friendRequest ||
                  n.type == NotificationType.friendRequestAccepted ||
                  n.type == NotificationType.newFollower,
            )
            .toList();
      case NotificationFilter.groups:
        return notifications
            .where(
              (n) =>
                  n.type == NotificationType.groupInvite ||
                  n.type == NotificationType.groupJoinRequest ||
                  n.type == NotificationType.groupRequestApproved ||
                  n.type == NotificationType.groupRequestRejected ||
                  n.type == NotificationType.newMember,
            )
            .toList();
    }
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
  Widget build(BuildContext context) {
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

class _NotificationGroup {
  final String key;
  final List<NotificationEntity> notifications;

  _NotificationGroup({required this.key, required this.notifications});

  NotificationEntity get summary => notifications.first;
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

class _NotificationGroupItemState extends State<_NotificationGroupItem> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final summary = widget.group.summary;
    final unreadCount =
        widget.group.notifications.where((n) => !n.isRead).length;

    return Container(
      decoration: BoxDecoration(
        color:
            unreadCount > 0
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
          // Header / Summary Item
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stacked Icon look
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: context.surfaceColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.layers, // Stack icon
                          color: context.adaptivePrimaryColor,
                          size: 24,
                        ),
                      ),
                    ],
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
                                '${widget.group.notifications.length} notifications', // Customize based on type later
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: context.textPrimaryColor,
                                ),
                              ),
                            ),
                            if (unreadCount > 0)
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: context.adaptivePrimaryColor,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  unreadCount.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          summary.body, // Show latest body as preview
                          style: TextStyle(
                            fontSize: 13,
                            color: context.textSecondaryColor,
                            height: 1.4,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _timeAgo(summary.createdAt), // Helper function needed
                          style: TextStyle(
                            fontSize: 12,
                            color: context.textTertiaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: context.textTertiaryColor,
                  ),
                ],
              ),
            ),
          ),

          // Expanded Children
          if (_isExpanded)
            Column(
              children:
                  widget.group.notifications.map((notification) {
                    return Padding(
                      padding: const EdgeInsets.only(left: 32),
                      child: _NotificationItem(
                        notification: notification,
                        onTap: () => widget.onTap(notification),
                        onLongPress: widget.onLongPress,
                        onDelete: () => widget.onDelete(notification),
                        onMarkAsRead: () => widget.onMarkAsRead(notification),
                      ),
                    );
                  }).toList(),
            ),
        ],
      ),
    );
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
      return '${difference.inMinutes} min';
    } else {
      return 'À l\'instant';
    }
  }
}
