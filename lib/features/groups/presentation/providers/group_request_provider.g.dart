// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'group_request_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$groupRequestDataSourceHash() =>
    r'fddd1a1254177a8bcfaf6d962602066c3dec3b92';

/// See also [groupRequestDataSource].
@ProviderFor(groupRequestDataSource)
final groupRequestDataSourceProvider =
    AutoDisposeProvider<GroupRequestDataSource>.internal(
      groupRequestDataSource,
      name: r'groupRequestDataSourceProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$groupRequestDataSourceHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef GroupRequestDataSourceRef =
    AutoDisposeProviderRef<GroupRequestDataSource>;
String _$groupPendingRequestsHash() =>
    r'e3b717ca34e5b00371e6121dcf81e061c3d86004';

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

/// See also [groupPendingRequests].
@ProviderFor(groupPendingRequests)
const groupPendingRequestsProvider = GroupPendingRequestsFamily();

/// See also [groupPendingRequests].
class GroupPendingRequestsFamily
    extends Family<AsyncValue<List<GroupRequestEntity>>> {
  /// See also [groupPendingRequests].
  const GroupPendingRequestsFamily();

  /// See also [groupPendingRequests].
  GroupPendingRequestsProvider call(String groupId) {
    return GroupPendingRequestsProvider(groupId);
  }

  @override
  GroupPendingRequestsProvider getProviderOverride(
    covariant GroupPendingRequestsProvider provider,
  ) {
    return call(provider.groupId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'groupPendingRequestsProvider';
}

/// See also [groupPendingRequests].
class GroupPendingRequestsProvider
    extends AutoDisposeStreamProvider<List<GroupRequestEntity>> {
  /// See also [groupPendingRequests].
  GroupPendingRequestsProvider(String groupId)
    : this._internal(
        (ref) => groupPendingRequests(ref as GroupPendingRequestsRef, groupId),
        from: groupPendingRequestsProvider,
        name: r'groupPendingRequestsProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$groupPendingRequestsHash,
        dependencies: GroupPendingRequestsFamily._dependencies,
        allTransitiveDependencies:
            GroupPendingRequestsFamily._allTransitiveDependencies,
        groupId: groupId,
      );

  GroupPendingRequestsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.groupId,
  }) : super.internal();

  final String groupId;

  @override
  Override overrideWith(
    Stream<List<GroupRequestEntity>> Function(GroupPendingRequestsRef provider)
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: GroupPendingRequestsProvider._internal(
        (ref) => create(ref as GroupPendingRequestsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        groupId: groupId,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<List<GroupRequestEntity>> createElement() {
    return _GroupPendingRequestsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is GroupPendingRequestsProvider && other.groupId == groupId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, groupId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin GroupPendingRequestsRef
    on AutoDisposeStreamProviderRef<List<GroupRequestEntity>> {
  /// The parameter `groupId` of this provider.
  String get groupId;
}

class _GroupPendingRequestsProviderElement
    extends AutoDisposeStreamProviderElement<List<GroupRequestEntity>>
    with GroupPendingRequestsRef {
  _GroupPendingRequestsProviderElement(super.provider);

  @override
  String get groupId => (origin as GroupPendingRequestsProvider).groupId;
}

String _$myGroupRequestsHash() => r'e64394180eeeb8a8069a56bc8f859909df260a08';

/// See also [myGroupRequests].
@ProviderFor(myGroupRequests)
final myGroupRequestsProvider =
    AutoDisposeStreamProvider<List<GroupRequestEntity>>.internal(
      myGroupRequests,
      name: r'myGroupRequestsProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$myGroupRequestsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef MyGroupRequestsRef =
    AutoDisposeStreamProviderRef<List<GroupRequestEntity>>;
String _$receivedGroupInvitesHash() =>
    r'f60387b77556b780ccefbfd6442f13f58588a2d2';

/// See also [receivedGroupInvites].
@ProviderFor(receivedGroupInvites)
final receivedGroupInvitesProvider =
    AutoDisposeStreamProvider<List<GroupInviteEntity>>.internal(
      receivedGroupInvites,
      name: r'receivedGroupInvitesProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$receivedGroupInvitesHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ReceivedGroupInvitesRef =
    AutoDisposeStreamProviderRef<List<GroupInviteEntity>>;
String _$groupSentInvitesHash() => r'fafc04d95634d1c3f46323d8357f09ce66670bce';

/// See also [groupSentInvites].
@ProviderFor(groupSentInvites)
const groupSentInvitesProvider = GroupSentInvitesFamily();

/// See also [groupSentInvites].
class GroupSentInvitesFamily
    extends Family<AsyncValue<List<GroupInviteEntity>>> {
  /// See also [groupSentInvites].
  const GroupSentInvitesFamily();

  /// See also [groupSentInvites].
  GroupSentInvitesProvider call(String groupId) {
    return GroupSentInvitesProvider(groupId);
  }

  @override
  GroupSentInvitesProvider getProviderOverride(
    covariant GroupSentInvitesProvider provider,
  ) {
    return call(provider.groupId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'groupSentInvitesProvider';
}

/// See also [groupSentInvites].
class GroupSentInvitesProvider
    extends AutoDisposeStreamProvider<List<GroupInviteEntity>> {
  /// See also [groupSentInvites].
  GroupSentInvitesProvider(String groupId)
    : this._internal(
        (ref) => groupSentInvites(ref as GroupSentInvitesRef, groupId),
        from: groupSentInvitesProvider,
        name: r'groupSentInvitesProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$groupSentInvitesHash,
        dependencies: GroupSentInvitesFamily._dependencies,
        allTransitiveDependencies:
            GroupSentInvitesFamily._allTransitiveDependencies,
        groupId: groupId,
      );

  GroupSentInvitesProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.groupId,
  }) : super.internal();

  final String groupId;

  @override
  Override overrideWith(
    Stream<List<GroupInviteEntity>> Function(GroupSentInvitesRef provider)
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: GroupSentInvitesProvider._internal(
        (ref) => create(ref as GroupSentInvitesRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        groupId: groupId,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<List<GroupInviteEntity>> createElement() {
    return _GroupSentInvitesProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is GroupSentInvitesProvider && other.groupId == groupId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, groupId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin GroupSentInvitesRef
    on AutoDisposeStreamProviderRef<List<GroupInviteEntity>> {
  /// The parameter `groupId` of this provider.
  String get groupId;
}

class _GroupSentInvitesProviderElement
    extends AutoDisposeStreamProviderElement<List<GroupInviteEntity>>
    with GroupSentInvitesRef {
  _GroupSentInvitesProviderElement(super.provider);

  @override
  String get groupId => (origin as GroupSentInvitesProvider).groupId;
}

String _$groupRequestNotifierHash() =>
    r'141ad80d392c60352ad61940e65545315de5f4ea';

/// See also [GroupRequestNotifier].
@ProviderFor(GroupRequestNotifier)
final groupRequestNotifierProvider = AutoDisposeNotifierProvider<
  GroupRequestNotifier,
  AsyncValue<void>
>.internal(
  GroupRequestNotifier.new,
  name: r'groupRequestNotifierProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$groupRequestNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$GroupRequestNotifier = AutoDisposeNotifier<AsyncValue<void>>;
String _$groupInviteNotifierHash() =>
    r'ea3a2405f44e33fe35757b16509075eccadb82db';

/// See also [GroupInviteNotifier].
@ProviderFor(GroupInviteNotifier)
final groupInviteNotifierProvider =
    AutoDisposeNotifierProvider<GroupInviteNotifier, AsyncValue<void>>.internal(
      GroupInviteNotifier.new,
      name: r'groupInviteNotifierProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$groupInviteNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$GroupInviteNotifier = AutoDisposeNotifier<AsyncValue<void>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
