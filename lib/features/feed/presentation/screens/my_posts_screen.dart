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
        error: (_, __) => _EmptyState(
          icon: AppIcon(AppIcon.error, size: 64, color: tokens.mutedText),
          message: l10n.feedError,
        ),
        data: (posts) {
          if (posts.isEmpty) {
            return _EmptyState(
              icon: Icon(Icons.article_outlined, size: 64, color: tokens.mutedText),
              message: l10n.myPostsEmpty,
              actionLabel: l10n.createPost,
              onAction: () => context.push('/feed/create'),
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
                icon: AppIcon(AppIcon.add, color: tokens.onAccent),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
