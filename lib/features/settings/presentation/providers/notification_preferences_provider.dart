import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/services/preferences_service.dart';

part 'notification_preferences_provider.g.dart';

/// State class for notification preferences
class NotificationPreferences {
  final bool messagesEnabled;
  final bool eventsEnabled;
  final bool friendRequestsEnabled;
  final bool groupsEnabled;
  final bool eventRemindersEnabled;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final bool quietHoursEnabled;
  final int quietHoursStartHour;
  final int quietHoursStartMinute;
  final int quietHoursEndHour;
  final int quietHoursEndMinute;

  const NotificationPreferences({
    required this.messagesEnabled,
    required this.eventsEnabled,
    required this.friendRequestsEnabled,
    required this.groupsEnabled,
    required this.eventRemindersEnabled,
    required this.soundEnabled,
    required this.vibrationEnabled,
    required this.quietHoursEnabled,
    required this.quietHoursStartHour,
    required this.quietHoursStartMinute,
    required this.quietHoursEndHour,
    required this.quietHoursEndMinute,
  });

  NotificationPreferences copyWith({
    bool? messagesEnabled,
    bool? eventsEnabled,
    bool? friendRequestsEnabled,
    bool? groupsEnabled,
    bool? eventRemindersEnabled,
    bool? soundEnabled,
    bool? vibrationEnabled,
    bool? quietHoursEnabled,
    int? quietHoursStartHour,
    int? quietHoursStartMinute,
    int? quietHoursEndHour,
    int? quietHoursEndMinute,
  }) {
    return NotificationPreferences(
      messagesEnabled: messagesEnabled ?? this.messagesEnabled,
      eventsEnabled: eventsEnabled ?? this.eventsEnabled,
      friendRequestsEnabled:
          friendRequestsEnabled ?? this.friendRequestsEnabled,
      groupsEnabled: groupsEnabled ?? this.groupsEnabled,
      eventRemindersEnabled:
          eventRemindersEnabled ?? this.eventRemindersEnabled,
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
      messagesEnabled: _prefs.notifyMessages,
      eventsEnabled: _prefs.notifyEvents,
      friendRequestsEnabled: _prefs.notifyFriendRequests,
      groupsEnabled: _prefs.notifyGroups,
      eventRemindersEnabled: _prefs.notifyEventReminders,
      soundEnabled: _prefs.notificationSound,
      vibrationEnabled: _prefs.notificationVibration,
      quietHoursEnabled: _prefs.quietHoursEnabled,
      quietHoursStartHour: _prefs.quietHoursStartHour,
      quietHoursStartMinute: _prefs.quietHoursStartMinute,
      quietHoursEndHour: _prefs.quietHoursEndHour,
      quietHoursEndMinute: _prefs.quietHoursEndMinute,
    );
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
