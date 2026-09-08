import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:diaspo_niger/l10n/app_localizations.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../../../core/theme/design_kit.dart';
import '../../../../shared/widgets/app_icon.dart';
import '../../domain/entities/embassy_entity.dart';
import '../providers/embassies_provider.dart';
import 'embassy_detail_screen.dart';

/// Entrée de la route `/embassies/:id`.
///
/// La fiche complète est un `StatelessWidget` qui exige son `EmbassyEntity` :
/// c'est bien quand on vient de la liste, qui l'a déjà en main. Mais un lien
/// profond ou une notification n'apportent que l'identifiant — `state.extra`
/// est nul par construction dans ces deux cas — et la route terminait alors
/// par un `!` sur ce nul.
///
/// Ce widget résout l'identifiant quand l'objet manque, et donne une sortie
/// aux deux états sans contenu : le chargement et la fiche introuvable. Il ne
/// touche pas à `EmbassyDetailScreen`, qui reste servi tel quel dès que
/// l'entité est là.
class EmbassyDetailRoute extends ConsumerWidget {
  final String embassyId;

  /// L'entité passée par la navigation interne, quand il y en a une : elle
  /// évite l'aller-retour et affiche la fiche immédiatement.
  final EmbassyEntity? initialEmbassy;

  const EmbassyDetailRoute({
    super.key,
    required this.embassyId,
    this.initialEmbassy,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initial = initialEmbassy;
    if (initial != null) {
      return EmbassyDetailScreen(embassy: initial);
    }

    final l10n = AppLocalizations.of(context)!;
    return ref
        .watch(embassyByIdProvider(embassyId))
        .when(
          data: (embassy) {
            if (embassy != null) return EmbassyDetailScreen(embassy: embassy);
            // Rendre `null` veut dire « cette fiche n'existe pas, ou n'est pas
            // montrable » : il n'y a rien à réessayer.
            return _EmbassyUnavailable(
              title: l10n.embassyNotFoundTitle,
              message: l10n.embassyNotFoundMessage,
              icon: AppIcon.searchOff,
              l10n: l10n,
            );
          },
          loading:
              () => const Scaffold(
                body: DesignExitOnlyBody(
                  fallbackRoute: '/embassies',
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
          // Le dépôt sert déjà la copie locale quand le réseau manque : une
          // erreur ici est une vraie panne, pas un simple hors-ligne.
          error:
              (_, __) => _EmbassyUnavailable(
                title: l10n.embassyLoadFailedTitle,
                message: l10n.embassyLoadError,
                icon: AppIcon.refresh,
                l10n: l10n,
                onRetry:
                    () => ref.invalidate(embassyByIdProvider(embassyId)),
              ),
        );
  }
}

/// État sans contenu : un titre, une explication, et toujours une porte de
/// sortie — la flèche de `DesignExitOnlyBody` plus un bouton explicite, parce
/// qu'arrivé par lien profond il n'y a rien à dépiler derrière.
class _EmbassyUnavailable extends StatelessWidget {
  final String title;
  final String message;
  final String icon;
  final AppLocalizations l10n;
  final VoidCallback? onRetry;

  const _EmbassyUnavailable({
    required this.title,
    required this.message,
    required this.icon,
    required this.l10n,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final retry = onRetry;
    return Scaffold(
      body: DesignExitOnlyBody(
        fallbackRoute: '/embassies',
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: context.surfaceColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: AppIcon(
                      icon,
                      size: 32,
                      color: context.textSecondaryColor,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: context.textPrimaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.textSecondaryColor,
                  ),
                ),
                const SizedBox(height: 24),
                if (retry != null) ...[
                  FilledButton(onPressed: retry, child: Text(l10n.retry)),
                  TextButton(
                    onPressed: () => context.go('/embassies'),
                    child: Text(l10n.backToEmbassies),
                  ),
                ] else
                  FilledButton(
                    onPressed: () => context.go('/embassies'),
                    child: Text(l10n.backToEmbassies),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
