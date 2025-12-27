import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../../../shared/widgets/standard_search_bar.dart';
import '../../../groups/domain/entities/group_entity.dart';
import '../../../profile/data/models/profile_model.dart';
import '../providers/search_provider.dart';
import '../../../../core/theme/adaptive_colors.dart';

class SearchScreen extends ConsumerStatefulWidget {
  final SearchFilter? initialFilter;

  const SearchScreen({super.key, this.initialFilter});

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

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchNotifierProvider);

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        title: const Text('Recherche'),
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
            hintText: 'Rechercher des membres ou groupes...',
            autofocus: true,
            onChanged: _onSearchChanged,
            onClear: () {
              ref.read(searchNotifierProvider.notifier).clearSearch();
            },
          ),

          // Filter Chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children:
                  SearchFilter.values.map((filter) {
                    final isSelected = searchState.filter == filter;
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
                            filter.label,
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 80,
              color: context.textTertiaryColor.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun résultat pour "${state.query}"',
              style: TextStyle(fontSize: 16, color: context.textTertiaryColor),
            ),
          ],
        ),
      );
    }

    final filteredProfiles = state.filteredProfiles;
    final filteredGroups = state.filteredGroups;

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
        ],

        const SizedBox(height: 32),
      ],
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
