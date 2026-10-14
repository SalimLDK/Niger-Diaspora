part of 'messages_screen.dart';

/// Filtrage, options et rendu de la liste des discussions, notes
/// personnelles.
extension _ListeDiscussions on _MessagesScreenState {
  List<ConversationEntity> _filterConversations(
    List<ConversationEntity> conversations, {
    required String currentUserId,
    required bool showArchived,
    required Set<String> blockedUserIds,
    required Map<String, String> participantNames,
  }) {
    // Filter by archived status
    var filtered = conversations;
    filtered =
        filtered.where((conv) {
          final isArchived = conv.isArchivedBy(currentUserId);
          return showArchived ? isArchived : !isArchived;
        }).toList();

    // « Mes notes » (self-chat) a sa propre tuile épinglée en tête de liste :
    // on la retire d'ici, sinon elle apparaîtrait deux fois.
    filtered =
        filtered.where((conv) => !conv.isSelfNotesFor(currentUserId)).toList();

    // Puces de filtre rapide. « archives » est déjà géré par le filtre
    // showArchived ci-dessus (les 2 se déduisent de la même puce active).
    if (!showArchived) {
      switch (_filter) {
        case _MessagesFilter.all:
        case _MessagesFilter.archives:
          break;
        case _MessagesFilter.unread:
          filtered =
              filtered
                  .where((conv) => conv.hasUnreadFor(currentUserId))
                  .toList();
        case _MessagesFilter.groups:
          filtered = filtered.where((conv) => conv.isGroup).toList();
      }
    }

    // Then filter by search query if any
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered =
          filtered.where((conv) {
            // Search by conversation name (for groups)
            final name = (conv.name ?? '').toLowerCase();
            if (name.contains(query)) {
              return true;
            }

            // Search by last message
            final lastMessage = (conv.lastMessage ?? '').toLowerCase();
            if (lastMessage.contains(query)) {
              return true;
            }

            // For individual conversations, search by other participant's name
            if (conv.isIndividual) {
              final otherUserId = conv.getOtherParticipantId(currentUserId);
              if (otherUserId.isNotEmpty) {
                final displayName =
                    (participantNames[otherUserId] ?? '').toLowerCase();
                if (displayName.contains(query)) {
                  return true;
                }
              }
            }

            return false;
          }).toList();
    }

