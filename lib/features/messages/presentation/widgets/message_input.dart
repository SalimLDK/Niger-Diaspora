import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/audio_recording_service.dart';
import '../../../../core/theme/adaptive_colors.dart';
import 'audio_recorder_overlay.dart';
import '../screens/media_preview_screen.dart';

class MessageInput extends StatefulWidget {
  final Function(String) onSendText;
  final Function(File, bool isImage, {String? caption}) onSendFile;
  final Function(File audioFile, int duration, List<double> waveform)?
  onSendAudio;
  final VoidCallback? onTyping;
  final bool isLoading;

  const MessageInput({
    super.key,
    required this.onSendText,
    required this.onSendFile,
    this.onSendAudio,
    this.onTyping,
    this.isLoading = false,
  });

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final AudioRecordingService _recordingService = AudioRecordingService();

  bool _hasText = false;
  bool _isRecording = false;
  double _dragOffset = 0;
  bool _isCancelling = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _hasText) {
        setState(() => _hasText = hasText);
      }
      // Notify parent that user is typing
      if (hasText) {
        widget.onTyping?.call();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    if (_isRecording) {
      _recordingService.cancelRecording();
    }
    super.dispose();
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    widget.onSendText(text);
    _controller.clear();
    _focusNode.requestFocus();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (image != null && mounted) {
      // Navigate to preview screen
      final result = await Navigator.push<MediaPreviewResult>(
        context,
        MaterialPageRoute(
          builder:
              (_) => MediaPreviewScreen(
                file: File(image.path),
                type: MediaType.image,
                conversationId: '',
              ),
        ),
      );

      if (result != null && mounted) {
        widget.onSendFile(result.file, result.isImage, caption: result.caption);
      }
    }
  }

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
    );

    if (image != null) {
      widget.onSendFile(File(image.path), true);
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx'],
    );

    if (result != null && result.files.single.path != null) {
      widget.onSendFile(File(result.files.single.path!), false);
    }
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
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
                Text(
                  'Envoyer un fichier',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: context.textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _AttachmentOption(
                      icon: Icons.photo_library,
                      label: 'Galerie',
                      color: context.adaptivePrimaryColor,
                      onTap: () {
                        Navigator.pop(context);
                        _pickImage();
                      },
                    ),
                    _AttachmentOption(
                      icon: Icons.camera_alt,
                      label: 'Camera',
                      color: context.adaptiveSecondaryColor,
                      onTap: () {
                        Navigator.pop(context);
                        _takePhoto();
                      },
                    ),
                    _AttachmentOption(
                      icon: Icons.insert_drive_file,
                      label: 'Document',
                      color: Colors.blue,
                      onTap: () {
                        Navigator.pop(context);
                        _pickFile();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
    );
  }

  // Audio recording methods
  Future<void> _startRecording() async {
    if (widget.onSendAudio == null) return;

    final hasPermission = await _recordingService.requestPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permission du microphone requise'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final path = await _recordingService.startRecording();
    if (path != null) {
      HapticFeedback.mediumImpact();
      setState(() {
        _isRecording = true;
        _dragOffset = 0;
        _isCancelling = false;
      });
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    if (_isCancelling) {
      await _recordingService.cancelRecording();
      HapticFeedback.lightImpact();
    } else {
      final result = await _recordingService.stopRecording();
      if (result != null && widget.onSendAudio != null) {
        final (file, duration, waveform) = result;
        widget.onSendAudio!(file, duration, waveform);
        HapticFeedback.mediumImpact();
      }
    }

    setState(() {
      _isRecording = false;
      _dragOffset = 0;
      _isCancelling = false;
    });
  }

  void _onRecordingDrag(DragUpdateDetails details) {
    if (!_isRecording) return;

    setState(() {
      _dragOffset += details.delta.dx;
      _isCancelling = _dragOffset < -80;
    });

    if (_isCancelling && !_recordingService.isRecording) {
      HapticFeedback.selectionClick();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isRecording) {
      return GestureDetector(
        onHorizontalDragUpdate: _onRecordingDrag,
        onHorizontalDragEnd: (_) => _stopRecording(),
        onPanEnd: (_) => _stopRecording(),
        child: AudioRecorderOverlay(
          dragOffset: _dragOffset,
          isCancelling: _isCancelling,
          onCancel: () async {
            await _recordingService.cancelRecording();
            setState(() {
              _isRecording = false;
              _dragOffset = 0;
              _isCancelling = false;
            });
          },
          onSend: _stopRecording,
        ),
      );
    }

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        boxShadow:
            context.isDarkMode
                ? null
                : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            onPressed:
                () => _showAttachmentOptions(), // Removed isLoading check
            icon: const Icon(Icons.attach_file),
            color: context.textSecondaryColor,
          ),
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: context.surfaceVariantColor,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                enabled: !widget.isLoading, // Keep this for text sending
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Votre message...',
                  hintStyle: TextStyle(color: context.textTertiaryColor),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child:
                widget.isLoading
                    ? Container(
                      width: 48,
                      height: 48,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.adaptivePrimaryColor,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: CircularProgressIndicator(
                        color: AppColors.white,
                        strokeWidth: 2,
                      ),
                    )
                    : _hasText
                    ? IconButton(
                      onPressed: _sendMessage,
                      style: IconButton.styleFrom(
                        backgroundColor: context.adaptivePrimaryColor,
                        padding: const EdgeInsets.all(12),
                      ),
                      icon: Icon(Icons.send, color: AppColors.white),
                    )
                    : GestureDetector(
                      onLongPressStart: (_) => _startRecording(),
                      onLongPressEnd: (_) => _stopRecording(),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color:
                              widget.onSendAudio != null
                                  ? context.adaptivePrimaryColor
                                  : context.surfaceVariantColor,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Icon(
                          Icons.mic,
                          color:
                              widget.onSendAudio != null
                                  ? AppColors.white
                                  : context.textTertiaryColor,
                        ),
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AttachmentOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(fontSize: 13, color: context.textSecondaryColor),
          ),
        ],
      ),
    );
  }
}
