import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../../../core/theme/adaptive_colors.dart';
import '../../domain/entities/message_entity.dart';
import '../providers/media_upload_provider.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

/// Skeleton widget displayed while media is uploading
/// Shows a preview with progress overlay and cancel button
class UploadingMediaSkeleton extends ConsumerWidget {
  const UploadingMediaSkeleton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uploadState = ref.watch(mediaUploadProvider);

    if (!uploadState.isUploading) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(left: 64, right: 16, top: 4, bottom: 4),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 280),
          decoration: BoxDecoration(
            color: context.adaptivePrimaryColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(4),
            ),
            boxShadow:
                context.isDarkMode
                    ? null
                    : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(4),
            ),
            child: switch (uploadState.type) {
              MessageType.image => _buildImageUpload(context, ref, uploadState),
              MessageType.video => _buildVideoUpload(context, ref, uploadState),
              _ => _buildDocumentUpload(context, ref, uploadState),
            },
          ),
        ),
      ),
    );
  }

  Widget _buildImageUpload(
    BuildContext context,
    WidgetRef ref,
    MediaUploadState uploadState,
  ) {
    return Stack(
      children: [
        // Image preview with shimmer effect
        if (uploadState.file != null)
          SizedBox(
            width: 250,
            height: 200,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Blurred/dimmed image preview
                ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    Colors.black.withValues(alpha: 0.3),
                    BlendMode.darken,
                  ),
                  child: Image.file(
                    uploadState.file!,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (_, __, ___) => _buildShimmerPlaceholder(context),
                  ),
                ),
                // Shimmer overlay
                Shimmer.fromColors(
                  baseColor: Colors.transparent,
                  highlightColor: Colors.white.withValues(alpha: 0.15),
                  child: Container(color: Colors.white),
                ),
              ],
            ),
          )
        else
          _buildShimmerPlaceholder(context),

        // Progress overlay
        Positioned.fill(
          child: Container(
            color: Colors.black.withValues(alpha: 0.4),
            child: Center(
              child: _buildProgressIndicator(context, ref, uploadState),
            ),
          ),
        ),

        // Caption if present
        if (uploadState.caption != null && uploadState.caption!.isNotEmpty)
          _buildCaptionOverlay(uploadState.caption!),
      ],
    );
  }

  /// Aperçu vidéo pendant l'upload : même traitement que l'image (image
  /// réelle assombrie + effet shimmer) au lieu du squelette générique
  /// « document », plus un badge vidéo pour rester cohérent avec `VideoBubble`.
  Widget _buildVideoUpload(
    BuildContext context,
    WidgetRef ref,
    MediaUploadState uploadState,
  ) {
    return Stack(
      children: [
        if (uploadState.file != null)
          SizedBox(
            width: 250,
            height: 200,
            child: _VideoThumbnailPreview(
              key: ValueKey(uploadState.file!.path),
              file: uploadState.file!,
              placeholderBuilder: () => _buildShimmerPlaceholder(context),
            ),
          )
        else
          _buildShimmerPlaceholder(context),

        Positioned(top: 8, left: 8, child: _buildVideoBadge()),

        // Progress overlay
        Positioned.fill(
          child: Container(
            color: Colors.black.withValues(alpha: 0.4),
            child: Center(
              child: _buildProgressIndicator(context, ref, uploadState),
            ),
          ),
        ),

        if (uploadState.caption != null && uploadState.caption!.isNotEmpty)
          _buildCaptionOverlay(uploadState.caption!),
      ],
    );
  }

  Widget _buildVideoBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Icon(Icons.videocam_rounded, color: Colors.white, size: 14),
    );
  }

  Widget _buildCaptionOverlay(String caption) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: 0.6),
            ],
          ),
        ),
        child: Text(
          caption,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildDocumentUpload(
    BuildContext context,
    WidgetRef ref,
    MediaUploadState uploadState,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // File icon with progress
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.insert_drive_file,
                  color: Colors.white70,
                  size: 28,
                ),
              ),
              SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  value: uploadState.progress,
                  strokeWidth: 3,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),

          // File info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  uploadState.fileName ?? l10n.adminSending,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${(uploadState.progress * 100).toInt()}%',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Cancel button
          IconButton(
            onPressed: () => ref.read(mediaUploadProvider.notifier).cancel(),
            icon: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(
    BuildContext context,
    WidgetRef ref,
    MediaUploadState uploadState,
  ) {
    return GestureDetector(
      onTap: () => ref.read(mediaUploadProvider.notifier).cancel(),
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Progress ring
            SizedBox(
              width: 52,
              height: 52,
              child: CircularProgressIndicator(
                value: uploadState.progress,
                strokeWidth: 3,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            // Cancel icon
            const Icon(Icons.close, color: Colors.white, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerPlaceholder(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: context.surfaceVariantColor,
      highlightColor: context.surfaceColor,
      child: Container(
        width: 250,
        height: 200,
        color: context.surfaceVariantColor,
      ),
    );
  }
}

/// Extrait une vignette de la première image du fichier vidéo local (pas
/// encore de blurhash serveur à ce stade) et l'affiche assombrie, avec le
/// même effet shimmer que l'aperçu image. Widget à état séparé pour ne
/// générer la vignette qu'une fois, indépendamment des rebuilds fréquents du
/// parent pendant que la progression avance.
class _VideoThumbnailPreview extends StatefulWidget {
  final File file;
  final Widget Function() placeholderBuilder;

  const _VideoThumbnailPreview({
    super.key,
    required this.file,
    required this.placeholderBuilder,
  });

  @override
  State<_VideoThumbnailPreview> createState() =>
      _VideoThumbnailPreviewState();
}

class _VideoThumbnailPreviewState extends State<_VideoThumbnailPreview> {
  Uint8List? _thumbnail;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  @override
  void didUpdateWidget(covariant _VideoThumbnailPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path != widget.file.path) {
      _thumbnail = null;
      _generate();
    }
  }

  Future<void> _generate() async {
    try {
      final bytes = await VideoThumbnail.thumbnailData(
        video: widget.file.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 400,
        quality: 60,
      );
      if (mounted) setState(() => _thumbnail = bytes);
    } catch (_) {
      // Le shimmer reste affiché si l'extraction échoue.
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _thumbnail;
    if (bytes == null) return widget.placeholderBuilder();

    return Stack(
      fit: StackFit.expand,
      children: [
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withValues(alpha: 0.3),
            BlendMode.darken,
          ),
          child: Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true),
        ),
        Shimmer.fromColors(
          baseColor: Colors.transparent,
          highlightColor: Colors.white.withValues(alpha: 0.15),
          child: Container(color: Colors.white),
        ),
      ],
    );
  }
}
