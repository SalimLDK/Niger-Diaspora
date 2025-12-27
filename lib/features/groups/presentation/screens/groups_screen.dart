import 'package:flutter/material.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/group_entity.dart';
import '../providers/group_provider.dart';
import '../../../../core/theme/adaptive_colors.dart';

class GroupsScreen extends ConsumerStatefulWidget {
  const GroupsScreen({super.key});

  @override
  ConsumerState<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends ConsumerState<GroupsScreen> {
  GroupCategory? _selectedCategory;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser != null) {
      ref.read(myGroupsNotifierProvider.notifier).loadMyGroups(currentUser.id);
    }
    ref.read(groupsNotifierProvider.notifier).loadGroups();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final myGroupsAsync = ref.watch(myGroupsNotifierProvider);
    final allGroupsAsync = ref.watch(groupsNotifierProvider);

    return Scaffold(
      backgroundColor: context.backgroundColor,
      body: RefreshIndicator(
        onRefresh: () async => _loadData(),
        color: context.adaptivePrimaryColor,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Header avec gradient
            SliverToBoxAdapter(
              child: Container(
                decoration: BoxDecoration(
                  gradient: context.adaptiveSecondaryGradient,
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.groupsTitle,
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Rejoignez une communauté',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.white.withValues(
                                      alpha: 0.8,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            GestureDetector(
                              onTap: () => context.push('/groups/create'),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.add,
                                  color: AppColors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Search Bar
                        GestureDetector(
                          onTap: () => context.push('/groups/search'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: context.surfaceColor,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow:
                                  context.isDarkMode
                                      ? null
                                      : [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.1,
                                          ),
                                          blurRadius: 20,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: context.secondaryBackgroundColor,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.search,
                                    color: context.adaptivePrimaryColor,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    l10n.searchGroup,
                                    style: TextStyle(
                                      color: context.textTertiaryColor,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Filtres par catégorie
            SliverToBoxAdapter(
              child: Container(
                height: 50,
                margin: const EdgeInsets.only(top: 20),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _CategoryChip(
                      label: 'Tous',
                      isSelected: _selectedCategory == null,
                      onTap: () => setState(() => _selectedCategory = null),
                    ),
                    ...GroupCategory.values.map(
                      (category) => Padding(
                        padding: const EdgeInsets.only(left: 10),
                        child: _CategoryChip(
                          label: category.label,
                          isSelected: _selectedCategory == category,
                          onTap:
                              () =>
                                  setState(() => _selectedCategory = category),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Contenu principal
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Mes groupes
                  _SectionHeader(
                    title: l10n.myGroups,
                    icon: Icons.favorite,
                    iconColor: context.adaptivePrimaryColor,
                  ),

                  const SizedBox(height: 16),

                  myGroupsAsync.when(
                    skipLoadingOnRefresh: true,
                    data: (myGroups) {
                      final filteredGroups =
                          _selectedCategory == null
                              ? myGroups
                              : myGroups
                                  .where((g) => g.category == _selectedCategory)
                                  .toList();

                      if (filteredGroups.isEmpty) {
                        return _buildEmptyMyGroups();
                      }
                      return Column(
                        children:
                            filteredGroups
                                .map(
                                  (group) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _GroupCard(
                                      group: group,
                                      isJoined: true,
                                      currentUserId: currentUser?.id ?? '',
                                      onTap:
                                          () => context.push(
                                            '/groups/${group.id}',
                                            extra: group,
                                          ),
                                      onJoinLeave: () => _leaveGroup(group.id),
                                    ),
                                  ),
                                )
                                .toList(),
                      );
                    },
                    loading: () => _buildLoadingCards(2),
                    error: (error, _) => _buildErrorWidget(l10n.loadingError),
                  ),

                  const SizedBox(height: 28),

                  // Découvrir
                  _SectionHeader(
                    title: l10n.discover,
                    icon: Icons.explore,
                    iconColor: context.adaptiveSecondaryColor,
                  ),

                  const SizedBox(height: 16),

                  allGroupsAsync.when(
                    skipLoadingOnRefresh: true,
                    data: (allGroups) {
                      // Wait for myGroups to load before filtering
                      return myGroupsAsync.when(
                        data: (myGroups) {
                          // Filtrer les groupes déjà rejoints
                          final myGroupIds = myGroups.map((g) => g.id).toSet();
                          var discoverGroups =
                              allGroups
                                  .where((g) => !myGroupIds.contains(g.id))
                                  .toList();

                          // Appliquer le filtre de catégorie
                          if (_selectedCategory != null) {
                            discoverGroups =
                                discoverGroups
                                    .where(
                                      (g) => g.category == _selectedCategory,
                                    )
                                    .toList();
                          }

                          if (discoverGroups.isEmpty) {
                            return _buildEmptyDiscover();
                          }

                          return Column(
                            children:
                                discoverGroups
                                    .map(
                                      (group) => Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        child: _GroupCard(
                                          group: group,
                                          isJoined: false,
                                          currentUserId: currentUser?.id ?? '',
                                          onTap:
                                              () => context.push(
                                                '/groups/${group.id}',
                                                extra: group,
                                              ),
                                          onJoinLeave:
                                              () => _joinGroup(group.id),
                                        ),
                                      ),
                                    )
                                    .toList(),
                          );
                        },
                        loading: () => _buildLoadingCards(4),
                        error:
                            (_, __) => _buildLoadingCards(
                              4,
                            ), // Show loading if myGroups failed
                      );
                    },
                    loading: () => _buildLoadingCards(4),
                    error: (error, _) => _buildErrorWidget(l10n.loadingError),
                  ),

                  const SizedBox(height: 24),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _joinGroup(String groupId) async {
    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser == null) return;

    final success = await ref
        .read(groupDetailNotifierProvider.notifier)
        .joinGroup(groupId, currentUser.id);

    if (success) {
      _loadData();
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.groupJoined),
            backgroundColor: AppColors.secondary,
          ),
        );
      }
    }
  }

  Future<void> _leaveGroup(String groupId) async {
    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser == null) return;

    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: context.surfaceColor,
            title: Text(l10n.leaveGroupTitle),
            content: Text(l10n.leaveGroupConfirm),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.cancel),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: Text(l10n.leaveGroup),
              ),
            ],
          ),
    );

    if (confirm == true) {
      final success = await ref
          .read(groupDetailNotifierProvider.notifier)
          .leaveGroup(groupId, currentUser.id);

      if (success) {
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.groupLeft)));
        }
      }
    }
  }

  Widget _buildEmptyMyGroups() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: context.cardDecoration,
      child: Column(
        children: [
          Icon(
            Icons.groups_outlined,
            size: 48,
            color: context.textTertiaryColor.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.noJoinedGroups,
            style: TextStyle(color: context.textSecondaryColor, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyDiscover() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: context.cardDecoration,
      child: Column(
        children: [
          Icon(
            Icons.search_off,
            size: 48,
            color: context.textTertiaryColor.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.noGroupsToDiscover,
            style: TextStyle(color: context.textSecondaryColor, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCards(int count) {
    return Column(
      children: List.generate(
        count,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _GroupCardLoading(),
        ),
      ),
    );
  }

  Widget _buildErrorWidget(String message) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: context.cardDecoration,
      child: Column(
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(color: context.textSecondaryColor, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final GroupEntity group;
  final bool isJoined;
  final String currentUserId;
  final VoidCallback onTap;
  final VoidCallback onJoinLeave;

  const _GroupCard({
    required this.group,
    required this.isJoined,
    required this.currentUserId,
    required this.onTap,
    required this.onJoinLeave,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow:
              context.isDarkMode
                  ? null
                  : [
                    BoxShadow(
                      color: (isJoined
                              ? context.adaptivePrimaryColor
                              : context.adaptiveSecondaryColor)
                          .withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
        ),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient:
                    isJoined
                        ? context.adaptivePrimaryGradient
                        : context.adaptiveSecondaryGradient,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: (isJoined
                            ? context.adaptivePrimaryColor
                            : context.adaptiveSecondaryColor)
                        .withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child:
                  group.imageUrl != null
                      ? ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: CachedNetworkImage(
                          imageUrl: group.imageUrl!,
                          fit: BoxFit.cover,
                          placeholder:
                              (_, __) => const Center(
                                child: Icon(
                                  Icons.groups,
                                  color: AppColors.white,
                                  size: 30,
                                ),
                              ),
                          errorWidget:
                              (_, __, ___) => const Center(
                                child: Icon(
                                  Icons.groups,
                                  color: AppColors.white,
                                  size: 30,
                                ),
                              ),
                        ),
                      )
                      : const Center(
                        child: Icon(
                          Icons.groups,
                          color: AppColors.white,
                          size: 30,
                        ),
                      ),
            ),
            const SizedBox(width: 14),
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    group.description,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.textTertiaryColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: context.secondaryBackgroundColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.people,
                              size: 12,
                              color: context.adaptivePrimaryColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${group.memberIds.length}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: context.adaptivePrimaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: context.surfaceVariantColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          group.category.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: context.textSecondaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onJoinLeave,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: isJoined ? null : context.adaptiveSecondaryGradient,
                  color: isJoined ? context.primaryBackgroundColor : null,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow:
                      isJoined
                          ? null
                          : [
                            BoxShadow(
                              color: context.adaptiveSecondaryColor.withValues(
                                alpha: 0.3,
                              ),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                ),
                child: Text(
                  isJoined ? l10n.member : l10n.joinGroup,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color:
                        isJoined
                            ? context.adaptivePrimaryColor
                            : AppColors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected ? context.adaptiveSecondaryGradient : null,
          color: isSelected ? null : context.surfaceColor,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color:
                  isSelected
                      ? context.adaptiveSecondaryColor.withValues(alpha: 0.3)
                      : Colors.black.withValues(alpha: 0.05),
              blurRadius: isSelected ? 12 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? AppColors.white : context.textSecondaryColor,
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;

  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: context.textPrimaryColor,
          ),
        ),
      ],
    );
  }
}

class _GroupCardLoading extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: context.cardDecoration,
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: context.surfaceVariantColor,
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 140,
                  height: 16,
                  decoration: BoxDecoration(
                    color: context.surfaceVariantColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  height: 12,
                  decoration: BoxDecoration(
                    color: context.surfaceVariantColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 22,
                      decoration: BoxDecoration(
                        color: context.surfaceVariantColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 70,
                      height: 22,
                      decoration: BoxDecoration(
                        color: context.surfaceVariantColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 70,
            height: 36,
            decoration: BoxDecoration(
              color: context.surfaceVariantColor,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ],
      ),
    );
  }
}
