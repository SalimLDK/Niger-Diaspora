// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transfer_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$transferRemoteDatasourceHash() =>
    r'a3290633223b8a2e9836921bfffdd05cdfc2a168';

/// See also [transferRemoteDatasource].
@ProviderFor(transferRemoteDatasource)
final transferRemoteDatasourceProvider =
    AutoDisposeProvider<TransferRemoteDatasource>.internal(
      transferRemoteDatasource,
      name: r'transferRemoteDatasourceProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$transferRemoteDatasourceHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef TransferRemoteDatasourceRef =
    AutoDisposeProviderRef<TransferRemoteDatasource>;
String _$transferRepositoryHash() =>
    r'a4be3c2185d5645d867f1dde2e6910aa76a1d7c8';

/// See also [transferRepository].
@ProviderFor(transferRepository)
final transferRepositoryProvider =
    AutoDisposeProvider<TransferRepository>.internal(
      transferRepository,
      name: r'transferRepositoryProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$transferRepositoryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef TransferRepositoryRef = AutoDisposeProviderRef<TransferRepository>;
String _$transferFeePercentHash() =>
    r'bdfd3db8139646535afac2657927f57fdb27d179';

/// Provider to get the current fee percentage for display
///
/// Copied from [transferFeePercent].
@ProviderFor(transferFeePercent)
final transferFeePercentProvider = AutoDisposeProvider<double>.internal(
  transferFeePercent,
  name: r'transferFeePercentProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$transferFeePercentHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef TransferFeePercentRef = AutoDisposeProviderRef<double>;
String _$userTransactionsHash() => r'b955c35484f236300982ef4b4cd4534aadb498f5';

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

/// See also [userTransactions].
@ProviderFor(userTransactions)
const userTransactionsProvider = UserTransactionsFamily();

/// See also [userTransactions].
class UserTransactionsFamily
    extends Family<AsyncValue<List<TransactionEntity>>> {
  /// See also [userTransactions].
  const UserTransactionsFamily();

  /// See also [userTransactions].
  UserTransactionsProvider call(String userId) {
    return UserTransactionsProvider(userId);
  }

  @override
  UserTransactionsProvider getProviderOverride(
    covariant UserTransactionsProvider provider,
  ) {
    return call(provider.userId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'userTransactionsProvider';
}

/// See also [userTransactions].
class UserTransactionsProvider
    extends AutoDisposeFutureProvider<List<TransactionEntity>> {
  /// See also [userTransactions].
  UserTransactionsProvider(String userId)
    : this._internal(
        (ref) => userTransactions(ref as UserTransactionsRef, userId),
        from: userTransactionsProvider,
        name: r'userTransactionsProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$userTransactionsHash,
        dependencies: UserTransactionsFamily._dependencies,
        allTransitiveDependencies:
            UserTransactionsFamily._allTransitiveDependencies,
        userId: userId,
      );

  UserTransactionsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.userId,
  }) : super.internal();

  final String userId;

  @override
  Override overrideWith(
    FutureOr<List<TransactionEntity>> Function(UserTransactionsRef provider)
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: UserTransactionsProvider._internal(
        (ref) => create(ref as UserTransactionsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        userId: userId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<TransactionEntity>> createElement() {
    return _UserTransactionsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is UserTransactionsProvider && other.userId == userId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, userId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin UserTransactionsRef
    on AutoDisposeFutureProviderRef<List<TransactionEntity>> {
  /// The parameter `userId` of this provider.
  String get userId;
}

class _UserTransactionsProviderElement
    extends AutoDisposeFutureProviderElement<List<TransactionEntity>>
    with UserTransactionsRef {
  _UserTransactionsProviderElement(super.provider);

  @override
  String get userId => (origin as UserTransactionsProvider).userId;
}

String _$watchUserTransactionsHash() =>
    r'1c714278f4a9c08656e9803c3b01e0d03d6c3e5e';

/// See also [watchUserTransactions].
@ProviderFor(watchUserTransactions)
const watchUserTransactionsProvider = WatchUserTransactionsFamily();

/// See also [watchUserTransactions].
class WatchUserTransactionsFamily
    extends Family<AsyncValue<List<TransactionEntity>>> {
  /// See also [watchUserTransactions].
  const WatchUserTransactionsFamily();

  /// See also [watchUserTransactions].
  WatchUserTransactionsProvider call(String userId) {
    return WatchUserTransactionsProvider(userId);
  }

  @override
  WatchUserTransactionsProvider getProviderOverride(
    covariant WatchUserTransactionsProvider provider,
  ) {
    return call(provider.userId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'watchUserTransactionsProvider';
}

/// See also [watchUserTransactions].
class WatchUserTransactionsProvider
    extends AutoDisposeStreamProvider<List<TransactionEntity>> {
  /// See also [watchUserTransactions].
  WatchUserTransactionsProvider(String userId)
    : this._internal(
        (ref) => watchUserTransactions(ref as WatchUserTransactionsRef, userId),
        from: watchUserTransactionsProvider,
        name: r'watchUserTransactionsProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$watchUserTransactionsHash,
        dependencies: WatchUserTransactionsFamily._dependencies,
        allTransitiveDependencies:
            WatchUserTransactionsFamily._allTransitiveDependencies,
        userId: userId,
      );

  WatchUserTransactionsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.userId,
  }) : super.internal();

  final String userId;

  @override
  Override overrideWith(
    Stream<List<TransactionEntity>> Function(WatchUserTransactionsRef provider)
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: WatchUserTransactionsProvider._internal(
        (ref) => create(ref as WatchUserTransactionsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        userId: userId,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<List<TransactionEntity>> createElement() {
    return _WatchUserTransactionsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is WatchUserTransactionsProvider && other.userId == userId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, userId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin WatchUserTransactionsRef
    on AutoDisposeStreamProviderRef<List<TransactionEntity>> {
  /// The parameter `userId` of this provider.
  String get userId;
}

class _WatchUserTransactionsProviderElement
    extends AutoDisposeStreamProviderElement<List<TransactionEntity>>
    with WatchUserTransactionsRef {
  _WatchUserTransactionsProviderElement(super.provider);

  @override
  String get userId => (origin as WatchUserTransactionsProvider).userId;
}

String _$watchTransactionHash() => r'29f2aa1a1de435206fae871eb1d962c2449292d2';

/// See also [watchTransaction].
@ProviderFor(watchTransaction)
const watchTransactionProvider = WatchTransactionFamily();

/// See also [watchTransaction].
class WatchTransactionFamily extends Family<AsyncValue<TransactionEntity>> {
  /// See also [watchTransaction].
  const WatchTransactionFamily();

  /// See also [watchTransaction].
  WatchTransactionProvider call(String transactionId) {
    return WatchTransactionProvider(transactionId);
  }

  @override
  WatchTransactionProvider getProviderOverride(
    covariant WatchTransactionProvider provider,
  ) {
    return call(provider.transactionId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'watchTransactionProvider';
}

/// See also [watchTransaction].
class WatchTransactionProvider
    extends AutoDisposeStreamProvider<TransactionEntity> {
  /// See also [watchTransaction].
  WatchTransactionProvider(String transactionId)
    : this._internal(
        (ref) => watchTransaction(ref as WatchTransactionRef, transactionId),
        from: watchTransactionProvider,
        name: r'watchTransactionProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$watchTransactionHash,
        dependencies: WatchTransactionFamily._dependencies,
        allTransitiveDependencies:
            WatchTransactionFamily._allTransitiveDependencies,
        transactionId: transactionId,
      );

  WatchTransactionProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.transactionId,
  }) : super.internal();

  final String transactionId;

  @override
  Override overrideWith(
    Stream<TransactionEntity> Function(WatchTransactionRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: WatchTransactionProvider._internal(
        (ref) => create(ref as WatchTransactionRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        transactionId: transactionId,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<TransactionEntity> createElement() {
    return _WatchTransactionProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is WatchTransactionProvider &&
        other.transactionId == transactionId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, transactionId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin WatchTransactionRef on AutoDisposeStreamProviderRef<TransactionEntity> {
  /// The parameter `transactionId` of this provider.
  String get transactionId;
}

class _WatchTransactionProviderElement
    extends AutoDisposeStreamProviderElement<TransactionEntity>
    with WatchTransactionRef {
  _WatchTransactionProviderElement(super.provider);

  @override
  String get transactionId =>
      (origin as WatchTransactionProvider).transactionId;
}

String _$userRecipientsHash() => r'a77aad88d29072b122ad649da4132c72451bc9d1';

/// See also [userRecipients].
@ProviderFor(userRecipients)
const userRecipientsProvider = UserRecipientsFamily();

/// See also [userRecipients].
class UserRecipientsFamily extends Family<AsyncValue<List<RecipientEntity>>> {
  /// See also [userRecipients].
  const UserRecipientsFamily();

  /// See also [userRecipients].
  UserRecipientsProvider call(String userId) {
    return UserRecipientsProvider(userId);
  }

  @override
  UserRecipientsProvider getProviderOverride(
    covariant UserRecipientsProvider provider,
  ) {
    return call(provider.userId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'userRecipientsProvider';
}

/// See also [userRecipients].
class UserRecipientsProvider
    extends AutoDisposeFutureProvider<List<RecipientEntity>> {
  /// See also [userRecipients].
  UserRecipientsProvider(String userId)
    : this._internal(
        (ref) => userRecipients(ref as UserRecipientsRef, userId),
        from: userRecipientsProvider,
        name: r'userRecipientsProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$userRecipientsHash,
        dependencies: UserRecipientsFamily._dependencies,
        allTransitiveDependencies:
            UserRecipientsFamily._allTransitiveDependencies,
        userId: userId,
      );

  UserRecipientsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.userId,
  }) : super.internal();

  final String userId;

  @override
  Override overrideWith(
    FutureOr<List<RecipientEntity>> Function(UserRecipientsRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: UserRecipientsProvider._internal(
        (ref) => create(ref as UserRecipientsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        userId: userId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<RecipientEntity>> createElement() {
    return _UserRecipientsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is UserRecipientsProvider && other.userId == userId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, userId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin UserRecipientsRef on AutoDisposeFutureProviderRef<List<RecipientEntity>> {
  /// The parameter `userId` of this provider.
  String get userId;
}

class _UserRecipientsProviderElement
    extends AutoDisposeFutureProviderElement<List<RecipientEntity>>
    with UserRecipientsRef {
  _UserRecipientsProviderElement(super.provider);

  @override
  String get userId => (origin as UserRecipientsProvider).userId;
}

String _$watchUserRecipientsHash() =>
    r'5fe17edcadacc29f32f671d6bdd3158de085d12d';

/// See also [watchUserRecipients].
@ProviderFor(watchUserRecipients)
const watchUserRecipientsProvider = WatchUserRecipientsFamily();

/// See also [watchUserRecipients].
class WatchUserRecipientsFamily
    extends Family<AsyncValue<List<RecipientEntity>>> {
  /// See also [watchUserRecipients].
  const WatchUserRecipientsFamily();

  /// See also [watchUserRecipients].
  WatchUserRecipientsProvider call(String userId) {
    return WatchUserRecipientsProvider(userId);
  }

  @override
  WatchUserRecipientsProvider getProviderOverride(
    covariant WatchUserRecipientsProvider provider,
  ) {
    return call(provider.userId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'watchUserRecipientsProvider';
}

/// See also [watchUserRecipients].
class WatchUserRecipientsProvider
    extends AutoDisposeStreamProvider<List<RecipientEntity>> {
  /// See also [watchUserRecipients].
  WatchUserRecipientsProvider(String userId)
    : this._internal(
        (ref) => watchUserRecipients(ref as WatchUserRecipientsRef, userId),
        from: watchUserRecipientsProvider,
        name: r'watchUserRecipientsProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$watchUserRecipientsHash,
        dependencies: WatchUserRecipientsFamily._dependencies,
        allTransitiveDependencies:
            WatchUserRecipientsFamily._allTransitiveDependencies,
        userId: userId,
      );

  WatchUserRecipientsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.userId,
  }) : super.internal();

  final String userId;

  @override
  Override overrideWith(
    Stream<List<RecipientEntity>> Function(WatchUserRecipientsRef provider)
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: WatchUserRecipientsProvider._internal(
        (ref) => create(ref as WatchUserRecipientsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        userId: userId,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<List<RecipientEntity>> createElement() {
    return _WatchUserRecipientsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is WatchUserRecipientsProvider && other.userId == userId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, userId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin WatchUserRecipientsRef
    on AutoDisposeStreamProviderRef<List<RecipientEntity>> {
  /// The parameter `userId` of this provider.
  String get userId;
}

class _WatchUserRecipientsProviderElement
    extends AutoDisposeStreamProviderElement<List<RecipientEntity>>
    with WatchUserRecipientsRef {
  _WatchUserRecipientsProviderElement(super.provider);

  @override
  String get userId => (origin as WatchUserRecipientsProvider).userId;
}

String _$exchangeRateHash() => r'7a2c24f356cd14e7a8c55b5f7a0c2e4d6ef460b1';

/// See also [exchangeRate].
@ProviderFor(exchangeRate)
const exchangeRateProvider = ExchangeRateFamily();

/// See also [exchangeRate].
class ExchangeRateFamily extends Family<AsyncValue<double>> {
  /// See also [exchangeRate].
  const ExchangeRateFamily();

  /// See also [exchangeRate].
  ExchangeRateProvider call(String fromCurrency, String toCurrency) {
    return ExchangeRateProvider(fromCurrency, toCurrency);
  }

  @override
  ExchangeRateProvider getProviderOverride(
    covariant ExchangeRateProvider provider,
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
  String? get name => r'exchangeRateProvider';
}

/// See also [exchangeRate].
class ExchangeRateProvider extends AutoDisposeFutureProvider<double> {
  /// See also [exchangeRate].
  ExchangeRateProvider(String fromCurrency, String toCurrency)
    : this._internal(
        (ref) => exchangeRate(ref as ExchangeRateRef, fromCurrency, toCurrency),
        from: exchangeRateProvider,
        name: r'exchangeRateProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$exchangeRateHash,
        dependencies: ExchangeRateFamily._dependencies,
        allTransitiveDependencies:
            ExchangeRateFamily._allTransitiveDependencies,
        fromCurrency: fromCurrency,
        toCurrency: toCurrency,
      );

  ExchangeRateProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.fromCurrency,
    required this.toCurrency,
  }) : super.internal();

  final String fromCurrency;
  final String toCurrency;

  @override
  Override overrideWith(
    FutureOr<double> Function(ExchangeRateRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ExchangeRateProvider._internal(
        (ref) => create(ref as ExchangeRateRef),
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
    return _ExchangeRateProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ExchangeRateProvider &&
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
mixin ExchangeRateRef on AutoDisposeFutureProviderRef<double> {
  /// The parameter `fromCurrency` of this provider.
  String get fromCurrency;

  /// The parameter `toCurrency` of this provider.
  String get toCurrency;
}

class _ExchangeRateProviderElement
    extends AutoDisposeFutureProviderElement<double>
    with ExchangeRateRef {
  _ExchangeRateProviderElement(super.provider);

  @override
  String get fromCurrency => (origin as ExchangeRateProvider).fromCurrency;
  @override
  String get toCurrency => (origin as ExchangeRateProvider).toCurrency;
}

String _$transferFeeHash() => r'b14cde0841cc459d95063a35ef0bb8c96dc6aa73';

/// See also [transferFee].
@ProviderFor(transferFee)
const transferFeeProvider = TransferFeeFamily();

/// See also [transferFee].
class TransferFeeFamily extends Family<AsyncValue<double>> {
  /// See also [transferFee].
  const TransferFeeFamily();

  /// See also [transferFee].
  TransferFeeProvider call(double amount, String currency) {
    return TransferFeeProvider(amount, currency);
  }

  @override
  TransferFeeProvider getProviderOverride(
    covariant TransferFeeProvider provider,
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
  String? get name => r'transferFeeProvider';
}

/// See also [transferFee].
class TransferFeeProvider extends AutoDisposeFutureProvider<double> {
  /// See also [transferFee].
  TransferFeeProvider(double amount, String currency)
    : this._internal(
        (ref) => transferFee(ref as TransferFeeRef, amount, currency),
        from: transferFeeProvider,
        name: r'transferFeeProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$transferFeeHash,
        dependencies: TransferFeeFamily._dependencies,
        allTransitiveDependencies: TransferFeeFamily._allTransitiveDependencies,
        amount: amount,
        currency: currency,
      );

  TransferFeeProvider._internal(
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
  final String currency;

  @override
  Override overrideWith(
    FutureOr<double> Function(TransferFeeRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: TransferFeeProvider._internal(
        (ref) => create(ref as TransferFeeRef),
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
  AutoDisposeFutureProviderElement<double> createElement() {
    return _TransferFeeProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is TransferFeeProvider &&
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
mixin TransferFeeRef on AutoDisposeFutureProviderRef<double> {
  /// The parameter `amount` of this provider.
  double get amount;

  /// The parameter `currency` of this provider.
  String get currency;
}

class _TransferFeeProviderElement
    extends AutoDisposeFutureProviderElement<double>
    with TransferFeeRef {
  _TransferFeeProviderElement(super.provider);

  @override
  double get amount => (origin as TransferFeeProvider).amount;
  @override
  String get currency => (origin as TransferFeeProvider).currency;
}

String _$transactionNotifierHash() =>
    r'2e0b840c8a94dc46b549e3da791bb6cd67a37d6c';

/// See also [TransactionNotifier].
@ProviderFor(TransactionNotifier)
final transactionNotifierProvider =
    AutoDisposeAsyncNotifierProvider<TransactionNotifier, void>.internal(
      TransactionNotifier.new,
      name: r'transactionNotifierProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$transactionNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$TransactionNotifier = AutoDisposeAsyncNotifier<void>;
String _$recipientNotifierHash() => r'6562f4b49c7a120d351680101dab132577a44429';

/// See also [RecipientNotifier].
@ProviderFor(RecipientNotifier)
final recipientNotifierProvider =
    AutoDisposeAsyncNotifierProvider<RecipientNotifier, void>.internal(
      RecipientNotifier.new,
      name: r'recipientNotifierProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$recipientNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$RecipientNotifier = AutoDisposeAsyncNotifier<void>;
String _$selectedCurrencyHash() => r'1217f572ce9df6eb14cce58dbb9819c6ee6768a1';

/// See also [SelectedCurrency].
@ProviderFor(SelectedCurrency)
final selectedCurrencyProvider =
    AutoDisposeNotifierProvider<SelectedCurrency, String>.internal(
      SelectedCurrency.new,
      name: r'selectedCurrencyProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$selectedCurrencyHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$SelectedCurrency = AutoDisposeNotifier<String>;
String _$transferStateNotifierHash() =>
    r'8deebbb0ccc9e698b49e4c8c36bd7ff006aa8da3';

/// See also [TransferStateNotifier].
@ProviderFor(TransferStateNotifier)
final transferStateNotifierProvider =
    AutoDisposeNotifierProvider<TransferStateNotifier, TransferState>.internal(
      TransferStateNotifier.new,
      name: r'transferStateNotifierProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$transferStateNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$TransferStateNotifier = AutoDisposeNotifier<TransferState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
