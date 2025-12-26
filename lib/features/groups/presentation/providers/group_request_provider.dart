import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/group_request_datasource.dart';
import '../../domain/entities/group_request_entity.dart';
import '../../domain/entities/group_invite_entity.dart';

part 'group_request_provider.g.dart';

@riverpod
GroupRequestDataSource groupRequestDataSource(Ref ref) {
  return GroupRequestDataSourceImpl();
}

// ==================== GROUP JOIN REQUESTS ====================

@riverpod
Stream<List<GroupRequestEntity>> groupPendingRequests(
    Ref ref, String groupId) {
  final dataSource = ref.watch(groupRequestDataSourceProvider);
  return dataSource.getPendingRequests(groupId).map(
        (models) => models.map((m) => m.toEntity()).toList(),
      );
}

@riverpod
Stream<List<GroupRequestEntity>> myGroupRequests(Ref ref) {
  final currentUser = ref.watch(currentUserProvider).valueOrNull;
  if (currentUser == null) {
    return Stream.value([]);
  }

  final dataSource = ref.watch(groupRequestDataSourceProvider);
  return dataSource.getMyGroupRequests(currentUser.id).map(
        (models) => models.map((m) => m.toEntity()).toList(),
      );
}

@riverpod
class GroupRequestNotifier extends _$GroupRequestNotifier {
  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }

  Future<bool> requestToJoin({
    required String groupId,
    required String groupName,
    String? groupImageUrl,
    String? message,
  }) async {
    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser == null) return false;

    state = const AsyncValue.loading();

    try {
      final dataSource = ref.read(groupRequestDataSourceProvider);
      await dataSource.requestToJoinGroup(
        groupId: groupId,
        groupName: groupName,
        groupImageUrl: groupImageUrl,
        requesterId: currentUser.id,
        requesterName: currentUser.displayName ?? 'Utilisateur',
        requesterPhotoUrl: currentUser.photoUrl,
        message: message,
      );
      state = const AsyncValue.data(null);
      ref.invalidate(myGroupRequestsProvider);
      return true;
    } catch (e) {
      state = AsyncValue.error(e.toString(), StackTrace.current);
      return false;
    }
  }

  Future<bool> approveRequest(String requestId) async {
    state = const AsyncValue.loading();

    try {
      final dataSource = ref.read(groupRequestDataSourceProvider);
      await dataSource.approveJoinRequest(requestId);
      state = const AsyncValue.data(null);
      return true;
    } catch (e) {
      state = AsyncValue.error(e.toString(), StackTrace.current);
      return false;
    }
  }

  Future<bool> rejectRequest(String requestId) async {
    state = const AsyncValue.loading();

    try {
      final dataSource = ref.read(groupRequestDataSourceProvider);
      await dataSource.rejectJoinRequest(requestId);
      state = const AsyncValue.data(null);
      return true;
    } catch (e) {
      state = AsyncValue.error(e.toString(), StackTrace.current);
      return false;
    }
  }

  Future<bool> cancelRequest(String requestId) async {
    state = const AsyncValue.loading();

    try {
      final dataSource = ref.read(groupRequestDataSourceProvider);
      await dataSource.cancelJoinRequest(requestId);
      state = const AsyncValue.data(null);
      ref.invalidate(myGroupRequestsProvider);
      return true;
    } catch (e) {
      state = AsyncValue.error(e.toString(), StackTrace.current);
      return false;
    }
  }
}

// ==================== GROUP INVITES ====================

@riverpod
Stream<List<GroupInviteEntity>> receivedGroupInvites(Ref ref) {
  final currentUser = ref.watch(currentUserProvider).valueOrNull;
  if (currentUser == null) {
    return Stream.value([]);
  }

  final dataSource = ref.watch(groupRequestDataSourceProvider);
  return dataSource.getReceivedInvites(currentUser.id).map(
        (models) => models.map((m) => m.toEntity()).toList(),
      );
}

@riverpod
Stream<List<GroupInviteEntity>> groupSentInvites(Ref ref, String groupId) {
  final dataSource = ref.watch(groupRequestDataSourceProvider);
  return dataSource.getSentInvites(groupId).map(
        (models) => models.map((m) => m.toEntity()).toList(),
      );
}

@riverpod
class GroupInviteNotifier extends _$GroupInviteNotifier {
  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }

  Future<bool> inviteUser({
    required String groupId,
    required String groupName,
    String? groupImageUrl,
    required String inviteeId,
    required String inviteeName,
    String? inviteePhotoUrl,
  }) async {
    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser == null) return false;

    state = const AsyncValue.loading();

    try {
      final dataSource = ref.read(groupRequestDataSourceProvider);
      await dataSource.inviteUserToGroup(
        groupId: groupId,
        groupName: groupName,
        groupImageUrl: groupImageUrl,
        inviterId: currentUser.id,
        inviterName: currentUser.displayName ?? 'Utilisateur',
        inviteeId: inviteeId,
        inviteeName: inviteeName,
        inviteePhotoUrl: inviteePhotoUrl,
      );
      state = const AsyncValue.data(null);
      ref.invalidate(groupSentInvitesProvider(groupId));
      return true;
    } catch (e) {
      state = AsyncValue.error(e.toString(), StackTrace.current);
      return false;
    }
  }

  Future<bool> acceptInvite(String inviteId) async {
    state = const AsyncValue.loading();

    try {
      final dataSource = ref.read(groupRequestDataSourceProvider);
      await dataSource.acceptGroupInvite(inviteId);
      state = const AsyncValue.data(null);
      ref.invalidate(receivedGroupInvitesProvider);
      return true;
    } catch (e) {
      state = AsyncValue.error(e.toString(), StackTrace.current);
      return false;
    }
  }

  Future<bool> declineInvite(String inviteId) async {
    state = const AsyncValue.loading();

    try {
      final dataSource = ref.read(groupRequestDataSourceProvider);
      await dataSource.declineGroupInvite(inviteId);
      state = const AsyncValue.data(null);
      ref.invalidate(receivedGroupInvitesProvider);
      return true;
    } catch (e) {
      state = AsyncValue.error(e.toString(), StackTrace.current);
      return false;
    }
  }

  Future<bool> cancelInvite(String inviteId, String groupId) async {
    state = const AsyncValue.loading();

    try {
      final dataSource = ref.read(groupRequestDataSourceProvider);
      await dataSource.cancelGroupInvite(inviteId);
      state = const AsyncValue.data(null);
      ref.invalidate(groupSentInvitesProvider(groupId));
      return true;
    } catch (e) {
      state = AsyncValue.error(e.toString(), StackTrace.current);
      return false;
    }
  }
}
