part of 'conversation_screen.dart';

/// Ouverture, défilement, transfert, suppression multiple, sondages.
extension _ActionsConversation on _ConversationScreenState {
  /// Travail d'ouverture réservé aux groupes. Idempotent : appelé à
  /// l'ouverture puis à chaque réconciliation, chaque effet ne part qu'une fois.
  void _runGroupOpenWork() {
    if (!_isGroup) return;

    // Clear unread mention badge when opening a group conversation
    if (!_unreadMentionsCleared) {
      final userId = ref.read(currentUserProvider).valueOrNull?.id;
      if (userId != null) {
        _unreadMentionsCleared = true;
        unawaited(ref
            .read(messageRepositoryProvider)
            .clearUnreadMentions(
              conversationId: widget.conversationId,
              userId: userId,
            ));
      }
    }

    if (!_privateGroupFilterRequested && _effectiveGroupId != null) {
      _privateGroupFilterRequested = true;
      unawaited(_setupPrivateGroupFilter());
    }
  }

  /// Configure le filtre de messages pour les groupes privés
  /// Les nouveaux membres ne voient pas les messages envoyés avant leur adhésion
  Future<void> _setupPrivateGroupFilter() async {
    if (!_isGroup || _effectiveGroupId == null) return;

    final currentUser = ref.read(currentUserProvider).valueOrNull;
    if (currentUser == null) return;

    try {
      // Récupérer les informations du groupe via le repository
      final repository = ref.read(groupRepositoryProvider);
      final result = await repository.getGroupById(_effectiveGroupId!);

      final group = result.fold((failure) => null, (group) => group);
      if (group == null) return;

      // Vérifier si c'est un groupe privé
      if (!group.isPrivate) return;

      // Récupérer la date d'adhésion de l'utilisateur
      final joinedAt = group.memberJoinedAt[currentUser.id];

      if (joinedAt != null) {
        // Appliquer le filtre pour ne montrer que les messages après l'adhésion
        ref
            .read(paginatedMessagesProvider(widget.conversationId).notifier)
            .setFilterDate(joinedAt);
      }
    } catch (e) {
      // En cas d'erreur, ne pas appliquer de filtre (fail-safe)
      // debugPrint('⚠️ Error setting up private group filter: $e');
    }
  }

