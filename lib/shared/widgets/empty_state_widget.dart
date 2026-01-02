import 'package:flutter/material.dart';

/// Types d'états vides prédéfinis
enum EmptyStateType {
  noData,
  noResults,
  noMessages,
  noNotifications,
  noEvents,
  noGroups,
  noFriends,
  noProducts,
  noOrders,
  noTransactions,
  offline,
  error,
  maintenance,
}

/// Widget pour afficher un état vide personnalisé
class EmptyStateWidget extends StatelessWidget {
  final EmptyStateType? type;
  final IconData? icon;
  final String? title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? customIllustration;
  final Color? iconColor;
  final double iconSize;

  const EmptyStateWidget({
    super.key,
    this.type,
    this.icon,
    this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.customIllustration,
    this.iconColor,
    this.iconSize = 80,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = _getConfig(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Illustration ou icône
            if (customIllustration != null)
              customIllustration!
            else
              _buildIcon(context, config),

            const SizedBox(height: 24),

            // Titre
            Text(
              title ?? config.title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 12),

            // Message
            Text(
              message ?? config.message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),

            // Bouton d'action
            if (onAction != null) ...[
              const SizedBox(height: 24),
              FilledButton.tonal(
                onPressed: onAction,
                child: Text(actionLabel ?? config.actionLabel ?? 'Réessayer'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(BuildContext context, _EmptyStateConfig config) {
    final theme = Theme.of(context);
    final color = iconColor ?? theme.colorScheme.primary.withValues(alpha: 0.3);

    return Container(
      width: iconSize + 40,
      height: iconSize + 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon ?? config.icon,
        size: iconSize,
        color: color,
      ),
    );
  }

  _EmptyStateConfig _getConfig(BuildContext context) {
    switch (type) {
      case EmptyStateType.noData:
        return _EmptyStateConfig(
          icon: Icons.inbox_outlined,
          title: 'Aucune donnée',
          message: 'Il n\'y a rien à afficher pour le moment.',
        );

      case EmptyStateType.noResults:
        return _EmptyStateConfig(
          icon: Icons.search_off_outlined,
          title: 'Aucun résultat',
          message: 'Aucun résultat ne correspond à votre recherche.',
          actionLabel: 'Effacer la recherche',
        );

      case EmptyStateType.noMessages:
        return _EmptyStateConfig(
          icon: Icons.chat_bubble_outline,
          title: 'Pas de messages',
          message: 'Vous n\'avez pas encore de conversations. Commencez à discuter avec la communauté !',
          actionLabel: 'Nouvelle conversation',
        );

      case EmptyStateType.noNotifications:
        return _EmptyStateConfig(
          icon: Icons.notifications_none_outlined,
          title: 'Pas de notifications',
          message: 'Vous êtes à jour ! Aucune nouvelle notification.',
        );

      case EmptyStateType.noEvents:
        return _EmptyStateConfig(
          icon: Icons.event_outlined,
          title: 'Aucun événement',
          message: 'Il n\'y a pas d\'événements à venir pour le moment.',
          actionLabel: 'Créer un événement',
        );

      case EmptyStateType.noGroups:
        return _EmptyStateConfig(
          icon: Icons.groups_outlined,
          title: 'Aucun groupe',
          message: 'Vous n\'êtes membre d\'aucun groupe. Rejoignez ou créez un groupe !',
          actionLabel: 'Explorer les groupes',
        );

      case EmptyStateType.noFriends:
        return _EmptyStateConfig(
          icon: Icons.people_outline,
          title: 'Pas encore d\'amis',
          message: 'Connectez-vous avec d\'autres membres de la communauté.',
          actionLabel: 'Trouver des amis',
        );

      case EmptyStateType.noProducts:
        return _EmptyStateConfig(
          icon: Icons.store_outlined,
          title: 'Aucun produit',
          message: 'Le marketplace est vide pour le moment.',
          actionLabel: 'Publier un produit',
        );

      case EmptyStateType.noOrders:
        return _EmptyStateConfig(
          icon: Icons.shopping_bag_outlined,
          title: 'Aucune commande',
          message: 'Vous n\'avez pas encore passé de commande.',
          actionLabel: 'Voir le marketplace',
        );

      case EmptyStateType.noTransactions:
        return _EmptyStateConfig(
          icon: Icons.receipt_long_outlined,
          title: 'Aucune transaction',
          message: 'Vous n\'avez pas encore effectué de transfert.',
          actionLabel: 'Envoyer de l\'argent',
        );

      case EmptyStateType.offline:
        return _EmptyStateConfig(
          icon: Icons.cloud_off_outlined,
          title: 'Mode hors-ligne',
          message: 'Vous êtes actuellement hors-ligne. Certaines fonctionnalités peuvent être limitées.',
          actionLabel: 'Réessayer',
        );

      case EmptyStateType.error:
        return _EmptyStateConfig(
          icon: Icons.error_outline,
          title: 'Une erreur est survenue',
          message: 'Impossible de charger les données. Veuillez réessayer.',
          actionLabel: 'Réessayer',
        );

      case EmptyStateType.maintenance:
        return _EmptyStateConfig(
          icon: Icons.construction_outlined,
          title: 'Maintenance en cours',
          message: 'L\'application est en maintenance. Veuillez revenir plus tard.',
        );

      case null:
        return _EmptyStateConfig(
          icon: Icons.inbox_outlined,
          title: 'Aucune donnée',
          message: 'Il n\'y a rien à afficher pour le moment.',
        );
    }
  }
}

class _EmptyStateConfig {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;

  _EmptyStateConfig({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
  });
}

/// Widget compact pour les états vides dans les listes
class CompactEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final VoidCallback? onTap;

  const CompactEmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.1),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 40,
              color: theme.colorScheme.primary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
