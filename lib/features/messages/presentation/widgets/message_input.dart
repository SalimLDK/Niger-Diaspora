import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/audio_recording_service.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/theme/adaptive_colors.dart';
import 'audio_recorder_overlay.dart';
import '../screens/media_preview_screen.dart';
import '../../domain/entities/message_entity.dart';

class MessageInput extends StatefulWidget {
  final Function(String) onSendText;
  final Function(File, bool isImage, {String? caption}) onSendFile;
  final Function(File audioFile, int duration, List<double> waveform)?
  onSendAudio;
  final VoidCallback? onTyping;
  final bool isLoading;

  // Reply support
  final MessageEntity? replyToMessage;
  final VoidCallback? onCancelReply;

  const MessageInput({
    super.key,
    required this.onSendText,
    required this.onSendFile,
    this.onSendAudio,
    this.onTyping,
    this.isLoading = false,
    this.replyToMessage,
    this.onCancelReply,
  });

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput>
    with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final AudioRecordingService _recordingService = AudioRecordingService();

  bool _hasText = false;
  bool _isRecording = false;
  double _dragOffset = 0;
  bool _isCancelling = false;

  // Character counter threshold
  static const int _charCountThreshold = 200;
  static const int _maxCharCount = 2000;

  // Morphing animation
  late AnimationController _morphController;
  late Animation<double> _morphAnimation;

  @override
  void initState() {
    super.initState();

    _morphController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );

