import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:diaspo_niger/l10n/app_localizations.dart';
import '../providers/feed_provider.dart';

class FollowButton extends ConsumerWidget {
  final String targetUserId;

  const FollowButton({super.key, required this.targetUserId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final asyncFollowing = ref.watch(isFollowingProvider(targetUserId));

    return asyncFollowing.when(
      // Discret pendant le chargement : evite un spinner par carte du fil.
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (isFollowing) => OutlinedButton(
        onPressed: () async {
          await ref.read(feedRepositoryProvider).toggleFollow(targetUserId);
          ref.invalidate(isFollowingProvider(targetUserId));
        },
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          backgroundColor: isFollowing ? null : Theme.of(context).primaryColor,
          foregroundColor: isFollowing
              ? Theme.of(context).primaryColor
              : Colors.white,
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
