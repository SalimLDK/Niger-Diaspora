import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/network/network_info.dart';
import '../../data/datasources/group_remote_datasource.dart';
import '../../data/repositories/group_repository_impl.dart';
import '../../domain/entities/group_entity.dart';
import '../../domain/repositories/group_repository.dart';

part 'group_provider.g.dart';

@riverpod
GroupRemoteDataSource groupRemoteDataSource(Ref ref) {
  return GroupRemoteDataSourceImpl();
}

@riverpod
GroupRepository groupRepository(Ref ref) {
  return GroupRepositoryImpl(
    remoteDataSource: ref.watch(groupRemoteDataSourceProvider),
    networkInfo: ref.watch(networkInfoProvider),
  );
}

@Riverpod(keepAlive: true)
class GroupsNotifier extends _$GroupsNotifier {
  @override
  AsyncValue<List<GroupEntity>> build() {
    loadGroups();
    return const AsyncValue.loading();
  }

  Future<void> loadGroups() async {
    state = const AsyncValue.loading();
    final repository = ref.read(groupRepositoryProvider);
    final result = await repository.getGroups();
    result.fold(
      (failure) =>
          state = AsyncValue.error(failure.message, StackTrace.current),
      (groups) => state = AsyncValue.data(groups),
    );
  }

  Future<void> loadGroupsByCategory(GroupCategory category) async {
    state = const AsyncValue.loading();
    final repository = ref.read(groupRepositoryProvider);
    final result = await repository.getGroupsByCategory(category);
    result.fold(
      (failure) =>
          state = AsyncValue.error(failure.message, StackTrace.current),
      (groups) => state = AsyncValue.data(groups),
    );
  }

  Future<void> refresh() async {
    await loadGroups();
  }
}

@riverpod
class GroupDetailNotifier extends _$GroupDetailNotifier {
  @override
  AsyncValue<GroupEntity?> build() {
    return const AsyncValue.data(null);
  }

  Future<void> loadGroup(String groupId) async {
    state = const AsyncValue.loading();
    final repository = ref.read(groupRepositoryProvider);
    final result = await repository.getGroupById(groupId);
    result.fold(
      (failure) =>
          state = AsyncValue.error(failure.message, StackTrace.current),
      (group) => state = AsyncValue.data(group),
    );
  }

  Future<bool> joinGroup(String groupId, String userId) async {
    final repository = ref.read(groupRepositoryProvider);
    final result = await repository.joinGroup(groupId, userId);
    return result.fold((failure) => false, (_) {
      loadGroup(groupId);
      return true;
    });
  }

  Future<bool> leaveGroup(String groupId, String userId) async {
    final repository = ref.read(groupRepositoryProvider);
    final result = await repository.leaveGroup(groupId, userId);
    return result.fold((failure) => false, (_) {
      loadGroup(groupId);
      return true;
    });
  }
}

@Riverpod(keepAlive: true)
class MyGroupsNotifier extends _$MyGroupsNotifier {
  @override
  AsyncValue<List<GroupEntity>> build() {
    final user = ref.watch(currentUserProvider).valueOrNull;
    if (user != null) {
      loadMyGroups(user.id);
    }
    return const AsyncValue.loading();
  }

  Future<void> loadMyGroups(String userId) async {
    state = const AsyncValue.loading();
    final repository = ref.read(groupRepositoryProvider);
    final result = await repository.getMyGroups(userId);
    result.fold(
      (failure) =>
          state = AsyncValue.error(failure.message, StackTrace.current),
      (groups) => state = AsyncValue.data(groups),
    );
  }

  Future<bool> createGroup(GroupEntity group) async {
    final repository = ref.read(groupRepositoryProvider);
    final result = await repository.createGroup(group);
    return result.fold((failure) => false, (created) {
      final currentGroups = state.valueOrNull ?? [];
      state = AsyncValue.data([created, ...currentGroups]);
      return true;
    });
  }

  Future<bool> updateGroup(GroupEntity group) async {
    final repository = ref.read(groupRepositoryProvider);
    final result = await repository.updateGroup(group);
    return result.fold((failure) => false, (updated) {
      final currentGroups = state.valueOrNull ?? [];
      state = AsyncValue.data(
        currentGroups.map((g) => g.id == updated.id ? updated : g).toList(),
      );
      return true;
    });
  }

  Future<bool> deleteGroup(String groupId) async {
    final repository = ref.read(groupRepositoryProvider);
    final result = await repository.deleteGroup(groupId);
    return result.fold((failure) => false, (_) {
      final currentGroups = state.valueOrNull ?? [];
      state = AsyncValue.data(
        currentGroups.where((g) => g.id != groupId).toList(),
      );
      return true;
    });
  }
}
