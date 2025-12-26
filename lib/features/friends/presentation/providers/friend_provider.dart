import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/friend_remote_datasource.dart';
import '../../data/repositories/friend_repository_impl.dart';
import '../../domain/entities/friend_entity.dart';
import '../../domain/entities/friend_request_entity.dart';
import '../../domain/repositories/friend_repository.dart';

part 'friend_provider.g.dart';

@riverpod
FriendRemoteDataSource friendRemoteDataSource(Ref ref) {
  return FriendRemoteDataSourceImpl();
}

@riverpod
FriendRepository friendRepository(Ref ref) {
  return FriendRepositoryImpl(
    dataSource: ref.watch(friendRemoteDataSourceProvider),
  );
}

@Riverpod(keepAlive: true)
Stream<List<FriendEntity>> friends(Ref ref) {
  final currentUser = ref.watch(currentUserAsyncProvider).valueOrNull;
  if (currentUser == null) {
    return Stream.value([]);
  }

  final repository = ref.watch(friendRepositoryProvider);
  return repository
      .getFriends(currentUser.id)
      .map((either) => either.fold((_) => [], (friends) => friends));
}

@Riverpod(keepAlive: true)
Stream<List<FriendRequestEntity>> receivedFriendRequests(Ref ref) {
  final currentUser = ref.watch(currentUserAsyncProvider).valueOrNull;
  if (currentUser == null) {
    return Stream.value([]);
  }

  final repository = ref.watch(friendRepositoryProvider);
  return repository
      .getReceivedRequests(currentUser.id)
      .map((either) => either.fold((_) => [], (requests) => requests));
}

@Riverpod(keepAlive: true)
Stream<List<FriendRequestEntity>> sentFriendRequests(Ref ref) {
  final currentUser = ref.watch(currentUserAsyncProvider).valueOrNull;
  if (currentUser == null) {
    return Stream.value([]);
  }

  final repository = ref.watch(friendRepositoryProvider);
  return repository
      .getSentRequests(currentUser.id)
      .map((either) => either.fold((_) => [], (requests) => requests));
}

@Riverpod(keepAlive: true)
Future<FriendshipStatus> friendshipStatus(Ref ref, String otherUserId) async {
  final currentUser = ref.watch(currentUserAsyncProvider).valueOrNull;
  if (currentUser == null) {
    return FriendshipStatus.none;
  }

  final repository = ref.watch(friendRepositoryProvider);
  final result = await repository.getFriendshipStatus(
    currentUser.id,
    otherUserId,
  );
  return result.fold((_) => FriendshipStatus.none, (status) => status);
}

@Riverpod(keepAlive: true)
class FriendRequestNotifier extends _$FriendRequestNotifier {
  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }

  Future<bool> sendRequest({
    required String receiverId,
    required String receiverName,
    String? receiverPhotoUrl,
  }) async {
    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser == null) {
      state = AsyncValue.error(
        'Utilisateur non authentifié',
        StackTrace.current,
      );
      return false;
    }

    state = const AsyncValue.loading();

    final repository = ref.read(friendRepositoryProvider);
    final result = await repository.sendFriendRequest(
      senderId: currentUser.id,
      senderName: currentUser.displayName ?? 'Utilisateur',
      senderPhotoUrl: currentUser.photoUrl,
      receiverId: receiverId,
      receiverName: receiverName,
      receiverPhotoUrl: receiverPhotoUrl,
    );

    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        ref.invalidate(friendshipStatusProvider(receiverId));
        return true;
      },
    );
  }

  Future<bool> acceptRequest(String requestId) async {
    state = const AsyncValue.loading();

    final repository = ref.read(friendRepositoryProvider);
    final result = await repository.acceptFriendRequest(requestId);

    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        ref.invalidate(receivedFriendRequestsProvider);
        ref.invalidate(friendsProvider);
        return true;
      },
    );
  }

  Future<bool> declineRequest(String requestId) async {
    state = const AsyncValue.loading();

    final repository = ref.read(friendRepositoryProvider);
    final result = await repository.declineFriendRequest(requestId);

    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        ref.invalidate(receivedFriendRequestsProvider);
        return true;
      },
    );
  }

  Future<bool> cancelRequest(String requestId) async {
    state = const AsyncValue.loading();

    final repository = ref.read(friendRepositoryProvider);
    final result = await repository.cancelFriendRequest(requestId);

    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        ref.invalidate(sentFriendRequestsProvider);
        return true;
      },
    );
  }

  Future<bool> removeFriend(String friendId) async {
    final currentUser = ref.read(currentUserAsyncProvider).valueOrNull;
    if (currentUser == null) return false;

    state = const AsyncValue.loading();

    final repository = ref.read(friendRepositoryProvider);
    final result = await repository.removeFriend(currentUser.id, friendId);

    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        ref.invalidate(friendsProvider);
        ref.invalidate(friendshipStatusProvider(friendId));
        return true;
      },
    );
  }
}
