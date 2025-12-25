// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$notificationServiceHash() =>
    r'cda5ea9d196dce85bee56839a4a0f035021752e3';

/// See also [notificationService].
@ProviderFor(notificationService)
final notificationServiceProvider =
    AutoDisposeProvider<NotificationService>.internal(
      notificationService,
      name: r'notificationServiceProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$notificationServiceHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef NotificationServiceRef = AutoDisposeProviderRef<NotificationService>;
String _$notificationDataSourceHash() =>
    r'27437227f019a151f26d5d3757c2fd32b75e2b05';

/// See also [notificationDataSource].
@ProviderFor(notificationDataSource)
final notificationDataSourceProvider =
    AutoDisposeProvider<NotificationRemoteDataSource>.internal(
      notificationDataSource,
      name: r'notificationDataSourceProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$notificationDataSourceHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef NotificationDataSourceRef =
    AutoDisposeProviderRef<NotificationRemoteDataSource>;
String _$notificationsStreamHash() =>
    r'4e1c646ac2ba5a0f67d22b3bd4b1bb6585d759b6';

/// See also [notificationsStream].
@ProviderFor(notificationsStream)
final notificationsStreamProvider =
    AutoDisposeStreamProvider<List<NotificationEntity>>.internal(
      notificationsStream,
      name: r'notificationsStreamProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$notificationsStreamHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef NotificationsStreamRef =
    AutoDisposeStreamProviderRef<List<NotificationEntity>>;
String _$notificationsNotifierHash() =>
    r'ff96d52b455a0a6249e70734268a30f32229b7eb';

/// See also [NotificationsNotifier].
@ProviderFor(NotificationsNotifier)
final notificationsNotifierProvider = AutoDisposeNotifierProvider<
  NotificationsNotifier,
  AsyncValue<List<NotificationEntity>>
>.internal(
  NotificationsNotifier.new,
  name: r'notificationsNotifierProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$notificationsNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$NotificationsNotifier =
    AutoDisposeNotifier<AsyncValue<List<NotificationEntity>>>;
String _$unreadNotificationsCountHash() =>
    r'0528436681602a75643a9b4d967b88de80798455';

/// See also [UnreadNotificationsCount].
@ProviderFor(UnreadNotificationsCount)
final unreadNotificationsCountProvider =
    AutoDisposeNotifierProvider<UnreadNotificationsCount, int>.internal(
      UnreadNotificationsCount.new,
      name: r'unreadNotificationsCountProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$unreadNotificationsCountHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$UnreadNotificationsCount = AutoDisposeNotifier<int>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
