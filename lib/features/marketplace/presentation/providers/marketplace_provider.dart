import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/services/currency_provider.dart';
import '../../../../core/services/currency_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
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

@Riverpod(keepAlive: true)
Future<List<ProductEntity>> products(
  Ref ref, {
  ProductCategory? category,
  Country? country,
  String? sellerId,
}) async {
  final repository = ref.watch(marketplaceRepositoryProvider);
  final result = await repository.getProducts(
    category: category,
    country: country,
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
    final repository = ref.read(marketplaceRepositoryProvider);
    final result = await repository.createProduct(product);
    return result.fold(
      (failure) => null,
      (created) {
        ref.invalidate(productsProvider);
        return created;
      },
    );
  }

  Future<ProductEntity?> updateProduct(ProductEntity product) async {
    final repository = ref.read(marketplaceRepositoryProvider);
    final result = await repository.updateProduct(product);
    return result.fold(
      (failure) => null,
      (updated) {
        ref.invalidate(productsProvider);
        ref.invalidate(productProvider(product.id));
        return updated;
      },
    );
  }

  Future<bool> deleteProduct(String id) async {
    final repository = ref.read(marketplaceRepositoryProvider);
    final result = await repository.deleteProduct(id);
    return result.fold(
      (failure) => false,
      (_) {
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
      (failure) => null,
      (order) {
        ref.invalidate(buyerOrdersProvider(buyerId));
        ref.invalidate(productProvider(product.id));
        return order;
      },
    );
  }

  Future<bool> payOrder(String orderId, String buyerId) async {
    final repository = ref.read(marketplaceRepositoryProvider);
    final result = await repository.payOrder(orderId);
    return result.fold(
      (failure) => false,
      (_) {
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
    final repository = ref.read(marketplaceRepositoryProvider);
    final result = await repository.markAsShipped(orderId, trackingNumber);
    return result.fold(
      (failure) => false,
      (_) {
        ref.invalidate(sellerOrdersProvider(sellerId));
        return true;
      },
    );
  }

  Future<bool> confirmDelivery(String orderId, String buyerId) async {
    final repository = ref.read(marketplaceRepositoryProvider);
    final result = await repository.confirmDelivery(orderId);
    return result.fold(
      (failure) => false,
      (_) {
        ref.invalidate(buyerOrdersProvider(buyerId));
        return true;
      },
    );
  }

  Future<bool> releaseEscrow(String orderId, String buyerId) async {
    final repository = ref.read(marketplaceRepositoryProvider);
    final result = await repository.releaseEscrow(orderId);
    return result.fold(
      (failure) => false,
      (_) {
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
    final repository = ref.read(marketplaceRepositoryProvider);
    final result = await repository.cancelOrder(orderId, reason);
    return result.fold(
      (failure) => false,
      (_) {
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

  Map<String, dynamic> toJson() => {
    'productId': product.id,
    'quantity': quantity,
    'product': product.toJson(),
  };

  static CartItem? fromJson(Map<String, dynamic> json) {
    try {
      final productJson = json['product'] as Map<String, dynamic>?;
      if (productJson == null) return null;
      return CartItem(
        product: ProductEntity.fromJson(productJson),
        quantity: json['quantity'] as int? ?? 1,
      );
    } catch (_) {
      return null;
    }
  }
}

@Riverpod(keepAlive: true)
class CartNotifier extends _$CartNotifier {
  static const String _cartKey = 'marketplace_cart';

  @override
  List<CartItem> build() {
    // Load cart on initialization
    _loadCartFromLocal();
    return [];
  }

  Future<void> _loadCartFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJson = prefs.getString(_cartKey);
      if (cartJson != null) {
        final List<dynamic> decoded = jsonDecode(cartJson);
        final items =
            decoded
                .map((e) => CartItem.fromJson(e as Map<String, dynamic>))
                .whereType<CartItem>()
                .toList();
        state = items;
      }

      // Also try to sync from cloud if logged in
      await _syncFromCloud();
    } catch (_) {
      // Ignore cart loading errors
    }
  }

  Future<void> _saveCartToLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJson = jsonEncode(state.map((e) => e.toJson()).toList());
      await prefs.setString(_cartKey, cartJson);
    } catch (_) {
      // Ignore cart saving errors
    }
  }

  Future<void> _syncToCloud() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final cartData =
          state
              .map(
                (item) => {
                  'productId': item.product.id,
                  'quantity': item.quantity,
                  'addedAt': FieldValue.serverTimestamp(),
                },
              )
              .toList();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('cart')
          .doc('items')
          .set({'items': cartData, 'updatedAt': FieldValue.serverTimestamp()});
    } catch (_) {
      // Ignore cloud sync errors
    }
  }

  Future<void> _syncFromCloud() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('cart')
              .doc('items')
              .get();

      if (!doc.exists) return;

      final items = doc.data()?['items'] as List<dynamic>?;
      if (items == null || items.isEmpty) return;

      // If local cart is empty, use cloud cart
      if (state.isEmpty) {
        final repository = ref.read(marketplaceRepositoryProvider);
        final loadedItems = <CartItem>[];

        for (final item in items) {
          final productId = item['productId'] as String?;
          final quantity = item['quantity'] as int? ?? 1;
          if (productId != null) {
            final result = await repository.getProduct(productId);
            result.fold(
              (_) {}, // Ignore failed products
              (product) {
                if (product.isAvailable && product.quantity >= quantity) {
                  loadedItems.add(
                    CartItem(product: product, quantity: quantity),
                  );
                }
              },
            );
          }
        }

        if (loadedItems.isNotEmpty) {
          state = loadedItems;
          await _saveCartToLocal();
        }
      }
    } catch (_) {
      // Ignore cloud sync errors
    }
  }

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
        _persistCart();
      }
    } else {
      if (quantity <= product.quantity) {
        state = [...state, CartItem(product: product, quantity: quantity)];
        _persistCart();
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
        _persistCart();
      }
    }
  }

  void removeFromCart(String productId) {
    state = state.where((item) => item.product.id != productId).toList();
    _persistCart();
  }

  void clearCart() {
    state = [];
    _persistCart();
  }

  void _persistCart() {
    _saveCartToLocal();
    _syncToCloud();
  }

  double get totalAmount =>
      state.fold(0.0, (total, item) => total + item.total);

  int get itemCount => state.fold(0, (total, item) => total + item.quantity);

  /// Retourne les totaux par devise
  Map<String, double> get totalsByCurrency {
    final totals = <String, double>{};
    for (final item in state) {
      final currency = item.product.currency;
      totals[currency] = (totals[currency] ?? 0.0) + item.total;
    }
    return totals;
  }

  /// Verifie si le panier contient plusieurs devises
  bool get hasMultipleCurrencies => totalsByCurrency.keys.length > 1;

  /// Retourne la devise principale du panier (celle avec le plus grand montant)
  String get primaryCurrency {
    if (state.isEmpty) return 'XOF';
    final totals = totalsByCurrency;
    return totals.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }
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

