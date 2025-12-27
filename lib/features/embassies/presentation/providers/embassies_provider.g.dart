// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'embassies_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$embassiesLocalDataSourceHash() =>
    r'9a3aba067b43a20759913f861266b8e16e8cd408';

/// See also [embassiesLocalDataSource].
@ProviderFor(embassiesLocalDataSource)
final embassiesLocalDataSourceProvider =
    AutoDisposeProvider<EmbassiesLocalDataSource>.internal(
      embassiesLocalDataSource,
      name: r'embassiesLocalDataSourceProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$embassiesLocalDataSourceHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef EmbassiesLocalDataSourceRef =
    AutoDisposeProviderRef<EmbassiesLocalDataSource>;
String _$embassiesRepositoryHash() =>
    r'bf405587754a28dd48bf3e876555664c2b3f9f0b';

/// See also [embassiesRepository].
@ProviderFor(embassiesRepository)
final embassiesRepositoryProvider =
    AutoDisposeProvider<EmbassiesRepository>.internal(
      embassiesRepository,
      name: r'embassiesRepositoryProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$embassiesRepositoryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef EmbassiesRepositoryRef = AutoDisposeProviderRef<EmbassiesRepository>;
String _$embassiesListHash() => r'4453f9532e0a2ca93936dfbe48989547f6267831';

/// See also [embassiesList].
@ProviderFor(embassiesList)
final embassiesListProvider = FutureProvider<List<EmbassyEntity>>.internal(
  embassiesList,
  name: r'embassiesListProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$embassiesListHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef EmbassiesListRef = FutureProviderRef<List<EmbassyEntity>>;
String _$embassiesControllerHash() =>
    r'89a63acfdbe13a87de11dfba37b0ac8737bcc3e1';

/// See also [EmbassiesController].
@ProviderFor(EmbassiesController)
final embassiesControllerProvider =
    AutoDisposeNotifierProvider<EmbassiesController, EmbassiesState>.internal(
      EmbassiesController.new,
      name: r'embassiesControllerProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$embassiesControllerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$EmbassiesController = AutoDisposeNotifier<EmbassiesState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
