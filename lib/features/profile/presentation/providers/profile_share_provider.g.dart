// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_share_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$profileShareDataSourceHash() =>
    r'c2bc2b9f11025b39f263d4d019e0682baa86e37a';

/// See also [profileShareDataSource].
@ProviderFor(profileShareDataSource)
final profileShareDataSourceProvider =
    AutoDisposeProvider<ProfileShareDataSource>.internal(
      profileShareDataSource,
      name: r'profileShareDataSourceProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$profileShareDataSourceHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ProfileShareDataSourceRef =
    AutoDisposeProviderRef<ProfileShareDataSource>;
String _$profileUserIdFromShareCodeHash() =>
    r'a6944e3348278984306eddb56366e05f05b6d5aa';

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

/// See also [profileUserIdFromShareCode].
@ProviderFor(profileUserIdFromShareCode)
const profileUserIdFromShareCodeProvider = ProfileUserIdFromShareCodeFamily();

/// See also [profileUserIdFromShareCode].
class ProfileUserIdFromShareCodeFamily extends Family<AsyncValue<String?>> {
  /// See also [profileUserIdFromShareCode].
  const ProfileUserIdFromShareCodeFamily();

  /// See also [profileUserIdFromShareCode].
  ProfileUserIdFromShareCodeProvider call(String shortCode) {
    return ProfileUserIdFromShareCodeProvider(shortCode);
  }

  @override
  ProfileUserIdFromShareCodeProvider getProviderOverride(
    covariant ProfileUserIdFromShareCodeProvider provider,
  ) {
    return call(provider.shortCode);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'profileUserIdFromShareCodeProvider';
}

/// See also [profileUserIdFromShareCode].
class ProfileUserIdFromShareCodeProvider
    extends AutoDisposeFutureProvider<String?> {
  /// See also [profileUserIdFromShareCode].
  ProfileUserIdFromShareCodeProvider(String shortCode)
    : this._internal(
        (ref) => profileUserIdFromShareCode(
          ref as ProfileUserIdFromShareCodeRef,
          shortCode,
        ),
        from: profileUserIdFromShareCodeProvider,
        name: r'profileUserIdFromShareCodeProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$profileUserIdFromShareCodeHash,
        dependencies: ProfileUserIdFromShareCodeFamily._dependencies,
        allTransitiveDependencies:
            ProfileUserIdFromShareCodeFamily._allTransitiveDependencies,
        shortCode: shortCode,
      );

  ProfileUserIdFromShareCodeProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.shortCode,
  }) : super.internal();

  final String shortCode;

  @override
  Override overrideWith(
    FutureOr<String?> Function(ProfileUserIdFromShareCodeRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ProfileUserIdFromShareCodeProvider._internal(
        (ref) => create(ref as ProfileUserIdFromShareCodeRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        shortCode: shortCode,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<String?> createElement() {
    return _ProfileUserIdFromShareCodeProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ProfileUserIdFromShareCodeProvider &&
        other.shortCode == shortCode;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, shortCode.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ProfileUserIdFromShareCodeRef on AutoDisposeFutureProviderRef<String?> {
  /// The parameter `shortCode` of this provider.
  String get shortCode;
}

class _ProfileUserIdFromShareCodeProviderElement
    extends AutoDisposeFutureProviderElement<String?>
    with ProfileUserIdFromShareCodeRef {
  _ProfileUserIdFromShareCodeProviderElement(super.provider);

  @override
  String get shortCode =>
      (origin as ProfileUserIdFromShareCodeProvider).shortCode;
}

String _$profileShareNotifierHash() =>
    r'bb3c20b2afd0cc83fc1cba97ed752fb7a4f7cab7';

/// See also [ProfileShareNotifier].
@ProviderFor(ProfileShareNotifier)
final profileShareNotifierProvider = AutoDisposeNotifierProvider<
  ProfileShareNotifier,
  AsyncValue<ProfileShareLinkEntity?>
>.internal(
  ProfileShareNotifier.new,
  name: r'profileShareNotifierProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$profileShareNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ProfileShareNotifier =
    AutoDisposeNotifier<AsyncValue<ProfileShareLinkEntity?>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
