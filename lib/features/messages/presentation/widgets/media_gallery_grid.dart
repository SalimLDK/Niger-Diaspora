import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/theme/adaptive_colors.dart';
import '../../domain/entities/message_entity.dart';
import '../providers/media_gallery_provider.dart';
import 'full_screen_image_viewer.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            l10n.sharedMedia,
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
                l10n.seeAll,
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

  Widget _buildGrid(
    BuildContext context,
    List<MessageEntity> images,
    bool hasMore,
  ) {
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
          final isLastItem =
              index == images.length - 1 && hasMore && onViewAll != null;

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
                placeholder:
                    (context, url) => Container(
                      color: context.surfaceVariantColor,
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.textTertiaryColor,
                        ),
                      ),
                    ),
                errorWidget:
                    (context, url, error) => Container(
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
  final String? conversationId;
  final VoidCallback? onViewAll;
  final bool showEmptyState;

  const MediaGalleryCompact({
    super.key,
    required this.conversationId,
    this.onViewAll,
    this.showEmptyState = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    if (conversationId == null) {
      return showEmptyState
          ? _buildEmptyState(context)
          : const SizedBox.shrink();
    }

    final mediaState = ref.watch(conversationMediaProvider(conversationId!));

    // Afficher le skeleton uniquement pendant le chargement initial
    if (mediaState.isLoading &&
        mediaState.isEmpty &&
        mediaState.error == null) {
      return _buildLoadingState(context);
    }

    // Afficher l'état vide si pas de médias (y compris en cas d'erreur)
    if (mediaState.isEmpty) {
      return showEmptyState
          ? _buildEmptyState(context)
          : const SizedBox.shrink();
    }

    final images = mediaState.images.take(6).toList();
    final totalCount = mediaState.images.length;
    final hasMore = totalCount > 6;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow:
            context.isDarkMode
                ? null
                : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header avec icône, titre, compteur et bouton "Voir tout"
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.adaptivePrimaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.photo_library_rounded,
                  size: 20,
                  color: context.adaptivePrimaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.sharedMedia,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimaryColor,
                      ),
                    ),
                    Text(
                      '$totalCount photo${totalCount > 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textTertiaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasMore && onViewAll != null)
                GestureDetector(
                  onTap: onViewAll,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: context.adaptivePrimaryColor.withValues(
                        alpha: 0.1,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.seeAll,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: context.adaptivePrimaryColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 12,
                          color: context.adaptivePrimaryColor,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Grille de photos améliorée
          SizedBox(
            height: 90,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: hasMore ? images.length + 1 : images.length,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                // Dernier élément avec "+X" overlay si plus d'images
                if (hasMore && index == images.length) {
                  return GestureDetector(
                    onTap: onViewAll,
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: context.adaptivePrimaryColor.withValues(
                          alpha: 0.1,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: context.adaptivePrimaryColor.withValues(
                            alpha: 0.3,
                          ),
                          width: 2,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '+${totalCount - 6}',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: context.adaptivePrimaryColor,
                            ),
                          ),
                          Text(
                            'photos',
                            style: TextStyle(
                              fontSize: 11,
                              color: context.adaptivePrimaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final image = images[index];
                return GestureDetector(
                  onTap: () => _openImage(context, image),
                  child: Hero(
                    tag: 'compact_${image.id}',
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: image.fileUrl ?? '',
                          width: 90,
                          height: 90,
                          fit: BoxFit.cover,
                          memCacheWidth: 250,
                          placeholder:
                              (context, url) => Container(
                                width: 90,
                                height: 90,
                                color: context.surfaceVariantColor,
                                child: Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: context.textTertiaryColor,
                                    ),
                                  ),
                                ),
                              ),
                          errorWidget:
                              (context, url, error) => Container(
                                width: 90,
                                height: 90,
                                color: context.surfaceVariantColor,
                                child: Icon(
                                  Icons.broken_image_rounded,
                                  size: 24,
                                  color: context.textTertiaryColor,
                                ),
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

  Widget _buildEmptyState(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow:
            context.isDarkMode
                ? null
                : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.surfaceVariantColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.photo_library_outlined,
              size: 24,
              color: context.textTertiaryColor,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.sharedMedia,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Aucun média partagé pour le moment',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.textTertiaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header skeleton
          Row(
            children: [
              Shimmer.fromColors(
                baseColor: context.surfaceVariantColor,
                highlightColor: context.surfaceColor,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: context.surfaceVariantColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Shimmer.fromColors(
                    baseColor: context.surfaceVariantColor,
                    highlightColor: context.surfaceColor,
                    child: Container(
                      width: 100,
                      height: 14,
                      decoration: BoxDecoration(
                        color: context.surfaceVariantColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Shimmer.fromColors(
                    baseColor: context.surfaceVariantColor,
                    highlightColor: context.surfaceColor,
                    child: Container(
                      width: 60,
                      height: 10,
                      decoration: BoxDecoration(
                        color: context.surfaceVariantColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Images skeleton
          SizedBox(
            height: 90,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 4,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                return Shimmer.fromColors(
                  baseColor: context.surfaceVariantColor,
                  highlightColor: context.surfaceColor,
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: context.surfaceVariantColor,
                      borderRadius: BorderRadius.circular(12),
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
