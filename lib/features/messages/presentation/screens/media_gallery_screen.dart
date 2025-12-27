import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/adaptive_colors.dart';
import '../../domain/entities/message_entity.dart';
import '../providers/media_gallery_provider.dart';
import '../widgets/full_screen_image_viewer.dart';

class MediaGalleryScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final String? title;

  const MediaGalleryScreen({
    super.key,
    required this.conversationId,
    this.title,
  });

  @override
  ConsumerState<MediaGalleryScreen> createState() => _MediaGalleryScreenState();
}

class _MediaGalleryScreenState extends ConsumerState<MediaGalleryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaState = ref.watch(conversationMediaProvider(widget.conversationId));

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.arrow_back, color: context.textPrimaryColor),
        ),
        title: Text(
          widget.title ?? 'Médias partagés',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: context.textPrimaryColor,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: context.adaptivePrimaryColor,
          labelColor: context.adaptivePrimaryColor,
          unselectedLabelColor: context.textSecondaryColor,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.photo, size: 18),
                  const SizedBox(width: 8),
                  Text('Photos (${mediaState.images.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.insert_drive_file, size: 18),
                  const SizedBox(width: 8),
                  Text('Fichiers (${mediaState.files.length})'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _PhotosTab(
            images: mediaState.images,
            isLoading: mediaState.isLoading,
            onLoadMore: () {
              ref.read(conversationMediaProvider(widget.conversationId).notifier).loadMore();
            },
          ),
          _FilesTab(
            files: mediaState.files,
            isLoading: mediaState.isLoading,
          ),
        ],
      ),
    );
  }
}

/// Groupe les images par date
Map<String, List<MessageEntity>> _groupImagesByDate(List<MessageEntity> images) {
  final Map<String, List<MessageEntity>> grouped = {};
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final thisWeekStart = today.subtract(Duration(days: today.weekday - 1));
  final lastWeekStart = thisWeekStart.subtract(const Duration(days: 7));

  for (final image in images) {
    final imageDate = DateTime(
      image.createdAt.year,
      image.createdAt.month,
      image.createdAt.day,
    );

    String key;
    if (imageDate == today) {
      key = "Aujourd'hui";
    } else if (imageDate == yesterday) {
      key = 'Hier';
    } else if (imageDate.isAfter(thisWeekStart) || imageDate == thisWeekStart) {
      key = 'Cette semaine';
    } else if (imageDate.isAfter(lastWeekStart) || imageDate == lastWeekStart) {
      key = 'La semaine dernière';
    } else if (imageDate.year == now.year && imageDate.month == now.month) {
      key = 'Ce mois-ci';
    } else if (imageDate.year == now.year) {
      key = DateFormat.MMMM('fr_FR').format(image.createdAt);
      // Capitalize first letter
      key = key[0].toUpperCase() + key.substring(1);
    } else {
      key = DateFormat.yMMMM('fr_FR').format(image.createdAt);
      key = key[0].toUpperCase() + key.substring(1);
    }

    grouped.putIfAbsent(key, () => []);
    grouped[key]!.add(image);
  }

  return grouped;
}

class _PhotosTab extends StatelessWidget {
  final List<MessageEntity> images;
  final bool isLoading;
  final VoidCallback onLoadMore;