// ============ SELECTED COUNTRY ============

@riverpod
class SelectedCountry extends _$SelectedCountry {
  @override
  Country? build() {
    // Initialize with user's country asynchronously
    _initFromUserProfile();
    return null;
  }

  void _initFromUserProfile() {
    try {
      final user = ref.read(currentUserAsyncProvider).valueOrNull;
      if (user != null) {
        final profile = ref.read(profileNotifierProvider(user.id)).valueOrNull;
        if (profile?.currentCountry != null) {
          final countryName = profile!.currentCountry!;
          // Convert string to Country enum
          final country = Country.values.firstWhere(
            (c) => c.name.toLowerCase() == countryName.toLowerCase(),
            orElse: () => Country.niger,
          );
          state = country;
        }
      }
    } catch (_) {
      // Ignore errors, keep default null (show all)
    }
  }

  void select(Country? country) {
    state = country;
  }
}

// ============ MULTI-CURRENCY CART PROVIDERS ============

/// Provider pour le total du panier converti dans la devise preferee de l'utilisateur
@riverpod
double cartTotalInPreferredCurrency(Ref ref) {
  final cartItems = ref.watch(cartNotifierProvider);
  final preferredCurrencyAsync = ref.watch(userCurrencyPreferenceProvider);
  final preferredCurrency = preferredCurrencyAsync.valueOrNull ?? Currency.eur;
  final currencyService = ref.watch(currencyServiceProvider);

  double total = 0.0;
  for (final item in cartItems) {
    final itemCurrency = CurrencyExtension.fromCode(item.product.currency);
    final itemTotal = item.total;

    // Convertir vers la devise preferee
    final converted = currencyService.convert(
      itemTotal,
      itemCurrency,
      preferredCurrency,
    );
    total += converted;
  }

  return total;
}

/// Provider pour le total du panier formate avec le symbole de devise
@riverpod
String formattedCartTotal(Ref ref) {
  final total = ref.watch(cartTotalInPreferredCurrencyProvider);
  final preferredCurrencyAsync = ref.watch(userCurrencyPreferenceProvider);
  final preferredCurrency = preferredCurrencyAsync.valueOrNull ?? Currency.eur;
  final currencyService = ref.watch(currencyServiceProvider);

  return currencyService.format(total, preferredCurrency);
}

/// Provider pour obtenir le prix d'un article du panier converti
@riverpod
({double originalTotal, double convertedTotal, Currency originalCurrency, Currency targetCurrency})
cartItemConverted(Ref ref, String productId) {
  final cartItems = ref.watch(cartNotifierProvider);
  final preferredCurrencyAsync = ref.watch(userCurrencyPreferenceProvider);
  final preferredCurrency = preferredCurrencyAsync.valueOrNull ?? Currency.eur;
  final currencyService = ref.watch(currencyServiceProvider);

  final item = cartItems.firstWhere(
    (i) => i.product.id == productId,
    orElse: () => throw Exception('Item not found in cart'),
  );

  final originalCurrency = CurrencyExtension.fromCode(item.product.currency);
  final originalTotal = item.total;
  final convertedTotal = currencyService.convert(
    originalTotal,
    originalCurrency,
    preferredCurrency,
  );

  return (
    originalTotal: originalTotal,
    convertedTotal: convertedTotal,
    originalCurrency: originalCurrency,
    targetCurrency: preferredCurrency,
  );
}

/// Provider pour verifier si le panier a plusieurs devises
@riverpod
bool cartHasMultipleCurrencies(Ref ref) {
  final cartItems = ref.watch(cartNotifierProvider);
  if (cartItems.isEmpty) return false;

  final currencies = cartItems.map((item) => item.product.currency).toSet();
  return currencies.length > 1;
}
