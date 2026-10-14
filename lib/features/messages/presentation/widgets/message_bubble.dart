import 'dart:async' show unawaited;
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/e2ee/undecryptable_placeholders.dart';
import '../../../../core/services/qr_code_parser.dart';
import '../../../../core/utils/mention_handle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/verification_badge.dart';
import '../../../../core/services/auto_download_service.dart';
import '../../../../core/services/file_download_service.dart';
import '../../../../shared/widgets/app_icon.dart';
import '../../../../shared/widgets/sheet_handle.dart';
import '../../domain/entities/message_entity.dart';
import '../utils/message_copy_text.dart';
import '../utils/phrase_modification.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../../../core/utils/user_color_utils.dart';
import '../../../reports/domain/entities/report_entity.dart'
    show ReportTargetType, ContentSnapshot;
import '../../../reports/presentation/widgets/report_content_modal.dart';
import '../widgets/audio_file_bubble.dart';
import 'audio_message_bubble.dart';
import '../widgets/blurhash_image.dart';
import '../widgets/data_saver_gate.dart';
import '../widgets/media_chiffre_gate.dart';
import '../utils/image_locale_ou_reseau.dart';
import '../providers/media_dechiffre_provider.dart';
import '../widgets/call_message_bubble.dart';
import '../widgets/undecryptable_message_bubble.dart';
import '../widgets/delete_message_modal.dart';
import '../widgets/full_screen_image_viewer.dart';
import '../widgets/link_preview_bubble.dart';
import '../widgets/message_info_sheet.dart';
import '../widgets/optimized_image_bubble.dart';
import '../widgets/document_bubble.dart';
import '../widgets/video_bubble.dart';
import '../screens/video_player_screen.dart';
import '../widgets/post_message_card.dart';
import '../widgets/event_message_card.dart';
import '../widgets/product_message_card.dart';
import '../widgets/location_message_bubble.dart';
import 'poll_message_bubble.dart';
import 'reaction_picker.dart';
import '../utils/accuse_de_groupe.dart';
import '../../../stickers/presentation/widgets/sticker_bubble.dart';

part 'message_bubble_contenu.dart';
part 'message_bubble_options.dart';
part 'message_bubble_actions.dart';

/// Position of a message in a group of consecutive messages from the same sender
enum MessageGroupPosition { first, middle, last, single }

class MessageBubble extends ConsumerStatefulWidget {
  final MessageEntity message;
  final bool isMe;
  final bool showSenderInfo;
  final VoidCallback? onRetry;
  final Function(String userId)? onSenderTap;
  final String? conversationId;
  final String? currentUserId;

  // Linked bubbles support
  final MessageGroupPosition groupPosition;

  // Reply support
  final MessageEntity? replyToMessage;
  final Function(MessageEntity message)? onReply;

  // Reactions support
  final Function(MessageEntity message, String emoji)? onReact;

  // Read receipts for groups
  final List<String>? readByAvatars;

  // Scroll to replied message
  final Function(String messageId)? onScrollToMessage;

  final bool isAdmin;

  /// L'expéditeur de ce message est-il admin/modérateur du groupe ?
  /// (Affiche un badge « Admin » à côté de son nom dans les bulles de groupe.)
  final bool senderIsAdmin;

  // Forward support
  final Function(MessageEntity message)? onForward;

  // Multi-selection support
  final bool isSelectionMode;
  final bool isSelected;
  final Function(MessageEntity message)? onSelect;

  // Star support
  final Function(MessageEntity message)? onToggleStar;

  // Pin support (groupes uniquement, selon les permissions du groupe)
  final bool canPin;
  final Function(MessageEntity message)? onPin;

  /// Message déjà épinglé : le menu propose « Détacher » au lieu d'« Épingler »
  /// (le bandeau d'épinglés ne porte pas de croix).
  final bool isPinned;
  final Function(MessageEntity message)? onUnpin;

  // Edit support
  /// Entrer en modification sur ce message.
  ///
  /// Ne porte plus le nouveau texte : la saisie se fait dans la barre du bas,
  /// pas dans une boîte de dialogue. La bulle ne fait qu'ouvrir le geste.
  final void Function(MessageEntity message)? onEdit;

  // Call back support (for call messages)
  final VoidCallback? onCallBack;

