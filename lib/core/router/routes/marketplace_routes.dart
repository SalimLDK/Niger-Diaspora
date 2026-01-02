import 'package:go_router/go_router.dart';
import '../../../features/marketplace/presentation/screens/marketplace_screen.dart';
import '../../../features/marketplace/presentation/screens/product_detail_screen.dart';
import '../../../features/marketplace/presentation/screens/create_product_screen.dart';
import '../../../features/marketplace/presentation/screens/cart_screen.dart';
import '../../../features/marketplace/presentation/screens/my_products_screen.dart';
import '../../../features/marketplace/presentation/screens/my_orders_screen.dart';
import '../../../features/marketplace/domain/entities/product_entity.dart';

/// Routes du marketplace
class MarketplaceRoutes {
  MarketplaceRoutes._();

  static List<RouteBase> get routes => [
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
      path: '/marketplace/:productId/edit',
      builder: (context, state) {
        final product = state.extra as ProductEntity?;
        return CreateProductScreen(product: product);
      },
    ),
  ];
}
