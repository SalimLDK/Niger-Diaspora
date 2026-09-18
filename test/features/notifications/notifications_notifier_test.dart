import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/features/auth/domain/entities/user_entity.dart';
import 'package:diaspo_niger/features/auth/presentation/providers/auth_provider.dart';
import 'package:diaspo_niger/features/notifications/data/datasources/notification_remote_datasource.dart';
import 'package:diaspo_niger/features/notifications/domain/entities/notification_entity.dart';
import 'package:diaspo_niger/features/notifications/presentation/providers/notification_provider.dart';

/// Les quatre écritures du notifier de notifications avalaient toute erreur
/// (« Handle error silently ») et rendaient `void` : la fiche qui se referme
/// comme si la notification était supprimée n'avait aucun moyen de savoir.
///
/// Elles rendent maintenant `Future<bool>` — un booléen plutôt qu'une
/// exception, parce que la plupart des appelants sont en `unawaited(...)`.
class _FauxSource implements NotificationRemoteDataSource {
  bool echoue = false;

  /// Écritures reçues, « verbe:argument ».
  final recues = <String>[];

  Future<void> _ecrire(String appel) async {
    recues.add(appel);
    if (echoue) throw StateError('refusé par le serveur');
  }

  @override
  Future<void> markAsRead(String notificationId) =>
      _ecrire('markAsRead:$notificationId');

  @override
  Future<void> markAllAsRead(String userId) => _ecrire('markAllAsRead:$userId');

  @override
  Future<void> deleteNotification(String notificationId) =>
      _ecrire('deleteNotification:$notificationId');

  @override
  Future<void> deleteAllNotifications(String userId) =>
      _ecrire('deleteAllNotifications:$userId');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<({ProviderContainer c, NotificationsNotifier notifier})> monter(
    _FauxSource source, {
    UserEntity? user = const UserEntity(id: 'u1'),
  }) async {
    final c = ProviderContainer(
      overrides: [
        notificationDataSourceProvider.overrideWithValue(source),
        // `build()` s'abonne au flux : on le neutralise, seules les écritures
        // sont l'objet de ce banc.
        notificationsStreamProvider.overrideWith(
          (ref) => Stream.value(const <NotificationEntity>[]),
        ),
        currentUserAsyncProvider.overrideWith((ref) => Stream.value(user)),
      ],
    );
    addTearDown(c.dispose);
    c.listen(notificationsNotifierProvider, (_, __) {}, fireImmediately: true);
    await c.read(currentUserAsyncProvider.future);
    return (c: c, notifier: c.read(notificationsNotifierProvider.notifier));
  }

  test('suppression acceptée : rend true', () async {
    final source = _FauxSource();
    final m = await monter(source);

    expect(await m.notifier.deleteNotification('n1'), isTrue);
    expect(source.recues, ['deleteNotification:n1']);
  });

  test('suppression refusée : rend false au lieu de tout avaler', () async {
    final source = _FauxSource()..echoue = true;
    final m = await monter(source);

    expect(
      await m.notifier.deleteNotification('n1'),
      isFalse,
      reason: 'la fiche se refermait comme si la suppression avait eu lieu',
    );
  });

  test('marquer comme lue, une ou toutes : le refus remonte', () async {
    final source = _FauxSource()..echoue = true;
    final m = await monter(source);

    expect(await m.notifier.markAsRead('n1'), isFalse);
    expect(await m.notifier.markAllAsRead(), isFalse);
    expect(await m.notifier.deleteAllNotifications(), isFalse);
  });

  test('les écritures par utilisateur utilisent l\'id de l\'utilisateur',
      () async {
    final source = _FauxSource();
    final m = await monter(source);

    expect(await m.notifier.markAllAsRead(), isTrue);
    expect(await m.notifier.deleteAllNotifications(), isTrue);
    expect(source.recues, [
      'markAllAsRead:u1',
      'deleteAllNotifications:u1',
    ]);
  });

  test('sans utilisateur : rien n\'est écrit, et ce n\'est pas un succès',
      () async {
    // Ces deux méthodes sortaient sur `return` : rien n'était supprimé, et
    // l'appelant n'avait aucun moyen de le distinguer d'un succès.
    final source = _FauxSource();
    final m = await monter(source, user: null);

    expect(await m.notifier.markAllAsRead(), isFalse);
    expect(await m.notifier.deleteAllNotifications(), isFalse);
    expect(source.recues, isEmpty);
  });
}
