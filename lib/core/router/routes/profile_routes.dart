import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../../../features/profile/presentation/screens/edit_profile_screen.dart';
import '../../../features/profile/presentation/screens/profile_view_screen.dart';
import '../../../features/profile/presentation/screens/qr_scanner_screen.dart';
import '../../../features/profile/domain/entities/profile_entity.dart';

/// Routes du profil utilisateur
class ProfileRoutes {
  ProfileRoutes._();

  static List<RouteBase> get routes => [
    GoRoute(
      path: '/profile/edit',
      builder: (context, state) => const EditProfileScreen(),
    ),
    GoRoute(
      path: '/profile/:userId',
      redirect: (context, state) {
        final userId = state.pathParameters['userId']!;
        final currentUserId = FirebaseAuth.instance.currentUser?.uid;
        if (currentUserId != null && currentUserId == userId) {
          return '/profile';
        }
        return null;
      },
      builder: (context, state) {
        final userId = state.pathParameters['userId']!;
        final profile = state.extra as ProfileEntity?;
        return ProfileViewScreen(userId: userId, initialProfile: profile);
      },
    ),
    // Deep link pour les partages de profil
    GoRoute(
      path: '/p/u/:userId',
      redirect: (context, state) {
        final userId = state.pathParameters['userId']!;
        final currentUserId = FirebaseAuth.instance.currentUser?.uid;
        if (currentUserId != null && currentUserId == userId) {
          return '/profile';
        }
        return '/profile/$userId';
      },
    ),
    GoRoute(
      path: '/qr-scanner',
      builder: (context, state) => const QrScannerScreen(),
    ),
  ];
}
