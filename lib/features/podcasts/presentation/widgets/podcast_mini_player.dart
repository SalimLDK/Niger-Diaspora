import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_provider.dart';
import '../providers/podcast_player_provider.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';

/// A mini-player widget that appears at the bottom of the screen
/// when a podcast is playing
class PodcastMiniPlayer extends ConsumerWidget {
  const PodcastMiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(podcastPlayerProvider);

    // Don't show if no episode is playing
    if (!playerState.hasEpisode) {
      return const SizedBox.shrink();
    }

    final episode = playerState.currentEpisode!;
    // Même parti pris que le lecteur plein écran : la barre est sombre en
    // permanence, quel que soit le thème de l'écran au-dessus duquel elle
    // flotte. Elle reprend le thème sombre de l'app (variante orange
    // comprise) plutôt qu'une palette à part.
    final themeColor = ref.watch(themeColorNotifierProvider);
    final theme = themeColor == AppThemeColor.orange
        ? AppTheme.orangeDarkTheme
        : AppTheme.darkTheme;

    return Theme(
      data: theme,
      child: GestureDetector(
        onTap: () {
          // Navigate to full player screen for the episode currently playing
          context.push('/podcasts/episodes/${episode.id}');
        },
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            boxShadow: [
              // Ombre plus marquée : sur un écran clair, une barre sombre a
              // besoin d'être détachée du contenu, pas fondue dedans.
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Progress bar
              LinearProgressIndicator(
                value: playerState.duration.inMilliseconds > 0
                    ? playerState.position.inMilliseconds /
                        playerState.duration.inMilliseconds
                    : 0,
                minHeight: 2,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.colorScheme.primary,
                ),
              ),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      // Artwork (with video badge for video episodes)
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: _buildThumbnail(
                              episode,
                              playerState.coverUrl,
                              theme.colorScheme,
                            ),
                          ),
                          if (episode.isVideoEpisode)
                            Positioned(
                              bottom: 2,
                              right: 2,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: Colors.black87,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: const AppIcon(AppIcon.video,
                                  color: Colors.white,
                                  size: 10,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      // Info
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              episode.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              playerState.podcastTitle ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Play/Pause button
                      if (playerState.isLoading)
                        const SizedBox(
                          width: 40,
                          height: 40,
                          child: Padding(
                            padding: EdgeInsets.all(8),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      else
                        IconButton(
                          icon: Icon(
                            playerState.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: 32,
                          ),
                          onPressed: () {
                            ref
                                .read(podcastPlayerProvider.notifier)
                                .togglePlayPause();
                          },
                        ),
                      // Close button
                      IconButton(
                        icon: AppIcon(AppIcon.close,
                            color: theme.colorScheme.onSurfaceVariant, size: 20,),
                        onPressed: () {
                          ref.read(podcastPlayerProvider.notifier).stop();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _buildThumbnail(
  episode,
  String? coverUrl,
  ColorScheme scheme,
) {
  final imageUrl = (episode.isVideoEpisode && episode.thumbnailUrl != null)
      ? episode.thumbnailUrl!
      : coverUrl;

  if (imageUrl != null) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: 48,
      height: 48,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(
        width: 48,
        height: 48,
        color: scheme.surfaceContainerHighest,
        child: AppIcon(AppIcon.podcasts, color: scheme.onSurfaceVariant),
      ),
      errorWidget: (_, __, ___) => Container(
        width: 48,
        height: 48,
        color: scheme.surfaceContainerHighest,
        child: AppIcon(AppIcon.podcasts, color: scheme.onSurfaceVariant),
      ),
    );
  }
  return Container(
    width: 48,
    height: 48,
    color: scheme.surfaceContainerHighest,
    child: AppIcon(AppIcon.podcasts, color: scheme.onSurfaceVariant),
  );
}

/// Helper extension for formatting duration
extension DurationFormat on Duration {
  String get formatted {
    final hours = inHours;
    final minutes = inMinutes.remainder(60);
    final seconds = inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
