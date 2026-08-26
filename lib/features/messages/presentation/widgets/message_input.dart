import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart' as emoji_picker;

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/mention_handle.dart';
import '../widgets/emoji_sticker_picker.dart';
import '../../../../core/services/audio_recording_service.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/services/preferences_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../widgets/location_picker_modal.dart';
import '../screens/camera_capture_screen.dart';
import '../screens/gallery_picker_screen.dart';
import '../screens/media_batch_preview_screen.dart';
import '../screens/media_preview_screen.dart';
import '../../domain/entities/message_entity.dart';
import '../../../gifs/domain/entities/gif_entity.dart';
import '../../../stickers/domain/entities/sticker_entity.dart';
import '../../../feed/domain/entities/post_entity.dart'
    show MentionCandidate, MentionedUser;
import '../widgets/mention_suggestion_overlay.dart';
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
  final List<MentionCandidate> mentionCandidates;

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
    this.mentionCandidates = const [],
    this.onCreateEvent,
    this.onCreatePoll,
  });

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final AudioRecordingService _recordingService = AudioRecordingService();

  bool _hasText = false;
  bool _isRecording = false;
  bool _showPicker = false;
  bool _showAttachPanel = false; // panneau grille 3×2 ancré (pièces jointes)
  /// Compteur de caractères affiché : bascule au franchissement du seuil, pas
  /// à chaque frappe (le contenu du compteur, lui, se met à jour tout seul via
  /// le `ValueListenableBuilder` de `_buildPillField`).
  bool _showCounter = false;
  // Onglet demandé au panneau. Une énumération, pas un index : l'onglet
  // Stickers n'apparaît qu'une fois les packs chargés, et un index se
  // décalerait silencieusement à ce moment-là.
  MessagePickerTab _pickerTab = MessagePickerTab.emojis;
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
  List<MentionCandidate> _mentionSuggestions = [];
  String? _activeMentionQuery;
  int? _mentionTriggerOffset;

  /// Dernière hauteur connue du clavier logiciel.
  ///
  /// Les panneaux (pièces jointes, emoji) prennent **la place du clavier** au
  /// lieu de s'ajouter à la colonne : sans ça, pendant les ~250 ms de repli du
  /// clavier les `viewInsets` valent encore leur pleine valeur *et* le panneau
  /// est déjà inséré — la colonne dépassait de 85 px sur une conversation
  /// chargée (bandeau épinglé + chips + bandeau de clés).
  double _lastKeyboardHeight = 0;

  // Morphing animation
  late AnimationController _morphController;
  late Animation<double> _morphAnimation;

  @override
  void initState() {
    super.initState();

    // Indispensable au créneau clavier de `_revealInKeyboardSlot` : on y lit
    // `View.of(context).viewInsets`, qui **ne crée aucune dépendance**. Sans cet
    // observateur, plus rien ne redemande de build quand le clavier finit de se
    // replier — la fraction visible reste à 0 et le panneau ne s'affiche jamais
    // (il n'apparaissait que si un autre `setState` passait par là).
    WidgetsBinding.instance.addObserver(this);

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

    // Le retour du clavier referme les panneaux qui occupent la même place :
    // le picker emoji ET la grille de pièces jointes (sinon elle reste
    // affichée sous le clavier).
    _focusNode.addListener(() {
      if (_focusNode.hasFocus && (_showPicker || _showAttachPanel)) {
        setState(() {
          _showPicker = false;
          _showAttachPanel = false;
        });
      }
    });

    _controller.addListener(() {
      _detectMentionTrigger();
      final hasText = _controller.text.trim().isNotEmpty;

      if (hasText != _hasText) {
        setState(() {
          _hasText = hasText;
        });

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
      // Apparition/disparition du compteur : un seul `setState` au passage du
      // seuil, au lieu d'un par caractère saisi.
      final showCounter = _controller.text.length >= _charCountThreshold;
      if (showCounter != _showCounter) {
        setState(() => _showCounter = showCounter);
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
      // Le brouillon est injecté depuis initState, avant que le listener du
      // contrôleur ne soit posé : personne ne recalcule l'état dérivé. Sans
      // ça, le bouton reste sur le micro tant que l'utilisateur n'a pas tapé.
      _syncTextState(animateMorph: false);
    }
  }

  /// Recalcule l'état dérivé du texte (`_hasText`, `_showCounter`, morphing)
  /// à partir du contrôleur, au lieu d'attendre une frappe.
  ///
  /// Appelé depuis `initState` (brouillon restauré) : on assigne les champs
  /// directement, le premier build n'a pas encore eu lieu.
  void _syncTextState({required bool animateMorph}) {
    _hasText = _controller.text.trim().isNotEmpty;
    _showCounter = _controller.text.length >= _charCountThreshold;

    if (_hasText) {
      // Pas d'animation à l'ouverture : le bouton d'envoi doit être là d'emblée.
      if (animateMorph) {
        _morphController.forward();
      } else {
        _morphController.value = _morphController.upperBound;
      }
    } else {
      if (animateMorph) {
        _morphController.reverse();
      } else {
        _morphController.value = _morphController.lowerBound;
      }
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

  /// Le clavier bouge : redessiner pour que le panneau suive son retrait.
  @override
  void didChangeMetrics() {
    if (mounted && (_showAttachPanel || _showPicker)) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Une sauvegarde encore en attente serait perdue : on la force avant de
    // disposer le contrôleur (quitter l'écran moins de 500 ms après la
    // dernière frappe effaçait la fin du brouillon).
    if (_draftSaveTimer?.isActive ?? false) {
      PreferencesService.instance.saveMessageDraft(
        widget.conversationId,
        _controller.text,
      );
    }
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
    if (widget.mentionCandidates.isEmpty) return;
    final text = _controller.text;
    final cursor = _controller.selection.baseOffset;
    if (cursor < 0) return;

    final before = text.substring(0, cursor);
    final atIndex = before.lastIndexOf('@');
    if (atIndex == -1) {
      _clearMentionState();
      return;
    }

    // Un `@` collé à un caractère de mot n'ouvre pas une mention : c'est une
    // adresse e-mail qu'on est en train de taper.
    if (atIndex > 0 && RegExp(r'[\w.]').hasMatch(before[atIndex - 1])) {
      _clearMentionState();
      return;
    }

    final query = before.substring(atIndex + 1);
    if (query.contains(' ') || query.contains('\n')) {
      _clearMentionState();
      return;
    }

    // Le pseudo, mais aussi n'importe quel mot du nom affiché, accents repliés :
    // on tape `@mai`, pas `@IbrahimYacoubaMaïdaoua`.
    final filtered =
        widget.mentionCandidates
            .where(
              (c) => mentionQueryMatches(
                query: query,
                token: c.mentionToken,
                displayName: c.displayName,
              ),
            )
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

  void _onMentionSelected(MentionCandidate candidate) {
    // On écrit le PSEUDO, pas le nom affiché. Avant, la mention insérait
    // `@Ibrahim Yacouba Maïdaoua` : un jeton à espaces, que la détection ne
    // savait pas relire — elle abandonne dès qu'une espace apparaît, donc seul
    // le premier mot était cherchable.
    final token = candidate.mentionToken;
    final text = _controller.text;
    final triggerOffset = _mentionTriggerOffset!;
    final cursor = _controller.selection.baseOffset;
    final newText = text.replaceRange(triggerOffset, cursor, '@$token ');
    _controller.text = newText;
    _controller.selection = TextSelection.collapsed(
      offset: triggerOffset + token.length + 2,
    );

    final mention = MentionedUser(id: candidate.id, name: token);
    if (!_pendingMentions.any((m) => m.id == mention.id)) {
      _pendingMentions = [..._pendingMentions, mention];
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

  void _togglePicker({MessagePickerTab tab = MessagePickerTab.emojis}) {
    if (_showPicker && _pickerTab == tab) {
      // Hide picker and show keyboard
      setState(() => _showPicker = false);
      _focusNode.requestFocus();
    } else {
      // Hide keyboard and show picker
      _focusNode.unfocus();
      setState(() {
        _showPicker = true;
        _showAttachPanel = false;
        _pickerTab = tab;
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
        SnackBar(content: Text(message), backgroundColor: context.errorColor),
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
                conversationId: widget.conversationId,
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
                conversationId: widget.conversationId,
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
                      color: context.adaptivePrimaryColor,
                      onTap: () {
                        Navigator.pop(context);
                        _pickVideo();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Second row - Audio, Documents
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _AttachmentOption(
                      icon: Icons.audiotrack,
                      label: l10n.audioLabel,
                      color: context.adaptivePrimaryColor,
                      onTap: () {
                        Navigator.pop(context);
                        _pickAudio();
                      },
                    ),
                    _AttachmentOption(
                      icon: Icons.insert_drive_file,
                      label: l10n.documentsLabel,
                      color: context.adaptivePrimaryColor,
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
                          label: l10n.eventLabel,
                          color: context.adaptiveSecondaryColor,
                          onTap: () {
                            Navigator.pop(context);
                            widget.onCreateEvent!();
                          },
                        ),
                      if (widget.onCreatePoll != null)
                        _AttachmentOption(
                          icon: Icons.poll,
                          label: l10n.pollLabel,
                          color: context.adaptiveSecondaryColor,
                          onTap: () {
                            Navigator.pop(context);
                            widget.onCreatePoll!();
                          },
                        ),
                    ],
                  ),
                ],
                // La section « Caméra » qui suivait (Photo + Vidéo dédiées)
                // faisait doublon avec la tuile Caméra unifiée de la première
                // rangée, sous un séparateur qui reprenait le même libellé.
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
                        color: context.adaptiveSecondaryColor,
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
            backgroundColor: context.errorColor,
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
    //
    // Le LayoutBuilder ne sert pas à mesurer, mais à SAVOIR si quelqu'un nous a
    // donné une hauteur. Quand la hauteur est bornée, les panneaux deviennent
    // `Flexible` et se rétrécissent au lieu de déborder — `Flexible` dans une
    // colonne de hauteur infinie lèverait une assertion, d'où la condition
    // plutôt qu'un `Flexible` inconditionnel.
    //
    // Ce garde-fou est resté longtemps inerte en production : un commentaire
    // affirmait « la conversation le fait », mais dans
    // `conversation_screen.dart` (`body > Container > Stack > Column`), ce
    // widget était un enfant **non-flexible** de la `Column` ; `RenderFlex`
    // donne alors à ses enfants non-flexibles `maxHeight: Infinity`, donc
    // `bornee` valait `false` et `panneau()` renvoyait l'enfant tel quel.
    // C'était la cause du `BOTTOM OVERFLOWED` en paysage (bandeau de
    // restauration des clés + brouillon long, jusqu'à 240px avec un panneau
    // ouvert, encore 47px avec un brouillon de 2 lignes seulement).
    // Corrigé côté conversation (pas ici — un `Flexible` de plus dans cette
    // `Column` se serait partagé l'espace libre avec l'`Expanded` de la liste
    // des messages et l'aurait rabotée) : `conversation_screen.dart` borne
    // désormais ce widget dans un `ConstrainedBox(maxHeight: zoneCorps
    // .maxHeight)`, où `zoneCorps` vient du `LayoutBuilder` qui mesure déjà
    // la hauteur réelle du corps de la conversation. Voir
    // TESTS_APPAREIL_A_FAIRE.md, section « Paysage — overflow quand le chrome
    // dépasse la hauteur ».
    return LayoutBuilder(
      builder: (context, contraintes) {
        return _buildColumn(context, contraintes.maxHeight);
      },
    );
  }

  Widget _buildColumn(BuildContext context, double borne) {
    final bornee = borne.isFinite;
    // Un panneau ne peut se rétrécir que si la colonne a une hauteur connue.
    Widget panneau(Widget enfant) =>
        bornee ? Flexible(fit: FlexFit.loose, child: enfant) : enfant;

    // En paysage clavier ouvert, la hauteur disponible peut être si faible
    // qu'un composeur VIDE, sans aucune bannière, déborde déjà de quelques
    // pixels (mesuré : jusqu'à 12 px sur SM A515F). Le ConstrainedBox posé
    // côté conversation borne MessageInput, il ne le compresse pas sous son
    // contenu minimal — desserrer ce padding en paysage réduit ce plancher
    // au lieu de le déplacer ailleurs. Voir TESTS_APPAREIL_A_FAIRE.md,
    // section « Paysage — overflow quand le chrome dépasse la hauteur ».
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

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
        if (_showAttachPanel && !_isRecording)
          panneau(_revealInKeyboardSlot(context, _buildAttachPanel(context))),

        // Zone principale : barre flottante (« + » + champ) et le bouton
        // vocal/envoi **hors de la barre** (cercle séparé à droite).
        Padding(
          padding: EdgeInsets.fromLTRB(
            6,
            isLandscape ? 2 : 6,
            6,
            MediaQuery.of(context).padding.bottom + (isLandscape ? 2 : 8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // « + » **hors** de la pilule, en miroir du bouton d'envoi à
              // droite. À l'intérieur, il réservait sa largeur sur toute la
              // hauteur du champ : à 6 lignes, ça laissait une colonne vide de
              // ~68 px le long du texte, alors qu'il n'occupe que la ligne du
              // bas. Dehors, le texte part du bord de la pilule.
              if (!_isRecording) ...[
                _buildPlusButton(context),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: context.isDarkMode ? _kBarFillDark : _kBarFillLight,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color:
                          context.isDarkMode
                              ? _kBarBorderDark
                              : _kBarBorderLight,
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
                  padding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: isLandscape ? 3 : 6,
                  ),
                  child:
                      _isRecording
                          ? _buildRecordingBanner(context)
                          : _buildPillField(context, borne),
                ),
              ),
              // L'emoji garde sa pastille (fiche 26b) mais **dans** la pilule,
              // à droite du texte : en pastille autonome il lui prenait 52 dp,
              // et la pilule tombait à 55 % de la largeur de l'écran. Elle
              // remonte à ~73 %, sans que l'emoji revienne empiéter sur le
              // champ. Voir `_buildPillField`.
              // Bouton vocal / envoi HORS de la barre flottante.
              if (!_isLocked) ...[
                const SizedBox(width: 6),
                _buildPersistentActionButton(context),
              ],
            ],
          ),
        ),

        // Combined emoji/sticker picker (uniquement si pas en enregistrement)
        if (_showPicker && !_isRecording)
          panneau(
            _revealInKeyboardSlot(
              context,
              EmojiStickerPicker(
                // Hauteur SOUHAITEE. Quand la conversation borne la colonne,
                // le `panneau` la rabote a ce qui reste vraiment : cette
                // formule ne connait que la taille de l'ecran, pas les
                // bandeaux ni un champ de six lignes.
                height: computeMessagePickerHeight(
                  screenHeight: MediaQuery.of(context).size.height,
                  systemInset: MediaQuery.of(context).viewPadding.vertical,
                  isLandscape:
                      MediaQuery.of(context).orientation ==
                      Orientation.landscape,
                ),
                initialTab: _pickerTab,
                onEmojiSelected: _onEmojiSelected,
                onBackspacePressed: _onBackspacePressed,
                onStickerSelected:
                    widget.onSendSticker != null ? _onStickerSelected : null,
                onGifSelected: widget.onSendGif != null ? _onGifSelected : null,
              ),
            ),
          ),
      ],
    );
  }

  /// Révèle un panneau **à la place du clavier**, jamais en plus de lui.
  ///
  /// La fraction visible suit le retrait du clavier : pleine hauteur d'inset =
  /// rien d'affiché, inset nul = panneau entier. La hauteur totale de la
  /// colonne reste donc constante pendant toute l'animation, ce qui supprime
  /// l'overflow au lieu de le rendre seulement moins probable.
  ///
  /// Le panneau est aussi borné à la hauteur du clavier : au-delà, il défile.
  Widget _revealInKeyboardSlot(BuildContext context, Widget child) {
    // ⚠ Pas `MediaQuery.of(context).viewInsets` : le `Scaffold` consomme
    // l'inset du clavier pour rétrécir son `body`, donc il vaut déjà 0 ici.
    // Seule la vue porte encore la vraie hauteur du clavier.
    final view = View.of(context);
    final insets = view.viewInsets.bottom / view.devicePixelRatio;
    if (insets > _lastKeyboardHeight) {
      _lastKeyboardHeight = insets;
    }
    // Repli tant qu'aucun clavier n'a encore été vu (premier ouverture au « + »
    // sans avoir tapé) : hauteur usuelle d'un clavier Android.
    final slot = _lastKeyboardHeight > 0 ? _lastKeyboardHeight : 280.0;
    final factor = ((slot - insets) / slot).clamp(0.0, 1.0);

    return ClipRect(
      child: Align(
        alignment: Alignment.topCenter,
        heightFactor: factor,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: slot),
          child: child,
        ),
      ),
    );
  }

  /// Emoji en pastille propre, à droite de la barre (fiche 26b : cercle 44,
  /// fond `#F7EAE3`, glyphe `#FA7D00`). Il bascule en icône clavier quand le
  /// panneau est ouvert, comme lorsqu'il vivait dans le champ.
  ///
  /// Les valeurs de la fiche sont la version claire : en nocturne l'aplat
  /// pastel deviendrait un pavé lumineux, on le remplace par l'accent teinté.
  Widget _buildEmojiButton(BuildContext context) {
    final isDark = context.isDarkMode;
    final glyph = isDark ? const Color(0xFFFA7E3B) : const Color(0xFFFA7D00);
    final fill =
        isDark
            ? glyph.withValues(alpha: _showPicker ? 0.28 : 0.18)
            : (_showPicker ? const Color(0xFFF0DAC8) : const Color(0xFFF7EAE3));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      // 40 plutôt que 44 : la pastille vit maintenant dans la pilule, elle doit
      // tenir dans sa hauteur de ligne sans la faire grossir.
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
      child: IconButton(
        onPressed: () => _togglePicker(),
        icon: Icon(
          _showPicker ? Icons.keyboard_rounded : Icons.emoji_emotions_outlined,
          size: 23,
        ),
        tooltip: AppLocalizations.of(context)!.emojis,
        color: glyph,
        padding: EdgeInsets.zero,
      ),
    );
  }

  /// Bouton « + » hors du champ : ouvre le panneau ancré (grille 3×2).
  /// Pastille circulaire teintée accent (le « + » pivote en « × » à l'ouverture).
  /// Appui long = ancien sheet complet (repli avec audio/vidéo dédiés).
  Widget _buildPlusButton(BuildContext context) {
    final active = _showAttachPanel;
    final accent = context.adaptivePrimaryColor;
    final isDark = context.isDarkMode;

    // En clair, l'accent à 12 % posé sur le fond crème de la page donnait deux
    // teintes quasi identiques (relevé à l'écran : #F2E5D9 des deux côtés) —
    // le disque disparaissait, seul le glyphe orange se voyait. Il reprend donc
    // la surface de la pilule, blanc + liseré, et devient un frère de la barre
    // au lieu d'une tache. En nocturne l'aplat teinté ressort déjà sur le fond
    // sombre : on n'y touche pas.
    final poseSurLaPage = !isDark && !active;
    final fill =
        active
            ? accent.withValues(alpha: isDark ? 0.20 : 0.22)
            : (isDark ? accent.withValues(alpha: 0.12) : _kBarFillLight);

    return GestureDetector(
      onLongPress: _showAttachmentOptions,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        // 40 : le « + » est secondaire, seul le bouton d'envoi garde 44.
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: fill,
          shape: BoxShape.circle,
          border:
              poseSurLaPage
                  ? Border.all(color: _kBarBorderLight, width: 1)
                  : null,
          boxShadow:
              poseSurLaPage
                  ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                  : null,
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

  /// Champ pilule. L'emoji n'y est plus : il a rejoint sa propre pastille,
  /// hors de la barre (fiche 26b).
  /// [borne] : hauteur disponible pour tout le composer, `infinity` si
  /// personne ne nous en a donné une.
  Widget _buildPillField(BuildContext context, double borne) {
    // Six lignes, c'est bon en portrait (873 dp). En paysage il ne reste que
    // ~190 dp sous les bandeaux : un champ de six lignes y mangerait tout et
    // ferait déborder la colonne avant même que le panneau s'ouvre. On lui
    // laisse au plus la moitié de la place, ~22 dp par ligne.
    final maxLignes = borne.isFinite ? (borne / 2 / 22).floor().clamp(1, 6) : 6;
    // Dernier point de compression du plancher paysage (cf. `_buildColumn`) :
    // desserre aussi le padding vertical interne du champ lui-même.
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          // Aucun cadre ni fond : la saisie se fond dans la barre flottante.
          constraints: BoxConstraints(minHeight: isLandscape ? 38 : 44),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  enabled: !widget.isLoading,
                  // La barre grandit avec le texte jusqu'à 6 lignes, puis le
                  // champ défile verticalement. `maxLines: 6` plutôt qu'une
                  // contrainte de hauteur sur le Container : avec `null`, le
                  // champ déborde au lieu de défiler.
                  minLines: 1,
                  maxLines: maxLignes,
                  keyboardType: TextInputType.multiline,
                  // Entrée insère un retour à la ligne ; l'envoi passe par le
                  // bouton rond, toujours présent à droite.
                  textInputAction: TextInputAction.newline,
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
                    // Seul le « + » est hors de la pilule : 10 + les 8 du
                    // Container = 18 réels à gauche. À droite, la pastille
                    // emoji fait office de marge, d'où le 4.
                    contentPadding: EdgeInsets.only(
                      left: 10,
                      right: 4,
                      top: isLandscape ? 9 : 12,
                      bottom: isLandscape ? 9 : 12,
                    ),
                  ),
                ),
              ),
              // Pastille emoji dans la pilule, collée en bas à droite : elle
              // reste entièrement à droite du champ (elle n'empiète pas
              // dessus), mais ne coûte plus 52 dp de largeur au texte.
              _buildEmojiButton(context),
            ],
          ),
        ),
        // Le compteur ne reconstruit que lui-même à la frappe : la colonne du
        // composer, elle, ne bouge qu'au franchissement du seuil.
        if (_showCounter)
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _controller,
            builder: (context, value, _) => _buildCharacterCounter(context),
          ),
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
        // Défilable : le panneau est borné au créneau du clavier, et sur un
        // petit écran (ou en paysage) la grille doit pouvoir glisser au lieu
        // de déborder.
        physics: const ClampingScrollPhysics(),
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
                ? context.errorColor.withValues(alpha: 0.15)
                : _kBannerCancelBg)
            : (context.isDarkMode
                ? context.surfaceVariantColor
                : _kBannerRecordingBg);
    final borderColor =
        _isCancelling
            ? (context.isDarkMode
                ? context.errorColor.withValues(alpha: 0.4)
                : _kBannerCancelBorder)
            : (context.isDarkMode
                ? AppColors.borderDark
                : _kBannerRecordingBorder);

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

        // Minuterie + waveform sur la première ligne.
        Row(
          children: [
            _buildRecordingIndicator(context),
            const SizedBox(width: 12),
            Expanded(child: _buildSimpleWaveform(context)),
          ],
        ),

        const SizedBox(height: 4),

        // Le libellé a désormais **sa propre ligne**, sur toute la largeur.
        //
        // Il partageait la ligne avec la minuterie et le waveform, et n'en
        // recevait que 2/5 : sur l'appareil (A51, font_scale 1.1) « Relâcher
        // pour annuler » devenait « Relâc… » et « L'enregistrement sera
        // supprimé » devenait « L'enregi… ». Autrement dit, au moment précis
        // où l'utilisateur renonce, il ne pouvait pas lire ce qui allait
        // arriver à son enregistrement. Le waveform, lui, ne dit rien d'utile :
        // il pouvait céder la place.
        SizedBox(
          width: double.infinity,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child:
                showCancelHint
                    ? _buildCancelHint(context, cancelProgress)
                    : _buildDefaultRecordingHint(context),
          ),
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
                // Deux lignes plutôt qu'une coupure : à forte échelle de
                // police, la conséquence de l'annulation doit rester lisible.
                maxLines: 2,
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
            // « Glisser ‹ pour annuler · ↑ pour verrouiller » fait 43
            // caractères : à font_scale 1.1 il ne tient pas sur une ligne,
            // et il devenait « Glisser ‹… », ce qui n'apprend rien.
            maxLines: 2,
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
                    color: context.errorColor.withValues(alpha: value),
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
                      _isCancelling
                          ? context.errorColor
                          : context.adaptivePrimaryColor,
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
                child: AppIcon(
                  AppIcon.delete,
                  color: context.errorColor,
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
      case MessageType.poll:
        return 'Sondage';
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
                      ? context.errorColor.withValues(alpha: 0.1)
                      : isNearLimit
                      ? context.warningColor.withValues(alpha: 0.1)
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
                        ? context.errorColor
                        : isNearLimit
                        ? context.warningColor
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
          onTap: _hasText ? _sendMessage : null,

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
  static const Color _kVoiceGreen = Color(0xFF009600);
  static const Color _kVoiceGreenLight = Color(0xFF009600);

  /// Chrome de la barre flottante et du bandeau d'enregistrement.
  ///
  /// Ces teintes viennent du Guide de style et ne se déduisent d'aucun jeton
  /// de `AdaptiveColors` : elles restent codées ici, mais nommées plutôt que
  /// semées en littéraux au milieu du `build`.
  static const Color _kBarFillDark = Color(0xFF1A1714);
  static const Color _kBarFillLight = Color(0xFFFFFFFF);
  static const Color _kBarBorderDark = Color(0xFF2A241E);
  static const Color _kBarBorderLight = Color(0xFFEFE7DB);

  /// Bandeau d'enregistrement, thème clair uniquement (en sombre on retombe
  /// sur les jetons de surface et `errorColor`).
  static const Color _kBannerRecordingBg = Color(0xFFFDF3EF);
  static const Color _kBannerRecordingBorder = Color(0xFFF0D9CE);
  static const Color _kBannerCancelBg = Color(0xFFFBE9E5);
  static const Color _kBannerCancelBorder = Color(0xFFF0C7BC);

  /// Remplissage du bouton selon l'état, en aplat.
  ///
  /// Les quatre dégradés d'origine ont sauté : le système ne s'en sert plus.
  /// Les couleurs *signifiantes* sont conservées telles quelles, parce
  /// qu'elles disent chacune quelque chose — rouge pour l'annulation,
  /// terracotta pendant l'enregistrement, bleu E2EE pour l'envoi chiffré,
  /// vert pour le vocal.
  Color? _getButtonFill(BuildContext context) {
    if (_isCancelling) return context.errorColor;
    if (_isRecording) return context.adaptivePrimaryColor;
    if (_hasText || widget.onSendAudio != null) {
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
      return context.errorColor.withValues(alpha: 0.4);
    }
    if (_isRecording) {
      return context.adaptivePrimaryColor.withValues(alpha: 0.4);
    }
    if (_hasText || widget.onSendAudio != null) {
      final base =
          _hasText
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
        // Masqué hors mode envoi (le bouton est alors un micro).
        if (_hasText)
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
