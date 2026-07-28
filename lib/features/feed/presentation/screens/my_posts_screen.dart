import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:diaspo_niger/l10n/app_localizations.dart';
import '../../domain/entities/post_entity.dart';
import '../providers/feed_provider.dart';
import '../theme/feed_text.dart';
import '../theme/feed_tokens.dart';
import '../widgets/feed_empty_state.dart';
import '../widgets/post_card.dart';
import '../widgets/post_card_skeleton.dart';

// Provider for user's own posts
final myPostsProvider =
    FutureProvider.autoDispose<List<PostEntity>>((ref) async {
  final currentUserId = FirebaseAuth.instance.currentUser?.uid;
  if (currentUserId == null) return const [];
  final repo = ref.read(feedRepositoryProvider);
  final result = await repo.getUserPosts(currentUserId);
  return result.fold((_) => const [], (posts) => posts);
});

final userPostsCountProvider =
    FutureProvider.autoDispose<int>((ref) async {
  final currentUserId = FirebaseAuth.instance.currentUser?.uid;
  if (currentUserId == null) return 0;
  final repo = ref.read(feedRepositoryProvider);
  final result = await repo.getUserPosts(currentUserId);
  return result.fold((_) => 0, (posts) => posts.length);
});

class MyPostsScreen extends ConsumerWidget {
  const MyPostsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final postsAsync = ref.watch(myPostsProvider);
    final tokens = FeedTokens.of(context);

    return Scaffold(
      backgroundColor: tokens.bg,
      appBar: AppBar(
        backgroundColor: tokens.bg,
        title: Text(l10n.myPostsTitle, style: FeedText.heading(tokens, size: 18)),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.edit_note_rounded, color: tokens.accent),
            tooltip: l10n.createPost,
            onPressed: () => context.push('/feed/create'),
          ),
        ],
      ),
      body: postsAsync.when(
        loading: () => const PostCardListSkeleton(),
        error: (_, __) => FeedEmptyState(
          icon: Icons.error_outline_rounded,
          title: l10n.feedError,
          body: l10n.myPostsEmptyBody,
          ctaLabel: l10n.retry,
          ctaIcon: Icons.refresh_rounded,
          onCta: () => ref.invalidate(myPostsProvider),
        ),
        data: (posts) {
          if (posts.isEmpty) {
            return FeedEmptyState(
              icon: Icons.article_outlined,
              title: l10n.myPostsEmptyTitle,
              body: l10n.myPostsEmptyBody,
              ctaLabel: l10n.createPost,
              ctaIcon: Icons.edit_note_rounded,
              onCta: () => context.push('/feed/create'),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(myPostsProvider.future),
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

