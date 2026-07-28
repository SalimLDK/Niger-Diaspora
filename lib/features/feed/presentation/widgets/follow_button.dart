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