  /// Scroll vers le premier message non lu (si nécessaire)
  /// Avec reverse: true, la liste démarre déjà au bas (position 0 = messages récents)
  void _scrollToUnreadOrBottom(int? unreadIndex, int totalMessages) {
    if (_hasScrolledToInitialPosition) return;
    _hasScrolledToInitialPosition = true;

    // Avec reverse: true, la liste démarre au bas (position 0)
    // Donc pas besoin de scroll si pas de messages non lus
    if (unreadIndex == null) {
      _apresPlacement();
      return;
    }

    // Attendre que le ListView soit complètement rendu
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Chaque sortie pose la vue : un placement impossible reste un
      // placement, et la lecture de ce qui est à l'écran doit partir.
      if (!mounted || !_scrollController.hasClients) {
        _apresPlacement();
        return;
      }

      final maxExtent = _scrollController.position.maxScrollExtent;
      if (maxExtent <= 0) {
        _apresPlacement();
        return;
      }

      // Avec reverse: true, l'index dans la liste inversée est:
      // reversedIndex = totalMessages - 1 - unreadIndex
      // Position = (reversedIndex / totalMessages) * maxExtent
      final reversedIndex = totalMessages - 1 - unreadIndex;
      final ratio = reversedIndex / totalMessages;
      final targetPosition = (maxExtent * ratio).clamp(0.0, maxExtent);

      _scrollController.jumpTo(targetPosition);
      // Le saut s'applique à l'image suivante : c'est elle que
      // [_apresPlacement] attend, pas celle-ci, où la liste est encore en bas.
      _apresPlacement();
    });
  }

  void _onScroll() {
    // With reverse: true, maxScrollExtent is at the TOP (oldest messages)
    // and pixels = 0 is at the BOTTOM (newest messages)
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    // Check if we're near the top (oldest messages) to load more
    if ((maxScroll - currentScroll) <= 100) {
      final paginationState = ref.read(
        paginatedMessagesProvider(widget.conversationId),
      );
      if (paginationState.canLoadMore) {
        unawaited(ref
            .read(paginatedMessagesProvider(widget.conversationId).notifier)
            .loadMore());
      }
    }

    // Track if we're near bottom (newest messages = near pixels 0)
    _isNearBottom = currentScroll <= 100;

    // Show/hide scroll to bottom button (show when scrolled up from bottom)
    final shouldShowButton = currentScroll > 300;
    if (shouldShowButton != _showScrollToBottomButton.value) {
      _showScrollToBottomButton.value = shouldShowButton;
      if (shouldShowButton) {
        unawaited(_scrollButtonController.forward());
      } else {
        unawaited(_scrollButtonController.reverse());
      }
    }
  }

  void _scrollToBottom() {
    // With reverse: true, position 0 is at the bottom (newest messages)
    if (_scrollController.hasClients) {
      unawaited(_scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      ));
    }
  }

  MessageEntity? _getReplyEntity(MessageEntity message) {
    // Check for null or empty replyToMessageData
    if (message.replyToMessageData == null ||
        message.replyToMessageData!.isEmpty) {
      return null;
    }
    final data = message.replyToMessageData!;

    // Validate required fields exist
    if (data['id'] == null || data['senderId'] == null) {
      // debugPrint(
      //   '⚠️ Invalid reply data: missing id or senderId. Data: $data',
      // );
      return null;
    }

    try {
      return MessageEntity(
        id: data['id'] as String? ?? '',
        senderId: data['senderId'] as String? ?? '',
        senderName:
            data['senderName'] as String? ?? AppLocalizations.of(context)!.user,
        content: data['content'] as String? ?? '',
        type: MessageType.values.firstWhere(
          (e) => e.name == data['type'],
          orElse: () => MessageType.text,
        ),
        createdAt: DateTime.now(),
        readBy: const [],
        readAt: const {},
        fileUrl: data['fileUrl'] as String?,
        fileName: data['fileName'] as String?,
      );
    } catch (e) {
      // debugPrint('❌ Error parsing reply entity: $e');
      // debugPrint('   Data: $data');
      return null;
    }
  }

  void _handleForward(MessageEntity message) {
    unawaited(ForwardConversationPicker.show(context, messages: [message]));
  }

  // Fonctionnalité épingle mise en pause (2026-08-14) : `_pinMessage`,
  // `_unpinMessage` et `_refreshPinnedBanner` n'ont plus d'appelant (`canPin`
  // figé à `false` plus bas fait retomber `onPin`/`onUnpin` sur `null`).
  // Gardées en commentaire pour réactivation plutôt que supprimées — voir
  // aussi group_pinned_banner.dart et `_GroupInfoCard` dans
  // group_detail_screen.dart pour le reste de la pause.
  //
  // Future<void> _pinMessage(MessageEntity message) async {
  //   final currentUserId = ref.read(currentUserProvider).valueOrNull?.id;
  //   if (currentUserId == null) return;
  //
  //   // Un message encore optimiste porte un id local `temp_…` (message_provider)
  //   // qui n'existera JAMAIS côté serveur : l'épingler enregistrait une entrée
  //   // définitivement irrésolvable — le bandeau la lisait « Élément
  //   // indisponible », ou masquait tout quand c'était la seule épingle. Deux
  //   // orphelines de ce type ont été trouvées en base (16 et 17/07/2026).
  //   if (message.id.startsWith('temp_')) {
  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(
  //           content: Text('Attendez l\'envoi du message pour l\'épingler'),
  //         ),
  //       );
  //     }
  //     return;
  //   }
  //
  //   // L'épingle est TOUJOURS portée par la conversation, groupe compris.
  //   //
  //   // `group_pinned_items.group_id` a une clé étrangère vers `groups(id)`, or
  //   // les groupes de l'app vivent encore dans Firestore : leur identifiant
  //   // (ex. `yflqsRLMMhTPpiW0NFHx`) n'existe pas dans `public.groups`, donc
  //   // l'insertion violait la contrainte et l'utilisateur voyait « Impossible
  //   // d'épingler ce message » — reproduit sur appareil le 2026-08-05. La
  //   // colonne `conversation_id` pointe, elle, sur une table réellement peuplée
  //   // dans les deux cas.
  //   //
  //   // ⚠ Contrepartie : ce sont alors les policies RLS « Conversation
  //   // participants » qui s'appliquent. La permission de groupe « qui peut
  //   // épingler » n'est plus vérifiée par la base — seul `canPin`, côté écran,
  //   // filtre encore. À revoir quand les groupes seront dans Supabase.
  //   final success = await ref
  //       .read(groupPinActionsNotifierProvider.notifier)
  //       .pinItem(
  //         conversationId: widget.conversationId,
  //         itemType: GroupPinnedItemType.message,
  //         itemId: message.id,
  //         pinnedBy: currentUserId,
  //       );
  //
  //   // Rafraîchit le bandeau immédiatement : le stream Supabase ne reçoit pas
  //   // toujours l'insert en temps réel (réplication realtime pas garantie sur
  //   // `group_pinned_items`), donc sans ça le bandeau ne s'affichait qu'au
  //   // prochain ouverture de la conversation.
  //   if (success) _refreshPinnedBanner();
  //
  //   if (mounted) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text(
  //           success ? 'Message épinglé' : 'Impossible d\'épingler ce message',
  //         ),
  //       ),
  //     );
  //   }
  // }
  //
  // /// Force le re-fetch de la liste des épingles (auto-dispose StreamProvider),
  // /// pour un affichage immédiat après épinglage/désépinglage local.
  // void _refreshPinnedBanner() {
  //   ref.invalidate(conversationPinnedItemsProvider(widget.conversationId));
  // }
  //
  // /// Détache un message épinglé depuis son menu contextuel : le bandeau ne
  // /// porte plus de croix, c'est le seul chemin de désépinglage (comme Telegram).
  // Future<void> _unpinMessage(MessageEntity message) async {
  //   final items =
  //       ref
  //           .read(conversationPinnedItemsProvider(widget.conversationId))
  //           .valueOrNull;
  //   final pin =
  //       items
  //           ?.where(
  //             (i) =>
  //                 i.itemType == GroupPinnedItemType.message &&
  //                 i.itemId == message.id,
  //           )
  //           .firstOrNull;
  //   if (pin == null) {
  //     // La liste d'épingles locale (ref.read, snapshot synchrone) ne
  //     // contenait pas ce message : sans ce retour explicite, l'utilisateur
  //     // tapait « Détacher » et rien ne se passait, sans le moindre signal.
  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text(l10n.messageUnpinFailed)),
  //       );
  //     }
  //     return;
  //   }
  //
  //   final success = await ref
  //       .read(groupPinActionsNotifierProvider.notifier)
  //       .unpinItem(pin.id);
  //
  //   // Idem épinglage : rafraîchit le bandeau immédiatement (le retrait n'est
  //   // pas garanti en temps réel via le stream Supabase).
  //   if (success) _refreshPinnedBanner();
  //
  //   if (mounted) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text(
  //           success ? 'Message détaché' : l10n.messageUnpinFailed,
  //         ),
  //       ),
  //     );
  //   }
  // }

  List<MessageEntity> _getSelectedMessages(List<MessageEntity> allMessages) {
    return allMessages.where((m) => _selectedMessageIds.contains(m.id)).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  void _copySelectedMessages(List<MessageEntity> allMessages) {
    final texte = selectionCopyText(_getSelectedMessages(allMessages));
    if (texte == null) return;
    unawaited(Clipboard.setData(ClipboardData(text: texte)));
    _exitSelectionMode();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.copiedToClipboard),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _forwardSelectedMessages(List<MessageEntity> allMessages) async {
    final selected = _getSelectedMessages(allMessages);
    if (selected.isEmpty) return;

    final result = await ForwardConversationPicker.show(
      context,
      messages: selected,
    );

    if (result == true && mounted) {
      _exitSelectionMode();
    }
  }

  Future<void> _deleteSelectedMessages(List<MessageEntity> allMessages) async {
    final selected = _getSelectedMessages(allMessages);
    if (selected.isEmpty) return;

    final currentUserId = ref.read(currentUserProvider).valueOrNull?.id;
    if (currentUserId == null) return;

    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: ctx.surfaceColor,
            title: Text(
              l10n.deleteSelectedMessages(selected.length),
              style: TextStyle(color: ctx.textPrimaryColor),
            ),
            content: Text(
              l10n.messagesDeletedForYou,
              style: TextStyle(color: ctx.textSecondaryColor),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  l10n.cancel,
                  style: TextStyle(color: ctx.textSecondaryColor),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  l10n.delete,
                  style: TextStyle(
                    color:
                        ctx.isDarkMode ? AppColors.errorDark : AppColors.error,
                  ),
                ),
              ),
            ],
          ),
    );

    if (confirmed == true && mounted) {
      // Même chemin que la suppression d'un seul message (Supabase, MLS
      // compris) : l'ancien service écrivait dans Firebase RTDB, que plus rien
      // ne lit — les messages revenaient au rechargement.
      final suppression = ref.read(deleteMessageProvider.notifier);
      final deletedCount = await suppression.deleteManyForMe(
        conversationId: widget.conversationId,
        messageIds: selected.map((m) => m.id).toList(),
      );
      final erreur = ref.read(deleteMessageProvider).error;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          erreur != null
              ? SnackBar(
                  content: Text(
                    FailureMapper.toUserFriendlyString(
                      erreur.toString(),
                      context,
                    ),
                  ),
                  backgroundColor:
                      context.isDarkMode ? AppColors.errorDark : AppColors.error,
                )
              : SnackBar(
                  content: Text(l10n.messagesDeletedSuccess(deletedCount)),
                  backgroundColor: AppColors.secondary,
                ),
        );
      }
      _exitSelectionMode();
    }
  }

  void _starSelectedMessages(List<MessageEntity> allMessages) {
    final selected = _getSelectedMessages(allMessages);
    if (selected.isEmpty) return;

    final notifier = ref.read(
      paginatedMessagesProvider(widget.conversationId).notifier,
    );
    for (final message in selected) {
      unawaited(notifier.toggleStar(message.id));
    }
    _exitSelectionMode();
  }

  Future<void> _handleReact(MessageEntity message, String emoji) async {
    // debugPrint('🎭 _handleReact called');
    try {
      await ref
          .read(paginatedMessagesProvider(widget.conversationId).notifier)
          .toggleReaction(message.id, emoji);
      // debugPrint('   ✅ Reaction toggled (optimistic)');
    } catch (e) {
      // debugPrint('  ❌ Error toggling reaction: $e');
    }
  }

  /// Cree le sondage puis le publie comme bulle de la conversation.
  ///
  /// Sans cette seconde etape, la ligne de `post_polls` n'etait lue par aucun
  /// ecran : le sondage existait en base et restait invisible partout.
  Future<void> _createAndPublishPoll(
    PollContextType contextType,
    String contextId,
  ) async {
    final poll = await showCreatePollSheet(
      context,
      contextType: contextType,
      contextId: contextId,
    );
    if (poll == null || !mounted) return;
    await _publishPollBubble(poll.id, poll.question);
  }

  /// Publie (ou republie) la bulle d'un sondage deja cree.
  ///
  /// « Reessayez » renvoyait vers la feuille de creation, qui aurait cree un
  /// SECOND sondage en laissant le premier invisible — une ligne de
  /// `post_polls` qu'aucun ecran ne lit. L'action rejoue donc l'envoi de la
  /// bulle, avec le meme identifiant.
  Future<void> _publishPollBubble(String pollId, String question) async {
    final published = await ref
        .read(sendMessageProvider.notifier)
        .sendPoll(
          conversationId: widget.conversationId,
          pollId: pollId,
          question: question,
        );

    if (!mounted || published) return;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.pollBubbleFailed),
        action: SnackBarAction(
          label: l10n.retry,
          onPressed: () => _publishPollBubble(pollId, question),
        ),
        duration: const Duration(seconds: 8),
      ),
    );
  }
}

