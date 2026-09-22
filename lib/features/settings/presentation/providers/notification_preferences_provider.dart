import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/services/logger_service.dart';
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

  /// Le texte du message dans la notification. Coupé : « Nouveau message ».
  final bool messagePreviewEnabled;
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
    this.messagePreviewEnabled = true,
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
    bool? messagePreviewEnabled,
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
      messagePreviewEnabled:
          messagePreviewEnabled ?? this.messagePreviewEnabled,
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
      messagePreviewEnabled: _prefs.showMessagePreview,
      soundEnabled: _prefs.notificationSound,
      vibrationEnabled: _prefs.notificationVibration,
      quietHoursEnabled: _prefs.quietHoursEnabled,
      quietHoursStartHour: _prefs.quietHoursStartHour,
      quietHoursStartMinute: _prefs.quietHoursStartMinute,
      quietHoursEndHour: _prefs.quietHoursEndHour,
      quietHoursEndMinute: _prefs.quietHoursEndMinute,
    );
  }

  /// Une écriture à la fois.
  ///
  /// Chaque écriture qui échoue **revient à la valeur d'avant** — et cette
  /// valeur n'a de sens que si aucune autre écriture n'est en vol. Sans file,
  /// deux bascules rapides sur un réseau lent, dont la première échoue,
  /// laissaient le local et le serveur en désaccord : la seconde envoie la carte
  /// ENTIÈRE, donc la première bascule avec elle, puis la première revient en
  /// arrière sur le local seul.
  ///
  /// La file continue même si un travail lève : une exception ne doit jamais
  /// bloquer les écritures suivantes.
  Future<void> _queue = Future<void>.value();

  Future<bool> _serialized(Future<bool> Function() job) {
    final result = _queue.then((_) => job());
    _queue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
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
  ///
  /// Rend `false` si l'étage serveur a échoué, et **remet alors les deux étages
  /// d'accord sur la valeur d'avant**. Sans ce retour en arrière, l'étage local
  /// restait écrit : l'interrupteur affichait « désactivé » et masquait les
  /// notifications au premier plan, pendant que la colonne lue par `send-push`
  /// gardait « activé » et que le back-end continuait de pousser vers un
  /// téléphone dont l'utilisateur croyait avoir coupé le son. Trois sorties
  /// muettes menaient là — profil introuvable, `updateProfile` qui pose une
  /// erreur au lieu de lever, exception — et aucune n'avait de `try/catch`.
  ///
  /// C'est à l'écran de dire l'échec (`reportIfFailed`) ; rendre un booléen
  /// plutôt que lever, parce que l'appel se fait en `unawaited(...)`.
  Future<bool> setMasterEnabled(bool enabled) => _serialized(() async {
    final before = state.masterEnabled;
    await _prefs.setNotificationsEnabled(enabled);
    state = state.copyWith(masterEnabled: enabled);

    // Étage serveur : sans lui, le back-end continue de pousser.
    try {
      final userId = (await ref.read(currentUserAsyncProvider.future))?.id;
      if (userId != null) {
        final notifier = ref.read(profileNotifierProvider(userId).notifier);
        final profile = await notifier.currentProfile();
        if (profile == null) {
          throw StateError('Profil introuvable : étage serveur non écrit');
        }
        await notifier.updateProfile(
          profile.copyWith(notificationsEnabled: enabled),
        );
        // `updateProfile` pose une erreur au lieu de lever.
        if (ref.read(profileNotifierProvider(userId)).hasError) {
          throw StateError('Écriture de notifications_enabled refusée');
        }
      }
      return true;
    } catch (e, s) {
      LoggerService.w('NotificationPreferences.setMasterEnabled: échec', e, s);
      await _rollback(() async {
        await _prefs.setNotificationsEnabled(before);
        state = state.copyWith(masterEnabled: before);
      });
      return false;
    }
  });

  /// Retour en arrière d'une écriture refusée. Ne lève jamais : si le
  /// notifier a été libéré entre-temps, personne n'affiche plus cet état.
  Future<void> _rollback(Future<void> Function() undo) async {
    try {
      await undo();
    } catch (e, s) {
      LoggerService.w('NotificationPreferences: retour arrière impossible', e, s);
    }
  }

  /// Recopie **toutes** les préférences par type dans
  /// `users.notification_prefs`, seule version que `send-push` consulte — et,
  /// pour un réglage qui en a une, dans sa colonne dédiée [writeColumn].
  ///
  /// La préférence locale ne décide que de l'affichage au premier plan
  /// (`_shouldShowNotification`), pas de l'envoi. Sans cette recopie, couper
  /// « Messages » ne coupait rien dès que l'app était fermée. On envoie la
  /// carte entière plutôt que la clé touchée : elle est petite, et ça
  /// réconcilie au passage un appareil désynchronisé.
  ///
  /// **Lève si le serveur refuse.** Elle avalait l'échec (« Best effort : la
  /// préférence locale est déjà écrite, l'appareil se resynchronisera à la
  /// bascule suivante »). Or l'utilisateur qui voit « Messages » sur
  /// « désactivé » ne rebascule pas : local et serveur restaient en désaccord,
  /// sans un signal, et le back-end continuait de pousser.
  ///
  /// Deux écritures (colonne, puis carte) ne sont pas atomiques : si la carte
  /// échoue après la colonne, on **remet la colonne**, sinon c'est elle qui
  /// diverge de la préférence locale, revenue en arrière.
  Future<void> _writeToServer({
    required bool enabled,
    required bool before,
    Future<void> Function(String userId, bool value)? writeColumn,
  }) async {
    final userId = (await ref.read(currentUserAsyncProvider.future))?.id;
    // Pas de compte : rien à synchroniser, la préférence reste locale.
    if (userId == null) return;

    if (writeColumn != null) await writeColumn(userId, enabled);
    try {
      await ref
          .read(profileRemoteDataSourceProvider)
          .updateNotificationPrefs(userId, _prefs.notificationTypePrefs);
    } catch (_) {
      if (writeColumn != null) {
        await _rollback(() => writeColumn(userId, before));
      }
      rethrow;
    }
  }

  /// Un réglage par type : préférence locale d'abord (l'interrupteur suit le
  /// doigt), puis serveur. Si le serveur refuse, **retour à la valeur d'avant**
  /// des deux côtés et `false` — voir [_writeToServer].
  Future<bool> _setTypePref(
    bool enabled, {
    required bool Function(NotificationPreferences) read,
    required Future<void> Function(bool) writeLocal,
    required NotificationPreferences Function(NotificationPreferences, bool)
    apply,
    Future<void> Function(String userId, bool value)? writeColumn,
  }) => _serialized(() async {
    final before = read(state);
    await writeLocal(enabled);
    state = apply(state, enabled);
    try {
      await _writeToServer(
        enabled: enabled,
        before: before,
        writeColumn: writeColumn,
      );
      return true;
    } catch (e, s) {
      LoggerService.w(
        'NotificationPreferences: écriture serveur refusée, retour arrière',
        e,
        s,
      );
      await _rollback(() async {
        await writeLocal(before);
        state = apply(state, before);
      });
      return false;
    }
  });

  Future<bool> setMessagesEnabled(bool enabled) => _setTypePref(
    enabled,
    read: (s) => s.messagesEnabled,
    writeLocal: _prefs.setNotifyMessages,
    apply: (s, v) => s.copyWith(messagesEnabled: v),
  );

  Future<bool> setEventsEnabled(bool enabled) => _setTypePref(
    enabled,
    read: (s) => s.eventsEnabled,
    writeLocal: _prefs.setNotifyEvents,
    apply: (s, v) => s.copyWith(eventsEnabled: v),
  );

  Future<bool> setFriendRequestsEnabled(bool enabled) => _setTypePref(
    enabled,
    read: (s) => s.friendRequestsEnabled,
    writeLocal: _prefs.setNotifyFriendRequests,
    apply: (s, v) => s.copyWith(friendRequestsEnabled: v),
  );

  Future<bool> setGroupsEnabled(bool enabled) => _setTypePref(
    enabled,
    read: (s) => s.groupsEnabled,
    writeLocal: _prefs.setNotifyGroups,
    apply: (s, v) => s.copyWith(groupsEnabled: v),
  );

  Future<bool> setEventRemindersEnabled(bool enabled) => _setTypePref(
    enabled,
    read: (s) => s.eventRemindersEnabled,
    writeLocal: _prefs.setNotifyEventReminders,
    apply: (s, v) => s.copyWith(eventRemindersEnabled: v),
  );

  Future<bool> setLocalEventsEnabled(bool enabled) => _setTypePref(
    enabled,
    read: (s) => s.localEventsEnabled,
    writeLocal: _prefs.setNotifyLocalEvents,
    apply: (s, v) => s.copyWith(localEventsEnabled: v),
    // Colonne dédiée : les requêtes serveur ciblent les destinataires par
    // `notify_local_events`, elles ne fouillent pas le JSONB.
    writeColumn: (userId, value) => ref
        .read(profileRemoteDataSourceProvider)
        .updateNotifyLocalEvents(userId, value),
  );

  Future<bool> setSystemMessagesEnabled(bool enabled) => _setTypePref(
    enabled,
    read: (s) => s.systemMessagesEnabled,
    writeLocal: _prefs.setNotifySystemMessages,
    apply: (s, v) => s.copyWith(systemMessagesEnabled: v),
  );

  /// Aperçu du texte dans les notifications de message.
  ///
  /// Le serveur l'appliquait déjà (`send-push` remplace le texte par
  /// « Nouveau message » quand `show_message_preview` est faux, et l'appareil
  /// ne reconstruit alors pas l'aperçu chiffré) — mais aucun écran ne
  /// permettait de le changer. Constaté le 2026-09-21.
  Future<bool> setMessagePreviewEnabled(bool enabled) => _setTypePref(
    enabled,
    read: (s) => s.messagePreviewEnabled,
    writeLocal: _prefs.setShowMessagePreview,
    apply: (s, v) => s.copyWith(messagePreviewEnabled: v),
    writeColumn: (userId, value) => ref
        .read(profileRemoteDataSourceProvider)
        .updateShowMessagePreview(userId, value),
  );

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
