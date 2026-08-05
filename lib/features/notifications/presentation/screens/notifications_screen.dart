import 'package:flutter/material.dart';
import '../../../../core/theme/design_kit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

import '../../../../shared/widgets/loading_indicator.dart';
import '../../domain/entities/notification_entity.dart';
import '../providers/notification_provider.dart';
import '../widgets/notification_style.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../../settings/presentation/providers/blocked_users_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../events/presentation/providers/event_provider.dart';
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
      // En-tête plat (§12c) : grand titre serif, compte de non-lues, la
      // pastille « Tout lire » et un contrôle. L'AppBar Material et sa flèche
      // retour disparaissent — l'écran est un onglet, pas une page empilée.
      //
      // Le libellé est **« Tout lire »**, pas `l10n.markAllAsRead` (« Tout
      // marquer comme lu »). Ces 21 caractères prenaient ~410 px et ne
      // laissaient que ~230 px au titre : « Notifications » en Playfair 30 se
      // coupait au milieu du mot (« Notific / ations ») sur SM A515F à
      // `font_scale` 1.1. La maquette 12c répond par un libellé court, pas en
      // cachant l'action — c'est le geste courant de l'écran, il reste visible.
      // Le second contrôle est le **bouton rond ⚙ de la fiche**, qui va droit
      // aux réglages (20d) — pas un menu ⋯. « Tout supprimer » n'a donc plus
      // sa place ici : il a déménagé au bas de l'écran de réglages, seul
      // endroit de la fiche où une action destructive sur les notifications
      // ait un sens. Il était injoignable avant ce lot ; il ne l'est pas
      // redevenu.
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
                    padding: const EdgeInsets.only(right: 8),
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
                      child: const Text(
                        'Tout lire',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                _SettingsAction(
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
          // §12c : la liste se lit par tranches de temps
          // (« AUJOURD'HUI », « CETTE SEMAINE », puis le mois). Le
          // sectionnement vient après le regroupement : un groupe se range
          // sous la tranche de sa notification la plus récente.
          final sections = _sectionByDate(groupedItems);

          return ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            itemCount: sections.length,
            itemBuilder: (context, index) {
              final section = sections[index];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DesignSectionLabel(section.label),
                  for (final item in section.items) ...[
                    _buildItem(context, ref, item),
                    const SizedBox(height: 8),
                  ],
                ],
              );
            },
          );
        },
      );
  }

  Widget _buildItem(BuildContext context, WidgetRef ref, Object item) {
    if (item is _NotificationGroup) {
      return _NotificationGroupItem(
        key: ValueKey('group_${item.key}'),
        group: item,
        onTap: (n) => _handleNotificationTap(context, ref, n),
        onLongPress: () => context.push('/notifications/${item.summary.id}'),
        onDelete: (n) {
          ref
              .read(notificationsNotifierProvider.notifier)
              .deleteNotification(n.id);
        },
        onMarkAsRead: (n) {
          ref.read(notificationsNotifierProvider.notifier).markAsRead(n.id);
        },
      );
    }
    if (item is NotificationEntity) {
      return _NotificationItem(
        key: ValueKey('item_${item.id}'),
        notification: item,
        onTap: () => _handleNotificationTap(context, ref, item),
        onLongPress: () => context.push('/notifications/${item.id}'),
        onDelete: () {
          ref
              .read(notificationsNotifierProvider.notifier)
              .deleteNotification(item.id);
        },
        onMarkAsRead: () {
          ref.read(notificationsNotifierProvider.notifier).markAsRead(item.id);
        },
      );
    }
    return const SizedBox.shrink();
  }

  /// Découpe la liste déjà regroupée en tranches de temps (§12c).
  ///
  /// L'ordre des éléments est conservé tel quel — le flux arrive déjà trié du
  /// plus récent au plus ancien, et re-trier ici ferait diverger l'affichage
  /// de la pagination.
  List<({String label, List<Object> items})> _sectionByDate(
    List<dynamic> items,
  ) {
    final sections = <({String label, List<Object> items})>[];
    for (final item in items) {
      final label = _sectionLabel(_itemDate(item));
      if (sections.isEmpty || sections.last.label != label) {
        sections.add((label: label, items: <Object>[]));
      }
      sections.last.items.add(item as Object);
    }
    return sections;
  }

  DateTime? _itemDate(Object item) {
    if (item is _NotificationGroup) return item.summary.createdAt;
    if (item is NotificationEntity) return item.createdAt;
    return null;
  }

  String _sectionLabel(DateTime? date) {
    if (date == null) return 'PLUS ANCIEN';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final ecart = today.difference(day).inDays;
    if (ecart <= 0) return 'AUJOURD\'HUI';
    if (ecart == 1) return 'HIER';
    if (ecart < 7) return 'CETTE SEMAINE';
    if (ecart < 30) return 'CE MOIS-CI';
    return 'PLUS ANCIEN';
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
              // « notifications » est féminin : filterUnread reste au
              // masculin pour la messagerie, qui filtre des messages.
              l10n.filterUnreadFeminine,
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
        // Puce active en **encre** (#1C1815), pas en accent (fiche 12c) :
        // l'accent est déjà celui des pastilles et du compteur, l'empiler
        // ferait trois terracotta différents sur la même bande.
        decoration: BoxDecoration(
          color: active ? context.textPrimaryColor : context.surfaceVariantColor,
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
                color: active
                    ? context.backgroundColor
                    : context.textSecondaryColor,
              ),
            ),
            if (badge > 0) ...[
              const SizedBox(width: 6),
              Container(
                constraints: const BoxConstraints(minWidth: 18),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                alignment: Alignment.center,
                // Compteur en rouge d'alerte (#C23E2D) dans les deux états —
                // c'est un décompte de retard, pas une décoration de puce.
                decoration: BoxDecoration(
                  color: context.errorColor,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  badge > 99 ? '99+' : '$badge',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
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

}

/// Bouton ⚙ de l'en-tête (fiche 12c) : rond de 42, il va droit aux réglages
/// de notifications (20d).
///
/// Il remplace le menu ⋯ que j'avais posé pour loger « Tout supprimer » : la
/// fiche ne prévoit qu'un contrôle ici, et une action destructive n'a pas à
/// partager une pastille avec un raccourci de navigation. « Tout supprimer »
/// vit désormais au bas de l'écran de réglages.
class _SettingsAction extends StatelessWidget {
  final VoidCallback onPressed;

  const _SettingsAction({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Material(
      color: context.surfaceColor,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Tooltip(
          message: l10n.settings,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: context.borderColor),
            ),
            child: Icon(Icons.tune, size: 19, color: context.textPrimaryColor),
          ),
        ),
      ),
    );
  }
}

