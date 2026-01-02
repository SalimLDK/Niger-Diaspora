// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'review_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$reviewRemoteDataSourceHash() =>
    r'10d2a514306011f8e382cbba9ff63c0f3e675709';

/// See also [reviewRemoteDataSource].
@ProviderFor(reviewRemoteDataSource)
final reviewRemoteDataSourceProvider =
    AutoDisposeProvider<ReviewRemoteDataSource>.internal(
      reviewRemoteDataSource,
      name: r'reviewRemoteDataSourceProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$reviewRemoteDataSourceHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ReviewRemoteDataSourceRef =
    AutoDisposeProviderRef<ReviewRemoteDataSource>;
String _$reviewRepositoryHash() => r'4178a7450d650a6b6446ecbbcb07fe404e7cc1c9';

/// See also [reviewRepository].
@ProviderFor(reviewRepository)
final reviewRepositoryProvider = AutoDisposeProvider<ReviewRepository>.internal(
  reviewRepository,
  name: r'reviewRepositoryProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$reviewRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ReviewRepositoryRef = AutoDisposeProviderRef<ReviewRepository>;
String _$businessReviewsNotifierHash() =>
    r'9f5a02940dbd4560cb6662c4be8477a3db1f62a5';

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

abstract class _$BusinessReviewsNotifier
    extends BuildlessAutoDisposeNotifier<AsyncValue<List<ReviewEntity>>> {
  late final String businessId;

  AsyncValue<List<ReviewEntity>> build(String businessId);
}

/// See also [BusinessReviewsNotifier].
@ProviderFor(BusinessReviewsNotifier)
const businessReviewsNotifierProvider = BusinessReviewsNotifierFamily();

/// See also [BusinessReviewsNotifier].
class BusinessReviewsNotifierFamily
    extends Family<AsyncValue<List<ReviewEntity>>> {
  /// See also [BusinessReviewsNotifier].
  const BusinessReviewsNotifierFamily();

  /// See also [BusinessReviewsNotifier].
  BusinessReviewsNotifierProvider call(String businessId) {
    return BusinessReviewsNotifierProvider(businessId);
  }

  @override
  BusinessReviewsNotifierProvider getProviderOverride(
    covariant BusinessReviewsNotifierProvider provider,
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
  String? get name => r'businessReviewsNotifierProvider';
}

/// See also [BusinessReviewsNotifier].
class BusinessReviewsNotifierProvider
    extends
        AutoDisposeNotifierProviderImpl<
          BusinessReviewsNotifier,
          AsyncValue<List<ReviewEntity>>
        > {
  /// See also [BusinessReviewsNotifier].
  BusinessReviewsNotifierProvider(String businessId)
    : this._internal(
        () => BusinessReviewsNotifier()..businessId = businessId,
        from: businessReviewsNotifierProvider,
        name: r'businessReviewsNotifierProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$businessReviewsNotifierHash,
        dependencies: BusinessReviewsNotifierFamily._dependencies,
        allTransitiveDependencies:
            BusinessReviewsNotifierFamily._allTransitiveDependencies,
        businessId: businessId,
      );

  BusinessReviewsNotifierProvider._internal(
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
  AsyncValue<List<ReviewEntity>> runNotifierBuild(
    covariant BusinessReviewsNotifier notifier,
  ) {
    return notifier.build(businessId);
  }

  @override
  Override overrideWith(BusinessReviewsNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: BusinessReviewsNotifierProvider._internal(
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
    BusinessReviewsNotifier,
    AsyncValue<List<ReviewEntity>>
  >
  createElement() {
    return _BusinessReviewsNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is BusinessReviewsNotifierProvider &&
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
mixin BusinessReviewsNotifierRef
    on AutoDisposeNotifierProviderRef<AsyncValue<List<ReviewEntity>>> {
  /// The parameter `businessId` of this provider.
  String get businessId;
}

class _BusinessReviewsNotifierProviderElement
    extends
        AutoDisposeNotifierProviderElement<
          BusinessReviewsNotifier,
          AsyncValue<List<ReviewEntity>>
        >
    with BusinessReviewsNotifierRef {
  _BusinessReviewsNotifierProviderElement(super.provider);

  @override
  String get businessId =>
      (origin as BusinessReviewsNotifierProvider).businessId;
}

String _$userBusinessReviewNotifierHash() =>
    r'e04ad83a6428b7e660e069bea0c84bdfc599b092';

abstract class _$UserBusinessReviewNotifier
    extends BuildlessAutoDisposeNotifier<AsyncValue<ReviewEntity?>> {
  late final String businessId;

  AsyncValue<ReviewEntity?> build(String businessId);
}

/// See also [UserBusinessReviewNotifier].
@ProviderFor(UserBusinessReviewNotifier)
const userBusinessReviewNotifierProvider = UserBusinessReviewNotifierFamily();

/// See also [UserBusinessReviewNotifier].
class UserBusinessReviewNotifierFamily
    extends Family<AsyncValue<ReviewEntity?>> {
  /// See also [UserBusinessReviewNotifier].
  const UserBusinessReviewNotifierFamily();

  /// See also [UserBusinessReviewNotifier].
  UserBusinessReviewNotifierProvider call(String businessId) {
    return UserBusinessReviewNotifierProvider(businessId);
  }

  @override
  UserBusinessReviewNotifierProvider getProviderOverride(
    covariant UserBusinessReviewNotifierProvider provider,
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
  String? get name => r'userBusinessReviewNotifierProvider';
}

/// See also [UserBusinessReviewNotifier].
class UserBusinessReviewNotifierProvider
    extends
        AutoDisposeNotifierProviderImpl<
          UserBusinessReviewNotifier,
          AsyncValue<ReviewEntity?>
        > {
  /// See also [UserBusinessReviewNotifier].
  UserBusinessReviewNotifierProvider(String businessId)
    : this._internal(
        () => UserBusinessReviewNotifier()..businessId = businessId,
        from: userBusinessReviewNotifierProvider,
        name: r'userBusinessReviewNotifierProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$userBusinessReviewNotifierHash,
        dependencies: UserBusinessReviewNotifierFamily._dependencies,
        allTransitiveDependencies:
            UserBusinessReviewNotifierFamily._allTransitiveDependencies,
        businessId: businessId,
      );

  UserBusinessReviewNotifierProvider._internal(
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
  AsyncValue<ReviewEntity?> runNotifierBuild(
    covariant UserBusinessReviewNotifier notifier,
  ) {
    return notifier.build(businessId);
  }

  @override
  Override overrideWith(UserBusinessReviewNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: UserBusinessReviewNotifierProvider._internal(
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
    UserBusinessReviewNotifier,
    AsyncValue<ReviewEntity?>
  >
  createElement() {
    return _UserBusinessReviewNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is UserBusinessReviewNotifierProvider &&
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
mixin UserBusinessReviewNotifierRef
    on AutoDisposeNotifierProviderRef<AsyncValue<ReviewEntity?>> {
  /// The parameter `businessId` of this provider.
  String get businessId;
}

class _UserBusinessReviewNotifierProviderElement
    extends
        AutoDisposeNotifierProviderElement<
          UserBusinessReviewNotifier,
          AsyncValue<ReviewEntity?>
        >
    with UserBusinessReviewNotifierRef {
  _UserBusinessReviewNotifierProviderElement(super.provider);

  @override
  String get businessId =>
      (origin as UserBusinessReviewNotifierProvider).businessId;
}

String _$userReviewsNotifierHash() =>
    r'ce67488ac00a0c440912c6c5082f036595fa296b';

/// See also [UserReviewsNotifier].
@ProviderFor(UserReviewsNotifier)
final userReviewsNotifierProvider = AutoDisposeNotifierProvider<
  UserReviewsNotifier,
  AsyncValue<List<ReviewEntity>>
>.internal(
  UserReviewsNotifier.new,
  name: r'userReviewsNotifierProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$userReviewsNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$UserReviewsNotifier =
    AutoDisposeNotifier<AsyncValue<List<ReviewEntity>>>;
String _$reviewActionsNotifierHash() =>
    r'7de76994a59188e1e3ebb3fec3db11b015497cd4';

/// See also [ReviewActionsNotifier].
@ProviderFor(ReviewActionsNotifier)
final reviewActionsNotifierProvider =
    AutoDisposeAsyncNotifierProvider<ReviewActionsNotifier, void>.internal(
      ReviewActionsNotifier.new,
      name: r'reviewActionsNotifierProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$reviewActionsNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ReviewActionsNotifier = AutoDisposeAsyncNotifier<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
