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

/// Provider that derives friendship status from existing streams
/// This ensures real-time updates when friend requests change
@Riverpod(keepAlive: true)
FriendshipStatus friendshipStatus(Ref ref, String otherUserId) {
  final currentUser = ref.watch(currentUserAsyncProvider).valueOrNull;
  if (currentUser == null) {
    return FriendshipStatus.none;
  }

  // Watch the friends list
  final friendsAsync = ref.watch(friendsProvider);
  final friends = friendsAsync.valueOrNull ?? [];

  // Check if already friends
  if (friends.any((f) => f.id == otherUserId)) {
    return FriendshipStatus.friends;
  }

  // Watch sent requests
  final sentRequestsAsync = ref.watch(sentFriendRequestsProvider);
  final sentRequests = sentRequestsAsync.valueOrNull ?? [];

  // Check if current user sent a request to otherUserId
  if (sentRequests.any((r) => r.receiverId == otherUserId)) {
    return FriendshipStatus.pendingSent;
  }

  // Watch received requests
  final receivedRequestsAsync = ref.watch(receivedFriendRequestsProvider);
  final receivedRequests = receivedRequestsAsync.valueOrNull ?? [];

  // Check if current user received a request from otherUserId
  if (receivedRequests.any((r) => r.senderId == otherUserId)) {
    return FriendshipStatus.pendingReceived;
  }

  return FriendshipStatus.none;
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

  Future<bool> acceptRequest(String requestId, {String? senderId}) async {
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
        ref.invalidate(sentFriendRequestsProvider);
        ref.invalidate(friendsProvider);
        // Invalidate friendship status for the other user if provided
        if (senderId != null) {
          ref.invalidate(friendshipStatusProvider(senderId));
        }
        return true;
      },
    );
  }

  Future<bool> declineRequest(String requestId, {String? senderId}) async {
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
        // Invalidate friendship status for the other user if provided
        if (senderId != null) {
          ref.invalidate(friendshipStatusProvider(senderId));
        }
        return true;
      },
    );
  }

  Future<bool> cancelRequest(String requestId, {String? receiverId}) async {
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
        // Invalidate friendship status for the other user if provided
        if (receiverId != null) {
          ref.invalidate(friendshipStatusProvider(receiverId));
        }
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
