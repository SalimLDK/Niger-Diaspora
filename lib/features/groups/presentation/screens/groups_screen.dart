import 'package:flutter/material.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/profile_options.dart';
import '../../../../core/errors/failure_mapper.dart';
import '../../../../core/responsive/responsive_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../domain/entities/group_entity.dart';
import '../providers/group_provider.dart';
import '../providers/group_request_provider.dart';
import '../../../messages/presentation/providers/message_provider.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../../../shared/widgets/sheet_handle.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';

/// Dernière activité (dernier message) par groupe, dérivée des conversations
/// déjà chargées — le champ `lastMessageAt` vit sur la conversation liée
/// (`conversations.groupId`), pas sur le document groupe. Permet le badge
/// ACTIF/CALME sans requête supplémentaire ni changement backend.
final groupLastActivityProvider = Provider<Map<String, DateTime>>((ref) {
  final conversations =
      ref.watch(conversationsProvider).valueOrNull ?? const [];
  final map = <String, DateTime>{};
  for (final c in conversations) {
    final gid = c.groupId;
    final at = c.lastMessageAt;
    if (gid != null && at != null) {
      final existing = map[gid];
      if (existing == null || at.isAfter(existing)) map[gid] = at;
    }
  }
  return map;
});

/// Groupes dont la conversation liée est épinglée par l'utilisateur courant
/// (§9c : indicateur épinglé sur la carte) — même mécanisme dérivé que
/// [groupLastActivityProvider], zéro requête supplémentaire.
final groupPinnedProvider = Provider<Set<String>>((ref) {
  final currentUserId = ref.watch(currentUserProvider).valueOrNull?.id;
  if (currentUserId == null) return const <String>{};
  final conversations =
      ref.watch(conversationsProvider).valueOrNull ?? const [];
  final pinned = <String>{};
  for (final c in conversations) {
    final gid = c.groupId;
    if (gid != null && c.isPinnedBy(currentUserId)) pinned.add(gid);
  }
  return pinned;
});

class GroupsScreen extends ConsumerStatefulWidget {
  const GroupsScreen({super.key});

