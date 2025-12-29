// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'currency_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$currencyServiceHash() => r'c9ca76c2c00418fd79e1f52db4fad93eec87e2cf';

/// See also [currencyService].
@ProviderFor(currencyService)
final currencyServiceProvider = AutoDisposeProvider<CurrencyService>.internal(
  currencyService,
  name: r'currencyServiceProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$currencyServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CurrencyServiceRef = AutoDisposeProviderRef<CurrencyService>;
String _$exchangeRateForCurrencyHash() =>
    r'1e3508a2cfe03afc7842f99163613c9a90c757fa';

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

/// See also [exchangeRateForCurrency].
@ProviderFor(exchangeRateForCurrency)
const exchangeRateForCurrencyProvider = ExchangeRateForCurrencyFamily();

/// See also [exchangeRateForCurrency].
class ExchangeRateForCurrencyFamily extends Family<AsyncValue<double>> {
  /// See also [exchangeRateForCurrency].
  const ExchangeRateForCurrencyFamily();

  /// See also [exchangeRateForCurrency].
  ExchangeRateForCurrencyProvider call(
    Currency fromCurrency,
    Currency toCurrency,
  ) {
    return ExchangeRateForCurrencyProvider(fromCurrency, toCurrency);
  }

  @override
  ExchangeRateForCurrencyProvider getProviderOverride(
    covariant ExchangeRateForCurrencyProvider provider,
  ) {
    return call(provider.fromCurrency, provider.toCurrency);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'exchangeRateForCurrencyProvider';
}

/// See also [exchangeRateForCurrency].
class ExchangeRateForCurrencyProvider
    extends AutoDisposeFutureProvider<double> {
  /// See also [exchangeRateForCurrency].
  ExchangeRateForCurrencyProvider(Currency fromCurrency, Currency toCurrency)
    : this._internal(
        (ref) => exchangeRateForCurrency(
          ref as ExchangeRateForCurrencyRef,
          fromCurrency,
          toCurrency,
        ),
        from: exchangeRateForCurrencyProvider,
        name: r'exchangeRateForCurrencyProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$exchangeRateForCurrencyHash,
        dependencies: ExchangeRateForCurrencyFamily._dependencies,
        allTransitiveDependencies:
            ExchangeRateForCurrencyFamily._allTransitiveDependencies,
        fromCurrency: fromCurrency,
        toCurrency: toCurrency,
      );

  ExchangeRateForCurrencyProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.fromCurrency,
    required this.toCurrency,
  }) : super.internal();

  final Currency fromCurrency;
  final Currency toCurrency;

  @override
  Override overrideWith(
    FutureOr<double> Function(ExchangeRateForCurrencyRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ExchangeRateForCurrencyProvider._internal(
        (ref) => create(ref as ExchangeRateForCurrencyRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        fromCurrency: fromCurrency,
        toCurrency: toCurrency,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<double> createElement() {
    return _ExchangeRateForCurrencyProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ExchangeRateForCurrencyProvider &&
        other.fromCurrency == fromCurrency &&
        other.toCurrency == toCurrency;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, fromCurrency.hashCode);
    hash = _SystemHash.combine(hash, toCurrency.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ExchangeRateForCurrencyRef on AutoDisposeFutureProviderRef<double> {
  /// The parameter `fromCurrency` of this provider.
  Currency get fromCurrency;

  /// The parameter `toCurrency` of this provider.
  Currency get toCurrency;
}

class _ExchangeRateForCurrencyProviderElement
    extends AutoDisposeFutureProviderElement<double>
    with ExchangeRateForCurrencyRef {
  _ExchangeRateForCurrencyProviderElement(super.provider);

  @override
  Currency get fromCurrency =>
      (origin as ExchangeRateForCurrencyProvider).fromCurrency;
  @override
  Currency get toCurrency =>
      (origin as ExchangeRateForCurrencyProvider).toCurrency;
}

String _$allExchangeRatesHash() => r'162d46c91e2f5dc79c466745bcbbc04a47111640';

/// See also [allExchangeRates].
@ProviderFor(allExchangeRates)
const allExchangeRatesProvider = AllExchangeRatesFamily();

/// See also [allExchangeRates].
class AllExchangeRatesFamily extends Family<AsyncValue<Map<String, double>>> {
  /// See also [allExchangeRates].
  const AllExchangeRatesFamily();

  /// See also [allExchangeRates].
  AllExchangeRatesProvider call(Currency base) {
    return AllExchangeRatesProvider(base);
  }

  @override
  AllExchangeRatesProvider getProviderOverride(
    covariant AllExchangeRatesProvider provider,
  ) {
    return call(provider.base);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'allExchangeRatesProvider';
}

/// See also [allExchangeRates].
class AllExchangeRatesProvider
    extends AutoDisposeFutureProvider<Map<String, double>> {
  /// See also [allExchangeRates].
  AllExchangeRatesProvider(Currency base)
    : this._internal(
        (ref) => allExchangeRates(ref as AllExchangeRatesRef, base),
        from: allExchangeRatesProvider,
        name: r'allExchangeRatesProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$allExchangeRatesHash,
        dependencies: AllExchangeRatesFamily._dependencies,
        allTransitiveDependencies:
            AllExchangeRatesFamily._allTransitiveDependencies,
        base: base,
      );

  AllExchangeRatesProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.base,
  }) : super.internal();

  final Currency base;

  @override
  Override overrideWith(
    FutureOr<Map<String, double>> Function(AllExchangeRatesRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: AllExchangeRatesProvider._internal(
        (ref) => create(ref as AllExchangeRatesRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        base: base,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<Map<String, double>> createElement() {
    return _AllExchangeRatesProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is AllExchangeRatesProvider && other.base == base;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, base.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin AllExchangeRatesRef on AutoDisposeFutureProviderRef<Map<String, double>> {
  /// The parameter `base` of this provider.
  Currency get base;
}

class _AllExchangeRatesProviderElement
    extends AutoDisposeFutureProviderElement<Map<String, double>>
    with AllExchangeRatesRef {
  _AllExchangeRatesProviderElement(super.provider);

  @override
  Currency get base => (origin as AllExchangeRatesProvider).base;
}

String _$convertedAmountHash() => r'990727d2fde15e3076a5992eadb0336c2352393d';

/// See also [convertedAmount].
@ProviderFor(convertedAmount)
const convertedAmountProvider = ConvertedAmountFamily();

/// See also [convertedAmount].
class ConvertedAmountFamily extends Family<String> {
  /// See also [convertedAmount].
  const ConvertedAmountFamily();

  /// See also [convertedAmount].
  ConvertedAmountProvider call(
    double amount,
    Currency fromCurrency,
    Currency toCurrency,
  ) {
    return ConvertedAmountProvider(amount, fromCurrency, toCurrency);
  }

  @override
  ConvertedAmountProvider getProviderOverride(
    covariant ConvertedAmountProvider provider,
  ) {
    return call(provider.amount, provider.fromCurrency, provider.toCurrency);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'convertedAmountProvider';
}

/// See also [convertedAmount].
class ConvertedAmountProvider extends AutoDisposeProvider<String> {
  /// See also [convertedAmount].
  ConvertedAmountProvider(
    double amount,
    Currency fromCurrency,
    Currency toCurrency,
  ) : this._internal(
        (ref) => convertedAmount(
          ref as ConvertedAmountRef,
          amount,
          fromCurrency,
          toCurrency,
        ),
        from: convertedAmountProvider,
        name: r'convertedAmountProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$convertedAmountHash,
        dependencies: ConvertedAmountFamily._dependencies,
        allTransitiveDependencies:
            ConvertedAmountFamily._allTransitiveDependencies,
        amount: amount,
        fromCurrency: fromCurrency,
        toCurrency: toCurrency,
      );

  ConvertedAmountProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.amount,
    required this.fromCurrency,
    required this.toCurrency,
  }) : super.internal();

  final double amount;
  final Currency fromCurrency;
  final Currency toCurrency;

  @override
  Override overrideWith(String Function(ConvertedAmountRef provider) create) {
    return ProviderOverride(
      origin: this,
      override: ConvertedAmountProvider._internal(
        (ref) => create(ref as ConvertedAmountRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        amount: amount,
        fromCurrency: fromCurrency,
        toCurrency: toCurrency,
      ),
    );
  }

  @override
  AutoDisposeProviderElement<String> createElement() {
    return _ConvertedAmountProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ConvertedAmountProvider &&
        other.amount == amount &&
        other.fromCurrency == fromCurrency &&
        other.toCurrency == toCurrency;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, amount.hashCode);
    hash = _SystemHash.combine(hash, fromCurrency.hashCode);
    hash = _SystemHash.combine(hash, toCurrency.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ConvertedAmountRef on AutoDisposeProviderRef<String> {
  /// The parameter `amount` of this provider.
  double get amount;

  /// The parameter `fromCurrency` of this provider.
  Currency get fromCurrency;

  /// The parameter `toCurrency` of this provider.
  Currency get toCurrency;
}

class _ConvertedAmountProviderElement extends AutoDisposeProviderElement<String>
    with ConvertedAmountRef {
  _ConvertedAmountProviderElement(super.provider);

  @override
  double get amount => (origin as ConvertedAmountProvider).amount;
  @override
  Currency get fromCurrency => (origin as ConvertedAmountProvider).fromCurrency;
  @override
  Currency get toCurrency => (origin as ConvertedAmountProvider).toCurrency;
}

String _$formattedAmountHash() => r'fc641ac56c18a59cdabdb1dd3c75682a4e269829';

/// See also [formattedAmount].
@ProviderFor(formattedAmount)
const formattedAmountProvider = FormattedAmountFamily();

/// See also [formattedAmount].
class FormattedAmountFamily extends Family<String> {
  /// See also [formattedAmount].
  const FormattedAmountFamily();

  /// See also [formattedAmount].
  FormattedAmountProvider call(double amount, Currency currency) {
    return FormattedAmountProvider(amount, currency);
  }

  @override
  FormattedAmountProvider getProviderOverride(
    covariant FormattedAmountProvider provider,
  ) {
    return call(provider.amount, provider.currency);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'formattedAmountProvider';
}

/// See also [formattedAmount].
class FormattedAmountProvider extends AutoDisposeProvider<String> {
  /// See also [formattedAmount].
  FormattedAmountProvider(double amount, Currency currency)
    : this._internal(
        (ref) => formattedAmount(ref as FormattedAmountRef, amount, currency),
        from: formattedAmountProvider,
        name: r'formattedAmountProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$formattedAmountHash,
        dependencies: FormattedAmountFamily._dependencies,
        allTransitiveDependencies:
            FormattedAmountFamily._allTransitiveDependencies,
        amount: amount,
        currency: currency,
      );

  FormattedAmountProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.amount,
    required this.currency,
  }) : super.internal();

  final double amount;
  final Currency currency;

  @override
  Override overrideWith(String Function(FormattedAmountRef provider) create) {
    return ProviderOverride(
      origin: this,
      override: FormattedAmountProvider._internal(
        (ref) => create(ref as FormattedAmountRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        amount: amount,
        currency: currency,
      ),
    );
  }

  @override
  AutoDisposeProviderElement<String> createElement() {
    return _FormattedAmountProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is FormattedAmountProvider &&
        other.amount == amount &&
        other.currency == currency;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, amount.hashCode);
    hash = _SystemHash.combine(hash, currency.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin FormattedAmountRef on AutoDisposeProviderRef<String> {
  /// The parameter `amount` of this provider.
  double get amount;

  /// The parameter `currency` of this provider.
  Currency get currency;
}

class _FormattedAmountProviderElement extends AutoDisposeProviderElement<String>
    with FormattedAmountRef {
  _FormattedAmountProviderElement(super.provider);

  @override
  double get amount => (origin as FormattedAmountProvider).amount;
  @override
  Currency get currency => (origin as FormattedAmountProvider).currency;
}

String _$availableCurrenciesHash() =>
    r'15b0e5b2c21cee7ac0804a50ce0a4fd3e0c56c0b';

/// See also [availableCurrencies].
@ProviderFor(availableCurrencies)
final availableCurrenciesProvider =
    AutoDisposeProvider<List<Currency>>.internal(
      availableCurrencies,
      name: r'availableCurrenciesProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$availableCurrenciesHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AvailableCurrenciesRef = AutoDisposeProviderRef<List<Currency>>;
String _$userCurrencyPreferenceHash() =>
    r'9a4a883f7732e8a93a70a0258182953302cb5dc5';

/// See also [UserCurrencyPreference].
@ProviderFor(UserCurrencyPreference)
final userCurrencyPreferenceProvider =
    AutoDisposeAsyncNotifierProvider<UserCurrencyPreference, Currency>.internal(
      UserCurrencyPreference.new,
      name: r'userCurrencyPreferenceProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$userCurrencyPreferenceHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$UserCurrencyPreference = AutoDisposeAsyncNotifier<Currency>;
String _$selectedDisplayCurrencyHash() =>
    r'b6c4937c5c525a0f4d07a6e2b52c5b2cf0dabb8c';

/// See also [SelectedDisplayCurrency].
@ProviderFor(SelectedDisplayCurrency)
final selectedDisplayCurrencyProvider =
    AutoDisposeNotifierProvider<SelectedDisplayCurrency, Currency>.internal(
      SelectedDisplayCurrency.new,
      name: r'selectedDisplayCurrencyProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$selectedDisplayCurrencyHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$SelectedDisplayCurrency = AutoDisposeNotifier<Currency>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
