import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../../../core/services/image_compressor_service.dart';

enum MediaType { image, video, document }

class MediaPreviewResult {
  final File file;
  final bool isImage;
  final String? caption;

  MediaPreviewResult({required this.file, required this.isImage, this.caption});
}

/// Écran de preview pour les médias avant envoi (style WhatsApp)
class MediaPreviewScreen extends StatefulWidget {
  final File file;
  final MediaType type;
  final String conversationId;

  const MediaPreviewScreen({
    super.key,
    required this.file,
    required this.type,
    required this.conversationId,
  });

  @override
  State<MediaPreviewScreen> createState() => _MediaPreviewScreenState();
}

class _MediaPreviewScreenState extends State<MediaPreviewScreen> {
  final TextEditingController _captionController = TextEditingController();
  final ImageCompressorService _compressor = ImageCompressorService();
  bool _isCompressing = false;
  String? _fileSize;

  @override
  void initState() {
    super.initState();
    _loadFileInfo();
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _loadFileInfo() async {
    final size = await _compressor.getFileSize(widget.file);
    if (mounted) {
      setState(() {
        _fileSize = _compressor.formatFileSize(size);
      });
    }
  }

  Future<void> _sendMedia() async {
    File fileToSend = widget.file;

    // Compresser les images avant envoi
    if (widget.type == MediaType.image) {
      setState(() => _isCompressing = true);

      try {
        final needsCompression = await _compressor.needsCompression(
          widget.file,
          maxSizeInMB: 5,
        );

        if (needsCompression) {
          fileToSend = await _compressor.compressImage(widget.file);
        }
      } catch (e) {
        debugPrint('Erreur de compression: $e');
        // Continue avec le fichier original en cas d'erreur
      }

      if (mounted) {
        setState(() => _isCompressing = false);
      }
    }

    if (!mounted) return;

    // Retourner le résultat
    Navigator.pop(
      context,
      MediaPreviewResult(
        file: fileToSend,
        isImage: widget.type == MediaType.image,
        caption:
            _captionController.text.trim().isNotEmpty
                ? _captionController.text.trim()
                : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.type == MediaType.image
              ? 'Aperçu de l\'image'
              : widget.type == MediaType.video
              ? 'Aperçu de la vidéo'
              : 'Aperçu du document',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          if (_fileSize != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  _fileSize!,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Preview du média
          Expanded(child: Center(child: _buildMediaPreview())),

          // Zone de caption
          Container(
            color: Colors.black87,
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(context).padding.bottom + 12,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _captionController,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 3,
                      minLines: 1,
                      decoration: const InputDecoration(
                        hintText: 'Ajouter une légende...',
                        hintStyle: TextStyle(color: Colors.white54),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FloatingActionButton(
                  onPressed: _isCompressing ? null : _sendMedia,
                  backgroundColor: context.adaptivePrimaryColor,
                  child:
                      _isCompressing
                          ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                          : const Icon(Icons.send, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaPreview() {
    switch (widget.type) {
      case MediaType.image:
        return InteractiveViewer(
          child: Image.file(widget.file, fit: BoxFit.contain),
        );

      case MediaType.video:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.play_circle_outline,
                size: 80,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.file.path.split('/').last,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            const Text(
              'Aperçu vidéo',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        );

      case MediaType.document:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.insert_drive_file,
                size: 80,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.file.path.split('/').last,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        );
    }
  }
}
