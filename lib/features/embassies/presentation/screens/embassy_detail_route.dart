import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
            return Scaffold(
              body: DesignUnavailableBody(
                icon: AppIcon(
                  AppIcon.searchOff,
                  size: 32,
                  color: context.textSecondaryColor,
                ),
                title: l10n.embassyNotFoundTitle,
                message: l10n.embassyNotFoundMessage,
                exitLabel: l10n.backToEmbassies,
                fallbackRoute: '/embassies',
              ),
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
              (_, __) => Scaffold(
                body: DesignUnavailableBody(
                  icon: AppIcon(
                    AppIcon.refresh,
                    size: 32,
                    color: context.textSecondaryColor,
                  ),
                  title: l10n.embassyLoadFailedTitle,
                  message: l10n.embassyLoadError,
                  exitLabel: l10n.backToEmbassies,
                  fallbackRoute: '/embassies',
                  retryLabel: l10n.retry,
                  onRetry:
                      () => ref.invalidate(embassyByIdProvider(embassyId)),
                ),
              ),
        );
  }
}
