import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/adaptive_colors.dart';
import '../../../../core/theme/dn_colors.dart';
import '../../../../core/router/routes/podcasts_routes.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/standard_search_bar.dart';
import '../../domain/entities/podcast_entity.dart';
import '../providers/podcast_provider.dart';
import '../widgets/podcast_card.dart';
import '../widgets/episode_tile.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';
import 'package:diaspo_niger/core/errors/error_handler.dart';

/// Home screen for podcasts discovery
class PodcastsHomeScreen extends ConsumerStatefulWidget {
  const PodcastsHomeScreen({super.key});

  @override
  ConsumerState<PodcastsHomeScreen> createState() => _PodcastsHomeScreenState();
}

class _PodcastsHomeScreenState extends ConsumerState<PodcastsHomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  List<PodcastEntity> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    final results = await ref
        .read(podcastNotifierProvider.notifier)
        .search(query);
    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.podcasts),
        actions: [
          IconButton(
            icon: AppIcon(AppIcon.add, color: Colors.grey[400]!),
            tooltip: l10n.createPodcast,
            onPressed: () => context.push(PodcastsRoutes.create),
          ),
          IconButton(
            icon: const Icon(Icons.folder_outlined),
            tooltip: l10n.myPodcasts,
            onPressed: () => context.push(PodcastsRoutes.myPodcasts),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              // Search bar
              StandardSearchBar(
                controller: _searchController,
                hintText: l10n.podcastsSearch,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                debounceDuration: const Duration(milliseconds: 500),
                isLoading: _isSearching,
                onSubmitted: _performSearch,
                onChanged: (value) {
                  if (value.isEmpty) {
                    setState(() {
                      _searchResults = [];
                      _isSearching = false;
                    });
                  }
                },
                onClear: () => _performSearch(''),
              ),
              // Tabs
              TabBar(
                controller: _tabController,
                tabs: [
                  Tab(text: l10n.discover),
                  Tab(text: l10n.categories),
                  Tab(text: l10n.subscriptions),
                ],
              ),
            ],
          ),
        ),
      ),
      body:
          _searchResults.isNotEmpty || _searchController.text.isNotEmpty
              ? _buildSearchResults(l10n)
              : TabBarView(
                controller: _tabController,
                children: [
                  _buildDiscoverTab(l10n),
                  _buildCategoriesTab(),
                  _buildSubscriptionsTab(l10n),
                ],
              ),
    );
  }

  Widget _buildSearchResults(AppLocalizations l10n) {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              l10n.noResultsFound,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final podcast = _searchResults[index];
        return PodcastCard(
          podcast: podcast,
          onTap: () => context.push('/podcasts/${podcast.id}'),
        );
      },
    );
  }

  Widget _buildDiscoverTab(AppLocalizations l10n) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(trendingPodcastsProvider);
        ref.invalidate(latestEpisodesProvider);
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bandeau « Reprendre » (§1d)
            _buildResumeBanner(l10n),

            // Trending section
            _buildSectionHeader(l10n.trending, l10n, onSeeAll: () {}),
            const SizedBox(height: 12),
            _buildTrendingPodcasts(l10n),
            const SizedBox(height: 24),

            // Latest episodes section
            _buildSectionHeader(l10n.newEpisodes, l10n, onSeeAll: () {}),
            const SizedBox(height: 12),
            _buildLatestEpisodes(l10n),
          ],
        ),
      ),
    );
  }

  /// Bandeau « Reprendre » (§1d) : dernier épisode commencé mais non terminé,
  /// avec sa progression ; le tap ouvre l'écran de détail d'épisode (d'où la
  /// lecture reprend).
  Widget _buildResumeBanner(AppLocalizations l10n) {
    final userData = ref.watch(podcastUserDataProvider).valueOrNull;
    final inProgress = userData?.inProgressEpisodes ?? const [];
    if (inProgress.isEmpty) return const SizedBox.shrink();

    // Le plus récemment écouté.
    final entry = inProgress.reduce(
      (a, b) => a.listenedAt.isAfter(b.listenedAt) ? a : b,
    );
    final episode = ref.watch(episodeProvider(entry.episodeId)).valueOrNull;
    if (episode == null) return const SizedBox.shrink();

    final total = episode.durationSeconds;
    final progress =
        total > 0 ? (entry.progressSeconds / total).clamp(0.0, 1.0) : 0.0;
    // Carte sombre ink + accent ocre (§1d, palette Sahel DNColors).
    const accent = DNColors.ochre;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Material(
        color: DNColors.ink,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push('/podcasts/episodes/${episode.id}'),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child:
                        episode.coverImageUrl != null &&
                                episode.coverImageUrl!.isNotEmpty
                            ? Image.network(
                              episode.coverImageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder:
                                  (_, __, ___) => Container(
                                    color: DNColors.ink2,
                                    child: Icon(Icons.podcasts, color: accent),
                                  ),
                            )
                            : Container(
                              color: DNColors.ink2,
                              child: Icon(Icons.podcasts, color: accent),
                            ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.resumeListening.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: accent,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        episode.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: DNColors.paper,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 4,
                          backgroundColor: DNColors.paper.withValues(alpha: 0.2),
                          valueColor: const AlwaysStoppedAnimation<Color>(accent),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.play_circle_fill_rounded, color: accent, size: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    String title,
    AppLocalizations l10n, {
    VoidCallback? onSeeAll,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        if (onSeeAll != null)
          TextButton(onPressed: onSeeAll, child: Text(l10n.seeAll)),
      ],
    );
  }

  Widget _buildTrendingPodcasts(AppLocalizations l10n) {
    final trendingAsync = ref.watch(trendingPodcastsProvider);

    return trendingAsync.when(
      loading:
          () => const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          ),
      error:
          (e, _) => SizedBox(
            height: 200,
            child: Center(
              child: Text(
                ErrorHandler.instance.getShortMessage(
                  ErrorHandler.instance.handleException(e),
                ),
              ),
            ),
          ),
      data: (podcasts) {
        if (podcasts.isEmpty) {
          return SizedBox(
            height: 200,
            child: Center(child: Text(l10n.noPodcastAvailable)),
          );
        }

        return SizedBox(
          height: 220,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: podcasts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final podcast = podcasts[index];
              return SizedBox(
                width: 160,
                child: PodcastCard(
                  podcast: podcast,
                  compact: true,
                  onTap: () => context.push('/podcasts/${podcast.id}'),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildLatestEpisodes(AppLocalizations l10n) {
    final latestAsync = ref.watch(latestEpisodesProvider);

    return latestAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(
          ErrorHandler.instance.getShortMessage(
            ErrorHandler.instance.handleException(e),
          ),
        ),
      ),
      data: (episodes) {
        if (episodes.isEmpty) {
          return Center(child: Text(l10n.noRecentEpisode));
        }

        return Column(
          children:
              episodes.take(5).map((episode) {
                return EpisodeTile(episode: episode);
              }).toList(),
        );
      },
    );
  }

  Widget _buildCategoriesTab() {
    const categories = PodcastCategory.values;

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.5,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        return _buildCategoryCard(category);
      },
    );
  }

  Widget _buildCategoryCard(PodcastCategory category) {
    // Palette DNColors (Sahel) au lieu de l'arc-en-ciel Material (§1d).
    final colors = {
      PodcastCategory.news: DNColors.terra,
      PodcastCategory.culture: DNColors.ochre,
      PodcastCategory.spirituality: DNColors.ink3,
      PodcastCategory.business: DNColors.teal,
      PodcastCategory.entertainment: DNColors.terra2,
      PodcastCategory.education: DNColors.leaf,
      PodcastCategory.storytelling: DNColors.ochre,
      PodcastCategory.sports: DNColors.teal,
      PodcastCategory.politics: DNColors.ink3,
      PodcastCategory.technology: DNColors.teal,
      PodcastCategory.health: DNColors.leaf,
      PodcastCategory.other: DNColors.ink4,
    };

    final icons = {
      PodcastCategory.news: Icons.newspaper,
      PodcastCategory.culture: Icons.theater_comedy,
      PodcastCategory.spirituality: Icons.self_improvement,
      PodcastCategory.business: Icons.business_center,
      PodcastCategory.entertainment: Icons.music_note,
      PodcastCategory.education: Icons.school,
      PodcastCategory.storytelling: Icons.auto_stories,
      PodcastCategory.sports: Icons.sports_soccer,
      PodcastCategory.politics: Icons.account_balance,
      PodcastCategory.technology: Icons.computer,
      PodcastCategory.health: Icons.favorite,
      PodcastCategory.other: Icons.category,
    };

    final label =
        PodcastEntity(
          id: '',
          title: '',
          coverImageUrl: '',
          hostId: '',
          hostName: '',
          category: category,
          language: 'fr',
          createdAt: DateTime.now(),
        ).categoryLabel;

    return Card(
      color: colors[category]?.withValues(alpha: 0.1),
      child: InkWell(
        onTap: () {
          _tabController.animateTo(0);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icons[category], size: 32, color: colors[category]),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: colors[category],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// « Aucun abonnement » (maquette 2f) : au lieu d'une icône grise et d'un
  /// bouton qui renvoie vers l'onglet Découvrir, on propose directement de
  /// quoi s'abonner — les podcasts qui marchent déjà — et de créer le sien.
  Widget _buildNoSubscriptionState(AppLocalizations l10n) {
    final trendingAsync = ref.watch(trendingPodcastsProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 32),
      children: [
        Icon(
          Icons.headphones_rounded,
          size: 56,
          color: context.textTertiaryColor,
        ),
        const SizedBox(height: 16),
        Text(
          l10n.podcastsDiasporaVoicesTitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: context.textPrimaryColor,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.subscribeToFindHere,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: context.textSecondaryColor),
        ),
        const SizedBox(height: 28),
        trendingAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const SizedBox.shrink(),
          data: (podcasts) {
            if (podcasts.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.podcastsPopularInDiaspora,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: context.textTertiaryColor,
                  ),
                ),
                const SizedBox(height: 10),
                ...podcasts.take(3).map(
                      (p) => _SuggestedPodcastRow(podcast: p),
                    ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () => context.push('/podcasts/create'),
          icon: const Icon(Icons.mic_rounded, size: 18),
          label: Text(l10n.podcastsCreateMine),
        ),
      ],
    );
  }

  Widget _buildSubscriptionsTab(AppLocalizations l10n) {
    final userDataAsync = ref.watch(podcastUserDataProvider);

    return userDataAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(
          ErrorHandler.instance.getShortMessage(
            ErrorHandler.instance.handleException(e),
          ),
        ),
      ),
      data: (userData) {
        if (userData == null || userData.subscribedPodcastIds.isEmpty) {
          return _buildNoSubscriptionState(l10n);
        }

        // Build list of subscribed podcasts
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: userData.subscribedPodcastIds.length,
          itemBuilder: (context, index) {
            final podcastId = userData.subscribedPodcastIds[index];
            final podcastAsync = ref.watch(podcastStreamProvider(podcastId));

            return podcastAsync.when(
              loading:
                  () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              error: (e, _) => const SizedBox.shrink(),
              data: (podcast) {
                if (podcast == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: PodcastCard(
                    podcast: podcast,
                    onTap: () => context.push('/podcasts/${podcast.id}'),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

/// Ligne de suggestion de l'état « aucun abonnement » : le podcast, et le
/// bouton pour s'y abonner sans quitter l'écran.
class _SuggestedPodcastRow extends ConsumerWidget {
  final PodcastEntity podcast;

  const _SuggestedPodcastRow({required this.podcast});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isSubscribed = ref.watch(isSubscribedProvider(podcast.id));

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              podcast.coverImageUrl,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 48,
                height: 48,
                color: DNColors.terra.withValues(alpha: 0.2),
                child: const Icon(Icons.podcasts_rounded, size: 22),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => context.push('/podcasts/${podcast.id}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    podcast.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.textPrimaryColor,
                    ),
                  ),
                  Text(
                    '${podcast.categoryLabel} · ${podcast.hostName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textSecondaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (isSubscribed)
            Icon(Icons.check_rounded, size: 20, color: context.successColor)
          else
            TextButton(
              onPressed: () => ref
                  .read(podcastNotifierProvider.notifier)
                  .subscribe(podcast),
              child: Text(l10n.podcastsSubscribe),
            ),
        ],
      ),
    );
  }
}
