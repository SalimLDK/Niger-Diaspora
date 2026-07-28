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
import '../widgets/feed_segmented_control.dart';
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

class MyPostsScreen extends ConsumerStatefulWidget {
  const MyPostsScreen({super.key});

  @override
  ConsumerState<MyPostsScreen> createState() => _MyPostsScreenState();
}

class _MyPostsScreenState extends ConsumerState<MyPostsScreen> {
  // 0 = Publications, 1 = Repartages (§5b).
  int _tab = 0;

  String _withCount(String label, int count) =>
      count > 0 ? '$label · $count' : label;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = FeedTokens.of(context);
    final postsAsync = ref.watch(myPostsProvider);
    final repostsAsync = ref.watch(myRepostsProvider);
    final postsCount = postsAsync.valueOrNull?.length ?? 0;
    final repostsCount = repostsAsync.valueOrNull?.length ?? 0;

    return Scaffold(
      backgroundColor: tokens.bg,
      appBar: AppBar(
        backgroundColor: tokens.bg,
        title: Text(
          l10n.myPostsTitle,
          style: FeedText.heading(tokens, size: 18),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.edit_note_rounded, color: tokens.accent),
            tooltip: l10n.createPost,
            onPressed: () => context.push('/feed/create'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: FeedSegmentedControl<int>(
              tokens: tokens,
              fullWidth: true,
              selected: _tab,
              onChanged: (v) => setState(() => _tab = v),
              segments: [
                FeedSegment(
                  value: 0,
                  icon: (c) => Icon(Icons.article_outlined, color: c),
                  label: _withCount(l10n.myPostsTitle, postsCount),
                ),
                FeedSegment(
                  value: 1,
                  icon: (c) => Icon(Icons.repeat_rounded, color: c),
                  label: _withCount(l10n.repostsTitle, repostsCount),
                ),
              ],
            ),
          ),
          Expanded(
            child:
                _tab == 0
                    ? _buildPostsList(
                      l10n,
                      postsAsync,
                      emptyIcon: Icons.article_outlined,
                      emptyTitle: l10n.myPostsEmptyTitle,
                      emptyBody: l10n.myPostsEmptyBody,
                      ctaLabel: l10n.createPost,
                      ctaIcon: Icons.edit_note_rounded,
                      onCta: () => context.push('/feed/create'),
                      onRefresh: () => ref.invalidate(myPostsProvider),
                      onRetry: () => ref.invalidate(myPostsProvider),
                      errorTitle: l10n.feedError,
                    )
                    : _buildPostsList(
                      l10n,
                      repostsAsync,
                      emptyIcon: Icons.repeat_rounded,
                      emptyTitle: l10n.repostsEmptyTitle,
                      emptyBody: l10n.repostsEmptyBody,
                      ctaLabel: l10n.exploreFeed,
                      ctaIcon: Icons.explore_outlined,
                      onCta: () => context.push('/feed'),
                      onRefresh: () => ref.invalidate(myRepostsProvider),
                      onRetry: () => ref.invalidate(myRepostsProvider),
                      errorTitle: l10n.repostsError,
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostsList(
    AppLocalizations l10n,
    AsyncValue<List<PostEntity>> async, {
    required IconData emptyIcon,
    required String emptyTitle,
    required String emptyBody,
    required String ctaLabel,
    required IconData ctaIcon,
    required VoidCallback onCta,
    required VoidCallback onRefresh,
    required VoidCallback onRetry,
    required String errorTitle,
  }) {
    return async.when(
      loading: () => const PostCardListSkeleton(),
      error:
          (_, __) => FeedEmptyState(
            icon: Icons.error_outline_rounded,
            title: errorTitle,
            body: emptyBody,
            ctaLabel: l10n.retry,
            ctaIcon: Icons.refresh_rounded,
            onCta: onRetry,
          ),
      data: (posts) {
        if (posts.isEmpty) {
          return FeedEmptyState(
            icon: emptyIcon,
            title: emptyTitle,
            body: emptyBody,
            ctaLabel: ctaLabel,
            ctaIcon: ctaIcon,
            onCta: onCta,
          );
        }
        return RefreshIndicator(
          onRefresh: () async => onRefresh(),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: posts.length,
            itemBuilder: (context, index) => PostCard(post: posts[index]),
          ),
        );
      },
    );
  }
}

