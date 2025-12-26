// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'marketplace_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$marketplaceRemoteDatasourceHash() =>
    r'e2f1f1c6e95d03c2c4d9f79db3178fc0d0e97847';

/// See also [marketplaceRemoteDatasource].
@ProviderFor(marketplaceRemoteDatasource)
final marketplaceRemoteDatasourceProvider =
    AutoDisposeProvider<MarketplaceRemoteDatasource>.internal(
      marketplaceRemoteDatasource,
      name: r'marketplaceRemoteDatasourceProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$marketplaceRemoteDatasourceHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef MarketplaceRemoteDatasourceRef =
    AutoDisposeProviderRef<MarketplaceRemoteDatasource>;
String _$marketplaceRepositoryHash() =>
    r'dcdd63b796e1e1efd08d40a2504e5c38541bd21b';

/// See also [marketplaceRepository].
@ProviderFor(marketplaceRepository)
final marketplaceRepositoryProvider =
    AutoDisposeProvider<MarketplaceRepository>.internal(
      marketplaceRepository,
      name: r'marketplaceRepositoryProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$marketplaceRepositoryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef MarketplaceRepositoryRef =
    AutoDisposeProviderRef<MarketplaceRepository>;
String _$productsHash() => r'e993a7ad7e7490dcd6b6dab178f03df17e175ffb';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// See also [products].
@ProviderFor(products)
const productsProvider = ProductsFamily();

/// See also [products].
class ProductsFamily extends Family<AsyncValue<List<ProductEntity>>> {
  /// See also [products].
  const ProductsFamily();

  /// See also [products].
  ProductsProvider call({ProductCategory? category, String? sellerId}) {
    return ProductsProvider(category: category, sellerId: sellerId);
  }

  @override
  ProductsProvider getProviderOverride(covariant ProductsProvider provider) {
    return call(category: provider.category, sellerId: provider.sellerId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'productsProvider';
}

/// See also [products].
class ProductsProvider extends AutoDisposeFutureProvider<List<ProductEntity>> {
  /// See also [products].
  ProductsProvider({ProductCategory? category, String? sellerId})
    : this._internal(
        (ref) => products(
          ref as ProductsRef,
          category: category,
          sellerId: sellerId,
        ),
        from: productsProvider,
        name: r'productsProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$productsHash,
        dependencies: ProductsFamily._dependencies,
        allTransitiveDependencies: ProductsFamily._allTransitiveDependencies,
        category: category,
        sellerId: sellerId,
      );

  ProductsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.category,
    required this.sellerId,
  }) : super.internal();

  final ProductCategory? category;
  final String? sellerId;

  @override
  Override overrideWith(
    FutureOr<List<ProductEntity>> Function(ProductsRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ProductsProvider._internal(
        (ref) => create(ref as ProductsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        category: category,
        sellerId: sellerId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<ProductEntity>> createElement() {
    return _ProductsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ProductsProvider &&
        other.category == category &&
        other.sellerId == sellerId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, category.hashCode);
    hash = _SystemHash.combine(hash, sellerId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ProductsRef on AutoDisposeFutureProviderRef<List<ProductEntity>> {
  /// The parameter `category` of this provider.
  ProductCategory? get category;

  /// The parameter `sellerId` of this provider.
  String? get sellerId;
}

class _ProductsProviderElement
    extends AutoDisposeFutureProviderElement<List<ProductEntity>>
    with ProductsRef {
  _ProductsProviderElement(super.provider);

  @override
  ProductCategory? get category => (origin as ProductsProvider).category;
  @override
  String? get sellerId => (origin as ProductsProvider).sellerId;
}

String _$productHash() => r'f908d99059941ae1a638b897e9969a11ca69ae8e';

/// See also [product].
@ProviderFor(product)
const productProvider = ProductFamily();

/// See also [product].
class ProductFamily extends Family<AsyncValue<ProductEntity>> {
  /// See also [product].
  const ProductFamily();

  /// See also [product].
  ProductProvider call(String id) {
    return ProductProvider(id);
  }

  @override
  ProductProvider getProviderOverride(covariant ProductProvider provider) {
    return call(provider.id);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'productProvider';
}

/// See also [product].
class ProductProvider extends AutoDisposeFutureProvider<ProductEntity> {
  /// See also [product].
  ProductProvider(String id)
    : this._internal(
        (ref) => product(ref as ProductRef, id),
        from: productProvider,
        name: r'productProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$productHash,
        dependencies: ProductFamily._dependencies,
        allTransitiveDependencies: ProductFamily._allTransitiveDependencies,
        id: id,
      );

  ProductProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.id,
  }) : super.internal();

  final String id;

  @override
  Override overrideWith(
    FutureOr<ProductEntity> Function(ProductRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ProductProvider._internal(
        (ref) => create(ref as ProductRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        id: id,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<ProductEntity> createElement() {
    return _ProductProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ProductProvider && other.id == id;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, id.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ProductRef on AutoDisposeFutureProviderRef<ProductEntity> {
  /// The parameter `id` of this provider.
  String get id;
}

class _ProductProviderElement
    extends AutoDisposeFutureProviderElement<ProductEntity>
    with ProductRef {
  _ProductProviderElement(super.provider);

  @override
  String get id => (origin as ProductProvider).id;
}

String _$searchProductsHash() => r'61d99b66a4cebd4625bebf758886b4bc0aec81ab';

/// See also [searchProducts].
@ProviderFor(searchProducts)
const searchProductsProvider = SearchProductsFamily();

/// See also [searchProducts].
class SearchProductsFamily extends Family<AsyncValue<List<ProductEntity>>> {
  /// See also [searchProducts].
  const SearchProductsFamily();

  /// See also [searchProducts].
  SearchProductsProvider call(String query) {
    return SearchProductsProvider(query);
  }

  @override
  SearchProductsProvider getProviderOverride(
    covariant SearchProductsProvider provider,
  ) {
    return call(provider.query);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'searchProductsProvider';
}

/// See also [searchProducts].
class SearchProductsProvider
    extends AutoDisposeFutureProvider<List<ProductEntity>> {
  /// See also [searchProducts].
  SearchProductsProvider(String query)
    : this._internal(
        (ref) => searchProducts(ref as SearchProductsRef, query),
        from: searchProductsProvider,
        name: r'searchProductsProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$searchProductsHash,
        dependencies: SearchProductsFamily._dependencies,
        allTransitiveDependencies:
            SearchProductsFamily._allTransitiveDependencies,
        query: query,
      );

  SearchProductsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.query,
  }) : super.internal();

  final String query;

  @override
  Override overrideWith(
    FutureOr<List<ProductEntity>> Function(SearchProductsRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: SearchProductsProvider._internal(
        (ref) => create(ref as SearchProductsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        query: query,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<ProductEntity>> createElement() {
    return _SearchProductsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SearchProductsProvider && other.query == query;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, query.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin SearchProductsRef on AutoDisposeFutureProviderRef<List<ProductEntity>> {
  /// The parameter `query` of this provider.
  String get query;
}

class _SearchProductsProviderElement
    extends AutoDisposeFutureProviderElement<List<ProductEntity>>
    with SearchProductsRef {
  _SearchProductsProviderElement(super.provider);

  @override
  String get query => (origin as SearchProductsProvider).query;
}

String _$sellerProductsHash() => r'd9d8812cad1413717117b680508207c793533d3e';

/// See also [sellerProducts].
@ProviderFor(sellerProducts)
const sellerProductsProvider = SellerProductsFamily();

/// See also [sellerProducts].
class SellerProductsFamily extends Family<AsyncValue<List<ProductEntity>>> {
  /// See also [sellerProducts].
  const SellerProductsFamily();

  /// See also [sellerProducts].
  SellerProductsProvider call(String sellerId) {
    return SellerProductsProvider(sellerId);
  }

  @override
  SellerProductsProvider getProviderOverride(
    covariant SellerProductsProvider provider,
  ) {
    return call(provider.sellerId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'sellerProductsProvider';
}

/// See also [sellerProducts].
class SellerProductsProvider
    extends AutoDisposeStreamProvider<List<ProductEntity>> {
  /// See also [sellerProducts].
  SellerProductsProvider(String sellerId)
    : this._internal(
        (ref) => sellerProducts(ref as SellerProductsRef, sellerId),
        from: sellerProductsProvider,
        name: r'sellerProductsProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$sellerProductsHash,
        dependencies: SellerProductsFamily._dependencies,
        allTransitiveDependencies:
            SellerProductsFamily._allTransitiveDependencies,
        sellerId: sellerId,
      );

  SellerProductsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.sellerId,
  }) : super.internal();

  final String sellerId;

  @override
  Override overrideWith(
    Stream<List<ProductEntity>> Function(SellerProductsRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: SellerProductsProvider._internal(
        (ref) => create(ref as SellerProductsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        sellerId: sellerId,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<List<ProductEntity>> createElement() {
    return _SellerProductsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SellerProductsProvider && other.sellerId == sellerId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, sellerId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin SellerProductsRef on AutoDisposeStreamProviderRef<List<ProductEntity>> {
  /// The parameter `sellerId` of this provider.
  String get sellerId;
}

class _SellerProductsProviderElement
    extends AutoDisposeStreamProviderElement<List<ProductEntity>>
    with SellerProductsRef {
  _SellerProductsProviderElement(super.provider);

  @override
  String get sellerId => (origin as SellerProductsProvider).sellerId;
}

String _$buyerOrdersHash() => r'11ba4cc649032c3d57647e97395309f80c248897';

/// See also [buyerOrders].
@ProviderFor(buyerOrders)
const buyerOrdersProvider = BuyerOrdersFamily();

/// See also [buyerOrders].
class BuyerOrdersFamily extends Family<AsyncValue<List<OrderEntity>>> {
  /// See also [buyerOrders].
  const BuyerOrdersFamily();

  /// See also [buyerOrders].
  BuyerOrdersProvider call(String buyerId) {
    return BuyerOrdersProvider(buyerId);
  }

  @override
  BuyerOrdersProvider getProviderOverride(
    covariant BuyerOrdersProvider provider,
  ) {
    return call(provider.buyerId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'buyerOrdersProvider';
}

/// See also [buyerOrders].
class BuyerOrdersProvider extends AutoDisposeFutureProvider<List<OrderEntity>> {
  /// See also [buyerOrders].
  BuyerOrdersProvider(String buyerId)
    : this._internal(
        (ref) => buyerOrders(ref as BuyerOrdersRef, buyerId),
        from: buyerOrdersProvider,
        name: r'buyerOrdersProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$buyerOrdersHash,
        dependencies: BuyerOrdersFamily._dependencies,
        allTransitiveDependencies: BuyerOrdersFamily._allTransitiveDependencies,
        buyerId: buyerId,
      );

  BuyerOrdersProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.buyerId,
  }) : super.internal();

  final String buyerId;

  @override
  Override overrideWith(
    FutureOr<List<OrderEntity>> Function(BuyerOrdersRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: BuyerOrdersProvider._internal(
        (ref) => create(ref as BuyerOrdersRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        buyerId: buyerId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<OrderEntity>> createElement() {
    return _BuyerOrdersProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is BuyerOrdersProvider && other.buyerId == buyerId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, buyerId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin BuyerOrdersRef on AutoDisposeFutureProviderRef<List<OrderEntity>> {
  /// The parameter `buyerId` of this provider.
  String get buyerId;
}

class _BuyerOrdersProviderElement
    extends AutoDisposeFutureProviderElement<List<OrderEntity>>
    with BuyerOrdersRef {
  _BuyerOrdersProviderElement(super.provider);

  @override
  String get buyerId => (origin as BuyerOrdersProvider).buyerId;
}

String _$sellerOrdersHash() => r'ef4ca09eb90c28d4b76feb3f9ce5ca0489f3fe3a';

/// See also [sellerOrders].
@ProviderFor(sellerOrders)
const sellerOrdersProvider = SellerOrdersFamily();

/// See also [sellerOrders].
class SellerOrdersFamily extends Family<AsyncValue<List<OrderEntity>>> {
  /// See also [sellerOrders].
  const SellerOrdersFamily();

  /// See also [sellerOrders].
  SellerOrdersProvider call(String sellerId) {
    return SellerOrdersProvider(sellerId);
  }

  @override
  SellerOrdersProvider getProviderOverride(
    covariant SellerOrdersProvider provider,
  ) {
    return call(provider.sellerId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'sellerOrdersProvider';
}

/// See also [sellerOrders].
class SellerOrdersProvider
    extends AutoDisposeFutureProvider<List<OrderEntity>> {
  /// See also [sellerOrders].
  SellerOrdersProvider(String sellerId)
    : this._internal(
        (ref) => sellerOrders(ref as SellerOrdersRef, sellerId),
        from: sellerOrdersProvider,
        name: r'sellerOrdersProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$sellerOrdersHash,
        dependencies: SellerOrdersFamily._dependencies,
        allTransitiveDependencies:
            SellerOrdersFamily._allTransitiveDependencies,
        sellerId: sellerId,
      );

  SellerOrdersProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.sellerId,
  }) : super.internal();

  final String sellerId;

  @override
  Override overrideWith(
    FutureOr<List<OrderEntity>> Function(SellerOrdersRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: SellerOrdersProvider._internal(
        (ref) => create(ref as SellerOrdersRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        sellerId: sellerId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<OrderEntity>> createElement() {
    return _SellerOrdersProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SellerOrdersProvider && other.sellerId == sellerId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, sellerId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin SellerOrdersRef on AutoDisposeFutureProviderRef<List<OrderEntity>> {
  /// The parameter `sellerId` of this provider.
  String get sellerId;
}

class _SellerOrdersProviderElement
    extends AutoDisposeFutureProviderElement<List<OrderEntity>>
    with SellerOrdersRef {
  _SellerOrdersProviderElement(super.provider);

  @override
  String get sellerId => (origin as SellerOrdersProvider).sellerId;
}

String _$watchBuyerOrdersHash() => r'955aecd2704ddc991fb27ea27ebc660961b2685d';

/// See also [watchBuyerOrders].
@ProviderFor(watchBuyerOrders)
const watchBuyerOrdersProvider = WatchBuyerOrdersFamily();

/// See also [watchBuyerOrders].
class WatchBuyerOrdersFamily extends Family<AsyncValue<List<OrderEntity>>> {
  /// See also [watchBuyerOrders].
  const WatchBuyerOrdersFamily();

  /// See also [watchBuyerOrders].
  WatchBuyerOrdersProvider call(String buyerId) {
    return WatchBuyerOrdersProvider(buyerId);
  }

  @override
  WatchBuyerOrdersProvider getProviderOverride(
    covariant WatchBuyerOrdersProvider provider,
  ) {
    return call(provider.buyerId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'watchBuyerOrdersProvider';
}

/// See also [watchBuyerOrders].
class WatchBuyerOrdersProvider
    extends AutoDisposeStreamProvider<List<OrderEntity>> {
  /// See also [watchBuyerOrders].
  WatchBuyerOrdersProvider(String buyerId)
    : this._internal(
        (ref) => watchBuyerOrders(ref as WatchBuyerOrdersRef, buyerId),
        from: watchBuyerOrdersProvider,
        name: r'watchBuyerOrdersProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$watchBuyerOrdersHash,
        dependencies: WatchBuyerOrdersFamily._dependencies,
        allTransitiveDependencies:
            WatchBuyerOrdersFamily._allTransitiveDependencies,
        buyerId: buyerId,
      );

  WatchBuyerOrdersProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.buyerId,
  }) : super.internal();

  final String buyerId;

  @override
  Override overrideWith(
    Stream<List<OrderEntity>> Function(WatchBuyerOrdersRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: WatchBuyerOrdersProvider._internal(
        (ref) => create(ref as WatchBuyerOrdersRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        buyerId: buyerId,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<List<OrderEntity>> createElement() {
    return _WatchBuyerOrdersProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is WatchBuyerOrdersProvider && other.buyerId == buyerId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, buyerId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin WatchBuyerOrdersRef on AutoDisposeStreamProviderRef<List<OrderEntity>> {
  /// The parameter `buyerId` of this provider.
  String get buyerId;
}

class _WatchBuyerOrdersProviderElement
    extends AutoDisposeStreamProviderElement<List<OrderEntity>>
    with WatchBuyerOrdersRef {
  _WatchBuyerOrdersProviderElement(super.provider);

  @override
  String get buyerId => (origin as WatchBuyerOrdersProvider).buyerId;
}

String _$watchSellerOrdersHash() => r'1549aabb8834200ab35eebbe76c38c174aef0f60';

/// See also [watchSellerOrders].
@ProviderFor(watchSellerOrders)
const watchSellerOrdersProvider = WatchSellerOrdersFamily();

/// See also [watchSellerOrders].
class WatchSellerOrdersFamily extends Family<AsyncValue<List<OrderEntity>>> {
  /// See also [watchSellerOrders].
  const WatchSellerOrdersFamily();

  /// See also [watchSellerOrders].
  WatchSellerOrdersProvider call(String sellerId) {
    return WatchSellerOrdersProvider(sellerId);
  }

  @override
  WatchSellerOrdersProvider getProviderOverride(
    covariant WatchSellerOrdersProvider provider,
  ) {
    return call(provider.sellerId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'watchSellerOrdersProvider';
}

/// See also [watchSellerOrders].
class WatchSellerOrdersProvider
    extends AutoDisposeStreamProvider<List<OrderEntity>> {
  /// See also [watchSellerOrders].
  WatchSellerOrdersProvider(String sellerId)
    : this._internal(
        (ref) => watchSellerOrders(ref as WatchSellerOrdersRef, sellerId),
        from: watchSellerOrdersProvider,
        name: r'watchSellerOrdersProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$watchSellerOrdersHash,
        dependencies: WatchSellerOrdersFamily._dependencies,
        allTransitiveDependencies:
            WatchSellerOrdersFamily._allTransitiveDependencies,
        sellerId: sellerId,
      );

  WatchSellerOrdersProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.sellerId,
  }) : super.internal();

  final String sellerId;

  @override
  Override overrideWith(
    Stream<List<OrderEntity>> Function(WatchSellerOrdersRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: WatchSellerOrdersProvider._internal(
        (ref) => create(ref as WatchSellerOrdersRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        sellerId: sellerId,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<List<OrderEntity>> createElement() {
    return _WatchSellerOrdersProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is WatchSellerOrdersProvider && other.sellerId == sellerId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, sellerId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin WatchSellerOrdersRef on AutoDisposeStreamProviderRef<List<OrderEntity>> {
  /// The parameter `sellerId` of this provider.
  String get sellerId;
}

class _WatchSellerOrdersProviderElement
    extends AutoDisposeStreamProviderElement<List<OrderEntity>>
    with WatchSellerOrdersRef {
  _WatchSellerOrdersProviderElement(super.provider);

  @override
  String get sellerId => (origin as WatchSellerOrdersProvider).sellerId;
}

String _$watchOrderHash() => r'4729d6fd9f15382eda497dad8924f895cddfdc39';

/// See also [watchOrder].
@ProviderFor(watchOrder)
const watchOrderProvider = WatchOrderFamily();

/// See also [watchOrder].
class WatchOrderFamily extends Family<AsyncValue<OrderEntity>> {
  /// See also [watchOrder].
  const WatchOrderFamily();

  /// See also [watchOrder].
  WatchOrderProvider call(String orderId) {
    return WatchOrderProvider(orderId);
  }

  @override
  WatchOrderProvider getProviderOverride(
    covariant WatchOrderProvider provider,
  ) {
    return call(provider.orderId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'watchOrderProvider';
}

/// See also [watchOrder].
class WatchOrderProvider extends AutoDisposeStreamProvider<OrderEntity> {
  /// See also [watchOrder].
  WatchOrderProvider(String orderId)
    : this._internal(
        (ref) => watchOrder(ref as WatchOrderRef, orderId),
        from: watchOrderProvider,
        name: r'watchOrderProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$watchOrderHash,
        dependencies: WatchOrderFamily._dependencies,
        allTransitiveDependencies: WatchOrderFamily._allTransitiveDependencies,
        orderId: orderId,
      );

  WatchOrderProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.orderId,
  }) : super.internal();

  final String orderId;

  @override
  Override overrideWith(
    Stream<OrderEntity> Function(WatchOrderRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: WatchOrderProvider._internal(
        (ref) => create(ref as WatchOrderRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        orderId: orderId,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<OrderEntity> createElement() {
    return _WatchOrderProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is WatchOrderProvider && other.orderId == orderId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, orderId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin WatchOrderRef on AutoDisposeStreamProviderRef<OrderEntity> {
  /// The parameter `orderId` of this provider.
  String get orderId;
}

class _WatchOrderProviderElement
    extends AutoDisposeStreamProviderElement<OrderEntity>
    with WatchOrderRef {
  _WatchOrderProviderElement(super.provider);

  @override
  String get orderId => (origin as WatchOrderProvider).orderId;
}

String _$productNotifierHash() => r'68d5c03ba406171cf7cdbf7f6d42dbd6620a972a';

/// See also [ProductNotifier].
@ProviderFor(ProductNotifier)
final productNotifierProvider =
    AutoDisposeAsyncNotifierProvider<ProductNotifier, void>.internal(
      ProductNotifier.new,
      name: r'productNotifierProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$productNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ProductNotifier = AutoDisposeAsyncNotifier<void>;
String _$orderNotifierHash() => r'c994a37f926e4ac8b31e74410538621584165335';

/// See also [OrderNotifier].
@ProviderFor(OrderNotifier)
final orderNotifierProvider =
    AutoDisposeAsyncNotifierProvider<OrderNotifier, void>.internal(
      OrderNotifier.new,
      name: r'orderNotifierProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$orderNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$OrderNotifier = AutoDisposeAsyncNotifier<void>;
String _$cartNotifierHash() => r'2e58d4ed0aaf264db4e48cdf522011d2ec46f2fc';

/// See also [CartNotifier].
@ProviderFor(CartNotifier)
final cartNotifierProvider =
    AutoDisposeNotifierProvider<CartNotifier, List<CartItem>>.internal(
      CartNotifier.new,
      name: r'cartNotifierProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$cartNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$CartNotifier = AutoDisposeNotifier<List<CartItem>>;
String _$selectedCategoryHash() => r'83b8c001cf48417c6732ed7b77c42c40bd1e46e8';

/// See also [SelectedCategory].
@ProviderFor(SelectedCategory)
final selectedCategoryProvider =
    AutoDisposeNotifierProvider<SelectedCategory, ProductCategory?>.internal(
      SelectedCategory.new,
      name: r'selectedCategoryProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$selectedCategoryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$SelectedCategory = AutoDisposeNotifier<ProductCategory?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
