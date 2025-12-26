import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/theme/adaptive_colors.dart';
import '../../domain/entities/message_entity.dart';
import '../providers/media_gallery_provider.dart';
import 'full_screen_image_viewer.dart';

/// Widget to display a grid of media (images) from a conversation
/// Used in profile and group detail screens
class MediaGalleryGrid extends ConsumerWidget {
  final String conversationId;
  final int maxItems;
  final VoidCallback? onViewAll;
  final bool showHeader;

  const MediaGalleryGrid({
    super.key,
    required this.conversationId,
    this.maxItems = 9,
    this.onViewAll,
    this.showHeader = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaState = ref.watch(conversationMediaProvider(conversationId));

    if (mediaState.isLoading && mediaState.isEmpty) {
      return _buildLoadingState(context);
    }

    if (mediaState.isEmpty) {
      return const SizedBox.shrink();
    }

    final images = mediaState.images.take(maxItems).toList();
    final hasMore = mediaState.images.length > maxItems;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeader) _buildHeader(context, hasMore),
        _buildGrid(context, images, hasMore),
      ],
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: context.surfaceVariantColor,
      highlightColor: context.surfaceColor,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: context.surfaceVariantColor,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool hasMore) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Médias partagés',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: context.textPrimaryColor,
            ),
          ),
          if (hasMore && onViewAll != null)
            TextButton(
              onPressed: onViewAll,
              child: Text(
                'Voir tout',
                style: TextStyle(
                  fontSize: 14,
                  color: context.adaptivePrimaryColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGrid(BuildContext context, List<MessageEntity> images, bool hasMore) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
        ),
        itemCount: images.length,
        itemBuilder: (context, index) {
          final image = images[index];
          final isLastItem = index == images.length - 1 && hasMore && onViewAll != null;

          return _MediaGridItem(
            message: image,
            showOverlay: isLastItem,
            overlayCount: (images.length - maxItems + 1).clamp(0, 999),
            onTap: () {
              if (isLastItem) {
                onViewAll?.call();
              } else {
                _openImage(context, image);
              }
            },
          );
        },
      ),
    );
  }

  void _openImage(BuildContext context, MessageEntity message) {
    if (message.fileUrl != null) {
      FullScreenImageViewer.show(
        context,
        imageUrl: message.fileUrl!,
        heroTag: 'gallery_${message.id}',
        senderName: message.senderName,
        sentAt: message.createdAt,
      );
    }
  }
}

class _MediaGridItem extends StatelessWidget {
  final MessageEntity message;
  final bool showOverlay;
  final int overlayCount;
  final VoidCallback onTap;

  const _MediaGridItem({
    required this.message,
    required this.showOverlay,
    required this.overlayCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Hero(
        tag: 'gallery_${message.id}',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: message.fileUrl ?? '',
                fit: BoxFit.cover,
                memCacheWidth: 300,
                placeholder: (context, url) => Container(
                  color: context.surfaceVariantColor,
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.textTertiaryColor,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: context.surfaceVariantColor,
                  child: Icon(
                    Icons.broken_image,
                    color: context.textTertiaryColor,
                  ),
                ),
              ),
              if (showOverlay)
                Container(
                  color: Colors.black.withValues(alpha: 0.6),
                  child: Center(
                    child: Text(
                      '+$overlayCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
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

/// Compact version for inline display in profile/group screens
class MediaGalleryCompact extends ConsumerWidget {
  final String conversationId;
  final VoidCallback? onViewAll;

  const MediaGalleryCompact({
    super.key,
    required this.conversationId,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaState = ref.watch(conversationMediaProvider(conversationId));

    if (mediaState.isLoading && mediaState.isEmpty) {
      return _buildLoadingState(context);
    }

    if (mediaState.isEmpty) {
      return const SizedBox.shrink();
    }

    final images = mediaState.images.take(6).toList();
    final hasMore = mediaState.images.length > 6;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.photo_library,
                    size: 18,
                    color: context.adaptivePrimaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Médias partagés',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.textPrimaryColor,
                    ),
                  ),
                ],
              ),
              if (hasMore && onViewAll != null)
                GestureDetector(
                  onTap: onViewAll,
                  child: Row(
                    children: [
                      Text(
                        'Voir tout',
                        style: TextStyle(
                          fontSize: 13,
                          color: context.adaptivePrimaryColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 12,
                        color: context.adaptivePrimaryColor,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final image = images[index];
                return GestureDetector(
                  onTap: () => _openImage(context, image),
                  child: Hero(
                    tag: 'compact_${image.id}',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: image.fileUrl ?? '',
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        memCacheWidth: 200,
                        placeholder: (context, url) => Container(
                          width: 72,
                          height: 72,
                          color: context.surfaceVariantColor,
                        ),
                        errorWidget: (context, url, error) => Container(
                          width: 72,
                          height: 72,
                          color: context.surfaceVariantColor,
                          child: Icon(
                            Icons.broken_image,
                            size: 20,
                            color: context.textTertiaryColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: context.surfaceVariantColor,
      highlightColor: context.surfaceColor,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: context.surfaceVariantColor,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  void _openImage(BuildContext context, MessageEntity message) {
    if (message.fileUrl != null) {
      FullScreenImageViewer.show(
        context,
        imageUrl: message.fileUrl!,
        heroTag: 'compact_${message.id}',
        senderName: message.senderName,
        sentAt: message.createdAt,
      );
    }
  }
}