  // Skip animation for existing messages (performance optimization)
  final bool skipAnimation;

  // Hide read/delivered status for pending requests (sender only sees "sent")
  final bool isPendingRequest;

  // Non-null for group conversations — distingue un message reçu d'un groupe
  // (accusés, en-tête d'expéditeur) d'un message reçu en 1:1.
  final String? groupId;

  /// En groupe, les membres qui doivent avoir lu CE message pour qu'il soit
  /// « Lu » — voir `lecteursAttendus`. `null` tant que les membres ne sont pas
  /// connus : on n'affiche alors jamais « Lu », plutôt que de l'afficher trop
  /// tôt.
  final Set<String>? lecteursAttendus;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.showSenderInfo = false,
    this.onRetry,
    this.onSenderTap,
    this.conversationId,
    this.currentUserId,
    this.groupPosition = MessageGroupPosition.single,
    this.replyToMessage,
    this.onReply,
    this.onReact,
    this.readByAvatars,
    this.onScrollToMessage,
    this.isAdmin = false,
    this.senderIsAdmin = false,
    this.onForward,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onSelect,
    this.onToggleStar,
    this.canPin = false,
    this.onPin,
    this.isPinned = false,
    this.onUnpin,
    this.onEdit,
    this.onCallBack,
    this.skipAnimation = false,
    this.isPendingRequest = false,
    this.groupId,
    this.lecteursAttendus,
  });

  @override
  ConsumerState<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends ConsumerState<MessageBubble>
    with SingleTickerProviderStateMixin {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  // Swipe to reply
  double _swipeOffset = 0;
  bool _isSwipingToReply = false;

  /// Bulle elle-même (hors marges et méta) : la barre de réactions du double
  /// tap se pose au-dessus d'elle.
  final GlobalKey _bubbleKey = GlobalKey();

  /// Révélateur « Autres actions » de la feuille (§27a).
  bool _moreOptionsOpen = false;

  // Cached emoji-only check (computed once)
  late final bool _cachedIsEmojiOnly;

  // Local file path for expired media (null = not downloaded or not yet checked)
  String? _cachedLocalPath;
  bool _localPathChecked = false;

  // L'horodatage n'a plus de couleur propre : il est sorti de la bulle et se
  // lit sur le fond de la conversation, comme celui des messages reçus.
  // L'accusé de lecture bleu vit désormais dans AppColors.readReceiptBlue.

  /// Décoration opaque de la bulle (remplace le glassmorphism).
  BoxDecoration _bubbleDecoration(BuildContext context) {
    final isDark = context.isDarkMode;
    final Color bubbleColor =
        widget.isMe
            ? (isDark ? _kSentBubbleDark : _kSentBubbleLight)
            : (isDark ? _kRecvBubbleDark : _kRecvBubbleLight);
    return BoxDecoration(
      color: bubbleColor,
      borderRadius: _getBorderRadius(),
      // Bordure uniquement sur les bulles reçues (les envoyées sont pleines).
      // Pas d'ombre : la bulle est enveloppée d'un ClipRRect qui la rognerait
      // de toute façon — la définition vient de la bordure et du contraste.
      border:
          widget.isMe
              ? null
              // En nocturne, la bordure de thème (#2A241E) disparaît sur une
              // bulle #252119 : la fiche 6b nomme #3D352C pour ce rôle.
              : Border.all(
                color: isDark ? AppColors.bubbleBorderDark : context.borderColor,
                width: 1,
              ),
    );
  }

  /// Message reçu (pas de moi) dans une discussion de groupe : la colonne
  /// avatar doit rester réservée même quand elle n'affiche rien (voir
  /// `_isGroupReceived` ci-dessous, sur le calcul du padding gauche).
  bool get _isGroupReceived => !widget.isMe && widget.groupId != null;

  @override
  void initState() {
    super.initState();

    // Cache emoji-only check to avoid repeated regex evaluation
    _cachedIsEmojiOnly = _computeIsEmojiOnly();

    // Fire-and-forget: save media locally before the 15-day TTL expires
    unawaited(AutoDownloadService().tryDownload(widget.message));

    // For expired media, check synchronously whether a local copy exists
    if (widget.message.mediaExpired) {
      unawaited(_checkLocalPath());
    }

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    // Modern bouncy animation for message entry
    _slideAnimation = Tween<double>(
      begin: widget.isMe ? 40 : -40,
      end: 0,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCirc),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutQuart),
    );

    // Only animate new messages, skip for existing ones (performance)
    if (widget.skipAnimation) {
      _animationController.value = 1.0;
    } else {
      unawaited(_animationController.forward());
    }
  }

  /// Compute emoji-only status once and cache it
  bool _computeIsEmojiOnly() {
    if (widget.message.type != MessageType.text) return false;
    if (widget.message.deletedForEveryone) return false;
    if (widget.replyToMessage != null) return false;
    return _isEmojiOnly(widget.message.content);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  BorderRadius _getBorderRadius() {
    // Rayons 18 avec coin de queue 6 (cf. handoff Discussion).
    const double largeRadius = 18;
    const double smallRadius = 6;
    const double tinyRadius = 6;

    switch (widget.groupPosition) {
      case MessageGroupPosition.first:
        return BorderRadius.only(
          topLeft: const Radius.circular(largeRadius),
          topRight: const Radius.circular(largeRadius),
          bottomLeft: Radius.circular(widget.isMe ? largeRadius : smallRadius),
          bottomRight: Radius.circular(widget.isMe ? smallRadius : largeRadius),
        );
      case MessageGroupPosition.middle:
        return BorderRadius.only(
          topLeft: Radius.circular(widget.isMe ? largeRadius : smallRadius),
          topRight: Radius.circular(widget.isMe ? smallRadius : largeRadius),
          bottomLeft: Radius.circular(widget.isMe ? largeRadius : smallRadius),
          bottomRight: Radius.circular(widget.isMe ? smallRadius : largeRadius),
        );
      case MessageGroupPosition.last:
        return BorderRadius.only(
          topLeft: Radius.circular(widget.isMe ? largeRadius : smallRadius),
          topRight: Radius.circular(widget.isMe ? smallRadius : largeRadius),
          bottomLeft: Radius.circular(widget.isMe ? largeRadius : tinyRadius),
          bottomRight: Radius.circular(widget.isMe ? tinyRadius : largeRadius),
        );
      case MessageGroupPosition.single:
        return BorderRadius.only(
          topLeft: const Radius.circular(largeRadius),
          topRight: const Radius.circular(largeRadius),
          bottomLeft: Radius.circular(widget.isMe ? largeRadius : tinyRadius),
          bottomRight: Radius.circular(widget.isMe ? tinyRadius : largeRadius),
        );
    }
  }

  double _getVerticalPadding() {
    switch (widget.groupPosition) {
      case MessageGroupPosition.first:
        return 4;
      case MessageGroupPosition.middle:
        return 2;
      case MessageGroupPosition.last:
        return 4;
      case MessageGroupPosition.single:
        return 8;
    }
  }

  /// Check if the message contains only emojis
  bool _isEmojiOnly(String text) {
    if (text.isEmpty) return false;
    // Regex to match emojis
    final emojiRegex = RegExp(
      r'^[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\u{1F600}-\u{1F64F}\u{1F680}-\u{1F6FF}\u{1F1E0}-\u{1F1FF}\u{200D}\u{FE0F}\u{20E3}\s]+$',
      unicode: true,
    );
    return emojiRegex.hasMatch(text.trim()) && text.trim().length <= 12;
  }

  /// Check if message is emoji-only text (for bubble-less display)
  /// Uses cached value for performance
  bool _isEmojiOnlyTextMessage() {
    return _cachedIsEmojiOnly;
  }

  /// Build emoji-only content without bubble
  Widget _buildEmojiOnlyContent(BuildContext context) {
    return GestureDetector(
      key: _bubbleKey,
      onLongPress: _onLongPress,
      onDoubleTap: _onDoubleTap,
      child: Column(
        crossAxisAlignment:
            widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sender name for groups
          if (widget.showSenderInfo && !widget.isMe)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: InkWell(
                onTap: () => widget.onSenderTap?.call(widget.message.senderId),
                child: Text(
                  widget.message.senderName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: UserColorUtils.getUserColor(widget.message.senderId),
                  ),
                ),
              ),
            ),
          // Large emoji
          Text(widget.message.content, style: const TextStyle(fontSize: 42)),
          // L'heure et l'accusé de réception sont posés par _buildMetaRow,
          // en dessous : ce bloc ne les réaffiche pas.
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // System messages get special treatment - no bubble, no gestures
    if (widget.message.isSystem) {
      return Center(child: _buildSystemMessageContent(context));
    }

    // Call messages get special treatment - aligned based on direction, no swipe gestures
    if (widget.message.isCall) {
      return CallMessageBubble(
        message: widget.message,
        isMe: widget.isMe,
        currentUserId: widget.currentUserId ?? '',
        onCallBack: widget.onCallBack,
      );
    }

    // Check if message is deleted for the current user
    final isDeleted =
        widget.currentUserId != null &&
        widget.message.isDeletedFor(widget.currentUserId!);

    // Don't show messages that are deleted for the current user
    if (isDeleted && !widget.message.deletedForEveryone) {
      return const SizedBox.shrink();
    }

    // Selection mode: wrap with tap-to-select and show checkbox
    if (widget.isSelectionMode) {
      // L'appui long coche lui aussi : c'est le geste qui a ouvert le mode,
      // le refaire sur le message suivant doit l'ajouter, pas rouvrir un
      // menu par-dessus la barre de sélection.
      return GestureDetector(
        onTap: () => widget.onSelect?.call(widget.message),
        onLongPress: () => widget.onSelect?.call(widget.message),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          color:
              widget.isSelected
                  ? context.adaptivePrimaryColor.withValues(alpha: 0.15)
                  : Colors.transparent,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, animation) {
                    return ScaleTransition(scale: animation, child: child);
                  },
                  child: Icon(
                    widget.isSelected
                        ? Icons.check_circle
                        : Icons.circle_outlined,
                    key: ValueKey(widget.isSelected),
                    size: 24,
                    color:
                        widget.isSelected
                            ? context.adaptivePrimaryColor
                            : context.textTertiaryColor,
                  ),
                ),
              ),
              // En sélection, le contenu ne reçoit plus aucun pointeur : il
              // garde sinon TOUS ses gestes, et le plus profond gagne le tap.
              // Toucher un sondage votait au lieu de cocher — et de la même
              // façon une image s'ouvrait, un lien partait au navigateur, un
              // envoi échoué se relançait, un double-appui posait une
              // réaction, un glissement passait en réponse. Le tap remonte
              // maintenant au `GestureDetector` ci-dessus, partout sur la
              // ligne.
              Expanded(
                child: AbsorbPointer(
                  child: _buildMainContent(context, isDeleted),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _buildMainContent(context, isDeleted);
  }

  // La pastille bleue « lu » a disparu avec les coches : elle doublait
  // l'information que le libellé « Lu » porte désormais en clair.

  void _onSwipeStart(DragStartDetails details) {
    setState(() {
      _isSwipingToReply = true;
    });
  }

  void _onSwipeUpdate(DragUpdateDetails details) {
    final newOffset = _swipeOffset + details.delta.dx;

    // Only allow swipe in the correct direction, borné à 90 px.
    if (widget.isMe) {
      // Swipe left for "isMe" messages
      if (newOffset <= 0 && newOffset >= -90) {
        setState(() {
          _swipeOffset = newOffset;
        });
      }
    } else {
      // Swipe right for other's messages
      if (newOffset >= 0 && newOffset <= 90) {
        setState(() {
          _swipeOffset = newOffset;
        });
      }
    }

    // Haptic feedback au franchissement du seuil (52 px).
    if (_swipeOffset.abs() > 52 && _swipeOffset.abs() < 57) {
      unawaited(HapticFeedback.lightImpact());
    }
  }

  void _onSwipeEnd(DragEndDetails details) {
    if (_swipeOffset.abs() > 52) {
      // Trigger reply
      unawaited(HapticFeedback.mediumImpact());
      widget.onReply?.call(widget.message);
    }

    setState(() {
      _swipeOffset = 0;
      _isSwipingToReply = false;
    });
  }


  Widget _buildExpiredMediaPlaceholder(BuildContext context) {
    // _cachedLocalPath is set by _checkLocalPath() called in initState.
    // Shows ghost immediately, then switches to local media with a single
    // setState — no FutureBuilder re-build cycle, no null assertion needed.
    if (_localPathChecked && _cachedLocalPath != null) {
      return _buildLocalMediaWidget(_cachedLocalPath!);
    }
    return _buildExpiredGhost();
  }

  Future<void> _checkLocalPath() async {
    final path = await FileDownloadService().getDownloadedPath(
      widget.message.id,
    );
    if (!mounted) return;
    setState(() {
      _cachedLocalPath =
          (path != null && File(path).existsSync()) ? path : null;
      _localPathChecked = true;
    });
  }
}

// ── Bulles opaques (refonte Discussion — contraste AA) ────────────────────
/// Bulle envoyée : `#009600` (clair) / `#009600` (sombre).
const Color _kSentBubbleLight = Color(0xFF009600);

const Color _kSentBubbleDark = Color(0xFF009600);

/// Bulle reçue : `#FFFFFF` (clair) / `#252119` (sombre).
const Color _kRecvBubbleLight = Color(0xFFFFFFFF);

const Color _kRecvBubbleDark = Color(0xFF252119);

// Bordure de bulle reçue : c'est la bordure du thème, pas une valeur à
// part. Elle était figée à `#EFE7DB` / `#3D352C` — le clair était déjà
// celui du guide de style, le sombre a depuis été resserré à `#2A241E`.

// Greyscale + alpha-reduced color matrix for expired media ghost effect
const ColorFilter _greyFilter = ColorFilter.matrix([
  0.2126,
  0.7152,
  0.0722,
  0,
  0,
  0.2126,
  0.7152,
  0.0722,
  0,
  0,
  0.2126,
  0.7152,
  0.0722,
  0,
  0,
  0,
  0,
  0,
  0.55,
  0,
]);

final _urlRegex = RegExp(
  r'(?:https?://|www\.)[^\s<>\]\)]+|(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+(?:com|fr|org|net|io|co|app|dev|info|biz|edu|gov|me|tv|uk|de|nl|be|ch|ca|au|nz|ng|sn|ml|bf|ci|tg|bj|ne|gn|cm|cd|cg|ga|td|cf|rw|bi|ug|ke|tz|et|gh|za|ma|dz|tn|eg|ly|sd|mu|mg|mw|zm|zw|mz|ao|na|bw|sz|ls|so|dj|er|ss)(?:/[^\s<>\]\)]*)?',
  caseSensitive: false,
);

// Phone number regex supporting international and African formats
// +227 XX XX XX XX, 00227 XX XX XX XX, 227 XX XX XX XX, local formats
final _phoneRegex = RegExp(
  r'(?:\+|00)?(?:227|226|225|224|223|222|221|220|234|233|231|230|229|228|237|236|235|241|240|243|242|244|245|250|251|252|253|254|255|256|257|258|260|261|262|263|264|265|266|267|268|269|27|20|212|213|216|218|1|33|44|49|34|39|31|32|41)?[-.\s]?\(?\d{2,3}\)?[-.\s]?\d{2}[-.\s]?\d{2}[-.\s]?\d{2}[-.\s]?\d{0,2}',
);

// Email regex
final _emailRegex = RegExp(
  r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
  caseSensitive: false,
);

// Rich text formatting regex: *bold*, _italic_, ~strikethrough~, `code`
//
// Les délimiteurs doivent être ISOLÉS (rien d'alphanumérique juste avant ni
// juste après) et encadrer du contenu qui ne commence ni ne finit par une
// espace. Sans ces gardes, le marqueur était reconnu au MILIEU d'un mot et
// supprimé de l'affichage : `taux_change_2026` perdait ses tirets bas et
// passait en italique, `5*4*3` perdait ses astérisques. Même règle que
// WhatsApp et Signal.
final _richTextRegex = RegExp(
  r'(?<![\w*_~`])'
  r'(?:'
  r'\*(?=\S)[^*\n]*[^*\s]\*'
  r'|_(?=\S)[^_\n]*[^_\s]_'
  r'|~(?=\S)[^~\n]*[^~\s]~'
  r'|`(?=\S)[^`\n]*[^`\s]`'
  r')'
  r'(?![\w*_~`])',
);


/// Type of detected link in message content
enum _LinkType { url, phone, email, mention }

/// Represents a detected link in message content
class _LinkMatch {
  final int start;
  final int end;
  final String text;
  final _LinkType type;

  const _LinkMatch({
    required this.start,
    required this.end,
    required this.text,
    required this.type,
  });
}
