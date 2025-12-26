import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/services/notification_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/notification_remote_datasource.dart';
import '../../domain/entities/notification_entity.dart';

part 'notification_provider.g.dart';

@riverpod
NotificationService notificationService(Ref ref) {
  return NotificationService();
}

@riverpod
NotificationRemoteDataSource notificationDataSource(Ref ref) {
  return NotificationRemoteDataSourceImpl();
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

  Future<void> markAsRead(String notificationId) async {
    try {
      final dataSource = ref.read(notificationDataSourceProvider);
      await dataSource.markAsRead(notificationId);
    } catch (e) {
      // Handle error silently or show snackbar
    }
  }

  Future<void> markAllAsRead() async {
    try {
      final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
      if (currentUser == null) return;

      final dataSource = ref.read(notificationDataSourceProvider);
      await dataSource.markAllAsRead(currentUser.id);
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      final dataSource = ref.read(notificationDataSourceProvider);
      await dataSource.deleteNotification(notificationId);
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> deleteAllNotifications() async {
    try {
      final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
      if (currentUser == null) return;

      final dataSource = ref.read(notificationDataSourceProvider);
      await dataSource.deleteAllNotifications(currentUser.id);
    } catch (e) {
      // Handle error silently
    }
  }

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
    return notifications.where((n) => !n.isRead).length;
  }
}
