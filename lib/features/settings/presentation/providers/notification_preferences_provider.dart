import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/preferences_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';

part 'notification_preferences_provider.g.dart';

/// State class for notification preferences
class NotificationPreferences {
  final bool masterEnabled;
  final bool messagesEnabled;
  final bool eventsEnabled;
  final bool friendRequestsEnabled;
  final bool groupsEnabled;
  final bool eventRemindersEnabled;
  final bool localEventsEnabled;
  final bool systemMessagesEnabled;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final bool quietHoursEnabled;
  final int quietHoursStartHour;
  final int quietHoursStartMinute;
  final int quietHoursEndHour;
  final int quietHoursEndMinute;

  const NotificationPreferences({
    required this.masterEnabled,
    required this.messagesEnabled,
    required this.eventsEnabled,
    required this.friendRequestsEnabled,
    required this.groupsEnabled,
    required this.eventRemindersEnabled,
    required this.localEventsEnabled,
    required this.systemMessagesEnabled,
    required this.soundEnabled,
    required this.vibrationEnabled,
    required this.quietHoursEnabled,
    required this.quietHoursStartHour,
    required this.quietHoursStartMinute,
    required this.quietHoursEndHour,
    required this.quietHoursEndMinute,
  });

  NotificationPreferences copyWith({
    bool? masterEnabled,
    bool? messagesEnabled,
    bool? eventsEnabled,
    bool? friendRequestsEnabled,
    bool? groupsEnabled,
    bool? eventRemindersEnabled,
    bool? localEventsEnabled,
    bool? systemMessagesEnabled,
    bool? soundEnabled,
    bool? vibrationEnabled,
    bool? quietHoursEnabled,
    int? quietHoursStartHour,
    int? quietHoursStartMinute,
    int? quietHoursEndHour,
    int? quietHoursEndMinute,
  }) {
    return NotificationPreferences(
      masterEnabled: masterEnabled ?? this.masterEnabled,
      messagesEnabled: messagesEnabled ?? this.messagesEnabled,
      eventsEnabled: eventsEnabled ?? this.eventsEnabled,
      friendRequestsEnabled:
          friendRequestsEnabled ?? this.friendRequestsEnabled,
      groupsEnabled: groupsEnabled ?? this.groupsEnabled,
      eventRemindersEnabled:
          eventRemindersEnabled ?? this.eventRemindersEnabled,
      localEventsEnabled: localEventsEnabled ?? this.localEventsEnabled,
      systemMessagesEnabled:
          systemMessagesEnabled ?? this.systemMessagesEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietHoursStartHour: quietHoursStartHour ?? this.quietHoursStartHour,
      quietHoursStartMinute:
          quietHoursStartMinute ?? this.quietHoursStartMinute,
      quietHoursEndHour: quietHoursEndHour ?? this.quietHoursEndHour,
      quietHoursEndMinute: quietHoursEndMinute ?? this.quietHoursEndMinute,
    );
  }
}

