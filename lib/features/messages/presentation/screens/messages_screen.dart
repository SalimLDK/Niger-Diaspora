import 'package:flutter/material.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../settings/presentation/providers/blocked_users_provider.dart';
import '../providers/conversation_actions_provider.dart';
import '../../domain/entities/conversation_entity.dart';
import '../providers/message_provider.dart';
import '../widgets/conversation_item.dart';
import '../../../../core/theme/design_kit.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../../../shared/widgets/sheet_handle.dart';

/// Filtres rapides de la liste, en puces sous l'en-tête (§9a : Tous / Non lus
/// / Groupes / Archives, un seul rang de puces mutuellement exclusives).
enum _MessagesFilter { all, unread, groups, archives }

class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  _MessagesFilter _filter = _MessagesFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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

    showModalBottomSheet(
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
                    ref
                        .read(conversationActionsNotifierProvider.notifier)
                        .archiveConversation(conversation.id, !isArchived);
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
                    ref
                        .read(conversationActionsNotifierProvider.notifier)
                        .muteConversation(conversation.id, !isMuted);
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
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    ConversationEntity conversation,
  ) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
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
                  ref
                      .read(conversationActionsNotifierProvider.notifier)
                      .deleteConversation(conversation.id);
                },
                child: Text(
                  l10n.delete,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final conversationsAsync = ref.watch(conversationsProvider);
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final blockedUsers = ref.watch(blockedUsersProvider).valueOrNull ?? [];
    final blockedUserIds = blockedUsers.map((u) => u.id).toSet();

    // Total de non-lus affiché sous le titre. Les archives en sont exclues :
    // ce compteur décrit ce qui attend l'utilisateur dans sa liste courante.
    final headerUserId = currentUser?.id ?? '';
    final unreadTotal = (conversationsAsync.valueOrNull ?? [])
        .where((conv) => !conv.isArchivedBy(headerUserId))
        .fold<int>(
          0,
          (sum, conv) => sum + conv.getUnreadCountFor(headerUserId),
        );

    // Ligne de contexte sous le titre (§9a) : ce qui attend l'utilisateur,
    // et combien de groupes sont vivants dans sa liste courante.
    final activeGroups =
        (conversationsAsync.valueOrNull ?? [])
            .where(
              (conv) => conv.isGroup && !conv.isArchivedBy(headerUserId),
            )
            .length;
    final subtitleParts = <String>[
      if (unreadTotal > 0) l10n.unreadConversations(unreadTotal),
      if (activeGroups > 0) l10n.messagesActiveGroups(activeGroups),
    ];

    return Scaffold(
      backgroundColor: context.backgroundColor,
      // En-tête plat sur le fond crème (§9a) : le bandeau dégradé et son FAB
      // ont disparu au profit d'un grand titre serif et de deux actions
      // carrées, dont « composer » en terracotta plein.
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            DesignScreenHeader(
              title: l10n.messagesTitle,
              subtitle: subtitleParts.join(' · '),
              actions: [
                DesignSquareAction(
                  icon: Icons.inbox_outlined,
                  tooltip: l10n.archives,
                  onPressed:
                      () => setState(() => _filter = _MessagesFilter.archives),
                ),
                DesignSquareAction(
                  icon: Icons.edit_outlined,
                  filled: true,
                  tooltip: l10n.newConversation,
                  onPressed: () => context.push('/messages/new'),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: DesignSearchField(
                controller: _searchController,
                hintText: l10n.searchPlaceholder,
                onChanged: (value) => setState(() => _searchQuery = value),
                onClear: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              ),
            ),
            _buildFilterChips(context, l10n, unreadTotal),
            Expanded(
              child: conversationsAsync.when(
                skipLoadingOnRefresh: true,
                skipLoadingOnReload: true,
                data: (conversations) {
                  final currentUserId = currentUser?.id ?? '';

                  // Build participant names map for individual conversations
                  final participantNames = <String, String>{};
                  for (final conv in conversations) {
                    if (conv.isIndividual) {
                      final otherUserId = conv.getOtherParticipantId(
                        currentUserId,
                      );
                      if (otherUserId.isNotEmpty &&
                          !participantNames.containsKey(otherUserId)) {
                        final profileAsync = ref.watch(
                          userStreamProvider(otherUserId),
                        );
                        final profile = profileAsync.valueOrNull;
                        if (profile != null) {
                          participantNames[otherUserId] =
                              profile.displayName ?? '';
                        }
                      }
                    }
                  }

                  return _buildConversationList(
                    conversations: conversations,
                    currentUserId: currentUserId,
                    showArchived: _filter == _MessagesFilter.archives,
                    blockedUserIds: blockedUserIds,
                    participantNames: participantNames,
                  );
                },
                loading:
                    () => Center(
                      child: CircularProgressIndicator(
                        color: context.adaptivePrimaryColor,
                      ),
                    ),
                error:
                    (error, _) => Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AppIcon(
                            AppIcon.error,
                            size: 48,
                            color: context.textTertiaryColor,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            l10n.loadingError,
                            style: TextStyle(
                              color: context.textSecondaryColor,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed:
                                () => ref.invalidate(conversationsProvider),
                            child: Text(l10n.retry),
                          ),
                        ],
                      ),
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Messagerie vide (§9e) : pastille ronde, titre serif, explication qui
  /// mentionne le chiffrement, puis les deux amorces d'action.
  ///
  /// Les maquettes proposent en plus deux suggestions nommées (un membre
  /// proche, un groupe de la ville) : elles ne sont pas câblées ici, cet
  /// écran ne charge ni la liste des membres proches ni les groupes
  /// populaires — ce serait inventer des données.
  Widget _buildEmptyState(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
      child: DesignEmptyState(
        icon: Icons.chat_bubble_outline,
        title: l10n.noConversation,
        body: l10n.startChatting,
        children: [
          DesignPrimaryButton(
            label: l10n.newConversation,
            onPressed: () => context.push('/messages/new'),
          ),
          const SizedBox(height: 10),
          DesignSecondaryButton(
            label: l10n.emptyMessagesJoinGroup,
            onPressed: () => context.push('/groups'),
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

  /// Puces de filtre rapide (§9a : Tous / Non lus / Groupes / Archives, un
  /// seul rang mutuellement exclusif). Masquées seulement en recherche.
  Widget _buildFilterChips(
    BuildContext context,
    AppLocalizations l10n,
    int unreadTotal,
  ) {
    // Pendant une recherche, les puces disparaissent : le résultat porte sur
    // toute la messagerie, pas sur le filtre courant.
    if (_searchQuery.isNotEmpty) return const SizedBox.shrink();

    final entries = <(_MessagesFilter, String, int)>[
      (_MessagesFilter.all, l10n.filterAll, 0),
      (_MessagesFilter.unread, l10n.filterUnread, unreadTotal),
      (_MessagesFilter.groups, l10n.filterGroups, 0),
      (_MessagesFilter.archives, l10n.archives, 0),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 2),
      child: SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: entries.length,
          separatorBuilder: (_, __) => const SizedBox(width: 9),
          itemBuilder: (context, index) {
            final (value, label, count) = entries[index];
            return DesignFilterChip(
              label: label,
              count: count,
              selected: _filter == value,
              onTap: () => setState(() => _filter = value),
            );
          },
        ),
      ),
    );
  }

  /// Ouvre « Mes notes » : récupère (ou crée à la volée) la conversation dont
  /// l'utilisateur est l'unique participant, puis navigue avec le flag dédié
  /// qui désactive les appels et bascule le menu « + » en brouillon de sondage.
  Future<void> _openSelfNotes() async {
    final conversation =
        await ref.read(ensureSelfNotesProvider.notifier).ensure();
    if (!mounted) return;

    if (conversation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Impossible d'ouvrir Mes notes pour le moment"),
        ),
      );
      return;
    }

    context.push(
      '/messages/${conversation.id}',
      extra: {
        'name': AppLocalizations.of(context)!.messagesMyNotes,
        'isGroup': false,
        'isSelfNotes': true,
      },
    );
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

    // Liste d'entrées : marqueurs d'en-tête (String) + conversations.
    final entries = <Object>[];
    if (showSelfNotesTile) entries.add(_kSelfNotesMarker);
    if (useSections) {
      entries.add(l10n.pinnedSection);
      entries.addAll(pinned);
      if (others.isNotEmpty) entries.add(l10n.otherConversations);
      entries.addAll(others);
    } else {
      entries.addAll(filtered);
    }

    ConversationItem buildItem(
      ConversationEntity conversation, {
      required bool flat,
    }) => ConversationItem(
      conversation: conversation,
      currentUserId: currentUserId,
      flat: flat,
      onTap: () {
        context.push(
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
        );
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
      if (showSelfNotesTile || others.isNotEmpty) {
        children.add(DesignSectionLabel(l10n.otherConversations));
      }
    } else if (showSelfNotesTile || filtered.isNotEmpty) {
      children.add(const SizedBox(height: 8));
    }

    final flatEntries = <Object>[
      if (showSelfNotesTile) _kSelfNotesMarker,
      ...(useSections ? others : filtered),
    ];
    for (var i = 0; i < flatEntries.length; i++) {
      if (i > 0) {
        children.add(
          Divider(height: 1, thickness: 1, color: context.dividerColor),
        );
      }
      final entry = flatEntries[i];
      children.add(
        entry == _kSelfNotesMarker
            ? _buildSelfNotesTile(context)
            : buildItem(entry as ConversationEntity, flat: true),
      );
    }

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

/// Marqueur interne pour la tuile « Mes notes » dans la liste d'entrées.
const String _kSelfNotesMarker = '__self_notes__';
