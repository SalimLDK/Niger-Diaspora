import 'package:flutter/material.dart';
import '../../../../core/theme/dn_text.dart';
import '../../../../core/theme/dn_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/errors/error_handler.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/podcast_entity.dart';
import '../../domain/entities/podcast_episode_entity.dart';
import '../providers/podcast_provider.dart';

/// /podcasts/:podcastId/stats — tableau de bord d'un podcast (maquette 4a).
///
/// Tout est dérivé de données déjà présentes : les compteurs cumulés du
/// podcast et les compteurs par épisode. L'app ne stocke aucun historique
/// daté (pas de table d'événements d'écoute), donc il n'y a délibérément
/// aucune courbe d'évolution ici — elle serait inventée.
class PodcastStatsScreen extends ConsumerWidget {
  final String podcastId;

  const PodcastStatsScreen({super.key, required this.podcastId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final podcastAsync = ref.watch(podcastStreamProvider(podcastId));
    final episodesAsync = ref.watch(podcastEpisodesProvider(podcastId));

    return Scaffold(
      backgroundColor: context.dn.surface,
      appBar: AppBar(
        backgroundColor: context.dn.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        title: Text(
          l10n.podcastStatsTitle,
          style: DNText.serif(size: 22, color: context.dn.onSurface),
        ),
      ),
      body: podcastAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorBody(error: e),
        data: (podcast) {
          if (podcast == null) return _ErrorBody(error: l10n.podcastNotFound);
          return episodesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _ErrorBody(error: e),
            data: (episodes) => _StatsBody(
              podcast: podcast,
              episodes: episodes,
            ),
          );
        },
      ),
    );
  }
}

class _StatsBody extends StatelessWidget {
  final PodcastEntity podcast;
  final List<PodcastEpisodeEntity> episodes;

  const _StatsBody({required this.podcast, required this.episodes});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Les brouillons et les programmés ne sont écoutés par personne : les
    // compter fausserait toutes les moyennes.
    final published = episodes
        .where((e) => e.status == EpisodeStatus.published)
        .toList();

