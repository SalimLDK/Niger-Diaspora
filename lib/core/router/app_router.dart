import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'router_codec.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/consent_screen.dart';
import '../../features/auth/presentation/screens/maintenance_screen.dart';
import '../services/feature_flag_service.dart';
import '../../features/onboarding/presentation/screens/onboarding_intro_screen.dart';
import '../../features/onboarding/presentation/providers/onboarding_provider.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/home/presentation/screens/services_screen.dart';
import '../../features/map/presentation/screens/map_screen.dart';
import '../../features/groups/presentation/screens/groups_screen.dart';
import '../../features/groups/presentation/screens/group_detail_screen.dart';
import '../../features/groups/presentation/screens/create_group_screen.dart';
import '../../features/groups/presentation/screens/groups_map_screen.dart';
import '../../features/groups/presentation/screens/edit_group_screen.dart';
import '../../features/groups/domain/entities/group_entity.dart';
import '../../features/groups/presentation/screens/group_members_screen.dart';
import '../../features/groups/presentation/screens/group_requests_screen.dart';
import '../../features/messages/presentation/screens/messages_screen.dart';
import '../../features/messages/presentation/screens/conversation_screen.dart';
import '../../features/messages/presentation/screens/new_conversation_screen.dart';
import '../../features/messages/presentation/screens/media_gallery_screen.dart';
import '../../features/messages/presentation/screens/starred_messages_screen.dart';
import '../../features/messages/presentation/screens/share_to_conversation_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/edit_profile_screen.dart';
import '../../features/profile/presentation/screens/profile_view_screen.dart';
import '../../features/profile/presentation/screens/qr_scanner_screen.dart';
import '../../features/profile/presentation/screens/profile_config_screen.dart';
import '../../features/profile/domain/entities/profile_entity.dart';
import '../../features/feed/presentation/screens/mon_espace_screen.dart';
import '../../features/feed/presentation/screens/followed_hashtags_screen.dart';
import '../../features/feed/presentation/screens/story_viewer_screen.dart';
import '../../features/feed/presentation/screens/my_posts_screen.dart';
import '../../features/feed/presentation/screens/saved_posts_screen.dart';
import '../../features/feed/presentation/screens/follows_screen.dart';
import '../../features/events/presentation/screens/events_screen.dart';
import '../../features/events/presentation/screens/create_event_screen.dart';
import '../../features/events/presentation/screens/event_detail_screen.dart';
import '../../features/events/presentation/screens/edit_event_screen.dart';
import '../../features/events/presentation/screens/event_recap_screen.dart';
import '../../features/events/domain/entities/event_entity.dart';
import '../../features/polls/presentation/screens/poll_results_screen.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/notifications/presentation/screens/notification_settings_screen.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import '../../features/search/presentation/providers/search_provider.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/legal/presentation/screens/legal_documents_screen.dart';
import '../../features/settings/presentation/screens/security_backup_screen.dart';
import '../../features/settings/presentation/screens/devices_screen.dart';
import '../../features/reports/presentation/screens/my_reports_screen.dart';
import '../../features/friends/presentation/screens/friends_screen.dart';
import '../shell/main_shell.dart';
// Business Directory
import '../../features/businesses/presentation/screens/businesses_screen.dart';
import '../../features/businesses/presentation/screens/business_detail_screen.dart';
import '../../features/businesses/presentation/screens/create_business_screen.dart';
import '../../features/businesses/presentation/screens/my_businesses_screen.dart';
import '../../features/businesses/presentation/screens/boost_business_screen.dart';
import '../../features/businesses/presentation/screens/business_reviews_screen.dart';
import '../../features/businesses/domain/entities/business_entity.dart';
// Marketplace
import '../../features/marketplace/presentation/screens/marketplace_screen.dart';
import '../../features/marketplace/presentation/screens/product_detail_screen.dart';
import '../../features/marketplace/presentation/screens/create_product_screen.dart';
import '../../features/marketplace/presentation/screens/cart_screen.dart';
import '../../features/marketplace/presentation/screens/my_products_screen.dart';
import '../../features/marketplace/presentation/screens/my_orders_screen.dart';
import '../../features/marketplace/domain/entities/product_entity.dart';
// Transfers
import '../../features/transfers/presentation/screens/transfer_screen.dart';
import '../../features/transfers/presentation/screens/send_money_screen.dart';
import '../../features/transfers/presentation/screens/recipient_select_screen.dart';
import '../../features/transfers/presentation/screens/add_recipient_screen.dart';
import '../../features/transfers/presentation/screens/transaction_detail_screen.dart';
import '../../features/transfers/presentation/screens/transaction_history_screen.dart';
import '../../features/transfers/presentation/screens/friend_recipient_select_screen.dart';
import '../../features/transfers/domain/entities/recipient_entity.dart';

