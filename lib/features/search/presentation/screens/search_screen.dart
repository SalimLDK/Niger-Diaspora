import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../../../shared/widgets/search_empty_state.dart';
import '../../../../shared/widgets/standard_search_bar.dart';
import '../../../friends/domain/entities/friend_entity.dart';
import '../../../groups/domain/entities/group_entity.dart';
import '../../../messages/domain/entities/conversation_entity.dart';
import '../../../profile/data/models/profile_model.dart';
import '../providers/search_provider.dart';
import '../../../../core/theme/adaptive_colors.dart';

class SearchScreen extends ConsumerStatefulWidget {
  final SearchFilter? initialFilter;
  final bool restrictToFilter;

  const SearchScreen({
    super.key,
    this.initialFilter,
    this.restrictToFilter = false,
  });

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // Set initial filter if provided
    if (widget.initialFilter != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(searchNotifierProvider.notifier)
            .setFilter(widget.initialFilter!);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      ref.read(searchNotifierProvider.notifier).search(query);
    });
  }

  /// Requête validée (entrée clavier ou tap sur une puce récente) : lance la
  /// recherche et l'ajoute aux recherches récentes (§12d).
  void _onSearchSubmitted(String query) {
    if (query.trim().isEmpty) return;
    _debounce?.cancel();
    ref.read(searchNotifierProvider.notifier).commitSearch(query);
  }

  void _tapRecentSearch(String query) {
    _searchController.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
    _onSearchSubmitted(query);
  }

  /// Nombre de résultats bruts pour une catégorie (compteurs des puces 12d).
  int _resultCountFor(SearchState state, SearchFilter filter) {
    switch (filter) {
      case SearchFilter.all:
        return state.profiles.length +
            state.groups.length +
            state.friends.length +
            state.conversations.length;
      case SearchFilter.members:
        return state.profiles.length;
      case SearchFilter.groups:
        return state.groups.length;
      case SearchFilter.friends:
        return state.friends.length;
      case SearchFilter.conversations:
        return state.conversations.length;
    }
  }

  String _getTitle() {
    if (widget.restrictToFilter && widget.initialFilter != null) {
      switch (widget.initialFilter!) {
        case SearchFilter.groups:
          return 'Rechercher un groupe';
        case SearchFilter.conversations:
          return 'Rechercher une discussion';
        case SearchFilter.friends:
          return 'Rechercher un ami';
        case SearchFilter.members:
          return 'Rechercher un membre';
        case SearchFilter.all:
          return 'Recherche';
      }
    }
    return 'Recherche';
  }

  String _getHintText() {
    if (widget.restrictToFilter && widget.initialFilter != null) {
      switch (widget.initialFilter!) {
        case SearchFilter.groups:
          return 'Rechercher un groupe...';
        case SearchFilter.conversations:
          return 'Rechercher une discussion...';
        case SearchFilter.friends:
          return 'Rechercher un ami...';
        case SearchFilter.members:
          return 'Rechercher un membre...';
        case SearchFilter.all:
          return 'Rechercher...';
      }
    }
    return 'Rechercher des membres ou groupes...';
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchNotifierProvider);

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        title: Text(_getTitle()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          StandardSearchBar(
            controller: _searchController,
            hintText: _getHintText(),
            autofocus: true,
            onChanged: _onSearchChanged,
            onSubmitted: _onSearchSubmitted,
            onClear: () {
              ref.read(searchNotifierProvider.notifier).clearSearch();
            },
          ),

          // Filter Chips - only show if not restricted to a specific filter
          if (!widget.restrictToFilter)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children:
                    SearchFilter.values.map((filter) {
                      final isSelected = searchState.filter == filter;
                      // Compteur par catégorie (refonte 12d) — brut, indépendant
                      // du filtre actif ; masqué tant qu'il n'y a pas de requête.
                      final count = searchState.query.isEmpty
                          ? 0
                          : _resultCountFor(searchState, filter);
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () {
                            ref
                                .read(searchNotifierProvider.notifier)
                                .setFilter(filter);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  isSelected
                                      ? context.adaptivePrimaryColor
                                      : context.surfaceColor,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color:
                                    isSelected
                                        ? context.adaptivePrimaryColor
                                        : context.borderColor,
                              ),
                            ),
                            child: Text(
                              count > 0
                                  ? '${filter.label}  $count'
                                  : filter.label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color:
                                    isSelected
                                        ? AppColors.white
                                        : context.textSecondaryColor,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
              ),
            ),

          const SizedBox(height: 16),

          // Results
          Expanded(child: _buildResults(searchState)),
        ],
      ),
    );
  }

  Widget _buildResults(SearchState state) {
    if (state.query.isEmpty) {
      if (state.recentSearches.isNotEmpty) {
        return _buildRecentSearches(state);
      }
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 80,
              color: context.textTertiaryColor.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Recherchez des membres ou groupes',
              style: TextStyle(fontSize: 16, color: context.textTertiaryColor),
            ),
          ],
        ),
      );
    }

    if (state.isLoading) {
      return const Center(child: LoadingIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Erreur de recherche',
              style: TextStyle(color: context.textTertiaryColor),
            ),
          ],
        ),
      );
    }

    if (!state.hasResults) {
      // Un filtre restreint par la route (ex. /groups/search) n'est pas
      // « effaçable » : le proposer enverrait l'utilisateur dans un état que
      // l'écran ne sait pas afficher.
      final canClearFilter =
          !widget.restrictToFilter && state.filter != SearchFilter.all;

      return SearchEmptyState(
        query: state.query,
        // « Créer «X» » plutôt qu'un « Créer un groupe » générique : la
        // requête devient le nom proposé, ce qui évite de la ressaisir.
        primaryActionLabel: state.filter == SearchFilter.groups
            ? AppLocalizations.of(context)!.searchCreateNamed(state.query)
            : null,
        onPrimaryAction: state.filter == SearchFilter.groups
            ? () => context.push(
                  '/groups/create?name=${Uri.encodeComponent(state.query)}',
                )
            : null,
        onClearFilters: canClearFilter
            ? () => ref
                .read(searchNotifierProvider.notifier)
                .setFilter(SearchFilter.all)
            : null,
      );
    }

    final filteredProfiles = state.filteredProfiles;
    final filteredGroups = state.filteredGroups;
    final filteredFriends = state.filteredFriends;
    final filteredConversations = state.filteredConversations;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        // Members Section
        if (filteredProfiles.isNotEmpty) ...[
          _SectionHeader(title: 'Membres', count: filteredProfiles.length),
          ...filteredProfiles.map((profile) => _MemberItem(profile: profile)),
          const SizedBox(height: 16),
        ],

        // Groups Section
        if (filteredGroups.isNotEmpty) ...[
          _SectionHeader(title: 'Groupes', count: filteredGroups.length),
          ...filteredGroups.map((group) => _GroupItem(group: group)),
          const SizedBox(height: 16),
        ],

        // Friends Section
        if (filteredFriends.isNotEmpty) ...[
          _SectionHeader(title: 'Amis', count: filteredFriends.length),
          ...filteredFriends.map((friend) => _FriendItem(friend: friend)),
          const SizedBox(height: 16),
        ],

        // Conversations Section
        if (filteredConversations.isNotEmpty) ...[
          _SectionHeader(title: 'Discussions', count: filteredConversations.length),
          ...filteredConversations.map((conv) => _ConversationItem(conversation: conv)),
        ],

        const SizedBox(height: 32),
      ],
    );
  }

  /// Recherches récentes (§12d) : chips avec icône horloge + « Effacer ».
  Widget _buildRecentSearches(SearchState state) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recherches récentes',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: context.textPrimaryColor,
              ),
            ),
            TextButton(
              onPressed:
                  () =>
                      ref
                          .read(searchNotifierProvider.notifier)
                          .clearRecentSearches(),
              child: const Text('Effacer'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              state.recentSearches
                  .map(
                    (query) => _RecentSearchChip(
                      query: query,
                      onTap: () => _tapRecentSearch(query),
                    ),
                  )
                  .toList(),
        ),
      ],
    );
  }
}

