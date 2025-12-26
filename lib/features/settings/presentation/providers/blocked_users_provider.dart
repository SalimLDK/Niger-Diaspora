import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/blocked_users_datasource.dart';
import '../../data/repositories/blocked_users_repository_impl.dart';
import '../../domain/entities/blocked_user_entity.dart';
import '../../domain/repositories/blocked_users_repository.dart';

part 'blocked_users_provider.g.dart';

@riverpod
BlockedUsersDataSource blockedUsersDataSource(Ref ref) {
  return BlockedUsersDataSourceImpl();
}

@riverpod
BlockedUsersRepository blockedUsersRepository(Ref ref) {
  return BlockedUsersRepositoryImpl(
    dataSource: ref.watch(blockedUsersDataSourceProvider),
  );
}

@riverpod
Stream<List<BlockedUserEntity>> blockedUsers(Ref ref) {
  final currentUser = ref.watch(currentUserProvider).valueOrNull;
  if (currentUser == null) {
    return Stream.value([]);
  }

  final repository = ref.watch(blockedUsersRepositoryProvider);
  return repository.getBlockedUsers(currentUser.id).map(
        (either) => either.fold((_) => [], (users) => users),
      );
}

@riverpod
class BlockUserNotifier extends _$BlockUserNotifier {
  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }

  Future<bool> blockUser({
    required String targetUserId,
    required String targetDisplayName,
    String? targetPhotoUrl,
  }) async {
    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser == null) return false;

    state = const AsyncValue.loading();

    final repository = ref.read(blockedUsersRepositoryProvider);
    final result = await repository.blockUser(
      currentUser.id,
      targetUserId,
      targetDisplayName,
      targetPhotoUrl,
    );

    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        return true;
      },
    );
  }

  Future<bool> unblockUser(String targetUserId) async {
    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser == null) return false;

    state = const AsyncValue.loading();

    final repository = ref.read(blockedUsersRepositoryProvider);
    final result = await repository.unblockUser(currentUser.id, targetUserId);

    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        return true;
      },
    );
  }
}
