import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/podcast_entity.dart';
import '../providers/podcast_provider.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';
import 'package:diaspo_niger/core/errors/error_handler.dart';

/// Screen showing user's created podcasts (creator dashboard)
class MyPodcastsScreen extends ConsumerWidget {
  const MyPodcastsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myPodcastsAsync = ref.watch(myPodcastsProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.myPodcasts),
        actions: [
          IconButton(
            icon: AppIcon(AppIcon.add, color: Theme.of(context).iconTheme.color!),
            tooltip: l10n.createPodcast,
            onPressed: () => context.push('/podcasts/create'),
          ),
        ],
      ),
      body: myPodcastsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (e, _) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const AppIcon(AppIcon.error, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    ErrorHandler.instance.getShortMessage(
                      ErrorHandler.instance.handleException(e),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(myPodcastsProvider),
                    child: Text(l10n.retry),
                  ),
                ],
              ),
            ),
        data: (podcasts) {
          if (podcasts.isEmpty) {
            return _buildEmptyState(context, l10n);
          }
          return _buildPodcastsList(context, ref, podcasts, l10n);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/podcasts/create'),
        icon: AppIcon(AppIcon.add, color: Theme.of(context).iconTheme.color!),
        label: Text(l10n.newPodcast),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppIcon(AppIcon.podcasts, size: 80, color: Colors.grey[400]!),
            const SizedBox(height: 24),
            Text(
              l10n.noPodcastsYet,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.noPodcastsDescription,
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => context.push('/podcasts/create'),
              icon: AppIcon(AppIcon.add, color: Theme.of(context).iconTheme.color!),
              label: Text(l10n.createMyFirstPodcast),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPodcastsList(
    BuildContext context,
    WidgetRef ref,
    List<PodcastEntity> podcasts,
    AppLocalizations l10n,
  ) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(myPodcastsProvider);
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: podcasts.length,
        itemBuilder: (context, index) {
          final podcast = podcasts[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _PodcastManagementCard(podcast: podcast),
          );
        },
      ),
    );
  }
}

/// Card for managing a podcast (creator view)
class _PodcastManagementCard extends ConsumerWidget {
  final PodcastEntity podcast;

