// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'group_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$groupRemoteDataSourceHash() =>
    r'dea53a877fc09739063e6f86acc605c8912b7c2c';

/// See also [groupRemoteDataSource].
@ProviderFor(groupRemoteDataSource)
final groupRemoteDataSourceProvider =
    AutoDisposeProvider<GroupRemoteDataSource>.internal(
      groupRemoteDataSource,
      name: r'groupRemoteDataSourceProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$groupRemoteDataSourceHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef GroupRemoteDataSourceRef =
    AutoDisposeProviderRef<GroupRemoteDataSource>;
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
String _$groupRepositoryHash() => r'703db55e0de5aaf585532c8f38b4b41e1e19f8b5';

/// See also [groupRepository].
@ProviderFor(groupRepository)
final groupRepositoryProvider = AutoDisposeProvider<GroupRepository>.internal(
  groupRepository,
  name: r'groupRepositoryProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$groupRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef GroupRepositoryRef = AutoDisposeProviderRef<GroupRepository>;
String _$groupByNameHash() => r'de64cd21a8719dad25f75dd65197c902ba818194';

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

/// Find a group by its name - useful as fallback when groupId is missing
///
/// Copied from [groupByName].
@ProviderFor(groupByName)
const groupByNameProvider = GroupByNameFamily();

/// Find a group by its name - useful as fallback when groupId is missing
///
/// Copied from [groupByName].
class GroupByNameFamily extends Family<AsyncValue<GroupEntity?>> {
  /// Find a group by its name - useful as fallback when groupId is missing
  ///
  /// Copied from [groupByName].
  const GroupByNameFamily();

  /// Find a group by its name - useful as fallback when groupId is missing
  ///
  /// Copied from [groupByName].
  GroupByNameProvider call(String groupName) {
    return GroupByNameProvider(groupName);
  }

  @override
  GroupByNameProvider getProviderOverride(
    covariant GroupByNameProvider provider,
  ) {
    return call(provider.groupName);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'groupByNameProvider';
}

/// Find a group by its name - useful as fallback when groupId is missing
///
/// Copied from [groupByName].
class GroupByNameProvider extends AutoDisposeFutureProvider<GroupEntity?> {
  /// Find a group by its name - useful as fallback when groupId is missing
  ///
  /// Copied from [groupByName].
  GroupByNameProvider(String groupName)
    : this._internal(
        (ref) => groupByName(ref as GroupByNameRef, groupName),
        from: groupByNameProvider,
        name: r'groupByNameProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$groupByNameHash,
        dependencies: GroupByNameFamily._dependencies,
        allTransitiveDependencies: GroupByNameFamily._allTransitiveDependencies,
        groupName: groupName,
      );

  GroupByNameProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.groupName,
  }) : super.internal();

  final String groupName;

  @override
  Override overrideWith(
    FutureOr<GroupEntity?> Function(GroupByNameRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: GroupByNameProvider._internal(
        (ref) => create(ref as GroupByNameRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        groupName: groupName,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<GroupEntity?> createElement() {
    return _GroupByNameProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is GroupByNameProvider && other.groupName == groupName;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, groupName.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin GroupByNameRef on AutoDisposeFutureProviderRef<GroupEntity?> {
  /// The parameter `groupName` of this provider.
  String get groupName;
}

class _GroupByNameProviderElement
    extends AutoDisposeFutureProviderElement<GroupEntity?>
    with GroupByNameRef {
  _GroupByNameProviderElement(super.provider);

  @override
  String get groupName => (origin as GroupByNameProvider).groupName;
}

String _$groupByIdHash() => r'1589025845c43331e65246b6ed08fceaaf5ad40a';

/// Récupérer un groupe par son ID
///
/// Copied from [groupById].
@ProviderFor(groupById)
const groupByIdProvider = GroupByIdFamily();

/// Récupérer un groupe par son ID
///
/// Copied from [groupById].
class GroupByIdFamily extends Family<AsyncValue<GroupEntity?>> {
  /// Récupérer un groupe par son ID
  ///
  /// Copied from [groupById].
  const GroupByIdFamily();

  /// Récupérer un groupe par son ID
  ///
  /// Copied from [groupById].
  GroupByIdProvider call(String groupId) {
    return GroupByIdProvider(groupId);
  }

  @override
  GroupByIdProvider getProviderOverride(covariant GroupByIdProvider provider) {
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
  String? get name => r'groupByIdProvider';
}

/// Récupérer un groupe par son ID
///
/// Copied from [groupById].
class GroupByIdProvider extends AutoDisposeFutureProvider<GroupEntity?> {
  /// Récupérer un groupe par son ID
  ///
  /// Copied from [groupById].
  GroupByIdProvider(String groupId)
    : this._internal(
        (ref) => groupById(ref as GroupByIdRef, groupId),
        from: groupByIdProvider,
        name: r'groupByIdProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$groupByIdHash,
        dependencies: GroupByIdFamily._dependencies,
        allTransitiveDependencies: GroupByIdFamily._allTransitiveDependencies,
        groupId: groupId,
      );

  GroupByIdProvider._internal(
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
    FutureOr<GroupEntity?> Function(GroupByIdRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: GroupByIdProvider._internal(
        (ref) => create(ref as GroupByIdRef),
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
  AutoDisposeFutureProviderElement<GroupEntity?> createElement() {
    return _GroupByIdProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is GroupByIdProvider && other.groupId == groupId;
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
mixin GroupByIdRef on AutoDisposeFutureProviderRef<GroupEntity?> {
  /// The parameter `groupId` of this provider.
  String get groupId;
}

class _GroupByIdProviderElement
    extends AutoDisposeFutureProviderElement<GroupEntity?>
    with GroupByIdRef {
  _GroupByIdProviderElement(super.provider);

  @override
  String get groupId => (origin as GroupByIdProvider).groupId;
}

String _$groupStreamHash() => r'e11dcbe825673146bb3636f646084b568ce3ab4d';

/// Stream provider for real-time group updates
///
/// Copied from [groupStream].
@ProviderFor(groupStream)
const groupStreamProvider = GroupStreamFamily();

/// Stream provider for real-time group updates
///
/// Copied from [groupStream].
class GroupStreamFamily extends Family<AsyncValue<GroupEntity?>> {
  /// Stream provider for real-time group updates
  ///
  /// Copied from [groupStream].
  const GroupStreamFamily();

  /// Stream provider for real-time group updates
  ///
  /// Copied from [groupStream].
  GroupStreamProvider call(String groupId) {
    return GroupStreamProvider(groupId);
  }

  @override
  GroupStreamProvider getProviderOverride(
    covariant GroupStreamProvider provider,
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
  String? get name => r'groupStreamProvider';
}

/// Stream provider for real-time group updates
///
/// Copied from [groupStream].
class GroupStreamProvider extends AutoDisposeStreamProvider<GroupEntity?> {
  /// Stream provider for real-time group updates
  ///
  /// Copied from [groupStream].
  GroupStreamProvider(String groupId)
    : this._internal(
        (ref) => groupStream(ref as GroupStreamRef, groupId),
        from: groupStreamProvider,
        name: r'groupStreamProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$groupStreamHash,
        dependencies: GroupStreamFamily._dependencies,
        allTransitiveDependencies: GroupStreamFamily._allTransitiveDependencies,
        groupId: groupId,
      );

  GroupStreamProvider._internal(
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
    Stream<GroupEntity?> Function(GroupStreamRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: GroupStreamProvider._internal(
        (ref) => create(ref as GroupStreamRef),
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
  AutoDisposeStreamProviderElement<GroupEntity?> createElement() {
    return _GroupStreamProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is GroupStreamProvider && other.groupId == groupId;
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
mixin GroupStreamRef on AutoDisposeStreamProviderRef<GroupEntity?> {
  /// The parameter `groupId` of this provider.
  String get groupId;
}

class _GroupStreamProviderElement
    extends AutoDisposeStreamProviderElement<GroupEntity?>
    with GroupStreamRef {
  _GroupStreamProviderElement(super.provider);

  @override
  String get groupId => (origin as GroupStreamProvider).groupId;
}

String _$groupPendingRequestsHash() =>
    r'01b3f55eb46e76a21997b0f516ae42db88592ca3';

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

String _$myGroupRequestsHash() => r'71c6635611e02bc6427e6080f4c185aef5d4c12e';

/// See also [myGroupRequests].
@ProviderFor(myGroupRequests)
const myGroupRequestsProvider = MyGroupRequestsFamily();

/// See also [myGroupRequests].
class MyGroupRequestsFamily
    extends Family<AsyncValue<List<GroupRequestEntity>>> {
  /// See also [myGroupRequests].
  const MyGroupRequestsFamily();

  /// See also [myGroupRequests].
  MyGroupRequestsProvider call(String userId) {
    return MyGroupRequestsProvider(userId);
  }

  @override
  MyGroupRequestsProvider getProviderOverride(
    covariant MyGroupRequestsProvider provider,
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
  String? get name => r'myGroupRequestsProvider';
}

/// See also [myGroupRequests].
class MyGroupRequestsProvider
    extends AutoDisposeStreamProvider<List<GroupRequestEntity>> {
  /// See also [myGroupRequests].
  MyGroupRequestsProvider(String userId)
    : this._internal(
        (ref) => myGroupRequests(ref as MyGroupRequestsRef, userId),
        from: myGroupRequestsProvider,
        name: r'myGroupRequestsProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$myGroupRequestsHash,
        dependencies: MyGroupRequestsFamily._dependencies,
        allTransitiveDependencies:
            MyGroupRequestsFamily._allTransitiveDependencies,
        userId: userId,
      );

  MyGroupRequestsProvider._internal(
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
    Stream<List<GroupRequestEntity>> Function(MyGroupRequestsRef provider)
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: MyGroupRequestsProvider._internal(
        (ref) => create(ref as MyGroupRequestsRef),
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
  AutoDisposeStreamProviderElement<List<GroupRequestEntity>> createElement() {
    return _MyGroupRequestsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is MyGroupRequestsProvider && other.userId == userId;
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
mixin MyGroupRequestsRef
    on AutoDisposeStreamProviderRef<List<GroupRequestEntity>> {
  /// The parameter `userId` of this provider.
  String get userId;
}

class _MyGroupRequestsProviderElement
    extends AutoDisposeStreamProviderElement<List<GroupRequestEntity>>
    with MyGroupRequestsRef {
  _MyGroupRequestsProviderElement(super.provider);

  @override
  String get userId => (origin as MyGroupRequestsProvider).userId;
}

String _$availableGroupCountriesHash() =>
    r'c2579417eafb96c613f9d405d0bce298141f9b6a';

/// Provider pour récupérer la liste des pays disponibles (depuis les groupes existants)
///
/// Copied from [availableGroupCountries].
@ProviderFor(availableGroupCountries)
final availableGroupCountriesProvider =
    AutoDisposeProvider<List<String>>.internal(
      availableGroupCountries,
      name: r'availableGroupCountriesProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$availableGroupCountriesHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AvailableGroupCountriesRef = AutoDisposeProviderRef<List<String>>;
String _$availableGroupRegionsHash() =>
    r'5e7b8b212a7bef5d8d20f8901aad23153d334384';

/// Provider pour récupérer la liste des régions d'origine disponibles
///
/// Copied from [availableGroupRegions].
@ProviderFor(availableGroupRegions)
final availableGroupRegionsProvider =
    AutoDisposeProvider<List<String>>.internal(
      availableGroupRegions,
      name: r'availableGroupRegionsProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$availableGroupRegionsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AvailableGroupRegionsRef = AutoDisposeProviderRef<List<String>>;
String _$groupsNotifierHash() => r'25b035e59ab8e14b591948968b7e6e8f50f25f16';

/// See also [GroupsNotifier].
@ProviderFor(GroupsNotifier)
final groupsNotifierProvider =
    NotifierProvider<GroupsNotifier, AsyncValue<List<GroupEntity>>>.internal(
      GroupsNotifier.new,
      name: r'groupsNotifierProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$groupsNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$GroupsNotifier = Notifier<AsyncValue<List<GroupEntity>>>;
String _$groupDetailNotifierHash() =>
    r'3707848fdf4e18ee4f27e98fe55a60378da44893';

/// See also [GroupDetailNotifier].
@ProviderFor(GroupDetailNotifier)
final groupDetailNotifierProvider = AutoDisposeNotifierProvider<
  GroupDetailNotifier,
  AsyncValue<GroupEntity?>
>.internal(
  GroupDetailNotifier.new,
  name: r'groupDetailNotifierProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$groupDetailNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$GroupDetailNotifier = AutoDisposeNotifier<AsyncValue<GroupEntity?>>;
String _$myGroupsNotifierHash() => r'e2a824f32573bb54fa003bcc4dac511626bb19ec';

/// See also [MyGroupsNotifier].
@ProviderFor(MyGroupsNotifier)
final myGroupsNotifierProvider =
    NotifierProvider<MyGroupsNotifier, AsyncValue<List<GroupEntity>>>.internal(
      MyGroupsNotifier.new,
      name: r'myGroupsNotifierProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$myGroupsNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$MyGroupsNotifier = Notifier<AsyncValue<List<GroupEntity>>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
