// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tax_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$taxServiceHash() => r'e03833ab0eb32a69a6b3b71677c9f9034890c39a';

/// See also [taxService].
@ProviderFor(taxService)
final taxServiceProvider = AutoDisposeProvider<TaxService>.internal(
  taxService,
  name: r'taxServiceProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$taxServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef TaxServiceRef = AutoDisposeProviderRef<TaxService>;
String _$calculateProductTaxHash() =>
    r'18caddeef41280a084e9ef8208b84bfcb0a1ced7';

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

/// See also [calculateProductTax].
@ProviderFor(calculateProductTax)
const calculateProductTaxProvider = CalculateProductTaxFamily();

/// See also [calculateProductTax].
class CalculateProductTaxFamily extends Family<TaxBreakdown> {
  /// See also [calculateProductTax].
  const CalculateProductTaxFamily();

  /// See also [calculateProductTax].
  CalculateProductTaxProvider call({
    required double amount,
    required String category,
    required int quantity,
    double? customTaxRate,
    bool isTaxExemptSeller = false,
  }) {
    return CalculateProductTaxProvider(
      amount: amount,
      category: category,
      quantity: quantity,
      customTaxRate: customTaxRate,
      isTaxExemptSeller: isTaxExemptSeller,
    );
  }

  @override
  CalculateProductTaxProvider getProviderOverride(
    covariant CalculateProductTaxProvider provider,
  ) {
    return call(
      amount: provider.amount,
      category: provider.category,
      quantity: provider.quantity,
      customTaxRate: provider.customTaxRate,
      isTaxExemptSeller: provider.isTaxExemptSeller,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'calculateProductTaxProvider';
}

/// See also [calculateProductTax].
class CalculateProductTaxProvider extends AutoDisposeProvider<TaxBreakdown> {
  /// See also [calculateProductTax].
  CalculateProductTaxProvider({
    required double amount,
    required String category,
    required int quantity,
    double? customTaxRate,
    bool isTaxExemptSeller = false,
  }) : this._internal(
         (ref) => calculateProductTax(
           ref as CalculateProductTaxRef,
           amount: amount,
           category: category,
           quantity: quantity,
           customTaxRate: customTaxRate,
           isTaxExemptSeller: isTaxExemptSeller,
         ),
         from: calculateProductTaxProvider,
         name: r'calculateProductTaxProvider',
         debugGetCreateSourceHash:
             const bool.fromEnvironment('dart.vm.product')
                 ? null
                 : _$calculateProductTaxHash,
         dependencies: CalculateProductTaxFamily._dependencies,
         allTransitiveDependencies:
             CalculateProductTaxFamily._allTransitiveDependencies,
         amount: amount,
         category: category,
         quantity: quantity,
         customTaxRate: customTaxRate,
         isTaxExemptSeller: isTaxExemptSeller,
       );

  CalculateProductTaxProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.amount,
    required this.category,
    required this.quantity,
    required this.customTaxRate,
    required this.isTaxExemptSeller,
  }) : super.internal();

  final double amount;
  final String category;
  final int quantity;
  final double? customTaxRate;
  final bool isTaxExemptSeller;

  @override
  Override overrideWith(
    TaxBreakdown Function(CalculateProductTaxRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: CalculateProductTaxProvider._internal(
        (ref) => create(ref as CalculateProductTaxRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        amount: amount,
        category: category,
        quantity: quantity,
        customTaxRate: customTaxRate,
        isTaxExemptSeller: isTaxExemptSeller,
      ),
    );
  }

  @override
  AutoDisposeProviderElement<TaxBreakdown> createElement() {
    return _CalculateProductTaxProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is CalculateProductTaxProvider &&
        other.amount == amount &&
        other.category == category &&
        other.quantity == quantity &&
        other.customTaxRate == customTaxRate &&
        other.isTaxExemptSeller == isTaxExemptSeller;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, amount.hashCode);
    hash = _SystemHash.combine(hash, category.hashCode);
    hash = _SystemHash.combine(hash, quantity.hashCode);
    hash = _SystemHash.combine(hash, customTaxRate.hashCode);
    hash = _SystemHash.combine(hash, isTaxExemptSeller.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin CalculateProductTaxRef on AutoDisposeProviderRef<TaxBreakdown> {
  /// The parameter `amount` of this provider.
  double get amount;

  /// The parameter `category` of this provider.
  String get category;

  /// The parameter `quantity` of this provider.
  int get quantity;

  /// The parameter `customTaxRate` of this provider.
  double? get customTaxRate;

  /// The parameter `isTaxExemptSeller` of this provider.
  bool get isTaxExemptSeller;
}

class _CalculateProductTaxProviderElement
    extends AutoDisposeProviderElement<TaxBreakdown>
    with CalculateProductTaxRef {
  _CalculateProductTaxProviderElement(super.provider);

  @override
  double get amount => (origin as CalculateProductTaxProvider).amount;
  @override
  String get category => (origin as CalculateProductTaxProvider).category;
  @override
  int get quantity => (origin as CalculateProductTaxProvider).quantity;
  @override
  double? get customTaxRate =>
      (origin as CalculateProductTaxProvider).customTaxRate;
  @override
  bool get isTaxExemptSeller =>
      (origin as CalculateProductTaxProvider).isTaxExemptSeller;
}

String _$calculateCartTaxHash() => r'b7d165154795aed6b39427cf59c6aaedec8829d8';

/// See also [calculateCartTax].
@ProviderFor(calculateCartTax)
const calculateCartTaxProvider = CalculateCartTaxFamily();

/// See also [calculateCartTax].
class CalculateCartTaxFamily extends Family<TaxBreakdown> {
  /// See also [calculateCartTax].
  const CalculateCartTaxFamily();

  /// See also [calculateCartTax].
  CalculateCartTaxProvider call(List<CartTaxItem> items) {
    return CalculateCartTaxProvider(items);
  }

  @override
  CalculateCartTaxProvider getProviderOverride(
    covariant CalculateCartTaxProvider provider,
  ) {
    return call(provider.items);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'calculateCartTaxProvider';
}

/// See also [calculateCartTax].
class CalculateCartTaxProvider extends AutoDisposeProvider<TaxBreakdown> {
  /// See also [calculateCartTax].
  CalculateCartTaxProvider(List<CartTaxItem> items)
    : this._internal(
        (ref) => calculateCartTax(ref as CalculateCartTaxRef, items),
        from: calculateCartTaxProvider,
        name: r'calculateCartTaxProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$calculateCartTaxHash,
        dependencies: CalculateCartTaxFamily._dependencies,
        allTransitiveDependencies:
            CalculateCartTaxFamily._allTransitiveDependencies,
        items: items,
      );

  CalculateCartTaxProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.items,
  }) : super.internal();

  final List<CartTaxItem> items;

  @override
  Override overrideWith(
    TaxBreakdown Function(CalculateCartTaxRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: CalculateCartTaxProvider._internal(
        (ref) => create(ref as CalculateCartTaxRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        items: items,
      ),
    );
  }

  @override
  AutoDisposeProviderElement<TaxBreakdown> createElement() {
    return _CalculateCartTaxProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is CalculateCartTaxProvider && other.items == items;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, items.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin CalculateCartTaxRef on AutoDisposeProviderRef<TaxBreakdown> {
  /// The parameter `items` of this provider.
  List<CartTaxItem> get items;
}

class _CalculateCartTaxProviderElement
    extends AutoDisposeProviderElement<TaxBreakdown>
    with CalculateCartTaxRef {
  _CalculateCartTaxProviderElement(super.provider);

  @override
  List<CartTaxItem> get items => (origin as CalculateCartTaxProvider).items;
}

String _$taxRateForCategoryHash() =>
    r'd62184d97bbfbf92efb04e119a8e041d0d9f9286';

/// See also [taxRateForCategory].
@ProviderFor(taxRateForCategory)
const taxRateForCategoryProvider = TaxRateForCategoryFamily();

/// See also [taxRateForCategory].
class TaxRateForCategoryFamily extends Family<double> {
  /// See also [taxRateForCategory].
  const TaxRateForCategoryFamily();

  /// See also [taxRateForCategory].
  TaxRateForCategoryProvider call(String category) {
    return TaxRateForCategoryProvider(category);
  }

  @override
  TaxRateForCategoryProvider getProviderOverride(
    covariant TaxRateForCategoryProvider provider,
  ) {
    return call(provider.category);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'taxRateForCategoryProvider';
}

/// See also [taxRateForCategory].
class TaxRateForCategoryProvider extends AutoDisposeProvider<double> {
  /// See also [taxRateForCategory].
  TaxRateForCategoryProvider(String category)
    : this._internal(
        (ref) => taxRateForCategory(ref as TaxRateForCategoryRef, category),
        from: taxRateForCategoryProvider,
        name: r'taxRateForCategoryProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$taxRateForCategoryHash,
        dependencies: TaxRateForCategoryFamily._dependencies,
        allTransitiveDependencies:
            TaxRateForCategoryFamily._allTransitiveDependencies,
        category: category,
      );

  TaxRateForCategoryProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.category,
  }) : super.internal();

  final String category;

  @override
  Override overrideWith(
    double Function(TaxRateForCategoryRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: TaxRateForCategoryProvider._internal(
        (ref) => create(ref as TaxRateForCategoryRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        category: category,
      ),
    );
  }

  @override
  AutoDisposeProviderElement<double> createElement() {
    return _TaxRateForCategoryProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is TaxRateForCategoryProvider && other.category == category;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, category.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin TaxRateForCategoryRef on AutoDisposeProviderRef<double> {
  /// The parameter `category` of this provider.
  String get category;
}

class _TaxRateForCategoryProviderElement
    extends AutoDisposeProviderElement<double>
    with TaxRateForCategoryRef {
  _TaxRateForCategoryProviderElement(super.provider);

  @override
  String get category => (origin as TaxRateForCategoryProvider).category;
}

String _$isCategoryTaxableHash() => r'9fb058fa173d217780a0112a2469eceaa1a7e741';

/// See also [isCategoryTaxable].
@ProviderFor(isCategoryTaxable)
const isCategoryTaxableProvider = IsCategoryTaxableFamily();

/// See also [isCategoryTaxable].
class IsCategoryTaxableFamily extends Family<bool> {
  /// See also [isCategoryTaxable].
  const IsCategoryTaxableFamily();

  /// See also [isCategoryTaxable].
  IsCategoryTaxableProvider call(String category) {
    return IsCategoryTaxableProvider(category);
  }

  @override
  IsCategoryTaxableProvider getProviderOverride(
    covariant IsCategoryTaxableProvider provider,
  ) {
    return call(provider.category);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'isCategoryTaxableProvider';
}

/// See also [isCategoryTaxable].
class IsCategoryTaxableProvider extends AutoDisposeProvider<bool> {
  /// See also [isCategoryTaxable].
  IsCategoryTaxableProvider(String category)
    : this._internal(
        (ref) => isCategoryTaxable(ref as IsCategoryTaxableRef, category),
        from: isCategoryTaxableProvider,
        name: r'isCategoryTaxableProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$isCategoryTaxableHash,
        dependencies: IsCategoryTaxableFamily._dependencies,
        allTransitiveDependencies:
            IsCategoryTaxableFamily._allTransitiveDependencies,
        category: category,
      );

  IsCategoryTaxableProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.category,
  }) : super.internal();

  final String category;

  @override
  Override overrideWith(bool Function(IsCategoryTaxableRef provider) create) {
    return ProviderOverride(
      origin: this,
      override: IsCategoryTaxableProvider._internal(
        (ref) => create(ref as IsCategoryTaxableRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        category: category,
      ),
    );
  }

  @override
  AutoDisposeProviderElement<bool> createElement() {
    return _IsCategoryTaxableProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is IsCategoryTaxableProvider && other.category == category;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, category.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin IsCategoryTaxableRef on AutoDisposeProviderRef<bool> {
  /// The parameter `category` of this provider.
  String get category;
}

class _IsCategoryTaxableProviderElement extends AutoDisposeProviderElement<bool>
    with IsCategoryTaxableRef {
  _IsCategoryTaxableProviderElement(super.provider);

  @override
  String get category => (origin as IsCategoryTaxableProvider).category;
}

String _$taxCategoryForHash() => r'a7af0e737ef5156e26cf1fc3932b5a100e6a56e8';

/// See also [taxCategoryFor].
@ProviderFor(taxCategoryFor)
const taxCategoryForProvider = TaxCategoryForFamily();

/// See also [taxCategoryFor].
class TaxCategoryForFamily extends Family<TaxCategory> {
  /// See also [taxCategoryFor].
  const TaxCategoryForFamily();

  /// See also [taxCategoryFor].
  TaxCategoryForProvider call(String productCategory) {
    return TaxCategoryForProvider(productCategory);
  }

  @override
  TaxCategoryForProvider getProviderOverride(
    covariant TaxCategoryForProvider provider,
  ) {
    return call(provider.productCategory);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'taxCategoryForProvider';
}

/// See also [taxCategoryFor].
class TaxCategoryForProvider extends AutoDisposeProvider<TaxCategory> {
  /// See also [taxCategoryFor].
  TaxCategoryForProvider(String productCategory)
    : this._internal(
        (ref) => taxCategoryFor(ref as TaxCategoryForRef, productCategory),
        from: taxCategoryForProvider,
        name: r'taxCategoryForProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$taxCategoryForHash,
        dependencies: TaxCategoryForFamily._dependencies,
        allTransitiveDependencies:
            TaxCategoryForFamily._allTransitiveDependencies,
        productCategory: productCategory,
      );

  TaxCategoryForProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.productCategory,
  }) : super.internal();

  final String productCategory;

  @override
  Override overrideWith(
    TaxCategory Function(TaxCategoryForRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: TaxCategoryForProvider._internal(
        (ref) => create(ref as TaxCategoryForRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        productCategory: productCategory,
      ),
    );
  }

  @override
  AutoDisposeProviderElement<TaxCategory> createElement() {
    return _TaxCategoryForProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is TaxCategoryForProvider &&
        other.productCategory == productCategory;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, productCategory.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin TaxCategoryForRef on AutoDisposeProviderRef<TaxCategory> {
  /// The parameter `productCategory` of this provider.
  String get productCategory;
}

class _TaxCategoryForProviderElement
    extends AutoDisposeProviderElement<TaxCategory>
    with TaxCategoryForRef {
  _TaxCategoryForProviderElement(super.provider);

  @override
  String get productCategory =>
      (origin as TaxCategoryForProvider).productCategory;
}

String _$currentTaxConfigHash() => r'ed50ed72e8d72c0afdb17a33ac3f829e9d92ba01';

/// See also [currentTaxConfig].
@ProviderFor(currentTaxConfig)
final currentTaxConfigProvider = AutoDisposeProvider<TaxConfig>.internal(
  currentTaxConfig,
  name: r'currentTaxConfigProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$currentTaxConfigHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CurrentTaxConfigRef = AutoDisposeProviderRef<TaxConfig>;
String _$availableTaxOptionsHash() =>
    r'174d2b43797e95b453a32322213de297e3a250f4';

/// See also [availableTaxOptions].
@ProviderFor(availableTaxOptions)
final availableTaxOptionsProvider =
    AutoDisposeProvider<List<TaxOption>>.internal(
      availableTaxOptions,
      name: r'availableTaxOptionsProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$availableTaxOptionsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AvailableTaxOptionsRef = AutoDisposeProviderRef<List<TaxOption>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
