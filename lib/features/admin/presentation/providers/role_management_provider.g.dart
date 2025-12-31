// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'role_management_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$roleManagementNotifierHash() =>
    r'bd87aca9424d77edb85dbaaf69f161249951142f';

/// Provider pour gérer les rôles admin (SuperAdmin uniquement)
///
/// Copied from [RoleManagementNotifier].
@ProviderFor(RoleManagementNotifier)
final roleManagementNotifierProvider = AutoDisposeNotifierProvider<
  RoleManagementNotifier,
  RoleManagementState
>.internal(
  RoleManagementNotifier.new,
  name: r'roleManagementNotifierProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$roleManagementNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$RoleManagementNotifier = AutoDisposeNotifier<RoleManagementState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
