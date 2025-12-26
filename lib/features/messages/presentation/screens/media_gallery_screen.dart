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

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification &&
            notification.metrics.extentAfter < 200) {
          onLoadMore();
        }
        return false;
      },
      child: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
        ),
        itemCount: images.length + (isLoading ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= images.length) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.adaptivePrimaryColor,
                ),
              ),
            );
          }

          final image = images[index];
          return _PhotoGridItem(
            message: image,
            onTap: () => _openImage(context, image),
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
          Icon(
            Icons.photo_library_outlined,
            size: 64,
            color: context.textTertiaryColor,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: context.textSecondaryColor,
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
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: CachedNetworkImage(
            imageUrl: message.fileUrl ?? '',
            fit: BoxFit.cover,
            memCacheWidth: 400,
            placeholder: (context, url) => Container(
              color: context.surfaceVariantColor,
            ),
            errorWidget: (context, url, error) => Container(
              color: context.surfaceVariantColor,
              child: Icon(
                Icons.broken_image,
                color: context.textTertiaryColor,
              ),
            ),
          ),
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

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: files.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final file = files[index];
        return _FileListItem(message: file);
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open,
            size: 64,
            color: context.textTertiaryColor,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: context.textSecondaryColor,
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
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
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
      subtitle: Text(
        '${message.fileSizeFormatted} • ${_formatDate(message.createdAt)}',
        style: TextStyle(
          fontSize: 12,
          color: context.textTertiaryColor,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message.senderName,
            style: TextStyle(
              fontSize: 11,
              color: context.textTertiaryColor,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => _openFile(message.fileUrl),
            icon: Icon(
              Icons.download,
              color: context.adaptivePrimaryColor,
              size: 20,
            ),
          ),
        ],
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

  String _formatDate(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return DateFormat.Hm().format(dateTime);
    } else if (difference.inDays < 7) {
      return DateFormat.E().format(dateTime);
    } else {
      return DateFormat.yMd().format(dateTime);
    }
  }

  Future<void> _openFile(String? url) async {
    if (url == null) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
