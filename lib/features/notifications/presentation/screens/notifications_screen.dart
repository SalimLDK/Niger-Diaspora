import 'package:flutter/material.dart';
import '../../../../core/theme/design_kit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

import '../../../../shared/widgets/loading_indicator.dart';
import '../../domain/entities/notification_entity.dart';
import '../providers/notification_provider.dart';
import '../widgets/notification_style.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../../settings/presentation/providers/blocked_users_provider.dart';
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

  /// Pagination au défilement.
  ///
  /// Ce garde-fou vaut une explication, parce que son absence gelait l'écran.
  ///
  /// La condition était seulement `pixels >= maxScrollExtent - 200`. Sur une
  /// liste courte — mesuré ici : `maxScrollExtent = 87.2` — le seuil vaut
  /// **−112.8**, donc la condition est vraie **dès le pixel zéro**. Au premier
  /// micro-mouvement du doigt, `loadMore()` partait ; il fait `state += 20`
  /// sur la limite, ce qui **réabonne le flux Firestore** et reconstruit le
  /// sous-arbre. Sous le doigt, en boucle, à chaque événement de défilement :
  /// la liste ne bougeait pas d'un pixel, et un glissement lent finissait
  /// interprété comme un tap. La limite grimpait de 20 en 20 dans le vide.
  ///
  /// Deux gardes, dans cet ordre :
  /// 1. rien à faire défiler → rien à paginer ;
  /// 2. **le serveur a rendu moins que la limite demandée → on a déjà tout**.
  ///    C'est le test qui manquait ; à lui seul il suffit ici (15 notifications
  ///    pour une limite de 20), mais les deux ensemble couvrent aussi le cas
  ///    d'une page pleine sur un écran court.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.maxScrollExtent <= 0) return;
    if (position.pixels < position.maxScrollExtent - 200) return;

    final chargees =
        ref.read(notificationsNotifierProvider).valueOrNull?.length ?? 0;
    if (chargees < ref.read(notificationLimitProvider)) return;

    ref.read(notificationsNotifierProvider.notifier).loadMore();
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
    final quiMOntBloque =
        ref.watch(usersWhoBlockedMeProvider).valueOrNull ?? const <String>{};

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

              // Check if sender blocked me — le test disait « j'ai bloque
              // l'expediteur », sur un champ toujours vide.
              if (quiMOntBloque.contains(n.senderId)) return false;
              return true;
            }

            // Only filter user-related notifications
            if (!userRelatedTypes.contains(n.type)) return true;
            if (n.targetId == null) return true;

            // If I blocked this user, hide their notifications
            if (blockedUserIds.contains(n.targetId)) return false;

            // Check if target user blocked me — meme inversion.
            if (quiMOntBloque.contains(n.targetId)) return false;

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

          // §12c : la liste se lit par tranches de temps
          // (« AUJOURD'HUI », « CETTE SEMAINE », puis le mois). Une
          // notification = une ligne : le regroupement par conversation a été
          // retiré, la liste reste donc plate à l'intérieur d'une tranche.
          final sections = _sectionByDate(filteredNotifications);

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

  Widget _buildItem(
    BuildContext context,
    WidgetRef ref,
    NotificationEntity item,
  ) {
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

  /// Découpe la liste en tranches de temps (§12c).
  ///
  /// L'ordre des éléments est conservé tel quel — le flux arrive déjà trié du
  /// plus récent au plus ancien, et re-trier ici ferait diverger l'affichage
  /// de la pagination.
  List<({String label, List<NotificationEntity> items})> _sectionByDate(
    List<NotificationEntity> items,
  ) {
    final sections = <({String label, List<NotificationEntity> items})>[];
    for (final item in items) {
      final label = _sectionLabel(item.createdAt);
      if (sections.isEmpty || sections.last.label != label) {
        sections.add((label: label, items: <NotificationEntity>[]));
      }
      sections.last.items.add(item);
    }
    return sections;
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
    // Les vraies mentions, justement : elles n'existaient pas encore comme
    // type quand ce filtre a été écrit.
    NotificationType.mentioned,
    NotificationType.groupMention,
    NotificationType.commentReply,
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
      // Fil d'actualité : la cible est toujours l'identifiant de la
      // publication (cf. `notify_on_post_insert`, qui écrit `postId` ET
      // `targetId`).
      case NotificationType.newPost:
      case NotificationType.mentioned:
      case NotificationType.groupMention:
      case NotificationType.postCommented:
      case NotificationType.commentReply:
        if (notification.targetId != null) {
          context.push('/feed/${notification.targetId}');
        } else {
          context.push('/notifications/${notification.id}');
        }
        break;
      case NotificationType.reportResolved:
      case NotificationType.groupCallInvitation:
      case NotificationType.general:
        // Pas de destination propre : la fiche de la notification reste plus
        // utile qu'un appui sans effet — c'est précisément ce que faisait
        // `general` avant, et rien ne distinguait à l'écran une notification
        // « cliquable » d'une autre.
        context.push('/notifications/${notification.id}');
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

    final l10n = AppLocalizations.of(context)!;
    if (ok) widget.onResponded();

    // L'échec ne disait **rien** : le bouton reprenait son état et la carte
    // restait là, à l'identique. Un refus de permission Firestore se lisait
    // donc comme un tap qui n'avait pas pris. C'est ce qui a caché pendant des
    // mois le fait qu'accepter une demande d'ami était impossible.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? (accept ? l10n.requestAccepted : l10n.requestDeclined)
              : l10n.loadingError,
        ),
        backgroundColor: ok ? null : context.errorColor,
      ),
    );
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
