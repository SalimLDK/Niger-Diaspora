import 'dart:async';

import 'package:flutter/material.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../groups/presentation/providers/group_provider.dart';
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

/// Portée des résultats de recherche (fiche 9b).
///
/// La fiche prévoit aussi « Messages » et « Fichiers ». Ils sont absents ici :
/// le contenu des messages est chiffré de bout en bout, et la seule recherche
/// du dépôt (`searchMessagesInConversation`) fait un `ILIKE` Postgres sur le
/// champ chiffré — elle ne peut structurellement rien trouver. Les rétablir
/// demande un index de recherche local, pas un écran.
enum _SearchScope { all, people, conversations }

class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  String _searchQuery = '';
  _MessagesFilter _filter = _MessagesFilter.all;

  /// Recherche ouverte (fiche 9b) : l'en-tête se replie sur ← + champ actif.
  bool _searchOpen = false;
  _SearchScope _searchScope = _SearchScope.all;
  Timer? _profileSearchDebounce;

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(() {
      if (_searchFocus.hasFocus && !_searchOpen) {
        // ⚠ Défaut ouvert : le premier tap ouvre bien l'en-tête de recherche
        // et le champ garde le focus, mais le clavier ne se lève qu'au second
        // tap. Trois pistes essayées sans succès — `requestFocus` en
        // post-frame, `SystemChannels.textInput.invokeMethod('TextInput.show')`,
        // et le maintien du champ au même rang d'enfant dans la `Row` comme
        // dans la `Column`. La saisie et les résultats fonctionnent, eux.
        // Ne pas retenter à l'aveugle : instrumenter `FocusManager` d'abord.
        setState(() => _searchOpen = true);
      }
    });
  }

  @override
  void dispose() {
    _profileSearchDebounce?.cancel();
    _searchFocus.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
      _searchScope = _SearchScope.all;
    });
    // La recherche de profils tape le réseau : on attend que la frappe se
    // pose avant de partir.
    _profileSearchDebounce?.cancel();
    _profileSearchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      ref.read(searchProfilesNotifierProvider.notifier).search(value.trim());
    });
  }

  void _closeSearch() {
    _profileSearchDebounce?.cancel();
    _searchController.clear();
    _searchFocus.unfocus();
    ref.read(searchProfilesNotifierProvider.notifier).clear();
    setState(() {
      _searchQuery = '';
      _searchOpen = false;
      _searchScope = _SearchScope.all;
    });
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

    // Messagerie réellement vide (fiche 9e) : ni recherche ni puces de filtre
    // — il n'y a rien à chercher ni à filtrer — et l'entrée « Archives »
    // disparaît de l'en-tête, qui annonce simplement « Aucune conversation ».
    final isEmptyInbox =
        conversationsAsync.hasValue && conversationsAsync.value!.isEmpty;

    return Scaffold(
      backgroundColor: context.backgroundColor,
      // En-tête plat sur le fond crème (§9a) : le bandeau dégradé et son FAB
      // ont disparu au profit d'un grand titre serif et de deux actions
      // carrées, dont « composer » en terracotta plein.
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // En recherche (fiche 9b), l'en-tête se replie sur ← + champ actif.
            // Le champ garde sa place d'enfant n°2 de la colonne dans les deux
            // états : le déplacer dans un autre sous-arbre le ferait
            // reconstruire, il perdrait le focus et le clavier ne s'ouvrirait
            // jamais (constaté à l'écran).
            if (_searchOpen)
              const SizedBox.shrink()
            else
              DesignScreenHeader(
                title: l10n.messagesTitle,
                subtitle:
                    isEmptyInbox
                        ? l10n.noConversation
                        : subtitleParts.join(' · '),
                actions: [
                  if (!isEmptyInbox)
                    DesignSquareAction(
                      icon: Icons.inbox_outlined,
                      tooltip: l10n.archives,
                      onPressed:
                          () => setState(
                            () => _filter = _MessagesFilter.archives,
                          ),
                    ),
                  DesignSquareAction(
                    icon: Icons.edit_outlined,
                    filled: true,
                    tooltip: l10n.newConversation,
                    onPressed: () => context.push('/messages/new'),
                  ),
                ],
              ),
            if (isEmptyInbox && !_searchOpen)
              const SizedBox.shrink()
            else
              Padding(
                padding:
                    _searchOpen
                        ? const EdgeInsets.fromLTRB(16, 4, 16, 12)
                        : const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    // Emplacement de la flèche toujours présent, réduit à 0 de
                    // large quand la recherche est fermée. Une insertion
                    // conditionnelle décalerait le champ d'un rang dans la
                    // `Row` : Flutter le reconstruirait, et il faudrait un
                    // second tap pour lever le clavier (constaté à l'écran).
                    SizedBox(
                      width: _searchOpen ? 34 : 0,
                      height: 44,
                      child:
                          _searchOpen
                              ? GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: _closeSearch,
                                child: Center(
                                  child: AppIcon(
                                    AppIcon.arrowBack,
                                    size: 24,
                                    color: context.textPrimaryColor,
                                  ),
                                ),
                              )
                              : null,
                    ),
                    Expanded(
                      child: DesignSearchField(
                        controller: _searchController,
                        focusNode: _searchFocus,
                        active: _searchOpen,
                        // La fiche 9a annonce ce que la recherche couvre. La
                        // clé l10n `searchPlaceholder` (« Rechercher... »)
                        // sert cinq autres écrans : on ne la détourne pas.
                        hintText: 'Rechercher une personne, un message',
                        onChanged: _onSearchChanged,
                        onClear: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      ),
                    ),
                  ],
                ),
              ),
            if (!isEmptyInbox && !_searchOpen)
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

                  if (_searchOpen && _searchQuery.trim().isNotEmpty) {
                    return _buildSearchResults(
                      conversations: conversations,
                      currentUserId: currentUserId,
                      blockedUserIds: blockedUserIds,
                      participantNames: participantNames,
                    );
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

  /// Résultats de recherche (fiche 9b) : les personnes en tête, puis les
  /// conversations trouvées, le terme surligné.
  ///
  /// Les portées « Messages » et « Fichiers » de la fiche sont absentes : le
  /// contenu est chiffré de bout en bout et n'est pas cherchable côté serveur.
  /// Un bandeau le dit à l'utilisateur plutôt que de laisser croire à une
  /// recherche qui ne trouve rien.
  Widget _buildSearchResults({
    required List<ConversationEntity> conversations,
    required String currentUserId,
    required Set<String> blockedUserIds,
    required Map<String, String> participantNames,
  }) {
    final query = _searchQuery.trim();
    final lower = query.toLowerCase();

    final matchedConversations =
        _filterConversations(
          conversations,
          currentUserId: currentUserId,
          showArchived: false,
          blockedUserIds: blockedUserIds,
          participantNames: participantNames,
        ).toList();

    final people =
        (ref.watch(searchProfilesNotifierProvider).valueOrNull ?? [])
            .where((p) => p.id != currentUserId)
            .toList();

    final showPeople =
        _searchScope != _SearchScope.conversations && people.isNotEmpty;
    final showConversations =
        _searchScope != _SearchScope.people && matchedConversations.isNotEmpty;

    final children = <Widget>[
      Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final (scope, label, count) in <(
                _SearchScope,
                String,
                int,
              )>[
                (
                  _SearchScope.all,
                  'Tout',
                  people.length + matchedConversations.length,
                ),
                (_SearchScope.people, 'Personnes', people.length),
                (
                  _SearchScope.conversations,
                  'Conversations',
                  matchedConversations.length,
                ),
              ]) ...[
                DesignFilterChip(
                  label: '$label · $count',
                  selected: _searchScope == scope,
                  onTap: () => setState(() => _searchScope = scope),
                ),
                const SizedBox(width: 9),
              ],
            ],
          ),
        ),
      ),
    ];

    if (showPeople) {
      children.add(const DesignSectionLabel('Personnes'));
      children.add(
        SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: people.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final profile = people[i];
              final name = (profile.displayName ?? '').trim();
              return _PersonResult(
                name: name.isEmpty ? '?' : name,
                photoUrl: profile.photoUrl,
                onTap:
                    () => context.push('/messages/new?userId=${profile.id}'),
              );
            },
          ),
        ),
      );
      children.add(const SizedBox(height: 18));
    }

    if (showConversations) {
      children.add(const DesignSectionLabel('Conversations'));
      for (var i = 0; i < matchedConversations.length; i++) {
        if (i > 0) {
          children.add(
            Divider(height: 1, thickness: 1, color: context.dividerColor),
          );
        }
        final c = matchedConversations[i];
        children.add(
          ConversationItem(
            conversation: c,
            currentUserId: currentUserId,
            flat: true,
            highlight: lower,
            onTap: () {
              context.push(
                '/messages/${c.id}',
                extra: {
                  'name': c.name ?? 'Conversation',
                  'imageUrl': c.imageUrl,
                  'isGroup': c.isGroup,
                  'groupId': c.groupId,
                  'otherUserId':
                      c.isGroup ? null : c.getOtherParticipantId(currentUserId),
                },
              );
            },
            onLongPress:
                () => _showConversationOptions(context, c, currentUserId),
          ),
        );
      }
      children.add(const SizedBox(height: 18));
    }

    if (!showPeople && !showConversations) {
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Center(
            child: Text(
              'Aucun nom ne correspond à « $query ».',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: context.textSecondaryColor,
              ),
            ),
          ),
        ),
      );
    }

    children.add(
      DesignInfoLine(
        icon: Icons.lock_outline,
        text:
            'La recherche porte sur les noms. Le contenu des messages est '
            'chiffré de bout en bout : il ne peut pas être cherché depuis '
            'le serveur.',
      ),
    );

    return ListView(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        16 + MediaQuery.of(context).padding.bottom,
      ),
      children: children,
    );
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

