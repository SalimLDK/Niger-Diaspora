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
import '../theme/attachment_accents.dart';
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

part 'message_input_texte.dart';
part 'message_input_pieces.dart';
part 'message_input_champ.dart';
part 'message_input_enregistrement.dart';
part 'message_input_apercus.dart';

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
  final Function(File, MessageType type, {String? caption}) onSendFile;
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

  /// Message en cours de modification, ou `null` en composition normale.
  ///
  /// La modification se fait **dans ce champ**, pas dans une boîte de dialogue :
  /// la conversation reste visible, le clavier ne change pas de place, et le
  /// geste est le même que pour écrire.
  final MessageEntity? editingMessage;

  /// Quitter la modification sans l'appliquer (croix du bandeau).
  final VoidCallback? onCancelEdit;

  /// Applique le nouveau texte.
  ///
  /// Le composeur ne referme rien de lui-même : c'est l'écran qui sort du mode
  /// modification une fois l'écriture faite — ou qui l'y laisse, texte intact,
  /// si elle a été refusée.
  final void Function(String nouveauTexte)? onSubmitEdit;

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
    this.editingMessage,
    this.onCancelEdit,
    this.onSubmitEdit,
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

  /// Brouillon mis de côté le temps d'une modification.
  ///
  /// Le champ sert aux deux usages. Sans cette mise de côté, entrer en
  /// modification écrasait le brouillon en cours (le listener le sauvegarde
  /// toutes les 500 ms), et en sortir laissait à sa place le texte du message
  /// modifié : un brouillon perdu, sans un mot.
  String? _brouillonMisDeCote;

  bool get _enModification => widget.editingMessage != null;

  /// Un appui long lancerait un vocal — faux pendant une modification, où le
  /// bouton applique. Sans ce garde, il en gardait aussi le vert.
  bool get _peutEnregistrer => widget.onSendAudio != null && !_enModification;
  final FocusNode _focusNode = FocusNode();
  final AudioRecordingService _recordingService = AudioRecordingService();

  /// Le doigt est-il encore posé sur le micro ? `_isRecording` ne le dit
  /// pas : il ne passe à vrai qu'APRÈS la permission et le démarrage du
  /// micro, deux attentes. Un doigt levé pendant ce temps trouvait
  /// `_isRecording` à faux, `onLongPressEnd` ne faisait rien — puis
  /// l'enregistrement démarrait, et plus rien ne l'arrêtait.
  bool _appuiMicro = false;

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

  /// Un champ de recherche du panneau emoji/GIF/sticker est ouvert : le
  /// panneau reste alors AU-DESSUS du clavier au lieu de lui céder la place
  /// (voir `EmojiStickerPicker.onRechercheOuverte`).
  bool _rechercheDansLePanneau = false;

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

    // Monté **déjà** en modification : `didUpdateWidget` ne se déclenchera
    // jamais pour ce cas-là. Sans ce rattrapage, le bandeau annonçait
    // « Modifier le message » au-dessus d'un champ vide — et le brouillon
    // restauré juste au-dessus serait parti pour le nouveau texte du message.
    // Vu sur un aperçu de rendu, pas en usage : aujourd'hui le composeur est
    // toujours déjà là quand on entre en modification. Ça ne tient qu'à
    // l'arbre de la conversation.
    if (widget.editingMessage != null) {
      _brouillonMisDeCote = _controller.text;
      _draftSaveTimer?.cancel();
      _controller.text = widget.editingMessage!.content;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
      _syncTextState(animateMorph: false);
    }

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
          unawaited(_morphController.forward());
        } else {
          unawaited(_morphController.reverse());
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

  @override
  void didUpdateWidget(MessageInput oldWidget) {
    super.didUpdateWidget(oldWidget);

    final avant = oldWidget.editingMessage;
    final apres = widget.editingMessage;
    if (avant?.id == apres?.id) return;

    if (apres != null) {
      // Entrée : le brouillon de côté, le texte du message dans le champ.
      // `??=` et non `=` — passer d'un message à un autre sans repasser par la
      // composition ne doit pas prendre le texte du premier pour un brouillon.
      _brouillonMisDeCote ??= _controller.text;
      _draftSaveTimer?.cancel();
      _remplacerTexte(apres.content);
      _focusNode.requestFocus();
    } else {
      // Sortie : le brouillon revient tel qu'il était.
      final brouillon = _brouillonMisDeCote ?? '';
      _brouillonMisDeCote = null;
      _remplacerTexte(brouillon);
    }
  }

  /// Remplace le contenu du champ et recalcule l'état dérivé.
  ///
  /// `_syncTextState` sans quoi le bouton resterait sur le micro jusqu'à la
  /// première frappe — même piège que le brouillon restauré au démarrage.
  void _remplacerTexte(String texte) {
    _controller.text = texte;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: texte.length),
    );
    _clearMentionState();
    setState(() => _syncTextState(animateMorph: false));
  }

  /// Le clavier bouge : redessiner pour que le panneau suive son retrait.
  /// L'app passe en arrière-plan pendant un vocal : on l'abandonne.
  ///
  /// Le doigt posé sur le micro, `onLongPressEnd` peut ne jamais venir — et
  /// rien d'autre n'arrêtait le micro, qui continuait d'écouter hors de
  /// l'app. Verrouillé, l'enregistrement est abandonné aussi : l'envoyer
  /// sans un dernier geste serait pire que le perdre.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive) {
      return;
    }
    _appuiMicro = false;
    if (_isRecording) {
      unawaited(_recordingService.cancelRecording());
      _resetRecordingState();
    }
  }

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
    if (_enModification) {
      // Le champ ne porte pas un brouillon mais le texte d'une modification en
      // cours : c'est celui mis de côté qu'il faut garder. Sans ça, quitter
      // l'écran en pleine modification perdait ce qu'on avait commencé à
      // écrire — la dernière sauvegarde datant d'avant.
      unawaited(PreferencesService.instance.saveMessageDraft(
        widget.conversationId,
        _brouillonMisDeCote ?? '',
      ));
    } else if (_draftSaveTimer?.isActive ?? false) {
      unawaited(PreferencesService.instance.saveMessageDraft(
        widget.conversationId,
        _controller.text,
      ));
    }
    _draftSaveTimer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    _morphController.dispose();
    if (_isRecording) {
      unawaited(_recordingService.cancelRecording());
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
        _rechercheDansLePanneau = false;
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
        widget.onSendFile(file, MessageType.file);
      }
      _controller.clear();
      setState(() => _hasText = false);
    }
  }

  // Audio recording methods
  Future<void> _startRecording() async {
    if (widget.onSendAudio == null) return;

    final hasPermission = await _recordingService.requestPermission();
    // Relâché pendant la demande — c'est le cas ordinaire au premier usage,
    // la boîte de permission fait lever le doigt : on ne démarre pas.
    if (!mounted || (hasPermission && !_appuiMicro)) return;
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
    if (path == null) return;
    // Relâché, écran quitté ou app passée en arrière-plan pendant le
    // démarrage du micro : personne n'arrêterait cet enregistrement.
    if (!mounted || !_appuiMicro) {
      await _recordingService.cancelRecording();
      return;
    }
    // `_isRecording` passe à vrai dans le même tour que le contrôle, AVANT
    // la vibration : un relâchement pendant son attente doit déjà le voir.
    setState(() {
      _isRecording = true;
      _dragOffset = 0;
      _isCancelling = false;
      _isLocked = false;
      _verticalDragOffset = 0;
    });
    await HapticFeedback.mediumImpact();
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
        unawaited(HapticFeedback.heavyImpact());
      }
    });

    // Feedback haptic quand on entre dans la zone d'annulation
    if (_isCancelling && !wasCancelling) {
      unawaited(HapticFeedback.mediumImpact());
    }

    // Feedback quand on approche du seuil de verrouillage
    if (_verticalDragOffset < -35 && !wasNearLock && !_isLocked) {
      unawaited(HapticFeedback.selectionClick());
    }
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

        // Bandeau de modification, sinon bandeau de réponse (jamais les deux :
        // entrer en modification annule la réponse en cours, côté écran).
        if (_enModification && !_isRecording)
          _buildEditPreview(context)
        else if (widget.replyToMessage != null && !_isRecording)
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
              // Pas de « + » en modification : seul le texte d'un message se
              // modifie, une pièce jointe n'aurait nulle part où aller.
              if (!_isRecording && !_enModification) ...[
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
                onRechercheOuverte: (ouverte) {
                  if (mounted && ouverte != _rechercheDansLePanneau) {
                    setState(() => _rechercheDansLePanneau = ouverte);
                  }
                },
              ),
              enRecherche: _rechercheDansLePanneau,
            ),
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
}

