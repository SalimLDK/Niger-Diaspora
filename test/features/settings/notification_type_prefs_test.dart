import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:diaspo_niger/core/services/preferences_service.dart';
import 'package:diaspo_niger/features/auth/domain/entities/user_entity.dart';
import 'package:diaspo_niger/features/auth/presentation/providers/auth_provider.dart';
import 'package:diaspo_niger/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:diaspo_niger/features/profile/presentation/providers/profile_provider.dart';
import 'package:diaspo_niger/features/settings/presentation/providers/notification_preferences_provider.dart';

/// Réglages de notifications **par type** : local et serveur ne divergent plus
/// sans signal.
///
/// La carte `users.notification_prefs` est la seule version que `send-push`
/// consulte ; la préférence locale ne décide que de l'affichage au premier
/// plan. `_syncTypePrefsToServer` avalait l'échec (« Best effort : l'appareil se
/// resynchronisera à la bascule suivante »). Or un utilisateur qui voit
/// « Messages » sur « désactivé » ne rebascule pas : le back-end continuait de
/// pousser, sans un signal. Et `setLocalEventsEnabled`, qui écrit une colonne
/// dédiée PUIS la carte, n'avait aucun `try/catch` : l'échec remontait à un
/// appelant en `unawaited`, préférence locale déjà changée.
///
/// Chaque écriture rend maintenant `false` si le serveur a refusé, et revient
/// à la valeur d'avant des deux côtés.
class _FauxServeur implements ProfileRemoteDataSource {
  /// Vérité « serveur » : dernière carte acceptée, `null` tant qu'aucune.
  Map<String, bool>? carteAcceptee;

  /// Vérité « serveur » de la colonne `notify_local_events`.
  bool? colonneLocalEvents;

  /// Cartes reçues, acceptées ou non, dans l'ordre d'arrivée.
  final cartesRecues = <Map<String, bool>>[];

  /// Écritures de colonne reçues, dans l'ordre.
  final colonneRecue = <bool>[];

  bool refuseCarte = false;
  bool refuseColonne = false;

  /// Barrières : la N-ième écriture de carte attend la N-ième barrière avant
  /// de répondre. Sert à tenir une écriture « en vol ».
  final barrieres = <Completer<void>>[];

  @override
  Future<void> updateNotificationPrefs(
    String userId,
    Map<String, bool> prefs,
  ) async {
    cartesRecues.add(Map.of(prefs));
    if (barrieres.isNotEmpty) await barrieres.removeAt(0).future;
    if (refuseCarte) throw StateError('carte refusée');
    carteAcceptee = Map.of(prefs);
  }

  @override
  Future<void> updateNotifyLocalEvents(String userId, bool enabled) async {
    colonneRecue.add(enabled);
    if (refuseColonne) throw StateError('colonne refusée');
    colonneLocalEvents = enabled;
  }

  /// `show_message_preview` reçus, dans l'ordre.
  final apercusRecus = <bool>[];
  bool refuseApercu = false;