/// Marqueur interne pour la tuile « Mes notes » dans la liste d'entrées.
const String _kSelfNotesMarker = '__self_notes__';

/// Les deux amorces de la fiche 9e — « écrivez à un membre proche » et
/// « rejoignez un groupe de votre ville » — rendues à partir de données
/// réelles, et masquées sans bruit quand ces données n'existent pas.
class _EmptyStateSuggestions extends ConsumerWidget {
  const _EmptyStateSuggestions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = <Widget>[];

    // Membre proche : on lit l'état déjà chargé (l'accueil le remplit quand
    // la localisation est accordée) sans déclencher de nouvelle demande de
    // permission depuis la messagerie.
    final nearby =
        ref.watch(nearbyProfilesNotifierProvider).valueOrNull ?? const [];
    final me = ref.watch(currentUserProvider).valueOrNull?.id;
    final candidate =
        nearby.where((p) => p.id != me && (p.displayName ?? '').isNotEmpty);
    if (candidate.isNotEmpty) {
      final profile = candidate.first;
      final city = profile.currentCity?.trim();
      rows.add(
        _SuggestionRow(
          leading: _InitialAvatar(name: profile.displayName!),
          title: profile.displayName!,
          subtitle:
              profile.isOnline
                  ? 'En ligne'
                  : (city != null && city.isNotEmpty ? city : 'À proximité'),
          trailing: Icons.send_rounded,
          onTap: () => context.push('/messages/new?userId=${profile.id}'),
        ),
      );
    }

