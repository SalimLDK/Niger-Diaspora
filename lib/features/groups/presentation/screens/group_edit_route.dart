import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:diaspo_niger/l10n/app_localizations.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../../../core/theme/design_kit.dart';
import '../../../../shared/widgets/app_icon.dart';
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
    final initial = initialGroup;
    if (initial != null) return _guard(context, ref, l10n, initial);

    return ref
        .watch(groupByIdProvider(groupId))
        .when(
          // Un seul état pour « absent » et « échec » : `getGroupById` rend un
          // `Left` aussi bien pour une ligne supprimée que pour une panne
          // réseau, et `groupByIdProvider` replie tout sur `null`. Trancher
          // ici reviendrait à lire le message d'erreur — et à affirmer
          // « supprimé » quand on n'en sait rien.
          data: (group) {
            if (group != null) return _guard(context, ref, l10n, group);
            return _unavailable(context, l10n, ref);
          },
          loading:
              () => const Scaffold(
                body: DesignExitOnlyBody(
                  fallbackRoute: '/groups',
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
          error: (_, __) => _unavailable(context, l10n, ref),
        );
  }

  /// Le même test que la fiche de groupe, y compris le repli superAdmin sur
  /// les groupes officiels (cf. `group_detail_screen.dart`) : sans lui, un
  /// superAdmin se verrait refuser une édition que RLS accepterait.
  Widget _guard(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    GroupEntity group,
  ) {
    final me = ref.watch(currentUserProvider).valueOrNull;
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
