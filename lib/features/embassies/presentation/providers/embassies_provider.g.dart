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
String _$embassiesDataSourceHash() =>
    r'9dee78cccf89a7e7c4988a84713b7eb47406fcc2';

/// See also [embassiesDataSource].
@ProviderFor(embassiesDataSource)
final embassiesDataSourceProvider =
    AutoDisposeProvider<EmbassiesDataSource>.internal(
      embassiesDataSource,
      name: r'embassiesDataSourceProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$embassiesDataSourceHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef EmbassiesDataSourceRef = AutoDisposeProviderRef<EmbassiesDataSource>;
String _$embassiesRepositoryHash() =>
    r'293acd98a49a19253b81026f427515e228877816';

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
String _$embassiesCachedAtHash() => r'224c63f6220844b10b8f143afaacdf120aa72dcf';

/// Date de la copie locale servie hors ligne, pour que l'écran puisse dire
/// « données du 3 septembre » plutôt que de les présenter comme courantes.
///
/// Copied from [embassiesCachedAt].
@ProviderFor(embassiesCachedAt)
final embassiesCachedAtProvider = AutoDisposeFutureProvider<DateTime?>.internal(
  embassiesCachedAt,
  name: r'embassiesCachedAtProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$embassiesCachedAtHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef EmbassiesCachedAtRef = AutoDisposeFutureProviderRef<DateTime?>;
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
