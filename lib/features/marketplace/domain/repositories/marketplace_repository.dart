import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/product_entity.dart';
import '../entities/order_entity.dart';

abstract class MarketplaceRepository {
  // Products
  Future<Either<Failure, List<ProductEntity>>> getProducts({
    ProductCategory? category,
    String? sellerId,
    int limit = 20,
  });
  Future<Either<Failure, ProductEntity>> getProduct(String id);
  Future<Either<Failure, ProductEntity>> createProduct(ProductEntity product);
  Future<Either<Failure, ProductEntity>> updateProduct(ProductEntity product);
  Future<Either<Failure, void>> deleteProduct(String id);
  Future<Either<Failure, List<ProductEntity>>> searchProducts(String query);
  Future<Either<Failure, void>> incrementViewCount(String productId);
  Stream<List<ProductEntity>> watchSellerProducts(String sellerId);

  // Orders
  Future<Either<Failure, List<OrderEntity>>> getBuyerOrders(String buyerId);
  Future<Either<Failure, List<OrderEntity>>> getSellerOrders(String sellerId);
  Future<Either<Failure, OrderEntity>> getOrder(String id);
  Future<Either<Failure, OrderEntity>> createOrder({
    required ProductEntity product,
    required String buyerId,
    String? buyerName,
    required int quantity,
    String? shippingAddress,
    String? buyerNote,
    double platformFeePercent = 0.05, // 5% default
  });
  Future<Either<Failure, OrderEntity>> payOrder(String orderId);
  Future<Either<Failure, OrderEntity>> markAsShipped(String orderId, String? trackingNumber);
  Future<Either<Failure, OrderEntity>> confirmDelivery(String orderId);
  Future<Either<Failure, OrderEntity>> releaseEscrow(String orderId);
  Future<Either<Failure, OrderEntity>> cancelOrder(String orderId, String reason);
  Future<Either<Failure, OrderEntity>> refundOrder(String orderId);
  Stream<OrderEntity> watchOrder(String orderId);
  Stream<List<OrderEntity>> watchBuyerOrders(String buyerId);
  Stream<List<OrderEntity>> watchSellerOrders(String sellerId);
}
