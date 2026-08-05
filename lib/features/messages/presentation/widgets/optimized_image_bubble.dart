import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/adaptive_colors.dart';
import '../../../../shared/widgets/sheet_handle.dart';
import 'full_screen_image_viewer.dart';

class OptimizedImageBubble extends StatefulWidget {
  final String imageUrl;
  final String? caption;
  final String heroTag;
  final bool isMe;
  final VoidCallback? onTap;

  // L'heure et l'accusé de réception ne sont plus incrustés sur l'image :
  // ils vivent dans la ligne de méta posée sous la bulle par MessageBubble
  // (fiches 4a/6b, « une seule ligne d'heure pour tous les types »).
  final bool showSenderInfo;
  final String? senderName;

  // Long press actions
  final VoidCallback? onForward;
  final VoidCallback? onSave;
  final VoidCallback? onDelete;
  final VoidCallback? onShare;

  /// Si fourni, l'appui long ouvre le menu complet du message (Répondre,
  /// Épingler, Transférer…) au lieu du petit menu média — un message photo
  /// est ainsi épinglable comme n'importe quel autre type.
  final VoidCallback? onLongPress;
  final String? blurhash;

  const OptimizedImageBubble({
    super.key,
    required this.imageUrl,
    this.caption,
    required this.heroTag,
    this.isMe = false,
    this.onTap,
    this.showSenderInfo = false,
    this.senderName,
    this.onForward,
    this.onSave,
    this.onDelete,
    this.onShare,
    this.onLongPress,
    this.blurhash,
  });

  @override
  State<OptimizedImageBubble> createState() => _OptimizedImageBubbleState();
}

