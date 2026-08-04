import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:diaspo_niger/l10n/app_localizations.dart';
import '../providers/feed_provider.dart';
import '../theme/feed_tokens.dart';

/// Apparence du bouton « Suivre ».
///
/// Les deux variantes prennent leurs couleurs de `FeedTokens`. Une troisième,
/// `filled`, existait et lisait `Theme.of(context).primaryColor` : l'accent
/// choisi par l'utilisateur s'affichait alors au milieu de la palette du fil.
/// Elle est supprimée plutôt que corrigée — la garder, c'était laisser à
/// portée de main la seule variante capable de reproduire le défaut.
enum FollowButtonVariant {
  /// Simple libellé texte en couleur d'accent — utilisé dans l'en-tête des
  /// cartes du fil (refonte tour 4 : « Suivre » devient un lien discret).
  text,

  /// Pastille des listes (fiche 5d) : rayon 999, « Suivre » plein à l'accent,
  /// « Suivi » en contour.
  pill,
}

class FollowButton extends ConsumerWidget {
  final String targetUserId;
  final FollowButtonVariant variant;

  const FollowButton({
    super.key,
    required this.targetUserId,
    this.variant = FollowButtonVariant.pill,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final asyncFollowing = ref.watch(isFollowingProvider(targetUserId));

    if (variant == FollowButtonVariant.text) {
      return asyncFollowing.when(
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
        data: (isFollowing) {
          final tokens = FeedTokens.of(context);
          return InkWell(
            onTap: () async {
              await ref.read(feedRepositoryProvider).toggleFollow(targetUserId);
              ref.invalidate(isFollowingProvider(targetUserId));
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                isFollowing ? l10n.unfollowUser : l10n.followUser,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: isFollowing ? tokens.mutedText : tokens.accent,
                ),
              ),
            ),
          );
        },
      );
    }

    return asyncFollowing.when(
      // Discret pendant le chargement : évite un spinner par ligne de liste.
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (isFollowing) {
        final tokens = FeedTokens.of(context);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () async {
            await ref.read(feedRepositoryProvider).toggleFollow(targetUserId);
            ref.invalidate(isFollowingProvider(targetUserId));
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: isFollowing ? Colors.transparent : tokens.accent,
              borderRadius: BorderRadius.circular(999),
              border: isFollowing ? Border.all(color: tokens.divider) : null,
            ),
            child: Text(
              // « Suivi » et non `l10n.unfollowUser` (« Ne plus suivre ») :
              // la pastille indique un état, pas une action, et la fiche
              // 5d ne laisse pas la place à quatre mots.
              isFollowing ? 'Suivi' : 'Suivre',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isFollowing ? tokens.actionLabel : tokens.onAccent,
              ),
            ),
          ),
        );
      },
    );
  }
}
