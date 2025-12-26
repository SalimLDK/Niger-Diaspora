import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
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
import '../../features/groups/presentation/screens/group_members_screen.dart';
import '../../features/messages/presentation/screens/messages_screen.dart';
import '../../features/messages/presentation/screens/conversation_screen.dart';
import '../../features/messages/presentation/screens/new_conversation_screen.dart';
import '../../features/messages/presentation/screens/media_gallery_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/edit_profile_screen.dart';
import '../../features/profile/presentation/screens/profile_view_screen.dart';
import '../../features/profile/presentation/screens/qr_scanner_screen.dart';
import '../../features/profile/domain/entities/profile_entity.dart';
import '../../features/events/presentation/screens/events_screen.dart';
import '../../features/events/presentation/screens/create_event_screen.dart';
import '../../features/events/presentation/screens/event_detail_screen.dart';
import '../../features/events/presentation/screens/edit_event_screen.dart';
import '../../features/events/presentation/screens/event_recap_screen.dart';
import '../../features/events/domain/entities/event_entity.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/notifications/presentation/screens/notification_settings_screen.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import '../../features/search/presentation/providers/search_provider.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/settings/presentation/screens/terms_screen.dart';
import '../../features/settings/presentation/screens/privacy_policy_screen.dart';
import '../../features/friends/presentation/screens/friends_screen.dart';
import '../shell/main_shell.dart';
// Business Directory
import '../../features/businesses/presentation/screens/businesses_screen.dart';
import '../../features/businesses/presentation/screens/business_detail_screen.dart';
import '../../features/businesses/presentation/screens/create_business_screen.dart';
import '../../features/businesses/presentation/screens/boost_business_screen.dart';
import '../../features/businesses/domain/entities/business_entity.dart';
// Marketplace
import '../../features/marketplace/presentation/screens/marketplace_screen.dart';
import '../../features/marketplace/presentation/screens/product_detail_screen.dart';
import '../../features/marketplace/presentation/screens/create_product_screen.dart';
import '../../features/marketplace/presentation/screens/cart_screen.dart';
import '../../features/marketplace/presentation/screens/my_products_screen.dart';
import '../../features/marketplace/domain/entities/product_entity.dart';
// Transfers
import '../../features/transfers/presentation/screens/transfer_screen.dart';
import '../../features/transfers/presentation/screens/send_money_screen.dart';
import '../../features/transfers/presentation/screens/recipient_select_screen.dart';
import '../../features/transfers/presentation/screens/add_recipient_screen.dart';
import '../../features/transfers/presentation/screens/transaction_detail_screen.dart';
import '../../features/transfers/presentation/screens/transaction_history_screen.dart';
import '../../features/transfers/domain/entities/recipient_entity.dart';

import '../../features/notifications/presentation/screens/notification_detail_screen.dart';
// Embassies
import '../../features/embassies/presentation/screens/embassies_screen.dart';
import '../../features/embassies/presentation/screens/embassy_detail_screen.dart';
import '../../features/embassies/domain/entities/embassy_entity.dart';
import '../../features/admin/presentation/screens/admin_embassy_verification_screen.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  // Validates that the provider exists but doesn't rebuild the router when it changes
  // We use a ChangeNotifier to notify GoRouter when to refresh
  final authNotifier = _SimpleNotifier();

  ref.listen(authNotifierProvider, (_, __) {
    authNotifier.notify();
  });

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    debugLogDiagnostics: true,
    refreshListenable: authNotifier,
    observers: [
      FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
    ],
    redirect: (context, state) {
      // Use read() here to avoid rebuilding the provider
      final authState = ref.read(authNotifierProvider);

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
      GoRoute(
        path: '/groups/:groupId/members',
        builder: (context, state) {
          final groupId = state.pathParameters['groupId']!;
          final group = state.extra as GroupEntity?;
          return GroupMembersScreen(groupId: groupId, group: group);
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
      // Marketplace routes
      GoRoute(
        path: '/marketplace',
        builder: (context, state) => const MarketplaceScreen(),
      ),
      GoRoute(
        path: '/marketplace/create',
        builder: (context, state) {
          final product = state.extra as ProductEntity?;
          return CreateProductScreen(product: product);
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
        path: '/marketplace/:productId',
        builder: (context, state) {
          final productId = state.pathParameters['productId']!;
          return ProductDetailScreen(productId: productId);
        },
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
            groupId: extra?['groupId'] as String?, // Pass groupId
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

class _SimpleNotifier extends ChangeNotifier {
  void notify() {
    notifyListeners();
  }
}
