import 'package:riverpod_annotation/riverpod_annotation.dart';
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
  /// réglage, et il écrit ses deux étages.
  ///
  /// Il n'en écrivait qu'un. Or le commutateur vit à deux endroits qui
  /// décident chacun d'autre chose : la préférence locale décide de
  /// l'**affichage** (`notification_service.dart` la lit avant de montrer une
  /// notification) et la colonne `public.users.notifications_enabled` décide
  /// de l'**envoi** (l'Edge Function send-push la lit avant tout FCM). Couper
  /// depuis les réglages n'éteignait donc que l'affichage : le serveur
  /// continuait d'envoyer.
  ///
  /// Il y avait un troisième étage, l'abonnement au topic FCM `general` :
  /// retiré, aucun back-end n'émet vers un topic (voir `subscribeToTopic`).
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
  }

  /// Recopie **toutes** les préférences par type dans
  /// `users.notification_prefs`, seule version que `send-push` consulte.
  ///
  /// Appelé après chaque bascule : la préférence locale ne décide que de
  /// l'affichage au premier plan (`_shouldShowNotification`), pas de l'envoi.
  /// Sans cette recopie, couper « Messages » ne coupait rien dès que l'app
  /// était fermée. On envoie la carte entière plutôt que la clé touchée : elle
  /// est petite, et ça réconcilie au passage un appareil désynchronisé.
  Future<void> _syncTypePrefsToServer() async {
    final userId = ref.read(currentUserAsyncProvider).valueOrNull?.id;
    if (userId == null) return;
    try {
      await ref
          .read(profileRemoteDataSourceProvider)
          .updateNotificationPrefs(userId, _prefs.notificationTypePrefs);
    } catch (_) {
      // Best effort : la préférence locale est déjà écrite, l'appareil se
      // resynchronisera à la bascule suivante.
    }
  }

  Future<void> setMessagesEnabled(bool enabled) async {
    await _prefs.setNotifyMessages(enabled);
    state = state.copyWith(messagesEnabled: enabled);
    await _syncTypePrefsToServer();
  }

  Future<void> setEventsEnabled(bool enabled) async {
    await _prefs.setNotifyEvents(enabled);
    state = state.copyWith(eventsEnabled: enabled);
    await _syncTypePrefsToServer();
  }

  Future<void> setFriendRequestsEnabled(bool enabled) async {
    await _prefs.setNotifyFriendRequests(enabled);
    state = state.copyWith(friendRequestsEnabled: enabled);
    await _syncTypePrefsToServer();
  }

  Future<void> setGroupsEnabled(bool enabled) async {
    await _prefs.setNotifyGroups(enabled);
    state = state.copyWith(groupsEnabled: enabled);
    await _syncTypePrefsToServer();
  }

  Future<void> setEventRemindersEnabled(bool enabled) async {
    await _prefs.setNotifyEventReminders(enabled);
    state = state.copyWith(eventRemindersEnabled: enabled);
    await _syncTypePrefsToServer();
  }

  Future<void> setLocalEventsEnabled(bool enabled) async {
    await _prefs.setNotifyLocalEvents(enabled);
    state = state.copyWith(localEventsEnabled: enabled);

    // Colonne dédiée : les requêtes serveur ciblent les destinataires par
    // `notify_local_events`, elles ne fouillent pas le JSONB.
    final userId = ref.read(currentUserAsyncProvider).valueOrNull?.id;
    if (userId != null) {
      final datasource = ref.read(profileRemoteDataSourceProvider);
      await datasource.updateNotifyLocalEvents(userId, enabled);
    }
    await _syncTypePrefsToServer();
  }

  Future<void> setSystemMessagesEnabled(bool enabled) async {
    await _prefs.setNotifySystemMessages(enabled);
    state = state.copyWith(systemMessagesEnabled: enabled);
    await _syncTypePrefsToServer();
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