// Character counter threshold
const int _charCountThreshold = 200;

const int _maxCharCount = 2000;

/// Hauteur du panneau pendant une recherche : le clavier occupe déjà le bas
/// de l'écran, il ne reste que de quoi montrer le champ et une ou deux
/// rangées de résultats. Le `panneau` rabote encore si la colonne manque.
const double _hauteurPanneauEnRecherche = 240;

/// Bleu E2EE du bouton d'envoi : signale que le message part chiffré.
/// Même famille que l'accusé de lecture des bulles.
///
/// Chaque couleur signifiante garde une variante claire : elle ne sert plus
/// de second point d'arrêt de dégradé, mais de teinte pour le thème sombre,
/// où la version foncée passe mal (§6c).
const Color _kE2eeBlue = Color(0xFF2F6BE0);

const Color _kE2eeBlueLight = Color(0xFF5B9BFF);

/// Vert du bouton vocal, indépendant du thème.
const Color _kVoiceGreen = Color(0xFF009600);

const Color _kVoiceGreenLight = Color(0xFF009600);

/// Chrome de la barre flottante et du bandeau d'enregistrement.
///
/// Ces teintes viennent du Guide de style et ne se déduisent d'aucun jeton
/// de `AdaptiveColors` : elles restent codées ici, mais nommées plutôt que
/// semées en littéraux au milieu du `build`.
const Color _kBarFillDark = Color(0xFF1A1714);

const Color _kBarFillLight = Color(0xFFFFFFFF);

const Color _kBarBorderDark = Color(0xFF2A241E);

const Color _kBarBorderLight = Color(0xFFEFE7DB);

/// Bandeau d'enregistrement, thème clair uniquement (en sombre on retombe
/// sur les jetons de surface et `errorColor`).
const Color _kBannerRecordingBg = Color(0xFFFDF3EF);

const Color _kBannerRecordingBorder = Color(0xFFF0D9CE);

const Color _kBannerCancelBg = Color(0xFFFBE9E5);

const Color _kBannerCancelBorder = Color(0xFFF0C7BC);


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
