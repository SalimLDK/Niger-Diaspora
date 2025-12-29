// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'business_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$businessRemoteDataSourceHash() =>
    r'91ca72bc6e85815eb669c5ad82dcd9b36d033361';

/// See also [businessRemoteDataSource].
@ProviderFor(businessRemoteDataSource)
final businessRemoteDataSourceProvider =
    AutoDisposeProvider<BusinessRemoteDataSource>.internal(
      businessRemoteDataSource,
      name: r'businessRemoteDataSourceProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$businessRemoteDataSourceHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef BusinessRemoteDataSourceRef =
    AutoDisposeProviderRef<BusinessRemoteDataSource>;
String _$businessRepositoryHash() =>
    r'5f7c2e49892a371690d48ae5e921051cd1b79ab5';

/// See also [businessRepository].
@ProviderFor(businessRepository)
final businessRepositoryProvider =
    AutoDisposeProvider<BusinessRepository>.internal(
      businessRepository,
      name: r'businessRepositoryProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$businessRepositoryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef BusinessRepositoryRef = AutoDisposeProviderRef<BusinessRepository>;
String _$businessesNotifierHash() =>
    r'6fdd24bc9b9ade3af28ee006c34c8f44742cc56a';

/// See also [BusinessesNotifier].
@ProviderFor(BusinessesNotifier)
final businessesNotifierProvider = NotifierProvider<
  BusinessesNotifier,
  AsyncValue<List<BusinessEntity>>
>.internal(
  BusinessesNotifier.new,
  name: r'businessesNotifierProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$businessesNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$BusinessesNotifier = Notifier<AsyncValue<List<BusinessEntity>>>;
String _$businessDetailNotifierHash() =>
    r'e7088c768be177abe263bc2712b56622229d4c7e';

/// See also [BusinessDetailNotifier].
@ProviderFor(BusinessDetailNotifier)
final businessDetailNotifierProvider = AutoDisposeNotifierProvider<
  BusinessDetailNotifier,
  AsyncValue<BusinessEntity?>
>.internal(
  BusinessDetailNotifier.new,
  name: r'businessDetailNotifierProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$businessDetailNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$BusinessDetailNotifier =
    AutoDisposeNotifier<AsyncValue<BusinessEntity?>>;
String _$myBusinessNotifierHash() =>
    r'cd81b8ead4a625e163e278d7ab22b1feee5e537d';

/// See also [MyBusinessNotifier].
@ProviderFor(MyBusinessNotifier)
final myBusinessNotifierProvider =
    NotifierProvider<MyBusinessNotifier, AsyncValue<BusinessEntity?>>.internal(
      MyBusinessNotifier.new,
      name: r'myBusinessNotifierProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$myBusinessNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$MyBusinessNotifier = Notifier<AsyncValue<BusinessEntity?>>;
String _$boostNotifierHash() => r'3a979e11b75e116490be662f3eb94abbb40c7a5c';

/// See also [BoostNotifier].
@ProviderFor(BoostNotifier)
final boostNotifierProvider = AutoDisposeNotifierProvider<
  BoostNotifier,
  AsyncValue<BusinessBoostEntity?>
>.internal(
  BoostNotifier.new,
  name: r'boostNotifierProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$boostNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$BoostNotifier = AutoDisposeNotifier<AsyncValue<BusinessBoostEntity?>>;
String _$boostHistoryNotifierHash() =>
    r'db49664968a078a612952b90bddad7cf25b0ef5f';

/// See also [BoostHistoryNotifier].
@ProviderFor(BoostHistoryNotifier)
final boostHistoryNotifierProvider = AutoDisposeNotifierProvider<
  BoostHistoryNotifier,
  AsyncValue<List<BusinessBoostEntity>>
>.internal(
  BoostHistoryNotifier.new,
  name: r'boostHistoryNotifierProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$boostHistoryNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$BoostHistoryNotifier =
    AutoDisposeNotifier<AsyncValue<List<BusinessBoostEntity>>>;
String _$selectedBusinessCategoryHash() =>
    r'9e3cd4345ba5fd86c803b43c53624bbd7c14b68a';

/// See also [SelectedBusinessCategory].
@ProviderFor(SelectedBusinessCategory)
final selectedBusinessCategoryProvider = AutoDisposeNotifierProvider<
  SelectedBusinessCategory,
  BusinessCategory?
>.internal(
  SelectedBusinessCategory.new,
  name: r'selectedBusinessCategoryProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$selectedBusinessCategoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$SelectedBusinessCategory = AutoDisposeNotifier<BusinessCategory?>;
String _$selectedBusinessLocationHash() =>
    r'35ebe9bfbd6aa787060f0b8ec56d6df5faf5ac8f';

/// See also [SelectedBusinessLocation].
@ProviderFor(SelectedBusinessLocation)
final selectedBusinessLocationProvider =
    NotifierProvider<SelectedBusinessLocation, BusinessLocationFilter>.internal(
      SelectedBusinessLocation.new,
      name: r'selectedBusinessLocationProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$selectedBusinessLocationHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$SelectedBusinessLocation = Notifier<BusinessLocationFilter>;
String _$businessPostsNotifierHash() =>
    r'bc64ff10828a215d58ebe61a56e934e5948990b7';

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

abstract class _$BusinessPostsNotifier
    extends BuildlessAutoDisposeNotifier<AsyncValue<List<BusinessPostEntity>>> {
  late final String businessId;

  AsyncValue<List<BusinessPostEntity>> build(String businessId);
}

/// See also [BusinessPostsNotifier].
@ProviderFor(BusinessPostsNotifier)
const businessPostsNotifierProvider = BusinessPostsNotifierFamily();

/// See also [BusinessPostsNotifier].
class BusinessPostsNotifierFamily
    extends Family<AsyncValue<List<BusinessPostEntity>>> {
  /// See also [BusinessPostsNotifier].
  const BusinessPostsNotifierFamily();

  /// See also [BusinessPostsNotifier].
  BusinessPostsNotifierProvider call(String businessId) {
    return BusinessPostsNotifierProvider(businessId);
  }

  @override
  BusinessPostsNotifierProvider getProviderOverride(
    covariant BusinessPostsNotifierProvider provider,
  ) {
    return call(provider.businessId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'businessPostsNotifierProvider';
}

/// See also [BusinessPostsNotifier].
class BusinessPostsNotifierProvider
    extends
        AutoDisposeNotifierProviderImpl<
          BusinessPostsNotifier,
          AsyncValue<List<BusinessPostEntity>>
        > {
  /// See also [BusinessPostsNotifier].
  BusinessPostsNotifierProvider(String businessId)
    : this._internal(
        () => BusinessPostsNotifier()..businessId = businessId,
        from: businessPostsNotifierProvider,
        name: r'businessPostsNotifierProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$businessPostsNotifierHash,
        dependencies: BusinessPostsNotifierFamily._dependencies,
        allTransitiveDependencies:
            BusinessPostsNotifierFamily._allTransitiveDependencies,
        businessId: businessId,
      );

  BusinessPostsNotifierProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.businessId,
  }) : super.internal();

  final String businessId;

  @override
  AsyncValue<List<BusinessPostEntity>> runNotifierBuild(
    covariant BusinessPostsNotifier notifier,
  ) {
    return notifier.build(businessId);
  }

  @override
  Override overrideWith(BusinessPostsNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: BusinessPostsNotifierProvider._internal(
        () => create()..businessId = businessId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        businessId: businessId,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<
    BusinessPostsNotifier,
    AsyncValue<List<BusinessPostEntity>>
  >
  createElement() {
    return _BusinessPostsNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is BusinessPostsNotifierProvider &&
        other.businessId == businessId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, businessId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin BusinessPostsNotifierRef
    on AutoDisposeNotifierProviderRef<AsyncValue<List<BusinessPostEntity>>> {
  /// The parameter `businessId` of this provider.
  String get businessId;
}

class _BusinessPostsNotifierProviderElement
    extends
        AutoDisposeNotifierProviderElement<
          BusinessPostsNotifier,
          AsyncValue<List<BusinessPostEntity>>
        >
    with BusinessPostsNotifierRef {
  _BusinessPostsNotifierProviderElement(super.provider);

  @override
  String get businessId => (origin as BusinessPostsNotifierProvider).businessId;
}

String _$businessOffersNotifierHash() =>
    r'6c658dcf763ccb3ee14860058945c826d2357c6e';

abstract class _$BusinessOffersNotifier
    extends BuildlessAutoDisposeNotifier<AsyncValue<List<BusinessPostEntity>>> {
  late final String businessId;

  AsyncValue<List<BusinessPostEntity>> build(String businessId);
}

/// See also [BusinessOffersNotifier].
@ProviderFor(BusinessOffersNotifier)
const businessOffersNotifierProvider = BusinessOffersNotifierFamily();

/// See also [BusinessOffersNotifier].
class BusinessOffersNotifierFamily
    extends Family<AsyncValue<List<BusinessPostEntity>>> {
  /// See also [BusinessOffersNotifier].
  const BusinessOffersNotifierFamily();

  /// See also [BusinessOffersNotifier].
  BusinessOffersNotifierProvider call(String businessId) {
    return BusinessOffersNotifierProvider(businessId);
  }

  @override
  BusinessOffersNotifierProvider getProviderOverride(
    covariant BusinessOffersNotifierProvider provider,
  ) {
    return call(provider.businessId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'businessOffersNotifierProvider';
}

/// See also [BusinessOffersNotifier].
class BusinessOffersNotifierProvider
    extends
        AutoDisposeNotifierProviderImpl<
          BusinessOffersNotifier,
          AsyncValue<List<BusinessPostEntity>>
        > {
  /// See also [BusinessOffersNotifier].
  BusinessOffersNotifierProvider(String businessId)
    : this._internal(
        () => BusinessOffersNotifier()..businessId = businessId,
        from: businessOffersNotifierProvider,
        name: r'businessOffersNotifierProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$businessOffersNotifierHash,
        dependencies: BusinessOffersNotifierFamily._dependencies,
        allTransitiveDependencies:
            BusinessOffersNotifierFamily._allTransitiveDependencies,
        businessId: businessId,
      );

  BusinessOffersNotifierProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.businessId,
  }) : super.internal();

  final String businessId;

  @override
  AsyncValue<List<BusinessPostEntity>> runNotifierBuild(
    covariant BusinessOffersNotifier notifier,
  ) {
    return notifier.build(businessId);
  }

  @override
  Override overrideWith(BusinessOffersNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: BusinessOffersNotifierProvider._internal(
        () => create()..businessId = businessId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        businessId: businessId,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<
    BusinessOffersNotifier,
    AsyncValue<List<BusinessPostEntity>>
  >
  createElement() {
    return _BusinessOffersNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is BusinessOffersNotifierProvider &&
        other.businessId == businessId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, businessId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin BusinessOffersNotifierRef
    on AutoDisposeNotifierProviderRef<AsyncValue<List<BusinessPostEntity>>> {
  /// The parameter `businessId` of this provider.
  String get businessId;
}

class _BusinessOffersNotifierProviderElement
    extends
        AutoDisposeNotifierProviderElement<
          BusinessOffersNotifier,
          AsyncValue<List<BusinessPostEntity>>
        >
    with BusinessOffersNotifierRef {
  _BusinessOffersNotifierProviderElement(super.provider);

  @override
  String get businessId =>
      (origin as BusinessOffersNotifierProvider).businessId;
}

String _$businessPostActionsHash() =>
    r'b4b3b1f5244a4aa9faab112b5fbcdc783bd2c41c';

/// See also [BusinessPostActions].
@ProviderFor(BusinessPostActions)
final businessPostActionsProvider =
    AutoDisposeAsyncNotifierProvider<BusinessPostActions, void>.internal(
      BusinessPostActions.new,
      name: r'businessPostActionsProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$businessPostActionsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$BusinessPostActions = AutoDisposeAsyncNotifier<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
