import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:diaspo_niger/l10n/app_localizations.dart';
import '../providers/feed_provider.dart';
import '../theme/feed_tokens.dart';

/// Apparence du bouton « Suivre ».
enum FollowButtonVariant {
  /// Bouton plein/contour classique (listes, profils).
  filled,

  /// Simple libellé texte en couleur d'accent — utilisé dans l'en-tête des
  /// cartes du fil (refonte tour 4 : « Suivre » devient un lien discret).
  text,

  /// Pastille des listes « Mon réseau » (fiche 5d) : rayon 999, « Suivre »
  /// plein à l'accent, « Suivi » en contour. Contrairement à [filled], elle
  /// prend ses couleurs de `FeedTokens` et non du thème global — sinon
  /// l'accent choisi par l'utilisateur écrase la palette du fil.
  pill,
}

class FollowButton extends ConsumerWidget {
  final String targetUserId;
  final FollowButtonVariant variant;

  const FollowButton({
    super.key,
    required this.targetUserId,
    this.variant = FollowButtonVariant.filled,
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

    if (variant == FollowButtonVariant.pill) {
      return asyncFollowing.when(
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
                border:
                    isFollowing ? Border.all(color: tokens.divider) : null,
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

    return asyncFollowing.when(
      // Discret pendant le chargement : evite un spinner par carte du fil.
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data:
          (isFollowing) => OutlinedButton(
            onPressed: () async {
              await ref.read(feedRepositoryProvider).toggleFollow(targetUserId);
              ref.invalidate(isFollowingProvider(targetUserId));
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              backgroundColor:
                  isFollowing ? null : Theme.of(context).primaryColor,
              foregroundColor:
                  isFollowing ? Theme.of(context).primaryColor : Colors.white,
              side: BorderSide(color: Theme.of(context).primaryColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text(isFollowing ? l10n.unfollowUser : l10n.followUser),
          ),
    );
  }
}
