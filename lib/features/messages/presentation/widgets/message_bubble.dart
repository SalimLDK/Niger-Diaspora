import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/message_entity.dart';
import '../../../../core/theme/adaptive_colors.dart';
import 'audio_message_bubble.dart';
import 'delete_message_modal.dart';
import 'full_screen_image_viewer.dart';

class MessageBubble extends StatelessWidget {
  final MessageEntity message;
  final bool isMe;
  final bool showSenderInfo;
  final VoidCallback? onRetry;
  final Function(String userId)? onSenderTap;
  final String? conversationId;
  final String? currentUserId;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.showSenderInfo = false,
    this.onRetry,
    this.onSenderTap,
    this.conversationId,
    this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    // Check if message is deleted for the current user
    final isDeleted =
        currentUserId != null && message.isDeletedFor(currentUserId!);

    // Don't show messages that are deleted for the current user
    if (isDeleted && !message.deletedForEveryone) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.only(
        left: isMe ? 64 : 16,
        right: isMe ? 16 : 64,
        top: 4,
        bottom: 4,
      ),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (showSenderInfo && !isMe) ...[
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 4),
              child: InkWell(
                onTap: () => onSenderTap?.call(message.senderId),
                child: Text(
                  message.senderName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.textSecondaryColor,
                    decoration:
                        onSenderTap != null ? TextDecoration.underline : null,
                  ),
                ),
              ),
            ),
          ],
          GestureDetector(
            onLongPress:
                _canShowDeleteOption() ? () => _showDeleteModal(context) : null,
            child: Container(
              decoration: BoxDecoration(
                color:
                    isMe ? context.adaptivePrimaryColor : context.surfaceColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isMe ? 20 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 20),
                ),
                boxShadow:
                    context.isDarkMode
                        ? null
                        : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
              ),
              child: GestureDetector(
                onTap:
                    message.status == MessageStatus.failed && onRetry != null
                        ? onRetry
                        : null,
                child: ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(isMe ? 20 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 20),
                  ),
                  child:
                      message.deletedForEveryone
                          ? _buildDeletedContent(context)
                          : _buildContent(context),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 12, right: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(message.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: context.textTertiaryColor,
                  ),
                ),
                if (isMe && !message.deletedForEveryone) ...[
                  const SizedBox(width: 4),
                  _buildStatusIcon(context),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _canShowDeleteOption() {
    return conversationId != null &&
        currentUserId != null &&
        !message.deletedForEveryone &&
        message.status != MessageStatus.sending;
  }

  void _showDeleteModal(BuildContext context) {
    if (conversationId == null || currentUserId == null) return;

    DeleteMessageModal.show(
      context,
      message: message,
      conversationId: conversationId!,
      currentUserId: currentUserId!,
    );
  }

  Widget _buildDeletedContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.block,
            size: 16,
            color:
                isMe
                    ? AppColors.white.withValues(alpha: 0.7)
                    : context.textTertiaryColor,
          ),
          const SizedBox(width: 8),
          Text(
            'Message supprimé',
            style: TextStyle(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color:
                  isMe
                      ? AppColors.white.withValues(alpha: 0.7)
                      : context.textTertiaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (message.type) {
      case MessageType.image:
        return _buildImageContent(context);
      case MessageType.file:
        return _buildFileContent(context);
      case MessageType.audio:
        return AudioMessageBubble(message: message, isMe: isMe);
      case MessageType.text:
        return _buildTextContent(context);
    }
  }

  Widget _buildTextContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(
        message.content,
        style: TextStyle(
          fontSize: 15,
          color: isMe ? AppColors.white : context.textPrimaryColor,
        ),
      ),
    );
  }

  Widget _buildImageContent(BuildContext context) {
    final heroTag = 'message_image_${message.id}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (message.fileUrl != null)
          GestureDetector(
            onTap:
                () => FullScreenImageViewer.show(
                  context,
                  imageUrl: message.fileUrl!,
                  heroTag: heroTag,
                  senderName: message.senderName,
                  sentAt: message.createdAt,
                ),
            child: Hero(
              tag: heroTag,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 250,
                  maxHeight: 300,
                ),
                child: CachedNetworkImage(
                  imageUrl: message.fileUrl!,
                  fit: BoxFit.cover,
                  memCacheWidth: 600,
                  placeholder:
                      (context, url) => _buildImagePlaceholder(context),
                  errorWidget:
                      (context, url, error) => _buildImageError(context),
                ),
              ),
            ),
          ),
        if (message.content.isNotEmpty && message.content != message.fileName)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              message.content,
              style: TextStyle(
                fontSize: 14,
                color: isMe ? AppColors.white : context.textPrimaryColor,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildImagePlaceholder(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: context.surfaceVariantColor,
      highlightColor: context.surfaceColor,
      child: Container(
        width: 200,
        height: 150,
        color: context.surfaceVariantColor,
      ),
    );
  }

  Widget _buildImageError(BuildContext context) {
    return Container(
      width: 200,
      height: 150,
      color: context.surfaceVariantColor,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image, color: context.textTertiaryColor, size: 32),
          const SizedBox(height: 8),
          Text(
            'Image non disponible',
            style: TextStyle(fontSize: 12, color: context.textTertiaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildFileContent(BuildContext context) {
    return InkWell(
      onTap: () => _openFile(message.fileUrl),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color:
                    isMe
                        ? AppColors.white.withValues(alpha: 0.2)
                        : context.adaptivePrimaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getFileIcon(message.mimeType),
                color: isMe ? AppColors.white : context.adaptivePrimaryColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.fileName ?? 'Fichier',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isMe ? AppColors.white : context.textPrimaryColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message.fileSizeFormatted,
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          isMe
                              ? AppColors.white.withValues(alpha: 0.7)
                              : context.textTertiaryColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.download,
              color: isMe ? AppColors.white : context.adaptivePrimaryColor,
              size: 20,
            ),
          ],
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
    if (mimeType.contains('audio')) return Icons.audiotrack;
    return Icons.insert_drive_file;
  }

  Widget _buildStatusIcon(BuildContext context) {
    switch (message.status) {
      case MessageStatus.sending:
        return Icon(
          Icons.access_time,
          size: 14,
          color: context.textTertiaryColor,
        );

      case MessageStatus.failed:
        return const Icon(Icons.close, size: 14, color: Colors.red);

      case MessageStatus.sent:
        return Icon(
          message.readBy.length > 1 ? Icons.done_all : Icons.done,
          size: 14,
          color:
              message.readBy.length > 1
                  ? Colors
                      .blue // Blue for read (VV)
                  : context.textTertiaryColor,
        );
    }
  }

  String _formatTime(DateTime dateTime) {
    return DateFormat.Hm().format(dateTime);
  }

  Future<void> _openFile(String? url) async {
    if (url == null) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
