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

  // ── Bulles opaques (refonte Discussion — contraste AA) ────────────────────
  /// Bulle envoyée : `#009600` (clair) / `#009600` (sombre).
  static const Color _kSentBubbleLight = Color(0xFF009600);
  static const Color _kSentBubbleDark = Color(0xFF009600);

  /// Bulle reçue : `#FFFFFF` (clair) / `#252119` (sombre).
  static const Color _kRecvBubbleLight = Color(0xFFFFFFFF);
  static const Color _kRecvBubbleDark = Color(0xFF252119);

  // Bordure de bulle reçue : c'est la bordure du thème, pas une valeur à
  // part. Elle était figée à `#EFE7DB` / `#3D352C` — le clair était déjà
  // celui du guide de style, le sombre a depuis été resserré à `#2A241E`.

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

  Widget _buildMainContent(BuildContext context, bool isDeleted) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_slideAnimation.value, 0),
          child: Opacity(opacity: _fadeAnimation.value, child: child),
        );
      },
      child: GestureDetector(
        onHorizontalDragStart: widget.onReply != null ? _onSwipeStart : null,
        onHorizontalDragUpdate: widget.onReply != null ? _onSwipeUpdate : null,
        onHorizontalDragEnd: widget.onReply != null ? _onSwipeEnd : null,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Reply indicator
            if (_isSwipingToReply)
              Positioned(
                left: widget.isMe ? 16 : null,
                right: widget.isMe ? null : 16,
                top: 0,
                bottom: 0,
                child: Center(
                  child: AnimatedOpacity(
                    opacity: _swipeOffset.abs() > 52 ? 1 : 0.5,
                    duration: const Duration(milliseconds: 100),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: context.adaptivePrimaryColor.withValues(
                          alpha: 0.2,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.reply,
                        size: 20,
                        color: context.adaptivePrimaryColor,
                      ),
                    ),
                  ),
                ),
              ),

            // Message content
            Transform.translate(
              offset: Offset(_swipeOffset, 0),
              child: Padding(
                padding: EdgeInsets.only(
                  left: widget.isMe ? 64 : (_isGroupReceived ? 8 : 16),
                  right: widget.isMe ? 16 : 64,
                  top: _getVerticalPadding(),
                  bottom: _getVerticalPadding(),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Colonne avatar des messages de groupe (non-moi) : réservée
                    // sur TOUS les messages reçus d'un groupe, pas seulement le
                    // premier d'une série — sinon la bulle des messages suivants
                    // saute de 28px vers la gauche faute d'avatar à afficher, et
                    // la série ne reste plus alignée verticalement.
                    if (_isGroupReceived)
                      Padding(
                        padding: const EdgeInsets.only(right: 8, bottom: 2),
                        child:
                            widget.showSenderInfo
                                ? GestureDetector(
                                  onTap:
                                      () => widget.onSenderTap?.call(
                                        widget.message.senderId,
                                      ),
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      CircleAvatar(
                                        radius: 14,
                                        backgroundColor:
                                            UserColorUtils.getUserColor(
                                              widget.message.senderId,
                                            ),
                                        backgroundImage:
                                            widget.message.senderPhotoUrl !=
                                                    null
                                                ? CachedNetworkImageProvider(
                                                  widget
                                                      .message
                                                      .senderPhotoUrl!,
                                                )
                                                : null,
                                        child:
                                            widget.message.senderPhotoUrl ==
                                                    null
                                                ? Text(
                                                  widget
                                                          .message
                                                          .senderName
                                                          .isNotEmpty
                                                      ? widget
                                                          .message
                                                          .senderName[0]
                                                          .toUpperCase()
                                                      : '?',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight:
                                                        FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                )
                                                : null,
                                      ),
                                      if (widget.message.senderIsVerified)
                                        const Positioned(
                                          bottom: -2,
                                          right: -2,
                                          child: VerificationBadge(
                                            size: VerificationBadgeSize.small,
                                          ),
                                        ),
                                    ],
                                  ),
                                )
                                // Pas premier d'une série : pas d'avatar, mais
                                // la même largeur pour garder l'alignement.
                                : const SizedBox(width: 28),
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            widget.isMe
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                        children: [
                          // Check if this is an emoji-only text message (no bubble)
                          _isEmojiOnlyTextMessage()
                              ? _buildEmojiOnlyContent(context)
                              : GestureDetector(
                                key: _bubbleKey,
                                onLongPress: _onLongPress,
                                onDoubleTap: _onDoubleTap,
                                child: ClipRRect(
                                  borderRadius: _getBorderRadius(),
                                  child: Container(
                                    // Surface opaque : plus de BackdropFilter ni
                                    // de dégradé (coûteux sur entrée de gamme) —
                                    // contraste texte AA garanti.
                                    decoration: _bubbleDecoration(context),
                                    child: GestureDetector(
                                      onTap:
                                          widget.message.status ==
                                                      MessageStatus.failed &&
                                                  widget.onRetry != null
                                              ? widget.onRetry
                                              : null,
                                      child: ClipRRect(
                                        borderRadius: _getBorderRadius(),
                                        child: _buildBubbleColumn(context),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                          // Heure, accusé de réception et réactions : SOUS la
                          // bulle, jamais dedans (fiches 4a/6b). C'est la
                          // seule ligne de méta de la discussion, quel que
                          // soit le type de message.
                          _buildMetaRow(context),

                          // Read avatars for groups
                          if (widget.readByAvatars?.isNotEmpty == true &&
                              widget.isMe)
                            _buildReadAvatars(context),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Une bulle qui porte une citation ne descend jamais sous cette largeur.
  ///
  /// Sans elle, une réponse courte à un message court donne un bloc plus haut
  /// que large : la citation, le texte et rien d'autre, empilés dans une
  /// colonne de la largeur du plus court des trois. La citation s'y lit comme
  /// une étiquette posée à côté du message, plus comme le message cité.
  ///
  /// La contrainte est un plancher, jamais un plafond : `ConstrainedBox`
  /// applique `enforce()` sur les contraintes du parent, donc une largeur
  /// minimale plus grande que la place disponible est ramenée à cette place.
  double _largeurMinCitation(BuildContext context) {
    final largeur = MediaQuery.sizeOf(context).width * 0.58;
    return largeur > 260 ? 260 : largeur;
  }

  /// La citation ne peut s'étirer que si la largeur intrinsèque du contenu
  /// est calculable — voir `_buildBubbleColumn`.
  ///
  /// `AudioMessageBubble` et `AudioFileBubble` contiennent un `LayoutBuilder`,
  /// qui **lève** quand on lui demande une dimension intrinsèque au lieu de se
  /// dégrader. Une bulle média est large de toute façon : c'est la bulle de
  /// texte, elle seule, qui se repliait en colonne.
  bool get _citationEtirable {
    if (widget.replyToMessage == null) return false;
    if (_bulleVidee) return true;
    if (widget.message.type != MessageType.text) return false;
    return widget.message.postData == null &&
        widget.message.productData == null &&
        widget.message.eventData == null &&
        widget.message.linkPreviewData == null;
  }

  /// Colonne interne de la bulle : étiquette de transfert, nom de
  /// l'expéditeur, citation, puis contenu.
  ///
  /// Quand le message répond à un autre, la citation s'étire sur toute la
  /// largeur de la bulle — c'est ce qui la fait lire comme un bandeau. Le
  /// détour par `IntrinsicWidth` n'est pas évitable : un `Column` se
  /// dimensionne sur son enfant le plus large, donc `CrossAxisAlignment
  /// .stretch` seul ferait prendre à **chaque** bulle toute la largeur
  /// disponible. `IntrinsicWidth` mesure d'abord, `stretch` remplit ensuite
  /// la largeur mesurée — une passe de mise en page de plus, bornée aux
  /// bulles de texte qui citent.
  Widget _buildBubbleColumn(BuildContext context) {
    final colonne = Column(
      crossAxisAlignment:
          _citationEtirable
              ? CrossAxisAlignment.stretch
              : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Forwarded label
        if (widget.message.isForwarded)
          Padding(
            padding: const EdgeInsets.only(left: 12, right: 12, top: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.flip(
                  flipX: true,
                  child: Icon(
                    Icons.reply,
                    size: 16,
                    color:
                        widget.isMe
                            ? AppColors.white.withValues(alpha: 0.6)
                            : context.textTertiaryColor.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  AppLocalizations.of(context)!.forwarded,
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color:
                        widget.isMe
                            ? AppColors.white.withValues(alpha: 0.6)
                            : context.textTertiaryColor.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        // Sender name inside bubble for groups
        if (widget.showSenderInfo && !widget.isMe)
          Padding(
            padding: const EdgeInsets.only(left: 12, right: 12, top: 8),
            child: InkWell(
              onTap: () => widget.onSenderTap?.call(widget.message.senderId),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.message.senderName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: UserColorUtils.getUserColor(
                        widget.message.senderId,
                      ),
                    ),
                  ),
                  if (widget.message.senderIsVerified) ...[
                    const SizedBox(width: 4),
                    const VerificationBadge(size: VerificationBadgeSize.small),
                  ],
                  if (widget.senderIsAdmin) ...[
                    const SizedBox(width: 6),
                    _buildAdminBadge(context),
                  ],
                ],
              ),
            ),
          ),
        // Reply preview
        if (widget.replyToMessage != null) _buildReplyPreview(context),

        // Message content
        _bulleVidee ? _buildDeletedContent(context) : _buildContent(context),
      ],
    );

    if (widget.replyToMessage == null) return colonne;

    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: _largeurMinCitation(context)),
      child: _citationEtirable ? IntrinsicWidth(child: colonne) : colonne,
    );
  }

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


  /// Réaction déjà posée par l'utilisateur courant, s'il y en a une.
  String? get _myReaction => widget.currentUserId != null
      ? widget.message.myReaction(widget.currentUserId!)
      : null;

  /// Rangée de réactions rapides de la feuille d'actions (§27a) : les cinq
  /// de [kQuickReactions], le « + » ouvre le sélecteur complet.
  Widget _buildQuickReactions(BuildContext sheetContext) {
    return QuickReactionRow(
      selected: _myReaction,
      onPick: (emoji) {
        Navigator.pop(sheetContext);
        unawaited(HapticFeedback.lightImpact());
        widget.onReact?.call(widget.message, emoji);
      },
      onMore: () async {
        Navigator.pop(sheetContext);
        final emoji = await showFullReactionPicker(context);
        if (emoji != null && mounted) {
          widget.onReact?.call(widget.message, emoji);
        }
      },
    );
  }

  void _onLongPress() {
    unawaited(HapticFeedback.mediumImpact());
    // Unfocus any text field to prevent keyboard from appearing after modal closes
    FocusScope.of(context).unfocus();
    _showOptionsModal(context);
  }

  /// Double tap : la barre des cinq réactions et son « + », posée sur la
  /// bulle — plus de cœur imposé d'office.
  Future<void> _onDoubleTap() async {
    if (widget.onReact == null) return;
    final box =
        (_bubbleKey.currentContext ?? context).findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final anchor = box.localToGlobal(Offset.zero) & box.size;

    final emoji = await showReactionBar(
      context,
      anchor: anchor,
      selected: _myReaction,
    );
    if (emoji != null && mounted) {
      widget.onReact?.call(widget.message, emoji);
    }
  }

  /// Chips de réaction, posés sur la même ligne que l'heure (fiche 6b).
  ///
  /// `reactions` est userId -> emoji (une par personne) ; les chips
  /// regroupent par emoji pour l'affichage du compte.
  List<Widget> _buildReactionChips(
    BuildContext context,
    Map<String, String> reactions,
  ) {
    final myReaction = widget.currentUserId != null
        ? reactions[widget.currentUserId!]
        : null;
    final reactionCounts = <String, int>{};
    for (final emoji in reactions.values) {
      reactionCounts[emoji] = (reactionCounts[emoji] ?? 0) + 1;
    }

    return reactionCounts.entries.map((entry) {
      final isMine = entry.key == myReaction;
      // Re-tap sur sa propre réaction = toggle → la retire.
      return GestureDetector(
        onTap:
            widget.onReact == null
                ? null
                : () {
                  unawaited(HapticFeedback.lightImpact());
                  widget.onReact?.call(widget.message, entry.key);
                },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isMine
                ? context.adaptivePrimaryColor.withValues(alpha: 0.12)
                : context.surfaceVariantColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isMine
                  ? context.adaptivePrimaryColor.withValues(alpha: 0.6)
                  : context.outlineColor.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(entry.key, style: const TextStyle(fontSize: 14)),
              if (entry.value > 1) ...[
                const SizedBox(width: 4),
                Text(
                  '${entry.value}',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.textSecondaryColor,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }).toList();
  }

  /// Petit badge « Admin » affiché à côté du nom de l'expéditeur (groupes).
  Widget _buildAdminBadge(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: context.adaptivePrimaryColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(AppIcon.star, size: 9, color: context.adaptivePrimaryColor),
          const SizedBox(width: 3),
          Text(
            l10n.adminRoleLabel,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: context.adaptivePrimaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadAvatars(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, right: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children:
            (widget.readByAvatars ?? const []).take(3).map((avatarUrl) {
              return Container(
                margin: const EdgeInsets.only(left: 2),
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: context.surfaceColor, width: 1),
                  image:
                      avatarUrl.isNotEmpty
                          ? DecorationImage(
                            image: NetworkImage(avatarUrl),
                            fit: BoxFit.cover,
                          )
                          : null,
                  color:
                      avatarUrl.isEmpty
                          ? context.adaptivePrimaryColor.withValues(alpha: 0.3)
                          : null,
                ),
                child:
                    avatarUrl.isEmpty
                        ? AppIcon(
                          AppIcon.person,
                          size: 10,
                          color: context.adaptivePrimaryColor,
                        )
                        : null,
              );
            }).toList(),
      ),
    );
  }

  bool _canShowDeleteOption() {
    return widget.conversationId != null &&
        widget.currentUserId != null &&
        !widget.message.deletedForEveryone &&
        widget.message.status != MessageStatus.sending;
  }

  /// Ouvre la feuille d'actions (§27a).
  ///
  /// Les entrées courantes visibles, les autres derrière « Autres
  /// actions » : la maquette impose la brièveté, mais épingler, modifier,
  /// enregistrer et signaler restent des fonctions réelles qu'on ne fait pas
  /// disparaître.
  void _showOptionsModal(BuildContext context) {
    _moreOptionsOpen = false;
    unawaited(showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (_, setSheetState) {
          final secondaires = _secondaryOptionRows(ctx);
          // `Material` et non `Container` : les `ListTile` peignent leur onde
          // d'appui sur le Material le plus proche. Avec un fond opaque posé
          // entre eux et celui de la feuille, l'onde était peinte DERRIÈRE —
          // aucun retour au toucher sur douze entrées. Flutter 3.29 lève même
          // une assertion dessus en debug.
          return Material(
            color: context.surfaceColor,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20),
            ),
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SheetHandle(),
                  const SizedBox(height: 16),

                  // Réactions rapides : cinq émojis d'un geste, le « + »
                  // ouvre le sélecteur complet. Remplace l'ancienne ligne
                  // « Réagir », qui demandait un écran de plus.
                  if (widget.onReact != null) ...[
                    _buildQuickReactions(ctx),
                    const SizedBox(height: 8),
                    Divider(height: 1, color: context.dividerColor),
                    const SizedBox(height: 8),
                  ] else
                    const SizedBox(height: 4),

                  ..._primaryOptionRows(ctx),

                  if (secondaires.isNotEmpty) ...[
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: context.borderColor,
                    ),
                    if (!_moreOptionsOpen)
                      ListTile(
                        leading: Icon(
                          Icons.more_horiz,
                          color: context.textSecondaryColor,
                        ),
                        title: Text(
                          AppLocalizations.of(context)!.moreActions,
                          style: TextStyle(color: context.textSecondaryColor),
                        ),
                        onTap: () =>
                            setSheetState(() => _moreOptionsOpen = true),
                      )
                    else
                      ...secondaires,
                  ],

                  SizedBox(height: MediaQuery.of(ctx).padding.bottom),
                ],
              ),
            ),
          );
        },
      ),
    ));
  }

  /// Les actions du message, rangées par INTENTION.
  ///
  /// L'ordre d'avant était celui de la maquette puis des ajouts successifs :
  /// les gestes se retrouvaient mêlés, et le révélateur « Autres actions »
  /// gardait des choses qu'on cherche souvent. Quatre intentions, dans cet
  /// ordre :
  ///
  /// 1. **agir sur ce message** — Répondre, Modifier ;
  /// 2. **emporter son contenu** — Copier, Enregistrer, Transférer ;
  /// 3. **le ranger** — Favoris, Épingler, Sélectionner ;
  /// 4. **isolé par un filet** — Signaler / Supprimer.
  ///
  /// Ce qui est remonté du révélateur, et pourquoi :
  ///
  /// - **Enregistrer** : sur un média, c'est LE geste ; il demandait deux
  ///   étapes de plus ;
  /// - **Signaler** : c'est le recours d'une personne harcelée. Le
  ///   commentaire de l'entrée disait déjà « il ne disparaît pas d'un
  ///   écran » — il était pourtant caché. On a suivi l'intention écrite ;
  /// - **Épingler** : `canPin` est déjà restrictif, donc quand l'entrée
  ///   existe, elle est voulue ;
  /// - **Modifier** : action courante sur son propre message, dans la fenêtre
  ///   de [MessageEntity.fenetreModification] ; elle était en DERNIÈRE
  ///   position de la section repliée. Hors fenêtre elle reste VISIBLE mais
  ///   désactivée, avec le motif en sous-titre : la faire disparaître donnait
  ///   à croire à un bug de l'application ;
  /// - **Sélectionner** : seul chemin vers la multi-sélection — un appui
  ///   simple ne coche que si le mode est déjà entré.
  List<Widget> _primaryOptionRows(BuildContext ctx) {
    final l10n = AppLocalizations.of(context)!;
    return [
      if (widget.onReply != null)
        ListTile(
          leading: Icon(Icons.reply, color: context.textPrimaryColor),
          title: Text(
            l10n.reply,
            style: TextStyle(color: context.textPrimaryColor),
          ),
          onTap: () {
            Navigator.pop(ctx);
            widget.onReply?.call(widget.message);
          },
        ),

      if (widget.isMe &&
          widget.message.type == MessageType.text &&
          !widget.message.deletedForEveryone &&
          widget.onEdit != null &&
          widget.currentUserId != null)
        _entreeModifier(ctx, l10n),

      // Texte, légende de photo/vidéo, adresse d'une position, question d'un
      // sondage : la règle vit dans `messageCopyText`.
      if (messageCopyText(widget.message) case final texte?)
        ListTile(
          leading: Icon(Icons.copy, color: context.textPrimaryColor),
          title: Text(
            l10n.copy,
            style: TextStyle(color: context.textPrimaryColor),
          ),
          onTap: () {
            Navigator.pop(ctx);
            _copyToClipboard(texte);
          },
        ),

      if (!widget.message.deletedForEveryone &&
          widget.message.fileUrl != null &&
          (widget.message.type == MessageType.image ||
              widget.message.type == MessageType.video))
        ListTile(
          leading: Icon(
            Icons.download_rounded,
            color: context.textPrimaryColor,
          ),
          title: Text(
            l10n.save,
            style: TextStyle(color: context.textPrimaryColor),
          ),
          onTap: () {
            Navigator.pop(ctx);
            if (widget.message.type == MessageType.image) {
              unawaited(_saveImageToGallery(widget.message.fileUrl!));
            } else {
              unawaited(_saveVideoToDevice(widget.message.fileUrl!));
            }
          },
        ),

      if (!widget.message.deletedForEveryone)
        ListTile(
          leading: Icon(Icons.shortcut, color: context.textPrimaryColor),
          title: Text(
            l10n.forwardTo,
            style: TextStyle(color: context.textPrimaryColor),
          ),
          onTap: () {
            Navigator.pop(ctx);
            widget.onForward?.call(widget.message);
          },
        ),

      if (widget.onToggleStar != null && !widget.message.deletedForEveryone)
        Builder(
          builder: (_) {
            final isStarred = widget.currentUserId != null &&
                widget.message.isStarredBy(widget.currentUserId!);
            return ListTile(
              leading: isStarred
                  ? const AppIcon(AppIcon.star, color: Colors.amber)
                  : AppIcon(
                      AppIcon.starBorder,
                      color: context.textPrimaryColor,
                    ),
              title: Text(
                isStarred ? l10n.unstarMessage : l10n.starMessage,
                style: TextStyle(color: context.textPrimaryColor),
              ),
              onTap: () {
                Navigator.pop(ctx);
                widget.onToggleStar?.call(widget.message);
              },
            );
          },
        ),

      if (widget.canPin && !widget.message.deletedForEveryone)
        if (widget.isPinned && widget.onUnpin != null)
          ListTile(
            leading: AppIcon(
              AppIcon.pin,
              size: 20,
              color: context.textPrimaryColor,
            ),
            title: Text(
              l10n.unpin,
              style: TextStyle(color: context.textPrimaryColor),
            ),
            onTap: () {
              Navigator.pop(ctx);
              widget.onUnpin?.call(widget.message);
            },
          )
        else if (!widget.isPinned && widget.onPin != null)
          ListTile(
            leading: AppIcon(
              AppIcon.pin,
              size: 20,
              color: context.textPrimaryColor,
            ),
            title: Text(
              l10n.pin,
              style: TextStyle(color: context.textPrimaryColor),
            ),
            onTap: () {
              Navigator.pop(ctx);
              widget.onPin?.call(widget.message);
            },
          ),

      // Entrer en sélection multiple depuis le message pressé : c'est le SEUL
      // chemin vers la sélection — un simple appui sur une bulle ne coche que
      // si le mode est déjà entré.
      if (widget.onSelect != null)
        ListTile(
          leading: AppIcon(
            AppIcon.checkCircle,
            color: context.textPrimaryColor,
          ),
          title: Text(
            l10n.select,
            style: TextStyle(color: context.textPrimaryColor),
          ),
          onTap: () {
            Navigator.pop(ctx);
            widget.onSelect?.call(widget.message);
          },
        ),

      // Signaler reste accessible : c'est le recours d'une personne
      // harcelée, il ne disparaît pas d'un écran.
      if (!widget.isMe && !widget.message.deletedForEveryone)
        ListTile(
          leading: AppIcon(AppIcon.flag, color: context.warningColor),
          title: Text(
            l10n.report,
            style: TextStyle(color: context.warningColor),
          ),
          onTap: () {
            Navigator.pop(ctx);
            final snapshot = _createMessageSnapshot();
            unawaited(ReportContentModal.show(
              context,
              targetType: ReportTargetType.message,
              targetId: widget.message.id,
              targetName: widget.message.senderName,
              targetPreview: widget.message.type == MessageType.text
                  ? widget.message.content
                  : null,
              conversationId: widget.conversationId,
              contentSnapshot: snapshot,
              reportedUserId: widget.message.senderId,
            ));
          },
        ),

      // Action destructive isolée par un filet.
      if (_canShowDeleteOption()) ...[
        Divider(
          height: 1,
          indent: 16,
          endIndent: 16,
          color: context.borderColor,
        ),
        ListTile(
          leading: AppIcon(AppIcon.delete, color: context.errorColor),
          title: Text(
            l10n.delete,
            style: TextStyle(color: context.errorColor),
          ),
          onTap: () {
            Navigator.pop(ctx);
            _showDeleteModal(context);
          },
        ),
      ],];
  }

  /// Ce qu'on ne cherche qu'exceptionnellement.
  ///
  /// Le révélateur ne garde plus que ça : copier une partie du texte,
  /// partager HORS de l'app (« Transférer » couvre l'intérieur, qui est le
  /// cas courant), et consulter les détails techniques d'un message.
  List<Widget> _secondaryOptionRows(BuildContext ctx) {
    final l10n = AppLocalizations.of(context)!;
    return [

      // Copier une partie seulement : un numéro, un lien, une phrase. La bulle
      // n'est pas sélectionnable (l'appui long y ouvre ce menu).
      if (messageCopyText(widget.message) case final texte?)
        ListTile(
          leading: Icon(
            Icons.text_fields_rounded,
            color: context.textPrimaryColor,
          ),
          title: Text(
            l10n.selectText,
            style: TextStyle(color: context.textPrimaryColor),
          ),
          onTap: () {
            Navigator.pop(ctx);
            _showSelectTextSheet(texte);
          },
        ),

      if (!widget.message.deletedForEveryone &&
          (widget.message.type == MessageType.text ||
              widget.message.type == MessageType.image ||
              widget.message.type == MessageType.video ||
              widget.message.type == MessageType.file))
        ListTile(
          leading: AppIcon(AppIcon.share, color: context.textPrimaryColor),
          title: Text(
            l10n.share,
            style: TextStyle(color: context.textPrimaryColor),
          ),
          onTap: () {
            Navigator.pop(ctx);
            unawaited(_shareMessage());
          },
        ),
      if (widget.isMe &&
          !widget.message.deletedForEveryone &&
          widget.conversationId != null)
        ListTile(
          leading: AppIcon(AppIcon.info, color: context.textPrimaryColor),
          title: Text(
            l10n.messageInfoTitle,
            style: TextStyle(color: context.textPrimaryColor),
          ),
          onTap: () {
            Navigator.pop(ctx);
            _showMessageInfoSheet(context);
          },
        ),];
  }

  void _copyToClipboard(String texte) {
    unawaited(Clipboard.setData(ClipboardData(text: texte)));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.messageCopied),
        backgroundColor: context.adaptivePrimaryColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  /// Le texte du message, sélectionnable : appui long ou double tap dedans
  /// pour choisir un passage, « Tout copier » pour le reste.
  void _showSelectTextSheet(String texte) {
    unawaited(showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.75,
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          12 + MediaQuery.of(ctx).padding.bottom,
        ),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: SheetHandle()),
            const SizedBox(height: 12),
            Text(
              l10n.selectText,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: context.textPrimaryColor,
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                child: SelectableText(
                  texte,
                  style: TextStyle(
                    fontSize: 17,
                    height: 1.35,
                    color: context.textPrimaryColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _copyToClipboard(texte);
              },
              icon: const Icon(Icons.copy, size: 18),
              label: Text(l10n.copyAll),
            ),
          ],
        ),
      ),
    ));
  }

  void _showMessageInfoSheet(BuildContext context) {
    final conversationId = widget.conversationId;
    if (conversationId == null) return;

    unawaited(showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => MessageInfoSheet(
            message: widget.message,
            conversationId: conversationId,
            currentUserId: widget.currentUserId,
          ),
    ));
  }

  void _showDeleteModal(BuildContext context) {
    final conversationId = widget.conversationId;
    final currentUserId = widget.currentUserId;
    if (conversationId == null || currentUserId == null) return;

    unawaited(DeleteMessageModal.show(
      context,
      message: widget.message,
      conversationId: conversationId,
      currentUserId: currentUserId,
      isAdmin: widget.isAdmin,
    ));
  }

  /// Entrée « Modifier », désactivée avec son motif quand le geste n'est plus
  /// possible.
  ///
  /// Remplace la boîte de dialogue d'avant. Celle-ci couvrait la conversation,
  /// n'avait ni le clavier ni les emoji du composeur, et son
  /// `TextEditingController` n'était jamais disposé ; surtout, son bouton
  /// « Enregistrer » se fermait sans rien dire quand le texte était vide ou
  /// inchangé. La saisie se fait maintenant dans la barre du bas.
  Widget _entreeModifier(BuildContext ctx, AppLocalizations l10n) {
    final motif = widget.message.motifModificationImpossible(
      widget.currentUserId!,
    );
    final possible = motif == null;
    final couleur =
        possible ? context.textPrimaryColor : context.textTertiaryColor;

    return ListTile(
      enabled: possible,
      leading: Icon(Icons.edit_outlined, color: couleur),
      title: Text(l10n.edit, style: TextStyle(color: couleur)),
      subtitle:
          possible
              ? null
              : Text(
                phraseModificationImpossible(l10n, motif),
                style: TextStyle(
                  fontSize: 12,
                  color: context.textTertiaryColor,
                ),
              ),
      onTap:
          possible
              ? () {
                Navigator.pop(ctx);
                widget.onEdit?.call(widget.message);
              }
              : null,
    );
  }

  /// Crée un snapshot du message pour préserver le contenu signalé
  ContentSnapshot _createMessageSnapshot() {
    final message = widget.message;

    switch (message.type) {
      case MessageType.text:
        return ReportContentModal.textMessageSnapshot(message.content);

      case MessageType.image:
        return ReportContentModal.imageSnapshot(
          message.fileUrl ?? '',
          caption:
              message.content.isNotEmpty && message.content != message.fileName
                  ? message.content
                  : null,
        );

      case MessageType.video:
        return ReportContentModal.videoSnapshot(
          message.fileUrl ?? '',
          caption: message.content.isNotEmpty ? message.content : null,
        );

      case MessageType.audio:
      case MessageType.voiceNote:
      case MessageType.file:
        return ReportContentModal.fileSnapshot(
          message.fileUrl ?? '',
          message.fileName ?? l10n.fileLabel,
        );

      case MessageType.system:
        return ReportContentModal.textMessageSnapshot(message.content);
      case MessageType.call:
        final l10n = AppLocalizations.of(context)!;
        return ReportContentModal.textMessageSnapshot(
          '${l10n.call} ${message.callType == 'video' ? l10n.video : l10n.audio}',
        );
      case MessageType.location:
        final l10n = AppLocalizations.of(context)!;
        return ReportContentModal.textMessageSnapshot(
          '${l10n.location}: ${message.locationAddress ?? l10n.sharedLocation}',
        );
      case MessageType.poll:
        return ReportContentModal.textMessageSnapshot(
          'Sondage : ${message.content}',
        );
      case MessageType.sticker:
        return ReportContentModal.imageSnapshot(message.fileUrl ?? '');
    }
  }

  /// Une bulle vidée de son contenu : supprimée pour tout le monde, ou
  /// arrivée à l'échéance de son minuteur.
  ///
  /// L'échéance compte **dès qu'elle est passée**, sans attendre la pierre
  /// tombale du serveur : le balayage ne tourne qu'au quart d'heure, et un
  /// appareil hors ligne ne le verra pas passer du tout. Le contenu doit
  /// quitter l'écran à l'heure dite, pas à l'heure où le serveur s'en
  /// aperçoit.
  bool get _bulleVidee =>
      widget.message.deletedForEveryone || widget.message.isExpired;

  Widget _buildDeletedContent(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // « Supprimé » et « expiré » ne disent pas la même chose : l'un désigne
    // quelqu'un qui a agi, l'autre un minuteur que les deux côtés ont accepté.
    // Les confondre ferait soupçonner son interlocuteur d'un effacement qu'il
    // n'a pas fait.
    final expire = widget.message.isExpired;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            expire ? Icons.timer_off_outlined : Icons.block,
            size: 16,
            color:
                widget.isMe
                    ? AppColors.white.withValues(alpha: 0.7)
                    : context.textTertiaryColor,
          ),
          const SizedBox(width: 8),
          Text(
            expire ? l10n.messageAutoDeleted : l10n.messageDeleted,
            style: TextStyle(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color:
                  widget.isMe
                      ? AppColors.white.withValues(alpha: 0.7)
                      : context.textTertiaryColor,
            ),
          ),
        ],
      ),
    );
  }

  // Greyscale + alpha-reduced color matrix for expired media ghost effect
  static const ColorFilter _greyFilter = ColorFilter.matrix([
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

  Widget _buildExpiredBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_clock, color: Colors.white70, size: 12),
          SizedBox(width: 3),
          Text(l10n.messageExpired, style: TextStyle(color: Colors.white70, fontSize: 10)),
        ],
      ),
    );
  }

  /// Ghost of an image or video — shows the blurhash faded with a dark veil.
  Widget _buildExpiredVisualGhost() {
    final message = widget.message;
    final blurhash = message.blurhash;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 200,
        height: 150,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Ghost background: blurhash if available, grey otherwise
            if (blurhash != null && blurhash.isNotEmpty)
              BlurhashImage(blurhash: blurhash, fit: BoxFit.cover)
            else
              ColoredBox(color: Colors.grey.shade400),
            // Dark veil
            ColoredBox(color: Colors.black.withValues(alpha: 0.55)),
            // Centred icon + label
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  message.type == MessageType.video
                      ? Icons.videocam_off_rounded
                      : Icons.image_not_supported_rounded,
                  color: Colors.white60,
                  size: 32,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Média expiré',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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

  /// Renders the media from a local file when the Storage URL has expired.
  Widget _buildLocalMediaWidget(String localPath) {
    final message = widget.message;
    final file = File(localPath);

    switch (message.type) {
      case MessageType.image:
        return Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                file,
                width: 200,
                height: 150,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildExpiredGhost(),
              ),
            ),
            Positioned(top: 4, right: 4, child: _buildLocalBadge()),
          ],
        );

      case MessageType.voiceNote:
        // Pass a file:// URI so just_audio can play from local storage.
        // Reset mediaExpired so the bubble renders and plays normally.
        final localEntity = message.copyWith(
          fileUrl: 'file://$localPath',
          mediaExpired: false,
        );
        return Stack(
          children: [
            AudioMessageBubble(message: localEntity, isMe: widget.isMe),
            Positioned(top: 4, right: 4, child: _buildLocalBadge()),
          ],
        );

      case MessageType.audio:
        // Audio file picked from device: render the compact player from local storage.
        final localEntity = message.copyWith(
          fileUrl: 'file://$localPath',
          mediaExpired: false,
        );
        return Stack(
          children: [
            AudioFileBubble(message: localEntity, isMe: widget.isMe),
            Positioned(top: 4, right: 4, child: _buildLocalBadge()),
          ],
        );

      case MessageType.video:
      case MessageType.file:
        // Show the greyed card but with a local badge; user can open from device
        return Stack(
          children: [
            ColorFiltered(
              colorFilter: _greyFilter,
              child: IgnorePointer(
                child: DocumentBubble(
                  fileUrl: '',
                  fileName: message.fileName ?? l10n.fileLabel,
                  fileSize: message.fileSize,
                  isMe: widget.isMe,
                ),
              ),
            ),
            Positioned(top: 4, right: 4, child: _buildLocalBadge()),
          ],
        );

      default:
        return _buildExpiredGhost();
    }
  }

  Widget _buildLocalBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.phone_android, color: Colors.white70, size: 12),
          SizedBox(width: 3),
          Text(l10n.messageLocalCopy, style: TextStyle(color: Colors.white70, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildExpiredGhost() {
    final message = widget.message;

    switch (message.type) {
      case MessageType.image:
      case MessageType.video:
        return _buildExpiredVisualGhost();

      case MessageType.voiceNote:
        return Stack(
          children: [
            ColorFiltered(
              colorFilter: _greyFilter,
              child: IgnorePointer(
                child: AudioMessageBubble(message: message, isMe: widget.isMe),
              ),
            ),
            Positioned(top: 4, right: 4, child: _buildExpiredBadge()),
          ],
        );

      case MessageType.audio:
        return Stack(
          children: [
            ColorFiltered(
              colorFilter: _greyFilter,
              child: IgnorePointer(
                child: AudioFileBubble(message: message, isMe: widget.isMe),
              ),
            ),
            Positioned(top: 4, right: 4, child: _buildExpiredBadge()),
          ],
        );

      case MessageType.file:
        return Stack(
          children: [
            ColorFiltered(
              colorFilter: _greyFilter,
              child: IgnorePointer(
                child: DocumentBubble(
                  fileUrl: '',
                  fileName: message.fileName ?? l10n.fileLabel,
                  fileSize: message.fileSize,
                  isMe: widget.isMe,
                ),
              ),
            ),
            Positioned(top: 4, right: 4, child: _buildExpiredBadge()),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildContent(BuildContext context) {
    // Show expired placeholder for any media type whose Storage file was deleted
    if (widget.message.mediaExpired &&
        (widget.message.type == MessageType.image ||
            widget.message.type == MessageType.video ||
            widget.message.type == MessageType.audio ||
            widget.message.type == MessageType.voiceNote ||
            widget.message.type == MessageType.file)) {
      return _buildExpiredMediaPlaceholder(context);
    }

    switch (widget.message.type) {
      case MessageType.image:
        return MediaChiffreGate(
          message: widget.message,
          builder: (context, m) => DataSaverGate(
          messageId: widget.message.id,
          isMe: widget.isMe,
          blurhash: widget.message.blurhash,
          fileSize: widget.message.fileSize,
          builder: (context) => OptimizedImageBubble(
          imageUrl: m.fileUrl ?? '',
          caption:
              widget.message.content == widget.message.fileName ||
                      widget.message.content == widget.message.fileUrl ||
                      widget.message.content.isEmpty
                  ? null
                  : widget.message.content,
          isMe: widget.isMe,
          heroTag: 'message_image_${widget.message.id}',
          showSenderInfo: widget.showSenderInfo && !widget.isMe,
          senderName: widget.message.senderName,
          blurhash: widget.message.blurhash,
          onTap:
              () => FullScreenImageViewer.show(
                context,
                imageUrl: m.fileUrl!,
                heroTag: 'message_image_${widget.message.id}',
                senderName: widget.message.senderName,
                sentAt: widget.message.createdAt,
                messageId: widget.message.id,
              ),
          onSave: () => _saveImageToGallery(m.fileUrl!),
          onShare: () => _shareMessage(),
          // Appui long = menu complet (permet d'épingler une photo, etc.).
          onLongPress: _onLongPress,
          ),
          ),
        );

      case MessageType.file:
        return MediaChiffreGate(
          message: widget.message,
          aspectRatio: 4,
          builder: (context, m) => DocumentBubble(
            fileUrl: m.fileUrl ?? '',
            fileName: m.fileName ?? l10n.fileLabel,
            fileSize: m.fileSize,
            isMe: widget.isMe,
            onTap: () => _openFile(m.fileUrl),
            onShare: () => _shareMessage(),
          ),
        );

      case MessageType.video: {
        final videoCaption =
            widget.message.content == widget.message.fileName ||
                    widget.message.content == widget.message.fileUrl ||
                    widget.message.content.isEmpty
                ? null
                : widget.message.content;
        return DataSaverGate(
          messageId: widget.message.id,
          isMe: widget.isMe,
          blurhash: widget.message.blurhash,
          fileSize: widget.message.fileSize,
          builder: (context) => VideoBubble(
          videoUrl: widget.message.fileUrl ?? '',
          thumbnailUrl: widget.message.thumbnailUrl,
          duration: widget.message.videoDuration,
          caption: videoCaption,
          isMe: widget.isMe,
          showSenderInfo: widget.showSenderInfo && !widget.isMe,
          senderName: widget.message.senderName,
          messageId: widget.message.id,
          blurhash: widget.message.blurhash,
          onTap:
              widget.message.fileUrl != null
                  ? () => VideoPlayerScreen.show(
                        context,
                        videoUrl: widget.message.fileUrl!,
                        senderName: widget.message.senderName,
                        timestamp: widget.message.createdAt,
                        caption: videoCaption,
                      )
                  : null,
          onForward:
              widget.onForward != null
                  ? () => widget.onForward?.call(widget.message)
                  : null,
          onSave:
              widget.message.fileUrl != null
                  ? () => _saveVideoToDevice(widget.message.fileUrl!)
                  : null,
          onShare: () => _shareMessage(),
          // Appui long = menu complet (permet d'épingler une vidéo, etc.).
          onLongPress: _onLongPress,
          ),
        );
      }

      case MessageType.audio:
        return MediaChiffreGate(
          message: widget.message,
          aspectRatio: 4,
          builder: (context, m) => AudioFileBubble(message: m, isMe: widget.isMe),
        );

      case MessageType.voiceNote:
        return MediaChiffreGate(
          message: widget.message,
          aspectRatio: 4,
          builder: (context, m) =>
              AudioMessageBubble(message: m, isMe: widget.isMe),
        );

      case MessageType.text:
        return _buildTextContent(context);

      case MessageType.system:
        return _buildSystemMessageContent(context);
      case MessageType.call:
        return CallMessageBubble(
          message: widget.message,
          isMe: widget.isMe,
          currentUserId: widget.currentUserId ?? '',
          onCallBack: widget.onCallBack,
        );

      case MessageType.location:
        return LocationMessageBubble(
          latitude: widget.message.latitude ?? 0,
          longitude: widget.message.longitude ?? 0,
          address: widget.message.locationAddress ?? '',
          isMe: widget.isMe,
          status: widget.message.status,
          onRetry: widget.onRetry,
        );

      case MessageType.poll:
        return PollMessageBubble(
          pollId: widget.message.pollId ?? '',
          fallbackQuestion: widget.message.content,
          // La carte reprend les rayons de la bulle : sans eux, son coin
          // arrondi a 16 laissait voir le vert de la bulle envoyee dans le
          // coin de queue, arrondi a 6.
          borderRadius: _getBorderRadius(),
        );

      case MessageType.sticker:
        return StickerBubble(
          stickerUrl: widget.message.fileUrl ?? '',
          isAnimated: widget.message.isAnimatedSticker,
          isMe: widget.isMe,
          onLongPress: _onLongPress,
        );
    }
  }

  Widget _buildReplyPreview(BuildContext context) {
    final reply = widget.replyToMessage;
    if (reply == null) return const SizedBox.shrink();
    final isMe = widget.isMe;
    final isDarkMode = context.isDarkMode;
    final l10n = AppLocalizations.of(context)!;

    // Show "You" if the reply is from the current user
    final isReplyFromMe =
        widget.currentUserId != null && reply.senderId == widget.currentUserId;
    final replyAuthorName = isReplyFromMe ? l10n.you : reply.senderName;

    return GestureDetector(
      onTap: () {
        // Scroll to original message - callback to parent
        widget.onScrollToMessage?.call(reply.id);
      },
      child: Container(
        margin: const EdgeInsets.only(left: 6, right: 6, top: 6, bottom: 2),
        // Fiche 4a : « citation bordure gauche blanche translucide ». Le filet
        // reste, l'aplat revient — sur la bulle envoyée aussi. Il avait été
        // retiré parce qu'il faisait « une seconde bulle dans la bulle », mais
        // c'était le liseré de 4 px OPAQUE qui la dessinait, pas l'aplat : à
        // 3 px translucides et 12 % d'alpha, le bloc pose un fond, pas une
        // bulle — et sans lui, la citation se lit comme une étiquette posée à
        // côté du message plutôt que comme le message cité.
        padding: const EdgeInsets.only(left: 8, top: 5, bottom: 5, right: 10),
        decoration: BoxDecoration(
          color:
              isMe
                  ? Colors.white.withValues(alpha: 0.12)
                  : isDarkMode
                  ? Colors.black.withValues(alpha: 0.35)
                  : Colors.black.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          // Un `Border` non uniforme avec un `borderRadius` ne passe que parce
          // qu'une SEULE couleur est visible (les trois autres côtés sont
          // `BorderStyle.none`) : `Border.paint` prend alors le chemin
          // `paintNonUniformBorder`. Ajouter un second côté coloré ici ferait
          // lever l'assertion « A borderRadius can only be given on borders
          // with uniform colors ».
          border: Border(
            left: BorderSide(
              color:
                  isMe
                      ? Colors.white.withValues(alpha: 0.85)
                      : context.adaptivePrimaryColor,
              width: 3,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              replyAuthorName,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isMe ? AppColors.white : context.adaptivePrimaryColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 1),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (reply.type != MessageType.text) ...[
                  Icon(
                    _getMediaIcon(reply.type),
                    size: 14,
                    color:
                        isMe
                            ? AppColors.white.withValues(alpha: 0.8)
                            : context.textSecondaryColor,
                  ),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(
                    reply.type == MessageType.text
                        ? reply.content
                        : _getMediaTypeLabel(reply.type),
                    style: TextStyle(
                      fontSize: 13,
                      color:
                          isMe
                              ? AppColors.white.withValues(alpha: 0.85)
                              : context.textSecondaryColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getMediaIcon(MessageType type) {
    switch (type) {
      case MessageType.image:
        return Icons.image;
      case MessageType.video:
        return Icons.videocam;
      case MessageType.voiceNote:
        return Icons.mic;
      case MessageType.audio:
        return Icons.audiotrack;
      case MessageType.file:
        return Icons.insert_drive_file;
      case MessageType.location:
        return Icons.location_on;
      case MessageType.poll:
        return Icons.bar_chart;
      case MessageType.sticker:
        return Icons.emoji_emotions;
      default:
        return Icons.chat_bubble;
    }
  }

  static final _urlRegex = RegExp(
    r'(?:https?://|www\.)[^\s<>\]\)]+|(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+(?:com|fr|org|net|io|co|app|dev|info|biz|edu|gov|me|tv|uk|de|nl|be|ch|ca|au|nz|ng|sn|ml|bf|ci|tg|bj|ne|gn|cm|cd|cg|ga|td|cf|rw|bi|ug|ke|tz|et|gh|za|ma|dz|tn|eg|ly|sd|mu|mg|mw|zm|zw|mz|ao|na|bw|sz|ls|so|dj|er|ss)(?:/[^\s<>\]\)]*)?',
    caseSensitive: false,
  );

  // Phone number regex supporting international and African formats
  // +227 XX XX XX XX, 00227 XX XX XX XX, 227 XX XX XX XX, local formats
  static final _phoneRegex = RegExp(
    r'(?:\+|00)?(?:227|226|225|224|223|222|221|220|234|233|231|230|229|228|237|236|235|241|240|243|242|244|245|250|251|252|253|254|255|256|257|258|260|261|262|263|264|265|266|267|268|269|27|20|212|213|216|218|1|33|44|49|34|39|31|32|41)?[-.\s]?\(?\d{2,3}\)?[-.\s]?\d{2}[-.\s]?\d{2}[-.\s]?\d{2}[-.\s]?\d{0,2}',
  );

  // Email regex
  static final _emailRegex = RegExp(
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
  static final _richTextRegex = RegExp(
    r'(?<![\w*_~`])'
    r'(?:'
    r'\*(?=\S)[^*\n]*[^*\s]\*'
    r'|_(?=\S)[^_\n]*[^_\s]_'
    r'|~(?=\S)[^~\n]*[^~\s]~'
    r'|`(?=\S)[^`\n]*[^`\s]`'
    r')'
    r'(?![\w*_~`])',
  );

  /// Build a RichText widget with clickable URLs, phone numbers, and emails
  Widget _buildRichTextWithLinks(BuildContext context, String text) {
    // Collect all matches: URLs, phone numbers, and emails
    final allMatches = <_LinkMatch>[];

    // URLs
    for (final match in _urlRegex.allMatches(text)) {
      allMatches.add(
        _LinkMatch(
          start: match.start,
          end: match.end,
          text: match.group(0)!,
          type: _LinkType.url,
        ),
      );
    }

    // Phone numbers
    for (final match in _phoneRegex.allMatches(text)) {
      final phoneText = match.group(0)!;
      // Only include if it has at least 8 digits (valid phone number)
      final digits = phoneText.replaceAll(RegExp(r'\D'), '');
      if (digits.length >= 8) {
        // Check for overlap with existing matches
        final hasOverlap = allMatches.any(
          (m) =>
              (match.start >= m.start && match.start < m.end) ||
              (match.end > m.start && match.end <= m.end) ||
              (match.start <= m.start && match.end >= m.end),
        );
        if (!hasOverlap) {
          allMatches.add(
            _LinkMatch(
              start: match.start,
              end: match.end,
              text: phoneText,
              type: _LinkType.phone,
            ),
          );
        }
      }
    }

    // Emails
    for (final match in _emailRegex.allMatches(text)) {
      final hasOverlap = allMatches.any(
        (m) =>
            (match.start >= m.start && match.start < m.end) ||
            (match.end > m.start && match.end <= m.end) ||
            (match.start <= m.start && match.end >= m.end),
      );
      if (!hasOverlap) {
        allMatches.add(
          _LinkMatch(
            start: match.start,
            end: match.end,
            text: match.group(0)!,
            type: _LinkType.email,
          ),
        );
      }
    }

    // Mentions — highlight @Name for each confirmed mentioned user
    final mentionedUsers = widget.message.mentionedUsers;
    if (mentionedUsers.isNotEmpty) {
      // Du plus long au plus court : l'alternation d'une RegExp s'arrête à la
      // première branche qui correspond, donc `@Ali` placé avant `@Alichina`
      // n'aurait coloré que les trois premières lettres de la seconde.
      final names = mentionedUsers.map((m) => m.name).toList()
        ..sort((a, b) => b.length.compareTo(a.length));
      final mentionPattern = RegExp(
        names.map((n) => RegExp.escape('@$n')).join('|'),
      );
      for (final match in mentionPattern.allMatches(text)) {
        final hasOverlap = allMatches.any(
          (m) =>
              (match.start >= m.start && match.start < m.end) ||
              (match.end > m.start && match.end <= m.end) ||
              (match.start <= m.start && match.end >= m.end),
        );
        if (!hasOverlap) {
          allMatches.add(
            _LinkMatch(
              start: match.start,
              end: match.end,
              text: match.group(0)!,
              type: _LinkType.mention,
            ),
          );
        }
      }
    }

    final baseStyle = TextStyle(
      fontSize: 17,
      color: widget.isMe ? AppColors.white : context.textPrimaryColor,
    );

    if (allMatches.isEmpty) {
      // No links, but may have rich text formatting.
      // Text.rich (non-sélectionnable) plutôt que SelectableText : la
      // sélection de texte native captait l'appui long avant le
      // GestureDetector de la bulle, affichant le menu OS (Copier / Partager
      // / Tout sélectionner) au lieu du menu contextuel façon Signal.
      final richSpans = _parseRichText(text, baseStyle);
      return Text.rich(TextSpan(children: richSpans));
    }

    // Sort matches by start position
    allMatches.sort((a, b) => a.start.compareTo(b.start));

    final spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final match in allMatches) {
      // Text before this match (may contain rich text formatting)
      if (match.start > lastEnd) {
        final plainText = text.substring(lastEnd, match.start);
        spans.addAll(_parseRichText(plainText, baseStyle));
      }

      // The link/mention itself
      if (match.type == _LinkType.mention) {
        spans.add(
          TextSpan(
            text: match.text,
            style: TextStyle(
              fontSize: 17,
              color:
                  widget.isMe
                      ? Colors.white
                      : Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
            // Une mention ne menait nulle part : elle était colorée, et c'est
            // tout. Même geste que dans le fil, où taper une mention ouvre le
            // profil.
            recognizer:
                TapGestureRecognizer()..onTap = () => _handleLinkTap(match),
          ),
        );
      } else {
        final linkColor =
            match.type == _LinkType.phone
                ? (widget.isMe ? Colors.greenAccent : Colors.green)
                : (widget.isMe ? Colors.lightBlueAccent : Colors.blue);

        spans.add(
          TextSpan(
            text: match.text,
            style: TextStyle(
              fontSize: 17,
              color: linkColor,
              decoration: TextDecoration.underline,
              decorationColor: linkColor,
            ),
            recognizer:
                TapGestureRecognizer()..onTap = () => _handleLinkTap(match),
          ),
        );
      }

      lastEnd = match.end;
    }

    // Remaining text after last match (may contain rich text formatting)
    if (lastEnd < text.length) {
      final remainingText = text.substring(lastEnd);
      spans.addAll(_parseRichText(remainingText, baseStyle));
    }

    return Text.rich(TextSpan(children: spans));
  }

  /// Parse text for rich formatting: *bold*, _italic_, ~strikethrough~, `code`
  List<InlineSpan> _parseRichText(String text, TextStyle baseStyle) {
    final matches = _richTextRegex.allMatches(text).toList();

    if (matches.isEmpty) {
      return [TextSpan(text: text, style: baseStyle)];
    }

    final spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final match in matches) {
      // Text before this match
      if (match.start > lastEnd) {
        spans.add(
          TextSpan(
            text: text.substring(lastEnd, match.start),
            style: baseStyle,
          ),
        );
      }

      final matchedText = match.group(0)!;
      final content = matchedText.substring(1, matchedText.length - 1);
      TextStyle style = baseStyle;

      if (matchedText.startsWith('*')) {
        // Bold
        style = style.copyWith(fontWeight: FontWeight.bold);
      } else if (matchedText.startsWith('_')) {
        // Italic
        style = style.copyWith(fontStyle: FontStyle.italic);
      } else if (matchedText.startsWith('~')) {
        // Strikethrough
        style = style.copyWith(decoration: TextDecoration.lineThrough);
      } else if (matchedText.startsWith('`')) {
        // Code
        style = style.copyWith(
          fontFamily: 'monospace',
          backgroundColor:
              widget.isMe
                  ? Colors.black.withValues(alpha: 0.2)
                  : Colors.grey.withValues(alpha: 0.2),
        );
      }

      spans.add(TextSpan(text: content, style: style));
      lastEnd = match.end;
    }

    // Remaining text after last match
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd), style: baseStyle));
    }

    return spans;
  }

  Widget _buildTextContent(BuildContext context) {
    // Aucun marqueur technique dans une bulle : ni « [Message illisible] », ni
    // « 🔐 Message chiffré », ni « session requise ». Quand le texte a déjà été
    // lu une fois sur cet appareil, il revient du cache bien avant ici
    // (`_healUndecryptableMessages`) ; s'il arrive quand même jusqu'ici, c'est
    // qu'il n'a jamais été lisible, et une phrase neutre vaut mieux qu'un
    // vocabulaire interne.
    //
    // La LISTE, pas `isUndecryptableContent` : celui-ci tient aussi le contenu
    // vide pour illisible, ce qu'est tout média sans légende — il masquerait
    // alors la légende absente de chaque photo.
    if (kUndecryptablePlaceholders.contains(widget.message.content)) {
      return const UndecryptableMessageBubble();
    }

    final isEmojiOnly = _isEmojiOnly(widget.message.content);
    final postData = widget.message.postData;
    final productData = widget.message.productData;
    final eventData = widget.message.eventData;
    final linkPreviewData = widget.message.linkPreviewData;
    final hasProduct = productData != null;
    final hasLinkPreview = linkPreviewData != null;

    // Emoji-only messages: larger text, no bubble background
    if (isEmojiOnly && !hasProduct && eventData == null) {
      return Padding(
        padding: const EdgeInsets.only(left: 12, right: 12, top: 8, bottom: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.message.content, style: const TextStyle(fontSize: 42)),
          ],
        ),
      );
    }

    return Padding(
      // Sous une citation, le bandeau porte déjà son propre retrait : 10 px de
      // plus séparaient le texte de la citation d'un tiers de sa hauteur.
      padding: EdgeInsets.only(
        left: 14,
        right: 14,
        top: widget.replyToMessage != null ? 4 : 10,
        bottom: 8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Post share card if attached
          if (postData != null)
            PostMessageCard(postData: postData, isMe: widget.isMe),
          // Product card if attached
          if (hasProduct)
            ProductMessageCard(productData: productData, isMe: widget.isMe),
          // Event card if attached
          if (eventData != null)
            EventMessageCard(eventData: eventData, isMe: widget.isMe),
          // Le texte occupe toute la bulle : l'heure et l'accusé de réception
          // sont posés sous la bulle par _buildMetaRow (fiches 4a/6b).
          // Sous une carte, le texte généré par le partage (« 📌 Post de… »,
          // « 📅 Titre ») répétait la carte : il n'est affiché que si
          // l'utilisateur a écrit autre chose.
          if (!((postData != null &&
                  PostMessageCard.isDefaultCaption(
                    widget.message.content,
                    postData,
                  )) ||
              (eventData != null &&
                  EventMessageCard.isDefaultCaption(
                    widget.message.content,
                    eventData,
                  ))))
            _buildRichTextWithLinks(context, widget.message.content),
          // Link preview card
          if (hasLinkPreview)
            LinkPreviewBubble.fromMap(linkPreviewData, isMe: widget.isMe),
        ],
      ),
    );
  }

  /// Ligne de méta posée **sous** la bulle : heure, accusé de réception et
  /// réactions (fiches 4a/6b — « 09:12 👍 1 »).
  ///
  /// Elle vit hors de la bulle, donc sur le fond de la conversation : ses
  /// couleurs ne dépendent plus de `isMe`. C'est la seule ligne de méta pour
  /// tout message qui l'atteint — aucune bulle spécialisée (image, vidéo,
  /// document, note vocale, sticker, localisation) ne réaffiche l'heure de
  /// son côté. Exception : un message d'appel (`widget.message.isCall`)
  /// retourne tôt dans `build()`, avant le `Column` qui pose cette ligne —
  /// `CallMessageBubble` affiche donc sa propre heure, seule pour ce type.
  ///
  /// Inconditionnelle : chaque message porte son heure, qu'il soit regroupé
  /// ou non avec ses voisins (rafale). Un masquage « une heure par rafale,
  /// tap pour révéler » a existé et a été retiré deux fois pour la même
  /// raison — illisible (un tap sans affordance) et, sur toute bulle média,
  /// irrécupérable (son propre geste de tap gagne toujours l'arène avant
  /// celui du masquage) — avant d'être remis en place à la demande. Retiré
  /// une troisième fois, cette fois pour de bon : demande explicite de
  /// Salim, plus de bascule du tout, l'heure s'affiche toujours. Le
  /// regroupement visuel (queue de bulle, nom de l'expéditeur, rayons) n'a
  /// jamais dépendu de cette ligne.
  Widget _buildMetaRow(BuildContext context) {
    final hasReactions = widget.message.reactions.isNotEmpty;
    final isStarred =
        widget.currentUserId != null &&
        widget.message.isStarredBy(widget.currentUserId!);
    final l10n = AppLocalizations.of(context)!;
    final metaColor = context.textTertiaryColor;

    // Nombre de lecteurs autres que l'expéditeur. En tête-à-tête, un seul
    // suffit à « Lu » ; en groupe, voir `_buildReceiptLabel`.
    final groupReadCount =
        widget.message.readBy
            .where((id) => id != widget.message.senderId)
            .length;

    final timeRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isStarred) ...[
          AppIcon(AppIcon.star, size: 12, color: metaColor),
          const SizedBox(width: 2),
        ],
        // Edited indicator
        if (widget.message.isEdited) ...[
          Text(
            l10n.edited,
            style: TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: metaColor,
            ),
          ),
          const SizedBox(width: 4),
        ],
        // Ephemeral indicator
        if (widget.message.isEphemeral) ...[
          Icon(Icons.timer_outlined, size: 12, color: metaColor),
          const SizedBox(width: 2),
        ],
        Text(
          _formatTime(widget.message.createdAt),
          style: TextStyle(fontSize: 11, color: metaColor),
        ),
        // « 09:24 · Envoyé » (fiche 26b) : l'accusé de réception se
        // lit, il ne se déchiffre plus. Une coche simple, une double
        // et une double bleue demandaient d'avoir appris le code.
        if (widget.isMe && !widget.message.deletedForEveryone)
          _buildReceiptLabel(context, groupReadCount),
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: widget.isMe ? WrapAlignment.end : WrapAlignment.start,
        children: [
          timeRow,
          if (hasReactions)
            ..._buildReactionChips(context, widget.message.reactions),
        ],
      ),
    );
  }

  String _getMediaTypeLabel(MessageType type) {
    final l10n = AppLocalizations.of(context)!;
    switch (type) {
      case MessageType.image:
        return '📷 ${l10n.photo}';
      case MessageType.video:
        return '🎥 ${l10n.video}';
      case MessageType.voiceNote:
        return '🎙️ ${l10n.messageTypeVoiceNote}';
      case MessageType.audio:
        return '🎵 ${l10n.messageTypeAudio}';
      case MessageType.file:
        return '📄 ${l10n.document}';
      case MessageType.text:
        return '';
      case MessageType.system:
        return '💬 ${l10n.systemMessage}';
      case MessageType.call:
        return '📞 ${l10n.call}';
      case MessageType.location:
        return '📍 ${l10n.location}';
      case MessageType.poll:
        return '📊 Sondage';
      case MessageType.sticker:
        return l10n.messageTypeSticker;
    }
  }

  /// Verifier si le message est en attente dans la queue offline
  bool _isPendingOffline() {
    return widget.message.id.startsWith('pending_') &&
        widget.message.status == MessageStatus.sending;
  }

  // Le cadenas de chiffrement n'était posé que sur les messages « emoji seul »,
  // nulle part ailleurs — une incohérence qui disparaît avec la ligne de méta
  // unique. Le rappel de chiffrement vit dans l'en-tête, à côté du statut
  // (`_buildStatusWithLock` de conversation_screen), comme le veut la fiche 4a.

  /// Accusé de réception **en toutes lettres**, à la suite de l'heure :
  /// « 09:24 · Envoyé » (fiche 26b).
  ///
  /// Il y avait trois coches à distinguer — simple, double, double bleue —
  /// dans un cercle de 18 px. Il fallait avoir appris le code pour le lire.
  ///
  /// En groupe, « Vu par N » remplace « Lu » : il dit combien de personnes ont
  /// lu, ce que « Lu » laissait deviner.
  Widget _buildReceiptLabel(BuildContext context, int groupReadCount) {
    final l10n = AppLocalizations.of(context)!;
    final metaColor = context.textTertiaryColor;

    switch (widget.message.status) {
      case MessageStatus.sending:
        // En attente dans la queue hors-ligne : c'est une information d'un
        // autre ordre (rien n'est parti), elle garde sa teinte d'alerte.
        if (_isPendingOffline()) {
          return _receiptText(
            l10n.pending,
            Colors.orange[700]!,
            italic: true,
          );
        }
        return _receiptText(l10n.receiptSending, metaColor);

      case MessageStatus.failed:
        // Seul état encore porteur d'une icône : l'échec appelle une action,
        // et le libellé est cliquable.
        const softRed = Color(0xFFF87171);
        return GestureDetector(
          onTap: widget.onRetry,
          behavior: HitTestBehavior.opaque,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                ' · ',
                style: TextStyle(fontSize: 11, color: metaColor),
              ),
              const Icon(Icons.error_outline, size: 12, color: softRed),
              const SizedBox(width: 3),
              Text(
                '${l10n.messageNotSent} · ${l10n.retry}',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: softRed,
                ),
              ),
            ],
          ),
        );

      case MessageStatus.sent:
        // Demande de message en attente : l'expéditeur ne voit que « Envoyé »,
        // jamais l'accusé de lecture de quelqu'un qui ne l'a pas accepté.
        if (widget.isPendingRequest) {
          return _receiptText(l10n.receiptSent, metaColor);
        }

        // En groupe, « Lu » quand TOUS les membres attendus ont lu (étape C).
        // Avant, « Vu par N » s'affichait en bleu dès le premier lecteur :
        // l'expéditeur d'un groupe de 24 lisait « Vu par 1 » comme « lu ». Le
        // détail par membre reste à un tap (`_showMessageInfoSheet`).
        final isRead =
            widget.groupId != null
                ? tousOntLu(widget.message.readBy, widget.lecteursAttendus)
                : groupReadCount > 0;
        final isDelivered =
            widget.message.deliveredTo
                .where((id) => id != widget.message.senderId)
                .isNotEmpty;

        late final String libelle;
        late final Color couleur;
        if (isRead) {
          libelle = l10n.receiptRead;
          couleur = AppColors.readReceiptBlue;
        } else if (isDelivered) {
          libelle = l10n.receiptDelivered;
          couleur = metaColor;
        } else {
          libelle = l10n.receiptSent;
          couleur = metaColor;
        }

        final label = _receiptText(libelle, couleur);
        // Le détail par destinataire reste accessible d'un tap, comme avant.
        if (widget.conversationId == null) return label;
        return GestureDetector(
          onTap: () => _showMessageInfoSheet(context),
          child: label,
        );
    }
  }

  /// « · Envoyé » — le séparateur appartient au libellé pour qu'il disparaisse
  /// avec lui.
  Widget _receiptText(String texte, Color couleur, {bool italic = false}) {
    return Text(
      ' · $texte',
      style: TextStyle(
        fontSize: 11,
        color: couleur,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      ),
    );
  }

  Widget _buildSystemMessageContent(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 32),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color:
            context.isDarkMode
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        // Le séparateur de bascule MLS ne porte pas son texte : il portait une
        // phrase française en dur, servie telle quelle à un compte en anglais.
        // Son libellé se résout ici, donc dans la langue courante. Même règle
        // pour les notices de gestion de groupe.
        widget.message.estSeparateurMls
            ? AppLocalizations.of(context)!.mlsSeparatorEncrypted
            : _libelleNoticeDeGroupe() ?? widget.message.content,
        style: TextStyle(fontSize: 12, color: context.textSecondaryColor),
        textAlign: TextAlign.center,
      ),
    );
  }

  /// Phrase d'une notice de gestion de groupe, dans la langue courante, ou
  /// `null` si ce message n'en est pas une.
  ///
  /// Le serveur envoie les identités (`data.evenement`), pas la phrase : lui
  /// laisser composer le texte le figerait en français pour tout le monde —
  /// exactement la faute que le séparateur MLS a coûtée. `content` reste le
  /// repli pour les notices déjà en base et pour un `type` qu'une version
  /// installée ne connaîtrait pas encore.
  ///
  /// Trois voix par action, et non un « Vous » injecté dans une phrase unique :
  /// « Vous a retiré Hocine » n'est pas du français. Acteur et cible ne peuvent
  /// pas être la même personne — la RPC refuse une action sur soi (22023) —
  /// donc les trois cas couvrent tout.
  String? _libelleNoticeDeGroupe() {
    final notice = widget.message.noticeDeGroupe;
    if (notice == null) return null;

    final l10n = AppLocalizations.of(context)!;
    String nom(String cleNom) {
      final valeur = (notice[cleNom] as String?)?.trim();
      return (valeur == null || valeur.isEmpty)
          ? l10n.unknownUserLabel
          : valeur;
    }

    final jeSuisLacteur = notice['acteurId'] == widget.currentUserId;
    final jeSuisLaCible = notice['cibleId'] == widget.currentUserId;
    final acteur = nom('acteurNom');
    final cible = nom('cibleNom');

    return switch (notice['type']) {
      // La cible ne peut pas se lire : exclue de `participant_ids`, la policy
      // `messages_select` lui refuse la notice. Pas de voix « à vous » ici.
      'membre_retire' => jeSuisLacteur
          ? l10n.groupNoticeMemberRemovedByYou(cible)
          : l10n.groupNoticeMemberRemoved(acteur, cible),
      'admin_nomme' => jeSuisLacteur
          ? l10n.groupNoticeAdminNamedByYou(cible)
          : jeSuisLaCible
              ? l10n.groupNoticeAdminNamedToYou(acteur)
              : l10n.groupNoticeAdminNamed(acteur, cible),
      'admin_retire' => jeSuisLacteur
          ? l10n.groupNoticeAdminRemovedByYou(cible)
          : jeSuisLaCible
              ? l10n.groupNoticeAdminRemovedToYou(acteur)
              : l10n.groupNoticeAdminRemoved(acteur, cible),
      _ => null,
    };
  }

  String _formatTime(DateTime dateTime) {
    // Message de moins d'une minute : « À l'instant » / « Just now »,
    // sinon l'heure exacte (12:04). Localisé via AppLocalizations.justNow.
    final diff = DateTime.now().difference(dateTime);
    if (!diff.isNegative && diff.inMinutes < 1) {
      return AppLocalizations.of(context)!.justNow;
    }
    return DateFormat.Hm().format(dateTime);
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

  Future<void> _saveImageToGallery(String imageUrl) async {
    final service = FileDownloadService();
    final hasPermission = await service.hasGalleryPermission();
    if (!hasPermission) {
      final granted = await service.requestGalleryPermission();
      if (!granted) return;
    }
    final success = estUrlLocale(imageUrl)
        ? await enregistrerImageLocaleDansGalerie(cheminDepuisUrlLocale(imageUrl))
        : await service.downloadImageToGallery(
          imageUrl,
          messageId: widget.message.id,
        );
    if (mounted) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? l10n.imageSaved : l10n.saveFailed),
          backgroundColor: success ? Colors.green : Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _saveVideoToDevice(String videoUrl) async {
    final msg = widget.message;
    final fileName =
        msg.fileName?.isNotEmpty == true ? msg.fileName! : '${msg.id}.mp4';
    final file = await FileDownloadService().downloadToAppDirectory(
      videoUrl,
      fileName: fileName,
      messageId: msg.id,
    );
    if (mounted) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(file != null ? l10n.videoSaved : l10n.saveFailed),
          backgroundColor: file != null ? Colors.green : Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _openFile(String? url) async {
    if (url == null) return;
    // Document déchiffré : pas d'URL à ouvrir dans un navigateur, on passe
    // par la feuille de partage du système, qui sait « ouvrir avec ».
    if (estUrlLocale(url)) {
      await SharePlus.instance.share(
        ShareParams(files: [XFile(cheminDepuisUrlLocale(url))]),
      );
      return;
    }
    // Add https:// if no protocol is specified
    String normalizedUrl = url;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      normalizedUrl = 'https://$url';
    }
    final uri = Uri.parse(normalizedUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _shareMessage() async {
    final l10n = AppLocalizations.of(context)!;
    final scaffold = ScaffoldMessenger.of(context);
    final message = widget.message;

    try {
      if (message.type == MessageType.text) {
        await SharePlus.instance.share(ShareParams(text: message.content));
        return;
      }

      // Média chiffré : partager le fichier déjà déchiffré (cache), jamais
      // le blob que `fileUrl` désigne.
      final mediaChiffre = message.mediaChiffre;
      if (mediaChiffre != null) {
        final chemin = await ref.read(
          mediaDechiffreProvider(
            DemandeMediaDechiffre(message.id, mediaChiffre),
          ).future,
        );
        final legende =
            message.content.isNotEmpty && message.content != message.fileName
                ? message.content
                : '';
        await SharePlus.instance.share(
          ShareParams(files: [XFile(chemin)], text: legende),
        );
        return;
      }

      final url = message.fileUrl;
      if (url == null || url.isEmpty) {
        scaffold.showSnackBar(
          SnackBar(
            content: Text(l10n.shareError),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      scaffold.showSnackBar(
        SnackBar(
          content: Text(l10n.shareDownloadingMedia),
          duration: const Duration(seconds: 1),
        ),
      );

      String fileName = message.fileName ?? '';
      if (fileName.isEmpty) {
        final ext = url.split('.').last.split('?').first;
        final sanitized = ext.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
        fileName =
            'shared_${message.type.name}_${DateTime.now().millisecondsSinceEpoch}.${sanitized.isNotEmpty ? sanitized : 'file'}';
      }

      final file = await FileDownloadService().downloadToTemp(
        url,
        fileName: fileName,
      );

      if (file == null) {
        scaffold.showSnackBar(
          SnackBar(
            content: Text(l10n.shareError),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final caption =
          message.content.isNotEmpty &&
                  message.content != message.fileName &&
                  message.content != message.fileUrl
              ? message.content
              : '';

      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: caption),
      );
    } catch (e) {
      scaffold.showSnackBar(
        SnackBar(
          content: Text(l10n.shareError),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleLinkTap(_LinkMatch match) async {
    switch (match.type) {
      case _LinkType.url:
        // Un lien de l'app s'ouvre dans l'app, empilé sur la discussion. La
        // boîte de confirmation protège d'un site tiers, pas de nos propres
        // écrans — et par `launchUrl`, Android renvoyait le lien à l'app, dont
        // le `router.go` effaçait la discussion de la pile.
        final route = QrCodeParser.routeInterne(match.text);
        if (route != null) {
          if (mounted) unawaited(context.push(route));
          break;
        }
        final confirmed = await _showUrlConfirmDialog(match.text);
        if (confirmed == true) {
          await _openFile(match.text);
        }
        break;
      case _LinkType.phone:
        final cleanNumber = match.text.replaceAll(RegExp(r'[\s.\-()]'), '');
        final confirmed = await _showPhoneConfirmDialog(cleanNumber);
        if (confirmed == true) {
          final uri = Uri.parse('tel:$cleanNumber');
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri);
          }
        }
        break;
      case _LinkType.email:
        final uri = Uri.parse('mailto:${match.text}');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
        break;
      case _LinkType.mention:
        // `match.text` porte le `@` : le pseudo commence après.
        final handle = match.text.startsWith('@')
            ? match.text.substring(1)
            : match.text;
        final userId = widget.message.mentionedUsers
            .where((m) => mentionHandleMatches(m.name, handle))
            .map((m) => m.id)
            .firstOrNull;
        if (userId != null && mounted) unawaited(context.push('/profile/$userId'));
        break;
    }
  }

  Future<bool?> _showPhoneConfirmDialog(String phoneNumber) {
    final l10n = AppLocalizations.of(context)!;
    return showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.phone, color: AppColors.success),
                const SizedBox(width: 8),
                Text(l10n.audioCall),
              ],
            ),
            content: Text('${l10n.callConfirmMessage} $phoneNumber ?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l10n.audioCall),
              ),
            ],
          ),
    );
  }

  Future<bool?> _showUrlConfirmDialog(String url) {
    final l10n = AppLocalizations.of(context)!;
    return showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  Icons.open_in_browser,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(l10n.openLink),
              ],
            ),
            content: Text('${l10n.openLinkConfirmMessage}\n\n$url'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l10n.open),
              ),
            ],
          ),
    );
  }
}

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