    _morphAnimation = CurvedAnimation(
      parent: _morphController,
      curve: Curves.easeOutCubic,
    );

    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _hasText) {
        setState(() => _hasText = hasText);

        // Animate morphing
        if (hasText) {
          _morphController.forward();
        } else {
          _morphController.reverse();
        }
      }
      // Notify parent that user is typing
      if (hasText) {
        widget.onTyping?.call();
      }
      // Trigger rebuild for character counter
      if (_controller.text.length >= _charCountThreshold ||
          (_controller.text.length < _charCountThreshold &&
              _controller.text.isNotEmpty)) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _morphController.dispose();
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
    // Request camera permission first
    final permissionResult =
        await PermissionService().requestCameraPermission();

    if (permissionResult != PermissionResult.granted) {
      if (mounted) {
        _showCameraPermissionError(permissionResult);
      }
      return;
    }

    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
      );

      if (image != null) {
        widget.onSendFile(File(image.path), true);
      }
    } on PlatformException catch (e) {
      if (e.code == 'camera_access_denied' && mounted) {
        _showCameraPermissionError(PermissionResult.permanentlyDenied);
      }
    }
  }

  void _showCameraPermissionError(PermissionResult result) {
    final isPermanent = result == PermissionResult.permanentlyDenied;
    final message = PermissionService.getCameraPermissionDeniedMessage(result);

    if (isPermanent) {
      PermissionService.showPermissionDeniedDialog(
        context: context,
        title: 'Permission caméra requise',
        message: message,
        showSettingsButton: true,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
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

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final video = await picker.pickVideo(source: ImageSource.gallery);

    if (video != null && mounted) {
      // Navigate to preview screen for video
      final result = await Navigator.push<MediaPreviewResult>(
        context,
        MaterialPageRoute(
          builder:
              (_) => MediaPreviewScreen(
                file: File(video.path),
                type: MediaType.video,
                conversationId: '',
              ),
        ),
      );

      if (result != null && mounted) {
        widget.onSendFile(result.file, false, caption: result.caption);
      }
    }
  }

  void _showAttachmentOptions() {
    // Unfocus to hide keyboard before showing attachment options
    _focusNode.unfocus();
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
                // First row
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
                      label: 'Caméra',
                      color: context.adaptiveSecondaryColor,
                      onTap: () {
                        Navigator.pop(context);
                        _takePhoto();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Second row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _AttachmentOption(
                      icon: Icons.videocam,
                      label: 'Vidéo',
                      color: Colors.purple,
                      onTap: () {
                        Navigator.pop(context);
                        _pickVideo();
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Reply preview
        if (widget.replyToMessage != null) _buildReplyPreview(context),

        // Main input area
        Container(
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: () => _showAttachmentOptions(),
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
                        enabled: !widget.isLoading,
                        maxLines: null,
                        maxLength: _maxCharCount,
                        buildCounter:
                            (
                              context, {
                              required currentLength,
                              required isFocused,
                              maxLength,
                            }) => null,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: 'Votre message...',
                          hintStyle: TextStyle(
                            color: context.textTertiaryColor,
                          ),
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
                  _buildActionButton(context),
                ],
              ),

              // Character counter
              if (_controller.text.length >= _charCountThreshold)
                _buildCharacterCounter(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReplyPreview(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        border: Border(
          bottom: BorderSide(
            color: context.outlineColor.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: context.adaptivePrimaryColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.replyToMessage!.senderName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.adaptivePrimaryColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.replyToMessage!.type == MessageType.text
                      ? widget.replyToMessage!.content
                      : _getMediaTypeLabel(widget.replyToMessage!.type),
                  style: TextStyle(
                    fontSize: 13,
                    color: context.textSecondaryColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: widget.onCancelReply,
            icon: Icon(
              Icons.close,
              size: 20,
              color: context.textSecondaryColor,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  String _getMediaTypeLabel(MessageType type) {
    switch (type) {
      case MessageType.image:
        return '📷 Photo';
      case MessageType.video:
        return '🎥 Vidéo';
      case MessageType.audio:
        return '🎵 Audio';
      case MessageType.file:
        return '📄 Document';
      case MessageType.text:
      case MessageType.system:
        return '';
    }
  }

  Widget _buildCharacterCounter(BuildContext context) {
    final currentLength = _controller.text.length;
    final remaining = _maxCharCount - currentLength;
    final isNearLimit = remaining < 100;
    final isAtLimit = remaining <= 0;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color:
                  isAtLimit
                      ? Colors.red.withValues(alpha: 0.1)
                      : isNearLimit
                      ? Colors.orange.withValues(alpha: 0.1)
                      : context.surfaceVariantColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$currentLength / $_maxCharCount',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color:
                    isAtLimit
                        ? Colors.red
                        : isNearLimit
                        ? Colors.orange
                        : context.textTertiaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context) {
    if (widget.isLoading) {
      return Container(
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
      );
    }

    return AnimatedBuilder(
      animation: _morphAnimation,
      builder: (context, child) {
        return GestureDetector(
          onTap: _hasText ? _sendMessage : null,
          onLongPressStart:
              !_hasText && widget.onSendAudio != null
                  ? (_) => _startRecording()
                  : null,
          onLongPressEnd:
              !_hasText && widget.onSendAudio != null
                  ? (_) => _stopRecording()
                  : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient:
                  _hasText
                      ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          context.adaptivePrimaryColor,
                          context.adaptivePrimaryColor.withValues(alpha: 0.8),
                        ],
                      )
                      : null,
              color:
                  _hasText
                      ? null
                      : widget.onSendAudio != null
                      ? context.adaptivePrimaryColor
                      : context.surfaceVariantColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow:
                  _hasText
                      ? [
                        BoxShadow(
                          color: context.adaptivePrimaryColor.withValues(
                            alpha: 0.3,
                          ),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                      : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Mic icon (fades out when text is present)
                AnimatedOpacity(
                  opacity: _hasText ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Transform.scale(
                    scale: 1 - (_morphAnimation.value * 0.3),
                    child: Icon(
                      Icons.mic,
                      color:
                          widget.onSendAudio != null
                              ? AppColors.white
                              : context.textTertiaryColor,
                    ),
                  ),
                ),
                // Send icon (fades in when text is present)
                AnimatedOpacity(
                  opacity: _hasText ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Transform.scale(
                    scale: 0.7 + (_morphAnimation.value * 0.3),
                    child: Transform.rotate(
                      angle: -0.4, // Slight rotation for send icon
                      child: Icon(Icons.send_rounded, color: AppColors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
