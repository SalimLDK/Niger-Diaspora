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
import '../widgets/messages_skeleton.dart';
import '../../../../core/theme/design_kit.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../../../shared/widgets/sheet_handle.dart';

part 'messages_screen_liste.dart';
part 'messages_screen_widgets.dart';

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
        // Ce `setState` reconstruit l'écran pendant que le champ vient de
        // prendre le focus. Il ne doit RIEN démonter sur le chemin du champ :
        // un `EditableText` recréé ferme sa `TextInputConnection` (clavier qui
        // retombe) sans que ce `FocusNode` perde le focus, donc plus rien ne la
        // rouvre — c'était le bug « il faut deux taps ». Deux gardes le
        // protègent : la `ValueKey` sur le bloc du champ plus bas, et le type
        // de widget constant dans `DesignSearchField`. Ne pas les retirer.
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
      unawaited(ref.read(searchProfilesNotifierProvider.notifier).search(value.trim()));
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
    //
    // `valueOrNull` et non `value` : en Riverpod 2, `value` **relance
    // l'erreur** dès que le flux en porte une — une simple coupure faisait
    // alors un écran rouge ici, sous un `hasValue` pourtant vrai (l'erreur
    // garde la dernière liste connue).
    final isEmptyInbox =
        conversationsAsync.hasValue &&
        (conversationsAsync.valueOrNull?.isEmpty ?? false);

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
            // Le champ reste au même rang dans la colonne, mais le rang seul ne
            // suffit pas à préserver son élément quand ses frères changent :
            // c'est la `ValueKey` posée dessus qui s'en charge (voir plus bas).
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
                // Clé indispensable, pas décorative. À l'ouverture de la
                // recherche, deux frères changent d'un coup : l'en-tête (rang 0)
                // change de type et les puces de filtre (rang 2) disparaissent.
                // `updateChildren` ne peut alors apparier ce bloc ni par le haut
                // ni par le bas : il tombe dans la zone « milieu », où tout
                // enfant SANS clé est démonté. Le champ serait reconstruit, sa
                // `TextInputConnection` fermée, et le clavier ne remonterait
                // qu'au second tap. Avec une clé stable, l'élément est réapparié
                // et l'`EditableText` survit au rebuild.
                key: const ValueKey('messages-search-field'),
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
                // Une panne n'efface pas ce qui est déjà à l'écran : l'état
                // d'erreur ne s'affiche que si aucune liste n'a jamais été
                // reçue. Sinon la liste (cache compris) reste en place, et se
                // remplit d'elle-même au retour du réseau.
                skipError: true,
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
                // Squelette plutôt qu'un tourniquet centré : la liste se
                // pose ensuite exactement sur les lignes annoncées, au lieu
                // d'apparaître d'un bloc à la place d'un rond au milieu du
                // vide. `skipLoadingOnRefresh`/`OnReload` ci-dessus le
                // réservent au tout premier chargement — un retour à l'écran
                // ou un « tirer pour rafraîchir » garde la liste en place.
                loading: () => const ConversationListSkeleton(),
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
                    () => context.push(
                      '/messages/new?userId=${profile.id}',
                      // Nom et photo évitent que l'en-tête de la discussion
                      // s'ouvre sur un libellé de repli le temps du
                      // chargement ; ils ne font pas autorité.
                      extra: {
                        'recipientName': profile.displayName,
                        'recipientPhotoUrl': profile.photoUrl,
                      },
                    ),
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
              unawaited(context.push(
                '/messages/${c.id}',
                extra: {
                  'name': c.name ?? 'Conversation',
                  'imageUrl': c.imageUrl,
                  'isGroup': c.isGroup,
                  'groupId': c.groupId,
                  'otherUserId':
                      c.isGroup ? null : c.getOtherParticipantId(currentUserId),
                },
              ));
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

  /// Filtre actif qui ne ramène rien — à ne pas confondre avec la fiche 9e.
  ///
  /// Même langage visuel que les deux états vides voisins (recherche sans
  /// résultat, archives vides) : icône en 64, une phrase. S'y ajoute la sortie
  /// qui manquait — sans elle, l'écran ne dit pas comment revenir à une liste
  /// non vide, et la puce active se lit mal sur un fond blanc.
  Widget _buildFilteredEmptyState(
    BuildContext context, {
    required String icon,
    required String message,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AppIcon(
            icon,
            size: 64,
            color: context.textTertiaryColor.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: context.textSecondaryColor),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => setState(() => _filter = _MessagesFilter.all),
            child: Text(l10n.showAllConversations),
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
}
