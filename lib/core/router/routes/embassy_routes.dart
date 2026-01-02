import 'package:go_router/go_router.dart';
import '../../../features/embassies/presentation/screens/embassies_screen.dart';
import '../../../features/embassies/presentation/screens/embassy_detail_screen.dart';
import '../../../features/embassies/presentation/screens/employee_search_screen.dart';
import '../../../features/embassies/domain/entities/embassy_entity.dart';
import '../../../features/admin/presentation/screens/admin_embassy_verification_screen.dart';
import '../../../features/admin/presentation/screens/admin_create_embassy_screen.dart';

/// Routes des ambassades
class EmbassyRoutes {
  EmbassyRoutes._();

  static List<RouteBase> get routes => [
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
        final embassy = state.extra as EmbassyEntity?;
        if (embassy != null) {
          return EmbassyDetailScreen(embassy: embassy);
        }
        // Fallback si pas d'extra
        return EmbassyDetailScreen(embassy: embassy!);
      },
    ),
  ];
}
