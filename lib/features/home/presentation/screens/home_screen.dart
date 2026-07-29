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
import '../../../../core/utils/geo_utils.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../events/presentation/providers/event_provider.dart';
import '../../../onboarding/presentation/providers/onboarding_provider.dart';
import '../../../onboarding/presentation/widgets/coach_mark_content.dart';
import '../../../notifications/presentation/providers/notification_provider.dart';
import '../../../messages/presentation/providers/message_provider.dart';
import '../../../events/domain/entities/event_entity.dart';
import '../../../settings/presentation/providers/blocked_users_provider.dart';
import '../providers/home_provider.dart';

import '../widgets/home_section_header.dart';
import '../widgets/home_empty_state_card.dart';
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
            // En-tête plat (le dégradé orange disparaît — refonte 8a).
            SliverToBoxAdapter(
              child: Container(
                color: context.backgroundColor,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
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
                                    color: context.borderColor,
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
                                      fontSize: 13.5,
                                      color: context.textSecondaryColor,
                                    ),
                                  ),
                                  Text(
                                    userName.split(' ').first,
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: context.textPrimaryColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),

                            GestureDetector(
                              onTap: () => context.push('/qr-scanner'),
                              child: Container(
                                width: 44,
                                height: 44,
                                alignment: Alignment.center,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: context.surfaceVariantColor,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  Icons.qr_code_scanner,
                                  color: context.textSecondaryColor,
                                  size: 22,
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
                                    width: 44,
                                    height: 44,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: context.surfaceVariantColor,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(
                                      Icons.notifications_outlined,
                                      color: context.textSecondaryColor,
                                      size: 22,
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
                              border: Border.all(color: context.borderColor),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.search,
                                  color: context.textTertiaryColor,
                                  size: 22,
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
                                Icon(
                                  Icons.tune,
                                  color: context.adaptivePrimaryColor,
                                  size: 22,
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
                  // Ligne de contexte : ville + compteurs (remplace les trois
                  // cartes de stats — refonte 8a).
                  Container(
                    key: _statsRowKey,
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _ContextLine(
                      city: profile?.currentCity,
                      country: profile?.currentCountry,
                      members: homeStats.valueOrNull?.membersCount,
                      groups: homeStats.valueOrNull?.groupsCount,
                    ),
                  ),

                  // Bloc « Aujourd'hui » : messages non lus, prochain
                  // événement, membres proches.
                  _TodayCard(
                    unread: ref.watch(totalUnreadCountProvider),
                    nextEvent: _nextEvent(upcomingEvents.valueOrNull),
                    nearbyCount: _locationError != null
                        ? null
                        : nearbyProfiles.valueOrNull?.length,
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
                        // Grille 4 colonnes (remplace le carrousel horizontal
                        // qui masquait la moitié des services).
                        const _ServicesGrid(),
                      ],
                    ),

                  const SizedBox(height: 28),

                  // Section « Autour de vous » : rangée d'avatars circulaires
                  // avec la distance (remplace les grandes cartes membres —
                  // refonte accueil).
                  Column(
                    key: _nearbyMembersKey,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      HomeSectionHeader(
                        title: l10n.aroundYou,
                        onSeeAll: () => context.go('/map'),
                        seeAllText: l10n.theMap,
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

                            // On affiche au plus 8 avatars, puis une pastille
                            // « +N / La carte » qui renvoie vers la carte.
                            const maxAvatars = 8;
                            final visible =
                                filteredProfiles.take(maxAvatars).toList();
                            final remaining =
                                filteredProfiles.length - visible.length;

                            return SizedBox(
                              height: 120,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: visible.length + (remaining > 0 ? 1 : 0),
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 16),
                                itemBuilder: (context, index) {
                                  if (index >= visible.length) {
                                    return _SeeAllAvatar(
                                      count: remaining,
                                      label: l10n.seeAll,
                                      onTap: () => context.go('/map'),
                                    );
                                  }
                                  final p = visible[index];
                                  return _NearbyAvatar(
                                    name: p.displayName ?? 'Membre',
                                    photoUrl: p.photoUrl,
                                    distance:
                                        _distanceLabel(p.latitude, p.longitude),
                                    color: _avatarColor(p.id),
                                    onTap: () => context.push(
                                      '/profile/${p.id}',
                                      extra: p,
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                          loading: () => SizedBox(
                            height: 120,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: 4,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 16),
                              itemBuilder: (_, __) => const _NearbyAvatarLoading(),
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
                                            date: event.startDate,
                                            subtitle: _eventSubtitle(
                                              event,
                                              l10n,
                                            ),
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

  /// Prochain événement à venir (le plus proche dans le futur) parmi la liste
  /// chargée, ou `null`.
  EventEntity? _nextEvent(List<EventEntity>? events) {
    if (events == null || events.isEmpty) return null;
    final now = DateTime.now();
    final upcoming =
        events.where((e) => e.startDate.isAfter(now)).toList()
          ..sort((a, b) => a.startDate.compareTo(b.startDate));
    return upcoming.isNotEmpty ? upcoming.first : null;
  }

  /// Ligne de contexte de l'événement : « Paris 18e · 14 h · 62 participants ».
  String _eventSubtitle(EventEntity e, AppLocalizations l10n) {
    final parts = <String>[];
    if (e.location.trim().isNotEmpty) parts.add(e.location.trim());
    final minute = e.startDate.minute;
    parts.add(
      minute == 0
          ? '${e.startDate.hour} h'
          : '${e.startDate.hour} h ${minute.toString().padLeft(2, '0')}',
    );
    parts.add(l10n.participants(e.attendeeIds.length));
    return parts.join(' · ');
  }

  /// Distance formatée « 1,2 km » entre l'utilisateur et un profil, ou `null`
  /// si la position (de l'un ou l'autre) est indisponible.
  String? _distanceLabel(double? lat, double? lng) {
    if (_currentLat == null || _currentLng == null) return null;
    if (lat == null || lng == null) return null;
    final d = GeoUtils.calculateDistance(_currentLat!, _currentLng!, lat, lng);
    return GeoUtils.formatDistance(d).replaceAll('.', ',');
  }
}

// ── Refonte 8a : ligne de contexte, bloc « Aujourd'hui », grille services ────

const _homeLocation = Color(0xFFB85E24);
const _homeGreen = Color(0xFF2D7D46);
const _homeOrange = Color(0xFFB85E24);
const _homeBadgeRed = Color(0xFFC23E2D);

String _eventDateLabel(DateTime date) {
  const months = [
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
  return '${date.day} ${months[date.month - 1]}';
}

/// Ligne « Paris, France · 318 membres · 12 groupes » qui remplace les trois
/// cartes de stats. La ville reste toujours lisible ; le reste s'ellipse.
class _ContextLine extends StatelessWidget {
  final String? city;
  final String? country;
  final int? members;
  final int? groups;

  const _ContextLine({this.city, this.country, this.members, this.groups});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final place = [
      city,
      country,
    ].where((e) => e != null && e.trim().isNotEmpty).join(', ');

    final parts = <String>[];
    if (members != null) {
      parts.add('${formatCount(members!)} ${l10n.membersLabel.toLowerCase()}');
    }
    if (groups != null) {
      parts.add('${formatCount(groups!)} ${l10n.groupsTitle.toLowerCase()}');
    }
    final trailing = parts.isEmpty ? '' : '· ${parts.join(' · ')}';

    if (place.isEmpty && trailing.isEmpty) return const SizedBox.shrink();

    return Row(
      children: [
        const Icon(Icons.location_on, size: 15, color: _homeLocation),
        const SizedBox(width: 6),
        if (place.isNotEmpty)
          Text(
            place,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.textPrimaryColor,
            ),
          ),
        if (place.isNotEmpty && trailing.isNotEmpty) const SizedBox(width: 6),
        if (trailing.isNotEmpty)
          Expanded(
            child: Text(
              trailing,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: context.textTertiaryColor),
            ),
          ),
      ],
    );
  }
}

/// Bloc « Aujourd'hui » : jusqu'à trois lignes actionnables (messages non lus,
/// prochain événement, membres proches). Masqué si aucune ligne ne s'applique.
class _TodayCard extends StatelessWidget {
  final int unread;
  final EventEntity? nextEvent;
  final int? nearbyCount;

  const _TodayCard({
    required this.unread,
    required this.nextEvent,
    required this.nearbyCount,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final rows = <Widget>[];
    if (unread > 0) {
      rows.add(
        _TodayRow(
          bg: _homeGreen.withValues(alpha: 0.12),
          iconColor: _homeGreen,
          icon: Icons.chat_bubble_outline_rounded,
          title: l10n.messagesUnreadTitle,
          trailing: _CountBadge(count: unread, color: _homeBadgeRed),
          onTap: () => context.go('/messages'),
        ),
      );
    }
    if (nextEvent != null) {
      final e = nextEvent!;
      final subtitle = e.location.trim().isEmpty
          ? _eventDateLabel(e.startDate)
          : '${_eventDateLabel(e.startDate)} · ${e.location}';
      rows.add(
        _TodayRow(
          bg: _homeOrange.withValues(alpha: 0.12),
          iconColor: _homeOrange,
          icon: Icons.event_rounded,
          title: e.title,
          subtitle: subtitle,
          trailing: _PillButton(
            label: l10n.participate,
            onTap: () => context.push('/events/${e.id}', extra: e),
          ),
          onTap: () => context.push('/events/${e.id}', extra: e),
        ),
      );
    }
    if (nearbyCount != null && nearbyCount! > 0) {
      rows.add(
        _TodayRow(
          bg: context.adaptivePrimaryColor.withValues(alpha: 0.10),
          iconColor: context.adaptivePrimaryColor,
          icon: Icons.people_alt_outlined,
          title: l10n.membersNearby,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CountBadge(
                count: nearbyCount!,
                color: context.textTertiaryColor,
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: context.textTertiaryColor,
              ),
            ],
          ),
          onTap: () => context.go('/map'),
        ),
      );
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.todayTitle.toUpperCase(),
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 10.5,
              letterSpacing: 1.05,
              fontWeight: FontWeight.w700,
              color: context.textTertiaryColor,
            ),
          ),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 1, color: context.borderColor),
            rows[i],
          ],
        ],
      ),
    );
  }
}

