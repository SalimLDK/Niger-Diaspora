import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:diaspo_niger/l10n/app_localizations.dart';
import '../../domain/entities/post_entity.dart';
import '../providers/feed_provider.dart';
import '../theme/feed_text.dart';
import '../theme/feed_tokens.dart';
import '../widgets/post_card.dart';
import '../widgets/post_card_skeleton.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';

// Provider for bookmarked posts count
final bookmarkedPostsCountProvider =
    FutureProvider.autoDispose<int>((ref) async {
  final currentUserId = FirebaseAuth.instance.currentUser?.uid;
  if (currentUserId == null) return 0;
  final repo = ref.read(feedRepositoryProvider);
  final result = await repo.getBookmarkedPostIds(currentUserId);
  return result.fold((_) => 0, (ids) => ids.length);
});

// Provider for bookmarked posts
final bookmarkedPostsProvider =
    StateNotifierProvider.autoDispose<BookmarkedPostsNotifier,
        AsyncValue<List<PostEntity>>>((ref) {
  return BookmarkedPostsNotifier(ref);
});

class BookmarkedPostsNotifier
    extends StateNotifier<AsyncValue<List<PostEntity>>> {
  final Ref _ref;

  BookmarkedPostsNotifier(this._ref) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      state = const AsyncValue.data([]);
      return;
    }
    final repo = _ref.read(feedRepositoryProvider);
    final result = await repo.getBookmarkedPosts(userId);
    state = result.fold(
      (failure) => AsyncValue.error(failure.message, StackTrace.current),
      (posts) => AsyncValue.data(posts),
    );
  }

  Future<void> removeBookmark(String postId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    // Optimistic removal
    final currentPosts = state.valueOrNull ?? [];
    state = AsyncValue.data(
      currentPosts.where((p) => p.id != postId).toList(),
    );
    final repo = _ref.read(feedRepositoryProvider);
    await repo.toggleBookmark(postId, userId);
  }

  void refresh() {
    load();
  }
}

class SavedPostsScreen extends ConsumerWidget {
  const SavedPostsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final postsAsync = ref.watch(bookmarkedPostsProvider);
    final tokens = FeedTokens.of(context);

    return Scaffold(
      backgroundColor: tokens.bg,
      appBar: AppBar(
        backgroundColor: tokens.bg,
        title: Text(l10n.savedPostsTitle, style: FeedText.heading(tokens, size: 18)),
        elevation: 0,
      ),
      body: postsAsync.when(
        loading: () => const PostCardListSkeleton(),
        error: (_, __) => _EmptyState(
          icon: AppIcon(AppIcon.error, size: 64, color: tokens.mutedText),
          message: l10n.feedError,
        ),
        data: (posts) {
          if (posts.isEmpty) {
            return _EmptyState(
              icon: Icon(Icons.bookmark_outline_rounded, size: 64, color: tokens.mutedText),
              message: l10n.savedPostsEmpty,
              actionLabel: l10n.exploreFeed,
              onAction: () => context.push('/feed'),
            );
          }
          return RefreshIndicator(
            onRefresh: () =>
                ref.read(bookmarkedPostsProvider.notifier).load(),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: posts.length,
              itemBuilder: (context, index) {
                final post = posts[index];
                return Dismissible(
                  key: Key('saved_${post.id}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    child: const Icon(
                      Icons.bookmark_remove_rounded,
                      color: Colors.white,
                    ),
                  ),
                  onDismissed: (_) async {
                    await ref
                        .read(bookmarkedPostsProvider.notifier)
                        .removeBookmark(post.id);
                  },
                  confirmDismiss: (_) async {
                    return true;
                  },
                  child: PostCard(post: post),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final Widget icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _EmptyState({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = FeedTokens.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: tokens.mutedText,
                  ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: tokens.accent),
                onPressed: onAction,
                icon: Icon(Icons.explore_outlined, color: tokens.onAccent),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
