import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/friend_entity.dart';
import '../entities/friend_request_entity.dart';

enum FriendshipStatus {
  none,
  pendingSent,
  pendingReceived,
  friends,
}

abstract class FriendRepository {
  // Friend Requests
  Future<Either<Failure, void>> sendFriendRequest({
    required String senderId,
    required String senderName,
    String? senderPhotoUrl,
    required String receiverId,
    required String receiverName,
    String? receiverPhotoUrl,
  });

  Future<Either<Failure, void>> acceptFriendRequest(String requestId);
  Future<Either<Failure, void>> declineFriendRequest(String requestId);
  Future<Either<Failure, void>> cancelFriendRequest(String requestId);

  Stream<Either<Failure, List<FriendRequestEntity>>> getReceivedRequests(
      String userId);
  Stream<Either<Failure, List<FriendRequestEntity>>> getSentRequests(
      String userId);

  Future<Either<Failure, FriendshipStatus>> getFriendshipStatus(
      String userId1, String userId2);

  // Friends List
  Stream<Either<Failure, List<FriendEntity>>> getFriends(String userId);
  Future<Either<Failure, void>> removeFriend(String userId, String friendId);
  Future<Either<Failure, bool>> areFriends(String userId1, String userId2);
  Future<Either<Failure, List<FriendEntity>>> searchFriends(
      String userId, String query);
}
