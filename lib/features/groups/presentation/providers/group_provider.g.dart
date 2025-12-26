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
String _$groupRepositoryHash() => r'3abceba78d0e12c1a11ab00bed320cd5902aed44';

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

String _$groupsNotifierHash() => r'402dd3221aa2dbddf1cb000cc013e8efa57fa184';

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
String _$myGroupsNotifierHash() => r'628ed5dc5104ac80b236e8660793596ee49f85b9';

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
