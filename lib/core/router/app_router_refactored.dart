import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'router_codec.dart';
import 'routes/auth_routes.dart';
import 'routes/profile_routes.dart';
import 'routes/events_routes.dart';
import 'routes/groups_routes.dart';
import 'routes/messages_routes.dart';
import 'routes/marketplace_routes.dart';
import 'routes/transfers_routes.dart';
import 'routes/business_routes.dart';
import 'routes/settings_routes.dart';
import 'routes/embassy_routes.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/home/presentation/screens/services_screen.dart';
import '../../features/map/presentation/screens/map_screen.dart';
import '../../features/groups/presentation/screens/groups_screen.dart';
import '../../features/messages/presentation/screens/messages_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/onboarding/presentation/providers/onboarding_provider.dart';
import '../services/feature_flag_service.dart';
import '../shell/main_shell.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

// Cache the router and notifier to prevent duplicate GlobalKey issues
GoRouter? _cachedRouter;
_SimpleNotifier? _cachedAuthNotifier;

/// Provider principal du router
final routerProvider = Provider<GoRouter>((ref) {
  if (_cachedRouter != null && _cachedAuthNotifier != null) {
    ref.listen(authNotifierProvider, (_, __) {
      _cachedAuthNotifier!.notify();
    });
    ref.listen(onboardingNotifierProvider, (_, __) {
      _cachedAuthNotifier!.notify();
    });
    return _cachedRouter!;
  }

  final authNotifier = _SimpleNotifier();
  _cachedAuthNotifier = authNotifier;

  ref.listen(authNotifierProvider, (_, __) {
    authNotifier.notify();
  });

  ref.listen(onboardingNotifierProvider, (_, __) {
    authNotifier.notify();
  });

  ref.listen(isMaintenanceModeProvider, (_, __) {
    authNotifier.notify();
  });

  _cachedRouter = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    debugLogDiagnostics: true,
    refreshListenable: authNotifier,
    extraCodec: const AppRouterCodec(),
    observers: [
      FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
    ],
    redirect: (context, state) => _handleRedirect(ref, state),
    routes: _buildRoutes(),
  );

  return _cachedRouter!;
});

/// Gère la logique de redirection
String? _handleRedirect(Ref<GoRouter> ref, GoRouterState state) {
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

  final isAdmin = authState.maybeWhen(
    authenticated: (user) => user.isAdmin,
    orElse: () => false,
  );

  final location = state.matchedLocation;
  final isSplashRoute = location == '/splash';
  final isAuthRoute = location.startsWith('/auth');
  final isConsentRoute = location == '/consent';
  final isProfileConfigRoute = location == '/profile-config';
  final isOnboardingRoute = location == '/onboarding/intro';
  final isMaintenanceRoute = location == '/maintenance';
  final isLegalRoute = location == '/settings/terms' ||
      location == '/settings/privacy' ||
      location == '/settings/code-of-conduct';

  // 1. Auth loading -> splash
  if (isAuthLoading) return '/splash';

  // 2. Not authenticated -> login
  if (!isAuthenticated) {
    return isAuthRoute ? null : '/auth/login';
  }

  // 3. Onboarding loading -> splash
  if (onboardingState.isLoading) return '/splash';

  // 4. Maintenance mode (admins exempt)
  if (isMaintenanceMode && !isAdmin) {
    return isMaintenanceRoute ? null : '/maintenance';
  }

  // 5. Maintenance off but on maintenance page -> home
  if (!isMaintenanceMode && isMaintenanceRoute) return '/home';

  // 6. Check consent
  if (!onboardingState.hasGivenConsent && !isLegalRoute) {
    return isConsentRoute ? null : '/consent';
  }

  // 7. Check profile config
  if (!onboardingState.profileConfigComplete && !isLegalRoute) {
    return isProfileConfigRoute ? null : '/profile-config';
  }

  // 8. Check onboarding intro
  if (!onboardingState.hasSeenIntro && !isLegalRoute) {
    return isOnboardingRoute ? null : '/onboarding/intro';
  }

  // 9. All setup complete -> redirect setup pages to home
  if (isSplashRoute || isAuthRoute || isConsentRoute ||
      isProfileConfigRoute || isOnboardingRoute) {
    return '/home';
  }

  return null;
}

/// Construit toutes les routes de l'application
List<RouteBase> _buildRoutes() {
  return [
    // Root redirect
    GoRoute(path: '/', redirect: (context, state) => '/home'),

    // Routes modulaires
    ...AuthRoutes.routes,
    ...ProfileRoutes.routes,
    ...EventsRoutes.routes,
    ...GroupsRoutes.routes,
    ...MessagesRoutes.routes,
    ...MarketplaceRoutes.routes,
    ...TransfersRoutes.routes,
    ...BusinessRoutes.routes,
    ...SettingsRoutes.routes,
    ...EmbassyRoutes.routes,

    // Services
    GoRoute(
      path: '/services',
      builder: (context, state) => const ServicesScreen(),
    ),

    // Shell routes (avec navigation bottom)
    _buildShellRoute(),
  ];
}

/// Construit les routes avec shell (bottom navigation)
StatefulShellRoute _buildShellRoute() {
  return StatefulShellRoute.indexedStack(
    builder: (context, state, navigationShell) =>
        MainShell(navigationShell: navigationShell),
    branches: [
      // Home
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: '/home',
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const HomeScreen(),
            ),
          ),
        ],
      ),
      // Map
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: '/map',
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const MapScreen(),
            ),
          ),
        ],
      ),
      // Groups
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: '/groups',
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const GroupsScreen(),
            ),
          ),
        ],
      ),
      // Messages
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: '/messages',
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const MessagesScreen(),
            ),
          ),
        ],
      ),
      // Profile
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: '/profile',
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const ProfileScreen(),
            ),
          ),
        ],
      ),
    ],
  );
}

class _SimpleNotifier extends ChangeNotifier {
  void notify() {
    notifyListeners();
  }
}