  const _PhotosTab({
    required this.images,
    required this.isLoading,
    required this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty && !isLoading) {
      return _buildEmptyState(context, 'Aucune photo');
    }

    final groupedImages = _groupImagesByDate(images);
    final sortedKeys = groupedImages.keys.toList();

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification &&
            notification.metrics.extentAfter < 200) {
          onLoadMore();
        }
        return false;
      },
      child: CustomScrollView(
        slivers: [
          ...sortedKeys.expand((dateKey) {
            final dateImages = groupedImages[dateKey]!;
            return [
              // Section header avec la date
              SliverToBoxAdapter(
                child: _DateSectionHeader(
                  title: dateKey,
                  count: dateImages.length,
                ),
              ),
              // Grille de photos pour cette date
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final image = dateImages[index];
                      return _PhotoGridItem(
                        message: image,
                        onTap: () => _openImage(context, image),
                      );
                    },
                    childCount: dateImages.length,
                  ),
                ),
              ),
            ];
          }),
          // Indicateur de chargement à la fin
          if (isLoading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          // Espace en bas
          const SliverToBoxAdapter(
            child: SizedBox(height: 24),
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
        heroTag: 'gallery_full_${message.id}',
        senderName: message.senderName,
        sentAt: message.createdAt,
      );
    }
  }

  Widget _buildEmptyState(BuildContext context, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: context.surfaceVariantColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.photo_library_outlined,
              size: 48,
              color: context.textTertiaryColor,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            message,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w500,
              color: context.textSecondaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Les photos partagées apparaîtront ici',
            style: TextStyle(
              fontSize: 14,
              color: context.textTertiaryColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _DateSectionHeader extends StatelessWidget {
  final String title;
  final int count;

  const _DateSectionHeader({
    required this.title,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: context.textPrimaryColor,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: context.adaptivePrimaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: context.adaptivePrimaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoGridItem extends StatelessWidget {
  final MessageEntity message;
  final VoidCallback onTap;

  const _PhotoGridItem({
    required this.message,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Hero(
        tag: 'gallery_full_${message.id}',
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: CachedNetworkImage(
                imageUrl: message.fileUrl ?? '',
                fit: BoxFit.cover,
                memCacheWidth: 400,
                placeholder: (context, url) => Container(
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
                errorWidget: (context, url, error) => Container(
                  color: context.surfaceVariantColor,
                  child: Icon(
                    Icons.broken_image_rounded,
                    color: context.textTertiaryColor,
                  ),
                ),
              ),
            ),
            // Afficher l'heure dans le coin
            Positioned(
              right: 4,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  DateFormat.Hm().format(message.createdAt),
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilesTab extends StatelessWidget {
  final List<MessageEntity> files;
  final bool isLoading;

  const _FilesTab({
    required this.files,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty && !isLoading) {
      return _buildEmptyState(context, 'Aucun fichier');
    }

    // Grouper les fichiers par date
    final groupedFiles = _groupFilesByDate(files);
    final sortedKeys = groupedFiles.keys.toList();

    return CustomScrollView(
      slivers: [
        ...sortedKeys.expand((dateKey) {
          final dateFiles = groupedFiles[dateKey]!;
          return [
            // Section header avec la date
            SliverToBoxAdapter(
              child: _DateSectionHeader(
                title: dateKey,
                count: dateFiles.length,
              ),
            ),
            // Liste de fichiers pour cette date
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final file = dateFiles[index];
                  return _FileListItem(message: file);
                },
                childCount: dateFiles.length,
              ),
            ),
          ];
        }),
        // Espace en bas
        const SliverToBoxAdapter(
          child: SizedBox(height: 24),
        ),
      ],
    );
  }

  Map<String, List<MessageEntity>> _groupFilesByDate(List<MessageEntity> files) {
    final Map<String, List<MessageEntity>> grouped = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (final file in files) {
      final fileDate = DateTime(
        file.createdAt.year,
        file.createdAt.month,
        file.createdAt.day,
      );

      String key;
      if (fileDate == today) {
        key = "Aujourd'hui";
      } else if (fileDate == yesterday) {
        key = 'Hier';
      } else if (fileDate.year == now.year) {
        key = DateFormat.MMMEd('fr_FR').format(file.createdAt);
      } else {
        key = DateFormat.yMMMd('fr_FR').format(file.createdAt);
      }

      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(file);
    }

    return grouped;
  }

  Widget _buildEmptyState(BuildContext context, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: context.surfaceVariantColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.folder_open_outlined,
              size: 48,
              color: context.textTertiaryColor,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            message,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w500,
              color: context.textSecondaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Les fichiers partagés apparaîtront ici',
            style: TextStyle(
              fontSize: 14,
              color: context.textTertiaryColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _FileListItem extends StatelessWidget {
  final MessageEntity message;

  const _FileListItem({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: context.isDarkMode
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: context.adaptivePrimaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _getFileIcon(message.mimeType),
            color: context.adaptivePrimaryColor,
          ),
        ),
        title: Text(
          message.fileName ?? 'Fichier',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: context.textPrimaryColor,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Text(
              message.fileSizeFormatted,
              style: TextStyle(
                fontSize: 12,
                color: context.textTertiaryColor,
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              width: 3,
              height: 3,
              decoration: BoxDecoration(
                color: context.textTertiaryColor,
                shape: BoxShape.circle,
              ),
            ),
            Text(
              DateFormat.Hm().format(message.createdAt),
              style: TextStyle(
                fontSize: 12,
                color: context.textTertiaryColor,
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              width: 3,
              height: 3,
              decoration: BoxDecoration(
                color: context.textTertiaryColor,
                shape: BoxShape.circle,
              ),
            ),
            Expanded(
              child: Text(
                message.senderName,
                style: TextStyle(
                  fontSize: 12,
                  color: context.textTertiaryColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        trailing: IconButton(
          onPressed: () => _openFile(message.fileUrl),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: context.adaptivePrimaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.download_rounded,
              color: context.adaptivePrimaryColor,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  IconData _getFileIcon(String? mimeType) {
    if (mimeType == null) return Icons.insert_drive_file;

    if (mimeType.contains('pdf')) return Icons.picture_as_pdf;
    if (mimeType.contains('word') || mimeType.contains('document')) {
      return Icons.description;
    }
    if (mimeType.contains('excel') || mimeType.contains('spreadsheet')) {
      return Icons.table_chart;
    }
    if (mimeType.contains('image')) return Icons.image;
    return Icons.insert_drive_file;
  }

  Future<void> _openFile(String? url) async {
    if (url == null) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
