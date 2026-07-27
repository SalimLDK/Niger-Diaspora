import 'dart:async';

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
import '../../../settings/presentation/providers/blocked_users_provider.dart';
import '../providers/home_provider.dart';

import '../widgets/quick_action_card.dart';
import '../widgets/home_section_header.dart';
import '../widgets/home_empty_state_card.dart';
import '../widgets/home_stat_card.dart';
import '../widgets/home_member_card.dart';
import '../widgets/home_event_card.dart';

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
  final GlobalKey _servicesKey = GlobalKey();
  final GlobalKey _nearbyMembersKey = GlobalKey();
  final GlobalKey _upcomingEventsKey = GlobalKey();

  late TutorialCoachMark _tutorialCoachMark;
  bool _coachMarksShown = false;
  String? _locationError;
  DateTime? _lastNearbyUpdate;

  // Timers pour mise à jour automatique
  Timer? _nearbyRefreshTimer;
  Timer? _uiRefreshTimer;
  static const int _nearbyRefreshIntervalSeconds = 60; // Rafraîchir les membres toutes les 60s
  static const int _uiRefreshIntervalSeconds = 10; // Rafraîchir l'affichage du temps toutes les 10s

  // Position actuelle pour le rafraîchissement
  double? _currentLat;
  double? _currentLng;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
      _checkAndShowCoachMarks();
    });
  }

  @override
  void dispose() {
    _nearbyRefreshTimer?.cancel();
    _uiRefreshTimer?.cancel();
    super.dispose();
  }

  /// Démarre les timers de rafraîchissement automatique
  void _startRefreshTimers() {
    // Timer pour rafraîchir les membres à proximité
    _nearbyRefreshTimer?.cancel();
    _nearbyRefreshTimer = Timer.periodic(
      Duration(seconds: _nearbyRefreshIntervalSeconds),
      (_) => _refreshNearbyMembers(),
    );

    // Timer pour rafraîchir l'affichage du temps relatif
    _uiRefreshTimer?.cancel();
    _uiRefreshTimer = Timer.periodic(
      Duration(seconds: _uiRefreshIntervalSeconds),
      (_) {
        if (mounted && _lastNearbyUpdate != null) {
          setState(() {}); // Rebuild pour mettre à jour l'affichage du temps
        }
      },
    );
  }

  /// Rafraîchit les membres à proximité (appelé par le timer)
  Future<void> _refreshNearbyMembers() async {
    if (!mounted || _currentLat == null || _currentLng == null) return;

    try {
      await ref
          .read(nearbyProfilesNotifierProvider.notifier)
          .loadNearbyProfiles(_currentLat!, _currentLng!, radiusKm: 50);

      if (mounted) {
        setState(() {
          _lastNearbyUpdate = DateTime.now();
        });
      }
    } catch (e) {
      // Ignorer les erreurs silencieusement pour le rafraîchissement automatique
    }
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
    // Check feature flags
    final hasMoneyTransfer = ref.read(isMoneyTransferEnabledProvider);
    final hasMarketplace = ref.read(isMarketplaceEnabledProvider);
    final hasBusinessDirectory = ref.read(isBusinessDirectoryEnabledProvider);
    final hasEmbassies = ref.read(isEmbassiesEnabledProvider);
    final hasEvents = ref.read(isEventsEnabledProvider);
    final hasGroups = ref.read(isGroupsEnabledProvider);

    final hasServices =
        hasMoneyTransfer || hasMarketplace || hasBusinessDirectory || hasEmbassies;

    // Build dynamic services description based on enabled features
    String buildServicesDescription() {
      final services = <String>[];
      if (hasMoneyTransfer) services.add('transferts d\'argent');
      if (hasMarketplace) services.add('boutique');
      if (hasBusinessDirectory) services.add('annuaire des entreprises');
      if (hasEmbassies) services.add('ambassades');

      if (services.isEmpty) return '';
      if (services.length == 1) return 'Acces rapide au service: ${services.first}.';

      final lastService = services.removeLast();
      return 'Acces rapide aux services: ${services.join(', ')} et $lastService.';
    }

    // Build dynamic search description based on enabled features
    String buildSearchDescription() {
      final searchables = <String>['membres'];
      if (hasGroups) searchables.add('groupes');
      if (hasEvents) searchables.add('evenements');

      if (searchables.length == 1) return 'Trouvez des ${searchables.first} facilement.';

      final last = searchables.removeLast();
      return 'Trouvez des ${searchables.join(', ')} et des $last facilement.';
    }

    // Build dynamic stats description
    String buildStatsDescription() {
      final stats = <String>['membres'];
      if (hasGroups) stats.add('groupes');
      if (hasEvents) stats.add('evenements');

      return 'Decouvrez la communaute: nombre de ${stats.join(', ')}. Appuyez pour explorer.';
    }

    // Determine which is the last coach mark for isLast flag
    final hasEventsCoachMark = hasEvents;

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
                    "Restez informe des nouveaux messages et activites de la communaute.",
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
              return CoachMarkContent(
                title: "Recherche",
                description: buildSearchDescription(),
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
              return CoachMarkContent(
                title: "Statistiques",
                description: buildStatsDescription(),
              );
            },
          ),
        ],
      ),
      // Services section (only if at least one service is enabled)
      if (hasServices)
        TargetFocus(
          identify: "services",
          keyTarget: _servicesKey,
          alignSkip: Alignment.topRight,
          shape: ShapeLightFocus.RRect,
          radius: 20,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              builder: (context, controller) {
                return CoachMarkContent(
                  title: "Services",
                  description: buildServicesDescription(),
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
              return CoachMarkContent(
                title: "Membres proches",
                description:
                    "Decouvrez les Nigeriens dans votre region. Faites glisser pour voir plus de profils.",
                // Last if events feature is disabled
                isLast: !hasEventsCoachMark,
              );
            },
          ),
        ],
      ),
      // Events section (only if events feature is enabled)
      if (hasEventsCoachMark)
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
      // Le profil est chargé automatiquement par le provider family si écouté
      // Mais ici on veut peut-être forcer le rafraichissement ou juste lire
      // On s'assure juste que c'est init
      final profile = ref.read(profileNotifierProvider(currentUser.id)).valueOrNull;

      // Mettre à jour les stats en fonction du pays de l'utilisateur
      if (profile?.currentCountry != null) {
        ref.read(homeStatsNotifierProvider.notifier).setCountry(profile!.currentCountry);
      }

      // Déterminer la localisation
      double lat = 13.5116; // Par défaut: Niamey
      double lng = 2.1254;
      double radius = 50; // Rayon standard

      // Tenter d'obtenir la position actuelle pour mettre à jour
      try {
        final position = await LocationService.instance.getCurrentPosition();
        lat = position.latitude;
        lng = position.longitude;

        if (mounted) {
          setState(() {
            _locationError = null;
          });

          // Mettre à jour la position du profil
          // updateLocation prend (lat, lng), userId est dans le provider
          ref
              .read(profileNotifierProvider(currentUser.id).notifier)
              .updateLocation(lat, lng);

          // Charger les profils à proximité UNIQUEMENT si la localisation est active
          await ref
              .read(nearbyProfilesNotifierProvider.notifier)
              .loadNearbyProfiles(lat, lng, radiusKm: radius);

          // Mettre à jour le timestamp et sauvegarder la position
          if (mounted) {
            setState(() {
              _lastNearbyUpdate = DateTime.now();
              _currentLat = lat;
              _currentLng = lng;
            });

            // Démarrer les timers de rafraîchissement automatique
            _startRefreshTimers();
          }
        }
      } catch (e) {
        // debugPrint('Erreur de localisation HomeScreen: $e');

        if (mounted) {
          setState(() {
            _locationError = e.toString();
          });
        }

        // La règle de réciprocité: si pas de localisation, pas de membres à proximité
        // On ne fait PAS de fallback sur la localisation du profil pour le chargement des autres
      }
    }
  }

  /// Formate un DateTime en temps relatif (ex: "il y a 2 min")
  String _formatRelativeTime(DateTime? dateTime, AppLocalizations l10n) {
    if (dateTime == null) return l10n.loading;

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 10) {
      return l10n.justNow;
    } else if (difference.inSeconds < 60) {
      return l10n.secondsAgo(difference.inSeconds);
    } else if (difference.inMinutes < 60) {
      return l10n.minutesAgo(difference.inMinutes);
    } else {
      return l10n.hoursAgo(difference.inHours);
    }
  }

  String _getInitials(String? name) {
    if (name == null || name.trim().isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  Widget _buildAvatarPlaceholder(BuildContext context, String? name) {
    return Container(
      color: context.adaptivePrimaryColor,
      child: Center(
        child: Text(
          _getInitials(name),
          style: const TextStyle(
            color: AppColors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildReciprocityCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.warningColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.warningColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.location_off_outlined,
            size: 40,
            color: context.warningColor,
          ),
          const SizedBox(height: 12),
          Text(
            "Localisation requise",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: context.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Pour voir les membres à proximité, vous devez activer votre localisation. C'est donnant-donnant !",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: context.textSecondaryColor),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () async {
              await LocationService.instance.openLocationSettings();
              await Future.delayed(const Duration(seconds: 1));
              _loadData();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: context.warningColor,
              foregroundColor: Colors.white,
            ),
            child: const Text("Activer la localisation"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final authState = ref.watch(authNotifierProvider);
    final authUser = authState.maybeWhen(
      authenticated: (user) => user,
      orElse: () => null,
    );
    final profileAsync =
        authUser != null
            ? ref.watch(profileNotifierProvider(authUser.id))
            : const AsyncValue.data(null);
    final homeStats = ref.watch(homeStatsNotifierProvider);
    final nearbyProfiles = ref.watch(nearbyProfilesNotifierProvider);

    final upcomingEvents = ref.watch(eventsNotifierProvider);

    // Écouter les changements d'utilisateur pour recharger les données si nécessaire
    ref.listen(currentUserAsyncProvider, (previous, next) {
      final user = next.valueOrNull;
      if (user != null) {
        // Si l'utilisateur vient d'être chargé ou a changé, on recharge les données
        // On vérifie si c'est la première connexion (previous.value était null)
        // ou si l'ID a changé
        if (previous?.valueOrNull == null ||
            previous!.valueOrNull!.id != user.id) {
          _loadData();
        }
      }
    });

    // Écouter les changements de profil pour mettre à jour les stats par pays
    if (authUser != null) {
      ref.listen(profileNotifierProvider(authUser.id), (previous, next) {
        final newCountry = next.valueOrNull?.currentCountry;
        final oldCountry = previous?.valueOrNull?.currentCountry;
        if (newCountry != oldCountry && newCountry != null) {
          ref.read(homeStatsNotifierProvider.notifier).setCountry(newCountry);
        }
      });
    }

    // Priorité aux données du profil, sinon fallback sur auth
    final profile = profileAsync.valueOrNull;

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
                                                (_, __) => _buildAvatarPlaceholder(
                                                  context,
                                                  userName,
                                                ),
                                            errorWidget:
                                                (_, __, ___) => _buildAvatarPlaceholder(
                                                  context,
                                                  userName,
                                                ),
                                          )
                                          : _buildAvatarPlaceholder(
                                            context,
                                            userName,
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
                              onTap: () => context.push('/qr-scanner'),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.white.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.qr_code_scanner,
                                  color: AppColors.white,
                                  size: 24,
                                ),
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
                  // Stats Header with country
                  if (profile?.currentCountry != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 16,
                            color: context.adaptivePrimaryColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            profile!.currentCountry!,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: context.textSecondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Stats Row
                  Container(
                    key: _statsRowKey,
                    child: homeStats.when(
                      skipLoadingOnRefresh: true,
                      data:
                          (stats) => Row(
                            children: [
                              Expanded(
                                child: HomeStatCard(
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
                                child: HomeStatCard(
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
                                child: HomeStatCard(
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
                              Expanded(child: HomeStatCardLoading()),
                              const SizedBox(width: 12),
                              Expanded(child: HomeStatCardLoading()),
                              const SizedBox(width: 12),
                              Expanded(child: HomeStatCardLoading()),
                            ],
                          ),
                      error:
                          (_, __) => Row(
                            children: [
                              Expanded(
                                child: HomeStatCard(
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
                                child: HomeStatCard(
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
                                child: HomeStatCard(
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

                  // Quick Actions - Services (le Fil d'actualité est toujours
                  // disponible, la section est donc toujours affichée)
                  Column(
                      key: _servicesKey,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        HomeSectionHeader(
                          title: 'Services',
                          onSeeAll: () => context.push('/services'),
                          seeAllText: l10n.seeAll,
                        ),
                        const SizedBox(height: 16),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              // Fil d'actualité (toujours disponible)
                              Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: QuickActionCard(
                                  width: 110,
                                  icon: Icons.dynamic_feed_rounded,
                                  label: 'Fil d\'actualité',
                                  color: context.adaptivePrimaryColor,
                                  onTap: () => context.push('/feed'),
                                ),
                              ),
                              // Money Transfer
                              if (ref.watch(isMoneyTransferEnabledProvider))
                                Padding(
                                  padding: const EdgeInsets.only(right: 12),
                                  child: QuickActionCard(
                                    width: 110,
                                    icon: Icons.send_rounded,
                                    label: 'Transfert',
                                    color: context.adaptivePrimaryColor,
                                    onTap: () => context.push('/transfers'),
                                  ),
                                ),
                              // Marketplace
                              if (ref.watch(isMarketplaceEnabledProvider))
                                Padding(
                                  padding: const EdgeInsets.only(right: 12),
                                  child: QuickActionCard(
                                    width: 110,
                                    icon: Icons.storefront_rounded,
                                    label: 'Boutique',
                                    color: context.adaptiveSecondaryColor,
                                    onTap: () => context.push('/marketplace'),
                                  ),
                                ),
                              // Business Directory
                              if (ref.watch(isBusinessDirectoryEnabledProvider))
                                Padding(
                                  padding: const EdgeInsets.only(right: 12),
                                  child: QuickActionCard(
                                    width: 110,
                                    icon: Icons.business_rounded,
                                    label: 'Annuaire',
                                    color:
                                        Theme.of(
                                          context,
                                        ).colorScheme.onPrimaryContainer,
                                    onTap: () => context.push('/businesses'),
                                  ),
                                ),
                              // Embassies
                              if (ref.watch(isEmbassiesEnabledProvider))
                                QuickActionCard(
                                  width: 110,
                                  icon: Icons.account_balance,
                                  label: 'Ambassades',
                                  color: Colors.indigo,
                                  onTap: () => context.push('/embassies'),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 28),

                  // Section Membres
                  Column(
                    key: _nearbyMembersKey,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      HomeSectionHeader(
                        title: l10n.membersNearby,
                        onSeeAll: () => context.go('/map'),
                        seeAllText: l10n.seeAll,
                      ),
                      // Indicateur de dernière mise à jour
                      if (_lastNearbyUpdate != null && _locationError == null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4, bottom: 12),
                          child: Row(
                            children: [
                              Icon(
                                Icons.update,
                                size: 12,
                                color: context.textTertiaryColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatRelativeTime(_lastNearbyUpdate, l10n),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: context.textTertiaryColor,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        const SizedBox(height: 16),
                      if (_locationError != null)
                        _buildReciprocityCard()
                      else
                        nearbyProfiles.when(
                          skipLoadingOnRefresh: true,
                          data: (profiles) {
                            // Filter out blocked users (both ways)
                            final blockedUsers = ref.watch(blockedUsersProvider).valueOrNull ?? [];
                            final blockedUserIds = blockedUsers.map((u) => u.id).toSet();
                            final currentUserId = ref.watch(currentUserProvider).valueOrNull?.id;

                            final filteredProfiles = profiles.where((p) {
                              // Skip if I blocked them
                              if (blockedUserIds.contains(p.id)) return false;
                              // Skip if they blocked me
                              if (currentUserId != null && p.blockedByUserIds.contains(currentUserId)) return false;
                              return true;
                            }).toList();

                            if (filteredProfiles.isEmpty) {
                              return HomeEmptyStateCard(
                                icon: Icons.people_outline,
                                message: l10n.noMembersNearby,
                              );
                            }

                            return SizedBox(
                              height: 200,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount:
                                    filteredProfiles.length > 10 ? 10 : filteredProfiles.length,
                                itemBuilder: (context, index) {
                                  final profile = filteredProfiles[index];
                                  return Padding(
                                    padding: EdgeInsets.only(
                                      left: index == 0 ? 0 : 12,
                                      right:
                                          index ==
                                                  (filteredProfiles.length > 10
                                                      ? 9
                                                      : filteredProfiles.length - 1)
                                              ? 0
                                              : 0,
                                    ),
                                    child: GestureDetector(
                                      onTap:
                                          () => context.push(
                                            '/profile/${profile.id}',
                                            extra: profile,
                                          ),
                                      child: HomeMemberCard(
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
                                        child: HomeMemberCardLoading(),
                                      ),
                                ),
                              ),
                          error:
                              (_, __) => HomeEmptyStateCard(
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
                      HomeSectionHeader(
                        title: l10n.upcomingEvents,
                        onSeeAll: () => context.push('/events'),
                        seeAllText: l10n.seeAll,
                      ),
                      const SizedBox(height: 16),
                      upcomingEvents.when(
                        skipLoadingOnRefresh: true,
                        data: (events) {
                          final upcoming = events.take(3).toList();
                          if (upcoming.isEmpty) {
                            return HomeEmptyStateCard(
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
                                          child: HomeEventCard(
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
                                  child: HomeEventCardLoading(),
                                ),
                              ),
                            ),
                        error:
                            (_, __) => HomeEmptyStateCard(
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
            SliverToBoxAdapter(
              child: SizedBox(height: MediaQuery.of(context).padding.bottom),
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
