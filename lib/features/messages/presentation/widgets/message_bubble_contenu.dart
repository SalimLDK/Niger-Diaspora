part of 'message_bubble.dart';

/// Ce que la bulle affiche : contenu, citation, texte enrichi, ligne de
/// métadonnées, accusés.
extension _ContenuBulle on _MessageBubbleState {
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
        // Économiseur de données D'ABORD, déchiffrement ensuite : une vidéo
        // pèse lourd, et `MediaChiffreGate` la télécharge en entier pour la
        // déchiffrer. Sans la barrière, une vidéo chiffrée était lue sur son
        // `fileUrl` — un blob illisible —, chez l'expéditeur comme chez le
        // destinataire. Les images, documents et sons y passaient déjà.
        return DataSaverGate(
          messageId: widget.message.id,
          isMe: widget.isMe,
          blurhash: widget.message.blurhash,
          fileSize: widget.message.fileSize,
          builder: (context) => MediaChiffreGate(
          message: widget.message,
          aspectRatio: 16 / 9,
          builder: (context, m) => VideoBubble(
          videoUrl: m.fileUrl ?? '',
          thumbnailUrl: widget.message.thumbnailUrl,
          duration: widget.message.videoDuration,
          caption: videoCaption,
          isMe: widget.isMe,
          showSenderInfo: widget.showSenderInfo && !widget.isMe,
          senderName: widget.message.senderName,
          messageId: widget.message.id,
          blurhash: widget.message.blurhash,
          onTap:
              m.fileUrl != null
                  ? () => VideoPlayerScreen.show(
                        context,
                        videoUrl: m.fileUrl!,
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
              m.fileUrl != null
                  ? () => _saveVideoToDevice(m.fileUrl!)
                  : null,
          onShare: () => _shareMessage(),
          // Appui long = menu complet (permet d'épingler une vidéo, etc.).
          onLongPress: _onLongPress,
          ),
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
    // Une carte dont l'URL n'est pas un lien du texte n'est pas montrée :
    // voir LinkPreviewBubble.
    final hasLinkPreview = LinkPreviewBubble.urlFiable(
          linkPreviewData,
          widget.message.content,
        ) !=
        null;

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
            LinkPreviewBubble.fromMap(
              linkPreviewData!,
              isMe: widget.isMe,
              confirmerOuverture: _showUrlConfirmDialog,
            ),
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
}