import '../../features/notifications/presentation/screens/notification_detail_screen.dart';
// Embassies
import '../../features/embassies/presentation/screens/embassies_screen.dart';
import '../../features/embassies/presentation/screens/embassy_detail_screen.dart';
import '../../features/embassies/domain/entities/embassy_entity.dart';
import '../../features/admin/presentation/screens/admin_embassy_verification_screen.dart';
import '../../features/admin/presentation/screens/admin_create_embassy_screen.dart';
import '../../features/embassies/presentation/screens/employee_search_screen.dart';
// Payment Accounts
import '../../features/payment_accounts/presentation/screens/payment_accounts_screen.dart';
import '../../features/payment_accounts/presentation/screens/add_payment_account_screen.dart';
// Payment History
import '../../features/payment_history/presentation/screens/payment_history_screen.dart';
import '../../features/payment_history/presentation/screens/payment_detail_screen.dart';
import '../../features/payment_history/domain/entities/payment_history_item.dart';
// Support Tickets
import '../../features/support/presentation/screens/support_tickets_screen.dart';
import '../../features/support/presentation/screens/create_ticket_screen.dart';
import '../../features/support/presentation/screens/ticket_detail_screen.dart';
import '../../features/support/presentation/screens/admin_support_screen.dart';
import '../../features/support/domain/entities/support_ticket_entity.dart';
import 'routes/audio_rooms_routes.dart';
import 'routes/podcasts_routes.dart';
// Feed social
import '../../features/feed/presentation/screens/feed_screen.dart';
import '../../features/feed/presentation/screens/create_post_screen.dart';
import '../../features/feed/presentation/screens/post_detail_screen.dart';
import '../../features/feed/presentation/screens/reposts_screen.dart';
import '../../features/feed/presentation/screens/reposters_screen.dart';
import '../../features/feed/domain/entities/post_entity.dart';
// Calls
import 'routes/calls_routes.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

// Cache the router and notifier to prevent duplicate GlobalKey issues
GoRouter? _cachedRouter;
_SimpleNotifier? _cachedAuthNotifier;

/// Destination réclamée par un lien profond, mise de côté le temps que
/// l'authentification et l'onboarding se terminent (cf. étapes 0 et 10 du
/// `redirect`). Nulle en dehors de cette fenêtre.
String? _pendingDeepLink;