    return filtered;
  }

  void _showConversationOptions(
    BuildContext context,
    ConversationEntity conversation,
    String currentUserId,
  ) {
    if (conversation.isGroup &&
        !conversation.participantIds.contains(currentUserId)) {
      // User left group logic if needed, but for now just actions
    }

    final isArchived = conversation.isArchivedBy(currentUserId);
    final isMuted = conversation.isMutedBy(currentUserId);
    final l10n = AppLocalizations.of(context)!;

    unawaited(showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: SheetHandle(),
                ),
                ListTile(
                  leading:
                      isArchived
                          ? Icon(
                            Icons.unarchive_outlined,
                            color: context.adaptivePrimaryColor,
                          )
                          : AppIcon(
                            AppIcon.archive,
                            color: context.adaptivePrimaryColor,
                          ),
                  title: Text(
                    isArchived ? l10n.unarchive : l10n.archive,
                    style: TextStyle(color: context.textPrimaryColor),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    unawaited(ref
                        .read(conversationActionsNotifierProvider.notifier)
                        .archiveConversation(conversation.id, !isArchived));
                  },
                ),
                ListTile(
                  leading: Icon(
                    isMuted
                        ? Icons.notifications_off_outlined
                        : Icons.notifications_outlined,
                    color: context.adaptivePrimaryColor,
                  ),
                  title: Text(
                    isMuted ? l10n.unmute : l10n.mute,
                    style: TextStyle(color: context.textPrimaryColor),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    unawaited(ref
                        .read(conversationActionsNotifierProvider.notifier)
                        .muteConversation(conversation.id, !isMuted));
                  },
                ),
                ListTile(
                  leading: const AppIcon(AppIcon.delete, color: Colors.red),
                  title: Text(
                    l10n.delete,
                    style: const TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showDeleteConfirmation(context, conversation);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
    ));
  }

  void _showDeleteConfirmation(
    BuildContext context,
    ConversationEntity conversation,
  ) {
    final l10n = AppLocalizations.of(context)!;
    unawaited(showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(l10n.deleteConversation),
            content: Text(l10n.confirmDeleteConversation),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.cancel),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  unawaited(ref
                      .read(conversationActionsNotifierProvider.notifier)
                      .deleteConversation(conversation.id));
                },
                child: Text(
                  l10n.delete,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    ));
  }

  /// Messagerie vide (fiche 9e) : pastille ronde, titre, explication qui
  /// mentionne le chiffrement, deux amorces nommées, puis le CTA.
  ///
  /// La fiche propose deux suggestions (un membre proche, un groupe de la
  /// ville). Elles ne s'affichent que si la donnée existe vraiment : la ligne
  /// « membre proche » lit l'état déjà chargé par l'accueil sans redemander
  /// la localisation, et la ligne groupe s'appuie sur la ville du profil.
  /// Aucune des deux n'apparaît en repli fabriqué.
  Widget _buildEmptyState(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
      child: DesignEmptyState(
        icon: Icons.chat_bubble_outline,
        title: l10n.noConversation,
        body: l10n.startChatting,
        children: [
          const _EmptyStateSuggestions(),
          DesignPrimaryButton(
            label: l10n.newConversation,
            onPressed: () => context.push('/messages/new'),
          ),
          const SizedBox(height: 20),
          DesignInfoLine(
            icon: Icons.lock_outline,
            text: l10n.e2eeDescription,
            center: true,
          ),
        ],
      ),
    );
  }

  /// Ouvre « Mes notes » : récupère (ou crée à la volée) la conversation dont
  /// l'utilisateur est l'unique participant, puis navigue avec le flag dédié
  /// qui désactive les appels et bascule le menu « + » en brouillon de sondage.
  Future<void> _openSelfNotes() async {
    final conversation =
        await ref.read(ensureSelfNotesProvider.notifier).ouvrir();
    if (!mounted) return;

    if (conversation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Impossible d'ouvrir Mes notes pour le moment"),
        ),
      );
      return;
    }

    unawaited(context.push(
      '/messages/${conversation.id}',
      extra: {
        'name': AppLocalizations.of(context)!.messagesMyNotes,
        'isGroup': false,
        'isSelfNotes': true,
      },
    ));
  }

  /// Tuile épinglée « Mes notes », toujours en tête de liste (hors recherche
  /// et hors archives). L'aperçu reprend le dernier contenu noté s'il existe.
  Widget _buildSelfNotesTile(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final selfConversation = ref.watch(selfNotesConversationProvider);
    final lastNote = selfConversation?.lastMessage?.trim();
    final subtitle =
        (lastNote != null && lastNote.isNotEmpty)
            ? lastNote
            : l10n.messagesMyNotesSubtitle;
    final isOpening = ref.watch(ensureSelfNotesProvider).isLoading;

    // Ligne à plat comme les autres conversations (§9a) : le bandeau
    // terracotta et le badge « Épinglé » ont disparu. La tuile reste en
    // revanche en tête de liste, pour rester joignable en un coup d'œil.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isOpening ? null : _openSelfNotes,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: context.surfaceVariantColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child:
                      isOpening
                          ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: context.adaptivePrimaryColor,
                            ),
                          )
                          : Icon(
                            Icons.bookmark_border,
                            size: 21,
                            color: context.adaptivePrimaryColor,
                          ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.messagesMyNotes,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildConversationList({
    required List<ConversationEntity> conversations,
    required String currentUserId,
    required bool showArchived,
    required Set<String> blockedUserIds,
    required Map<String, String> participantNames,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final filtered = _filterConversations(
      conversations,
      currentUserId: currentUserId,
      showArchived: showArchived,
      blockedUserIds: blockedUserIds,
      participantNames: participantNames,
    );

    // La tuile « Mes notes » n'a de sens que sur la liste principale : ni dans
    // les archives, ni au milieu de résultats de recherche.
    final showSelfNotesTile = !showArchived && _searchQuery.isEmpty;

    if (filtered.isEmpty) {
      if (_searchQuery.isNotEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppIcon(
                AppIcon.searchOff,
                size: 64,
                color: context.textTertiaryColor.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.noResults(_searchQuery),
                style: TextStyle(
                  fontSize: 16,
                  color: context.textSecondaryColor,
                ),
              ),
            ],
          ),
        );
      }

      if (showArchived) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppIcon(
                AppIcon.archive,
                size: 64,
                color: context.textTertiaryColor.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.noArchivedConversation,
                style: TextStyle(
                  fontSize: 16,
                  color: context.textSecondaryColor,
                ),
              ),
            ],
          ),
        );
      }

      // Une puce de filtre active qui ne ramène rien n'est PAS une messagerie
      // vide. `_buildEmptyState` (fiche 9e) annonçait « Aucune conversation /
      // Commencez à discuter » et proposait « Nouvelle conversation » alors que
      // la vérité était « aucune conversation non lue » ou « aucun groupe » —
      // le message mentait sur le filtre actif, et l'action proposée ne
      // répondait pas au problème. Les libellés existaient déjà dans les `.arb`
      // (`noUnreadMessages`, `noGroupConversations`, `showAllConversations`),
      // ils n'étaient simplement câblés nulle part.
      if (_filter == _MessagesFilter.unread ||
          _filter == _MessagesFilter.groups) {
        return _buildFilteredEmptyState(
          context,
          icon: _filter == _MessagesFilter.unread
              ? AppIcon.doneAll
              : AppIcon.groups,
          message: _filter == _MessagesFilter.unread
              ? l10n.noUnreadMessages
              : l10n.noGroupConversations,
        );
      }

      // Messagerie vide : la tuile « Mes notes » reste accessible.
      if (!showSelfNotesTile) return _buildEmptyState(context);
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: _buildSelfNotesTile(context),
          ),
          Expanded(child: _buildEmptyState(context)),
        ],
      );
    }

    // Section « Épinglées » séparée (§9a), hors recherche/archives.
    final pinned = <ConversationEntity>[];
    final others = <ConversationEntity>[];
    for (final c in filtered) {
      (c.isPinnedBy(currentUserId) ? pinned : others).add(c);
    }
    final useSections =
        !showArchived && _searchQuery.isEmpty && pinned.isNotEmpty;

    ConversationItem buildItem(
      ConversationEntity conversation, {
      required bool flat,
    }) => ConversationItem(
      conversation: conversation,
      currentUserId: currentUserId,
      flat: flat,
      onTap: () {
        unawaited(context.push(
          '/messages/${conversation.id}',
          extra: {
            'name': conversation.name ?? 'Conversation',
            'imageUrl': conversation.imageUrl,
            'isGroup': conversation.isGroup,
            'groupId': conversation.groupId,
            'otherUserId':
                conversation.isGroup
                    ? null
                    : conversation.getOtherParticipantId(currentUserId),
          },
        ));
      },
      onLongPress:
          () => _showConversationOptions(context, conversation, currentUserId),
    );

    // Mise en page du §9a : les épinglées forment une carte blanche groupée,
    // le reste de la liste est posé à plat sur le fond, lignes séparées par
    // un filet.
    final children = <Widget>[];
    if (useSections) {
      children.add(DesignSectionLabel(l10n.pinnedSection));
      children.add(
        DesignListCard(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [
            for (final c in pinned) buildItem(c, flat: true),
          ],
        ),
      );
    }

    // Le reste de la liste se regroupe par période (fiche 9a : « Cette
    // semaine », puis le plus ancien) au lieu d'un fourre-tout « Autres ».
    // Les conversations sans date atterrissent dans le plus ancien plutôt
    // que de disparaître.
    final now = DateTime.now();
    final rest = useSections ? others : filtered;
    final thisWeek = <ConversationEntity>[];
    final older = <ConversationEntity>[];
    for (final c in rest) {
      final at = c.lastMessageAt?.toLocal();
      if (at != null && now.difference(at).inDays < 7) {
        thisWeek.add(c);
      } else {
        older.add(c);
      }
    }

    void addFlatSection(String? label, List<Object> items) {
      if (items.isEmpty) return;
      if (label != null) {
        children.add(DesignSectionLabel(label));
      } else {
        children.add(const SizedBox(height: 8));
      }
      for (var i = 0; i < items.length; i++) {
        if (i > 0) {
          children.add(
            Divider(height: 1, thickness: 1, color: context.dividerColor),
          );
        }
        final entry = items[i];
        children.add(
          entry == _kSelfNotesMarker
              ? _buildSelfNotesTile(context)
              : buildItem(entry as ConversationEntity, flat: true),
        );
      }
    }

    // Les intertitres de période valent pour la liste principale, même sans
    // épinglée : ni les archives ni des résultats de recherche ne se
    // découpent en « Cette semaine ».
    final showTimeSections = !showArchived && _searchQuery.isEmpty;
    addFlatSection(showTimeSections ? l10n.thisWeek : null, [
      if (showSelfNotesTile) _kSelfNotesMarker,
      ...thisWeek,
    ]);
    addFlatSection(showTimeSections ? l10n.older : null, older);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(conversationsProvider);
      },
      color: context.adaptivePrimaryColor,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          10 + MediaQuery.of(context).padding.bottom,
        ),
        children: children,
      ),
    );
  }
}

