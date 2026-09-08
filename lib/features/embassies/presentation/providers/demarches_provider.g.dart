// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'demarches_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$demarchesLocalDataSourceHash() =>
    r'497ae65dc89d5a0da905261eb85e52a2ffd161c9';

/// See also [demarchesLocalDataSource].
@ProviderFor(demarchesLocalDataSource)
final demarchesLocalDataSourceProvider =
    AutoDisposeProvider<DemarchesLocalDataSource>.internal(
      demarchesLocalDataSource,
      name: r'demarchesLocalDataSourceProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$demarchesLocalDataSourceHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef DemarchesLocalDataSourceRef =
    AutoDisposeProviderRef<DemarchesLocalDataSource>;
String _$demarchesRemoteDataSourceHash() =>
    r'3586e26a6c95c6ff0fac2c9ee4915a6b51583d7d';

/// See also [demarchesRemoteDataSource].
@ProviderFor(demarchesRemoteDataSource)
final demarchesRemoteDataSourceProvider =
    AutoDisposeProvider<DemarchesRemoteDataSource>.internal(
      demarchesRemoteDataSource,
      name: r'demarchesRemoteDataSourceProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$demarchesRemoteDataSourceHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef DemarchesRemoteDataSourceRef =
    AutoDisposeProviderRef<DemarchesRemoteDataSource>;
String _$demarchesRepositoryHash() =>
    r'5e986fcf53eaac6820c60421ddf8dcc5618ae3ed';

/// See also [demarchesRepository].
@ProviderFor(demarchesRepository)
final demarchesRepositoryProvider =
    AutoDisposeProvider<DemarchesRepositoryImpl>.internal(
      demarchesRepository,
      name: r'demarchesRepositoryProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$demarchesRepositoryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef DemarchesRepositoryRef =
    AutoDisposeProviderRef<DemarchesRepositoryImpl>;
String _$demarchesCatalogueHash() =>
    r'cc228f310434adff1c3bded95015ecacbad40901';

/// Catalogue des démarches consulaires, avec son origine.
///
/// `keepAlive` volontaire. Un `autoDispose` se recycle entre le moment où
/// l'écran est construit et le premier geste de l'utilisateur ; un
/// `read(...).valueOrNull` rend alors `null` au premier tap et le bouton
/// paraît mort, sans rien dans logcat. Le catalogue est par ailleurs un objet
/// unique et figé pour la session : le garder coûte moins que le recharger.
///
/// Copied from [demarchesCatalogue].
@ProviderFor(demarchesCatalogue)
final demarchesCatalogueProvider = FutureProvider<CatalogueCharge>.internal(
  demarchesCatalogue,
  name: r'demarchesCatalogueProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$demarchesCatalogueHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef DemarchesCatalogueRef = FutureProviderRef<CatalogueCharge>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