    if (published.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            l10n.podcastStatsNoData,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: context.dn.onSurface2),
          ),
        ),
      );
    }

    final totalPlays =
        published.fold<int>(0, (sum, e) => sum + e.playCount);
    final totalLikes = published.fold<int>(0, (sum, e) => sum + e.likeCount);
    final totalShares = published.fold<int>(0, (sum, e) => sum + e.shareCount);
    final totalDownloads =
        published.fold<int>(0, (sum, e) => sum + e.downloadCount);
    final totalSeconds =
        published.fold<int>(0, (sum, e) => sum + e.durationSeconds);
    final avgPlays = (totalPlays / published.length).round();

    final top = [...published]
      ..sort((a, b) => b.playCount.compareTo(a.playCount));
    final topFive = top.take(5).toList();
    final maxPlays = topFive.isEmpty ? 0 : topFive.first.playCount;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Compteurs principaux.
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 1.9,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            _StatTile(
              label: l10n.podcastStatsTotalPlays,
              value: _compact(totalPlays),
              icon: Icons.headphones_rounded,
            ),
            _StatTile(
              label: l10n.podcastStatsSubscribers,
              value: _compact(podcast.subscriberCount),
              icon: Icons.people_alt_rounded,
            ),
            _StatTile(
              label: l10n.podcastStatsEpisodes,
              value: '${published.length}',
              icon: Icons.mic_rounded,
            ),
            _StatTile(
              label: l10n.podcastStatsTotalDuration,
              value: _duration(totalSeconds),
              icon: Icons.schedule_rounded,
            ),
          ],
        ),
        const SizedBox(height: 24),

        _SectionTitle(l10n.podcastStatsEngagementTitle),
        const SizedBox(height: 8),
        _MetricRow(
          label: l10n.podcastStatsLikes,
          value: _compact(totalLikes),
          icon: Icons.favorite_rounded,
        ),
        _MetricRow(
          label: l10n.podcastStatsShares,
          value: _compact(totalShares),
          icon: Icons.share_rounded,
        ),
        _MetricRow(
          label: l10n.podcastStatsDownloads,
          value: _compact(totalDownloads),
          icon: Icons.download_rounded,
        ),
        _MetricRow(
          label: l10n.podcastStatsAvgPlaysPerEpisode,
          value: _compact(avgPlays),
          icon: Icons.equalizer_rounded,
        ),
        const SizedBox(height: 24),

        _SectionTitle(l10n.podcastStatsTopEpisodesTitle),
        const SizedBox(height: 8),
        ...topFive.map(
          (e) => _TopEpisodeBar(
            episode: e,
            maxPlays: maxPlays,
          ),
        ),
        const SizedBox(height: 24),

        _SectionTitle(l10n.podcastStatsRhythmTitle),
        const SizedBox(height: 8),
        _MetricRow(
          label: l10n.podcastStatsLastEpisode,
          value: _lastEpisodeLabel(published),
          icon: Icons.event_rounded,
        ),
        _MetricRow(
          label: l10n.podcastStatsAvgInterval,
          value: _avgIntervalLabel(l10n, published),
          icon: Icons.timeline_rounded,
        ),
        const SizedBox(height: 20),

        // On dit ce que ces chiffres ne sont pas, plutôt que de laisser
        // croire à un suivi dans le temps qui n'existe pas.
        Text(
          l10n.podcastStatsNoHistoryNote,
          style: TextStyle(fontSize: 12, color: context.dn.onSurface3),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  static String _compact(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)} M';
    }
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)} k';
    return '$value';
  }

  static String _duration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) return '${hours}h${minutes.toString().padLeft(2, '0')}';
    return '${minutes}min';
  }

  static String _lastEpisodeLabel(List<PodcastEpisodeEntity> published) {
    final dates = published
        .map((e) => e.publishedAt)
        .whereType<DateTime>()
        .toList()
      ..sort();
    if (dates.isEmpty) return '—';
    return DateFormat('d MMM yyyy', 'fr_FR').format(dates.last);
  }

  static String _avgIntervalLabel(
    AppLocalizations l10n,
    List<PodcastEpisodeEntity> published,
  ) {
    final dates = published
        .map((e) => e.publishedAt)
        .whereType<DateTime>()
        .toList()
      ..sort();
    // Un seul épisode ne définit aucun intervalle.
    if (dates.length < 2) return '—';
    final span = dates.last.difference(dates.first).inDays;
    return l10n.podcastStatsIntervalDays((span / (dates.length - 1)).round());
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: context.dn.onSurface3,
        ),
      );
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.dn.surface2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: context.dn.onSurface3),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: context.dn.onSurface,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: context.dn.onSurface2),
            ),
          ],
        ),
      );
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 18, color: context.dn.onSurface3),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: context.dn.onSurface2,
                ),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: context.dn.onSurface,
              ),
            ),
          ],
        ),
      );
}

/// Une ligne du classement : titre + barre proportionnelle au meilleur score.
class _TopEpisodeBar extends StatelessWidget {
  final PodcastEpisodeEntity episode;
  final int maxPlays;

  const _TopEpisodeBar({required this.episode, required this.maxPlays});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ratio = maxPlays == 0 ? 0.0 : episode.playCount / maxPlays;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${episode.episodeNumber}. ${episode.title}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: context.dn.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                l10n.podcastStatsPlaysCount(episode.playCount),
                style: TextStyle(
                  fontSize: 12,
                  color: context.dn.onSurface3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: context.dn.surfaceVariant,
              valueColor: AlwaysStoppedAnimation(context.adaptivePrimaryColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  final Object error;

  const _ErrorBody({required this.error});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            error is String
                ? error as String
                : ErrorHandler.instance.getShortMessage(
                    ErrorHandler.instance.handleException(error),
                  ),
            textAlign: TextAlign.center,
            style: TextStyle(color: context.dn.onSurface2),
          ),
        ),
      );
}
