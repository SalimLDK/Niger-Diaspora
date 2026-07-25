// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$eventRemoteDataSourceHash() =>
    r'4438a154ff3f5200e526230271fc08f810bfb735';

/// See also [eventRemoteDataSource].
@ProviderFor(eventRemoteDataSource)
final eventRemoteDataSourceProvider =
    AutoDisposeProvider<EventRemoteDataSource>.internal(
      eventRemoteDataSource,
      name: r'eventRemoteDataSourceProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$eventRemoteDataSourceHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef EventRemoteDataSourceRef =
    AutoDisposeProviderRef<EventRemoteDataSource>;
String _$eventRepositoryHash() => r'7ede4199bc5a7fbef7ce75114daf5d2ffe3b8179';

/// See also [eventRepository].
@ProviderFor(eventRepository)
final eventRepositoryProvider = AutoDisposeProvider<EventRepository>.internal(
  eventRepository,
  name: r'eventRepositoryProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$eventRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef EventRepositoryRef = AutoDisposeProviderRef<EventRepository>;
String _$eventsNotifierHash() => r'03d40170e474c615e2ef52aacf077c5de0c9aa62';

/// See also [EventsNotifier].
@ProviderFor(EventsNotifier)
final eventsNotifierProvider =
    NotifierProvider<EventsNotifier, AsyncValue<List<EventEntity>>>.internal(
      EventsNotifier.new,
      name: r'eventsNotifierProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$eventsNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$EventsNotifier = Notifier<AsyncValue<List<EventEntity>>>;
String _$eventDetailNotifierHash() =>
    r'ba3736433b08f70af79a2f81b8b9184dacd95bd7';

/// See also [EventDetailNotifier].
@ProviderFor(EventDetailNotifier)
final eventDetailNotifierProvider = AutoDisposeNotifierProvider<
  EventDetailNotifier,
  AsyncValue<EventEntity?>
>.internal(
  EventDetailNotifier.new,
  name: r'eventDetailNotifierProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$eventDetailNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$EventDetailNotifier = AutoDisposeNotifier<AsyncValue<EventEntity?>>;
String _$myEventsNotifierHash() => r'113ff3560513b1e4ad41c8d8a6c4324ebabd0f82';

/// See also [MyEventsNotifier].
@ProviderFor(MyEventsNotifier)
final myEventsNotifierProvider =
    NotifierProvider<MyEventsNotifier, AsyncValue<List<EventEntity>>>.internal(
      MyEventsNotifier.new,
      name: r'myEventsNotifierProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$myEventsNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$MyEventsNotifier = Notifier<AsyncValue<List<EventEntity>>>;
String _$pastEventsNotifierHash() =>
    r'eea7cd87b126a9725bcdb7d4384c3faa3cf83f11';

/// See also [PastEventsNotifier].
@ProviderFor(PastEventsNotifier)
final pastEventsNotifierProvider = NotifierProvider<
  PastEventsNotifier,
  AsyncValue<List<EventEntity>>
>.internal(
  PastEventsNotifier.new,
  name: r'pastEventsNotifierProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$pastEventsNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$PastEventsNotifier = Notifier<AsyncValue<List<EventEntity>>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
