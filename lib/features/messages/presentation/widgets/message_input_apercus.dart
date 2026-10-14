part of 'message_input.dart';

/// Aperçus de réponse et de modification, compteur, bouton d'action.
extension _ApercusSaisie on _MessageInputState {
  /// Bandeau « Modifier le message » : le texte d'origine, et la croix pour
  /// ressortir. Même gabarit que le bandeau de réponse — c'est le même geste
  /// au même endroit, seuls l'icône et la couleur changent.
  Widget _buildEditPreview(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final accent = context.adaptivePrimaryColor;

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
              color: accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Icon(Icons.edit_outlined, size: 18, color: accent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.editMessage,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.editingMessage!.content,
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
            onPressed: widget.onCancelEdit,
            tooltip: l10n.cancel,
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
          // Un appui long en modification ne doit pas lancer un vocal : le
          // bouton n'est plus un micro, il applique.
          onLongPressStart: !_hasText && _peutEnregistrer
              ? (_) {
                  _appuiMicro = true;
                  unawaited(_startRecording());
                }
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
            _appuiMicro = false;
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
    if (_hasText || _peutEnregistrer) {
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
    if (_isRecording || _hasText || _peutEnregistrer) {
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
    if (_hasText || _peutEnregistrer) {
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

    // En modification : une coche, jamais le micro. Grisée tant que le champ
    // est vide — un message modifié à vide n'est pas une suppression, et le
    // laisser partir effaçait le texte sans rien dire.
    if (_enModification) {
      return AppIcon(
        AppIcon.check,
        color: _hasText ? AppColors.white : context.textTertiaryColor,
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
                  _peutEnregistrer
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

