import 'package:go_router/go_router.dart';
import '../../../features/auth/presentation/screens/splash_screen.dart';
import '../../../features/auth/presentation/screens/login_screen.dart';
import '../../../features/auth/presentation/screens/register_screen.dart';
import '../../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../../features/auth/presentation/screens/consent_screen.dart';
import '../../../features/auth/presentation/screens/maintenance_screen.dart';
import '../../../features/onboarding/presentation/screens/onboarding_intro_screen.dart';
import '../../../features/profile/presentation/screens/profile_config_screen.dart';

/// Routes d'authentification et d'onboarding
class AuthRoutes {
  AuthRoutes._();

  static List<RouteBase> get routes => [
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
    GoRoute(
      path: '/consent',
      builder: (context, state) => const ConsentScreen(),
    ),
    GoRoute(
      path: '/profile-config',
      builder: (context, state) => const ProfileConfigScreen(),
    ),
    GoRoute(
      path: '/onboarding/intro',
      builder: (context, state) => const OnboardingIntroScreen(),
    ),
  ];
}
