import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/podcast_entity.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';

/// Card widget displaying a podcast
class PodcastCard extends StatelessWidget {
  final PodcastEntity podcast;
  final VoidCallback? onTap;
  final bool compact;

  const PodcastCard({
    super.key,
    required this.podcast,
    this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return _buildCompactCard(context);
    }
    return _buildFullCard(context);
  }

  Widget _buildCompactCard(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image
            AspectRatio(
              aspectRatio: 1,
              child: CachedNetworkImage(
                imageUrl: podcast.coverImageUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: Colors.grey[300],
                  child: AppIcon(AppIcon.podcasts, color: Theme.of(context).iconTheme.color!, size: 40),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: Colors.grey[300],
                  child: AppIcon(AppIcon.podcasts, color: Theme.of(context).iconTheme.color!, size: 40),
                ),
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    podcast.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    podcast.hostName,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullCard(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            // Cover image
            SizedBox(
              width: 100,
              height: 100,
              child: CachedNetworkImage(
                imageUrl: podcast.coverImageUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: Colors.grey[300],
                  child: AppIcon(AppIcon.podcasts, color: Theme.of(context).iconTheme.color!, size: 32),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: Colors.grey[300],
                  child: AppIcon(AppIcon.podcasts, color: Theme.of(context).iconTheme.color!, size: 32),
                ),
              ),
            ),
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
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
                    Text(
                      podcast.hostName,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildChip(
                          podcast.categoryLabel,
                          Icons.category,
                        ),
                        const SizedBox(width: 8),
                        _buildChip(
                          '${podcast.totalEpisodes} ép.',
                          Icons.playlist_play,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Arrow
            Padding(
              padding: const EdgeInsets.all(12),
              child: AppIcon(AppIcon.chevronRight, color: Theme.of(context).iconTheme.color!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}
