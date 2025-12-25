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
