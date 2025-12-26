import 'package:flutter/material.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import '../../../../core/services/location_service.dart';
import '../../../../core/services/feature_flag_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../events/presentation/providers/event_provider.dart';
import '../../../onboarding/presentation/providers/onboarding_provider.dart';
import '../../../onboarding/presentation/widgets/coach_mark_content.dart';
import '../../../notifications/presentation/providers/notification_provider.dart';
import '../providers/home_provider.dart';
import '../../../profile/presentation/widgets/online_status_indicator.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // GlobalKeys for coach marks
  final GlobalKey _profilePictureKey = GlobalKey();
  final GlobalKey _notificationBellKey = GlobalKey();
  final GlobalKey _searchBarKey = GlobalKey();
  final GlobalKey _statsRowKey = GlobalKey();
  final GlobalKey _nearbyMembersKey = GlobalKey();
  final GlobalKey _upcomingEventsKey = GlobalKey();

  late TutorialCoachMark _tutorialCoachMark;
  bool _coachMarksShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
      _checkAndShowCoachMarks();
    });
  }

  void _checkAndShowCoachMarks() {
    if (_coachMarksShown) return;

    final onboardingState = ref.read(onboardingNotifierProvider);

    // Show coach marks only if intro was seen but coach marks weren't
    if (onboardingState.hasSeenIntro && !onboardingState.hasSeenCoachMarks) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _showCoachMarks();
        }
      });
    }
  }

  void _showCoachMarks() {
    _coachMarksShown = true;
    _tutorialCoachMark = TutorialCoachMark(
      targets: _createTargets(),
      textSkip: "Passer",
      paddingFocus: 10,
      opacityShadow: 0.8,
      colorShadow: context.textPrimaryColor,
      onFinish: () {
        ref.read(onboardingNotifierProvider.notifier).completeCoachMarks();
      },
      onSkip: () {
        ref.read(onboardingNotifierProvider.notifier).completeCoachMarks();
        return true;
      },
    );
    _tutorialCoachMark.show(context: context);
  }

  List<TargetFocus> _createTargets() {
    return [
      TargetFocus(
        identify: "profile",
        keyTarget: _profilePictureKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.RRect,
        radius: 16,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return const CoachMarkContent(
                title: "Votre profil",
                description:
                    "Appuyez ici pour acceder a votre profil et le completer avec vos informations.",
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "notifications",
        keyTarget: _notificationBellKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.RRect,
        radius: 14,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return const CoachMarkContent(
                title: "Notifications",
                description:
                    "Restez informe des nouveaux messages, evenements et activites de la communaute.",
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "search",
        keyTarget: _searchBarKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.RRect,
        radius: 16,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return const CoachMarkContent(
                title: "Recherche",
                description:
                    "Trouvez des membres, des groupes et des evenements facilement.",
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "stats",
        keyTarget: _statsRowKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.RRect,
        radius: 20,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return const CoachMarkContent(
                title: "Statistiques",
                description:
                    "Decouvrez la communaute: nombre de membres, groupes et evenements. Appuyez pour explorer.",
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "nearbyMembers",
        keyTarget: _nearbyMembersKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.RRect,
        radius: 20,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return const CoachMarkContent(
                title: "Membres proches",
                description:
                    "Decouvrez les Nigeriens dans votre region. Faites glisser pour voir plus de profils.",
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "events",
        keyTarget: _upcomingEventsKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.RRect,
        radius: 20,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return const CoachMarkContent(
                title: "Evenements a venir",
                description:
                    "Participez aux rencontres et activites de la diaspora. Appuyez pour voir les details.",
                isLast: true,
              );
            },
          ),
        ],
      ),
    ];
  }

  Future<void> _loadData() async {
    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser != null) {
      // Ne charger le profil que s'il n'est pas déjà chargé pour cet utilisateur
      var profile = ref.read(profileNotifierProvider).valueOrNull;
      if (profile == null || profile.id != currentUser.id) {
        await ref
            .read(profileNotifierProvider.notifier)
            .loadProfile(currentUser.id);
        profile = ref.read(profileNotifierProvider).valueOrNull;
      }

      // Déterminer la localisation
      double lat = 13.5116; // Par défaut: Niamey
      double lng = 2.1254;
      double radius = 1000; // Grand rayon par défaut

      // 1. Essayer d'utiliser la localisation du profil si disponible
      if (profile != null &&
          profile.latitude != null &&
          profile.longitude != null) {
        lat = profile.latitude!;
        lng = profile.longitude!;
        radius = 50; // Rayon plus pertinent pour le profil
      }
      // 2. Sinon essayer d'obtenir la position actuelle
      else {
        try {
          final position = await LocationService.instance.getCurrentPosition();
          lat = position.latitude;
          lng = position.longitude;
          radius = 50;

          // Mettre à jour la position du profil
          if (mounted) {
            ref
                .read(profileNotifierProvider.notifier)
                .updateLocation(currentUser.id, lat, lng);
          }
        } catch (e) {
          debugPrint('Erreur de localisation HomeScreen: $e');
          // Fallback silencieux sur Niamey
        }
      }

      // Charger les profils à proximité
      if (mounted) {
        ref
            .read(nearbyProfilesNotifierProvider.notifier)
            .loadNearbyProfiles(lat, lng, radiusKm: radius);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final authState = ref.watch(authNotifierProvider);
    final profileAsync = ref.watch(profileNotifierProvider);
    final homeStats = ref.watch(homeStatsNotifierProvider);
    final nearbyProfiles = ref.watch(nearbyProfilesNotifierProvider);
    final upcomingEvents = ref.watch(eventsNotifierProvider);

    // Priorité aux données du profil, sinon fallback sur auth
    final profile = profileAsync.valueOrNull;
    final authUser = authState.maybeWhen(
      authenticated: (user) => user,
      orElse: () => null,
    );

    final userName = profile?.displayName ?? authUser?.displayName ?? l10n.user;
    final userPhotoUrl = profile?.photoUrl ?? authUser?.photoUrl;

    return Scaffold(
      backgroundColor: context.backgroundColor,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.read(homeStatsNotifierProvider.notifier).refresh();
          _loadData();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Hero Header avec gradient
            SliverToBoxAdapter(
              child: Container(
                decoration: BoxDecoration(
                  gradient: context.adaptivePrimaryGradient,
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            GestureDetector(
                              key: _profilePictureKey,
                              onTap: () => context.go('/profile'),
                              child: Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: context.surfaceColor.withValues(
                                      alpha: 0.3,
                                    ),
                                    width: 2,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child:
                                      userPhotoUrl != null
                                          ? CachedNetworkImage(
                                            imageUrl: userPhotoUrl,
                                            fit: BoxFit.cover,
                                            placeholder:
                                                (_, __) => Container(
                                                  color: AppColors.primaryLight,
                                                  child: const Icon(
                                                    Icons.person,
                                                    color: AppColors.white,
                                                    size: 28,
                                                  ),
                                                ),
                                            errorWidget:
                                                (_, __, ___) => Container(
                                                  color: AppColors.primaryLight,
                                                  child: const Icon(
                                                    Icons.person,
                                                    color: AppColors.white,
                                                    size: 28,
                                                  ),
                                                ),
                                          )
                                          : Container(
                                            color: context.surfaceVariantColor,
                                            child: Icon(
                                              Icons.person,
                                              color: context.onSurfaceColor,
                                              size: 28,
                                            ),
                                          ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${l10n.hello},',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: context.onPrimaryColor.withValues(
                                        alpha: 0.8,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    userName,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            GestureDetector(
                              key: _notificationBellKey,
                              onTap: () => context.push('/notifications'),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.white.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Icon(
                                      Icons.notifications_outlined,
                                      color: AppColors.white,
                                      size: 24,
                                    ),
                                  ),
                                  if (ref.watch(
                                        unreadNotificationsCountProvider,
                                      ) >
                                      0)
                                    Positioned(
                                      right: -2,
                                      top: -2,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        constraints: const BoxConstraints(
                                          minWidth: 16,
                                          minHeight: 16,
                                        ),
                                        child: Center(
                                          child: Text(
                                            ref.watch(
                                                      unreadNotificationsCountProvider,
                                                    ) >
                                                    99
                                                ? '99+'
                                                : ref
                                                    .watch(
                                                      unreadNotificationsCountProvider,
                                                    )
                                                    .toString(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              height: 1,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Search Bar
                        GestureDetector(
                          key: _searchBarKey,
                          onTap: () => context.push('/search'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: context.surfaceColor,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
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
                                    color: context.adaptivePrimaryColor
                                        .withValues(alpha: 0.1),
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
                                    l10n.searchMembersGroups,
                                    style: TextStyle(
                                      color: context.textTertiaryColor,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: context.adaptivePrimaryColor,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.tune,
                                    color: Colors.white,
                                    size: 18,
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
            // Contenu principal
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Stats Row
                  Container(
                    key: _statsRowKey,
                    child: homeStats.when(
                      data:
                          (stats) => Row(
                            children: [
                              Expanded(
                                child: _StatCard(
                                  icon: Icons.people,
                                  value: formatCount(stats.membersCount),
                                  label: l10n.membersLabel,
                                  color: context.adaptivePrimaryColor,
                                  bgColor: context.adaptivePrimaryColor
                                      .withValues(alpha: 0.1),
                                  onTap: () => context.push('/search'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _StatCard(
                                  icon: Icons.groups,
                                  value: formatCount(stats.groupsCount),
                                  label: l10n.groupsTitle,
                                  color: context.adaptiveSecondaryColor,
                                  bgColor: context.adaptiveSecondaryColor
                                      .withValues(alpha: 0.1),
                                  onTap: () => context.go('/groups'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _StatCard(
                                  icon: Icons.event,
                                  value: formatCount(stats.eventsCount),
                                  label: l10n.eventsTitle,
                                  color: AppColors.primaryDark,
                                  bgColor: AppColors.primaryLighter,
                                  onTap: () => context.push('/events'),
                                ),
                              ),
                            ],
                          ),
                      loading:
                          () => Row(
                            children: [
                              Expanded(child: _StatCardLoading()),
                              const SizedBox(width: 12),
                              Expanded(child: _StatCardLoading()),
                              const SizedBox(width: 12),
                              Expanded(child: _StatCardLoading()),
                            ],
                          ),
                      error:
                          (_, __) => Row(
                            children: [
                              Expanded(
                                child: _StatCard(
                                  icon: Icons.people,
                                  value: '--',
                                  label: l10n.membersLabel,
                                  color: AppColors.primary,
                                  bgColor:
                                      AppColors
                                          .primaryLighter, // Restore original color logic if needed, or use context colors
                                  onTap: () => context.push('/search'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _StatCard(
                                  icon: Icons.groups,
                                  value: '--',
                                  label: l10n.groupsTitle,
                                  color: context.adaptiveSecondaryColor,
                                  bgColor: context.adaptiveSecondaryColor
                                      .withValues(alpha: 0.1),
                                  onTap: () => context.go('/groups'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _StatCard(
                                  icon: Icons.event,
                                  value: '--',
                                  label: l10n.eventsTitle,
                                  color: AppColors.primaryDark,
                                  bgColor: AppColors.primaryLighter,
                                  onTap: () => context.push('/events'),
                                ),
                              ),
                            ],
                          ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Quick Actions - Services (only show if at least one feature is enabled)
                  if (ref.watch(isMoneyTransferEnabledProvider) ||
                      ref.watch(isMarketplaceEnabledProvider) ||
                      ref.watch(isBusinessDirectoryEnabledProvider))
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Services',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: context.textPrimaryColor,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            // Money Transfer - conditional on feature flag
                            if (ref.watch(isMoneyTransferEnabledProvider))
                              Expanded(
                                child: _QuickActionCard(
                                  icon: Icons.send_rounded,
                                  label: 'Transfert',
                                  color: AppColors.primary,
                                  onTap: () => context.push('/transfers'),
                                ),
                              ),
                            if (ref.watch(isMoneyTransferEnabledProvider) &&
                                (ref.watch(isMarketplaceEnabledProvider) ||
                                    ref.watch(
                                      isBusinessDirectoryEnabledProvider,
                                    )))
                              const SizedBox(width: 12),
                            // Marketplace - conditional on feature flag
                            if (ref.watch(isMarketplaceEnabledProvider))
                              Expanded(
                                child: _QuickActionCard(
                                  icon: Icons.storefront_rounded,
                                  label: 'Boutique',
                                  color: context.adaptiveSecondaryColor,
                                  onTap: () => context.push('/marketplace'),
                                ),
                              ),
                            if (ref.watch(isMarketplaceEnabledProvider) &&
                                ref.watch(isBusinessDirectoryEnabledProvider))
                              const SizedBox(width: 12),
                            // Business Directory - conditional on feature flag
                            if (ref.watch(isBusinessDirectoryEnabledProvider))
                              Expanded(
                                child: _QuickActionCard(
                                  icon: Icons.business_rounded,
                                  label: 'Annuaire',
                                  color: AppColors.primaryDark,
                                  onTap: () => context.push('/businesses'),
                                ),
                              ),
                            if (ref.watch(isBusinessDirectoryEnabledProvider))
                              const SizedBox(width: 12),
                            // Embassies
                            Expanded(
                              child: _QuickActionCard(
                                icon: Icons.account_balance,
                                label: 'Ambassades',
                                color: Colors.indigo,
                                onTap: () => context.push('/embassies'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                  const SizedBox(height: 28),

                  // Section Membres
                  Column(
                    key: _nearbyMembersKey,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionHeader(
                        title: l10n.membersNearby,
                        onSeeAll: () => context.go('/map'),
                        seeAllText: l10n.seeAll,
                      ),
                      const SizedBox(height: 16),
                      nearbyProfiles.when(
                        data: (profiles) {
                          if (profiles.isEmpty) {
                            return _EmptyStateCard(
                              icon: Icons.people_outline,
                              message: l10n.noMembersNearby,
                            );
                          }

                          return SizedBox(
                            height: 200,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount:
                                  profiles.length > 10 ? 10 : profiles.length,
                              itemBuilder: (context, index) {
                                final profile = profiles[index];
                                return Padding(
                                  padding: EdgeInsets.only(
                                    left: index == 0 ? 0 : 12,
                                    right:
                                        index ==
                                                (profiles.length > 10
                                                    ? 9
                                                    : profiles.length - 1)
                                            ? 0
                                            : 0,
                                  ),
                                  child: GestureDetector(
                                    onTap:
                                        () => context.push(
                                          '/profile/${profile.id}',
                                          extra: profile,
                                        ),
                                    child: _MemberCard(
                                      userId: profile.id,
                                      name: profile.displayName ?? 'Membre',
                                      location: profile.currentCity ?? '',
                                      badge: profile.profession ?? '',
                                      photoUrl: profile.photoUrl,
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                        loading:
                            () => SizedBox(
                              height: 200,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: 3,
                                itemBuilder:
                                    (context, index) => Padding(
                                      padding: EdgeInsets.only(
                                        left: index == 0 ? 0 : 12,
                                      ),
                                      child: _MemberCardLoading(),
                                    ),
                              ),
                            ),
                        error:
                            (_, __) => _EmptyStateCard(
                              icon: Icons.error_outline,
                              message: l10n.loadingError,
                            ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // Section Événements
                  Column(
                    key: _upcomingEventsKey,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionHeader(
                        title: l10n.upcomingEvents,
                        onSeeAll: () => context.push('/events'),
                        seeAllText: l10n.seeAll,
                      ),
                      const SizedBox(height: 16),
                      upcomingEvents.when(
                        data: (events) {
                          final upcoming = events.take(3).toList();
                          if (upcoming.isEmpty) {
                            return _EmptyStateCard(
                              icon: Icons.event_busy,
                              message: l10n.noUpcomingEvents,
                              subtitle: l10n.createOrJoinEvents,
                            );
                          }

                          return Column(
                            children:
                                upcoming
                                    .map(
                                      (event) => Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        child: GestureDetector(
                                          onTap:
                                              () => context.push(
                                                '/events/${event.id}',
                                                extra: event,
                                              ),
                                          child: _EventCard(
                                            title: event.title,
                                            date: _formatEventDate(
                                              event.startDate,
                                            ),
                                            location: event.location,
                                            attendeesCount:
                                                event.attendeeIds.length,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                          );
                        },
                        loading:
                            () => Column(
                              children: List.generate(
                                2,
                                (index) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _EventCardLoading(),
                                ),
                              ),
                            ),
                        error:
                            (_, __) => _EmptyStateCard(
                              icon: Icons.error_outline,
                              message: l10n.loadingError,
                            ),
                      ),
                    ],
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

  String _formatEventDate(DateTime date) {
    final months = [
      'jan',
      'fév',
      'mar',
      'avr',
      'mai',
      'juin',
      'juil',
      'aoû',
      'sep',
      'oct',
      'nov',
      'déc',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onSeeAll;
  final String seeAllText;

  const _SectionHeader({
    required this.title,
    required this.onSeeAll,
    required this.seeAllText,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: context.textPrimaryColor,
          ),
        ),
        GestureDetector(
          onTap: onSeeAll,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: context.primaryBackgroundColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  seeAllText,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.adaptivePrimaryColor,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 12,
                  color: context.adaptivePrimaryColor,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? subtitle;

  const _EmptyStateCard({
    required this.icon,
    required this.message,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: context.cardDecoration,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.surfaceVariantColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 32, color: context.textTertiaryColor),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: context.textSecondaryColor,
            ),
            textAlign: TextAlign.center,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: TextStyle(fontSize: 13, color: context.textTertiaryColor),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final Color bgColor;
  final VoidCallback? onTap;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.bgColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: context.cardDecoration,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color:
                    context.isDarkMode
                        ? color.withValues(alpha: 0.15)
                        : bgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: context.textTertiaryColor,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCardLoading extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: context.cardDecoration,
      child: Column(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: context.surfaceVariantColor,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 20,
            decoration: BoxDecoration(
              color: context.surfaceVariantColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 50,
            height: 12,
            decoration: BoxDecoration(
              color: context.surfaceVariantColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  final String userId;
  final String name;
  final String location;
  final String badge;
  final String? photoUrl;

  const _MemberCard({
    required this.userId,
    required this.name,
    required this.location,
    required this.badge,
    this.photoUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border:
            context.isDarkMode
                ? Border.all(color: context.borderColor, width: 1)
                : null,
        boxShadow:
            context.isDarkMode
                ? null
                : [
                  BoxShadow(
                    color: context.adaptivePrimaryColor.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
      ),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: context.adaptivePrimaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: context.adaptivePrimaryColor.withValues(
                        alpha: 0.3,
                      ),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child:
                    photoUrl != null
                        ? ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: photoUrl!,
                            fit: BoxFit.cover,
                            width: 72,
                            height: 72,
                            placeholder:
                                (_, __) => const Icon(
                                  Icons.person,
                                  color: AppColors.white,
                                  size: 36,
                                ),
                            errorWidget:
                                (_, __, ___) => const Icon(
                                  Icons.person,
                                  color: AppColors.white,
                                  size: 36,
                                ),
                          ),
                        )
                        : const Icon(
                          Icons.person,
                          color: AppColors.white,
                          size: 36,
                        ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: context.surfaceColor,
                    shape: BoxShape.circle,
                  ),
                  child: OnlineStatusIndicator(
                    userId: userId,
                    showText: false,
                    dotSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            name,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: context.textPrimaryColor,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          if (location.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.location_on,
                  size: 13,
                  color: context.adaptiveSecondaryColor,
                ),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    location,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textSecondaryColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          const Spacer(),
          if (badge.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: context.primaryBackgroundColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: context.adaptivePrimaryColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}

class _MemberCardLoading extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(16),
      decoration: context.cardDecoration,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: context.surfaceVariantColor,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: 80,
            height: 14,
            decoration: BoxDecoration(
              color: context.surfaceVariantColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 60,
            height: 10,
            decoration: BoxDecoration(
              color: context.surfaceVariantColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final String title;
  final String date;
  final String location;
  final int attendeesCount;

  const _EventCard({
    required this.title,
    required this.date,
    required this.location,
    required this.attendeesCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: context.cardDecoration,
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: context.adaptivePrimaryGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.event, color: context.onPrimaryColor, size: 24),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimaryColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: context.primaryBackgroundColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 12,
                            color: context.adaptivePrimaryColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            date,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
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
                        color: context.secondaryBackgroundColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.people,
                            size: 12,
                            color: context.adaptiveSecondaryColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$attendeesCount',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: context.adaptiveSecondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: context.surfaceVariantColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: context.textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _EventCardLoading extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: context.cardDecoration,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: context.surfaceVariantColor,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  height: 14,
                  decoration: BoxDecoration(
                    color: context.surfaceVariantColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 120,
                  height: 10,
                  decoration: BoxDecoration(
                    color: context.surfaceVariantColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border:
              context.isDarkMode
                  ? Border.all(color: context.borderColor, width: 1)
                  : null,
          boxShadow:
              context.isDarkMode
                  ? null
                  : [
                    BoxShadow(
                      color: color.withValues(alpha: 0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color:
                    context.isDarkMode
                        ? color.withValues(alpha: 0.15)
                        : color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.textPrimaryColor,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
