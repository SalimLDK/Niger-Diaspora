// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$profileRemoteDataSourceHash() =>
    r'f1abd6607c606939e3a5f9dafd53e7ae8de41419';

/// See also [profileRemoteDataSource].
@ProviderFor(profileRemoteDataSource)
final profileRemoteDataSourceProvider =
    AutoDisposeProvider<ProfileRemoteDataSource>.internal(
      profileRemoteDataSource,
      name: r'profileRemoteDataSourceProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$profileRemoteDataSourceHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ProfileRemoteDataSourceRef =
    AutoDisposeProviderRef<ProfileRemoteDataSource>;
String _$profileRepositoryHash() => r'26a9561aac9311db6d216822f642469769e6ec2b';

/// See also [profileRepository].
@ProviderFor(profileRepository)
final profileRepositoryProvider =
    AutoDisposeProvider<ProfileRepository>.internal(
      profileRepository,
      name: r'profileRepositoryProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$profileRepositoryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ProfileRepositoryRef = AutoDisposeProviderRef<ProfileRepository>;
String _$userStreamHash() => r'0a90d4374470eff162fdd4c7859d9a940a336aaf';

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

/// See also [userStream].
@ProviderFor(userStream)
const userStreamProvider = UserStreamFamily();

/// See also [userStream].
class UserStreamFamily extends Family<AsyncValue<ProfileEntity?>> {
  /// See also [userStream].
  const UserStreamFamily();

  /// See also [userStream].
  UserStreamProvider call(String userId) {
    return UserStreamProvider(userId);
  }

  @override
  UserStreamProvider getProviderOverride(
    covariant UserStreamProvider provider,
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
  String? get name => r'userStreamProvider';
}

/// See also [userStream].
class UserStreamProvider extends AutoDisposeStreamProvider<ProfileEntity?> {
  /// See also [userStream].
  UserStreamProvider(String userId)
    : this._internal(
        (ref) => userStream(ref as UserStreamRef, userId),
        from: userStreamProvider,
        name: r'userStreamProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$userStreamHash,
        dependencies: UserStreamFamily._dependencies,
        allTransitiveDependencies: UserStreamFamily._allTransitiveDependencies,
        userId: userId,
      );

  UserStreamProvider._internal(
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
    Stream<ProfileEntity?> Function(UserStreamRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: UserStreamProvider._internal(
        (ref) => create(ref as UserStreamRef),
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
  AutoDisposeStreamProviderElement<ProfileEntity?> createElement() {
    return _UserStreamProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is UserStreamProvider && other.userId == userId;
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
mixin UserStreamRef on AutoDisposeStreamProviderRef<ProfileEntity?> {
  /// The parameter `userId` of this provider.
  String get userId;
}

class _UserStreamProviderElement
    extends AutoDisposeStreamProviderElement<ProfileEntity?>
    with UserStreamRef {
  _UserStreamProviderElement(super.provider);

  @override
  String get userId => (origin as UserStreamProvider).userId;
}

String _$profileNotifierHash() => r'9ca82bf82aace34d7a6f50356c9957abe3d6a3df';

abstract class _$ProfileNotifier
    extends BuildlessAsyncNotifier<ProfileEntity?> {
  late final String userId;

  FutureOr<ProfileEntity?> build(String userId);
}

/// See also [ProfileNotifier].
@ProviderFor(ProfileNotifier)
const profileNotifierProvider = ProfileNotifierFamily();

/// See also [ProfileNotifier].
class ProfileNotifierFamily extends Family<AsyncValue<ProfileEntity?>> {
  /// See also [ProfileNotifier].
  const ProfileNotifierFamily();

  /// See also [ProfileNotifier].
  ProfileNotifierProvider call(String userId) {
    return ProfileNotifierProvider(userId);
  }

  @override
  ProfileNotifierProvider getProviderOverride(
    covariant ProfileNotifierProvider provider,
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
  String? get name => r'profileNotifierProvider';
}

/// See also [ProfileNotifier].
class ProfileNotifierProvider
    extends AsyncNotifierProviderImpl<ProfileNotifier, ProfileEntity?> {
  /// See also [ProfileNotifier].
  ProfileNotifierProvider(String userId)
    : this._internal(
        () => ProfileNotifier()..userId = userId,
        from: profileNotifierProvider,
        name: r'profileNotifierProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$profileNotifierHash,
        dependencies: ProfileNotifierFamily._dependencies,
        allTransitiveDependencies:
            ProfileNotifierFamily._allTransitiveDependencies,
        userId: userId,
      );

  ProfileNotifierProvider._internal(
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
  FutureOr<ProfileEntity?> runNotifierBuild(
    covariant ProfileNotifier notifier,
  ) {
    return notifier.build(userId);
  }

  @override
  Override overrideWith(ProfileNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: ProfileNotifierProvider._internal(
        () => create()..userId = userId,
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
  AsyncNotifierProviderElement<ProfileNotifier, ProfileEntity?>
  createElement() {
    return _ProfileNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ProfileNotifierProvider && other.userId == userId;
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
mixin ProfileNotifierRef on AsyncNotifierProviderRef<ProfileEntity?> {
  /// The parameter `userId` of this provider.
  String get userId;
}

class _ProfileNotifierProviderElement
    extends AsyncNotifierProviderElement<ProfileNotifier, ProfileEntity?>
    with ProfileNotifierRef {
  _ProfileNotifierProviderElement(super.provider);

  @override
  String get userId => (origin as ProfileNotifierProvider).userId;
}

String _$nearbyProfilesNotifierHash() =>
    r'2fa84c3fc378ed4b4188e3ad98cdd8fed6f9a3f3';

/// See also [NearbyProfilesNotifier].
@ProviderFor(NearbyProfilesNotifier)
final nearbyProfilesNotifierProvider = NotifierProvider<
  NearbyProfilesNotifier,
  AsyncValue<List<ProfileEntity>>
>.internal(
  NearbyProfilesNotifier.new,
  name: r'nearbyProfilesNotifierProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$nearbyProfilesNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$NearbyProfilesNotifier = Notifier<AsyncValue<List<ProfileEntity>>>;
String _$searchProfilesNotifierHash() =>
    r'f193ac46009c2573a02749d11a4b32db75eae9e8';

/// See also [SearchProfilesNotifier].
@ProviderFor(SearchProfilesNotifier)
final searchProfilesNotifierProvider = AutoDisposeNotifierProvider<
  SearchProfilesNotifier,
  AsyncValue<List<ProfileEntity>>
>.internal(
  SearchProfilesNotifier.new,
  name: r'searchProfilesNotifierProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$searchProfilesNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$SearchProfilesNotifier =
    AutoDisposeNotifier<AsyncValue<List<ProfileEntity>>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
