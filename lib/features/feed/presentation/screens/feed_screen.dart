import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:diaspo_niger/shared/widgets/animated_list_item.dart';
import '../../../../core/constants/ad_config.dart';
import '../../domain/entities/post_entity.dart';
import '../../domain/repositories/feed_repository.dart';
import '../providers/feed_provider.dart';
import '../theme/feed_text.dart';
import '../theme/feed_tokens.dart';
import '../widgets/ad_slot.dart';
import '../widgets/feed_segmented_control.dart';
import '../widgets/post_card.dart';
import '../widgets/post_card_skeleton.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';

class FeedScreen extends ConsumerStatefulWidget {
  final String? hashtagFilter;

  const FeedScreen({super.key, this.hashtagFilter});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

// Sentinel object inserted into the mixed list to mark an ad slot position.
class _AdMarker {
  const _AdMarker(this.index);
  final int index;
}

// Ligne de fil représentant un repartage (post original + attribution).
class _RepostItem {
  const _RepostItem(this.entry);
  final RepostFeedEntry entry;
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  final _scrollController = ScrollController();
  final _random = Random();
  late final List<int> _adIntervals;

  @override
  void initState() {
    super.initState();
    // Pre-generate 20 random intervals [10, 15] — stable for the whole session.
    _adIntervals = List.generate(
      20,
      (_) =>
          AdConfig.adFrequencyMin +
          _random.nextInt(AdConfig.adFrequencyMax - AdConfig.adFrequencyMin + 1),
    );
    _scrollController.addListener(_onScroll);
    if (widget.hashtagFilter != null) {
      Future.microtask(() {
        ref
            .read(feedNotifierProvider.notifier)
            .loadInitial(hashtagFilter: widget.hashtagFilter);
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(feedNotifierProvider.notifier).loadMore();
    }
  }

  /// Builds a mixed list interleaving feed rows ([PostEntity] / [_RepostItem])
  /// and [_AdMarker] objects. Uses pre-generated [_adIntervals] so positions are
  /// stable across rebuilds.
  List<Object> _buildMixedItems(List<Object> rows) {
    final result = <Object>[];
    int adCount = 0;
    int postsInBlock = 0;
    int intervalIndex = 0;

    for (final row in rows) {
      result.add(row);
      postsInBlock++;
      if (postsInBlock >= _adIntervals[intervalIndex % _adIntervals.length]) {
        result.add(_AdMarker(adCount));
        adCount++;
        postsInBlock = 0;
        intervalIndex++;
      }
    }
    return result;
  }

  /// Fusionne les repartages des comptes suivis dans la liste des posts, triés
  /// par horodatage effectif (date du repartage pour un repost, date de création
  /// sinon). Les repartages d'un post déjà présent dans le fil sont ignorés.
  List<Object> _mergeRows(
    List<PostEntity> posts,
    List<RepostFeedEntry> reposts,
  ) {
    final postIds = posts.map((p) => p.id).toSet();
    final fresh = reposts.where((e) => !postIds.contains(e.post.id));
    final rows = <Object>[...posts, ...fresh.map((e) => _RepostItem(e))];
    DateTime keyOf(Object o) => o is _RepostItem
        ? o.entry.ref.repostedAt
        : (o as PostEntity).createdAt;
    rows.sort((a, b) => keyOf(b).compareTo(keyOf(a)));
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final feedState = ref.watch(feedNotifierProvider);
    final filter = feedState.hashtagFilter ?? widget.hashtagFilter;
    final reposts =
        ref.watch(feedRepostsProvider).valueOrNull ?? const <RepostFeedEntry>[];
    final tokens = FeedTokens.of(context);

    return Scaffold(
      backgroundColor: tokens.bg,
      appBar: AppBar(
        backgroundColor: tokens.bg,
        // Repli vers l'accueil quand la pile est vide (entrée par deep link).
        leading: IconButton(
          icon: AppIcon(AppIcon.arrowBack, color: tokens.text),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
        title: Text(l10n.feedTitle, style: FeedText.heading(tokens, size: 20)),
        centerTitle: true,
        elevation: 0,
      ),
      floatingActionButton: filter == null
          ? Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: tokens.fabBg,
                shape: BoxShape.circle,
                border: tokens.fabBorder != null
                    ? Border.all(color: tokens.fabBorder!, width: 1.5)
                    : null,
                boxShadow: tokens.fabShadow,
              ),
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => context.push('/feed/create'),
                  child: Icon(Icons.edit_rounded, color: tokens.fabFg),
                ),
              ),
            )
          : null,
      body: Column(
        children: [
          if (filter == null) _ModeSelector(mode: feedState.mode),
          if (filter != null) _HashtagBanner(hashtag: filter),
          Expanded(child: _buildBody(context, l10n, feedState, reposts)),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    FeedState state,
    List<RepostFeedEntry> reposts,
  ) {
    if (state.isLoading && state.posts.isEmpty) {
      return const PostCardListSkeleton();
    }

    final tokens = FeedTokens.of(context);

    if (state.error != null && state.posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.feedError,
              textAlign: TextAlign.center,
              style: TextStyle(color: tokens.mutedText),
            ),
            const SizedBox(height: 12),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: tokens.accent),
              onPressed: () =>
                  ref.read(feedNotifierProvider.notifier).refresh(),
              child: Text(l10n.retry),
            ),
          ],
        ),
      );
    }

    if (state.posts.isEmpty) {
      return Center(
        child: Text(
          l10n.feedEmpty,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13.5, color: tokens.mutedText),
        ),
      );
    }

    // Les repartages des comptes suivis n'enrichissent que les fils chronologiques
    // (following / recent) et hors filtre hashtag — on ne perturbe pas le tri forYou.
    final useReposts =
        state.mode != FeedMode.forYou && state.hashtagFilter == null;
    final rows = useReposts
        ? _mergeRows(state.posts, reposts)
        : List<Object>.from(state.posts);
    final mixedItems = _buildMixedItems(rows);
    final list = RefreshIndicator(
      onRefresh: () => ref.read(feedNotifierProvider.notifier).refresh(),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: mixedItems.length + (state.isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= mixedItems.length) {
            return const PostCardSkeleton();
          }
          final item = mixedItems[index];
          if (item is PostEntity) {
            // index % 12 borne la cascade pour que les items profonds
            // n'attendent pas plusieurs secondes avant d'apparaître.
            return AnimatedListItem(
              index: index % 12,
              child: PostCard(post: item),
            );
          }
          if (item is _RepostItem) {
            return AnimatedListItem(
              index: index % 12,
              child: PostCard(post: item.entry.post, repost: item.entry.ref),
            );
          }
          return AdSlot(adIndex: (item as _AdMarker).index);
        },
      ),
    );

    final showPill =
        state.pendingPosts.isNotEmpty && state.hashtagFilter == null;
    if (!showPill) return list;

    return Stack(
      children: [
        list,
        Positioned(
          top: 8,
          left: 0,
          right: 0,
          child: Center(
            child: ActionChip(
              backgroundColor: tokens.accent,
              avatar: Icon(
                Icons.arrow_upward_rounded,
                size: 16,
                color: tokens.onAccent,
              ),
              label: Text(
                l10n.feedNewPostsPill(state.pendingPosts.length),
                style: TextStyle(color: tokens.onAccent),
              ),
              onPressed: () {
                ref.read(feedNotifierProvider.notifier).showPendingPosts();
                if (_scrollController.hasClients) {
                  _scrollController.animateTo(
                    0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _ModeSelector extends ConsumerWidget {
  final FeedMode mode;

  const _ModeSelector({required this.mode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = FeedTokens.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: FeedSegmentedControl<FeedMode>(
        tokens: tokens,
        selected: mode,
        onChanged: (m) => ref.read(feedNotifierProvider.notifier).setMode(m),
        segments: [
          FeedSegment(
            value: FeedMode.forYou,
            icon: (c) => Icon(Icons.auto_awesome_rounded, size: 16, color: c),
            label: l10n.forYouTab,
          ),
          FeedSegment(
            value: FeedMode.following,
            icon: (c) => AppIcon(AppIcon.people, size: 16, color: c),
            label: l10n.followingTab,
          ),
          FeedSegment(
            value: FeedMode.recent,
            icon: (c) => Icon(Icons.schedule_rounded, size: 16, color: c),
            label: l10n.recentTab,
          ),
        ],
      ),
    );
  }
}

class _HashtagBanner extends StatelessWidget {
  final String hashtag;

  const _HashtagBanner({required this.hashtag});

  @override
  Widget build(BuildContext context) {
    final tokens = FeedTokens.of(context);
    return Container(
      width: double.infinity,
      color: tokens.accent.withValues(alpha: 0.1),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.tag_rounded, color: tokens.accent, size: 18),
          const SizedBox(width: 6),
          Text(
            hashtag,
            style: TextStyle(
              color: tokens.accent,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => context.pop(),
            child: AppIcon(AppIcon.close, size: 18, color: tokens.accent),
          ),
        ],
      ),
    );
  }
}
