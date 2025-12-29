// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'friend_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$friendRemoteDataSourceHash() =>
    r'3bbcc5b3b28a4b14398adf47bed84a5deb55a32d';

/// See also [friendRemoteDataSource].
@ProviderFor(friendRemoteDataSource)
final friendRemoteDataSourceProvider =
    AutoDisposeProvider<FriendRemoteDataSource>.internal(
      friendRemoteDataSource,
      name: r'friendRemoteDataSourceProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$friendRemoteDataSourceHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef FriendRemoteDataSourceRef =
    AutoDisposeProviderRef<FriendRemoteDataSource>;
String _$friendRepositoryHash() => r'978155a93d75d50ee56d2887bcb0813f83da6224';

/// See also [friendRepository].
@ProviderFor(friendRepository)
final friendRepositoryProvider = AutoDisposeProvider<FriendRepository>.internal(
  friendRepository,
  name: r'friendRepositoryProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$friendRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef FriendRepositoryRef = AutoDisposeProviderRef<FriendRepository>;
String _$friendsHash() => r'ae2f89078070bd795e09f7adf9d85ae2a809adbe';

/// See also [friends].
@ProviderFor(friends)
final friendsProvider = StreamProvider<List<FriendEntity>>.internal(
  friends,
  name: r'friendsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$friendsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef FriendsRef = StreamProviderRef<List<FriendEntity>>;
String _$receivedFriendRequestsHash() =>
    r'0d26b6fe1cf1dc3ca1a52e69275992d2bb7cad71';

/// See also [receivedFriendRequests].
@ProviderFor(receivedFriendRequests)
final receivedFriendRequestsProvider =
    StreamProvider<List<FriendRequestEntity>>.internal(
      receivedFriendRequests,
      name: r'receivedFriendRequestsProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$receivedFriendRequestsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ReceivedFriendRequestsRef =
    StreamProviderRef<List<FriendRequestEntity>>;
String _$sentFriendRequestsHash() =>
    r'47f767ee29552392796b5357cad6ac3628b1caea';

/// See also [sentFriendRequests].
@ProviderFor(sentFriendRequests)
final sentFriendRequestsProvider =
    StreamProvider<List<FriendRequestEntity>>.internal(
      sentFriendRequests,
      name: r'sentFriendRequestsProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$sentFriendRequestsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SentFriendRequestsRef = StreamProviderRef<List<FriendRequestEntity>>;
String _$friendshipStatusHash() => r'b0e87966e3d49ad3a59f0f8785fcc58139d3fe08';

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

/// See also [friendshipStatus].
@ProviderFor(friendshipStatus)
const friendshipStatusProvider = FriendshipStatusFamily();

/// See also [friendshipStatus].
class FriendshipStatusFamily extends Family<AsyncValue<FriendshipStatus>> {
  /// See also [friendshipStatus].
  const FriendshipStatusFamily();

  /// See also [friendshipStatus].
  FriendshipStatusProvider call(String otherUserId) {
    return FriendshipStatusProvider(otherUserId);
  }

  @override
  FriendshipStatusProvider getProviderOverride(
    covariant FriendshipStatusProvider provider,
  ) {
    return call(provider.otherUserId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'friendshipStatusProvider';
}

/// See also [friendshipStatus].
class FriendshipStatusProvider extends FutureProvider<FriendshipStatus> {
  /// See also [friendshipStatus].
  FriendshipStatusProvider(String otherUserId)
    : this._internal(
        (ref) => friendshipStatus(ref as FriendshipStatusRef, otherUserId),
        from: friendshipStatusProvider,
        name: r'friendshipStatusProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$friendshipStatusHash,
        dependencies: FriendshipStatusFamily._dependencies,
        allTransitiveDependencies:
            FriendshipStatusFamily._allTransitiveDependencies,
        otherUserId: otherUserId,
      );

  FriendshipStatusProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.otherUserId,
  }) : super.internal();

  final String otherUserId;

  @override
  Override overrideWith(
    FutureOr<FriendshipStatus> Function(FriendshipStatusRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: FriendshipStatusProvider._internal(
        (ref) => create(ref as FriendshipStatusRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        otherUserId: otherUserId,
      ),
    );
  }

  @override
  FutureProviderElement<FriendshipStatus> createElement() {
    return _FriendshipStatusProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is FriendshipStatusProvider &&
        other.otherUserId == otherUserId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, otherUserId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin FriendshipStatusRef on FutureProviderRef<FriendshipStatus> {
  /// The parameter `otherUserId` of this provider.
  String get otherUserId;
}

class _FriendshipStatusProviderElement
    extends FutureProviderElement<FriendshipStatus>
    with FriendshipStatusRef {
  _FriendshipStatusProviderElement(super.provider);

  @override
  String get otherUserId => (origin as FriendshipStatusProvider).otherUserId;
}

String _$friendRequestNotifierHash() =>
    r'0d8733cac0dc3691a7344f825c76bdcb67616361';

/// See also [FriendRequestNotifier].
@ProviderFor(FriendRequestNotifier)
final friendRequestNotifierProvider =
    NotifierProvider<FriendRequestNotifier, AsyncValue<void>>.internal(
      FriendRequestNotifier.new,
      name: r'friendRequestNotifierProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$friendRequestNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$FriendRequestNotifier = Notifier<AsyncValue<void>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
