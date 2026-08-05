import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:geocoding/geocoding.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import '../../../../core/services/location_service.dart';
import '../../../../core/services/deep_link_service.dart';
import '../../../../core/services/feature_flag_service.dart';
import '../../../../core/services/preferences_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/providers/connectivity_provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../../../core/utils/geo_utils.dart';
import '../../../profile/domain/entities/profile_entity.dart';
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

part 'home_screen_widgets.dart';

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
  static const double _nearbyRadiusDefaultKm = 50; // Rayon initial « Autour de vous »
  static const double _nearbyRadiusWideKm = 200; // Rayon élargi à la demande

  // Rayon courant : élargi de 50 à 200 km via le bouton de l'état vide.
  double _nearbyRadiusKm = _nearbyRadiusDefaultKm;

  /// Recherche déclenchée par la personne (élargissement du rayon), par
  /// opposition au rafraîchissement automatique toutes les 60 s.
  ///
  /// `skipLoadingOnRefresh: true` garde volontairement les résultats
  /// précédents pendant un rafraîchissement de fond — mais il gardait aussi
  /// l'état vide « Personne à moins de 50 km » affiché pendant toute la
  /// recherche à 200 km, ce que la maquette 1b/CAS 3 interdit explicitement.
  /// Ce drapeau force le squelette pour ce cas-là seulement.
  bool _nearbySearching = false;

  // Position actuelle pour le rafraîchissement
  double? _currentLat;
  double? _currentLng;

  // Ville / pays résolus par géocodage inverse de la position GPS. Servent de
  // repli dans la ligne de contexte quand le profil n'a pas ces champs.
  String? _geoCity;
  String? _geoCountry;

  // Bandeau hors-ligne masqué manuellement (« Lire hors ligne ») ; réaffiché
  // à la prochaine coupure réseau.
  bool _offlineDismissed = false;

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
          .loadNearbyProfiles(_currentLat!, _currentLng!,
              radiusKm: _nearbyRadiusKm);

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
    final l10n = AppLocalizations.of(context)!;
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
      if (hasMoneyTransfer) services.add(l10n.homeServiceTransfers);
      if (hasMarketplace) services.add(l10n.homeServiceShop);
      if (hasBusinessDirectory) services.add(l10n.serviceBusinessDirectory);
      if (hasEmbassies) services.add(l10n.homeServiceEmbassies);

      if (services.isEmpty) return '';
      return l10n.homeA11yServices(_enumere(services, l10n));
    }

    // Build dynamic search description based on enabled features
    String buildSearchDescription() {
      final searchables = <String>[l10n.homeSearchableMembers];
      if (hasGroups) searchables.add(l10n.homeSearchableGroups);
      if (hasEvents) searchables.add(l10n.homeSearchableEvents);

      return l10n.homeA11ySearch(_enumere(searchables, l10n));
    }

    // Build dynamic stats description
    String buildStatsDescription() {
      final stats = <String>[l10n.homeSearchableMembers];
      if (hasGroups) stats.add(l10n.homeSearchableGroups);
      if (hasEvents) stats.add(l10n.homeSearchableEvents);

      return l10n.homeA11yStats(_enumere(stats, l10n));
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
      double radius = _nearbyRadiusKm;

      // Premier affichage sans attendre le GPS. `getLastKnownPosition` répond
      // tout de suite, là où un point frais peut demander une quinzaine de
      // secondes — pendant lesquelles la section « membres autour » restait
      // vide, exactement comme sur la carte.
      var hasEarlyPosition = false;
      try {
        final lastKnown = await LocationService.instance.getLastKnownPosition();
        if (lastKnown != null && mounted) {
          lat = lastKnown.latitude;
          lng = lastKnown.longitude;
          hasEarlyPosition = true;

          setState(() {
            _locationError = null;
            _currentLat = lat;
            _currentLng = lng;
            _lastNearbyUpdate = DateTime.now();
          });

          // Sans `await` : le point GPS frais est demandé juste en dessous.
          unawaited(
            ref
                .read(nearbyProfilesNotifierProvider.notifier)
                .loadNearbyProfiles(lat, lng, radiusKm: radius),
          );
          _startRefreshTimers();
          _resolvePlaceName(lat, lng);
        }
      } catch (_) {
        // Aucune position en cache : le point frais ci-dessous prend le relais.
      }

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

          // Résoudre ville/pays depuis la position (repli pour la ligne stats).
          _resolvePlaceName(lat, lng);
        }
      } catch (e) {
        // debugPrint('Erreur de localisation HomeScreen: $e');

        if (mounted && !hasEarlyPosition) {
          // Si la dernière position connue a déjà peuplé la section, un GPS
          // lent n'est pas une absence de localisation : afficher l'erreur
          // reviendrait à vider un écran qui marche.
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

    // Complétude du profil (premier lancement — maquette 8a). Les cartes
    // d'onboarding restent affichées tant que le profil est incomplet.
    final placeCity = (profile?.currentCity?.trim().isNotEmpty ?? false)
        ? profile!.currentCity
        : _geoCity;
    final completion = _computeCompletion(profile, placeCity);
    final showOnboarding = profile != null && completion.filled < completion.total;

    // Hors-ligne : bandeau explicatif (contenu en cache) — maquette 2d.
    final isOnline = ref.watch(connectivityNotifierProvider);
    final showOffline = !isOnline && !_offlineDismissed;

    // Événement passé le plus récent, pour l'état vide « rien à venir, mais un
    // passé » des Événements (maquette 1c/CAS 3).
    final recentPastEvent = ref.watch(recentPastEventProvider).valueOrNull;
    // Topic FCM pour « M'avertir du prochain » (par pays si connu).
    final rawCc = (profile?.countryCode?.trim().isNotEmpty ?? false)
        ? profile!.countryCode!.trim()
        : (profile?.currentCountry?.trim().isNotEmpty ?? false)
            ? profile!.currentCountry!.trim()
            : 'all';
    final eventsTopic =
        'events_${rawCc.replaceAll(RegExp(r"[^A-Za-z0-9_-]"), "")}';

    // Retour du réseau : réarmer le bandeau et rafraîchir le contenu.
    ref.listen(connectivityNotifierProvider, (previous, next) {
      if (next == true) {
        if (_offlineDismissed && mounted) {
          setState(() => _offlineDismissed = false);
        }
        ref.read(homeStatsNotifierProvider.notifier).refresh();
        _loadData();
      }
    });

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
                                    style: GoogleFonts.playfairDisplay(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                      height: 1.1,
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
                                  color: context.surfaceColor,
                                  borderRadius: BorderRadius.circular(13),
                                  border: Border.all(color: context.borderColor),
                                ),
                                child: Icon(
                                  Icons.qr_code_scanner,
                                  color: context.textPrimaryColor,
                                  size: 20,
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
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
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
                  // Bandeau hors-ligne : contenu en cache + réessayer (2d).
                  if (showOffline) ...[
                    _OfflineBanner(
                      onRetry: () {
                        ref
                            .read(connectivityNotifierProvider.notifier)
                            .checkConnectivity();
                        ref.read(homeStatsNotifierProvider.notifier).refresh();
                        _loadData();
                      },
                      onDismiss: () =>
                          setState(() => _offlineDismissed = true),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Premier lancement : progression du profil, masquée dès qu'il
                  // est complet (maquette 8a).
                  if (showOnboarding) ...[
                    _ProfileCompletionCard(
                      filled: completion.filled,
                      total: completion.total,
                      ctaLabel: completion.ctaLabel,
                      message: completion.message,
                      onTap: () => context.push('/profile/edit'),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Ligne de contexte : ville + compteurs (remplace les trois
                  // cartes de stats — refonte 8a).
                  Container(
                    key: _statsRowKey,
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _ContextLine(
                      city: (profile?.currentCity?.trim().isNotEmpty ?? false)
                          ? profile!.currentCity
                          : _geoCity,
                      country:
                          (profile?.currentCountry?.trim().isNotEmpty ?? false)
                              ? profile!.currentCountry
                              : _geoCountry,
                      members: homeStats.valueOrNull?.membersCount,
                      groups: homeStats.valueOrNull?.groupsCount,
                    ),
                  ),

                  // Premier lancement : raccourcis d'onboarding (maquette 8a).
                  if (showOnboarding) ...[
                    _PourCommencerCard(
                      groupsCount: homeStats.valueOrNull?.groupsCount ?? 0,
                      onFindFriends: () => context.push('/qr-scanner'),
                      onJoinGroup: () => context.push('/groups'),
                      onActivateMap: _locationError != null
                          ? _enableLocation
                          : () => context.go('/map'),
                    ),
                    const SizedBox(height: 20),
                  ],

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
                        // Grille adaptative (3 ou 4 colonnes selon le nombre de
                        // services) — remplace le carrousel horizontal.
                        const _ServicesGrid(),
                      ],
                    ),

                  // Espace réduit avant « Autour de vous » (demande accueil).
                  const SizedBox(height: 20),

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
                        _NoPositionCard(onActivate: _enableLocation)
                      // Recherche demandée explicitement : le squelette passe
                      // devant les résultats précédents (maquette 1b/CAS 3).
                      else if (_nearbySearching)
                        const NearbyLoadingRow()
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
                              // État vide « position active, personne autour » :
                              // on explique la cause et on propose des issues
                              // plutôt qu'un simple libellé (maquette 1b/CAS 1).
                              return _NearbyEmptyCard(
                                radiusKm: _nearbyRadiusKm,
                                city: (profile?.currentCity?.trim().isNotEmpty ??
                                        false)
                                    ? profile!.currentCity
                                    : _geoCity,
                                canWiden:
                                    _nearbyRadiusKm < _nearbyRadiusWideKm,
                                onWiden: _widenRadius,
                                onInvite: _inviteFriend,
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
                          loading: () => const NearbyLoadingRow(),
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

                          if (upcoming.isNotEmpty) {
                            final hasPhysical =
                                upcoming.any((e) => !e.isOnline);
                            // CAS 1 : rien en présentiel, mais des événements en
                            // ligne accessibles (maquette 1c/CAS 1).
                            if (!hasPhysical) {
                              return _EventsOnlineOnlyCard(
                                events: upcoming,
                                city: placeCity,
                                subtitleOf: (e) => _eventSubtitle(e, l10n),
                              );
                            }
                            // Cartes normales (badge « EN LIGNE » si en ligne).
                            return Column(
                              children: upcoming
                                  .map(
                                    (event) => Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 12),
                                      child: GestureDetector(
                                        onTap: () => context.push(
                                          '/events/${event.id}',
                                          extra: event,
                                        ),
                                        child: HomeEventCard(
                                          title: event.title,
                                          date: event.startDate,
                                          subtitle: _eventSubtitle(event, l10n),
                                          isOnline: event.isOnline,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            );
                          }

                          // Rien à venir : CAS 3 si un événement passé existe,
                          // sinon CAS 2 (créer le premier).
                          if (recentPastEvent != null) {
                            return _EventsPastCard(
                              event: recentPastEvent,
                              subtitle:
                                  'Terminé · ${l10n.participants(recentPastEvent.attendeeIds.length)}',
                              notifyTopic: eventsTopic,
                            );
                          }
                          return _EventsEmptyCard(city: placeCity);
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

  /// Géocode inverse de la position en ville + pays, mémorisés pour la ligne
  /// de contexte. Silencieux en cas d'échec (réseau, quota).
  Future<void> _resolvePlaceName(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (!mounted || placemarks.isEmpty) return;
      final p = placemarks.first;
      final city = (p.locality?.trim().isNotEmpty ?? false)
          ? p.locality!.trim()
          : (p.subAdministrativeArea?.trim().isNotEmpty ?? false)
              ? p.subAdministrativeArea!.trim()
              : null;
      final country =
          (p.country?.trim().isNotEmpty ?? false) ? p.country!.trim() : null;
      if (city == null && country == null) return;
      setState(() {
        _geoCity = city;
        _geoCountry = country;
      });
    } catch (_) {
      // Géocodage indisponible : on garde les champs du profil s'ils existent.
    }
  }

  /// Enumère une liste en langue naturelle : « a, b et c ». La liaison
  /// finale vient de l'ARB, elle n'est pas la même dans toutes les langues.
  String _enumere(List<String> elements, AppLocalizations l10n) {
    if (elements.isEmpty) return '';
    if (elements.length == 1) return elements.first;
    final reste = elements.sublist(0, elements.length - 1);
    return '${reste.join(', ')}${l10n.listSeparatorAnd}${elements.last}';
  }

  /// Calcule la complétude du profil sur 5 champs clés et prépare le libellé
  /// d'action + le message contextuel (premier lancement — maquette 8a).
  _ProfileCompletion _computeCompletion(
    ProfileEntity? profile,
    String? city,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final items = <({bool done, String cta, String name})>[
      (
        done: (profile?.photoUrl?.trim().isNotEmpty ?? false),
        cta: l10n.addPhoto,
        name: l10n.homeFieldPhoto,
      ),
      (
        done: (profile?.currentCity?.trim().isNotEmpty ?? false),
        cta: l10n.homeAddCity,
        name: l10n.homeFieldCity,
      ),
      (
        done: (profile?.currentCountry?.trim().isNotEmpty ?? false),
        cta: l10n.homeAddCountry,
        name: l10n.homeFieldCountry,
      ),
      (
        done: (profile?.profession?.trim().isNotEmpty ?? false),
        cta: l10n.homeAddProfession,
        name: l10n.homeFieldProfession,
      ),
      (
        done: (profile?.bio?.trim().isNotEmpty ?? false),
        cta: l10n.homeCompleteBio,
        name: l10n.homeFieldBio,
      ),
    ];

    final filled = items.where((e) => e.done).length;
    final missing = items.where((e) => !e.done).toList();

    if (missing.isEmpty) {
      return const _ProfileCompletion(
        filled: 5,
        total: 5,
        ctaLabel: '',
        message: '',
      );
    }

    final names = missing
        .take(2)
        .map((e) => l10n.profileCompletionField(e.name))
        .toList();
    final list = _enumere(names, l10n);
    final cap = list[0].toUpperCase() + list.substring(1);
    final cityPart = (city != null && city.trim().isNotEmpty)
        ? l10n.profileCompletionPlace(city.trim())
        : '';

    return _ProfileCompletion(
      filled: filled,
      total: 5,
      ctaLabel: missing.first.cta,
      message: l10n.profileCompletionMessage(names.length, cap, cityPart),
    );
  }

  /// Élargit le rayon de recherche des membres proches (50 → 200 km) et
  /// recharge, depuis l'état vide « Personne à moins de 50 km ».
  Future<void> _widenRadius() async {
    if (_nearbyRadiusKm >= _nearbyRadiusWideKm) return;
    setState(() {
      _nearbyRadiusKm = _nearbyRadiusWideKm;
      // Squelette immédiat : on ne laisse pas « Personne à moins de 50 km »
      // à l'écran pendant qu'on cherche à 200 km.
      _nearbySearching = true;
    });
    if (_currentLat == null || _currentLng == null) {
      setState(() => _nearbySearching = false);
      return;
    }
    try {
      await ref
          .read(nearbyProfilesNotifierProvider.notifier)
          .loadNearbyProfiles(_currentLat!, _currentLng!,
              radiusKm: _nearbyRadiusKm);
    } finally {
      if (mounted) setState(() => _nearbySearching = false);
    }
  }

  /// Partage un lien d'invitation à rejoindre l'app (« Inviter un proche »).
  Future<void> _inviteFriend() async {
    final l10n = AppLocalizations.of(context)!;
    final uid = ref.read(currentUserProvider).valueOrNull?.id;
    final link = DeepLinkService.instance.generateInviteLink(referrerId: uid);
    await DeepLinkService.instance.shareLink(
      link: link,
      title: 'Rejoignez Diaspo Niger',
      text: l10n.homeShareInvite,
    );
  }

  /// Ouvre les réglages de localisation, puis recharge (« Activer ma position »).
  Future<void> _enableLocation() async {
    await LocationService.instance.openLocationSettings();
    await Future.delayed(const Duration(seconds: 1));
    _loadData();
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
