import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/feed_provider.dart';
import '../theme/feed_text.dart';
import '../theme/feed_tokens.dart';
import '../widgets/post_card.dart';
import '../widgets/post_card_skeleton.dart';

/// Liste des publications que l'utilisateur courant a repartagées
/// (route `/profile/reposts`). Jumeau de [SavedPostsScreen].
class RepostsScreen extends ConsumerWidget {
  const RepostsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(myRepostsProvider);
    final tokens = FeedTokens.of(context);

    return Scaffold(
      backgroundColor: tokens.bg,
      appBar: AppBar(
        backgroundColor: tokens.bg,
        title: Text('Mes repartages', style: FeedText.heading(tokens, size: 18)),
        elevation: 0,
      ),
      body: postsAsync.when(
        loading: () => const PostCardListSkeleton(),
        error: (_, __) => const _EmptyReposts(
          message: 'Impossible de charger vos repartages.',
        ),
        data: (posts) {
          if (posts.isEmpty) {
            return const _EmptyReposts(
              message: 'Vous n\'avez encore rien repartagé.',
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

class _EmptyReposts extends StatelessWidget {
  final String message;

  const _EmptyReposts({required this.message});

  @override
  Widget build(BuildContext context) {
    final tokens = FeedTokens.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.repeat_rounded, size: 64, color: tokens.mutedText),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: tokens.mutedText),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: tokens.accent),
              onPressed: () => context.push('/feed'),
              icon: Icon(Icons.explore_outlined, color: tokens.onAccent),
              label: const Text('Explorer le fil'),
            ),
          ],
        ),
      ),
    );
  }
}
