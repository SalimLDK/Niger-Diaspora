import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/services/logger_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../settings/presentation/providers/blocked_users_provider.dart';
import '../../data/datasources/notification_remote_datasource.dart';
import '../../data/datasources/notification_supabase_datasource.dart';
import '../../domain/entities/notification_entity.dart';

part 'notification_provider.g.dart';

@riverpod
NotificationService notificationService(Ref ref) {
  return NotificationService();
}

@riverpod
NotificationRemoteDataSource notificationDataSource(Ref ref) {
  // Source Supabase, pas Firestore.
  //
  // La chaine push ecrit les notifications dans Supabase (declencheurs SQL,
  // puis `send-push`), mais cet ecran lisait Firestore. Releve le 2026-08-06 :
  // 44 notifications dans Supabase, 34 dans Firestore. Celles produites par le
  // pipeline — dont les messages — n apparaissaient donc JAMAIS dans la liste
  // in-app : la personne recevait le push, ouvrait l ecran, et n y trouvait
  // rien.
  //
  // `NotificationSupabaseDataSource` implemente la meme interface (7 methodes,
  // toutes surchargees) : la bascule est un changement d instanciation.
  return NotificationSupabaseDataSource();
}

@riverpod
class NotificationLimit extends _$NotificationLimit {
  @override
  int build() => 20;

  void increment() {
    state += 20;
  }
}

@riverpod
Stream<List<NotificationEntity>> notificationsStream(Ref ref) {
  final currentUser = ref.watch(currentUserProvider).valueOrNull;
  if (currentUser == null) {
    return Stream.value([]);
  }

  final limit = ref.watch(notificationLimitProvider);
  final dataSource = ref.watch(notificationDataSourceProvider);
  return dataSource
      .getNotifications(currentUser.id, limit: limit)
      .map((models) => models.map((m) => m.toEntity()).toList());
}

@riverpod
class NotificationsNotifier extends _$NotificationsNotifier {
  @override
  AsyncValue<List<NotificationEntity>> build() {
    final stream = ref.watch(notificationsStreamProvider);
    return stream.when(
      data: (data) => AsyncValue.data(data),
      loading: () => const AsyncValue.loading(),
      error: (e, st) => AsyncValue.error(e, st),
    );
  }

  /// Une écriture sur les notifications. Rend `false` si elle a échoué.
  ///
  /// Les quatre méthodes ci-dessous avalaient toute erreur (« Handle error
  /// silently ») et rendaient `void` : l'écran qui annonce quelque chose — la
  /// fiche qui se referme comme si la notification était supprimée — n'avait
  /// aucun moyen de savoir. Un booléen plutôt qu'une exception, parce que la
  /// plupart des appelants sont en `unawaited(...)`.
  Future<bool> _write(String what, Future<void> Function() action) async {
    try {
      await action();
      return true;
    } catch (e, s) {
      LoggerService.w('NotificationsNotifier: $what a échoué', e, s);
      return false;
    }
  }

  /// Id de l'utilisateur courant ; lève s'il n'y en a pas, pour que
  /// l'écriture soit comptée comme échouée plutôt que comme faite.
  Future<String> _currentUserId() async {
    final currentUser = await ref.read(currentUserAsyncProvider.future);
    if (currentUser == null) throw StateError('Aucun utilisateur connecté');
    return currentUser.id;
  }

  Future<bool> markAsRead(String notificationId) => _write(
    'markAsRead',
    () => ref.read(notificationDataSourceProvider).markAsRead(notificationId),
  );

  Future<bool> markAllAsRead() => _write('markAllAsRead', () async {
    final userId = await _currentUserId();
    await ref.read(notificationDataSourceProvider).markAllAsRead(userId);
  });

  Future<bool> deleteNotification(String notificationId) => _write(
    'deleteNotification',
    () => ref
        .read(notificationDataSourceProvider)
        .deleteNotification(notificationId),
  );

  Future<bool> deleteAllNotifications() => _write('deleteAllNotifications', () async {
    final userId = await _currentUserId();
    await ref.read(notificationDataSourceProvider).deleteAllNotifications(userId);
  });

  void loadMore() {
    ref.read(notificationLimitProvider.notifier).increment();
  }
}

@riverpod
class UnreadNotificationsCount extends _$UnreadNotificationsCount {
  @override
  int build() {
    final notifications =
        ref.watch(notificationsStreamProvider).valueOrNull ?? [];
    final blockedUsers = ref.watch(blockedUsersProvider).valueOrNull ?? [];
    final blockedUserIds = blockedUsers.map((u) => u.id).toSet();

    // Notification types that have targetId as a user ID
    const userRelatedTypes = {
      NotificationType.friendRequest,
      NotificationType.friendRequestAccepted,
      NotificationType.friendAccepted,
    };

    final quiMOntBloque =
        ref.watch(usersWhoBlockedMeProvider).valueOrNull ?? const <String>{};

    // Les notifications de messagerie n'arrivent plus jusqu'ici : la requête
    // les écarte (`kTypesHorsEcranNotifications`). La pastille de la cloche ne
    // compte donc plus un message déjà compté par l'onglet Messages.
    return notifications.where((n) {
      if (n.isRead) return false;

      // Only filter user-related notifications
      if (!userRelatedTypes.contains(n.type)) return true;
      if (n.targetId == null) return true;

      // If I blocked this user, don't count their notifications
      if (blockedUserIds.contains(n.targetId)) return false;

      // Check if target user blocked me — meme inversion que ci-dessus.
      if (quiMOntBloque.contains(n.targetId)) return false;

      return true;
    }).length;
  }
}
