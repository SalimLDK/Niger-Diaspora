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

/// Filtre de type de média des enregistrements (chips 5c).
enum _SavedFilter { all, photos, videos, texts }

class SavedPostsScreen extends ConsumerStatefulWidget {
  const SavedPostsScreen({super.key});

  @override
  ConsumerState<SavedPostsScreen> createState() => _SavedPostsScreenState();
}

class _SavedPostsScreenState extends ConsumerState<SavedPostsScreen> {
  _SavedFilter _filter = _SavedFilter.all;

  bool _matchesFilter(PostEntity post) {
    switch (_filter) {
      case _SavedFilter.all:
        return true;
      case _SavedFilter.photos:
        return post.mediaType == PostMediaType.images;
      case _SavedFilter.videos:
        return post.mediaType == PostMediaType.video;
      case _SavedFilter.texts:
        return post.mediaType == PostMediaType.none;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final postsAsync = ref.watch(bookmarkedPostsProvider);
    final tokens = FeedTokens.of(context);

    return Scaffold(
      backgroundColor: tokens.bg,
      appBar: AppBar(
        backgroundColor: tokens.bg,
        title:
            Text(l10n.savedPostsTitle, style: FeedText.heading(tokens, size: 18)),
        elevation: 0,
      ),
      body: postsAsync.when(
        loading: () => const PostCardListSkeleton(),
        error: (_, __) => FeedEmptyState(
          icon: Icons.error_outline_rounded,
          title: l10n.feedError,
          body: l10n.savedPostsEmptyBody,
          ctaLabel: l10n.retry,
          ctaIcon: Icons.refresh_rounded,
          onCta: () => ref.read(bookmarkedPostsProvider.notifier).load(),
        ),
        data: (posts) {
          if (posts.isEmpty) {
            return FeedEmptyState(
              icon: Icons.bookmark_outline_rounded,
              title: l10n.savedPostsEmptyTitle,
              body: l10n.savedPostsEmptyBody,
              ctaLabel: l10n.exploreFeed,
              ctaIcon: Icons.explore_outlined,
              onCta: () => context.push('/feed'),
              note: l10n.savedPostsNote,
            );
          }

          final filtered = posts.where(_matchesFilter).toList();
          // Regroupement par période (Cette semaine / Plus ancien).
          final now = DateTime.now();
          final thisWeek = <PostEntity>[];
          final older = <PostEntity>[];
          for (final p in filtered) {
            if (now.difference(p.createdAt).inDays < 7) {
              thisWeek.add(p);
            } else {
              older.add(p);
            }
          }

          return RefreshIndicator(
            onRefresh: () => ref.read(bookmarkedPostsProvider.notifier).load(),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _FilterChips(
                    filter: _filter,
                    tokens: tokens,
                    onChanged: (f) => setState(() => _filter = f),
                  ),
                ),
                if (filtered.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _NoMatchNotice(
                      tokens: tokens,
                      label: l10n.savedPostsEmptyBody,
                    ),
                  )
                else ...[
                  if (thisWeek.isNotEmpty)
                    _buildSection(l10n.thisWeek, thisWeek, ref, tokens),
                  if (older.isNotEmpty)
                    _buildSection(l10n.older, older, ref, tokens),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSection(
    String title,
    List<PostEntity> posts,
    WidgetRef ref,
    FeedTokens tokens,
  ) {
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
            child: Text(
              title.toUpperCase(),
              style: FeedText.body(
                tokens,
                size: 11,
                weight: FontWeight.w700,
                color: tokens.mutedText,
              ).copyWith(letterSpacing: 1.0),
            ),
          ),
        ),
        SliverList.builder(
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
              confirmDismiss: (_) async => true,
              child: PostCard(post: post),
            );
          },
        ),
      ],
    );
  }
}

/// Rangée de chips Tout / Photos / Vidéos / Textes.
class _FilterChips extends StatelessWidget {
  final _SavedFilter filter;
  final FeedTokens tokens;
  final ValueChanged<_SavedFilter> onChanged;

  const _FilterChips({
    required this.filter,
    required this.tokens,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final items = <(_SavedFilter, String)>[
      (_SavedFilter.all, l10n.all),
      (_SavedFilter.photos, l10n.photos),
      (_SavedFilter.videos, l10n.videos),
      (_SavedFilter.texts, l10n.texts),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          for (final (value, label) in items) ...[
            _Chip(
              label: label,
              active: value == filter,
              tokens: tokens,
              onTap: () => onChanged(value),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool active;
  final FeedTokens tokens;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.active,
    required this.tokens,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Actif = #201E1D plein (texte clair) ; inactif = contour discret.
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? tokens.text : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? tokens.text : tokens.divider,
          ),
        ),
        child: Text(
          label,
          style: FeedText.body(
            tokens,
            size: 13,
            weight: active ? FontWeight.w600 : FontWeight.w400,
            color: active ? tokens.bg : tokens.mutedText,
          ),
        ),
      ),
    );
  }
}

class _NoMatchNotice extends StatelessWidget {
  final FeedTokens tokens;
  final String label;

  const _NoMatchNotice({required this.tokens, required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: FeedText.body(tokens, size: 14, color: tokens.mutedText),
        ),
      ),
    );
  }
}
