import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/adaptive_colors.dart';
import '../../domain/entities/message_entity.dart';

/// Bubble pour l'affichage de vidéos dans les messages avec style WhatsApp
class VideoBubble extends StatelessWidget {
  final String videoUrl;
  final String? thumbnailUrl;
  final int? duration; // en secondes
  final String? caption;
  final bool isMe;
  final VoidCallback? onTap;

  // WhatsApp-style parameters
  final DateTime? timestamp;
  final MessageStatus? messageStatus;
  final bool showSenderInfo;
  final String? senderName;
  final bool isHD;

  // Long press actions
  final VoidCallback? onForward;
  final VoidCallback? onSave;
  final VoidCallback? onDelete;
  final VoidCallback? onShare;

  /// Si fourni, l'appui long ouvre le menu complet du message (Épingler,
  /// Répondre…) au lieu du petit menu média.
  final VoidCallback? onLongPress;
  final List<String>? readBy;
  final List<String>? deliveredTo;
  final String? messageId;
  final String? blurhash;

  const VideoBubble({
    super.key,
    required this.videoUrl,
    this.thumbnailUrl,
    this.duration,
    this.caption,
    required this.isMe,
    this.onTap,
    this.timestamp,
    this.messageStatus,
    this.showSenderInfo = false,
    this.senderName,
    this.isHD = false,
    this.onForward,
    this.onSave,
    this.onDelete,
    this.onShare,
    this.onLongPress,
    this.readBy,
    this.deliveredTo,
    this.messageId,
    this.blurhash,
  });

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
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.textTertiaryColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),

                if (onForward != null)
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
                      onForward?.call();
                    },
                  ),

                if (onSave != null)
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
                      onSave?.call();
                    },
                  ),

                if (onDelete != null)
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
                      onDelete?.call();
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
      onTap: onTap,
      onLongPress:
          onLongPress ??
          ((onForward != null || onSave != null || onDelete != null)
              ? () => _showMediaContextMenu(context)
              : null),
      child: Container(
        padding: const EdgeInsets.all(4),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft:
                isMe ? const Radius.circular(16) : const Radius.circular(4),
            bottomRight:
                isMe ? const Radius.circular(4) : const Radius.circular(16),
          ),
          // Match text bubble styling
          gradient:
              isMe
                  ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      context.adaptiveSecondaryColor,
                      context.adaptiveSecondaryColor.withValues(alpha: 0.85),
                    ],
                  )
                  : null,
          color: isMe ? null : context.surfaceColor,
          border:
              !isMe
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
            if (showSenderInfo && senderName != null)
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 4, bottom: 4),
                child: Text(
                  senderName!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.adaptivePrimaryColor,
                  ),
                ),
              ),

            // Video preview
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Thumbnail ou placeholder
                    _buildThumbnail(context),

                    // Overlay gradient
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.4),
                          ],
                        ),
                      ),
                    ),

                    // Glassmorphism play button
                    Center(child: _buildPlayButton(context)),

                    // HD Badge
                    if (isHD)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: _buildHDBadge(context),
                      ),

                    // Duration badge
                    if (duration != null)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: _buildDurationBadge(context),
                      ),

                    // Time and status overlay (WhatsApp style)
                    if (timestamp != null)
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: _buildTimeStatusOverlay(context),
                      ),
                  ],
                ),
              ),
            ),

            // Caption inside bubble
            if (caption != null && caption!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(
                  left: 8,
                  right: 8,
                  top: 8,
                  bottom: 4,
                ),
                child: Text(
                  caption!,
                  style: TextStyle(
                    color: context.textPrimaryColor,
                    fontSize: 14,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayButton(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHDBadge(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'HD',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDurationBadge(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_rounded, color: Colors.white, size: 12),
              const SizedBox(width: 4),
              Text(
                _formatDuration(duration!),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeStatusOverlay(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                DateFormat.Hm().format(timestamp!),
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (isMe && messageStatus != null) ...[
                const SizedBox(width: 4),
                _buildStatusIcon(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    switch (messageStatus!) {
      case MessageStatus.sending:
        return const SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
          ),
        );

      case MessageStatus.failed:
        return const Icon(
          Icons.warning_amber_rounded,
          size: 14,
          color: Colors.red,
        );

      case MessageStatus.sent:
        return const Icon(Icons.done_all, size: 14, color: Colors.white);
    }
  }

  Widget _buildThumbnail(BuildContext context) {
    if (thumbnailUrl != null) {
      return CachedNetworkImage(
        imageUrl: thumbnailUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildPlaceholder(context),
        errorWidget: (context, url, error) => _buildPlaceholder(context),
      );
    }

    return _buildPlaceholder(context);
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      color: context.isDarkMode ? Colors.grey[800] : Colors.grey[300],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.videocam_rounded,
            size: 48,
            color: context.isDarkMode ? Colors.grey[600] : Colors.grey[500],
          ),
          const SizedBox(height: 8),
          Text(
            'Vidéo',
            style: TextStyle(
              color: context.isDarkMode ? Colors.grey[600] : Colors.grey[500],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}
