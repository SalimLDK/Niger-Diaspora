import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/adaptive_colors.dart';

/// Widget for displaying a sticker message
/// Stickers are displayed without a bubble background (floating style)
class StickerBubble extends StatefulWidget {
  final String stickerUrl;
  final bool isAnimated;
  final bool isMe;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDoubleTap;

  /// Maximum size for the sticker
  static const double maxSize = 180;

  // L'heure et l'accusé de réception vivent dans la ligne de méta posée sous
  // la bulle par MessageBubble (fiches 4a/6b).

  const StickerBubble({
    super.key,
    required this.stickerUrl,
    this.isAnimated = false,
    this.isMe = false,
    this.onTap,
    this.onLongPress,
    this.onDoubleTap,
  });

  @override
  State<StickerBubble> createState() => _StickerBubbleState();
}

class _StickerBubbleState extends State<StickerBubble> {
  bool _isLoading = true;
  bool _hasError = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onDoubleTap: widget.onDoubleTap,
      child: Column(
        crossAxisAlignment:
            widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sticker image
          _buildSticker(),
        ],
      ),
    );
  }

  Widget _buildSticker() {
    if (widget.stickerUrl.isEmpty) {
      return _buildErrorPlaceholder();
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: StickerBubble.maxSize,
        maxHeight: StickerBubble.maxSize,
      ),
      child: CachedNetworkImage(
        imageUrl: widget.stickerUrl,
        fit: BoxFit.contain,
        placeholder: (context, url) => _buildLoadingPlaceholder(),
        errorWidget: (context, url, error) => _buildErrorPlaceholder(),
        imageBuilder: (context, imageProvider) {
          if (_isLoading) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                });
              }
            });
          }
          return Image(
            image: imageProvider,
            fit: BoxFit.contain,
            gaplessPlayback: true, // Important for animated stickers
          );
        },
      ),
    );
  }

  Widget _buildLoadingPlaceholder() {
    return SizedBox(
      width: StickerBubble.maxSize * 0.6,
      height: StickerBubble.maxSize * 0.6,
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              context.textSecondaryColor.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorPlaceholder() {
    if (!_hasError) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _hasError = true;
            _isLoading = false;
          });
        }
      });
    }
    return Container(
      width: StickerBubble.maxSize * 0.6,
      height: StickerBubble.maxSize * 0.6,
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        Icons.broken_image_outlined,
        color: context.textSecondaryColor,
        size: 32,
      ),
    );
  }

}
