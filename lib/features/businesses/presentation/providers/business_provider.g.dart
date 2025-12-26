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
    r'555ae9b86a06aee2019292446451281e179b058d';

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
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