    // Groupe de la ville : la ville vient du profil, pas d'une géolocalisation.
    final myCity =
        me == null
            ? null
            : ref
                .watch(profileNotifierProvider(me))
                .valueOrNull
                ?.currentCity
                ?.trim();
    final groups = ref.watch(groupsNotifierProvider).valueOrNull ?? const [];
    final cityGroups =
        (myCity != null && myCity.isNotEmpty)
            ? groups.where(
              (g) =>
                  !g.isPrivate &&
                  ((g.location ?? '').toLowerCase().contains(
                        myCity.toLowerCase(),
                      ) ||
                      (g.country ?? '').toLowerCase().contains(
                        myCity.toLowerCase(),
                      )),
            )
            : const Iterable.empty();
    // Sans ville renseignée, on ne bascule pas sur « un groupe au hasard » :
    // la fiche promet un groupe *de votre ville*.
    if (cityGroups.isNotEmpty) {
      final group = cityGroups.first;
      rows.add(
        _SuggestionRow(
          leading: _GroupBadge(color: context.successColor),
          title: group.name,
          subtitle:
              '${group.memberCount} membres · ${group.isPrivate ? 'privé' : 'public'}',
          trailing: Icons.chevron_right_rounded,
          onTap: () => context.push('/groups/${group.id}'),
        ),
      );
    }

    if (rows.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            rows[i],
          ],
        ],
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  final Widget leading;
  final String title;
  final String subtitle;
  final IconData trailing;
  final VoidCallback onTap;

  const _SuggestionRow({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.surfaceColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.borderColor),
          ),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: context.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(trailing, size: 19, color: context.adaptivePrimaryColor),
            ],
          ),
        ),
      ),
    );
  }
}

class _InitialAvatar extends StatelessWidget {
  final String name;

  const _InitialAvatar({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.adaptivePrimaryColor,
      ),
      alignment: Alignment.center,
      child: Text(
        name.trim()[0].toUpperCase(),
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: context.onPrimaryColor,
        ),
      ),
    );
  }
}

class _GroupBadge extends StatelessWidget {
  final Color color;

  const _GroupBadge({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: const AppIcon(AppIcon.groups, size: 18, color: Colors.white),
    );
  }
}

/// Personne trouvée par la recherche (fiche 9b) : avatar rond 56 et prénom.
class _PersonResult extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final VoidCallback onTap;

  const _PersonResult({
    required this.name,
    required this.photoUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final firstName = name.split(' ').first;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 64,
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.adaptivePrimaryColor,
              ),
              clipBehavior: Clip.antiAlias,
              alignment: Alignment.center,
              child:
                  (photoUrl != null && photoUrl!.isNotEmpty)
                      ? Image.network(
                        photoUrl!,
                        fit: BoxFit.cover,
                        width: 56,
                        height: 56,
                        errorBuilder: (_, __, ___) => _initial(context),
                      )
                      : _initial(context),
            ),
            const SizedBox(height: 6),
            Text(
              firstName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: context.textPrimaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _initial(BuildContext context) => Text(
    name[0].toUpperCase(),
    style: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: context.onPrimaryColor,
    ),
  );
}
