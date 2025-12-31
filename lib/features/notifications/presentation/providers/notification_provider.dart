import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/services/notification_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../settings/presentation/providers/blocked_users_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
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
    final blockedUsers = ref.watch(blockedUsersProvider).valueOrNull ?? [];
    final blockedUserIds = blockedUsers.map((u) => u.id).toSet();
    final currentUserId = ref.watch(currentUserProvider).valueOrNull?.id;

    // Notification types that have targetId as a user ID
    const userRelatedTypes = {
      NotificationType.friendRequest,
      NotificationType.friendRequestAccepted,
      NotificationType.friendAccepted,
      NotificationType.newFollower,
      NotificationType.nearbyMember,
      NotificationType.proximityAlert,
    };

    return notifications.where((n) {
      if (n.isRead) return false;

      // Filter message notifications by senderId
      if (n.type == NotificationType.message && n.senderId != null) {
        // If I blocked this user, don't count their notifications
        if (blockedUserIds.contains(n.senderId)) return false;

        // Check if sender blocked me
        final senderProfileAsync = ref.watch(userStreamProvider(n.senderId!));
        final senderProfile = senderProfileAsync.valueOrNull;
        if (senderProfile != null && currentUserId != null) {
          if (senderProfile.blockedByUserIds.contains(currentUserId)) {
            return false;
          }
        }
        return true;
      }

      // Only filter user-related notifications
      if (!userRelatedTypes.contains(n.type)) return true;
      if (n.targetId == null) return true;

      // If I blocked this user, don't count their notifications
      if (blockedUserIds.contains(n.targetId)) return false;

      // Check if target user blocked me
      final targetProfileAsync = ref.watch(userStreamProvider(n.targetId!));
      final targetProfile = targetProfileAsync.valueOrNull;
      if (targetProfile != null && currentUserId != null) {
        if (targetProfile.blockedByUserIds.contains(currentUserId)) {
          return false;
        }
      }

      return true;
    }).length;
  }
}
