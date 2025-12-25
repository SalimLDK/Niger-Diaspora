// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_preferences_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$notificationPreferencesDataSourceHash() =>
    r'f4d4f3289feaf7d771ac28fe20bafae2ace5b45e';

/// See also [notificationPreferencesDataSource].
@ProviderFor(notificationPreferencesDataSource)
final notificationPreferencesDataSourceProvider =
    AutoDisposeProvider<NotificationPreferencesDataSource>.internal(
      notificationPreferencesDataSource,
      name: r'notificationPreferencesDataSourceProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$notificationPreferencesDataSourceHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef NotificationPreferencesDataSourceRef =
    AutoDisposeProviderRef<NotificationPreferencesDataSource>;
String _$notificationPreferencesRepositoryHash() =>
    r'6a6d26bd1c9be0602190f03ff520c2b87d68168f';

/// See also [notificationPreferencesRepository].
@ProviderFor(notificationPreferencesRepository)
final notificationPreferencesRepositoryProvider =
    AutoDisposeProvider<NotificationPreferencesRepository>.internal(
      notificationPreferencesRepository,
      name: r'notificationPreferencesRepositoryProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$notificationPreferencesRepositoryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef NotificationPreferencesRepositoryRef =
    AutoDisposeProviderRef<NotificationPreferencesRepository>;
String _$notificationPreferencesNotifierHash() =>
    r'c41818c35a8cb7b94f1a13e456cd50412f5e4dd1';

/// See also [NotificationPreferencesNotifier].
@ProviderFor(NotificationPreferencesNotifier)
final notificationPreferencesNotifierProvider = AutoDisposeNotifierProvider<
  NotificationPreferencesNotifier,
  AsyncValue<NotificationPreferencesEntity>
>.internal(
  NotificationPreferencesNotifier.new,
  name: r'notificationPreferencesNotifierProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$notificationPreferencesNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$NotificationPreferencesNotifier =
    AutoDisposeNotifier<AsyncValue<NotificationPreferencesEntity>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
