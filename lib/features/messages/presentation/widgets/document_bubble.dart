import 'package:flutter/material.dart';

import 'package:diaspo_niger/shared/widgets/app_icon.dart';
import '../../../../core/theme/adaptive_colors.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

/// Bubble pour l'affichage de documents/fichiers dans les messages
/// Avec icônes colorées par type de fichier et animation de succès
class DocumentBubble extends StatefulWidget {
  final String fileUrl;
  final String fileName;
  final int? fileSize;
  final bool isMe;
  final VoidCallback? onTap;
  final bool isDownloading;
  final double downloadProgress;

  // L'heure et l'accusé de réception vivent dans la ligne de méta posée sous
  // la bulle par MessageBubble (fiches 4a/6b).
  final VoidCallback? onShare;

  const DocumentBubble({
    super.key,
    required this.fileUrl,
    required this.fileName,
    this.fileSize,
    required this.isMe,
    this.onTap,
    this.isDownloading = false,
    this.downloadProgress = 0.0,
    this.onShare,
  });

  @override
  State<DocumentBubble> createState() => _DocumentBubbleState();
}

class _DocumentBubbleState extends State<DocumentBubble>
    with SingleTickerProviderStateMixin {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  late AnimationController _successAnimationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  bool _showSuccess = false;

  @override
  void initState() {
    super.initState();
    _successAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.2), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 60),
    ]).animate(CurvedAnimation(
      parent: _successAnimationController,
      curve: Curves.easeOutBack,
    ));

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _successAnimationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _successAnimationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _showSuccess = false;
            });
          }
        });
      }
    });
  }

  @override
  void didUpdateWidget(DocumentBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Show success animation when download completes
    if (oldWidget.isDownloading && !widget.isDownloading && oldWidget.downloadProgress > 0.9) {
      _triggerSuccessAnimation();
    }
  }

  void _triggerSuccessAnimation() {
    setState(() {
      _showSuccess = true;
    });
    _successAnimationController.forward(from: 0);
  }

  @override
  void dispose() {
    _successAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Handle empty file URL
    if (widget.fileUrl.isEmpty) {
      return _buildErrorState(context);
    }

    final fileTypeInfo = _getFileTypeInfo();

    return GestureDetector(
      onTap: widget.isDownloading ? null : widget.onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:
              widget.isMe
                  ? Colors.white.withValues(alpha: 0.2)
                  : context.isDarkMode
                      ? Colors.grey[800]
                      : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                widget.isMe
                    ? Colors.white.withValues(alpha: 0.3)
                    : context.outlineColor.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Colored file icon
                Stack(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color:
                            widget.isMe
                                ? Colors.white.withValues(alpha: 0.25)
                                : fileTypeInfo.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        fileTypeInfo.icon,
                        color:
                            widget.isMe ? Colors.white : fileTypeInfo.color,
                        size: 24,
                      ),
                    ),
                    // Success checkmark overlay
                    if (_showSuccess)
                      Positioned.fill(
                        child: AnimatedBuilder(
                          animation: _successAnimationController,
                          builder: (context, child) {
                            return Opacity(
                              opacity: _opacityAnimation.value,
                              child: Transform.scale(
                                scale: _scaleAnimation.value,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const AppIcon(
                                    AppIcon.check,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),

                // File info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.fileName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color:
                              widget.isMe
                                  ? Colors.white
                                  : context.textPrimaryColor,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          // File type badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  widget.isMe
                                      ? Colors.white.withValues(alpha: 0.2)
                                      : fileTypeInfo.color.withValues(
                                        alpha: 0.1,
                                      ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              fileTypeInfo.label,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color:
                                    widget.isMe
                                        ? Colors.white
                                        : fileTypeInfo.color,
                              ),
                            ),
                          ),
                          if (widget.fileSize != null) ...[
                            Text(
                              ' • ',
                              style: TextStyle(
                                color:
                                    widget.isMe
                                        ? Colors.white70
                                        : context.textSecondaryColor,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              _formatFileSize(widget.fileSize!),
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    widget.isMe
                                        ? Colors.white.withValues(alpha: 0.8)
                                        : context.textSecondaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                          if (widget.isDownloading) ...[
                            Text(
                              ' • ',
                              style: TextStyle(
                                color:
                                    widget.isMe
                                        ? Colors.white70
                                        : context.textSecondaryColor,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '${(widget.downloadProgress * 100).toInt()}%',
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    widget.isMe
                                        ? Colors.white.withValues(alpha: 0.8)
                                        : context.textSecondaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),

                      // Progress bar during download
                      if (widget.isDownloading) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: widget.downloadProgress,
                            minHeight: 4,
                            backgroundColor:
                                widget.isMe
                                    ? Colors.white24
                                    : fileTypeInfo.color.withValues(alpha: 0.2),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              widget.isMe ? Colors.white : fileTypeInfo.color,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Download icon or success indicator
                if (!widget.isDownloading) ...[
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          widget.isMe
                              ? Colors.white.withValues(alpha: 0.2)
                              : Colors.transparent,
                    ),
                    child: _showSuccess
                        ? AppIcon(
                            AppIcon.checkCircle,
                            color: Colors.green,
                            size: 20,
                          )
                        : Icon(
                            Icons.download_rounded,
                            color: widget.isMe
                                ? Colors.white
                                : context.textSecondaryColor,
                            size: 20,
                          ),
                  ),
                ],
              ],
            ),

          ],
        ),
      ),
    );
  }

  _FileTypeInfo _getFileTypeInfo() {
    final extension = widget.fileName.split('.').last.toLowerCase();

    switch (extension) {
      case 'pdf':
        return _FileTypeInfo(
          icon: Icons.picture_as_pdf_rounded,
          color: const Color(0xFFE53935), // Red
          label: l10n.pdf,
        );
      case 'doc':
      case 'docx':
        return _FileTypeInfo(
          icon: Icons.description_rounded,
          color: const Color(0xFF2196F3), // Blue
          label: l10n.doc,
        );
      case 'xls':
      case 'xlsx':
        return _FileTypeInfo(
          icon: Icons.table_chart_rounded,
          color: const Color(0xFF4CAF50), // Green
          label: l10n.xlsLabel,
        );
      case 'ppt':
      case 'pptx':
        return _FileTypeInfo(
          icon: Icons.slideshow_rounded,
          color: const Color(0xFFFF9800), // Orange
          label: l10n.pptLabel,
        );
      case 'zip':
      case 'rar':
      case '7z':
        return _FileTypeInfo(
          icon: Icons.folder_zip_rounded,
          color: const Color(0xFF9C27B0), // Purple
          label: l10n.zipLabel,
        );
      case 'txt':
        return _FileTypeInfo(
          icon: Icons.text_snippet_rounded,
          color: const Color(0xFF607D8B), // Blue Grey
          label: l10n.txtLabel,
        );
      case 'csv':
        return _FileTypeInfo(
          icon: Icons.table_rows_rounded,
          color: const Color(0xFF009688), // Teal
          label: l10n.csvLabel,
        );
      case 'json':
        return _FileTypeInfo(
          icon: Icons.data_object_rounded,
          color: const Color(0xFFFF5722), // Deep Orange
          label: l10n.jsonLabel,
        );
      default:
        return _FileTypeInfo(
          icon: Icons.insert_drive_file_rounded,
          color: const Color(0xFF78909C), // Blue Grey 400
          label: extension.toUpperCase(),
        );
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

  Widget _buildErrorState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            widget.isMe
                ? Colors.white.withValues(alpha: 0.2)
                : context.isDarkMode
                    ? Colors.grey[800]
                    : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              widget.isMe
                  ? Colors.white.withValues(alpha: 0.3)
                  : context.outlineColor.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const AppIcon(
              AppIcon.error,
              color: Colors.red,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.fileNotAvailable,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color:
                        widget.isMe ? Colors.white : context.textPrimaryColor,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Le fichier n\'a pas pu être chargé',
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        widget.isMe
                            ? Colors.white.withValues(alpha: 0.7)
                            : context.textSecondaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FileTypeInfo {
  final IconData icon;
  final Color color;
  final String label;

  const _FileTypeInfo({
    required this.icon,
    required this.color,
    required this.label,
  });
}