@riverpod
class NotificationPreferencesNotifier
    extends _$NotificationPreferencesNotifier {
  final _prefs = PreferencesService.instance;

  @override
  NotificationPreferences build() {
    return NotificationPreferences(
      masterEnabled: _prefs.notificationsEnabled,
      messagesEnabled: _prefs.notifyMessages,
      eventsEnabled: _prefs.notifyEvents,
      friendRequestsEnabled: _prefs.notifyFriendRequests,
      groupsEnabled: _prefs.notifyGroups,
      eventRemindersEnabled: _prefs.notifyEventReminders,
      localEventsEnabled: _prefs.notifyLocalEvents,
      systemMessagesEnabled: _prefs.notifySystemMessages,
      soundEnabled: _prefs.notificationSound,
      vibrationEnabled: _prefs.notificationVibration,
      quietHoursEnabled: _prefs.quietHoursEnabled,
      quietHoursStartHour: _prefs.quietHoursStartHour,
      quietHoursStartMinute: _prefs.quietHoursStartMinute,
      quietHoursEndHour: _prefs.quietHoursEndHour,
      quietHoursEndMinute: _prefs.quietHoursEndMinute,
    );
  }

  /// Interrupteur maître des notifications — **seul propriétaire** de ce
  /// réglage, et il écrit ses trois étages.
  ///
  /// Il n'en écrivait qu'un. Or le commutateur vit à trois endroits qui
  /// décident chacun d'autre chose : la préférence locale décide de
  /// l'**affichage** (`notification_service.dart` la lit avant de montrer une
  /// notification), la colonne Supabase `notifications_enabled` décide de
  /// l'**envoi** (`functions/supabase.js` la sélectionne pour filtrer les
  /// destinataires), et le topic FCM `general` décide de la réception des
  /// diffusions. Couper depuis les réglages n'éteignait donc que l'affichage :
  /// le serveur continuait d'envoyer, et l'appareil de recevoir.
  Future<void> setMasterEnabled(bool enabled) async {
    await _prefs.setNotificationsEnabled(enabled);
    state = state.copyWith(masterEnabled: enabled);

    // Étage serveur : sans lui, le back-end continue de pousser.
    final userId = ref.read(currentUserAsyncProvider).valueOrNull?.id;
    if (userId != null) {
      final profile = ref.read(profileNotifierProvider(userId)).valueOrNull;
      if (profile != null) {
        await ref
            .read(profileNotifierProvider(userId).notifier)
            .updateProfile(profile.copyWith(notificationsEnabled: enabled));
      }
    }

    // Étage diffusion.
    if (enabled) {
      await NotificationService().subscribeToTopic('general');
    } else {
      await NotificationService().unsubscribeFromTopic('general');
    }
  }

  Future<void> setMessagesEnabled(bool enabled) async {
    await _prefs.setNotifyMessages(enabled);
    state = state.copyWith(messagesEnabled: enabled);
  }

  Future<void> setEventsEnabled(bool enabled) async {
    await _prefs.setNotifyEvents(enabled);
    state = state.copyWith(eventsEnabled: enabled);
  }

  Future<void> setFriendRequestsEnabled(bool enabled) async {
    await _prefs.setNotifyFriendRequests(enabled);
    state = state.copyWith(friendRequestsEnabled: enabled);
  }

  Future<void> setGroupsEnabled(bool enabled) async {
    await _prefs.setNotifyGroups(enabled);
    state = state.copyWith(groupsEnabled: enabled);
  }

  Future<void> setEventRemindersEnabled(bool enabled) async {
    await _prefs.setNotifyEventReminders(enabled);
    state = state.copyWith(eventRemindersEnabled: enabled);
  }

  Future<void> setLocalEventsEnabled(bool enabled) async {
    await _prefs.setNotifyLocalEvents(enabled);
    state = state.copyWith(localEventsEnabled: enabled);

    // Sync to Firestore for Cloud Function queries
    final userId = ref.read(currentUserProvider).valueOrNull?.id;
    if (userId != null) {
      final datasource = ref.read(profileRemoteDataSourceProvider);
      await datasource.updateNotifyLocalEvents(userId, enabled);
    }
  }

  Future<void> setSystemMessagesEnabled(bool enabled) async {
    await _prefs.setNotifySystemMessages(enabled);
    state = state.copyWith(systemMessagesEnabled: enabled);
  }

  Future<void> setSoundEnabled(bool enabled) async {
    await _prefs.setNotificationSound(enabled);
    state = state.copyWith(soundEnabled: enabled);
  }

  Future<void> setVibrationEnabled(bool enabled) async {
    await _prefs.setNotificationVibration(enabled);
    state = state.copyWith(vibrationEnabled: enabled);
  }

  Future<void> setQuietHoursEnabled(bool enabled) async {
    await _prefs.setQuietHoursEnabled(enabled);
    state = state.copyWith(quietHoursEnabled: enabled);
  }

  Future<void> setQuietHoursStartTime(int hour, int minute) async {
    await _prefs.setQuietHoursStartHour(hour);
    await _prefs.setQuietHoursStartMinute(minute);
    state = state.copyWith(
      quietHoursStartHour: hour,
      quietHoursStartMinute: minute,
    );
  }

  Future<void> setQuietHoursEndTime(int hour, int minute) async {
    await _prefs.setQuietHoursEndHour(hour);
    await _prefs.setQuietHoursEndMinute(minute);
    state = state.copyWith(
      quietHoursEndHour: hour,
      quietHoursEndMinute: minute,
    );
  }
}