class _OptimizedImageBubbleState extends State<OptimizedImageBubble>
    with SingleTickerProviderStateMixin {
  double _downloadProgress = 0;
  bool _isLoading = true;
  bool _hasError = false;
  ImageProvider? _imageProvider;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  void _loadImage() {
    // Check for empty URL
    if (widget.imageUrl.isEmpty) {
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
      return;
    }

    _imageProvider = CachedNetworkImageProvider(
      widget.imageUrl,
      errorListener: (error) {
        if (mounted) {
          setState(() {
            _hasError = true;
            _isLoading = false;
          });
        }
      },
    );

    // Get image dimensions to handle loading state
    _imageProvider!
        .resolve(const ImageConfiguration())
        .addListener(
          ImageStreamListener(
            (info, _) {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                });
              }
            },
            onError: (exception, stackTrace) {
              if (mounted) {
                setState(() {
                  _hasError = true;
                  _isLoading = false;
                });
              }
            },
          ),
        );
  }

  void _showMediaContextMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SheetHandle(),
                const SizedBox(height: 20),

                if (widget.onForward != null)
                  ListTile(
                    leading: Icon(
                      Icons.forward,
                      color: context.textPrimaryColor,
                    ),
                    title: Text(
                      'Transférer',
                      style: TextStyle(color: context.textPrimaryColor),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      widget.onForward?.call();
                    },
                  ),

                if (widget.onSave != null)
                  ListTile(
                    leading: Icon(
                      Icons.download,
                      color: context.textPrimaryColor,
                    ),
                    title: Text(
                      'Enregistrer',
                      style: TextStyle(color: context.textPrimaryColor),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      widget.onSave?.call();
                    },
                  ),

                // Filet : destructif isolé en bas (§16).
                if (widget.onDelete != null)
                  Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: context.borderColor,
                  ),
                if (widget.onDelete != null)
                  ListTile(
                    leading: const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                    ),
                    title: const Text(
                      'Supprimer',
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      widget.onDelete?.call();
                    },
                  ),

                SizedBox(height: MediaQuery.of(ctx).padding.bottom),
              ],
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap:
          widget.onTap ??
          () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder:
                    (context) => FullScreenImageViewer(
                      imageUrl: widget.imageUrl,
                      heroTag: widget.heroTag,
                    ),
              ),
            );
          },
      // Priorité au menu complet du message (épinglage, réponse…) s'il est
      // fourni ; sinon repli sur le petit menu média (transférer/enregistrer).
      onLongPress:
          widget.onLongPress ??
          ((widget.onForward != null ||
                  widget.onSave != null ||
                  widget.onDelete != null)
              ? () => _showMediaContextMenu(context)
              : null),
      child: Hero(
        tag: widget.heroTag,
        child: Container(
          padding: const EdgeInsets.all(4),
          constraints: const BoxConstraints(maxWidth: 240, minWidth: 150),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft:
                  widget.isMe
                      ? const Radius.circular(16)
                      : const Radius.circular(4),
              bottomRight:
                  widget.isMe
                      ? const Radius.circular(4)
                      : const Radius.circular(16),
            ),
            // Match text bubble styling
            gradient:
                widget.isMe
                    ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        context.adaptiveSecondaryColor,
                        context.adaptiveSecondaryColor.withValues(alpha: 0.85),
                      ],
                    )
                    : null,
            color: widget.isMe ? null : context.surfaceColor,
            border:
                !widget.isMe
                    ? Border.all(
                      color:
                          context.isDarkMode
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.grey.withValues(alpha: 0.15),
                      width: 1,
                    )
                    : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Sender name for groups
              if (widget.showSenderInfo && widget.senderName != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 4, bottom: 4),
                  child: Text(
                    widget.senderName!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.adaptivePrimaryColor,
                    ),
                  ),
                ),

              // Image with overlay
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    // Image with aspect ratio preserved
                    _buildImage(context),

                    // Zoom indicator
                    if (!_isLoading && !_hasError)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: _buildZoomIndicator(context),
                      ),

                  ],
                ),
              ),

              // Caption below image but inside bubble
              if (widget.caption != null && widget.caption!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(
                    left: 8,
                    right: 8,
                    top: 8,
                    bottom: 4,
                  ),
                  child: Text(
                    widget.caption!,
                    style: TextStyle(
                      color: context.textPrimaryColor,
                      fontSize: 14,
                    ),
                    textAlign: widget.isMe ? TextAlign.right : TextAlign.left,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage(BuildContext context) {
    if (_hasError) {
      return Container(
        width: double.infinity,
        height: 200,
        color: context.surfaceVariantColor,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.broken_image_rounded,
                color: context.textTertiaryColor,
                size: 48,
              ),
              const SizedBox(height: 8),
              Text(
                'Image non disponible',
                style: TextStyle(
                  color: context.textTertiaryColor,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Use fixed aspect ratio for consistent size with loading state
    return AspectRatio(
      aspectRatio: 1.5,
      child: CachedNetworkImage(
        imageUrl: widget.imageUrl,
        fit: BoxFit.cover,
        errorWidget:
            (context, url, error) => Container(
              color: context.surfaceVariantColor,
              child: Center(
                child: Icon(
                  Icons.broken_image_rounded,
                  color: context.textTertiaryColor,
                  size: 48,
                ),
              ),
            ),
        progressIndicatorBuilder: (context, url, progress) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && progress.progress != null) {
              setState(() {
                _downloadProgress = progress.progress!;
              });
            }
          });
          return _buildLoadingIndicator(context);
        },
      ),
    );
  }

  Widget _buildLoadingIndicator(BuildContext context) {
    return Container(
      color: context.surfaceVariantColor,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: _downloadProgress > 0 ? _downloadProgress : null,
                    strokeWidth: 3,
                    color: context.adaptivePrimaryColor,
                    backgroundColor: context.adaptivePrimaryColor.withValues(
                      alpha: 0.2,
                    ),
                  ),
                  if (_downloadProgress > 0)
                    Text(
                      '${(_downloadProgress * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: context.adaptivePrimaryColor,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZoomIndicator(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.zoom_in, color: Colors.white, size: 16),
        ),
      ),
    );
  }

}
