import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:diaspo_niger/l10n/app_localizations.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../../../core/theme/design_kit.dart';
import '../../../../shared/widgets/app_icon.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/group_entity.dart';
import '../providers/group_provider.dart';
import 'edit_group_screen.dart';

/// Entrée de la route `/groups/:groupId/edit`.
///
/// La route transtypait `state.extra` vers un type **non nullable**
/// (`state.extra as GroupEntity`) : par lien profond ou par notification,
/// `extra` est nul par construction, et le cast levait un `TypeError` avant
/// même le montage de l'écran. L'identifiant était pourtant déjà là, dans
/// `pathParameters`.
///
/// ⚠️ Cette route porte **la seule** vérification d'autorisation du parcours.
/// `EditGroupScreen` n'en fait aucune : elle faisait confiance à son appelant,
/// le menu de la fiche de groupe, masqué derrière `isCreator || isAdmin`. Un
/// lien profond court-circuite ce menu, donc résoudre l'identifiant sans
/// garde ouvrirait le formulaire d'édition du groupe de n'importe qui — le
/// plantage, lui, fermait au moins la porte.
class GroupEditRoute extends ConsumerWidget {
  final String groupId;
  final GroupEntity? initialGroup;

  const GroupEditRoute({super.key, required this.groupId, this.initialGroup});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    // ⚠️ « Pas encore chargé » n'est pas « pas autorisé ». `.valueOrNull` rend
    // `null` dans les deux cas ; les confondre fait afficher « réservé aux
    // administrateurs » à un administrateur, de façon intermittente. Constaté
    // sur la route jumelle des événements, SM A515F le 2026-09-08.
    //
    // Absence de valeur ET d'erreur plutôt que `isLoading` : ce dernier vaut
    // aussi pendant un rafraîchissement et ferait clignoter l'écran. Une
    // session en erreur tranche — traitée comme absente.
    final utilisateur = ref.watch(currentUserProvider);
    if (!utilisateur.hasValue && !utilisateur.hasError) return _chargement();
    final moi = utilisateur.valueOrNull;

    final initial = initialGroup;
    if (initial != null) return _guard(context, l10n, moi, initial);

    return ref
        .watch(groupByIdProvider(groupId))
        .when(
          // Un seul état pour « absent » et « échec » : `getGroupById` rend un
          // `Left` aussi bien pour une ligne supprimée que pour une panne
          // réseau, et `groupByIdProvider` replie tout sur `null`. Trancher
          // ici reviendrait à lire le message d'erreur — et à affirmer
          // « supprimé » quand on n'en sait rien.
          data: (group) {
            if (group != null) return _guard(context, l10n, moi, group);
            return _unavailable(context, l10n, ref);
          },
          loading: _chargement,
          error: (_, __) => _unavailable(context, l10n, ref),
        );
  }

  /// Attente — du groupe ou de l'identité —, avec sa sortie.
  Widget _chargement() => const Scaffold(
    body: DesignExitOnlyBody(
      fallbackRoute: '/groups',
      child: Center(child: CircularProgressIndicator()),
    ),
  );

  /// Le même test que la fiche de groupe, y compris le repli superAdmin sur
  /// les groupes officiels (cf. `group_detail_screen.dart`) : sans lui, un
  /// superAdmin se verrait refuser une édition que RLS accepterait.
  Widget _guard(
    BuildContext context,
    AppLocalizations l10n,
    UserEntity? me,
    GroupEntity group,
  ) {
    final autorise =
        me != null &&
        (group.creatorId == me.id ||
            group.adminIds.contains(me.id) ||
            (group.isOfficial && me.isAdmin));

    if (!autorise) {
      return Scaffold(
        body: DesignUnavailableBody(
          icon: AppIcon(
            AppIcon.lock,
            size: 32,
            color: context.textSecondaryColor,
          ),
          title: l10n.groupEditNotAllowedTitle,
          message: l10n.groupEditNotAllowedMessage,
          exitLabel: l10n.backToGroup,
          fallbackRoute: '/groups/$groupId',
        ),
      );
    }
    return EditGroupScreen(group: group);
  }

  Widget _unavailable(
    BuildContext context,
    AppLocalizations l10n,
    WidgetRef ref,
  ) {
    return Scaffold(
      body: DesignUnavailableBody(
        icon: AppIcon(
          AppIcon.refresh,
          size: 32,
          color: context.textSecondaryColor,
        ),
        title: l10n.groupLoadFailedTitle,
        message: l10n.groupLoadFailedMessage,
        exitLabel: l10n.backToGroups,
        fallbackRoute: '/groups',
        retryLabel: l10n.retry,
        onRetry: () => ref.invalidate(groupByIdProvider(groupId)),
      ),
    );
  }
}