class _RecentSearchChip extends StatelessWidget {
  final String query;
  final VoidCallback onTap;

  const _RecentSearchChip({required this.query, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.access_time_rounded,
              size: 15,
              color: context.textTertiaryColor,
            ),
            const SizedBox(width: 6),
            Text(
              query,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: context.textSecondaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;

  const _SectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: context.textPrimaryColor,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: context.surfaceVariantColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: context.adaptivePrimaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberItem extends StatelessWidget {
  final ProfileModel profile;

  const _MemberItem({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          context.push('/profile/${profile.id}', extra: profile.toEntity());
        },
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: context.adaptivePrimaryGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child:
                  profile.photoUrl != null
                      ? ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(
                          profile.photoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (_, __, ___) => const Icon(
                                Icons.person,
                                color: AppColors.white,
                              ),
                        ),
                      )
                      : const Icon(Icons.person, color: AppColors.white),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.displayName ?? 'Membre',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: context.textPrimaryColor,
                    ),
                  ),
                  if (profile.handle != null && profile.handle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      '@${profile.handle}',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.adaptivePrimaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  if (profile.profession != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      profile.profession!,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.textSecondaryColor,
                      ),
                    ),
                  ],
                  if (profile.currentCity != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 12,
                          color: context.adaptivePrimaryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          profile.currentCity!,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.textTertiaryColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: context.textTertiaryColor),
          ],
        ),
      ),
    );
  }
}

