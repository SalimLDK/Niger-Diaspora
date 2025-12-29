import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/network/network_info.dart';
import '../../data/datasources/event_remote_datasource.dart';
import '../../data/repositories/event_repository_impl.dart';
import '../../domain/entities/event_entity.dart';
import '../../domain/repositories/event_repository.dart';

part 'event_provider.g.dart';

@riverpod
EventRemoteDataSource eventRemoteDataSource(Ref ref) {
  return EventRemoteDataSourceImpl();
}

@riverpod
EventRepository eventRepository(Ref ref) {
  return EventRepositoryImpl(
    remoteDataSource: ref.watch(eventRemoteDataSourceProvider),
    networkInfo: ref.watch(networkInfoProvider),
  );
}

@Riverpod(keepAlive: true)
class EventsNotifier extends _$EventsNotifier {
  @override
  AsyncValue<List<EventEntity>> build() {
    loadUpcomingEvents();
    return const AsyncValue.loading();
  }

  Future<void> loadUpcomingEvents() async {
    final repository = ref.read(eventRepositoryProvider);

    // 1. Try to load from cache first (Cache-First Strategy)
    final cachedResult = repository.getCachedEvents();
    cachedResult.fold(
      (failure) {
        // Cache miss or error - show loading
        state = const AsyncValue.loading();
      },
      (cachedEvents) {
        if (cachedEvents.isNotEmpty) {
          // Filter upcoming events from cache
          final now = DateTime.now();
          final upcomingCached =
              cachedEvents.where((e) => e.startDate.isAfter(now)).toList();

          if (upcomingCached.isNotEmpty) {
            state = AsyncValue.data(upcomingCached);
          } else {
            state = const AsyncValue.loading();
          }
        } else {
          state = const AsyncValue.loading();
        }
      },
    );

    // 2. Fetch from network
    final result = await repository.getUpcomingEvents();
    result.fold((failure) {
      // Only update to error if we don't have cached data
      if (state.valueOrNull == null || state.valueOrNull!.isEmpty) {
        state = AsyncValue.error(failure.message, StackTrace.current);
      }
    }, (events) => state = AsyncValue.data(events));
  }

  Future<void> loadEventsByCategory(EventCategory category) async {
    state = const AsyncValue.loading();
    final repository = ref.read(eventRepositoryProvider);
    final result = await repository.getEventsByCategory(category);
    result.fold(
      (failure) =>
          state = AsyncValue.error(failure.message, StackTrace.current),
      (events) => state = AsyncValue.data(events),
    );
  }

  Future<void> refresh() async {
    await loadUpcomingEvents();
  }
}

@riverpod
class EventDetailNotifier extends _$EventDetailNotifier {
  @override
  AsyncValue<EventEntity?> build() {
    return const AsyncValue.data(null);
  }

  Future<void> loadEvent(String eventId) async {
    state = const AsyncValue.loading();
    final repository = ref.read(eventRepositoryProvider);
    final result = await repository.getEventById(eventId);
    result.fold(
      (failure) =>
          state = AsyncValue.error(failure.message, StackTrace.current),
      (event) => state = AsyncValue.data(event),
    );
  }

  Future<bool> attendEvent(String eventId, String userId) async {
    final repository = ref.read(eventRepositoryProvider);
    final result = await repository.attendEvent(eventId, userId);
    return result.fold((failure) => false, (_) {
      loadEvent(eventId);
      return true;
    });
  }

  Future<bool> cancelAttendance(String eventId, String userId) async {
    final repository = ref.read(eventRepositoryProvider);
    final result = await repository.cancelAttendance(eventId, userId);
    return result.fold((failure) => false, (_) {
      loadEvent(eventId);
      return true;
    });
  }
}

@Riverpod(keepAlive: true)
class MyEventsNotifier extends _$MyEventsNotifier {
  @override
  AsyncValue<List<EventEntity>> build() {
    final user = ref.watch(currentUserProvider).valueOrNull;
    if (user != null) {
      loadMyEvents(user.id);
    }
    return const AsyncValue.data([]);
  }

  Future<void> loadMyEvents(String userId) async {
    state = const AsyncValue.loading();
    final repository = ref.read(eventRepositoryProvider);
    final result = await repository.getMyEvents(userId);
    result.fold(
      (failure) =>
          state = AsyncValue.error(failure.message, StackTrace.current),
      (events) => state = AsyncValue.data(events),
    );
  }

  Future<bool> createEvent(EventEntity event) async {
    final repository = ref.read(eventRepositoryProvider);
    final result = await repository.createEvent(event);
    return result.fold((failure) => false, (created) {
      final currentEvents = state.valueOrNull ?? [];
      state = AsyncValue.data([created, ...currentEvents]);
      return true;
    });
  }

  Future<bool> deleteEvent(String eventId) async {
    final repository = ref.read(eventRepositoryProvider);
    final result = await repository.deleteEvent(eventId);
    return result.fold((failure) => false, (_) {
      final currentEvents = state.valueOrNull ?? [];
      state = AsyncValue.data(
        currentEvents.where((e) => e.id != eventId).toList(),
      );
      return true;
    });
  }

  Future<bool> updateEvent(EventEntity event) async {
    final repository = ref.read(eventRepositoryProvider);
    final result = await repository.updateEvent(event);
    return result.fold((failure) => false, (updated) {
      final currentEvents = state.valueOrNull ?? [];
      state = AsyncValue.data(
        currentEvents.map((e) => e.id == updated.id ? updated : e).toList(),
      );
      return true;
    });
  }
}

@Riverpod(keepAlive: true)
class PastEventsNotifier extends _$PastEventsNotifier {
  @override
  AsyncValue<List<EventEntity>> build() {
    loadPastEvents();
    return const AsyncValue.loading();
  }

  Future<void> loadPastEvents() async {
    state = const AsyncValue.loading();
    final repository = ref.read(eventRepositoryProvider);
    final result = await repository.getPastEvents();
    result.fold(
      (failure) =>
          state = AsyncValue.error(failure.message, StackTrace.current),
      (events) => state = AsyncValue.data(events),
    );
  }

  Future<void> loadPastEventsByCategory(EventCategory category) async {
    state = const AsyncValue.loading();
    final repository = ref.read(eventRepositoryProvider);
    final result = await repository.getPastEvents();
    result.fold(
      (failure) =>
          state = AsyncValue.error(failure.message, StackTrace.current),
      (events) {
        final filtered = events.where((e) => e.category == category).toList();
        state = AsyncValue.data(filtered);
      },
    );
  }

  Future<void> refresh() async {
    await loadPastEvents();
  }
}
