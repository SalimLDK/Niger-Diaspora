import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart' as emoji_picker;

import '../../../../core/constants/app_colors.dart';
import '../../../../features/messages/presentation/widgets/emoji_sticker_picker.dart';
import '../../../../core/services/audio_recording_service.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/services/preferences_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../../../features/messages/presentation/widgets/location_picker_modal.dart';
import '../../../../features/messages/presentation/screens/camera_capture_screen.dart';
import '../../../../features/messages/presentation/screens/gallery_picker_screen.dart';
import '../../../../features/messages/presentation/screens/media_batch_preview_screen.dart';
import '../../../../features/messages/presentation/screens/media_preview_screen.dart';
import '../../../../features/messages/domain/entities/message_entity.dart';
import '../../../../features/gifs/domain/entities/gif_entity.dart';
import '../../../../features/stickers/domain/entities/sticker_entity.dart';
import '../../../../features/feed/domain/entities/post_entity.dart' show MentionedUser;
import '../../../../features/messages/presentation/widgets/mention_suggestion_overlay.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';

/// Hauteur du picker emoji/GIF, bornée à l'espace réellement libre.
///
/// Une fraction de la hauteur d'écran **totale** (sans réserver l'en-tête, le
/// composer et le bandeau épinglé) débordait la `Column` de l'écran de
/// conversation en paysage (écran court). On soustrait donc les zones système
/// et une réserve chrome (~176 dp), et on ne dépasse jamais l'espace libre.
/// Fonction pure (sans `BuildContext`) pour être testable directement.
double computeMessagePickerHeight({
  required double screenHeight,
  required double systemInset,
  required bool isLandscape,
}) {
  const chromeReserve = 176.0; // en-tête + composer + bandeau + marge
  final available = screenHeight - systemInset - chromeReserve;

  var height = screenHeight * (isLandscape ? 0.62 : 0.45);
  final maxByScreen = isLandscape ? 260.0 : 300.0;
  if (height > maxByScreen) height = maxByScreen;
  if (height > available) height = available; // évite l'overflow paysage
  // Viser ~150 dp min, mais jamais au-delà du disponible (petit écran = grille
  // compacte plutôt qu'un overflow).
  const minUsable = 150.0;
  final floor = minUsable < available ? minUsable : available;
  if (height < floor) height = floor;
  return height;
}

class MessageInput extends StatefulWidget {
  final String conversationId;
  final Function(String, List<MentionedUser>) onSendText;
  final Function(File, bool isImage, {String? caption}) onSendFile;
  final Function(File audioFile, {String? caption})? onSendAudioFile;
  final Function(File audioFile, int duration, List<double> waveform)?
  onSendAudio;
  final Function(double latitude, double longitude, String address)?
  onSendLocation;
  final Function(StickerEntity sticker)? onSendSticker;

  /// Appelé quand un GIF (ou sticker Tenor/Giphy) est choisi dans le picker.
  final Function(GifEntity gif)? onSendGif;
  final VoidCallback? onTyping;
  final bool isLoading;

  // Reply support
  final MessageEntity? replyToMessage;
  final VoidCallback? onCancelReply;

  // Mention support (empty for non-group conversations)
  final List<MentionedUser> groupMembers;

  // Création d'événement/sondage depuis le menu « + » (null = option masquée)
  final VoidCallback? onCreateEvent;
  final VoidCallback? onCreatePoll;