class _GroupItem extends StatelessWidget {
  final GroupEntity group;

  const _GroupItem({required this.group});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => context.push('/groups/${group.id}', extra: group),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: context.adaptivePrimaryGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child:
                  group.imageUrl != null
                      ? ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(
                          group.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (_, __, ___) => const Icon(
                                Icons.groups,
                                color: AppColors.white,
                              ),
                        ),
                      )
                      : const Icon(Icons.groups, color: AppColors.white),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: context.textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: context.adaptivePrimaryColor.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          group.category.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: context.adaptivePrimaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.people,
                        size: 14,
                        color: context.textTertiaryColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${group.memberIds.length}',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textTertiaryColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (group.isPrivate)
                  Icon(Icons.lock, size: 16, color: context.textTertiaryColor),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, color: context.textTertiaryColor),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FriendItem extends StatelessWidget {
  final FriendEntity friend;

  const _FriendItem({required this.friend});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          context.push('/profile/${friend.id}');
        },
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: context.adaptivePrimaryGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child:
                  friend.photoUrl != null
                      ? ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(
                          friend.photoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (_, __, ___) => const Icon(
                                Icons.person,
                                color: AppColors.white,
                              ),
                        ),
                      )
                      : const Icon(Icons.person, color: AppColors.white),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    friend.displayName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: context.textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.people,
                        size: 12,
                        color: context.adaptivePrimaryColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Ami',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textTertiaryColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: context.textTertiaryColor),
          ],
        ),
      ),
    );
  }
}

class _ConversationItem extends StatelessWidget {
  final ConversationEntity conversation;

  const _ConversationItem({required this.conversation});

  @override
  Widget build(BuildContext context) {
    final isGroup = conversation.isGroup;
    final displayName = conversation.name ?? 'Conversation';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          context.push(
            '/messages/${conversation.id}',
            extra: {
              'name': displayName,
              'imageUrl': conversation.imageUrl,
              'isGroup': isGroup,
              'groupId': conversation.groupId,
            },
          );
        },
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: context.adaptivePrimaryGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child:
                  conversation.imageUrl != null
                      ? ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(
                          conversation.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (_, __, ___) => Icon(
                                isGroup ? Icons.groups : Icons.chat,
                                color: AppColors.white,
                              ),
                        ),
                      )
                      : Icon(
                          isGroup ? Icons.groups : Icons.chat,
                          color: AppColors.white,
                        ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: context.textPrimaryColor,
                    ),
                  ),
                  if (conversation.lastMessage != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      conversation.lastMessage!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.textSecondaryColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isGroup)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: context.adaptivePrimaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Groupe',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: context.adaptivePrimaryColor,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, color: context.textTertiaryColor),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
