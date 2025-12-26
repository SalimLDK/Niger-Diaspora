// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'online_status_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$onlineStatusServiceHash() =>
    r'336d83c427b9157b2cb110246bf6f0b64f409649';

/// Provider for the OnlineStatusService instance
///
/// Copied from [onlineStatusService].
@ProviderFor(onlineStatusService)
final onlineStatusServiceProvider =
    AutoDisposeProvider<OnlineStatusService>.internal(
      onlineStatusService,
      name: r'onlineStatusServiceProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$onlineStatusServiceHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef OnlineStatusServiceRef = AutoDisposeProviderRef<OnlineStatusService>;
String _$userOnlineStatusHash() => r'16e890a75005a3c1f9841437ab351b5938e159b1';

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

/// Provider that streams a specific user's online status
///
/// Copied from [userOnlineStatus].
@ProviderFor(userOnlineStatus)
const userOnlineStatusProvider = UserOnlineStatusFamily();

/// Provider that streams a specific user's online status
///
/// Copied from [userOnlineStatus].
class UserOnlineStatusFamily extends Family<AsyncValue<bool>> {
  /// Provider that streams a specific user's online status
  ///
  /// Copied from [userOnlineStatus].
  const UserOnlineStatusFamily();

  /// Provider that streams a specific user's online status
  ///
  /// Copied from [userOnlineStatus].
  UserOnlineStatusProvider call(String userId) {
    return UserOnlineStatusProvider(userId);
  }

  @override
  UserOnlineStatusProvider getProviderOverride(
    covariant UserOnlineStatusProvider provider,
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
  String? get name => r'userOnlineStatusProvider';
}

/// Provider that streams a specific user's online status
///
/// Copied from [userOnlineStatus].
class UserOnlineStatusProvider extends AutoDisposeStreamProvider<bool> {
  /// Provider that streams a specific user's online status
  ///
  /// Copied from [userOnlineStatus].
  UserOnlineStatusProvider(String userId)
    : this._internal(
        (ref) => userOnlineStatus(ref as UserOnlineStatusRef, userId),
        from: userOnlineStatusProvider,
        name: r'userOnlineStatusProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$userOnlineStatusHash,
        dependencies: UserOnlineStatusFamily._dependencies,
        allTransitiveDependencies:
            UserOnlineStatusFamily._allTransitiveDependencies,
        userId: userId,
      );

  UserOnlineStatusProvider._internal(
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
    Stream<bool> Function(UserOnlineStatusRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: UserOnlineStatusProvider._internal(
        (ref) => create(ref as UserOnlineStatusRef),
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
  AutoDisposeStreamProviderElement<bool> createElement() {
    return _UserOnlineStatusProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is UserOnlineStatusProvider && other.userId == userId;
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
mixin UserOnlineStatusRef on AutoDisposeStreamProviderRef<bool> {
  /// The parameter `userId` of this provider.
  String get userId;
}

class _UserOnlineStatusProviderElement
    extends AutoDisposeStreamProviderElement<bool>
    with UserOnlineStatusRef {
  _UserOnlineStatusProviderElement(super.provider);

  @override
  String get userId => (origin as UserOnlineStatusProvider).userId;
}

String _$userLastSeenHash() => r'e156167e5b11d00a44bcfb283e2a2002100df2d7';

/// Provider that streams a specific user's last seen timestamp
///
/// Copied from [userLastSeen].
@ProviderFor(userLastSeen)
const userLastSeenProvider = UserLastSeenFamily();

/// Provider that streams a specific user's last seen timestamp
///
/// Copied from [userLastSeen].
class UserLastSeenFamily extends Family<AsyncValue<DateTime?>> {
  /// Provider that streams a specific user's last seen timestamp
  ///
  /// Copied from [userLastSeen].
  const UserLastSeenFamily();

  /// Provider that streams a specific user's last seen timestamp
  ///
  /// Copied from [userLastSeen].
  UserLastSeenProvider call(String userId) {
    return UserLastSeenProvider(userId);
  }

  @override
  UserLastSeenProvider getProviderOverride(
    covariant UserLastSeenProvider provider,
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
  String? get name => r'userLastSeenProvider';
}

/// Provider that streams a specific user's last seen timestamp
///
/// Copied from [userLastSeen].
class UserLastSeenProvider extends AutoDisposeStreamProvider<DateTime?> {
  /// Provider that streams a specific user's last seen timestamp
  ///
  /// Copied from [userLastSeen].
  UserLastSeenProvider(String userId)
    : this._internal(
        (ref) => userLastSeen(ref as UserLastSeenRef, userId),
        from: userLastSeenProvider,
        name: r'userLastSeenProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$userLastSeenHash,
        dependencies: UserLastSeenFamily._dependencies,
        allTransitiveDependencies:
            UserLastSeenFamily._allTransitiveDependencies,
        userId: userId,
      );

  UserLastSeenProvider._internal(
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
    Stream<DateTime?> Function(UserLastSeenRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: UserLastSeenProvider._internal(
        (ref) => create(ref as UserLastSeenRef),
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
  AutoDisposeStreamProviderElement<DateTime?> createElement() {
    return _UserLastSeenProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is UserLastSeenProvider && other.userId == userId;
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
mixin UserLastSeenRef on AutoDisposeStreamProviderRef<DateTime?> {
  /// The parameter `userId` of this provider.
  String get userId;
}

class _UserLastSeenProviderElement
    extends AutoDisposeStreamProviderElement<DateTime?>
    with UserLastSeenRef {
  _UserLastSeenProviderElement(super.provider);

  @override
  String get userId => (origin as UserLastSeenProvider).userId;
}

String _$currentUserOnlineStatusVisibilityHash() =>
    r'c1751f6c9ff57c60e26d47b1fb8615829596f126';

/// Provider for the current user's online status visibility preference
///
/// Copied from [CurrentUserOnlineStatusVisibility].
@ProviderFor(CurrentUserOnlineStatusVisibility)
final currentUserOnlineStatusVisibilityProvider =
    AutoDisposeAsyncNotifierProvider<
      CurrentUserOnlineStatusVisibility,
      bool
    >.internal(
      CurrentUserOnlineStatusVisibility.new,
      name: r'currentUserOnlineStatusVisibilityProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$currentUserOnlineStatusVisibilityHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$CurrentUserOnlineStatusVisibility = AutoDisposeAsyncNotifier<bool>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
