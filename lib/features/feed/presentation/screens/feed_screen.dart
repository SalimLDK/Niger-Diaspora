import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
          _random.nextInt(
            AdConfig.adFrequencyMax - AdConfig.adFrequencyMin + 1,
          ),
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
    DateTime keyOf(Object o) =>
        o is _RepostItem ? o.entry.ref.repostedAt : (o as PostEntity).createdAt;
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
      appBar:
          filter != null
              ? AppBar(
                backgroundColor: tokens.bg,
                // Repli vers l'accueil quand la pile est vide (entrée deep link).
                leading: IconButton(
                  icon: AppIcon(AppIcon.arrowBack, color: tokens.text),
                  onPressed:
                      () =>
                          context.canPop()
                              ? context.pop()
                              : context.go('/home'),
                ),
                title: Text(
                  l10n.feedTitle,
                  style: FeedText.heading(tokens, size: 20),
                ),
                centerTitle: true,
                elevation: 0,
              )
              : null,
      floatingActionButton:
          filter == null
              ? Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: tokens.fabBg,
                  shape: BoxShape.circle,
                  border:
                      tokens.fabBorder != null
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
          if (filter == null) const _FeedHeader(),
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
              onPressed:
                  () => ref.read(feedNotifierProvider.notifier).refresh(),
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
    final rows =
        useReposts
            ? _mergeRows(state.posts, reposts)
            : List<Object>.from(state.posts);
    final mixedItems = _buildMixedItems(rows);
    final list = RefreshIndicator(
      onRefresh: () => ref.read(feedNotifierProvider.notifier).refresh(),
      child: ListView.builder(
        controller: _scrollController,
        // Réserve basse de 100 px : le FAB flotte au-dessus du dernier post.
        padding: const EdgeInsets.only(top: 8, bottom: 100),
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

    // Tablette / desktop : colonne centrale de largeur bornée (le fil ne
    // s'étire pas sur toute la largeur). Le rail de navigation et la colonne
    // droite (hashtags / à suivre) restent à câbler côté données.
    final wide = MediaQuery.of(context).size.width >= 700;
    final content =
        wide
            ? Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: list,
              ),
            )
            : list;

    final showPill =
        state.pendingPosts.isNotEmpty && state.hashtagFilter == null;
    if (!showPill) return content;

    return Stack(
      children: [
        content,
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

/// En-tête du fil (remplace l'AppBar centrée) : sur-titre daté, titre
/// « Le fil. », recherche et avatar « Mon espace ».
class _FeedHeader extends StatelessWidget {
  const _FeedHeader();

  @override
  Widget build(BuildContext context) {
    final tokens = FeedTokens.of(context);
    final l10n = AppLocalizations.of(context)!;
    final lang = Localizations.localeOf(context).languageCode;

    // Date du jour, localisée et en majuscules (sur-titre monospace).
    final dateLabel = MaterialLocalizations.of(
      context,
    ).formatFullDate(DateTime.now());
    final overColor =
        tokens.isDark ? const Color(0xFF8E86C4) : const Color(0xFF9A6A3A);

    // Titre « Le fil. » : le point prend la couleur d'accent.
    final baseTitle = lang == 'en' ? 'The feed' : 'Le fil';
    final titleStyle = FeedText.heading(tokens, size: tokens.isDark ? 24 : 26);

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    dateLabel.toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10.5,
                      letterSpacing: 1.05,
                      fontWeight: FontWeight.w600,
                      color: overColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text.rich(
                    TextSpan(
                      style: titleStyle,
                      children: [
                        TextSpan(text: baseTitle),
                        TextSpan(
                          text: '.',
                          style: titleStyle.copyWith(color: tokens.accent),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _HeaderCircleButton(
              tokens: tokens,
              onTap: () => context.push('/search'),
              tooltip: l10n.searchLabel,
              child: AppIcon(AppIcon.search, size: 20, color: tokens.text),
            ),
            const SizedBox(width: 10),
            _MySpaceAvatar(tokens: tokens),
          ],
        ),
      ),
    );
  }
}

class _HeaderCircleButton extends StatelessWidget {
  final FeedTokens tokens;
  final Widget child;
  final VoidCallback onTap;
  final String? tooltip;

  const _HeaderCircleButton({
    required this.tokens,
    required this.child,
    required this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: tokens.surface,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: 40, height: 40, child: Center(child: child)),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip!, child: button) : button;
  }
}

/// Avatar « Mon espace » (anneau accent) → route `/feed/space`.
class _MySpaceAvatar extends StatelessWidget {
  final FeedTokens tokens;

  const _MySpaceAvatar({required this.tokens});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final photoUrl = user?.photoURL;
    final initial =
        (user?.displayName?.trim().isNotEmpty ?? false)
            ? user!.displayName!.trim()[0].toUpperCase()
            : '?';

    return GestureDetector(
      onTap: () => context.push('/feed/space'),
      child: Container(
        width: 40,
        height: 40,
        padding: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: tokens.accent, width: 1.5),
        ),
        child: ClipOval(
          child:
              (photoUrl != null && photoUrl.isNotEmpty)
                  ? CachedNetworkImage(
                    imageUrl: photoUrl,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _initialAvatar(initial),
                  )
                  : _initialAvatar(initial),
        ),
      ),
    );
  }

  Widget _initialAvatar(String initial) {
    return Container(
      color: tokens.avatarBg,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: tokens.avatarFg,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
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
        fullWidth: true,
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
            style: TextStyle(color: tokens.accent, fontWeight: FontWeight.w600),
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