  @override
  Future<void> updateShowMessagePreview(String userId, bool show) async {
    apercusRecus.add(show);
    if (refuseApercu) throw StateError('colonne aperçu refusée');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const userId = 'u1';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService.instance.initialize();
  });

  Future<ProviderContainer> conteneur(
    _FauxServeur serveur, {
    UserEntity? user = const UserEntity(id: userId),
  }) async {
    final c = ProviderContainer(
      overrides: [
        profileRemoteDataSourceProvider.overrideWithValue(serveur),
        currentUserAsyncProvider.overrideWith((ref) => Stream.value(user)),
      ],
    );
    addTearDown(c.dispose);
    c.listen(currentUserAsyncProvider, (_, __) {}, fireImmediately: true);
    c.listen(
      notificationPreferencesNotifierProvider,
      (_, __) {},
      fireImmediately: true,
    );
    await c.read(currentUserAsyncProvider.future);
    return c;
  }

  NotificationPreferencesNotifier notifier(ProviderContainer c) =>
      c.read(notificationPreferencesNotifierProvider.notifier);

  NotificationPreferences etat(ProviderContainer c) =>
      c.read(notificationPreferencesNotifierProvider);

  test('acceptée : local, état et carte serveur sont d\'accord', () async {
    final serveur = _FauxServeur();
    final c = await conteneur(serveur);

    final ok = await notifier(c).setMessagesEnabled(false);

    expect(ok, isTrue);
    expect(etat(c).messagesEnabled, isFalse);
    expect(PreferencesService.instance.notifyMessages, isFalse);
    expect(serveur.carteAcceptee?['messages'], isFalse);
  });

  test('serveur refuse : l\'état ET la préférence locale reviennent', () async {
    final serveur = _FauxServeur()..refuseCarte = true;
    final c = await conteneur(serveur);

    final ok = await notifier(c).setMessagesEnabled(false);

    expect(ok, isFalse, reason: 'l\'échec devait remonter à l\'écran');
    expect(
      etat(c).messagesEnabled,
      isTrue,
      reason:
          'l\'interrupteur affichait « désactivé » sur une valeur que le '
          'serveur n\'avait jamais reçue',
    );
    expect(
      PreferencesService.instance.notifyMessages,
      isTrue,
      reason:
          'la préférence locale restait écrite : les messages étaient masqués '
          'au premier plan pendant que le back-end continuait de pousser',
    );
    expect(serveur.carteAcceptee, isNull, reason: 'rien n\'a été accepté');
  });

  test('chacun des sept réglages par type revient en arrière', () async {
    // Ils passent tous par le même chemin ; ce test garde que le câblage de
    // chacun (lecture de la valeur d'avant, écriture, état) est le bon. On
    // bascule vers l'OPPOSÉ de la valeur courante : les défauts ne sont pas
    // tous à `true` (« Messages système » ne l'est pas).
    final reglages = <String, ({
      Future<bool> Function(NotificationPreferencesNotifier, bool) set,
      bool Function(NotificationPreferences) lu,
      bool Function() local,
    })>{
      'messages': (
        set: (n, v) => n.setMessagesEnabled(v),
        lu: (s) => s.messagesEnabled,
        local: () => PreferencesService.instance.notifyMessages,
      ),
      'events': (
        set: (n, v) => n.setEventsEnabled(v),
        lu: (s) => s.eventsEnabled,
        local: () => PreferencesService.instance.notifyEvents,
      ),
      'friend_requests': (
        set: (n, v) => n.setFriendRequestsEnabled(v),
        lu: (s) => s.friendRequestsEnabled,
        local: () => PreferencesService.instance.notifyFriendRequests,
      ),
      'groups': (
        set: (n, v) => n.setGroupsEnabled(v),
        lu: (s) => s.groupsEnabled,
        local: () => PreferencesService.instance.notifyGroups,
      ),
      'event_reminders': (
        set: (n, v) => n.setEventRemindersEnabled(v),
        lu: (s) => s.eventRemindersEnabled,
        local: () => PreferencesService.instance.notifyEventReminders,
      ),
      'local_events': (
        set: (n, v) => n.setLocalEventsEnabled(v),
        lu: (s) => s.localEventsEnabled,
        local: () => PreferencesService.instance.notifyLocalEvents,
      ),
      'system_messages': (
        set: (n, v) => n.setSystemMessagesEnabled(v),
        lu: (s) => s.systemMessagesEnabled,
        local: () => PreferencesService.instance.notifySystemMessages,
      ),
    };

    for (final entry in reglages.entries) {
      final serveur = _FauxServeur()..refuseCarte = true;
      final c = await conteneur(serveur);
      final r = entry.value;
      final avant = r.lu(etat(c));

      final ok = await r.set(notifier(c), !avant);

      expect(ok, isFalse, reason: '${entry.key}: le refus doit remonter');
      expect(r.lu(etat(c)), avant, reason: '${entry.key}: état non remis');
      expect(r.local(), avant, reason: '${entry.key}: local non remis');
      expect(serveur.cartesRecues, hasLength(1),
          reason: '${entry.key}: la carte devait bien être tentée');
    }
  });

  group('« Aperçu des messages » : le réglage existe et atteint le serveur',
      () {
    // 2026-09-21 : `send-push` lisait `show_message_preview`, mais aucun
    // écran ne permettait de le changer — ni de passer par ce provider.
    test("couper l'aperçu écrit la colonne et la préférence locale",
        () async {
      final serveur = _FauxServeur();
      final c = await conteneur(serveur);
      expect(etat(c).messagePreviewEnabled, isTrue);

      final ok = await notifier(c).setMessagePreviewEnabled(false);

      expect(ok, isTrue);
      expect(serveur.apercusRecus, [false]);
      expect(etat(c).messagePreviewEnabled, isFalse);
      expect(PreferencesService.instance.showMessagePreview, isFalse);
    });

    test('refusé par le serveur : tout revient à « affiché »', () async {
      final serveur = _FauxServeur()..refuseApercu = true;
      final c = await conteneur(serveur);

      final ok = await notifier(c).setMessagePreviewEnabled(false);

      expect(ok, isFalse);
      expect(etat(c).messagePreviewEnabled, isTrue);
      expect(PreferencesService.instance.showMessagePreview, isTrue);
    });
  });

  group('« Événements locaux » : colonne dédiée puis carte', () {
    test('les deux écritures passent : rien à défaire', () async {
      final serveur = _FauxServeur();
      final c = await conteneur(serveur);

      final ok = await notifier(c).setLocalEventsEnabled(false);

      expect(ok, isTrue);
      expect(serveur.colonneRecue, [false]);
      expect(serveur.colonneLocalEvents, isFalse);
      expect(serveur.carteAcceptee?['local_events'], isFalse);
    });

    test('la carte échoue APRÈS la colonne : la colonne est remise', () async {
      // Sans compensation, c'est la colonne — celle que lit `users_near_point`
      // pour choisir les destinataires — qui divergerait de la préférence
      // locale, revenue en arrière.
      final serveur = _FauxServeur()..refuseCarte = true;
      final c = await conteneur(serveur);

      final ok = await notifier(c).setLocalEventsEnabled(false);

      expect(ok, isFalse);
      expect(serveur.colonneRecue, [false, true], reason: 'écrite puis remise');
      expect(serveur.colonneLocalEvents, isTrue);
      expect(etat(c).localEventsEnabled, isTrue);
      expect(PreferencesService.instance.notifyLocalEvents, isTrue);
    });

    test('la colonne échoue : aucune carte envoyée, rien à compenser',
        () async {
      final serveur = _FauxServeur()..refuseColonne = true;
      final c = await conteneur(serveur);

      final ok = await notifier(c).setLocalEventsEnabled(false);

      expect(ok, isFalse);
      expect(serveur.cartesRecues, isEmpty);
      expect(serveur.colonneRecue, [false], reason: 'une seule tentative');
      expect(etat(c).localEventsEnabled, isTrue);
      expect(PreferencesService.instance.notifyLocalEvents, isTrue);
    });
  });

  test('sans compte : la préférence reste locale, ce n\'est pas un échec',
      () async {
    final serveur = _FauxServeur();
    final c = await conteneur(serveur, user: null);

    final ok = await notifier(c).setGroupsEnabled(false);

    expect(ok, isTrue);
    expect(etat(c).groupsEnabled, isFalse);
    expect(serveur.cartesRecues, isEmpty);
  });

  test('deux bascules qui se chevauchent : une écriture à la fois', () async {
    // Le cas qui défaisait le retour en arrière. Réseau lent : « Messages »
    // part, et avant sa réponse l'utilisateur touche « Événements ». Sans file,
    // la seconde envoyait la carte ENTIÈRE — donc « Messages » désactivé
    // aussi — puis « Messages » échouait et revenait en arrière sur le local
    // seul : le serveur gardait « désactivé », l'appareil « activé ».
    final serveur = _FauxServeur();
    final premiere = Completer<void>();
    serveur.barrieres.add(premiere);
    final c = await conteneur(serveur);

    final messages = notifier(c).setMessagesEnabled(false);
    final evenements = notifier(c).setEventsEnabled(false);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(
      serveur.cartesRecues,
      hasLength(1),
      reason: 'la seconde écriture ne doit pas partir avant la fin de la 1re',
    );

    // Le serveur refuse la première.
    premiere.completeError(StateError('carte refusée'));
    expect(await messages, isFalse);
    expect(await evenements, isTrue);

    // Les deux côtés racontent la même histoire.
    expect(etat(c).messagesEnabled, isTrue, reason: 'revenu en arrière');
    expect(etat(c).eventsEnabled, isFalse);
    expect(serveur.carteAcceptee?['messages'], isTrue);
    expect(serveur.carteAcceptee?['events'], isFalse);
    expect(
      serveur.carteAcceptee,
      PreferencesService.instance.notificationTypePrefs,
      reason: 'le serveur et la préférence locale doivent coïncider',
    );
  });

  test('une écriture qui échoue ne bloque pas les suivantes', () async {
    final serveur = _FauxServeur()..refuseCarte = true;
    final c = await conteneur(serveur);

    expect(await notifier(c).setMessagesEnabled(false), isFalse);

    serveur.refuseCarte = false;
    expect(await notifier(c).setMessagesEnabled(false), isTrue);
    expect(serveur.carteAcceptee?['messages'], isFalse);
  });
}
