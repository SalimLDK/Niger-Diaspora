import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/datasources/marketplace_remote_datasource.dart';
import '../../data/repositories/marketplace_repository_impl.dart';
import '../../domain/entities/product_entity.dart';
import '../../domain/entities/order_entity.dart';
import '../../domain/repositories/marketplace_repository.dart';

part 'marketplace_provider.g.dart';

// ============ DATASOURCE & REPOSITORY ============

@riverpod
MarketplaceRemoteDatasource marketplaceRemoteDatasource(Ref ref) {
  return MarketplaceRemoteDatasourceImpl();
}

@riverpod
MarketplaceRepository marketplaceRepository(Ref ref) {
  return MarketplaceRepositoryImpl(
    remoteDatasource: ref.watch(marketplaceRemoteDatasourceProvider),
  );
}

// ============ PRODUCTS ============

@riverpod
Future<List<ProductEntity>> products(
  Ref ref, {
  ProductCategory? category,
  String? sellerId,
}) async {
  final repository = ref.watch(marketplaceRepositoryProvider);
  final result = await repository.getProducts(
    category: category,
    sellerId: sellerId,
  );
  return result.fold(
    (failure) => throw Exception(failure.message),
    (products) => products,
  );
}

@riverpod
Future<ProductEntity> product(Ref ref, String id) async {
  final repository = ref.watch(marketplaceRepositoryProvider);
  final result = await repository.getProduct(id);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (product) => product,
  );
}

@riverpod
Future<List<ProductEntity>> searchProducts(Ref ref, String query) async {
  if (query.isEmpty) return [];
  final repository = ref.watch(marketplaceRepositoryProvider);
  final result = await repository.searchProducts(query);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (products) => products,
  );
}

@riverpod
Stream<List<ProductEntity>> sellerProducts(Ref ref, String sellerId) {
  final repository = ref.watch(marketplaceRepositoryProvider);
  return repository.watchSellerProducts(sellerId);
}

// ============ ORDERS ============

@riverpod
Future<List<OrderEntity>> buyerOrders(Ref ref, String buyerId) async {
  final repository = ref.watch(marketplaceRepositoryProvider);
  final result = await repository.getBuyerOrders(buyerId);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (orders) => orders,
  );
}

@riverpod
Future<List<OrderEntity>> sellerOrders(Ref ref, String sellerId) async {
  final repository = ref.watch(marketplaceRepositoryProvider);
  final result = await repository.getSellerOrders(sellerId);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (orders) => orders,
  );
}

@riverpod
Stream<List<OrderEntity>> watchBuyerOrders(Ref ref, String buyerId) {
  final repository = ref.watch(marketplaceRepositoryProvider);
  return repository.watchBuyerOrders(buyerId);
}

@riverpod
Stream<List<OrderEntity>> watchSellerOrders(Ref ref, String sellerId) {
  final repository = ref.watch(marketplaceRepositoryProvider);
  return repository.watchSellerOrders(sellerId);
}

@riverpod
Stream<OrderEntity> watchOrder(Ref ref, String orderId) {
  final repository = ref.watch(marketplaceRepositoryProvider);
  return repository.watchOrder(orderId);
}

// ============ PRODUCT NOTIFIER ============

@riverpod
class ProductNotifier extends _$ProductNotifier {
  @override
  FutureOr<void> build() {}

  Future<ProductEntity?> createProduct(ProductEntity product) async {
    state = const AsyncLoading();
    final repository = ref.read(marketplaceRepositoryProvider);
    final result = await repository.createProduct(product);
    return result.fold(
      (failure) {
        state = AsyncError(failure.message, StackTrace.current);
        return null;
      },
      (created) {
        state = const AsyncData(null);
        ref.invalidate(productsProvider);
        return created;
      },
    );
  }

  Future<ProductEntity?> updateProduct(ProductEntity product) async {
    state = const AsyncLoading();
    final repository = ref.read(marketplaceRepositoryProvider);
    final result = await repository.updateProduct(product);
    return result.fold(
      (failure) {
        state = AsyncError(failure.message, StackTrace.current);
        return null;
      },
      (updated) {
        state = const AsyncData(null);
        ref.invalidate(productsProvider);
        ref.invalidate(productProvider(product.id));
        return updated;
      },
    );
  }

  Future<bool> deleteProduct(String id) async {
    state = const AsyncLoading();
    final repository = ref.read(marketplaceRepositoryProvider);
    final result = await repository.deleteProduct(id);
    return result.fold(
      (failure) {
        state = AsyncError(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncData(null);
        ref.invalidate(productsProvider);
        return true;
      },
    );
  }

  Future<void> incrementViewCount(String productId) async {
    final repository = ref.read(marketplaceRepositoryProvider);
    await repository.incrementViewCount(productId);
  }
}

// ============ ORDER NOTIFIER ============

@riverpod
class OrderNotifier extends _$OrderNotifier {
  @override
  FutureOr<void> build() {}