  const _PodcastManagementCard({required this.podcast});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final episodesAsync = ref.watch(podcastEpisodesProvider(podcast.id));
    final l10n = AppLocalizations.of(context)!;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with cover
          InkWell(
            onTap: () => context.push('/podcasts/${podcast.id}'),
            child: Row(
              children: [
                // Cover image
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                  ),
                  child: Image.network(
                    podcast.coverImageUrl,
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (_, __, ___) => Container(
                          width: 100,
                          height: 100,
                          color: Theme.of(
                            context,
                          ).primaryColor.withValues(alpha: 0.2),
                          child: AppIcon(AppIcon.podcasts, color: Theme.of(context).iconTheme.color!, size: 40),
                        ),
                  ),
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        podcast.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _buildStatusChip(podcast.status),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              // Fréquence et prix (maquette 3a) : ce qui
                              // caractérise un podcast pour son créateur, plus
                              // que sa catégorie seule.
                              _subtitle(l10n, podcast),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildStat(
                            Icons.headphones,
                            '${podcast.totalPlayCount}',
                          ),
                          const SizedBox(width: 16),
                          _buildStat(
                            Icons.people,
                            '${podcast.subscriberCount}',
                          ),
                          const SizedBox(width: 16),
                          _buildStat(Icons.mic, '${podcast.totalEpisodes}'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),

          // Divider
          const Divider(height: 1),

          // Episodes preview
          episodesAsync.when(
            loading:
                () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            error: (_, __) => const SizedBox.shrink(),
            data: (episodes) {
              if (episodes.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    l10n.noEpisodesPublished,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                );
              }
              return Column(
                children: [
                  ...episodes
                      .take(2)
                      .map(
                        (episode) => ListTile(
                          leading: CircleAvatar(
                            child: Text('${episode.episodeNumber}'),
                          ),
                          title: Text(
                            episode.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            l10n.episodeListenInfo(
                              episode.formattedDuration,
                              episode.playCount,
                            ),
                          ),
                          trailing: AppIcon(AppIcon.chevronRight, color: Theme.of(context).iconTheme.color!),
                          onTap:
                              () => context.push(
                                '/podcasts/episodes/${episode.id}',
                              ),
                        ),
                      ),
                  if (episodes.length > 2)
                    TextButton(
                      onPressed: () => context.push('/podcasts/${podcast.id}'),
                      child: Text(l10n.viewAllEpisodes(episodes.length)),
                    ),
                ],
              );
            },
          ),

          // Actions
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                // « Voir la fiche » manquait : le seul moyen d'y aller était
                // de taper la carte, ce que rien n'indiquait.
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.push('/podcasts/${podcast.id}'),
                    child: Text(
                      l10n.podcastViewSheet,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        () => context.push('/podcasts/${podcast.id}/record'),
                    icon: AppIcon(AppIcon.add, color: Theme.of(context).iconTheme.color!, size: 18),
                    label: Text(
                      l10n.newEpisode,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  onSelected:
                      (value) => _handleAction(context, ref, value, l10n),
                  itemBuilder:
                      (context) => [
                        // « Voir la fiche » est désormais un bouton visible :
                        // le doublon dans le menu n'apporte plus rien.
                        PopupMenuItem(
                          value: 'stats',
                          child: ListTile(
                            leading: const Icon(Icons.bar_chart_rounded),
                            title: Text(l10n.podcastStatsTitle),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        const PopupMenuDivider(),
                        if (podcast.status == PodcastStatus.published)
                          PopupMenuItem(
                            value: 'pause',
                            child: ListTile(
                              leading: const Icon(Icons.pause_circle),
                              title: Text(l10n.pausePodcast),
                              contentPadding: EdgeInsets.zero,
                            ),
                          )
                        else
                          PopupMenuItem(
                            value: 'publish',
                            child: ListTile(
                              leading: const Icon(Icons.publish),
                              title: Text(l10n.publishPodcast),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        PopupMenuItem(
                          value: 'delete',
                          child: ListTile(
                            leading: const AppIcon(
                              AppIcon.delete,
                              color: Colors.red,
                            ),
                            title: Text(
                              l10n.delete,
                              style: const TextStyle(color: Colors.red),
                            ),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.more_horiz),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Fréquence et prix quand ils existent, catégorie sinon — on ne fabrique
  /// pas une périodicité qui n'a pas été renseignée.
  String _subtitle(AppLocalizations l10n, PodcastEntity p) {
    final parts = <String>[];
    if (p.episodeFrequency != null && p.episodeFrequency!.isNotEmpty) {
      parts.add(p.episodeFrequency!);
    }
    if (p.isPremium && p.premiumPrice != null) {
      final price = (p.premiumPrice! / 100).toStringAsFixed(2);
      parts.add('$price ${p.premiumCurrency ?? 'EUR'}');
    }
    if (parts.isEmpty) return p.categoryLabel;
    if (parts.length == 2) {
      return l10n.podcastFrequencyAndPrice(parts[0], parts[1]);
    }
    return parts.first;
  }

  Widget _buildStatusChip(PodcastStatus status) {
    Color color;
    switch (status) {
      case PodcastStatus.published:
        color = Colors.green;
        break;
      case PodcastStatus.paused:
        color = Colors.orange;
        break;
      case PodcastStatus.draft:
        color = Colors.grey;
        break;
      case PodcastStatus.archived:
        color = Colors.red;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        podcast.statusLabel,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStat(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(value, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      ],
    );
  }

  void _handleAction(
    BuildContext context,
    WidgetRef ref,
    String action,
    AppLocalizations l10n,
  ) {
    switch (action) {
      case 'view':
        context.push('/podcasts/${podcast.id}');
        break;
      case 'stats':
        context.push('/podcasts/${podcast.id}/stats');
        break;
      case 'pause':
      case 'publish':
        ref
            .read(podcastNotifierProvider.notifier)
            .togglePodcastStatus(podcast.id, podcast.status);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              action == 'pause' ? l10n.podcastPaused : l10n.podcastPublished,
            ),
          ),
        );
        break;
      case 'delete':
        _confirmDelete(context, ref, l10n);
        break;
    }
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(l10n.deletePodcastTitle),
            content: Text(l10n.deletePodcastWarning(podcast.title)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.cancel),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  ref
                      .read(podcastNotifierProvider.notifier)
                      .deletePodcast(podcast.id);
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(l10n.podcastDeleted)));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: Text(l10n.delete),
              ),
            ],
          ),
    );
  }
}
