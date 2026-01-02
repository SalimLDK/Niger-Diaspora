import 'package:go_router/go_router.dart';
import '../../../features/settings/presentation/screens/settings_screen.dart';
import '../../../features/settings/presentation/screens/terms_screen.dart';
import '../../../features/settings/presentation/screens/privacy_policy_screen.dart';
import '../../../features/settings/presentation/screens/code_of_conduct_screen.dart';
import '../../../features/reports/presentation/screens/my_reports_screen.dart';
import '../../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../../features/notifications/presentation/screens/notification_settings_screen.dart';
import '../../../features/notifications/presentation/screens/notification_detail_screen.dart';
import '../../../features/friends/presentation/screens/friends_screen.dart';
import '../../../features/search/presentation/screens/search_screen.dart';

/// Routes des paramètres, notifications et autres
class SettingsRoutes {
  SettingsRoutes._();

  static List<RouteBase> get routes => [
    // Recherche
    GoRoute(
      path: '/search',
      builder: (context, state) => const SearchScreen(),
    ),
    // Notifications
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
    // Amis
    GoRoute(
      path: '/friends',
      builder: (context, state) => const FriendsScreen(),
    ),
    // Paramètres
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
    GoRoute(
      path: '/settings/code-of-conduct',
      builder: (context, state) => const CodeOfConductScreen(),
    ),
    GoRoute(
      path: '/settings/my-reports',
      builder: (context, state) => const MyReportsScreen(),
    ),
  ];
}
