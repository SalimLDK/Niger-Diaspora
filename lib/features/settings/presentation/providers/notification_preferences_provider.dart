import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/notification_preferences_datasource.dart';
import '../../data/repositories/notification_preferences_repository_impl.dart';
import '../../domain/entities/notification_preferences_entity.dart';
import '../../domain/repositories/notification_preferences_repository.dart';

part 'notification_preferences_provider.g.dart';

@riverpod
NotificationPreferencesDataSource notificationPreferencesDataSource(
  Ref ref,
) {
  return NotificationPreferencesDataSourceImpl();
}

@riverpod
NotificationPreferencesRepository notificationPreferencesRepository(
  Ref ref,
) {
  return NotificationPreferencesRepositoryImpl(
    dataSource: ref.watch(notificationPreferencesDataSourceProvider),
  );
}

@riverpod
class NotificationPreferencesNotifier extends _$NotificationPreferencesNotifier {
  @override
  AsyncValue<NotificationPreferencesEntity> build() {
    _loadPreferences();
    return const AsyncValue.loading();
  }

  Future<void> _loadPreferences() async {
    final currentUser = ref.read(currentUserProvider).valueOrNull;
    if (currentUser == null) {
      state = const AsyncValue.data(NotificationPreferencesEntity());
      return;
    }

    final repository = ref.read(notificationPreferencesRepositoryProvider);
    final result = await repository.getPreferences(currentUser.id);

    result.fold(
      (failure) => state = AsyncValue.error(failure.message, StackTrace.current),
      (prefs) => state = AsyncValue.data(prefs),
    );
  }

  Future<void> reload() async {
    state = const AsyncValue.loading();
    await _loadPreferences();
  }

  Future<bool> updateMessages(bool value) async {
    return _updatePreference((current) => NotificationPreferencesEntity(
          messages: value,
          newEvents: current.newEvents,
          groupActivity: current.groupActivity,
          eventReminders: current.eventReminders,
        ));
  }

  Future<bool> updateNewEvents(bool value) async {
    return _updatePreference((current) => NotificationPreferencesEntity(
          messages: current.messages,
          newEvents: value,
          groupActivity: current.groupActivity,
          eventReminders: current.eventReminders,
        ));
  }

  Future<bool> updateGroupActivity(bool value) async {
    return _updatePreference((current) => NotificationPreferencesEntity(
          messages: current.messages,
          newEvents: current.newEvents,
          groupActivity: value,
          eventReminders: current.eventReminders,
        ));
  }

  Future<bool> updateEventReminders(bool value) async {
    return _updatePreference((current) => NotificationPreferencesEntity(
          messages: current.messages,
          newEvents: current.newEvents,
          groupActivity: current.groupActivity,
          eventReminders: value,
        ));
  }

  Future<bool> _updatePreference(
    NotificationPreferencesEntity Function(NotificationPreferencesEntity current) updater,
  ) async {
    final currentUser = ref.read(currentUserProvider).valueOrNull;
    if (currentUser == null) return false;

    final currentPrefs = state.valueOrNull ?? const NotificationPreferencesEntity();
    final newPrefs = updater(currentPrefs);

    // Optimistic update
    state = AsyncValue.data(newPrefs);

    final repository = ref.read(notificationPreferencesRepositoryProvider);
    final result = await repository.updatePreferences(currentUser.id, newPrefs);

    return result.fold(
      (failure) {
        // Revert on failure
        state = AsyncValue.data(currentPrefs);
        return false;
      },
      (_) => true,
    );
  }
}
