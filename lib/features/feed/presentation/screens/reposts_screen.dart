import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:diaspo_niger/l10n/app_localizations.dart';
import '../providers/feed_provider.dart';
import '../theme/feed_text.dart';
import '../theme/feed_tokens.dart';
import '../widgets/feed_empty_state.dart';
import '../widgets/post_card.dart';
import '../widgets/post_card_skeleton.dart';

/// Liste des publications que l'utilisateur courant a repartagées
/// (route `/profile/reposts`). Jumeau de [SavedPostsScreen].
class RepostsScreen extends ConsumerWidget {
  const RepostsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final postsAsync = ref.watch(myRepostsProvider);
    final tokens = FeedTokens.of(context);

    return Scaffold(
      backgroundColor: tokens.bg,
      appBar: AppBar(
        backgroundColor: tokens.bg,
        title: Text(l10n.repostsTitle, style: FeedText.heading(tokens, size: 18)),
        elevation: 0,
      ),
      body: postsAsync.when(
        loading: () => const PostCardListSkeleton(),
        error: (_, __) => FeedEmptyState(
          icon: Icons.error_outline_rounded,
          title: l10n.repostsError,
          body: l10n.repostsEmptyBody,
          ctaLabel: l10n.retry,
          ctaIcon: Icons.refresh_rounded,
          onCta: () => ref.invalidate(myRepostsProvider),
        ),
        data: (posts) {
          if (posts.isEmpty) {
            return FeedEmptyState(
              icon: Icons.repeat_rounded,
              title: l10n.repostsEmptyTitle,
              body: l10n.repostsEmptyBody,
              ctaLabel: l10n.exploreFeed,
              ctaIcon: Icons.explore_outlined,
              onCta: () => context.push('/feed'),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myRepostsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: posts.length,
              itemBuilder: (context, index) => PostCard(post: posts[index]),
            ),
          );
        },
      ),
    );
  }
}