  const MessageInput({
    super.key,
    required this.conversationId,
    required this.onSendText,
    required this.onSendFile,
    this.onSendAudioFile,
    this.onSendAudio,
    this.onSendLocation,
    this.onSendSticker,
    this.onSendGif,
    this.onTyping,
    this.isLoading = false,
    this.replyToMessage,
    this.onCancelReply,
    this.groupMembers = const [],
    this.onCreateEvent,
    this.onCreatePoll,
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
  bool _isOverLimit = false;
  bool _isRecording = false;
  bool _showPicker = false;
  bool _showAttachPanel = false; // panneau grille 3×2 ancré (pièces jointes)
  int _pickerTabIndex = 0; // 0 = emojis, 1 = stickers
  double _dragOffset = 0;
  bool _isCancelling = false;
  bool _isLocked = false;
  double _verticalDragOffset = 0;

  // Character counter threshold
  static const int _charCountThreshold = 200;
  static const int _maxCharCount = 2000;

  // Draft persistence
  Timer? _draftSaveTimer;

  // Mention state
  List<MentionedUser> _pendingMentions = [];
  List<MentionedUser> _mentionSuggestions = [];
  String? _activeMentionQuery;
  int? _mentionTriggerOffset;

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

    // Load saved draft
    _loadDraft();

    // Listen to focus changes for input field styling and emoji/sticker picker
    _focusNode.addListener(() {
      if (_focusNode.hasFocus && _showPicker) {
        setState(() {
          _showPicker = false;
        });
      } else {
        setState(() {});
      }
    });

    _controller.addListener(() {
      _detectMentionTrigger();
      final hasText = _controller.text.trim().isNotEmpty;
      final isOverLimit = _controller.text.length > _maxCharCount;

      if (hasText != _hasText || isOverLimit != _isOverLimit) {
        setState(() {
          _hasText = hasText;
          _isOverLimit = isOverLimit;
        });

        // Animate morphing
        if (hasText && !isOverLimit) {
          _morphController.forward();
        } else if (!hasText) {
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

      // Save draft with debounce
      _scheduleDraftSave();
    });
  }

  void _loadDraft() {
    final draft = PreferencesService.instance.getMessageDraft(
      widget.conversationId,
    );
    if (draft != null && draft.isNotEmpty) {
      _controller.text = draft;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: draft.length),
      );
    }
  }

  void _scheduleDraftSave() {
    _draftSaveTimer?.cancel();
    _draftSaveTimer = Timer(const Duration(milliseconds: 500), () {
      PreferencesService.instance.saveMessageDraft(
        widget.conversationId,
        _controller.text,
      );
    });
  }

  void _clearDraft() {
    _draftSaveTimer?.cancel();
    PreferencesService.instance.clearMessageDraft(widget.conversationId);
  }

  @override
  void dispose() {
    _draftSaveTimer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    _morphController.dispose();
    if (_isRecording) {
      _recordingService.cancelRecording();
    }
    super.dispose();
  }

  void _detectMentionTrigger() {
    if (widget.groupMembers.isEmpty) return;
    final text = _controller.text;
    final cursor = _controller.selection.baseOffset;
    if (cursor < 0) return;

    final before = text.substring(0, cursor);
    final atIndex = before.lastIndexOf('@');
    if (atIndex == -1) {
      _clearMentionState();
      return;
    }

    final query = before.substring(atIndex + 1);
    if (query.contains(' ') || query.contains('\n')) {
      _clearMentionState();
      return;
    }

    final filtered =
        widget.groupMembers
            .where((m) => m.name.toLowerCase().startsWith(query.toLowerCase()))
            .toList();

    if (_activeMentionQuery != query ||
        _mentionTriggerOffset != atIndex ||
        _mentionSuggestions.length != filtered.length) {
      setState(() {
        _activeMentionQuery = query;
        _mentionTriggerOffset = atIndex;
        _mentionSuggestions = filtered;
      });
    }
  }

  void _clearMentionState() {
    if (_activeMentionQuery != null || _mentionSuggestions.isNotEmpty) {
      setState(() {
        _activeMentionQuery = null;
        _mentionTriggerOffset = null;
        _mentionSuggestions = [];
      });
    }
  }

  void _onMentionSelected(MentionedUser user) {
    final text = _controller.text;
    final triggerOffset = _mentionTriggerOffset!;
    final cursor = _controller.selection.baseOffset;
    final newText = text.replaceRange(triggerOffset, cursor, '@${user.name} ');
    _controller.text = newText;
    _controller.selection = TextSelection.collapsed(
      offset: triggerOffset + user.name.length + 2,
    );

    if (!_pendingMentions.any((m) => m.id == user.id)) {
      _pendingMentions = [..._pendingMentions, user];
    }
    _clearMentionState();
    _focusNode.requestFocus();
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final finalMentions =
        _pendingMentions.where((m) => text.contains('@${m.name}')).toList();

    widget.onSendText(text, finalMentions);
    _pendingMentions = [];
    _clearMentionState();
    _controller.clear();
    _clearDraft();
    _focusNode.requestFocus();
  }

  void _togglePicker({int tabIndex = 0}) {
    if (_showPicker && _pickerTabIndex == tabIndex) {
      // Hide picker and show keyboard
      setState(() => _showPicker = false);
      _focusNode.requestFocus();
    } else {
      // Hide keyboard and show picker
      _focusNode.unfocus();
      setState(() {
        _showPicker = true;
        _showAttachPanel = false;
        _pickerTabIndex = tabIndex;
      });
    }
  }

  /// Ouvre/ferme le panneau ancré de pièces jointes (grille 3×2). Remplace
  /// l'ancien `showModalBottomSheet` (accessible en repli via appui long sur « + »).
  void _toggleAttachPanel() {
    if (_showAttachPanel) {
      setState(() => _showAttachPanel = false);
    } else {
      _focusNode.unfocus();
      setState(() {
        _showAttachPanel = true;
        _showPicker = false;
      });
    }
  }

  void _hidePicker() {
    setState(() => _showPicker = false);
    _focusNode.requestFocus();
  }

  void _onStickerSelected(StickerEntity sticker) {
    // Hide picker
    setState(() => _showPicker = false);
    // Send sticker
    widget.onSendSticker?.call(sticker);
  }

  void _onGifSelected(GifEntity gif) {
    setState(() => _showPicker = false);
    widget.onSendGif?.call(gif);
  }

  void _onEmojiSelected(
    emoji_picker.Category? category,
    emoji_picker.Emoji emoji,
  ) {
    final text = _controller.text;
    final selection = _controller.selection;
    final start = selection.start >= 0 ? selection.start : text.length;
    final end = selection.end >= 0 ? selection.end : text.length;
    final newText = text.replaceRange(start, end, emoji.emoji);
    _controller.text = newText;
    _controller.selection = TextSelection.collapsed(
      offset: start + emoji.emoji.length,
    );
  }

  void _onBackspacePressed() {
    final text = _controller.text;
    final selection = _controller.selection;
    if (text.isNotEmpty && selection.start > 0) {
      // Handle emoji deletion (emojis can be multiple code units)
      final beforeCursor = text.substring(0, selection.start);
      final characters = beforeCursor.characters.toList();
      if (characters.isNotEmpty) {
        characters.removeLast();
        final newText = characters.join() + text.substring(selection.end);
        _controller.text = newText;
        _controller.selection = TextSelection.collapsed(
          offset: characters.join().length,
        );
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
          widget.onSendFile(
            result.file,
            result.isImage,
            caption: result.caption,
          );
        }
      }
    } on PlatformException catch (e) {
      if (e.code == 'camera_access_denied' && mounted) {
        _showCameraPermissionError(PermissionResult.permanentlyDenied);
      }
    }
  }