class _TodayRow extends StatelessWidget {
  final Color bg;
  final Color iconColor;
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  const _TodayRow({
    required this.bg,
    required this.iconColor,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.textPrimaryColor,
                    ),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textSecondaryColor,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;
  final Color color;

  const _CountBadge({required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 22),
      height: 22,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PillButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: _homeOrange,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Grille 4 colonnes des services (remplace le carrousel horizontal). Chaque
/// tuile est conditionnée par son feature flag ; le Fil est toujours présent.
class _ServicesGrid extends ConsumerWidget {
  const _ServicesGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = <Widget>[
      _ServiceTile(
        icon: Icons.dynamic_feed_rounded,
        label: 'Le fil',
        color: context.adaptivePrimaryColor,
        onTap: () => context.push('/feed'),
      ),
      if (ref.watch(isMoneyTransferEnabledProvider))
        _ServiceTile(
          icon: Icons.send_rounded,
          label: 'Transfert',
          color: context.adaptivePrimaryColor,
          onTap: () => context.push('/transfers'),
        ),
      if (ref.watch(isMarketplaceEnabledProvider))
        _ServiceTile(
          icon: Icons.storefront_rounded,
          label: 'Boutique',
          color: context.adaptiveSecondaryColor,
          onTap: () => context.push('/marketplace'),
        ),
      if (ref.watch(isBusinessDirectoryEnabledProvider))
        _ServiceTile(
          icon: Icons.business_rounded,
          label: 'Annuaire',
          color: Theme.of(context).colorScheme.onPrimaryContainer,
          onTap: () => context.push('/businesses'),
        ),
      if (ref.watch(isEmbassiesEnabledProvider))
        _ServiceTile(
          icon: Icons.account_balance,
          label: 'Ambassades',
          color: context.adaptiveSecondaryColor,
          onTap: () => context.push('/embassies'),
        ),
    ];

    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.8,
      children: items,
    );
  }
}

class _ServiceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ServiceTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              alignment: Alignment.center,
              // Carte blanche à bord léger (remplace la pastille teintée —
              // refonte accueil).
              decoration: BoxDecoration(
                color: context.surfaceColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: context.borderColor),
                boxShadow: context.isDarkMode
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: Icon(icon, size: 26, color: color),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: context.textSecondaryColor,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Refonte accueil : section « Autour de vous » (avatars circulaires) ───────

/// Palette d'avatars (orange, vert, sarcelle, brique, violet) alignée sur la
/// maquette. La couleur est stable pour un même profil via son id.
const _avatarPalette = <Color>[
  Color(0xFFB85E24), // orange
  Color(0xFF2D7D46), // vert
  Color(0xFF2A7F7B), // sarcelle
  Color(0xFFC23E2D), // brique
  Color(0xFF7A5AA8), // violet
];

Color _avatarColor(String seed) =>
    _avatarPalette[seed.hashCode.abs() % _avatarPalette.length];

String _avatarInitials(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '?';
  final parts = trimmed.split(RegExp(r'\s+'));
  if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
  return trimmed[0].toUpperCase();
}

/// Avatar circulaire d'un membre proche : cercle coloré (photo ou initiales),
/// prénom, puis distance formatée.
class _NearbyAvatar extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final String? distance;
  final Color color;
  final VoidCallback onTap;

