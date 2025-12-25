import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_intro_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/map/presentation/screens/map_screen.dart';
import '../../features/groups/presentation/screens/groups_screen.dart';
import '../../features/groups/presentation/screens/group_detail_screen.dart';
import '../../features/groups/presentation/screens/create_group_screen.dart';
import '../../features/groups/presentation/screens/edit_group_screen.dart';
import '../../features/groups/domain/entities/group_entity.dart';
import '../../features/messages/presentation/screens/messages_screen.dart';
import '../../features/messages/presentation/screens/conversation_screen.dart';
import '../../features/messages/presentation/screens/new_conversation_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/edit_profile_screen.dart';
import '../../features/profile/presentation/screens/profile_view_screen.dart';
import '../../features/profile/presentation/screens/qr_scanner_screen.dart';
import '../../features/profile/domain/entities/profile_entity.dart';
import '../../features/events/presentation/screens/events_screen.dart';
import '../../features/events/presentation/screens/create_event_screen.dart';
import '../../features/events/presentation/screens/event_detail_screen.dart';
import '../../features/events/presentation/screens/edit_event_screen.dart';
import '../../features/events/domain/entities/event_entity.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import '../../features/search/presentation/providers/search_provider.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/settings/presentation/screens/terms_screen.dart';
import '../../features/settings/presentation/screens/privacy_policy_screen.dart';
import '../../features/friends/presentation/screens/friends_screen.dart';
import '../shell/main_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authNotifierProvider);

  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isAuthenticated = authState.maybeWhen(
        authenticated: (_) => true,
        orElse: () => false,
      );

      final isAuthRoute = state.matchedLocation.startsWith('/auth');
      final isSplashRoute = state.matchedLocation == '/splash';

      if (isSplashRoute) {
        return null;
      }

      if (!isAuthenticated && !isAuthRoute) {
        return '/auth/login';
      }

      if (isAuthenticated && isAuthRoute) {
        // Check if user is new (created within last 2 minutes)
        final user = authState.mapOrNull(authenticated: (s) => s.user);

        if (user?.createdAt != null) {
          final isNewUser =
              DateTime.now().difference(user!.createdAt!).inMinutes < 2;
          if (isNewUser) {
            return '/onboarding/intro';
          }
        }
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/auth/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/auth/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      // Onboarding route
      GoRoute(
        path: '/onboarding/intro',
        builder: (context, state) => const OnboardingIntroScreen(),
      ),
      // Routes outside of shell (no bottom navigation)
      GoRoute(
        path: '/profile/edit',
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/profile/:userId',
        builder: (context, state) {
          final userId = state.pathParameters['userId']!;
          final profile = state.extra as ProfileEntity?;
          return ProfileViewScreen(userId: userId, initialProfile: profile);
        },
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
        builder: (context, state) => const CreateEventScreen(),
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
      // Groups routes
      GoRoute(
        path: '/groups/create',
        builder: (context, state) => const CreateGroupScreen(),
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: '/groups/search',
        builder:
            (context, state) =>
                const SearchScreen(initialFilter: SearchFilter.groups),
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
      // Notifications route
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      // Friends route
      GoRoute(
        path: '/friends',
        builder: (context, state) => const FriendsScreen(),
      ),
      // Settings route
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/settings/terms',
        builder: (context, state) => const TermsScreen(),
      ),
      GoRoute(
        path: '/settings/privacy',
        builder: (context, state) => const PrivacyPolicyScreen(),
      ),
      // Messages routes
      GoRoute(
        path: '/messages/new',
        builder: (context, state) => const NewConversationScreen(),
      ),
      GoRoute(
        path: '/messages/:conversationId',
        builder: (context, state) {
          final conversationId = state.pathParameters['conversationId']!;
          final extra = state.extra as Map<String, dynamic>?;
          return ConversationScreen(
            conversationId: conversationId,
            conversationName: extra?['name'] as String?,
            conversationImageUrl: extra?['imageUrl'] as String?,
            isGroup: extra?['isGroup'] as bool? ?? false,
            otherUserId: extra?['otherUserId'] as String?,
          );
        },
      ),
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
                    (context, state) =>
                        const NoTransitionPage(child: HomeScreen()),
              ),
            ],
          ),
          // Map Branch
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/map',
                pageBuilder:
                    (context, state) =>
                        const NoTransitionPage(child: MapScreen()),
              ),
            ],
          ),
          // Groups Branch
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/groups',
                pageBuilder:
                    (context, state) =>
                        const NoTransitionPage(child: GroupsScreen()),
              ),
            ],
          ),
          // Messages Branch
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/messages',
                pageBuilder:
                    (context, state) =>
                        const NoTransitionPage(child: MessagesScreen()),
              ),
            ],
          ),
          // Profile Branch
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                pageBuilder:
                    (context, state) =>
                        const NoTransitionPage(child: ProfileScreen()),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
