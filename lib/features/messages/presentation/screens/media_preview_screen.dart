import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../../../core/services/image_compressor_service.dart';
import '../../../../core/services/preferences_service.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

enum MediaType { image, video, document }

enum _SubEditor { paint, crop, blur }

class MediaPreviewResult {
  final File file;
  final bool isImage;
  final String? caption;

  MediaPreviewResult({required this.file, required this.isImage, this.caption});
}

/// Écran de preview pour les médias avant envoi (style Signal) : outils
/// d'édition (dessiner, rogner, flouter), enregistrement galerie, légende.
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
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  final TextEditingController _captionController = TextEditingController();
  final ImageCompressorService _compressor = ImageCompressorService();
  bool _isCompressing = false;
  String? _fileSize;
  // Bascule « qualité réduite » (§27d) — activée par défaut en mode données
  // réduites. Envoie l'image en résolution/qualité moindre.
  bool _reduceQuality = false;

  // Fichier édité (annotation/rognage/flou) qui remplace l'original si présent.
  File? _editedFile;
  File get _currentFile => _editedFile ?? widget.file;

  @override
  void initState() {
    super.initState();
    _reduceQuality = PreferencesService.instance.dataSaverMode;
    _loadFileInfo();
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _loadFileInfo() async {
    final size = await _compressor.getFileSize(_currentFile);
    if (mounted) {
      setState(() {
        _fileSize = _compressor.formatFileSize(size);
      });
    }
  }

  /// Ouvre le sous-éditeur demandé (dessin, rognage/pivot, flou) sur l'image.
  Future<void> _editWith(_SubEditor which) async {
    if (!mounted) return;
    final theme = Theme.of(context);
    final bytes = await _currentFile.readAsBytes();
    if (!mounted) return;
    final callbacks = ProImageEditorCallbacks(
      onImageEditingComplete: (edited) async {
        final dir = await getTemporaryDirectory();
        final path =
            '${dir.path}/edit_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final f = await File(path).writeAsBytes(edited);
        if (mounted) setState(() => _editedFile = f);
      },
      onCloseEditor: (_) => Navigator.of(context).pop(),
    );
    late final Widget editor;
    switch (which) {
      case _SubEditor.paint:
        editor = PaintEditor.memory(
          bytes,
          initConfigs:
              PaintEditorInitConfigs(theme: theme, callbacks: callbacks),
        );
      case _SubEditor.crop:
        editor = CropRotateEditor.memory(
          bytes,
          initConfigs:
              CropRotateEditorInitConfigs(theme: theme, callbacks: callbacks),
        );
      case _SubEditor.blur:
        editor = BlurEditor.memory(
          bytes,
          initConfigs:
              BlurEditorInitConfigs(theme: theme, callbacks: callbacks),
        );
    }
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => editor));
    _loadFileInfo();
  }

  /// Enregistre le média (éventuellement édité) dans la galerie.
  Future<void> _saveToGallery() async {
    try {
      final ps = await PhotoManager.requestPermissionExtend();
      if (!ps.hasAccess) {
        _snack('Autorisation galerie refusée');
        return;
      }
      final name = 'diaspo_${DateTime.now().millisecondsSinceEpoch}';
      if (widget.type == MediaType.video) {
        await PhotoManager.editor.saveVideo(_currentFile, title: name);
      } else {
        await PhotoManager.editor
            .saveImageWithPath(_currentFile.path, title: name);
      }
      _snack('Enregistré dans la galerie');
    } catch (_) {
      _snack('Échec de l\'enregistrement');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _sendMedia() async {
    File fileToSend = _currentFile;

    // Compresser les images avant envoi
    if (widget.type == MediaType.image) {
      setState(() => _isCompressing = true);
      try {
        if (_reduceQuality) {
          // Qualité réduite (§27d) : résolution + qualité moindres.
          fileToSend = await _compressor.compressImage(
            _currentFile,
            maxWidth: 1280,
            maxHeight: 1280,
            quality: 55,
          );
        } else {
          final needsCompression = await _compressor.needsCompression(
            _currentFile,
            maxSizeInMB: 5,
          );
          if (needsCompression) {
            fileToSend = await _compressor.compressImage(_currentFile);
          }
        }
      } catch (e) {
        // Continue avec le fichier original en cas d'erreur
      }
      if (mounted) {
        setState(() => _isCompressing = false);
      }
    }

    if (!mounted) return;
    HapticFeedback.mediumImpact();
    Navigator.pop(
      context,
      MediaPreviewResult(
        file: fileToSend,
        isImage: widget.type == MediaType.image,
        caption: _captionController.text.trim().isNotEmpty
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
          icon: const AppIcon(AppIcon.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.type == MediaType.image
              ? 'Aperçu de l\'image'
              : widget.type == MediaType.video
                  ? l10n.videoPreview
                  : l10n.documentPreview,
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
          Expanded(child: Center(child: _buildMediaPreview())),
          _buildEditToolbar(),
          if (widget.type == MediaType.image) _buildQualityToggle(),
          _buildCaptionBar(),
        ],
      ),
    );
  }

  /// Bascule « Qualité réduite » (§27d) — envoi plus léger en données réduites.
  Widget _buildQualityToggle() {
    return Container(
      color: Colors.black87,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.data_saver_on, color: Colors.white70, size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Qualité réduite',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                Text(
                  'Envoi plus léger, idéal en données réduites',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          Switch(
            value: _reduceQuality,
            onChanged: (v) => setState(() => _reduceQuality = v),
            activeThumbColor: context.adaptivePrimaryColor,
          ),
        ],
      ),
    );
  }

  /// Barre d'outils façon Signal : dessiner · rogner · flou · enregistrer.
  Widget _buildEditToolbar() {
    if (widget.type == MediaType.document) return const SizedBox.shrink();
    if (widget.type == MediaType.video) {
      return Container(
        color: Colors.black87,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            _toolButton(Icons.download_outlined, l10n.save, _saveToGallery),
          ],
        ),
      );
    }
    return Container(
      color: Colors.black87,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _toolButton(
              Icons.draw_outlined, 'Dessiner', () => _editWith(_SubEditor.paint)),
          _toolButton(
              Icons.crop_rotate, 'Rogner', () => _editWith(_SubEditor.crop)),
          _toolButton(Icons.blur_on, 'Flou', () => _editWith(_SubEditor.blur)),
          _toolButton(Icons.download_outlined, l10n.save, _saveToGallery),
        ],
      ),
    );
  }

  Widget _toolButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildCaptionBar() {
    return Container(
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
            child: TextField(
              controller: _captionController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              minLines: 1,
              decoration: InputDecoration(
                hintText: l10n.addCaption,
                hintStyle: TextStyle(color: Colors.white54),
                // Pas d'encadré du thème : le texte coule sur la barre.
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // CTA nommé (§16/27d : le bouton nomme son action).
          FloatingActionButton.extended(
            onPressed: _isCompressing ? null : _sendMedia,
            backgroundColor: context.adaptivePrimaryColor,
            foregroundColor: Colors.white,
            icon: _isCompressing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const AppIcon(AppIcon.send, color: Colors.white),
            label: Text(
              _sendLabel(),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  String _sendLabel() {
    if (widget.type == MediaType.image) return 'Envoyer la photo';
    if (widget.type == MediaType.video) return 'Envoyer la vidéo';
    return 'Envoyer le document';
  }

  Widget _buildMediaPreview() {
    switch (widget.type) {
      case MediaType.image:
        return InteractiveViewer(
          child: Image.file(
            _currentFile,
            key: ValueKey(_currentFile.path),
            fit: BoxFit.contain,
          ),
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                widget.file.path.split('/').last,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
    }
  }
}
