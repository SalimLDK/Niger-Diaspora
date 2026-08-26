import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/app_icon.dart';
import '../../domain/entities/business_entity.dart';
import '../providers/business_provider.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

/// §19c « Mes entreprises » — écran propriétaire.
///
/// Un propriétaire peut désormais avoir plusieurs entreprises
/// (cf. [MyBusinessesNotifier] qui n'applique plus de `.limit(1)`).
class MyBusinessesScreen extends ConsumerWidget {
  const MyBusinessesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final businessesAsync = ref.watch(myBusinessesNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mes entreprises')),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/businesses/create'),
        icon: const AppIcon(AppIcon.add),
        label: Text(l10n.add),
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(myBusinessesNotifierProvider.notifier).refresh(),
        child: businessesAsync.when(
          skipLoadingOnRefresh: true,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _ErrorView(
            message: error.toString(),
            onRetry: () =>
                ref.read(myBusinessesNotifierProvider.notifier).refresh(),
          ),
          data: (businesses) {
            if (businesses.isEmpty) {
              return const _EmptyView();
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                _StatsRow(businesses: businesses),
                const SizedBox(height: 20),
                ...businesses.map(
                  (b) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _OwnerBusinessCard(business: b),
                  ),
                ),
                // Entrée « Ajouter une entreprise » en carte pointillée.
                _AddBusinessCard(
                  onTap: () => context.push('/businesses/create'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Trois compteurs agrégés : vues, avis, à répondre.
///
/// Le compteur « à répondre » se limite aux avis sans réponse *connus* de la
/// carte d'entreprise (`reviewCount` global) — une valeur fine par avis
/// nécessiterait N requêtes ; ici on affiche le total d'avis reçus, cohérent
/// avec le reste de l'écran.
class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.businesses});

  final List<BusinessEntity> businesses;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final totalViews =
        businesses.fold<int>(0, (sum, b) => sum + b.viewCount);
    final totalReviews =
        businesses.fold<int>(0, (sum, b) => sum + b.reviewCount);

    Widget cell(String value, String label) => Expanded(
          child: Column(
            children: [
              Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          cell('${businesses.length}', 'Entreprises'),
          _divider(theme),
          cell('$totalViews', l10n.businessViews),
          _divider(theme),
          cell('$totalReviews', l10n.reviews),
        ],
      ),
    );
  }

  Widget _divider(ThemeData theme) => Container(
        width: 1,
        height: 32,
        color: theme.colorScheme.outlineVariant,
      );
}

class _OwnerBusinessCard extends StatelessWidget {
  const _OwnerBusinessCard({required this.business});

  final BusinessEntity business;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final boostRemaining = _boostRemaining();

    return InkWell(
      onTap: () =>
          context.push('/businesses/${business.id}', extra: business),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(business.category.icon, size: 20,
                    color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    business.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _StatusPill(isVerified: business.isVerified),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              business.category.label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 12),
            // Stats compactes
            Row(
              children: [
                _stat(theme, Icons.visibility_outlined,
                    '${business.viewCount} vues'),
                const SizedBox(width: 16),
                _stat(theme, Icons.star_border,
                    '${business.reviewCount} avis'),
              ],
            ),
            if (boostRemaining != null) ...[
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer
                      .withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.trending_up,
                        size: 16, color: theme.colorScheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      'En avant · $boostRemaining',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 4),
            // Actions
            Row(
              children: [
                _action(context, Icons.edit_outlined, l10n.edit,
                    () => context.push('/businesses/${business.id}',
                        extra: business)),
                _action(context, Icons.local_offer_outlined, 'Offres',
                    () => context.push('/businesses/${business.id}',
                        extra: business)),
                _action(context, Icons.reviews_outlined, l10n.reviews,
                    () => context.push('/businesses/${business.id}/reviews',
                        extra: business)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(ThemeData theme, IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.outline),
          const SizedBox(width: 4),
          Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      );

  Widget _action(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);
    return Expanded(
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label, style: theme.textTheme.labelMedium),
        style: TextButton.styleFrom(
          foregroundColor: theme.colorScheme.onSurface,
          padding: const EdgeInsets.symmetric(vertical: 8),
        ),
      ),
    );
  }

  /// Retourne un libellé « N j » / « N h » si l'entreprise est mise en avant et
  /// n'a pas expiré, sinon `null`.
  String? _boostRemaining() {
    if (!business.isBoosted || business.boostExpiresAt == null) return null;
    final now = DateTime.now();
    if (business.boostExpiresAt!.isBefore(now)) return null;
    final diff = business.boostExpiresAt!.difference(now);
    if (diff.inDays >= 1) return '${diff.inDays} j restants';
    if (diff.inHours >= 1) return '${diff.inHours} h restantes';
    return '${diff.inMinutes} min';
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.isVerified});

  final bool isVerified;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final color = isVerified ? const Color(0xFF009600) : const Color(0xFFFA7D00);
    final bg = isVerified
        ? const Color(0xFFE8F0EA)
        : const Color(0xFFF7ECD9);
    final label = isVerified ? l10n.adminVerifiedStatus : l10n.pending;
    final icon = isVerified ? Icons.verified : Icons.hourglass_empty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? color.withValues(alpha: 0.2)
            : bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddBusinessCard extends StatelessWidget {
  const _AddBusinessCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: DottedBorderBox(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_business_outlined,
                  color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Ajouter une entreprise',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bordure pointillée simple via [CustomPaint].
class DottedBorderBox extends StatelessWidget {
  const DottedBorderBox({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
      child: child,
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(16),
    );
    final path = Path()..addRRect(rrect);
    const dash = 6.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + dash),
          paint,
        );
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        Icon(Icons.storefront_outlined,
            size: 72, color: theme.colorScheme.outline),
        const SizedBox(height: 16),
        Text(
          'Aucune entreprise',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Référencez votre commerce pour être visible par la diaspora.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: FilledButton.icon(
            onPressed: () => context.push('/businesses/create'),
            icon: const AppIcon(AppIcon.add),
            label: const Text('Ajouter une entreprise'),
          ),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        AppIcon(AppIcon.error, size: 64, color: theme.colorScheme.error),
        const SizedBox(height: 16),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: theme.colorScheme.error),
        ),
        const SizedBox(height: 16),
        Center(
          child: ElevatedButton(
            onPressed: onRetry,
            child: Text(l10n.retry),
          ),
        ),
      ],
    );
  }
}
