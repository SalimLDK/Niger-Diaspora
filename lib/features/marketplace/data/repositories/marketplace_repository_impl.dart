import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/product_entity.dart';
import '../../domain/entities/order_entity.dart';
import '../../domain/repositories/marketplace_repository.dart';
import '../datasources/marketplace_remote_datasource.dart';
import '../models/product_model.dart';
import '../models/order_model.dart';

class MarketplaceRepositoryImpl implements MarketplaceRepository {
  final MarketplaceRemoteDatasource _remoteDatasource;

  MarketplaceRepositoryImpl({
    required MarketplaceRemoteDatasource remoteDatasource,
  }) : _remoteDatasource = remoteDatasource;

  // ============ PRODUCTS ============

  @override
  Future<Either<Failure, List<ProductEntity>>> getProducts({
    ProductCategory? category,
    String? sellerId,
    int limit = 20,
  }) async {
    try {
      final products = await _remoteDatasource.getProducts(
        category: category?.name,
        sellerId: sellerId,
        limit: limit,
      );
      return Right(products.map((p) => p.toEntity()).toList());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, ProductEntity>> getProduct(String id) async {
    try {
      final product = await _remoteDatasource.getProduct(id);
      return Right(product.toEntity());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, ProductEntity>> createProduct(
    ProductEntity product,
  ) async {
    try {
      final model = ProductModel.fromEntity(product);
      final created = await _remoteDatasource.createProduct(model);
      return Right(created.toEntity());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, ProductEntity>> updateProduct(
    ProductEntity product,
  ) async {
    try {
      final model = ProductModel.fromEntity(product);
      final updated = await _remoteDatasource.updateProduct(model);
      return Right(updated.toEntity());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteProduct(String id) async {
    try {
      await _remoteDatasource.deleteProduct(id);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<ProductEntity>>> searchProducts(
    String query,
  ) async {
    try {
      final products = await _remoteDatasource.searchProducts(query);
      return Right(products.map((p) => p.toEntity()).toList());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> incrementViewCount(String productId) async {
    try {
      await _remoteDatasource.incrementViewCount(productId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Stream<List<ProductEntity>> watchSellerProducts(String sellerId) {
    return _remoteDatasource
        .watchSellerProducts(sellerId)
        .map((models) => models.map((m) => m.toEntity()).toList());
  }

  // ============ ORDERS ============

  @override
  Future<Either<Failure, List<OrderEntity>>> getBuyerOrders(
    String buyerId,
  ) async {
    try {
      final orders = await _remoteDatasource.getBuyerOrders(buyerId);
      return Right(orders.map((o) => o.toEntity()).toList());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<OrderEntity>>> getSellerOrders(
    String sellerId,
  ) async {
    try {
      final orders = await _remoteDatasource.getSellerOrders(sellerId);
      return Right(orders.map((o) => o.toEntity()).toList());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, OrderEntity>> getOrder(String id) async {
    try {
      final order = await _remoteDatasource.getOrder(id);
      return Right(order.toEntity());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, OrderEntity>> createOrder({
    required ProductEntity product,
    required String buyerId,
    String? buyerName,
    required int quantity,
    String? shippingAddress,
    String? buyerNote,
    double platformFeePercent = 0.05,
  }) async {
    try {
      // Calculate amounts with proper rounding to avoid floating point precision issues
      // This is especially important for certain currencies
      final amount = (product.price * quantity * 100).round() / 100;
      final platformFee = (amount * platformFeePercent * 100).round() / 100;
      final sellerAmount = (amount - platformFee * 100).round() / 100;

      final orderModel = OrderModel(
        id: '',
        productId: product.id,
        productTitle: product.title,
        productImageUrl:
            product.imageUrls.isNotEmpty ? product.imageUrls.first : null,
        buyerId: buyerId,
        buyerName: buyerName,
        sellerId: product.sellerId,
        sellerName: product.sellerName,
        amount: amount,
        platformFee: platformFee,
        sellerAmount: sellerAmount,
        currency: product.currency,
        quantity: quantity,
        status: 'pending',
        escrowStatus: 'notCreated',
        shippingAddress: shippingAddress,
        buyerNote: buyerNote,
      );

      final created = await _remoteDatasource.createOrder(orderModel);
      return Right(created.toEntity());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, OrderEntity>> payOrder(String orderId) async {
    try {
      final order = await _remoteDatasource.updateOrderStatus(orderId, 'paid');
      return Right(order.toEntity());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, OrderEntity>> markAsShipped(
    String orderId,
    String? trackingNumber,
  ) async {
    try {
      final order = await _remoteDatasource.markAsShipped(
        orderId,
        trackingNumber,
      );
      return Right(order.toEntity());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, OrderEntity>> confirmDelivery(String orderId) async {
    try {
      final order = await _remoteDatasource.confirmDelivery(orderId);
      return Right(order.toEntity());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, OrderEntity>> releaseEscrow(String orderId) async {
    try {
      final order = await _remoteDatasource.releaseEscrow(orderId);
      return Right(order.toEntity());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, OrderEntity>> cancelOrder(
    String orderId,
    String reason,
  ) async {
    try {
      final order = await _remoteDatasource.cancelOrder(orderId, reason);
      return Right(order.toEntity());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, OrderEntity>> refundOrder(String orderId) async {
    try {
      final order = await _remoteDatasource.updateOrderStatus(
        orderId,
        'refunded',
      );
      return Right(order.toEntity());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Stream<OrderEntity> watchOrder(String orderId) {
    return _remoteDatasource
        .watchOrder(orderId)
        .map((model) => model.toEntity());
  }

  @override
  Stream<List<OrderEntity>> watchBuyerOrders(String buyerId) {
    return _remoteDatasource
        .watchBuyerOrders(buyerId)
        .map((models) => models.map((m) => m.toEntity()).toList());
  }

  @override
  Stream<List<OrderEntity>> watchSellerOrders(String sellerId) {
    return _remoteDatasource
        .watchSellerOrders(sellerId)
        .map((models) => models.map((m) => m.toEntity()).toList());
  }
}