final routerProvider = Provider<GoRouter>((ref) {
  // Return cached router if it exists to prevent duplicate GlobalKey errors.
  // Re-register all listeners under the new ref so they are properly disposed.
  if (_cachedRouter != null && _cachedAuthNotifier != null) {
    ref.listen(authNotifierProvider, (_, __) => _cachedAuthNotifier!.notify());
    ref.listen(
      onboardingNotifierProvider,
      (_, __) => _cachedAuthNotifier!.notify(),
    );
    ref.listen(
      isMaintenanceModeProvider,
      (_, __) => _cachedAuthNotifier!.notify(),
    );
    ref.listen(
      loadedFeatureFlagsProvider,
      (_, __) => _cachedAuthNotifier!.notify(),
    );
    return _cachedRouter!;
  }

  final authNotifier = _SimpleNotifier();
  _cachedAuthNotifier = authNotifier;

  ref.listen(authNotifierProvider, (_, __) => authNotifier.notify());
  ref.listen(onboardingNotifierProvider, (_, __) => authNotifier.notify());
  ref.listen(isMaintenanceModeProvider, (_, __) => authNotifier.notify());
  // Réévalue le gating dès que les flags distants arrivent.
  ref.listen(loadedFeatureFlagsProvider, (_, __) => authNotifier.notify());

  _cachedRouter = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    debugLogDiagnostics: kDebugMode,
    refreshListenable: authNotifier,
    extraCodec: const AppRouterCodec(),
    observers: [
      FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
    ],
    redirect: (context, state) {
      // Use read() here to avoid rebuilding the provider
      final authState = ref.read(authNotifierProvider);
      final onboardingState = ref.read(onboardingNotifierProvider);
      final isMaintenanceMode = ref.read(isMaintenanceModeProvider);

      final isAuthLoading = authState.maybeWhen(
        initial: () => true,
        loading: () => true,
        orElse: () => false,
      );

      final isAuthenticated = authState.maybeWhen(
        authenticated: (_) => true,
        orElse: () => false,
      );

      // Vérifier si l'utilisateur est admin (exempt de la maintenance)
      final isAdmin = authState.maybeWhen(
        authenticated: (user) => user.isAdmin,
        orElse: () => false,
      );

      // La galerie de la refonte échappe au garde : elle ne montre que des
      // copies d'écrans, sans donnée réelle, et devoir se connecter pour
      // vérifier un rendu n'a pas de sens. En debug uniquement — la route
      // n'existe pas autrement.
      if (kDebugMode && state.matchedLocation == '/design-v2') return null;

      final isSplashRoute = state.matchedLocation == '/splash';
      final isAuthRoute = state.matchedLocation.startsWith('/auth');
      final isConsentRoute = state.matchedLocation == '/consent';
      final isProfileConfigRoute = state.matchedLocation == '/profile-config';
      final isOnboardingRoute = state.matchedLocation == '/onboarding/intro';
      final isMaintenanceRoute = state.matchedLocation == '/maintenance';
      final isLegalRoute =
          state.matchedLocation == '/settings/terms' ||
          state.matchedLocation == '/settings/privacy' ||
          state.matchedLocation == '/settings/code-of-conduct';

      // 0. Mise de côté de la destination d'un lien profond.
      //
      // Un lien ouvre l'app directement sur son contenu, mais au démarrage à
      // froid l'authentification n'est pas encore résolue : l'étape 1 renvoie
      // sur /splash, l'étape 2 sur /auth/login, et l'étape 10 terminerait sur
      // /home. La destination était perdue à tous les coups — c'est ce qui
      // faisait qu'un lien partagé n'ouvrait jamais son post. On la garde ici
      // pour la rejouer à l'étape 10, une fois l'utilisateur prêt.
      // `isLegalRoute` en fait partie : conditions et confidentialité sont
      // consultables sans compte (étape 2), les retenir enverrait l'utilisateur
      // sur les CGU juste après sa connexion.
      final isTechnicalRoute =
          isSplashRoute ||
          isAuthRoute ||
          isConsentRoute ||
          isProfileConfigRoute ||
          isOnboardingRoute ||
          isMaintenanceRoute ||
          isLegalRoute;
      if (!isTechnicalRoute && (isAuthLoading || !isAuthenticated)) {
        // `uri` et non `matchedLocation` : les paramètres de requête font
        // partie de la destination (ex. /feed?hashtag=niamey).
        _pendingDeepLink = state.uri.toString();
      }

      // 1. If auth is loading, stay on splash
      if (isAuthLoading) {
        return '/splash';
      }

      // 2. If not authenticated, redirect to login (except for legal routes)
      if (!isAuthenticated) {
        return (isAuthRoute || isLegalRoute) ? null : '/auth/login';
      }

      // 3. If authenticated, check onboarding loading status
      if (onboardingState.isLoading) {
        return '/splash';
      }

      // 4. Check maintenance mode (admins are exempt)
      if (isMaintenanceMode && !isAdmin) {
        return isMaintenanceRoute ? null : '/maintenance';
      }

      // 5. If maintenance mode is off but user is on maintenance page, redirect to home
      if (!isMaintenanceMode && isMaintenanceRoute) {
        return '/home';
      }

      // 6. Check if user has given consent (except for terms/privacy pages)
      if (!onboardingState.hasGivenConsent && !isLegalRoute) {
        return isConsentRoute ? null : '/consent';
      }

      // 7. Check if user has completed profile configuration (except for terms/privacy pages)
      if (!onboardingState.profileConfigComplete && !isLegalRoute) {
        return isProfileConfigRoute ? null : '/profile-config';
      }

      // 8. Check if user needs to see onboarding (except for terms/privacy pages)
      if (!onboardingState.hasSeenIntro && !isLegalRoute) {
        return isOnboardingRoute ? null : '/onboarding/intro';
      }

      // 9. PHASE 2 FEATURE FLAGS — protège transferts, marketplace, entreprises,
      // podcasts et salons audio.
      //
      // `loadedFeatureFlagsProvider` vaut null tant que app_config/settings
      // n'est pas revenu : on laisse alors passer. Bloquer pendant le
      // chargement reviendrait à appliquer les valeurs par défaut de
      // FeatureFlagsEntity (podcasts et salons audio à false) et à renvoyer
      // ces écrans sur /home à chaque démarrage à froid.
      final flags = ref.read(loadedFeatureFlagsProvider);
      if (flags != null) {
        final phase2Paths = <String, AppFeature>{
          '/transfers': AppFeature.moneyTransfer,
          '/marketplace': AppFeature.marketplace,
          '/businesses': AppFeature.businessDirectory,
          '/podcasts': AppFeature.podcasts,
          '/payment-accounts': AppFeature.moneyTransfer,
          '/payment-history': AppFeature.moneyTransfer,
          '/audio-rooms': AppFeature.audioRooms,
        };
        for (final entry in phase2Paths.entries) {
          if (state.matchedLocation.startsWith(entry.key) &&
              !FeatureFlagService.isFeatureEnabled(flags, entry.value)) {
            return '/home';
          }
        }
      }

      // 9b. Vue « modérateur fantôme » — réservée aux admins.
      // Sans cette garde, n'importe quel utilisateur connecté pouvait ouvrir
      // /audio-rooms/<id>/ghost et voir les outils de modération.
      if (state.matchedLocation.startsWith('/audio-rooms/') &&
          state.matchedLocation.endsWith('/ghost') &&
          !isAdmin) {
        return state.matchedLocation.substring(
          0,
          state.matchedLocation.length - '/ghost'.length,
        );
      }

      // 10. User is authenticated and has completed all setup steps
      // Redirect to home if on splash, auth, consent, profile-config, or onboarding pages
      if (isSplashRoute ||
          isAuthRoute ||
          isConsentRoute ||
          isProfileConfigRoute ||
          isOnboardingRoute) {
        // Le lien profond mis de côté à l'étape 0 reprend la main ici. Consommé
        // une seule fois : sans ça, chaque retour sur l'accueil y renverrait.
        final pending = _pendingDeepLink;
        _pendingDeepLink = null;
        return pending ?? '/home';
      }

      return null;
    },
    routes: [
      // Root route redirect to home
      GoRoute(path: '/', redirect: (context, state) => '/home'),
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/maintenance',
        builder: (context, state) => const MaintenanceScreen(),
      ),
      GoRoute(
        path: '/auth/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/auth/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/auth/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      // Consent screen
      GoRoute(
        path: '/consent',
        builder: (context, state) => const ConsentScreen(),
      ),
      // Profile configuration
      GoRoute(
        path: '/profile-config',
        builder: (context, state) => const ProfileConfigScreen(),
      ),
      // Onboarding route
      GoRoute(
        path: '/onboarding/intro',
        builder: (context, state) => const OnboardingIntroScreen(),
      ),
      // Routes outside of shell (no bottom navigation)
      GoRoute(
        path: '/profile/edit',
        // ?focus=photo|city|job|languages|bio — le bandeau de complétude
        // (§11f) ouvre le formulaire sur le champ qu'il propose d'ajouter.
        builder:
            (context, state) => EditProfileScreen(
              focusField: state.uri.queryParameters['focus'],
            ),
      ),
      // ⚠️ Les sous-routes statiques /profile/* DOIVENT être déclarées AVANT
      // '/profile/:userId' : sinon GoRouter capture "my-posts" / "saved-posts" /
      // "reposts" comme un userId → ProfileViewScreen charge un profil inexistant
      // → écran « Profil supprimé ». (Ordre = priorité de matching dans GoRouter.)
      GoRoute(
        path: '/profile/my-posts',
        // ?tab=1 ouvre directement l'onglet Repartages (§5a → §5b).
        builder:
            (context, state) => MyPostsScreen(
              initialTab: state.uri.queryParameters['tab'] == '1' ? 1 : 0,
            ),
      ),
      GoRoute(
        path: '/profile/saved-posts',
        builder: (context, state) => const SavedPostsScreen(),
      ),
      GoRoute(
        path: '/profile/reposts',
        builder: (context, state) => const RepostsScreen(),
      ),
      GoRoute(
        path: '/profile/follows',
        builder: (context, state) {
          final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '') ?? 0;
          return FollowsScreen(initialTab: tab);
        },
      ),
      GoRoute(
        path: '/profile/:userId',
        // No redirect to '/profile' shell branch: push() + redirect to a shell
        // route creates two ShellPage entries with the same key in the root
        // navigator, triggering _debugCheckDuplicatedPageKeys. ProfileViewScreen
        // handles own-profile display via userId == currentUser.uid check.
        builder: (context, state) {
          final userId = state.pathParameters['userId']!;
          final profile = state.extra as ProfileEntity?;
          return ProfileViewScreen(userId: userId, initialProfile: profile);
        },
      ),
      // Deep link support for profile shares
      GoRoute(
        path: '/p/u/:userId',
        redirect:
            (context, state) => '/profile/${state.pathParameters['userId']!}',
      ),
      GoRoute(
        path: '/qr-scanner',
        builder: (context, state) => const QrScannerScreen(),
      ),
      GoRoute(
        path: '/events',
        builder: (context, state) => const EventsScreen(),
      ),
      // Events routes
      GoRoute(
        path: '/events/create',
        builder:
            (context, state) => CreateEventScreen(
              initialCategory:
                  state.extra is EventCategory
                      ? state.extra as EventCategory
                      : null,
            ),
      ),
      GoRoute(
        path: '/events/:eventId',
        builder: (context, state) {
          final eventId = state.pathParameters['eventId']!;
          final event = state.extra as EventEntity?;
          return EventDetailScreen(eventId: eventId, initialEvent: event);
        },
      ),
      GoRoute(
        path: '/events/:eventId/edit',
        builder: (context, state) {
          final event = state.extra as EventEntity;
          return EditEventScreen(event: event);
        },
      ),
      GoRoute(
        path: '/events/:eventId/recap',
        builder: (context, state) {
          final event = state.extra as EventEntity;
          return EventRecapScreen(event: event);
        },
      ),
      // Groups routes
      GoRoute(
        path: '/groups/create',
        builder:
            (context, state) => CreateGroupScreen(
              initialName: state.uri.queryParameters['name'],
            ),
      ),
      GoRoute(
        path: '/groups/map',
        builder: (context, state) => const GroupsMapScreen(),
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: '/groups/search',
        builder:
            (context, state) => const SearchScreen(
              initialFilter: SearchFilter.groups,
              restrictToFilter: true,
            ),
      ),
      GoRoute(
        path: '/groups/:groupId',
        builder: (context, state) {
          final groupId = state.pathParameters['groupId']!;
          final group = state.extra as GroupEntity?;
          return GroupDetailScreen(groupId: groupId, initialGroup: group);
        },
      ),
      GoRoute(
        path: '/groups/:groupId/edit',
        builder: (context, state) {
          final group = state.extra as GroupEntity;
          return EditGroupScreen(group: group);
        },
      ),
      GoRoute(
        path: '/groups/:groupId/members',
        builder: (context, state) {
          final groupId = state.pathParameters['groupId']!;
          final group = state.extra as GroupEntity?;
          return GroupMembersScreen(groupId: groupId, group: group);
        },
      ),
      GoRoute(
        path: '/groups/:groupId/events/create',
        builder: (context, state) {
          final groupId = state.pathParameters['groupId']!;
          final group = state.extra as GroupEntity?;
          return CreateEventScreen(groupId: groupId, groupName: group?.name);
        },
      ),
      GoRoute(
        path: '/conversations/:conversationId/events/create',
        builder: (context, state) {
          final conversationId = state.pathParameters['conversationId']!;
          return CreateEventScreen(conversationId: conversationId);
        },
      ),
      GoRoute(
        path: '/polls/:pollId/results',
        builder: (context, state) {
          final pollId = state.pathParameters['pollId']!;
          return PollResultsScreen(pollId: pollId);
        },
      ),
      GoRoute(
        path: '/groups/:groupId/requests',
        builder: (context, state) {
          final groupId = state.pathParameters['groupId']!;
          return GroupRequestsScreen(groupId: groupId);
        },
      ),
      // Notifications routes
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/notifications/settings',
        builder: (context, state) => const NotificationSettingsScreen(),
      ),
      // Segments inverses. Vu sur appareil le 2026-08-06 : une navigation vers
      // `/settings/notifications` tombe sur « Page Not Found »
      // (`GoException: no routes for location`). Rien dans le depot ne pousse
      // ce chemin — il arrive de l'exterieur, en lien profond
      // (`https://diasponiger.web.app/settings/notifications`), donc
      // vraisemblablement d'une charge utile push deja deployee.
      //
      // On ne peut pas corriger l'emetteur d'ici, mais on peut supprimer le
      // cul-de-sac : les six autres routes de reglages sont en
      // `/settings/<quelque chose>`, donc la forme inversee est celle qu'on
      // ecrit naturellement de memoire. Elle menera desormais au bon ecran.
      GoRoute(
        path: '/settings/notifications',
        redirect: (context, state) => '/notifications/settings',
      ),
      GoRoute(
        path: '/notifications/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return NotificationDetailScreen(notificationId: id);
        },
      ),
      // Friends route
      GoRoute(
        path: '/friends',
        builder: (context, state) => const FriendsScreen(),
      ),
      // Écran de réglages dédié (§10b) : les 3 entrées condensées de
      // ProfileScreen y renvoient.
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      // Documents légaux (§26c) : 3 routes distinctes pour les liens
      // profonds existants (consentement, inscription...), mais un seul
      // écran à onglets partagé — voir LegalDocumentsScreen.
      GoRoute(
        path: '/settings/terms',
        builder:
            (context, state) =>
                const LegalDocumentsScreen(initialTab: LegalTab.terms),
      ),
      GoRoute(
        path: '/settings/privacy',
        builder:
            (context, state) =>
                const LegalDocumentsScreen(initialTab: LegalTab.privacy),
      ),
      GoRoute(
        path: '/settings/code-of-conduct',
        builder:
            (context, state) =>
                const LegalDocumentsScreen(initialTab: LegalTab.conduct),
      ),
      GoRoute(
        path: '/settings/my-reports',
        builder: (context, state) => const MyReportsScreen(),
      ),
      // E2EE Security routes
      GoRoute(
        path: '/settings/security/backup',
        builder: (context, state) => const SecurityBackupScreen(),
      ),
      GoRoute(
        path: '/settings/security/devices',
        builder: (context, state) => const DevicesScreen(),
      ),
      // Embassies routes
      GoRoute(
        path: '/embassies',
        builder: (context, state) => const EmbassiesScreen(),
      ),
      GoRoute(
        path: '/admin/embassies',
        builder: (context, state) => const AdminEmbassyVerificationScreen(),
      ),
      GoRoute(
        path: '/admin/embassies/create',
        builder: (context, state) => const AdminCreateEmbassyScreen(),
      ),
      GoRoute(
        path: '/embassies/employees',
        builder: (context, state) {
          final embassy = state.extra as EmbassyEntity?;
          return EmployeeSearchScreen(embassy: embassy);
        },
      ),
      GoRoute(
        path: '/embassies/:id',
        builder: (context, state) {
          // final id = state.pathParameters['id']!; // Id unused currently, relying on object passed via extra
          final embassy = state.extra as EmbassyEntity?;
          if (embassy != null) {
            return EmbassyDetailScreen(
              embassy: embassy,
            ); // Optimization: Pass object if available
          }
          // Fallback: Fetch by ID if deep linked (Not implemented yet in screen, assumes extra passed for now)
          // Ideally screen handles ID, but for now we expect extra navigation.
          // To be safe, we might need a wrapper or refetch.
          // For now let's assume navigation always provides extra or we handle null in screen if we modified it.
          // But EmbassyDetailScreen requires 'embassy'.
          // Let's rely on internal navigation for now.
          return EmbassyDetailScreen(embassy: embassy!);
        },
      ),
      // Business Directory routes
      GoRoute(
        path: '/businesses',
        builder: (context, state) => const BusinessesScreen(),
      ),
      GoRoute(
        path: '/businesses/create',
        builder: (context, state) => const CreateBusinessScreen(),
      ),
      // Déclarée AVANT '/businesses/:businessId' (sinon 'mine' serait pris
      // pour un identifiant).
      GoRoute(
        path: '/businesses/mine',
        builder: (context, state) => const MyBusinessesScreen(),
      ),
      GoRoute(
        path: '/businesses/:businessId',
        builder: (context, state) {
          final businessId = state.pathParameters['businessId']!;
          final business = state.extra as BusinessEntity?;
          return BusinessDetailScreen(
            businessId: businessId,
            initialBusiness: business,
          );
        },
      ),
      GoRoute(
        path: '/businesses/:businessId/boost',
        builder: (context, state) {
          final businessId = state.pathParameters['businessId']!;
          final business = state.extra as BusinessEntity?;
          return BoostBusinessScreen(
            businessId: businessId,
            business: business,
          );
        },
      ),
      GoRoute(
        path: '/businesses/:businessId/reviews',
        builder: (context, state) {
          final businessId = state.pathParameters['businessId']!;
          final business = state.extra as BusinessEntity?;
          return BusinessReviewsScreen(
            businessId: businessId,
            business: business,
          );
        },
      ),
      // Marketplace routes
      GoRoute(
        path: '/marketplace',
        builder: (context, state) => const MarketplaceScreen(),
      ),
      GoRoute(
        path: '/marketplace/create',
        builder: (context, state) {
          final product = state.extra as ProductEntity?;
          // ?category=… pré-sélectionne la catégorie depuis les puces de
          // l'état vide « rien mis en vente ». Distinct de `extra`, qui sert
          // à l'édition d'un produit existant.
          final categoryName = state.uri.queryParameters['category'];
          return CreateProductScreen(
            product: product,
            initialCategory:
                categoryName == null
                    ? null
                    : ProductCategory.values
                        .where((c) => c.name == categoryName)
                        .firstOrNull,
          );
        },
      ),
      GoRoute(
        path: '/marketplace/cart',
        builder: (context, state) => const CartScreen(),
      ),
      GoRoute(
        path: '/marketplace/my-listings',
        builder: (context, state) => const MyProductsScreen(),
      ),
      GoRoute(
        path: '/marketplace/my-orders',
        builder: (context, state) => const MyOrdersScreen(),
      ),
      GoRoute(
        path: '/marketplace/:productId',
        builder: (context, state) {
          final productId = state.pathParameters['productId']!;
          return ProductDetailScreen(productId: productId);
        },
      ),
      GoRoute(
        path: '/services',
        builder: (context, state) => const ServicesScreen(),
      ),
      GoRoute(
        path: '/marketplace/:productId/edit',
        builder: (context, state) {
          final product = state.extra as ProductEntity?;
          return CreateProductScreen(product: product);
        },
      ),
      // Transfers routes (conditional based on feature flag)
      GoRoute(
        path: '/transfers',
        builder: (context, state) => const TransferScreen(),
      ),
      GoRoute(
        path: '/transfers/send',
        builder: (context, state) => const SendMoneyScreen(),
      ),
      GoRoute(
        path: '/transfers/history',
        builder: (context, state) => const TransactionHistoryScreen(),
      ),
      GoRoute(
        path: '/transfers/recipient',
        builder: (context, state) => const RecipientSelectScreen(),
      ),
      GoRoute(
        path: '/transfers/recipient/add',
        builder: (context, state) {
          final recipient = state.extra as RecipientEntity?;
          return AddRecipientScreen(existingRecipient: recipient);
        },
      ),
      GoRoute(
        path: '/transfers/:transactionId',
        builder: (context, state) {
          final transactionId = state.pathParameters['transactionId']!;
          return TransactionDetailScreen(transactionId: transactionId);
        },
      ),
      // Plural alias routes for backward compatibility
      GoRoute(
        path: '/transfers/recipients',
        builder: (context, state) => const RecipientSelectScreen(),
      ),
      GoRoute(
        path: '/transfers/recipients/add',
        builder: (context, state) => const FriendRecipientSelectScreen(),
      ),
      // Payment Accounts routes
      GoRoute(
        path: '/payment-accounts',
        builder: (context, state) => const PaymentAccountsScreen(),
      ),
      GoRoute(
        path: '/payment-accounts/add',
        builder: (context, state) => const AddPaymentAccountScreen(),
      ),
      // Payment History routes
      GoRoute(
        path: '/payment-history',
        builder: (context, state) => const PaymentHistoryScreen(),
      ),
      GoRoute(
        path: '/payment-history/:transactionId',
        builder: (context, state) {
          final item = state.extra as PaymentHistoryItem?;
          if (item != null) {
            return PaymentDetailScreen(item: item);
          }
          // Fallback - go back to history list
          return const PaymentHistoryScreen();
        },
      ),
      // Support Tickets routes
      GoRoute(
        path: '/support',
        builder: (context, state) => const SupportTicketsScreen(),
      ),
      GoRoute(
        path: '/support/new',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return CreateTicketScreen(
            prefillSubject: extra?['subject'] as String?,
            prefillDescription: extra?['description'] as String?,
            relatedTransactionId: extra?['transactionId'] as String?,
            initialCategory: extra?['category'] as TicketCategory?,
          );
        },
      ),
      GoRoute(
        path: '/support/:ticketId',
        builder: (context, state) {
          final ticket = state.extra as SupportTicketEntity?;
          if (ticket != null) {
            return TicketDetailScreen(ticket: ticket);
          }
          return const SupportTicketsScreen();
        },
      ),
      GoRoute(
        path: '/admin/support',
        builder: (context, state) => const AdminSupportScreen(),
      ),
      // Messages routes
      GoRoute(
        path: '/share',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is List<SharedMediaFile> && extra.isNotEmpty) {
            return ShareToConversationScreen(mediaFiles: extra);
          }

          // Le contenu initial est consommé par `MainShell`, qui présente la
          // feuille lui-même. Le repli construisait ici un `SharedMediaService`
          // jetable : il ne rendait jamais rien (le canal natif répond de façon
          // asynchrone) et laissait derrière lui un abonnement au flux de
          // partage jamais annulé.
          return const MessagesScreen();
        },
      ),
      GoRoute(
        path: '/messages/new',
        builder: (context, state) => const NewConversationScreen(),
      ),
      GoRoute(
        path: '/messages/:conversationId',
        builder: (context, state) {
          final conversationId = state.pathParameters['conversationId']!;
          // `state.extra` n'est posé que par la tuile de la liste des
          // messages : il est NUL par lien profond et par notification. Tout
          // ce qui en vient est donc un simple raccourci d'affichage, jamais
          // une source de vérité — ConversationScreen réconcilie isGroup et
          // groupId avec la conversation chargée (_syncGroupIdentity).
          final extra = state.extra as Map<String, dynamic>?;
          return ConversationScreen(
            conversationId: conversationId,
            conversationName: extra?['name'] as String?,
            conversationImageUrl: extra?['imageUrl'] as String?,
            isGroup: extra?['isGroup'] as bool? ?? false,
            otherUserId: extra?['otherUserId'] as String?,
            groupId: extra?['groupId'] as String?, // Pass groupId
            // « Mes notes » (self-chat) : posé par la tuile épinglée de
            // MessagesScreen. Désactive les appels et bascule le menu « + »
            // sur le brouillon de sondage.
            isSelfNotes: extra?['isSelfNotes'] as bool? ?? false,
          );
        },
      ),
      GoRoute(
        path: '/messages/:conversationId/media',
        builder: (context, state) {
          final conversationId = state.pathParameters['conversationId']!;
          final extra = state.extra as Map<String, dynamic>?;
          return MediaGalleryScreen(
            conversationId: conversationId,
            title: extra?['title'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/messages/:conversationId/starred',
        builder: (context, state) {
          final conversationId = state.pathParameters['conversationId']!;
          return StarredMessagesScreen(conversationId: conversationId);
        },
      ),
      // Audio Rooms routes
      ...AudioRoomsRoutes.routes,
      // Feed routes
      GoRoute(
        path: '/feed',
        builder:
            (context, state) =>
                FeedScreen(hashtagFilter: state.uri.queryParameters['hashtag']),
      ),
      GoRoute(
        path: '/feed/create',
        // ?draft=<id> reprend un brouillon local existant (§5a/§5b) ;
        // ?compose=photo|poll ouvre directement le sélecteur correspondant
        // (amorces de l'état vide §5g). Sans paramètre : rédaction vierge.
        builder: (context, state) {
          final compose = switch (state.uri.queryParameters['compose']) {
            'photo' => ComposeIntent.photo,
            'poll' => ComposeIntent.poll,
            _ => ComposeIntent.blank,
          };
          return CreatePostScreen(
            draftId: state.uri.queryParameters['draft'],
            compose: compose,
          );
        },
      ),
      // Hub « Mon espace » — doit précéder '/feed/:postId' (sinon « space »
      // serait interprété comme un postId).
      GoRoute(
        path: '/feed/space',
        builder: (context, state) => const MonEspaceScreen(),
      ),
      GoRoute(
        path: '/feed/space/hashtags',
        builder: (context, state) => const FollowedHashtagsScreen(),
      ),
      // Viewer de stories — doit précéder '/feed/:postId' (même piège que
      // '/feed/space' : "stories" serait sinon interprété comme un postId).
      GoRoute(
        path: '/feed/stories/:authorId',
        builder: (context, state) {
          final authorId = state.pathParameters['authorId']!;
          return StoryViewerScreen(authorId: authorId);
        },
      ),
      GoRoute(
        path: '/feed/:postId/edit',
        builder: (context, state) {
          final post = state.extra as PostEntity?;
          return CreatePostScreen(editingPost: post);
        },
      ),
      GoRoute(
        path: '/feed/:postId/reposts',
        builder: (context, state) {
          final postId = state.pathParameters['postId']!;
          return RepostersScreen(postId: postId);
        },
      ),
      GoRoute(
        path: '/feed/:postId',
        builder: (context, state) {
          final postId = state.pathParameters['postId']!;
          return PostDetailScreen(postId: postId);
        },
      ),
      // Podcasts routes
      ...PodcastsRoutes.routes,
      // Calls routes
      ...CallsRoutes.routes,
      // Shell routes (with bottom navigation and persistent state)
      StatefulShellRoute.indexedStack(
        builder:
            (context, state, navigationShell) =>
                MainShell(navigationShell: navigationShell),
        branches: [
          // Home Branch
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                pageBuilder:
                    (context, state) => NoTransitionPage(
                      key: state.pageKey,
                      child: const HomeScreen(),
                    ),
              ),
            ],
          ),
          // Map Branch
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/map',
                pageBuilder:
                    (context, state) => NoTransitionPage(
                      key: state.pageKey,
                      child: const MapScreen(),
                    ),
              ),
            ],
          ),
          // Groups Branch
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/groups',
                pageBuilder:
                    (context, state) => NoTransitionPage(
                      key: state.pageKey,
                      child: const GroupsScreen(),
                    ),
              ),
            ],
          ),
          // Messages Branch
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/messages',
                pageBuilder:
                    (context, state) => NoTransitionPage(
                      key: state.pageKey,
                      child: const MessagesScreen(),
                    ),
              ),
            ],
          ),
          // Profile Branch
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                pageBuilder:
                    (context, state) => NoTransitionPage(
                      key: state.pageKey,
                      child: const ProfileScreen(),
                    ),
              ),
            ],
          ),
        ],
      ),
    ],
  );

  _bindNativeDeepLinks(_cachedRouter!);

  return _cachedRouter!;
});

