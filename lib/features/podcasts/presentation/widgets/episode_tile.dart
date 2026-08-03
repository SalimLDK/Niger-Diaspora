import 'package:flutter/material.dart';

import '../../../../shared/widgets/dn_sheet_handle.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/revenue_cat_provider.dart';
import '../../../../core/services/podcast_download_service.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/podcast_episode_entity.dart';
import '../providers/podcast_provider.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';

/// A tile widget for displaying a podcast episode with download capability
class EpisodeTile extends ConsumerWidget {
  final PodcastEpisodeEntity episode;
  final VoidCallback? onPlay;
  final bool showPodcastInfo;

  const EpisodeTile({
    super.key,
    required this.episode,
    this.onPlay,
    this.showPodcastInfo = false,
  });

  /// Épisode marqué terminé dans l'historique d'écoute.
  bool _isCompleted(WidgetRef ref) {
    final userData = ref.watch(podcastUserDataProvider).valueOrNull;
    if (userData == null) return false;
    return userData.listenHistory
        .any((h) => h.episodeId == episode.id && h.completed);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadState = ref.watch(downloadManagerProvider)[episode.id];
    final isDownloadedAsync = ref.watch(isEpisodeDownloadedProvider(episode.id));
    final hasPremiumAccess = ref.watch(hasPodcastPremiumProvider);

    // For premium episodes without access, replace tap/play with paywall redirect
    final isPremiumLocked = episode.isPremium && !hasPremiumAccess;

    // Prix d'abonnement premium (porté par le podcast parent), §1d.
    String? premiumPriceLabel;
    if (episode.isPremium) {
      final podcast =
          ref.watch(podcastStreamProvider(episode.podcastId)).valueOrNull;
      final cents = podcast?.premiumPrice;
      if (cents != null && cents > 0) {
        final amount = cents / 100;
        final text =
            amount == amount.roundToDouble() ? amount.toStringAsFixed(0) : amount.toStringAsFixed(2);
        final cur = podcast?.premiumCurrency ?? 'EUR';
        premiumPriceLabel = cur == 'EUR' ? '€$text' : '$text $cur';
      }
    }

    return InkWell(
      onTap: isPremiumLocked
          ? () => _showPremiumPaywall(context)
          : () => context.push('/podcasts/episodes/${episode.id}'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.borderColor.withValues(alpha: 0.5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Episode cover or number
            _buildCover(context),
            const SizedBox(width: 12),

            // Episode info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badges row: episode number + premium lock
                  Row(
                    children: [
                      // « Déjà écouté » (maquette 3b) : rien ne distinguait un
                      // épisode terminé d'un épisode jamais ouvert.
                      if (_isCompleted(ref))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4, right: 6),
                          child: Icon(
                            Icons.check_circle_rounded,
                            size: 14,
                            color: context.successColor,
                          ),
                        ),
                      if (episode.episodeNumber > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          margin: const EdgeInsets.only(bottom: 4, right: 6),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            AppLocalizations.of(context)!.podcastsEpisodeNumber(episode.episodeNumber),
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.orange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (episode.isPremium)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Colors.amber.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AppIcon(isPremiumLocked ? AppIcon.lock : AppIcon.star,
                                size: 10,
                                color: Colors.amber[700]!,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                premiumPriceLabel != null
                                    ? 'Premium · $premiumPriceLabel'
                                    : 'Premium',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: Colors.amber[700],
                                  fontWeight: FontWeight.w600,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),

                  // Title
                  Text(
                    episode.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // Description
                  if (episode.description != null && episode.description!.isNotEmpty)
                    Text(
                      episode.description!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.onSurfaceColor.withValues(alpha: 0.6),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 8),

                  // Duration and stats
                  Row(
                    children: [
                      AppIcon(AppIcon.clock,
                        size: 14,
                        color: context.onSurfaceColor.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDuration(episode.durationSeconds),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: context.onSurfaceColor.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.play_arrow,
                        size: 14,
                        color: context.onSurfaceColor.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${episode.playCount}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: context.onSurfaceColor.withValues(alpha: 0.5),
                        ),
                      ),
                      if (episode.sourceRoomId != null) ...[
                        const SizedBox(width: 12),
                        Icon(
                          Icons.headphones,
                          size: 14,
                          color: Colors.deepPurple.withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          AppLocalizations.of(context)!.podcastsLiveLabel,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.deepPurple,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Action buttons column
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Play / lock button
                IconButton(
                  icon: Icon(
                    isPremiumLocked ? Icons.lock : Icons.play_circle_filled,
                  ),
                  iconSize: 36,
                  color: isPremiumLocked ? Colors.amber[700] : Colors.orange,
                  onPressed: isPremiumLocked
                      ? () => _showPremiumPaywall(context)
                      : onPlay ?? () => context.push('/podcasts/episodes/${episode.id}'),
                ),

                // Download button (hidden for locked episodes)
                if (!isPremiumLocked)
                  _buildDownloadButton(context, ref, downloadState, isDownloadedAsync),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCover(BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.orange.withValues(alpha: 0.1),
        image: episode.coverImageUrl != null && episode.coverImageUrl!.isNotEmpty
            ? DecorationImage(
                image: NetworkImage(episode.coverImageUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: episode.coverImageUrl == null || episode.coverImageUrl!.isEmpty
          ? Center(
              child: Text(
                '${episode.episodeNumber}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildDownloadButton(
    BuildContext context,
    WidgetRef ref,
    DownloadState? downloadState,
    AsyncValue<bool> isDownloadedAsync,
  ) {
    // Video episodes are streamed — show a video badge instead of download button.
    if (episode.isVideoEpisode) {
      return const Padding(
        padding: EdgeInsets.all(6),
        child: AppIcon(AppIcon.video, size: 22, color: Colors.deepPurple),
      );
    }

    // Check if currently downloading
    if (downloadState?.isDownloading == true) {
      return SizedBox(
        width: 36,
        height: 36,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: downloadState!.progress,
              strokeWidth: 2,
              color: Colors.orange,
            ),
            IconButton(
              icon: AppIcon(AppIcon.close, color: Theme.of(context).iconTheme.color!, size: 16),
              onPressed: () {
                ref.read(downloadManagerProvider.notifier).cancelDownload(episode.id);
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      );
    }

    // Check if already downloaded
    return isDownloadedAsync.when(
      data: (isDownloaded) {
        if (isDownloaded) {
          return IconButton(
            icon: const Icon(Icons.download_done),
            iconSize: 24,
            color: Colors.green,
            tooltip: AppLocalizations.of(context)!.podcastsDownloaded,
            onPressed: () => _showDownloadOptions(context, ref),
          );
        }

        return IconButton(
          icon: const Icon(Icons.download_for_offline_outlined),
          iconSize: 24,
          color: context.onSurfaceColor.withValues(alpha: 0.6),
          tooltip: AppLocalizations.of(context)!.podcastsDownload,
          onPressed: () => _startDownload(ref),
        );
      },
      loading: () => const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (_, __) => IconButton(
        icon: const Icon(Icons.download_for_offline_outlined),
        iconSize: 24,
        color: context.onSurfaceColor.withValues(alpha: 0.6),
        onPressed: () => _startDownload(ref),
      ),
    );
  }

  void _startDownload(WidgetRef ref) {
    // Video episodes are streamed; offline download is audio-only.
    if (episode.isVideoEpisode) return;

    ref.read(downloadManagerProvider.notifier).startDownload(
      episodeId: episode.id,
      audioUrl: episode.audioUrl,
    );
  }

  void _showDownloadOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: DnSheetHandle(),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const AppIcon(AppIcon.checkCircle, color: Colors.green),
              title: Text(AppLocalizations.of(context)!.podcastsDownloaded),
              subtitle: Text(
                AppLocalizations.of(context)!.podcastsAvailableOffline,
                style: TextStyle(color: context.onSurfaceColor.withValues(alpha: 0.6)),
              ),
            ),
            const Divider(),
            ListTile(
              leading: const AppIcon(AppIcon.delete, color: Colors.red),
              title: Text(AppLocalizations.of(context)!.podcastsDeleteDownload),
              onTap: () {
                Navigator.pop(ctx);
                ref.read(downloadManagerProvider.notifier).deleteDownload(episode.id);
                ref.invalidate(isEpisodeDownloadedProvider(episode.id));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(AppLocalizations.of(context)!.podcastsDownloadDeleted)),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showPremiumPaywall(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: DnSheetHandle(),
              ),
              const AppIcon(AppIcon.star, color: Colors.amber, size: 48),
              const SizedBox(height: 12),
              Text(
                'Épisode Premium',
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Cet épisode est réservé aux abonnés premium. '
                'Abonnez-vous pour accéder à tout le contenu exclusif.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    // Navigate to the podcast detail page which has the subscribe button
                    if (episode.podcastId.isNotEmpty) {
                      context.push('/podcasts/${episode.podcastId}');
                    }
                  },
                  icon: AppIcon(AppIcon.star, color: Theme.of(context).iconTheme.color!),
                  label: Text(AppLocalizations.of(ctx)!.subscribeButton),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(AppLocalizations.of(ctx)!.laterButton),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }
}

/// A compact version of the episode tile for lists
class EpisodeTileCompact extends ConsumerWidget {
  final PodcastEpisodeEntity episode;
  final VoidCallback? onTap;

  const EpisodeTileCompact({
    super.key,
    required this.episode,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDownloadedAsync = ref.watch(isEpisodeDownloadedProvider(episode.id));

    return ListTile(
      onTap: onTap ?? () => context.push('/podcasts/episodes/${episode.id}'),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.orange.withValues(alpha: 0.1),
        ),
        child: Center(
          child: Text(
            '${episode.episodeNumber}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.orange,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      title: Text(
        episode.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Row(
        children: [
          Text(_formatDuration(episode.durationSeconds)),
          if (isDownloadedAsync.valueOrNull == true) ...[
            const SizedBox(width: 8),
            const Icon(Icons.download_done, size: 14, color: Colors.green),
          ],
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.play_circle_outline),
        color: Colors.orange,
        onPressed: onTap ?? () => context.push('/podcasts/episodes/${episode.id}'),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}min';
  }
}