  Future<void> _takeVideo() async {
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
      final video = await picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 5), // Limite de 5 minutes
      );

      if (video != null && mounted) {
        // Navigate to preview screen
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
    } on PlatformException catch (e) {
      if (e.code == 'camera_access_denied' && mounted) {
        _showCameraPermissionError(PermissionResult.permanentlyDenied);
      }
    }
  }

  void _showCameraPermissionError(PermissionResult result) {
    final l10n = AppLocalizations.of(context)!;
    final isPermanent = result == PermissionResult.permanentlyDenied;
    final message = PermissionService.getCameraPermissionDeniedMessageLocalized(
      result,
    );

    if (isPermanent) {
      PermissionService.showPermissionDeniedDialog(
        context: context,
        title: l10n.cameraPermissionRequiredTitle,
        message: message,
        showSettingsButton: true,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
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

  Future<void> _pickAudio() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final caption = _controller.text.trim();
      if (widget.onSendAudioFile != null) {
        widget.onSendAudioFile!(
          file,
          caption: caption.isEmpty ? null : caption,
        );
      } else {
        // Fallback for legacy callers.
        widget.onSendFile(file, false);
      }
      _controller.clear();
      setState(() => _hasText = false);
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

  /// Revue groupée (§27d) avant envoi : pellicule + qualité réduite + poids
  /// annoncé. Appelée seulement quand il y a plusieurs médias — 1 seul
  /// continue de passer par [MediaPreviewScreen] (édition Signal-style).
  Future<void> _reviewAndSendBatch(List<GalleryPick> picks) async {
    final result = await Navigator.push<MediaBatchPreviewResult>(
      context,
      MaterialPageRoute(builder: (_) => MediaBatchPreviewScreen(picks: picks)),
    );
    if (result == null || result.picks.isEmpty || !mounted) return;
    for (final p in result.picks) {
      widget.onSendFile(p.file, !p.isVideo);
    }
  }

  /// Caméra unifiée (photo/vidéo dans le même écran). 1 média passe par
  /// l'aperçu Signal-style, plusieurs passent par la revue groupée (§27d).
  Future<void> _openCamera() async {
    final permissionResult =
        await PermissionService().requestCameraPermission();
    if (permissionResult != PermissionResult.granted) {
      if (mounted) _showCameraPermissionError(permissionResult);
      return;
    }
    if (!mounted) return;
    final result = await Navigator.push<List<CameraMedia>>(
      context,
      MaterialPageRoute(builder: (_) => const CameraCaptureScreen()),
    );
    if (result == null || result.isEmpty || !mounted) return;
    if (result.length == 1) {
      widget.onSendFile(result.first.file, !result.first.isVideo);
      return;
    }
    await _reviewAndSendBatch(
      result.map((m) => GalleryPick(m.file, m.isVideo)).toList(),
    );
  }

  /// Galerie intégrée (grille photo_manager, jamais le gestionnaire de
  /// fichiers). 1 média passe par l'aperçu, plusieurs passent par la revue
  /// groupée (§27d) avant d'être envoyés.
  Future<void> _pickFromGalleryUnified() async {
    if (!mounted) return;
    final picks = await Navigator.push<List<GalleryPick>>(
      context,
      MaterialPageRoute(builder: (_) => const GalleryPickerScreen()),
    );
    if (picks == null || picks.isEmpty || !mounted) return;
    if (picks.length == 1) {
      final p = picks.first;
      final result = await Navigator.push<MediaPreviewResult>(
        context,
        MaterialPageRoute(
          builder:
              (_) => MediaPreviewScreen(
                file: p.file,
                type: p.isVideo ? MediaType.video : MediaType.image,
                conversationId: '',
              ),
        ),
      );
      if (result != null && mounted) {
        widget.onSendFile(result.file, result.isImage, caption: result.caption);
      }
    } else {
      await _reviewAndSendBatch(picks);
    }
  }

  void _showAttachmentOptions() {
    // Unfocus to hide keyboard before showing attachment options
    _focusNode.unfocus();
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
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
                  l10n.sendFileTitle,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: context.textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 24),
                // First row - Caméra (unifiée photo/vidéo) + Galerie intégrée
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _AttachmentOption(
                      icon: Icons.camera_alt,
                      label: l10n.cameraSection,
                      color: context.adaptiveSecondaryColor,
                      onTap: () {
                        Navigator.pop(context);
                        _openCamera();
                      },
                    ),
                    _AttachmentOption(
                      icon: Icons.photo_library,
                      label: l10n.photosLabel,
                      color: context.adaptivePrimaryColor,
                      onTap: () {
                        Navigator.pop(context);
                        _pickFromGalleryUnified();
                      },
                    ),
                    _AttachmentOption(
                      icon: Icons.video_library,
                      label: l10n.videosLabel,
                      color: Colors.purple,
                      onTap: () {
                        Navigator.pop(context);
                        _pickVideo();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Second row - Gallery options (Audio, Documents)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _AttachmentOption(
                      icon: Icons.audiotrack,
                      label: l10n.audioLabel,
                      color: Colors.orange,
                      onTap: () {
                        Navigator.pop(context);
                        _pickAudio();
                      },
                    ),
                    _AttachmentOption(
                      icon: Icons.insert_drive_file,
                      label: l10n.documentsLabel,
                      color: Colors.blue,
                      onTap: () {
                        Navigator.pop(context);
                        _pickFile();
                      },
                    ),
                  ],
                ),
                if (widget.onCreateEvent != null ||
                    widget.onCreatePoll != null) ...[
                  const SizedBox(height: 16),
                  // Third row - Contenu interactif (Événement, Sondage)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      if (widget.onCreateEvent != null)
                        _AttachmentOption(
                          icon: Icons.event,
                          label: 'Événement',
                          color: Colors.teal,
                          onTap: () {
                            Navigator.pop(context);
                            widget.onCreateEvent!();
                          },
                        ),
                      if (widget.onCreatePoll != null)
                        _AttachmentOption(
                          icon: Icons.poll,
                          label: 'Sondage',
                          color: const Color(0xFF6B5CE0),
                          onTap: () {
                            Navigator.pop(context);
                            widget.onCreatePoll!();
                          },
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                // Divider with label
                Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: context.outlineColor.withValues(alpha: 0.2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        l10n.cameraSection,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textTertiaryColor,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color: context.outlineColor.withValues(alpha: 0.2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Second row - Camera options
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _AttachmentOption(
                      icon: Icons.camera_alt,
                      label: l10n.photoLabel,
                      color: context.adaptiveSecondaryColor,
                      onTap: () {
                        Navigator.pop(context);
                        _takePhoto();
                      },
                    ),
                    _AttachmentOption(
                      icon: Icons.videocam,
                      label: l10n.videoLabel,
                      color: Colors.red,
                      onTap: () {
                        Navigator.pop(context);
                        _takeVideo();
                      },
                    ),
                  ],
                ),
                // Location option
                if (widget.onSendLocation != null) ...[
                  const SizedBox(height: 20),
                  // Divider with label
                  Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: context.outlineColor.withValues(alpha: 0.2),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          l10n.locationSection,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.textTertiaryColor,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: context.outlineColor.withValues(alpha: 0.2),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _AttachmentOption(
                        icon: Icons.location_on,
                        label: l10n.positionLabel,
                        color: Colors.green,
                        onTap: () {
                          Navigator.pop(context);
                          _showLocationPicker();
                        },
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
              ],
            ),
          ),
    );
  }

  Future<void> _showLocationPicker() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => LocationPickerModal(
            onLocationSelected: (lat, lng, address) {
              widget.onSendLocation?.call(lat, lng, address);
            },
          ),
    );
  }

  // Audio recording methods
  Future<void> _startRecording() async {
    if (widget.onSendAudio == null) return;

    final hasPermission = await _recordingService.requestPermission();
    if (!hasPermission) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.microphonePermissionRequired),
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
        _isLocked = false;
        _verticalDragOffset = 0;
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

    _resetRecordingState();
  }

  void _onLongPressDrag(LongPressMoveUpdateDetails details) {
    if (!_isRecording || _isLocked) return;

    final wasCancelling = _isCancelling;
    final wasNearLock = _verticalDragOffset < -35;

    setState(() {
      // offsetFromOrigin est déjà relatif au point de départ du LongPress
      _dragOffset = details.offsetFromOrigin.dx;
      _verticalDragOffset = details.offsetFromOrigin.dy;

      // Annulation si drag horizontal vers la gauche > 80px
      _isCancelling = _dragOffset < -80;

      // Verrouillage si drag vertical vers le haut > 50px
      if (_verticalDragOffset < -50) {
        _isLocked = true;
        HapticFeedback.heavyImpact();
      }
    });

    // Feedback haptic quand on entre dans la zone d'annulation
    if (_isCancelling && !wasCancelling) {
      HapticFeedback.mediumImpact();
    }

    // Feedback quand on approche du seuil de verrouillage
    if (_verticalDragOffset < -35 && !wasNearLock && !_isLocked) {
      HapticFeedback.selectionClick();
    }
  }

  void _onLongPressRelease() {
    if (!_isRecording) return;

    if (_isCancelling) {
      // Annuler l'enregistrement
      _recordingService.cancelRecording();
      HapticFeedback.lightImpact();
      _resetRecordingState();
    } else if (!_isLocked) {
      // Envoyer l'enregistrement
      _stopRecording();
    }
    // Si verrouillé, ne rien faire - l'utilisateur utilisera les boutons
  }

  @override
  Widget build(BuildContext context) {
    // Structure simple : Row avec l'input/overlay à gauche et le bouton à droite
    // Le bouton reste TOUJOURS dans l'arbre pour maintenir la continuité des gestes
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Mention suggestions overlay
        MentionSuggestionOverlay(
          suggestions: _mentionSuggestions,
          onSelect: _onMentionSelected,
        ),

        // Reply preview (uniquement si pas en enregistrement)
        if (widget.replyToMessage != null && !_isRecording)
          _buildReplyPreview(context),

        // Panneau ancré de pièces jointes (grille 3×2), au-dessus du composer.
        if (_showAttachPanel && !_isRecording) _buildAttachPanel(context),

        // Zone principale : barre flottante (« + » + champ) et le bouton
        // vocal/envoi **hors de la barre** (cercle séparé à droite).
        Padding(
          padding: EdgeInsets.fromLTRB(
            10,
            6,
            10,
            MediaQuery.of(context).padding.bottom + 8,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color:
                        context.isDarkMode
                            ? const Color(0xFF1A1714)
                            : const Color(0xFFFFFFFF),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color:
                          context.isDarkMode
                              ? const Color(0xFF2A241E)
                              : const Color(0xFFEFE7DB),
                      width: 1,
                    ),
                    boxShadow:
                        context.isDarkMode
                            ? null
                            : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // « + » (repli : appui long = panneau complet).
                      if (!_isRecording) ...[
                        _buildPlusButton(context),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child:
                            _isRecording
                                ? _buildRecordingBanner(context)
                                : _buildPillField(context),
                      ),
                    ],
                  ),
                ),
              ),
              // Bouton vocal / envoi HORS de la barre flottante.
              if (!_isLocked) ...[
                const SizedBox(width: 8),
                _buildPersistentActionButton(context),
              ],
            ],
          ),
        ),

        // Combined emoji/sticker picker (uniquement si pas en enregistrement)
        if (_showPicker && !_isRecording)
          EmojiStickerPicker(
            // Hauteur bornée à l'espace réellement libre (voir
            // computeMessagePickerHeight) : évite l'overflow paysage.
            height: computeMessagePickerHeight(
              screenHeight: MediaQuery.of(context).size.height,
              systemInset: MediaQuery.of(context).viewPadding.vertical,
              isLandscape:
                  MediaQuery.of(context).orientation == Orientation.landscape,
            ),
            initialTabIndex: _pickerTabIndex,
            onEmojiSelected: _onEmojiSelected,
            onBackspacePressed: _onBackspacePressed,
            onStickerSelected:
                widget.onSendSticker != null ? _onStickerSelected : null,
            onGifSelected: widget.onSendGif != null ? _onGifSelected : null,
            onClose: _hidePicker,
          ),
      ],
    );
  }

  /// Bouton « + » hors du champ : ouvre le panneau ancré (grille 3×2).
  /// Pastille circulaire teintée accent (le « + » pivote en « × » à l'ouverture).
  /// Appui long = ancien sheet complet (repli avec audio/vidéo dédiés).
  Widget _buildPlusButton(BuildContext context) {
    final active = _showAttachPanel;
    final accent = context.adaptivePrimaryColor;
    return GestureDetector(
      onLongPress: _showAttachmentOptions,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: active ? 0.20 : 0.12),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          onPressed: _toggleAttachPanel,
          // Le même glyphe « + » pivote de 45° pour devenir une croix.
          icon: AnimatedRotation(
            turns: active ? 0.125 : 0.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: const Icon(Icons.add_rounded, size: 24),
          ),
          tooltip: AppLocalizations.of(context)!.sendFileTitle,
          color: accent,
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }

  /// Champ pilule avec l'emoji **à l'intérieur** (à droite du texte).
  Widget _buildPillField(BuildContext context) {
    final accent = context.adaptivePrimaryColor;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          // Aucun cadre ni fond : la saisie se fond dans la barre flottante.
          constraints: const BoxConstraints(maxHeight: 120, minHeight: 44),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  enabled: !widget.isLoading,
                  // Champ sur une seule ligne (le texte défile horizontalement).
                  maxLines: 1,
                  maxLength: _maxCharCount,
                  style: TextStyle(
                    fontSize: 15.5,
                    color: context.textPrimaryColor,
                  ),
                  buildCounter:
                      (
                        context, {
                        required currentLength,
                        required isFocused,
                        maxLength,
                      }) => null,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context)!.yourMessage,
                    hintStyle: TextStyle(
                      color: context.textTertiaryColor,
                      fontSize: 15.5,
                    ),
                    isCollapsed: true,
                    // Le thème global impose un OutlineInputBorder : on neutralise
                    // TOUS les états (sinon le cadre reste malgré `border: none`).
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    filled: false,
                    contentPadding: const EdgeInsets.only(
                      left: 18,
                      right: 6,
                      top: 12,
                      bottom: 12,
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              // Emoji à l'intérieur du champ, centré verticalement.
              Padding(
                padding: const EdgeInsets.only(right: 6, bottom: 5),
                child: InkWell(
                  onTap: () => _togglePicker(),
                  customBorder: const CircleBorder(),
                  child: Padding(
                    padding: const EdgeInsets.all(5),
                    child: Icon(
                      _showPicker
                          ? Icons.keyboard_rounded
                          : Icons.emoji_emotions_outlined,
                      size: 23,
                      color: _showPicker ? accent : context.textSecondaryColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_controller.text.length >= _charCountThreshold)
          _buildCharacterCounter(context),
      ],
    );
  }

  /// Panneau ancré (grille 3×2) : Caméra, Galerie, Document, Position,
  /// Sondage, Événement.
  Widget _buildAttachPanel(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tiles = <Widget>[
      _buildAttachTile(
        icon: Icons.photo_camera,
        label: l10n.cameraSection,
        color: context.adaptivePrimaryColor,
        onTap: () {
          _toggleAttachPanel();
          _openCamera();
        },
      ),
      _buildAttachTile(
        icon: Icons.photo_library,
        label: l10n.photosLabel,
        color: context.adaptivePrimaryColor,
        onTap: () {
          _toggleAttachPanel();
          _pickFromGalleryUnified();
        },
      ),
      _buildAttachTile(
        icon: Icons.description,
        label: l10n.documentsLabel,
        color: context.adaptivePrimaryColor,
        onTap: () {
          _toggleAttachPanel();
          _pickFile();
        },
      ),
      if (widget.onSendLocation != null)
        _buildAttachTile(
          icon: Icons.location_on,
          label: l10n.positionLabel,
          color: context.adaptiveSecondaryColor,
          onTap: () {
            _toggleAttachPanel();
            _showLocationPicker();
          },
        ),
      if (widget.onCreatePoll != null)
        _buildAttachTile(
          icon: Icons.poll,
          label: l10n.pollLabel,
          color: context.adaptiveSecondaryColor,
          onTap: () {
            _toggleAttachPanel();
            widget.onCreatePoll!();
          },
        ),
      if (widget.onCreateEvent != null)
        _buildAttachTile(
          icon: Icons.event,
          label: l10n.eventLabel,
          color: context.adaptiveSecondaryColor,
          onTap: () {
            _toggleAttachPanel();
            widget.onCreateEvent!();
          },
        ),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border:
            context.isDarkMode ? Border.all(color: AppColors.borderDark) : null,
        boxShadow:
            context.isDarkMode
                ? null
                : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
      ),
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.95,
        children: tiles,
      ),
    );
  }

  Widget _buildAttachTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: context.textSecondaryColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// Bandeau d'enregistrement (fond selon l'état : en cours / annulation armée).
  Widget _buildRecordingBanner(BuildContext context) {
    final bg =
        _isCancelling
            ? (context.isDarkMode
                ? Colors.red.withValues(alpha: 0.15)
                : const Color(0xFFFBE9E5))
            : (context.isDarkMode
                ? context.surfaceVariantColor
                : const Color(0xFFFDF3EF));
    final borderColor =
        _isCancelling
            ? (context.isDarkMode
                ? Colors.red.withValues(alpha: 0.4)
                : const Color(0xFFF0C7BC))
            : (context.isDarkMode
                ? AppColors.borderDark
                : const Color(0xFFF0D9CE));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: _buildInlineRecordingUI(context),
    );
  }

  /// UI d'enregistrement inline (remplace l'input pendant l'enregistrement)
  Widget _buildInlineRecordingUI(BuildContext context) {
    final cancelProgress = (_dragOffset.abs() / 100).clamp(0.0, 1.0);
    final showCancelHint = _dragOffset < -30;
    final showLockIndicator = _verticalDragOffset < -20 && !_isLocked;

    if (_isLocked) {
      // Mode verrouillé : afficher les boutons d'action
      return _buildLockedRecordingUI(context);
    }

    // Mode normal : afficher l'UI d'enregistrement avec hints
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Indicateur flottant "Relâchez pour verrouiller" (état 4)
        if (showLockIndicator) _buildFloatingLockIndicator(context),

        // Ligne principale
        Row(
          children: [
            // Cancel hint (seulement "Annuler", pas de "Verrouiller")
            Expanded(
              flex: 2,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child:
                    showCancelHint
                        ? _buildCancelHint(context, cancelProgress)
                        : _buildDefaultRecordingHint(context),
              ),
            ),

            // Recording indicator and duration
            _buildRecordingIndicator(context),

            const SizedBox(width: 12),

            // Waveform visualization
            Expanded(flex: 3, child: _buildSimpleWaveform(context)),
          ],
        ),
      ],
    );
  }

  /// Indicateur flottant qui apparaît quand on glisse vers le haut
  Widget _buildFloatingLockIndicator(BuildContext context) {
    final progress = (_verticalDragOffset.abs() / 50).clamp(0.0, 1.0);
    final isNearLock = _verticalDragOffset < -40;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color:
            isNearLock
                ? context.adaptivePrimaryColor.withValues(alpha: 0.2)
                : context.surfaceVariantColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: context.adaptivePrimaryColor.withValues(alpha: progress * 0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          isNearLock
              ? AppIcon(
                AppIcon.lock,
                color: context.adaptivePrimaryColor.withValues(
                  alpha: 0.5 + progress * 0.5,
                ),
                size: 20,
              )
              : AppIcon(
                AppIcon.lockOpen,
                color: context.adaptivePrimaryColor.withValues(
                  alpha: 0.5 + progress * 0.5,
                ),
                size: 20,
              ),
          const SizedBox(width: 8),
          Text(
            isNearLock
                ? AppLocalizations.of(context)!.releaseToLock
                : AppLocalizations.of(context)!.slideUpToLock,
            style: TextStyle(
              color: context.textSecondaryColor.withValues(
                alpha: 0.7 + progress * 0.3,
              ),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelHint(BuildContext context, double progress) {
    return Row(
      key: const ValueKey('cancel'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.delete_outline, color: context.errorColor, size: 22),
        const SizedBox(width: 6),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)!.releaseToCancelNow,
                style: TextStyle(
                  color: context.errorColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                AppLocalizations.of(context)!.recordingWillBeDeleted,
                style: TextStyle(
                  color: context.errorColor,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDefaultRecordingHint(BuildContext context) {
    // Hint "Annuler" avec flèche - le cadenas est au-dessus du bouton micro
    return Row(
      key: const ValueKey('default'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.arrow_back_ios_rounded,
          color: context.textTertiaryColor,
          size: 16,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            AppLocalizations.of(context)!.recordingGestureHints,
            style: TextStyle(
              color: context.textTertiaryColor,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildRecordingIndicator(BuildContext context) {
    return StreamBuilder<int>(
      stream: _recordingService.durationStream,
      initialData: 0,
      builder: (context, snapshot) {
        final duration = snapshot.data ?? 0;
        final minutes = duration ~/ 60;
        final secs = duration % 60;
        final durationText = '$minutes:${secs.toString().padLeft(2, '0')}';

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pulsing red dot
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.5, end: 1.0),
              duration: const Duration(milliseconds: 500),
              builder: (context, value, child) {
                return Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: value),
                    shape: BoxShape.circle,
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
            Text(
              durationText,
              style: TextStyle(
                color: context.textPrimaryColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSimpleWaveform(BuildContext context) {
    return StreamBuilder<double>(
      stream: _recordingService.amplitudeStream,
      initialData: 0.3,
      builder: (context, snapshot) {
        final amplitude = snapshot.data ?? 0.3;
        return Container(
          height: 32,
          decoration: BoxDecoration(
            color: context.adaptivePrimaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(15, (index) {
              final height = 8 + (amplitude * 16 * ((index % 3) + 1) / 3);
              return AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                width: 3,
                height: height.clamp(4.0, 24.0),
                decoration: BoxDecoration(
                  color:
                      _isCancelling ? Colors.red : context.adaptivePrimaryColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildLockedRecordingUI(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Badge "Enregistrement verrouillé"
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: context.adaptivePrimaryColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(
                AppIcon.lock,
                color: context.adaptivePrimaryColor,
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                AppLocalizations.of(context)!.recordingLockedBadge,
                style: TextStyle(
                  color: context.adaptivePrimaryColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),

        // Le badge seul ne dit pas pourquoi l'enregistrement continue sans
        // le doigt (§4f) : la phrase le dit.
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            AppLocalizations.of(context)!.recordingHandsFree,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.textTertiaryColor,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),

        // Ligne de contrôles
        Row(
          children: [
            // Delete button
            GestureDetector(
              onTap: () async {
                await _recordingService.cancelRecording();
                _resetRecordingState();
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: context.errorColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const AppIcon(
                  AppIcon.delete,
                  color: Colors.red,
                  size: 22,
                ),
              ),
            ),

            const SizedBox(width: 10),

            // Recording indicator
            _buildRecordingIndicator(context),

            const SizedBox(width: 10),

            // Waveform
            Expanded(child: _buildSimpleWaveform(context)),

            const SizedBox(width: 12),

            // Send button
            GestureDetector(
              onTap: _stopRecording,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: context.adaptivePrimaryColor,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const AppIcon(
                  AppIcon.send,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Reset l'état d'enregistrement
  void _resetRecordingState() {
    setState(() {
      _isRecording = false;
      _dragOffset = 0;
      _isCancelling = false;
      _isLocked = false;
      _verticalDragOffset = 0;
    });
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
            icon: AppIcon(
              AppIcon.close,
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
    final l10n = AppLocalizations.of(context)!;
    switch (type) {
      case MessageType.image:
        return l10n.messageTypePhoto;
      case MessageType.video:
        return l10n.messageTypeVideo;
      case MessageType.voiceNote:
        return l10n.messageTypeVoiceNote;
      case MessageType.audio:
        return l10n.messageTypeAudio;
      case MessageType.file:
        return l10n.messageTypeFile;
      case MessageType.text:
      case MessageType.system:
        return '';
      case MessageType.call:
        return l10n.messageTypeCall;
      case MessageType.location:
        return l10n.messageTypeLocation;
      case MessageType.sticker:
        return l10n.messageTypeSticker;
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

  /// Bouton d'action persistant - TOUJOURS dans l'arbre de widgets
  /// Gère tous les gestes LongPress pour l'enregistrement audio
  Widget _buildPersistentActionButton(BuildContext context) {
    // État de chargement
    if (widget.isLoading) {
      return Container(
        width: 44,
        height: 44,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.adaptivePrimaryColor,
          borderRadius: BorderRadius.circular(22),
        ),
        child: const CircularProgressIndicator(
          color: AppColors.white,
          strokeWidth: 2,
        ),
      );
    }

    return AnimatedBuilder(
      animation: _morphAnimation,
      builder: (context, child) {
        return GestureDetector(
          // Tap pour envoyer du texte
          onTap: (_hasText && !_isOverLimit) ? _sendMessage : null,

          // LongPress pour démarrer l'enregistrement
          onLongPressStart:
              !_hasText && widget.onSendAudio != null
                  ? (_) => _startRecording()
                  : null,

          // LongPressMoveUpdate gère le drag PENDANT l'enregistrement
          // C'est la clé : ce handler reste actif car le bouton reste dans l'arbre
          onLongPressMoveUpdate: (details) {
            if (_isRecording && !_isLocked) {
              _onLongPressDrag(details);
            }
          },

          // LongPressEnd gère le relâcher
          onLongPressEnd: (_) {
            if (_isRecording) {
              _onLongPressRelease();
            }
          },

          child: Transform.translate(
            // Le bouton suit légèrement le doigt pendant le drag
            offset: Offset(
              _isRecording && !_isLocked
                  ? (_dragOffset.clamp(-60.0, 0.0) * 0.3)
                  : 0,
              _isRecording && !_isLocked
                  ? (_verticalDragOffset.clamp(-40.0, 0.0) * 0.3)
                  : 0,
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              // Bouton rond : micro à vide, envoi dès qu'il y a du texte.
              width: _isRecording ? 56 : 44,
              height: _isRecording ? 56 : 44,
              decoration: BoxDecoration(
                // Aplat : `_getButtonFill` rend la couleur d'état, et
                // `_getButtonColor` le fond neutre du bouton au repos.
                color: _getButtonFill(context) ?? _getButtonColor(context),
                borderRadius: BorderRadius.circular(_isRecording ? 28 : 22),
                boxShadow: [
                  BoxShadow(
                    color: _getButtonShadowColor(context),
                    blurRadius: _isRecording ? 16 : 12,
                    offset: const Offset(0, 3),
                    spreadRadius: _isRecording ? 0 : -2,
                  ),
                ],
              ),
              child: _buildButtonContent(context),
            ),
          ),
        );
      },
    );
  }

  /// Bleu E2EE du bouton d'envoi : signale que le message part chiffré.
  /// Même famille que l'accusé de lecture des bulles.
  ///
  /// Chaque couleur signifiante garde une variante claire : elle ne sert plus
  /// de second point d'arrêt de dégradé, mais de teinte pour le thème sombre,
  /// où la version foncée passe mal (§6c).
  static const Color _kE2eeBlue = Color(0xFF2F6BE0);
  static const Color _kE2eeBlueLight = Color(0xFF5B9BFF);

  /// Vert du bouton vocal, indépendant du thème.
  static const Color _kVoiceGreen = Color(0xFF1B5E32);
  static const Color _kVoiceGreenLight = Color(0xFF2D7D46);

  /// Remplissage du bouton selon l'état, en aplat.
  ///
  /// Les quatre dégradés d'origine ont sauté : le système ne s'en sert plus.
  /// Les couleurs *signifiantes* sont conservées telles quelles, parce
  /// qu'elles disent chacune quelque chose — rouge pour l'annulation et le
  /// dépassement de limite, terracotta pendant l'enregistrement, bleu E2EE
  /// pour l'envoi chiffré, vert pour le vocal.
  Color? _getButtonFill(BuildContext context) {
    if (_isCancelling) return context.errorColor;
    if (_isRecording) return context.adaptivePrimaryColor;
    if (_hasText || widget.onSendAudio != null) {
      if (_isOverLimit) return context.errorColor;
      // Les teintes foncées passent mal sur un fond nuit (§6c) : chaque
      // couleur signifiante a sa variante claire pour le thème sombre.
      final sombre = context.isDarkMode;
      if (_hasText) return sombre ? _kE2eeBlueLight : _kE2eeBlue;
      return sombre ? _kVoiceGreenLight : _kVoiceGreen;
    }
    return null;
  }

  /// Couleur de fond du bouton (si pas de gradient)
  Color? _getButtonColor(BuildContext context) {
    if (_isRecording || _hasText || widget.onSendAudio != null) {
      return null;
    }
    return context.surfaceVariantColor;
  }

  /// Couleur de l'ombre du bouton
  Color _getButtonShadowColor(BuildContext context) {
    if (_isCancelling) {
      return Colors.red.withValues(alpha: 0.4);
    }
    if (_isRecording) {
      return context.adaptivePrimaryColor.withValues(alpha: 0.4);
    }
    if (_hasText || widget.onSendAudio != null) {
      if (_isOverLimit) return Colors.red.withValues(alpha: 0.35);
      final base = _hasText
          ? (context.isDarkMode ? _kE2eeBlueLight : _kE2eeBlue)
          : (context.isDarkMode ? _kVoiceGreenLight : _kVoiceGreen);
      return base.withValues(alpha: 0.35);
    }
    return Colors.black.withValues(alpha: 0.1);
  }

  /// Contenu du bouton (icône)
  Widget _buildButtonContent(BuildContext context) {
    // Pendant l'enregistrement
    if (_isRecording) {
      // Stack pour superposer le micro et le petit cadenas
      return Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Icône principale (micro ou poubelle)
          _isCancelling
              ? const AppIcon(AppIcon.delete, color: AppColors.white, size: 26)
              : const AppIcon(AppIcon.mic, color: AppColors.white, size: 26),
          // Cadenas flottant AU-DESSUS du bouton (sauf si annulation ou déjà verrouillé)
          if (!_isCancelling && !_isLocked)
            Positioned(
              right: -4,
              top: -55,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: AppIcon(
                  AppIcon.lock,
                  size: 24,
                  color: context.adaptivePrimaryColor,
                ),
              ),
            ),
        ],
      );
    }

    // Mode normal avec morphing mic <-> send
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // Icône micro (disparaît quand il y a du texte)
        AnimatedOpacity(
          opacity: _hasText ? 0.0 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Transform.scale(
            scale: 1 - (_morphAnimation.value * 0.3),
            child: AppIcon(
              AppIcon.mic,
              color:
                  widget.onSendAudio != null
                      ? AppColors.white
                      : context.textTertiaryColor,
            ),
          ),
        ),
        // Icône envoi (apparaît quand il y a du texte)
        AnimatedOpacity(
          opacity: _hasText ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: Transform.scale(
            scale: 0.7 + (_morphAnimation.value * 0.3),
            child: Transform.rotate(
              angle: -0.4,
              child: const AppIcon(AppIcon.send, color: AppColors.white),
            ),
          ),
        ),
        // Badge cadenas : le message part chiffré de bout en bout.
        // Masqué hors mode envoi et au-delà de la limite de caractères
        // (le bouton passe alors en rouge : l'envoi est bloqué, pas chiffré).
        if (_hasText && !_isOverLimit)
          Positioned(
            right: -3,
            bottom: -3,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: const AppIcon(AppIcon.lock, size: 10, color: _kE2eeBlue),
            ),
          ),
      ],
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
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: color.withValues(alpha: 0.2),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: context.textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }
}
