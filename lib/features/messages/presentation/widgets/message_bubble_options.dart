part of 'message_bubble.dart';

/// Réactions, appui long et feuilles d'options d'un message.
extension _OptionsBulle on _MessageBubbleState {
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
}