  const _NearbyAvatar({
    required this.name,
    required this.photoUrl,
    required this.distance,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 68,
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              clipBehavior: Clip.antiAlias,
              alignment: Alignment.center,
              child: photoUrl != null
                  ? CachedNetworkImage(
                      imageUrl: photoUrl!,
                      fit: BoxFit.cover,
                      width: 60,
                      height: 60,
                      placeholder: (_, __) => _initials(),
                      errorWidget: (_, __, ___) => _initials(),
                    )
                  : _initials(),
            ),
            const SizedBox(height: 8),
            Text(
              name.split(' ').first,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.2,
                fontWeight: FontWeight.w600,
                color: context.textPrimaryColor,
              ),
            ),
            if (distance != null)
              Text(
                distance!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.2,
                  color: context.textTertiaryColor,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _initials() => Text(
        _avatarInitials(name),
        style: const TextStyle(
          color: AppColors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      );
}

/// Pastille finale « +N / Voir tout » de la rangée d'avatars.
class _SeeAllAvatar extends StatelessWidget {
  final int count;
  final String label;
  final VoidCallback onTap;

  const _SeeAllAvatar({
    required this.count,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 68,
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.surfaceVariantColor,
                shape: BoxShape.circle,
              ),
              child: Text(
                '+$count',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: context.textSecondaryColor,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: context.textSecondaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Placeholder de chargement d'un avatar proche.
class _NearbyAvatarLoading extends StatelessWidget {
  const _NearbyAvatarLoading();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 68,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: context.surfaceVariantColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 44,
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