/// Une notification isolée, dans l'un des **deux registres** de la maquette
/// 12c : carte tant qu'elle n'est pas lue, ligne nue une fois lue.
///
/// C'est la hiérarchie que l'écran n'avait pas — tout y était rendu pareil,
/// avec pour seule différence un fond teinté à 5 % d'opacité qui ne se voyait
/// pas. Ici la non-lue prend une carte, un pictogramme plein et un point
/// d'accent ; la lue redevient une ligne discrète.
class _NotificationItem extends ConsumerWidget {
  final NotificationEntity notification;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onDelete;
  final VoidCallback onMarkAsRead;

  const _NotificationItem({
    super.key,
    required this.notification,
    required this.onTap,
    required this.onLongPress,
    required this.onDelete,
    required this.onMarkAsRead,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return Dismissible(
      key: ValueKey('dismiss_${notification.id}'),
      direction: DismissDirection.horizontal,
      background: _SwipeBackground(
        color: context.successColor,
        icon: Icons.mark_email_read_outlined,
        label: l10n.markAsRead,
        alignment: Alignment.centerLeft,
      ),
      secondaryBackground: _SwipeBackground(
        color: context.errorColor,
        icon: Icons.delete_outline,
        label: l10n.delete,
        alignment: Alignment.centerRight,
      ),
      confirmDismiss: (direction) async {
        // Balayage à droite : marquer lu. La ligne reste — elle change de
        // registre au lieu de disparaître, c'est justement ce que la nouvelle
        // hiérarchie rend visible.
        if (direction == DismissDirection.startToEnd) {
          onMarkAsRead();
          return false;
        }
        return true;
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) onDelete();
      },
      child: notification.isRead
          ? _ReadRow(
              notification: notification,
              onTap: onTap,
              onLongPress: onLongPress,
            )
          : _UnreadCard(
              notification: notification,
              onTap: onTap,
              onLongPress: onLongPress,
              onMarkAsRead: onMarkAsRead,
            ),
    );
  }
}