/// Canal par lequel `MainActivity.onNewIntent` remet une route reçue alors que
/// l'app tournait déjà.
const MethodChannel _deepLinkChannel = MethodChannel('diaspo_niger/deep_link');

bool _deepLinkChannelBound = false;

/// Branche la réception des liens profonds arrivant **à chaud**.
///
/// Le chemin normal de Flutter (`pushRouteInformation` sur le canal de
/// navigation de l'embedding) ne fonctionne pas ici : vérifié sur appareil le
/// 2026-08-04, `onNewIntent` est bien appelé mais GoRouter ne journalise
/// aucune navigation — le moteur mis en cache qu'impose `audio_service` casse
/// ce relais. Le natif nous passe donc la route par un canal explicite, et on
/// navigue nous-mêmes.
///
/// Le démarrage à froid n'emprunte PAS ce chemin : l'URI y arrive comme route
/// initiale, déjà géré par le `redirect` (mise de côté étapes 0 et 10).
void _bindNativeDeepLinks(GoRouter router) {
  if (_deepLinkChannelBound) return;
  _deepLinkChannelBound = true;

  _deepLinkChannel.setMethodCallHandler((call) async {
    if (call.method != 'onDeepLink') return null;
    final route = call.arguments as String?;
    if (route == null || route.isEmpty) return null;

    debugPrint('DeepLink: route reçue à chaud → $route');
    // `go` et non `push` : on remplace la destination courante, comme le ferait
    // l'ouverture du lien depuis zéro. Si l'utilisateur n'est pas encore
    // authentifié, le `redirect` la met de côté et la rejouera (étape 10).
    router.go(route);
    return null;
  });
}

class _SimpleNotifier extends ChangeNotifier {
  bool _pending = false;

  // Debounce: coalesce rapid back-to-back calls (e.g. auth + onboarding both
  // firing in the same Riverpod tick) into a single GoRouter refresh per frame.
  // Without this, two simultaneous notifyListeners() calls can produce two
  // conflicting page-list updates in the same frame, causing the Navigator
  // duplicate-page-key assertion.
  void notify() {
    if (_pending) return;
    _pending = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _pending = false;
      if (hasListeners) notifyListeners();
    });
  }
}
