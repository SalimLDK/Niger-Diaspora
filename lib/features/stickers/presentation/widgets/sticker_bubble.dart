import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/adaptive_colors.dart';
import '../../../messages/domain/entities/message_entity.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';

/// Widget for displaying a sticker message
/// Stickers are displayed without a bubble background (floating style)
class StickerBubble extends StatefulWidget {
  final String stickerUrl;
  final bool isAnimated;
  final bool isMe;
  final DateTime? timestamp;
  final MessageStatus? messageStatus;
  final List<String> readBy;
  final List<String> deliveredTo;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDoubleTap;

  /// Maximum size for the sticker
  static const double maxSize = 180;

  const StickerBubble({
    super.key,
    required this.stickerUrl,
    this.isAnimated = false,
    this.isMe = false,
    this.timestamp,
    this.messageStatus,
    this.readBy = const [],
    this.deliveredTo = const [],
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
          // Timestamp and status
          if (widget.timestamp != null) _buildTimestamp(context),
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

  Widget _buildTimestamp(BuildContext context) {
    final timeFormat = DateFormat.Hm();

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            timeFormat.format(widget.timestamp!),
            style: TextStyle(
              fontSize: 11,
              color: context.textSecondaryColor,
            ),
          ),
          if (widget.isMe) ...[
            const SizedBox(width: 4),
            _buildStatusIcon(),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusIcon() {
    final color = context.textSecondaryColor;

    switch (widget.messageStatus) {
      case MessageStatus.sending:
        return AppIcon(AppIcon.clock,
          size: 14,
          color: color,
        );
      case MessageStatus.sent:
        // Check if delivered or read
        if (widget.readBy.length > 1) {
          return AppIcon(AppIcon.doneAll,
            size: 14,
            color: context.adaptivePrimaryColor,
          );
        } else if (widget.deliveredTo.length > 1) {
          return AppIcon(AppIcon.doneAll,
            size: 14,
            color: color,
          );
        }
        return Icon(
          Icons.done,
          size: 14,
          color: color,
        );
      case MessageStatus.failed:
        return AppIcon(AppIcon.error,
          size: 14,
          color: context.errorColor,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
