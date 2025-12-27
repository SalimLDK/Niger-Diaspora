import 'package:flutter/material.dart';
import '../../../../core/theme/adaptive_colors.dart';

/// Bubble pour l'affichage de documents/fichiers dans les messages
class DocumentBubble extends StatelessWidget {
  final String fileUrl;
  final String fileName;
  final int? fileSize;
  final bool isMe;
  final VoidCallback? onTap;
  final bool isDownloading;
  final double downloadProgress;

  const DocumentBubble({
    super.key,
    required this.fileUrl,
    required this.fileName,
    this.fileSize,
    required this.isMe,
    this.onTap,
    this.isDownloading = false,
    this.downloadProgress = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isDownloading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:
              isMe
                  ? Colors.white.withValues(alpha: 0.2)
                  : context.isDarkMode
                  ? Colors.grey[800]
                  : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isMe
                    ? Colors.white.withValues(alpha: 0.3)
                    : context.outlineColor.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icône du fichier
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color:
                    isMe
                        ? Colors.white.withValues(alpha: 0.25)
                        : context.adaptivePrimaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getFileIcon(),
                color: isMe ? Colors.white : context.adaptivePrimaryColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),

            // Info fichier
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isMe ? Colors.white : context.textPrimaryColor,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (fileSize != null)
                        Text(
                          _formatFileSize(fileSize!),
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                isMe
                                    ? Colors.white.withValues(alpha: 0.8)
                                    : context.textSecondaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      if (isDownloading) ...[
                        if (fileSize != null)
                          Text(
                            ' • ',
                            style: TextStyle(
                              color:
                                  isMe
                                      ? Colors.white70
                                      : context.textSecondaryColor,
                              fontSize: 12,
                            ),
                          ),
                        Text(
                          '${(downloadProgress * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                isMe
                                    ? Colors.white.withValues(alpha: 0.8)
                                    : context.textSecondaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),

                  // Progress bar pendant le téléchargement
                  if (isDownloading) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: downloadProgress,
                        minHeight: 4,
                        backgroundColor:
                            isMe
                                ? Colors.white24
                                : context.adaptivePrimaryColor.withValues(
                                  alpha: 0.2,
                                ),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isMe ? Colors.white : context.adaptivePrimaryColor,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Icône download
            if (!isDownloading) ...[
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      isMe
                          ? Colors.white.withValues(alpha: 0.2)
                          : Colors.transparent,
                ),
                child: Icon(
                  Icons.download_rounded,
                  color: isMe ? Colors.white : context.textSecondaryColor,
                  size: 20,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getFileIcon() {
    final extension = fileName.split('.').last.toLowerCase();

    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'doc':
      case 'docx':
        return Icons.description_rounded;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart_rounded;
      case 'zip':
      case 'rar':
        return Icons.folder_zip_rounded;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow_rounded;
      case 'txt':
        return Icons.text_snippet_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }
}
