import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/services/file_download_service.dart';
import '../../../../core/theme/adaptive_colors.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

/// Full screen image viewer with zoom, pan, download, and share capabilities
class FullScreenImageViewer extends StatefulWidget {
  final String imageUrl;
  final String? heroTag;
  final String? senderName;
  final DateTime? sentAt;
  final bool showActions;
  final String? messageId;

  const FullScreenImageViewer({
    super.key,
    required this.imageUrl,
    this.heroTag,
    this.senderName,
    this.sentAt,
    this.showActions = true,
    this.messageId,
  });

  /// Show the full screen image viewer
  static void show(
    BuildContext context, {
    required String imageUrl,
    String? heroTag,
    String? senderName,
    DateTime? sentAt,
    bool showActions = true,
    String? messageId,
  }) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (context, animation, secondaryAnimation) {
          return FullScreenImageViewer(
            imageUrl: imageUrl,
            heroTag: heroTag,
            senderName: senderName,
            sentAt: sentAt,
            showActions: showActions,
            messageId: messageId,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  bool _isDownloading = false;
  double _downloadProgress = 0;

  Future<void> _downloadImage() async {
    if (_isDownloading) return;

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
    });

    final service = FileDownloadService();

    // Request permission if needed
    final hasPermission = await service.hasGalleryPermission();
    if (!hasPermission) {
      final granted = await service.requestGalleryPermission();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.galleryPermissionDenied),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isDownloading = false);
        }
        return;
      }
    }

    final success = await service.downloadImageToGallery(
      widget.imageUrl,
      onProgress: (received, total) {
        if (total > 0) {
          setState(() {
            _downloadProgress = received / total;
          });
        }
      },
    );

    if (mounted) {
      setState(() => _isDownloading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? l10n.imageSavedToGallery
                : l10n.errorDownloading,
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _shareImage() async {
    try {
      await SharePlus.instance.share(ShareParams(text: widget.imageUrl));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorSharing),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return "Aujourd'hui à ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
    } else if (difference.inDays == 1) {
      return "Hier à ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
    } else {
      return "${date.day}/${date.month}/${date.year}";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black54,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: widget.senderName != null || widget.sentAt != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.senderName != null)
                    Text(
                      widget.senderName!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (widget.sentAt != null)
                    Text(
                      _formatDate(widget.sentAt!),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                ],
              )
            : null,
        actions: widget.showActions
            ? [
                if (_isDownloading)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        value: _downloadProgress > 0 ? _downloadProgress : null,
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  )
                else
                  IconButton(
                    onPressed: _downloadImage,
                    icon: const Icon(Icons.download),
                    tooltip: l10n.download,
                  ),
                IconButton(
                  onPressed: _shareImage,
                  icon: const Icon(Icons.share),
                  tooltip: l10n.share,
                ),
              ]
            : null,
      ),
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Center(
          child: widget.heroTag != null
              ? Hero(
                  tag: widget.heroTag!,
                  child: _buildPhotoView(),
                )
              : _buildPhotoView(),
        ),
      ),
    );
  }

  Widget _buildPhotoView() {
    return PhotoView(
      imageProvider: CachedNetworkImageProvider(widget.imageUrl),
      loadingBuilder: (context, event) {
        return Center(
          child: CircularProgressIndicator(
            value: event?.expectedTotalBytes != null
                ? event!.cumulativeBytesLoaded / event.expectedTotalBytes!
                : null,
            color: Colors.white,
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.broken_image,
                size: 64,
                color: context.textTertiaryColor,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.imageNotAvailable,
                style: TextStyle(
                  color: context.textSecondaryColor,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        );
      },
      minScale: PhotoViewComputedScale.contained,
      maxScale: PhotoViewComputedScale.covered * 4,
      backgroundDecoration: const BoxDecoration(color: Colors.black),
      enableRotation: false,
    );
  }
}
