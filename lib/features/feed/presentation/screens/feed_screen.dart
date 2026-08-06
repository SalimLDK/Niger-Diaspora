import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:diaspo_niger/shared/widgets/animated_list_item.dart';
import 'package:diaspo_niger/shared/widgets/offline_banner.dart';
import '../../../../core/constants/ad_config.dart';
import '../../domain/entities/post_entity.dart';
import '../../domain/repositories/feed_repository.dart';
import '../providers/feed_provider.dart';
import '../theme/feed_text.dart';
import '../theme/feed_tokens.dart';
import '../widgets/ad_slot.dart';
import '../widgets/feed_error_state.dart';
import '../widgets/feed_segmented_control.dart';
import '../widgets/post_card.dart';
import '../widgets/post_card_skeleton.dart';
import '../widgets/story_rail.dart';
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

  /// Filtre géographique actif (ville de l'auteur). `null` = toutes.
  ///
  /// Le filtre s'applique aux posts déjà chargés via [PostEntity.authorCity]
  /// (renseigné à la création depuis la ville du profil).
  String? _cityFilter;

  /// Rail de stories replié (§4 : `scrollOffset > 24`) en une barre compacte.
  bool _storyRailCollapsed = false;

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
    // Rail de stories replié au défilement (§4, seuil 24px).
    final collapsed = _scrollController.position.pixels > 24;
    if (collapsed != _storyRailCollapsed) {
      setState(() => _storyRailCollapsed = collapsed);
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

  /// Ville de l'auteur d'une ligne de fil (post ou repartage), ou `null`.
  String? _cityOf(Object row) => row is _RepostItem
      ? row.entry.post.authorCity
      : (row is PostEntity ? row.authorCity : null);

  /// Villes distinctes présentes dans les posts chargés (pour les chips de
  /// filtre), triées par ordre alphabétique. Vide s'il n'y a pas de quoi filtrer.
  List<String> _distinctCities(List<PostEntity> posts) {
    final set = <String>{};
    for (final p in posts) {
      final c = p.authorCity;
      if (c != null && c.trim().isNotEmpty) set.add(c.trim());
    }
    final list = set.toList()..sort();
    return list;
  }

  /// Hashtags les plus fréquents parmi les posts chargés (rail droit tablette).
  List<String> _topHashtags(List<PostEntity> posts, {int max = 8}) {
    final counts = <String, int>{};
    for (final p in posts) {
      for (final tag in p.hashtags) {
        final t = tag.trim();
        if (t.isEmpty) continue;
        counts[t] = (counts[t] ?? 0) + 1;
      }
    }
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(max).map((e) => e.key).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final feedState = ref.watch(feedNotifierProvider);
    final filter = feedState.hashtagFilter ?? widget.hashtagFilter;
    final reposts =
        ref.watch(feedRepostsProvider).valueOrNull ?? const <RepostFeedEntry>[];
    final tokens = FeedTokens.of(context);
    final wide = MediaQuery.of(context).size.width >= 700;
    // Le rail droit (tablette) héberge les filtres villes ; sur téléphone ils
    // s'affichent en rangée de chips sous le sélecteur de mode.
    final cities =
        filter == null ? _distinctCities(feedState.posts) : const <String>[];
    // FAB 64 px sur tablette (52 sur téléphone), cf. handoff tour 4b.
    final fabSize = wide ? 64.0 : 52.0;

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
                width: fabSize,
                height: fabSize,
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
      // Le fil vit sur du contenu distant : hors-ligne, il faut le dire plutôt
      // que de laisser croire à un fil vide ou figé.
      body: OfflineBanner(
        child: Column(
          children: [
            if (filter == null) const _FeedHeader(),
            if (filter == null) _ModeSelector(mode: feedState.mode),
            // Filtres villes (téléphone) : rangée de chips scrollable.
            if (filter == null && !wide && cities.length >= 2)
              _CityFilterChips(
                cities: cities,
                selected: _cityFilter,
                onChanged: (c) => setState(() => _cityFilter = c),
              ),
            if (filter == null)
              StoryRail(
                collapsed: _storyRailCollapsed,
                onExpand: () {
                  if (_scrollController.hasClients) {
                    _scrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                  setState(() => _storyRailCollapsed = false);
                },
              ),
            if (filter != null) _HashtagBanner(hashtag: filter),
            // Les publications viennent du cache : le dire, sinon
            // l'utilisateur croit lire un fil à jour.
            if (feedState.isFromCache)
              FeedCachedNotice(cachedAt: feedState.cachedAt),
            // Publications dont l'envoi a échoué : en tête, avant tout le
            // reste, pour que l'utilisateur les voie sans avoir à chercher.
            ...feedState.failedPosts.map(
              (p) => FailedPostCard(
                content: p.content,
                onRetry: () =>
                    ref.read(feedNotifierProvider.notifier).retryFailedPost(p),
                onDiscard: () => ref
                    .read(feedNotifierProvider.notifier)
                    .discardFailedPost(p),
              ),
            ),
            Expanded(
              child: _buildBody(context, l10n, feedState, reposts, wide),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    FeedState state,
    List<RepostFeedEntry> reposts,
    bool wide,
  ) {
    if (state.isLoading && state.posts.isEmpty) {
      return const PostCardListSkeleton();
    }

    final tokens = FeedTokens.of(context);

    // Les quatre échecs de la maquette 2b, chacun avec son message et son
    // action — au lieu du même « Impossible de charger » + « Réessayer ».
    if (state.error != null && state.posts.isEmpty) {
      return FeedErrorState(
        failure: state.failure ?? FeedFailure.unknown,
        onRetry: () => ref.read(feedNotifierProvider.notifier).refresh(),
      );
    }

    if (state.posts.isEmpty) {
      return Center(
        child: Text(
          l10n.feedEmpty,
          textAlign: TextAlign.center,
          style: FeedText.body(
            tokens,
            size: 13.5,
            color: tokens.mutedText,
          ),
        ),
      );
    }

    // Les repartages des comptes suivis n'enrichissent que les fils chronologiques
    // (following / recent) et hors filtre hashtag — on ne perturbe pas le tri forYou.
    final useReposts =
        state.mode != FeedMode.forYou && state.hashtagFilter == null;
    var rows =
        useReposts
            ? _mergeRows(state.posts, reposts)
            : List<Object>.from(state.posts);
    // Filtre ville (posts chargés uniquement — pas de filtre serveur).
    if (_cityFilter != null) {
      rows = rows.where((o) => _cityOf(o) == _cityFilter).toList();
    }
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

    // Filtre ville actif mais aucun post chargé ne correspond : notice claire
    // avec action pour lever le filtre (plutôt qu'un écran vide).
    if (_cityFilter != null && rows.isEmpty) {
      return _CityFilterEmpty(
        city: _cityFilter!,
        onClear: () => setState(() => _cityFilter = null),
      );
    }

    // Tablette / desktop : colonne centrale bornée + rail droit (filtres villes
    // + hashtags du moment, dérivés des posts chargés). Le rail de navigation
    // gauche reste géré par le shell de l'app (pas de double navigation).
    final Widget content;
    if (wide) {
      content = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: list,
              ),
            ),
          ),
          SizedBox(
            width: 330,
            child: _FeedRightRail(
              cities: _distinctCities(state.posts),
              selectedCity: _cityFilter,
              onCityChanged: (c) => setState(() => _cityFilter = c),
              hashtags: _topHashtags(state.posts),
            ),
          ),
        ],
      );
    } else {
      content = list;
    }

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
                style: FeedText.body(tokens, color: tokens.onAccent),
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
    final baseTitle = lang == 'en' ? 'The feed' : l10n.homeServiceFeed;
    final titleStyle = FeedText.heading(tokens, size: tokens.isDark ? 24 : 26);

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Le fil n'est pas un onglet de la barre principale : on y entre
            // par un `push` depuis Accueil, donc sans barre de navigation. La
            // maquette n'a pas de flèche de retour parce qu'elle le suppose
            // onglet — sans elle, on entrait dans le fil sans pouvoir en
            // sortir autrement qu'en quittant l'app.
            if (context.canPop()) ...[
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => context.pop(),
                child: SizedBox(
                  width: 34,
                  height: 44,
                  child: Center(
                    child: AppIcon(
                      AppIcon.arrowBack,
                      size: 24,
                      color: tokens.text,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
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
        style: FeedText.body(
          tokens,
          size: 15,
          weight: FontWeight.w600,
          color: tokens.avatarFg,
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

/// Rangée scrollable de chips de Filtre ville (téléphone). Le premier chip
/// « Tous » réinitialise le filtre ; le chip actif est plein avec l'icône
/// de localisation.
class _CityFilterChips extends StatelessWidget {
  final List<String> cities;
  final String? selected;
  final ValueChanged<String?> onChanged;

  const _CityFilterChips({
    required this.cities,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = FeedTokens.of(context);
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _CityChip(
            label: l10n.all,
            active: selected == null,
            tokens: tokens,
            onTap: () => onChanged(null),
          ),
          const SizedBox(width: 8),
          for (final c in cities) ...[
            _CityChip(
              label: c,
              active: selected == c,
              tokens: tokens,
              showLocationIcon: true,
              onTap: () => onChanged(c),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _CityChip extends StatelessWidget {
  final String label;
  final bool active;
  final FeedTokens tokens;
  final VoidCallback onTap;
  final bool showLocationIcon;

  const _CityChip({
    required this.label,
    required this.active,
    required this.tokens,
    required this.onTap,
    this.showLocationIcon = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = active ? tokens.bg : tokens.mutedText;
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: active ? tokens.text : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: active ? tokens.text : tokens.divider),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (active && showLocationIcon) ...[
                AppIcon(AppIcon.location, size: 14, color: fg),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: FeedText.body(
                  tokens,
                  size: 13,
                  weight: active ? FontWeight.w600 : FontWeight.w400,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Notice affichée quand un Filtre ville ne correspond à aucun post chargé.
class _CityFilterEmpty extends StatelessWidget {
  final String city;
  final VoidCallback onClear;

  const _CityFilterEmpty({required this.city, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final tokens = FeedTokens.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(AppIcon.location, size: 40, color: tokens.mutedText),
            const SizedBox(height: 12),
            Text(
              l10n.noPostsForFilter,
              textAlign: TextAlign.center,
              style: FeedText.body(tokens, size: 14, color: tokens.mutedText),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: tokens.accent,
                side: BorderSide(color: tokens.accent),
              ),
              onPressed: onClear,
              child: Text(l10n.seeAll),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rail droit (tablette) : filtres villes + hashtags du moment, dérivés des
/// posts chargés. Les panneaux « à suivre »/suggestions n'ont pas de provider
/// et ne sont pas repris.
class _FeedRightRail extends StatelessWidget {
  final List<String> cities;
  final String? selectedCity;
  final ValueChanged<String?> onCityChanged;
  final List<String> hashtags;

  const _FeedRightRail({
    required this.cities,
    required this.selectedCity,
    required this.onCityChanged,
    required this.hashtags,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = FeedTokens.of(context);
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 100),
      children: [
        if (cities.length >= 2)
          _RailCard(
            tokens: tokens,
            title: l10n.city,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _CityChip(
                  label: l10n.all,
                  active: selectedCity == null,
                  tokens: tokens,
                  onTap: () => onCityChanged(null),
                ),
                for (final c in cities)
                  _CityChip(
                    label: c,
                    active: selectedCity == c,
                    tokens: tokens,
                    showLocationIcon: true,
                    onTap: () => onCityChanged(c),
                  ),
              ],
            ),
          ),
        if (hashtags.isNotEmpty)
          _RailCard(
            tokens: tokens,
            title: l10n.trendingHashtags,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tag in hashtags)
                  GestureDetector(
                    onTap: () => context.push('/feed?hashtag=$tag'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: tokens.accent.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '#$tag',
                        style: FeedText.body(
                          tokens,
                          size: 13,
                          weight: FontWeight.w600,
                          color: tokens.hashtagColor,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _RailCard extends StatelessWidget {
  final FeedTokens tokens;
  final String title;
  final Widget child;

  const _RailCard({
    required this.tokens,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(tokens.radiusMd),
        border: Border.all(color: tokens.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: FeedText.body(
              tokens,
              size: 11,
              weight: FontWeight.w700,
              color: tokens.mutedText,
            ).copyWith(letterSpacing: 1.0),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _HashtagBanner extends ConsumerWidget {
  final String hashtag;

  const _HashtagBanner({required this.hashtag});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = FeedTokens.of(context);
    // Sans le `#`, cohérent avec le stockage local des hashtags suivis
    // (Mon espace, §5a).
    final tag = hashtag.startsWith('#') ? hashtag.substring(1) : hashtag;
    final isFollowed = ref.watch(
      followedHashtagsProvider.select((tags) => tags.contains(tag.toLowerCase())),
    );
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
            style: FeedText.body(
              tokens,
              weight: FontWeight.w600,
              color: tokens.accent,
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => ref.read(followedHashtagsProvider.notifier).toggle(tag),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isFollowed ? tokens.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: tokens.accent),
              ),
              child: Text(
                isFollowed ? 'Suivi' : l10n.followUser,
                style: FeedText.body(
                  tokens,
                  size: 12.5,
                  weight: FontWeight.w600,
                  color: isFollowed ? tokens.onAccent : tokens.accent,
                ),
              ),
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