  Future<OrderEntity?> createOrder({
    required ProductEntity product,
    required String buyerId,
    String? buyerName,
    required int quantity,
    String? shippingAddress,
    String? buyerNote,
  }) async {
    state = const AsyncLoading();
    final repository = ref.read(marketplaceRepositoryProvider);
    final result = await repository.createOrder(
      product: product,
      buyerId: buyerId,
      buyerName: buyerName,
      quantity: quantity,
      shippingAddress: shippingAddress,
      buyerNote: buyerNote,
    );
    return result.fold(
      (failure) {
        state = AsyncError(failure.message, StackTrace.current);
        return null;
      },
      (order) {
        state = const AsyncData(null);
        ref.invalidate(buyerOrdersProvider(buyerId));
        ref.invalidate(productProvider(product.id));
        return order;
      },
    );
  }

  Future<bool> payOrder(String orderId, String buyerId) async {
    state = const AsyncLoading();
    final repository = ref.read(marketplaceRepositoryProvider);
    final result = await repository.payOrder(orderId);
    return result.fold(
      (failure) {
        state = AsyncError(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncData(null);
        ref.invalidate(buyerOrdersProvider(buyerId));
        return true;
      },
    );
  }

  Future<bool> markAsShipped(
    String orderId,
    String sellerId,
    String? trackingNumber,
  ) async {
    state = const AsyncLoading();
    final repository = ref.read(marketplaceRepositoryProvider);
    final result = await repository.markAsShipped(orderId, trackingNumber);
    return result.fold(
      (failure) {
        state = AsyncError(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncData(null);
        ref.invalidate(sellerOrdersProvider(sellerId));
        return true;
      },
    );
  }

  Future<bool> confirmDelivery(String orderId, String buyerId) async {
    state = const AsyncLoading();
    final repository = ref.read(marketplaceRepositoryProvider);
    final result = await repository.confirmDelivery(orderId);
    return result.fold(
      (failure) {
        state = AsyncError(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncData(null);
        ref.invalidate(buyerOrdersProvider(buyerId));
        return true;
      },
    );
  }

  Future<bool> releaseEscrow(String orderId, String buyerId) async {
    state = const AsyncLoading();
    final repository = ref.read(marketplaceRepositoryProvider);
    final result = await repository.releaseEscrow(orderId);
    return result.fold(
      (failure) {
        state = AsyncError(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncData(null);
        ref.invalidate(buyerOrdersProvider(buyerId));
        return true;
      },
    );
  }

  Future<bool> cancelOrder(
    String orderId,
    String reason, {
    String? buyerId,
    String? sellerId,
  }) async {
    state = const AsyncLoading();
    final repository = ref.read(marketplaceRepositoryProvider);
    final result = await repository.cancelOrder(orderId, reason);
    return result.fold(
      (failure) {
        state = AsyncError(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncData(null);
        if (buyerId != null) ref.invalidate(buyerOrdersProvider(buyerId));
        if (sellerId != null) ref.invalidate(sellerOrdersProvider(sellerId));
        return true;
      },
    );
  }
}

// ============ CART PROVIDER ============

class CartItem {
  final ProductEntity product;
  final int quantity;

  CartItem({required this.product, required this.quantity});

  CartItem copyWith({ProductEntity? product, int? quantity}) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
    );
  }

  double get total => product.price * quantity;
}

@riverpod
class CartNotifier extends _$CartNotifier {
  @override
  List<CartItem> build() => [];

  void addToCart(ProductEntity product, {int quantity = 1}) {
    final existingIndex = state.indexWhere(
      (item) => item.product.id == product.id,
    );
    if (existingIndex != -1) {
      final existingItem = state[existingIndex];
      final newQuantity = existingItem.quantity + quantity;
      if (newQuantity <= product.quantity) {
        state = [
          ...state.sublist(0, existingIndex),
          existingItem.copyWith(quantity: newQuantity),
          ...state.sublist(existingIndex + 1),
        ];
      }
    } else {
      if (quantity <= product.quantity) {
        state = [...state, CartItem(product: product, quantity: quantity)];
      }
    }
  }

  void updateQuantity(String productId, int quantity) {
    final index = state.indexWhere((item) => item.product.id == productId);
    if (index != -1) {
      if (quantity <= 0) {
        removeFromCart(productId);
      } else if (quantity <= state[index].product.quantity) {
        state = [
          ...state.sublist(0, index),
          state[index].copyWith(quantity: quantity),
          ...state.sublist(index + 1),
        ];
      }
    }
  }

  void removeFromCart(String productId) {
    state = state.where((item) => item.product.id != productId).toList();
  }

  void clearCart() {
    state = [];
  }

  double get totalAmount => state.fold(0, (sum, item) => sum + item.total);

  int get itemCount => state.fold(0, (sum, item) => sum + item.quantity);
}

// ============ SELECTED CATEGORY ============

@riverpod
class SelectedCategory extends _$SelectedCategory {
  @override
  ProductCategory? build() => null;

  void select(ProductCategory? category) {
    state = category;
  }
}