  @override
  ConsumerState<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends ConsumerState<GroupsScreen> {
  GroupCategory? _selectedCategory;
  String? _selectedCountry;
  String? _selectedRegion;
  bool _showTitle = false;
  static const double _expandedHeight = 210;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
      _loadDefaultCountryFilter();
    });
  }

  Future<void> _loadData() async {
    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    // Charger les données en parallèle et attendre qu'elles arrivent pour le feedback visuel
    await Future.wait([
      ref.read(groupsNotifierProvider.notifier).loadGroups(),
      if (currentUser != null)
        ref.read(myGroupsNotifierProvider.notifier).loadMyGroups(currentUser.id),
    ]);
  }

  void _loadDefaultCountryFilter() {
    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser == null) return;

    final profileAsync = ref.read(profileNotifierProvider(currentUser.id));
    profileAsync.whenData((profile) {
      final availableCountries = ref.read(availableGroupCountriesProvider);

      if (profile?.currentCountry != null &&
          profile!.currentCountry!.isNotEmpty &&
          availableCountries.contains(profile.currentCountry)) {
        // Utiliser le pays du profil s'il existe dans les groupes disponibles
        setState(() => _selectedCountry = profile.currentCountry);
      } else if (availableCountries.contains('NE')) {
        // Sinon, utiliser le Niger par défaut s'il existe dans les groupes.
        // Le code ISO, pas le nom : `availableGroupCountriesProvider` dérive de
        // `groups.country_code`. Avec 'Niger', ce repli ne se déclenchait jamais.
        setState(() => _selectedCountry = 'NE');
      }
      // Si Niger n'existe pas non plus, on laisse sur "Tous" (null)
    });
  }

  /// Applique tous les filtres actifs (catégorie, pays, région) à une liste de groupes.
  /// [applyGeoFilters] permet d'exclure les filtres géographiques pour "Mes groupes".
  List<GroupEntity> _applyFilters(
    List<GroupEntity> groups, {
    bool applyGeoFilters = true,
  }) {
    var filtered = groups;

    if (_selectedCategory != null) {
      filtered = filtered.where((g) => g.category == _selectedCategory).toList();
    }

    if (!applyGeoFilters) return filtered;

    if (_selectedCountry != null) {
      filtered = filtered.where((g) => g.country == _selectedCountry).toList();
    }

    if (_selectedRegion != null) {
      filtered = filtered.where((g) => g.originRegion == _selectedRegion).toList();
    }

    return filtered;
  }

  /// Groupes correspondant au pays/région du profil de l'utilisateur, qu'il
  /// n'a pas encore rejoints. Le groupe officiel du pays (s'il est present)
  /// est mis en avant en premier.
  Widget _buildSuggestedSection(
    BuildContext context,
    AppLocalizations l10n,
    String? currentUserId,
    AsyncValue<List<GroupEntity>> allGroupsAsync,
    AsyncValue<List<GroupEntity>> myGroupsAsync,
  ) {
    if (currentUserId == null) return const SizedBox.shrink();

    final profile = ref.watch(profileNotifierProvider(currentUserId)).valueOrNull;
    if (profile == null) return const SizedBox.shrink();
    if ((profile.currentCountry ?? '').isEmpty &&
        (profile.originRegion ?? '').isEmpty) {
      return const SizedBox.shrink();
    }

    final allGroups = allGroupsAsync.valueOrNull ?? [];
    final myGroupIds = (myGroupsAsync.valueOrNull ?? []).map((g) => g.id).toSet();

    final suggested = allGroups
        .where((g) => !myGroupIds.contains(g.id))
        .where(
          (g) =>
              (profile.currentCountry != null &&
                  g.country == profile.currentCountry) ||
              (profile.originRegion != null &&
                  g.originRegion == profile.originRegion),
        )
        .toList()
      ..sort((a, b) => (b.isOfficial ? 1 : 0) - (a.isOfficial ? 1 : 0));

    if (suggested.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 28),
        _SectionHeader(
          title: 'Suggéré pour toi',
          icon: Icons.auto_awesome,
          iconColor: context.adaptivePrimaryColor,
        ),
        const SizedBox(height: 16),
        ...suggested.take(5).map(
              (group) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _GroupCard(
                  group: group,
                  isJoined: false,
                  currentUserId: currentUserId,
                  onTap: () => context.push('/groups/${group.id}', extra: group),
                  onJoinLeave: () => _joinGroup(group.id),
                ),
              ),
            ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final myGroupsAsync = ref.watch(myGroupsNotifierProvider);
    final allGroupsAsync = ref.watch(groupsNotifierProvider);

    return Scaffold(
      backgroundColor: context.backgroundColor,
      body: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          final collapsed = n.metrics.pixels > (_expandedHeight - kToolbarHeight);
          if (collapsed != _showTitle) setState(() => _showTitle = collapsed);
          return false;
        },
        child: RefreshIndicator(
          onRefresh: () async => _loadData(),
          color: context.adaptivePrimaryColor,
          child: CustomScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            // Header avec gradient
            SliverAppBar(
              pinned: true,
              expandedHeight: _expandedHeight,
              backgroundColor: context.adaptivePrimaryColor,
              automaticallyImplyLeading: false,
              title: _showTitle
                  ? Text(l10n.groupsTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                  : null,
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.pin,
                background: Container(
                  decoration: BoxDecoration(
                    gradient: context.adaptiveSecondaryGradient,
                  ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(context.horizontalPadding, 16, context.horizontalPadding, 24),
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
                                  l10n.joinCommunity,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.white.withValues(
                                      alpha: 0.8,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                // TODO: Réactiver l'icône carte des groupes une fois
                                // GroupsMapScreen stabilisé (désactivée sur demande).
                                // GestureDetector(
                                //   onTap: () => context.push('/groups/map'),
                                //   child: Container(
                                //     padding: const EdgeInsets.all(12),
                                //     decoration: BoxDecoration(
                                //       color: AppColors.white.withValues(alpha: 0.2),
                                //       borderRadius: BorderRadius.circular(14),
                                //     ),
                                //     child: const AppIcon(AppIcon.location,
                                //       color: AppColors.white,
                                //       size: 24,
                                //     ),
                                //   ),
                                // ),
                                // const SizedBox(width: 10),
                                GestureDetector(
                                  onTap: () => context.push('/groups/create'),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const AppIcon(AppIcon.add,
                                      color: AppColors.white,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ],
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
                                  child: AppIcon(AppIcon.search,
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
          ),
            // Filtres par catégorie
            SliverToBoxAdapter(
              child: Container(
                height: 50,
                margin: const EdgeInsets.only(top: 20),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: context.horizontalPadding),
                  children: [
                    _CategoryChip(
                      label: l10n.all,
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
            // Filtres géographiques (pays d'accueil + région d'origine)
            SliverToBoxAdapter(
              child: _buildGeoFilters(),
            ),
            // Contenu principal
            SliverPadding(
              padding: EdgeInsets.all(context.horizontalPadding),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Invitations reçues
                  _ReceivedInvitationsSection(onInviteAccepted: _loadData),

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
                      final filteredGroups = _applyFilters(myGroups, applyGeoFilters: false);

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

                  // Suggéré pour toi (pays/région du profil) - masquée si rien à suggérer
                  _buildSuggestedSection(context, l10n, currentUser?.id, allGroupsAsync, myGroupsAsync),

                  // Section Découvrir - masquée si aucun groupe à découvrir
                  allGroupsAsync.when(
                    skipLoadingOnRefresh: true,
                    data: (allGroups) {
                      // Wait for myGroups to load before filtering
                      return myGroupsAsync.when(
                        data: (myGroups) {
                          // Filtrer les groupes déjà rejoints
                          final myGroupIds = myGroups.map((g) => g.id).toSet();
                          final notJoinedGroups =
                              allGroups
                                  .where((g) => !myGroupIds.contains(g.id))
                                  .toList();

                          // Appliquer tous les filtres
                          final discoverGroups = _applyFilters(notJoinedGroups);

                          // Ne rien afficher si aucun groupe à découvrir
                          if (discoverGroups.isEmpty) {
                            return const SizedBox.shrink();
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 28),
                              _SectionHeader(
                                title: l10n.discover,
                                icon: Icons.explore,
                                iconColor: context.adaptiveSecondaryColor,
                              ),
                              const SizedBox(height: 16),
                              ...discoverGroups.map(
                                (group) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _GroupCard(
                                    group: group,
                                    isJoined: false,
                                    currentUserId: currentUser?.id ?? '',
                                    onTap:
                                        () => context.push(
                                          '/groups/${group.id}',
                                          extra: group,
                                        ),
                                    onJoinLeave: () => _joinGroup(group.id),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],
                          );
                        },
                        loading: () => _buildDiscoverLoading(l10n),
                        error: (_, __) => const SizedBox.shrink(),
                      );
                    },
                    loading: () => _buildDiscoverLoading(l10n),
                    error: (error, _) => const SizedBox.shrink(),
                  ),
                ]),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(height: MediaQuery.of(context).padding.bottom),
            ),
          ],
        ),
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
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.creatorMustTransferOwnership)),
        );
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
          AppIcon(
            AppIcon.groups,
            size: 48,
            color: context.textTertiaryColor.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.noJoinedGroups,
            style: TextStyle(
              color: context.textPrimaryColor,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          // Explication d'usage (§9f).
          Text(
            l10n.emptyGroupsUsage,
            style: TextStyle(color: context.textSecondaryColor, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          // « Créer votre groupe » en carte pointillée.
          InkWell(
            onTap: () => context.push('/groups/create'),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: context.adaptivePrimaryColor.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 18, color: context.adaptivePrimaryColor),
                  const SizedBox(width: 8),
                  Text(
                    l10n.createGroup,
                    style: TextStyle(
                      color: context.adaptivePrimaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscoverLoading(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 28),
        _SectionHeader(
          title: l10n.discover,
          icon: Icons.explore,
          iconColor: context.adaptiveSecondaryColor,
        ),
        const SizedBox(height: 16),
        _buildLoadingCards(4),
      ],
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
    // Convertir l'erreur technique en message user-friendly
    final userFriendlyMessage = FailureMapper.toUserFriendlyString(message, context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: context.cardDecoration,
      child: Column(
        children: [
          const AppIcon(AppIcon.error, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          Text(
            userFriendlyMessage,
            style: TextStyle(color: context.textSecondaryColor, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildGeoFilters() {
    final l10n = AppLocalizations.of(context)!;
    final countries = ref.watch(availableGroupCountriesProvider);
    final regions = ref.watch(availableGroupRegionsProvider);

    // Ne rien afficher si aucun filtre disponible
    if (countries.isEmpty && regions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filtres par pays d'accueil
          if (countries.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(left: 20, bottom: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.public,
                    size: 14,
                    color: context.textTertiaryColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l10n.hostCountry,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: context.textTertiaryColor,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: context.horizontalPadding),
                children: [
                  _GeoFilterChip(
                    label: l10n.all,
                    isSelected: _selectedCountry == null,
                    onTap: () => setState(() => _selectedCountry = null),
                  ),
                  ...countries.map(
                    (country) => Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _GeoFilterChip(
                        // `country` est un code ISO : on compare dessus, mais
                        // on affiche le nom (sinon l'utilisateur lit « NE »).
                        label: CountryCodeLookup.labelForCode(country),
                        isSelected: _selectedCountry == country,
                        onTap: () => setState(() => _selectedCountry = country),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Filtres par région d'origine
          if (regions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 20, bottom: 8),
              child: Row(
                children: [
                  AppIcon(AppIcon.location,
                    size: 14,
                    color: context.textTertiaryColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l10n.originRegionLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: context.textTertiaryColor,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: context.horizontalPadding),
                children: [
                  _GeoFilterChip(
                    label: l10n.allFeminine,
                    isSelected: _selectedRegion == null,
                    onTap: () => setState(() => _selectedRegion = null),
                  ),
                  ...regions.map(
                    (region) => Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _GeoFilterChip(
                        label: region,
                        isSelected: _selectedRegion == region,
                        onTap: () => setState(() => _selectedRegion = region),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GroupCard extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final lastActivity = ref.watch(groupLastActivityProvider)[group.id];
    final isPinned = ref.watch(groupPinnedProvider).contains(group.id);
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
                                child: AppIcon(AppIcon.groups,
                                  color: AppColors.white,
                                  size: 30,
                                ),
                              ),
                          errorWidget:
                              (_, __, ___) => const Center(
                                child: AppIcon(AppIcon.groups,
                                  color: AppColors.white,
                                  size: 30,
                                ),
                              ),
                        ),
                      )
                      : const Center(
                        child: AppIcon(AppIcon.groups,
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
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                group.name,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: context.textPrimaryColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Cadenas si le groupe est privé (refonte 9c).
                            if (group.isPrivate) ...[
                              const SizedBox(width: 6),
                              Icon(
                                Icons.lock_outline_rounded,
                                size: 13,
                                color: context.textTertiaryColor,
                              ),
                            ],
                            if (group.isOfficial) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: context.adaptivePrimaryColor
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Officiel',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: context.adaptivePrimaryColor,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Épinglé (refonte 9c) : reprend l'icône/couleur du
                      // même indicateur sur les conversations.
                      if (isPinned) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.push_pin,
                          size: 14,
                          color: context.adaptivePrimaryColor,
                        ),
                      ],
                      // Badge d'activité ACTIF/CALME (refonte 9c) — visible dès
                      // qu'on connaît la dernière activité de la conversation.
                      if (lastActivity != null) ...[
                        const SizedBox(width: 8),
                        _GroupActivityBadge(lastActivity: lastActivity),
                      ],
                    ],
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
                      // Ville (refonte 9c : « ville · N membres »).
                      if ((group.location ?? group.country)?.trim().isNotEmpty ??
                          false) ...[
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: context.surfaceVariantColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AppIcon(
                                  AppIcon.location,
                                  size: 12,
                                  color: context.textSecondaryColor,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    (group.location ?? group.country)!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: context.textSecondaryColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
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
                            AppIcon(AppIcon.people,
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

/// Pastille d'activité : ACTIF (< 24 h) vert, sinon CALME neutre.
class _GroupActivityBadge extends StatelessWidget {
  final DateTime lastActivity;

  const _GroupActivityBadge({required this.lastActivity});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isActive = DateTime.now().difference(lastActivity).inHours < 24;
    // Vert lisible en clair comme en sombre pour ACTIF ; neutre pour CALME.
    const activeColor = Color(0xFF2D7D46);
    final fg = isActive ? activeColor : context.textSecondaryColor;
    final bg = isActive
        ? activeColor.withValues(alpha: 0.14)
        : context.surfaceVariantColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            (isActive ? l10n.groupActive : l10n.groupCalm).toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: fg,
            ),
          ),
        ],
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

class _GeoFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _GeoFilterChip({
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected ? context.adaptivePrimaryGradient : null,
          color: isSelected ? null : context.surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? null
              : Border.all(
                  color: context.borderColor,
                  width: 1,
                ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: context.adaptivePrimaryColor.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? AppColors.white : context.textSecondaryColor,
          ),
        ),
      ),
    );
  }
}

class _ReceivedInvitationsSection extends ConsumerWidget {
  final VoidCallback onInviteAccepted;

  const _ReceivedInvitationsSection({required this.onInviteAccepted});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final invitesAsync = ref.watch(receivedGroupInvitesProvider);
    final invites = invitesAsync.valueOrNull ?? [];

    if (invites.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.mail_outline, color: context.adaptivePrimaryColor, size: 20),
            const SizedBox(width: 8),
            Text(
              '${l10n.receivedGroupInvitations} (${invites.length})',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: context.textPrimaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...invites.map(
          (invite) => _InviteCard(
            invite: invite,
            onAccepted: onInviteAccepted,
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _InviteCard extends ConsumerWidget {
  final dynamic invite;
  final VoidCallback onAccepted;

  const _InviteCard({required this.invite, required this.onAccepted});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.adaptivePrimaryColor.withValues(alpha: 0.3),
        ),
        boxShadow: context.isDarkMode
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Zone d'infos : tap = aperçu des détails du groupe avant de décider.
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _showGroupDetails(context, ref),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: context.adaptivePrimaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: invite.groupImageUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            invite.groupImageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => AppIcon(
                              AppIcon.groups,
                              color: context.adaptivePrimaryColor,
                            ),
                          ),
                        )
                      : AppIcon(AppIcon.groups,
                          color: context.adaptivePrimaryColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invite.groupName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: context.textPrimaryColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.invitedByName(invite.inviterName),
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textTertiaryColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.info_outline,
                  size: 20,
                  color: context.textTertiaryColor,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Accepter / Refuser sur la même ligne, pleine largeur (moins d'erreurs).
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _decline(context, ref),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(l10n.declineRequest),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _accept(context, ref),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(l10n.acceptRequest),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _accept(BuildContext context, WidgetRef ref) async {
    final ok = await ref
        .read(groupInviteNotifierProvider.notifier)
        .acceptInvite(invite.id);
    if (ok) {
      ref.invalidate(myGroupsNotifierProvider);
      onAccepted();
    } else if (context.mounted) {
      _showError(context);
    }
  }

  Future<void> _decline(BuildContext context, WidgetRef ref) async {
    final ok = await ref
        .read(groupInviteNotifierProvider.notifier)
        .declineInvite(invite.id);
    // La liste se rafraîchit via l'invalidation dans le notifier.
    if (!ok && context.mounted) {
      _showError(context);
    }
  }

  void _showError(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Action impossible pour le moment, réessayez.'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Aperçu des détails du groupe (nom, description, membres) avant de décider.
  void _showGroupDetails(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Consumer(
          builder: (ctx, ref2, _) {
            final groupAsync = ref2.watch(groupByIdProvider(invite.groupId));
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 12,
                bottom: MediaQuery.of(ctx).padding.bottom + 20,
              ),
              decoration: BoxDecoration(
                color: context.surfaceColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: SheetHandle(),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: context.adaptivePrimaryColor
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: invite.groupImageUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.network(
                                  invite.groupImageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => AppIcon(
                                    AppIcon.groups,
                                    color: context.adaptivePrimaryColor,
                                  ),
                                ),
                              )
                            : AppIcon(AppIcon.groups,
                                color: context.adaptivePrimaryColor),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              invite.groupName,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: context.textPrimaryColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              AppLocalizations.of(context)!
                                  .invitedByName(invite.inviterName),
                              style: TextStyle(
                                fontSize: 13,
                                color: context.textTertiaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  groupAsync.when(
                    data: (group) {
                      if (group == null) {
                        return Text(
                          'Détails indisponibles.',
                          style: TextStyle(color: context.textTertiaryColor),
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.group_outlined,
                                  size: 18,
                                  color: context.textTertiaryColor),
                              const SizedBox(width: 6),
                              Text(
                                '${group.memberCount} membre${group.memberCount > 1 ? 's' : ''}',
                                style: TextStyle(
                                  color: context.textSecondaryColor,
                                ),
                              ),
                            ],
                          ),
                          if (group.description.trim().isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              group.description,
                              style: TextStyle(
                                color: context.textSecondaryColor,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (_, __) => Text(
                      'Détails indisponibles.',
                      style: TextStyle(color: context.textTertiaryColor),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _decline(context, ref);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(
                            AppLocalizations.of(context)!.declineRequest,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _accept(context, ref);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(
                            AppLocalizations.of(context)!.acceptRequest,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
