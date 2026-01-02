import 'package:go_router/go_router.dart';
import '../../../features/businesses/presentation/screens/businesses_screen.dart';
import '../../../features/businesses/presentation/screens/business_detail_screen.dart';
import '../../../features/businesses/presentation/screens/create_business_screen.dart';
import '../../../features/businesses/presentation/screens/boost_business_screen.dart';
import '../../../features/businesses/presentation/screens/business_reviews_screen.dart';
import '../../../features/businesses/domain/entities/business_entity.dart';

/// Routes de l'annuaire des entreprises
class BusinessRoutes {
  BusinessRoutes._();

  static List<RouteBase> get routes => [
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
  ];
}