/// Registre « non lue » (§12c) : carte tramée, pictogramme carré plein 44 au
/// rayon 12, titre gras, corps, horodatage en chasse fixe, point d'accent.
class _UnreadCard extends StatelessWidget {
  final NotificationEntity notification;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onMarkAsRead;

  const _UnreadCard({
    required this.notification,
    required this.onTap,
    required this.onLongPress,
    required this.onMarkAsRead,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(kNotificationCardRadius),
        child: Container(
          padding: const EdgeInsets.all(14),
          // La carte est **uniforme** (§12c, fiche : fond #FBF1E9, bordure
          // #F0DCCB, rayon 16) : c'est le pictogramme qui porte la teinte de
          // famille, pas la carte. Teinter les deux donnait six fonds
          // différents dans une même section.
          decoration: BoxDecoration(
            color: context.adaptivePrimaryColor.withValues(
              alpha: context.isDarkMode ? 0.09 : 0.05,
            ),
            borderRadius: BorderRadius.circular(kNotificationCardRadius),
            border: Border.all(
              color: context.adaptivePrimaryColor.withValues(alpha: 0.16),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TypeBadge(type: notification.type, filled: true),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (notification.priority ==
                            NotificationPriority.urgent) ...[
                          _UrgentTag(),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              height: 1.25,
                              color: context.textPrimaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Le point de non-lu de la maquette (9 px).
                        Container(
                          margin: const EdgeInsets.only(top: 6),
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: context.adaptivePrimaryColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    if (notification.body.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        notification.body,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: context.textSecondaryColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 7),
                    _Stamp(date: notification.createdAt),
                    _InlineActions(
                      notification: notification,
                      onHandled: onMarkAsRead,
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
}

/// Registre « lue » (§12c) : plus de carte, pastille ronde éteinte, titre
/// normal et le jour en chasse fixe à la place de l'horodatage relatif.
class _ReadRow extends StatelessWidget {
  final NotificationEntity notification;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ReadRow({
    required this.notification,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Row(
            children: [
              _TypeBadge(type: notification.type, filled: false),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        height: 1.25,
                        color: context.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _Stamp(date: notification.createdAt),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pastille de famille, 38 px dans les deux registres (fiche 12c) : pleine et
/// teintée par type quand la notification n'est pas lue, fond neutre #F5F0E8
/// (`surfaceVariant`) quand elle l'est. Seule la teinte distingue les deux —
/// la taille reste constante pour que la colonne de texte ne bouge pas.
class _TypeBadge extends StatelessWidget {
  final NotificationType type;
  final bool filled;

  const _TypeBadge({required this.type, required this.filled});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: filled
            ? notificationTint(context, type)
            : context.surfaceVariantColor,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(
        notificationIcon(type),
        size: 18,
        color: filled ? context.onPrimaryColor : context.textTertiaryColor,
      ),
    );
  }
}

/// Horodatage en chasse fixe capitale (« IL Y A 12 MIN », « HIER »).
class _Stamp extends StatelessWidget {
  final DateTime? date;

  const _Stamp({required this.date});

  @override
  Widget build(BuildContext context) {
    final texte = notificationStamp(context, date);
    if (texte.isEmpty) return const SizedBox.shrink();
    return Text(
      texte,
      style: GoogleFonts.robotoMono(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.9,
        // #A79C8E — un cran plus clair que le texte tertiaire : l'horodatage
        // se lit en dernier.
        color: context.textDisabledColor,
      ),
    );
  }
}

/// Étiquette « URGENT ».
class _UrgentTag extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: context.errorColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        'URGENT',
        style: GoogleFonts.robotoMono(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: context.errorColor,
        ),
      ),
    );
  }
}

/// Fond de balayage : couleur pleine, pictogramme et libellé.
class _SwipeBackground extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final Alignment alignment;

  const _SwipeBackground({
    required this.color,
    required this.icon,
    required this.label,
    required this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(kDesignRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Actions en ligne de la maquette 12c.
///
/// Deux familles seulement, celles dont la maquette montre les boutons :
/// « Accepter / Refuser » sur une demande d'ami, « J'y vais / Voir » sur un
/// événement. Rien pour les autres types — un bouton qui ne fait rien coûte
/// plus cher que pas de bouton.
class _InlineActions extends StatelessWidget {
  final NotificationEntity notification;
  final VoidCallback onHandled;

  const _InlineActions({required this.notification, required this.onHandled});

  @override
  Widget build(BuildContext context) {
    if (notification.targetId == null) return const SizedBox.shrink();

    switch (notification.type) {
      case NotificationType.friendRequest:
        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: _FriendRequestActions(
            requesterId: notification.targetId!,
            onResponded: onHandled,
          ),
        );
      case NotificationType.eventReminder:
      case NotificationType.eventUpdate:
      case NotificationType.localEvent:
        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: _EventActions(
            eventId: notification.targetId!,
            onResponded: onHandled,
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

/// « J'y vais » / « Voir » sur une notification d'événement (§12c).
///
/// « J'y vais » appelle réellement `attendEvent` ; sans identité connue le
/// bouton n'est pas rendu du tout plutôt que rendu inerte.
class _EventActions extends ConsumerStatefulWidget {
  final String eventId;
  final VoidCallback onResponded;

  const _EventActions({required this.eventId, required this.onResponded});

  @override
  ConsumerState<_EventActions> createState() => _EventActionsState();
}

class _EventActionsState extends ConsumerState<_EventActions> {
  bool _busy = false;

  Future<void> _attend(String userId) async {
    if (_busy) return;
    setState(() => _busy = true);

    final ok = await ref
        .read(eventDetailNotifierProvider.notifier)
        .attendEvent(widget.eventId, userId);

    if (!mounted) return;
    setState(() => _busy = false);

    final l10n = AppLocalizations.of(context)!;
    if (ok) widget.onResponded();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Vous y participez' : l10n.loadingError),
        backgroundColor: ok ? null : context.errorColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final userId = ref.watch(currentUserProvider).valueOrNull?.id;

    return Row(
      children: [
        if (userId != null) ...[
          SizedBox(
            height: 34,
            child: ElevatedButton(
              onPressed: _busy ? null : () => _attend(userId),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.successColor,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(kDesignPillRadius),
                ),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'J\'y vais',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        SizedBox(
          height: 34,
          child: OutlinedButton(
            onPressed: () => context.push('/events/${widget.eventId}'),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.textSecondaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              side: BorderSide(color: context.borderColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(kDesignPillRadius),
              ),
            ),
            child: Text(
              l10n.viewAction,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
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
    super.key,
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
    final latestNotification = widget.group.notifications.first;
    final hasUnread = unreadCount > 0;

    // Même partition que pour une notification isolée (§12c) : carte tramée
    // tant qu'il reste du non-lu, ligne nue quand tout est lu. L'accordéon est
    // conservé — c'est le seul endroit d'où l'on voit les notifications du
    // groupe une par une — mais il adopte les deux registres.
    return Container(
      padding: hasUnread ? const EdgeInsets.all(14) : EdgeInsets.zero,
      decoration: hasUnread
          ? BoxDecoration(
              color: context.adaptivePrimaryColor.withValues(
                alpha: context.isDarkMode ? 0.09 : 0.05,
              ),
              borderRadius: BorderRadius.circular(kNotificationCardRadius),
              border: Border.all(
                color: context.adaptivePrimaryColor.withValues(alpha: 0.16),
              ),
            )
          : null,
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _toggleExpanded,
              // `onLongPress` était déclaré, passé par la liste, et **jamais
              // branché ici** : l'appui long dépliait le groupe comme un tap
              // ordinaire. Comme le compte de test n'a que des notifications
              // groupées, l'écran de détail était injoignable en pratique.
              onLongPress: widget.onLongPress,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: hasUnread ? 0 : 4,
                  vertical: hasUnread ? 0 : 10,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Le compteur remplace le badge flottant vert WhatsApp :
                    // il tient dans la pastille, sans déborder ni imiter une
                    // autre application.
                    _TypeBadge(type: widget.group.type, filled: hasUnread),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  groupTitle,
                                  style: TextStyle(
                                    fontSize: hasUnread ? 15 : 14.5,
                                    height: 1.25,
                                    fontWeight: hasUnread
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    color: context.textPrimaryColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (hasUnread)
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 20,
                                  ),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: context.adaptivePrimaryColor,
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  child: Text(
                                    unreadCount > 99 ? '99+' : '$unreadCount',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: context.onPrimaryColor,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  groupSubtitle,
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.35,
                                    color: context.textSecondaryColor,
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
                          if (hasUnread && latestNotification.body.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                latestNotification.body,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: context.textTertiaryColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          const SizedBox(height: 6),
                          _Stamp(date: latestNotification.createdAt),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Le dépliant : les notifications du groupe une par une.
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 57, top: 6, bottom: 2),
                  child: Divider(height: 1, color: context.dividerColor),
                ),
                ...widget.group.notifications.map((notification) {
                  return _CompactNotificationItem(
                    key: ValueKey('compact_row_${notification.id}'),
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
}

/// Ligne du dépliant d'un groupe : la même notification, en plus serré.
class _CompactNotificationItem extends ConsumerWidget {
  final NotificationEntity notification;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onMarkAsRead;

  const _CompactNotificationItem({
    super.key,
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
      background: _SwipeBackground(
        color: context.errorColor,
        icon: Icons.delete_outline,
        label: AppLocalizations.of(context)!.delete,
        alignment: Alignment.centerRight,
      ),
      onDismissed: (_) => onDelete(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (!notification.isRead) {
              onMarkAsRead();
            }
            onTap();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            margin: const EdgeInsets.only(left: 45),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: context.dividerColor.withValues(alpha: 0.4),
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Point de non-lu — il était en vert WhatsApp codé en dur.
                if (!notification.isRead)
                  Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.only(right: 9, top: 6),
                    decoration: BoxDecoration(
                      color: context.adaptivePrimaryColor,
                      shape: BoxShape.circle,
                    ),
                  )
                else
                  const SizedBox(width: 16),

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
                              : FontWeight.w600,
                          color: context.textPrimaryColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (notification.body.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          notification.body,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: context.textSecondaryColor,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      // Actions en ligne (§12c) : ami et événement.
                      _InlineActions(
                        notification: notification,
                        onHandled: onMarkAsRead,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    DateFormat('HH:mm').format(
                      notification.createdAt ?? DateTime.now(),
                    ),
                    style: GoogleFonts.robotoMono(
                      fontSize: 10,
                      letterSpacing: 0.6,
                      color: context.textTertiaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
