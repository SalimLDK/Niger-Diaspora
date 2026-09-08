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
String _$embassiesListHash() => r'a9897985a1109e98a210efdeae69a91e0a9d9daf';

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
String _$embassyByIdHash() => r'326a4ba479ca7da152014758921fdd2c3a9af86a';

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

/// La fiche d'un poste, résolue par son identifiant seul.
///
/// Le lien profond (`diasponiger:///embassies/<id>`) et la notification
/// n'arrivent jamais avec l'entité en `state.extra` — c'est nul par
/// construction. Sans cette voie, la route n'avait que l'objet passé par la
/// liste, et un `!` sur ce nul faisait l'écran rouge « Null check operator
/// used on a null value » dès qu'on l'atteignait autrement.
///
/// Rend `null` — et non une erreur — quand la fiche n'existe pas ou n'est pas
/// montrable : l'écran distingue « introuvable » (rien à réessayer) de
/// « chargement impossible » (réessayer a du sens).
///
/// Copied from [embassyById].
@ProviderFor(embassyById)
const embassyByIdProvider = EmbassyByIdFamily();

/// La fiche d'un poste, résolue par son identifiant seul.
///
/// Le lien profond (`diasponiger:///embassies/<id>`) et la notification
/// n'arrivent jamais avec l'entité en `state.extra` — c'est nul par
/// construction. Sans cette voie, la route n'avait que l'objet passé par la
/// liste, et un `!` sur ce nul faisait l'écran rouge « Null check operator
/// used on a null value » dès qu'on l'atteignait autrement.
///
/// Rend `null` — et non une erreur — quand la fiche n'existe pas ou n'est pas
/// montrable : l'écran distingue « introuvable » (rien à réessayer) de
/// « chargement impossible » (réessayer a du sens).
///
/// Copied from [embassyById].
class EmbassyByIdFamily extends Family<AsyncValue<EmbassyEntity?>> {
  /// La fiche d'un poste, résolue par son identifiant seul.
  ///
  /// Le lien profond (`diasponiger:///embassies/<id>`) et la notification
  /// n'arrivent jamais avec l'entité en `state.extra` — c'est nul par
  /// construction. Sans cette voie, la route n'avait que l'objet passé par la
  /// liste, et un `!` sur ce nul faisait l'écran rouge « Null check operator
  /// used on a null value » dès qu'on l'atteignait autrement.
  ///
  /// Rend `null` — et non une erreur — quand la fiche n'existe pas ou n'est pas
  /// montrable : l'écran distingue « introuvable » (rien à réessayer) de
  /// « chargement impossible » (réessayer a du sens).
  ///
  /// Copied from [embassyById].
  const EmbassyByIdFamily();

  /// La fiche d'un poste, résolue par son identifiant seul.
  ///
  /// Le lien profond (`diasponiger:///embassies/<id>`) et la notification
  /// n'arrivent jamais avec l'entité en `state.extra` — c'est nul par
  /// construction. Sans cette voie, la route n'avait que l'objet passé par la
  /// liste, et un `!` sur ce nul faisait l'écran rouge « Null check operator
  /// used on a null value » dès qu'on l'atteignait autrement.
  ///
  /// Rend `null` — et non une erreur — quand la fiche n'existe pas ou n'est pas
  /// montrable : l'écran distingue « introuvable » (rien à réessayer) de
  /// « chargement impossible » (réessayer a du sens).
  ///
  /// Copied from [embassyById].
  EmbassyByIdProvider call(String id) {
    return EmbassyByIdProvider(id);
  }

  @override
  EmbassyByIdProvider getProviderOverride(
    covariant EmbassyByIdProvider provider,
  ) {
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
  String? get name => r'embassyByIdProvider';
}

/// La fiche d'un poste, résolue par son identifiant seul.
///
/// Le lien profond (`diasponiger:///embassies/<id>`) et la notification
/// n'arrivent jamais avec l'entité en `state.extra` — c'est nul par
/// construction. Sans cette voie, la route n'avait que l'objet passé par la
/// liste, et un `!` sur ce nul faisait l'écran rouge « Null check operator
/// used on a null value » dès qu'on l'atteignait autrement.
///
/// Rend `null` — et non une erreur — quand la fiche n'existe pas ou n'est pas
/// montrable : l'écran distingue « introuvable » (rien à réessayer) de
/// « chargement impossible » (réessayer a du sens).
///
/// Copied from [embassyById].
class EmbassyByIdProvider extends AutoDisposeFutureProvider<EmbassyEntity?> {
  /// La fiche d'un poste, résolue par son identifiant seul.
  ///
  /// Le lien profond (`diasponiger:///embassies/<id>`) et la notification
  /// n'arrivent jamais avec l'entité en `state.extra` — c'est nul par
  /// construction. Sans cette voie, la route n'avait que l'objet passé par la
  /// liste, et un `!` sur ce nul faisait l'écran rouge « Null check operator
  /// used on a null value » dès qu'on l'atteignait autrement.
  ///
  /// Rend `null` — et non une erreur — quand la fiche n'existe pas ou n'est pas
  /// montrable : l'écran distingue « introuvable » (rien à réessayer) de
  /// « chargement impossible » (réessayer a du sens).
  ///
  /// Copied from [embassyById].
  EmbassyByIdProvider(String id)
    : this._internal(
        (ref) => embassyById(ref as EmbassyByIdRef, id),
        from: embassyByIdProvider,
        name: r'embassyByIdProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$embassyByIdHash,
        dependencies: EmbassyByIdFamily._dependencies,
        allTransitiveDependencies: EmbassyByIdFamily._allTransitiveDependencies,
        id: id,
      );

  EmbassyByIdProvider._internal(
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
    FutureOr<EmbassyEntity?> Function(EmbassyByIdRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: EmbassyByIdProvider._internal(
        (ref) => create(ref as EmbassyByIdRef),
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
  AutoDisposeFutureProviderElement<EmbassyEntity?> createElement() {
    return _EmbassyByIdProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is EmbassyByIdProvider && other.id == id;
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
mixin EmbassyByIdRef on AutoDisposeFutureProviderRef<EmbassyEntity?> {
  /// The parameter `id` of this provider.
  String get id;
}

class _EmbassyByIdProviderElement
    extends AutoDisposeFutureProviderElement<EmbassyEntity?>
    with EmbassyByIdRef {
  _EmbassyByIdProviderElement(super.provider);

  @override
  String get id => (origin as EmbassyByIdProvider).id;
}

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
