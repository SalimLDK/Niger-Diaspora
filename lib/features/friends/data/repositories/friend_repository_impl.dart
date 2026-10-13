import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/garde_appel.dart';
import '../../../../core/services/notification_service.dart';
import '../../domain/entities/friend_entity.dart';
import '../../domain/entities/friend_request_entity.dart';
import '../../domain/repositories/friend_repository.dart';
import '../datasources/friend_remote_datasource.dart';

class FriendRepositoryImpl implements FriendRepository {
  final FriendRemoteDataSource dataSource;

  FriendRepositoryImpl({required this.dataSource});

  @override
  Future<Either<Failure, void>> sendFriendRequest({
    required String senderId,
    required String senderName,
    String? senderPhotoUrl,
    required String receiverId,
    required String receiverName,
    String? receiverPhotoUrl,
  }) async {
    return garderAppel(() async {
      await dataSource.sendFriendRequest(
        senderId: senderId,
        senderName: senderName,
        senderPhotoUrl: senderPhotoUrl,
        receiverId: receiverId,
        receiverName: receiverName,
        receiverPhotoUrl: receiverPhotoUrl,
      );

      // Send notification to receiver
      await NotificationService().createNotification(
        userId: receiverId,
        title: 'Nouvelle demande d\'ami',
        body: '$senderName souhaite vous ajouter en ami',
        type: 'friendRequest',
        targetId: senderId,
        data: {
          'senderId': senderId,
          'senderName': senderName,
          'senderPhotoUrl': senderPhotoUrl,
        },
      );

      return const Right(null);
    }, sinon: (e) => ServerFailure(e.toString()));
  }

  @override
  Future<Either<Failure, void>> acceptFriendRequest(String requestId) async {
    return garderAppel(() async {
      // Get request details before accepting to know who to notify
      final requestDoc = await dataSource.getRequestById(requestId);

      await dataSource.acceptFriendRequest(requestId);

      // Notify the sender that their request was accepted
      await NotificationService().createNotification(
        userId: requestDoc.senderId,
        title: 'Demande d\'ami acceptée',
        body: '${requestDoc.receiverName} a accepté votre demande d\'ami',
        type: 'friendAccepted',
        targetId: requestDoc.receiverId,
        data: {
          'receiverId': requestDoc.receiverId,
          'receiverName': requestDoc.receiverName,
          'receiverPhotoUrl': requestDoc.receiverPhotoUrl,
        },
      );

      return const Right(null);
    }, sinon: (e) => ServerFailure(e.toString()));
  }

  @override
  Future<Either<Failure, void>> declineFriendRequest(String requestId) async {
    return garderAppel(() async {
      await dataSource.declineFriendRequest(requestId);
      return const Right(null);
    }, sinon: (e) => ServerFailure(e.toString()));
  }

  @override
  Future<Either<Failure, void>> cancelFriendRequest(String requestId) async {
    return garderAppel(() async {
      await dataSource.cancelFriendRequest(requestId);
      return const Right(null);
    }, sinon: (e) => ServerFailure(e.toString()));
  }

  @override
  Stream<Either<Failure, List<FriendRequestEntity>>> getReceivedRequests(
    String userId,
  ) {
    return dataSource
        .getReceivedRequests(userId)
        .map((models) {
          return Right<Failure, List<FriendRequestEntity>>(
            models.map((m) => m.toEntity()).toList(),
          );
        })
        .handleError((error) {
          return Left<Failure, List<FriendRequestEntity>>(
            ServerFailure(error.toString()),
          );
        });
  }

  @override
  Stream<Either<Failure, List<FriendRequestEntity>>> getSentRequests(
    String userId,
  ) {
    return dataSource
        .getSentRequests(userId)
        .map((models) {
          return Right<Failure, List<FriendRequestEntity>>(
            models.map((m) => m.toEntity()).toList(),
          );
        })
        .handleError((error) {
          return Left<Failure, List<FriendRequestEntity>>(
            ServerFailure(error.toString()),
          );
        });
  }

  @override
  Future<Either<Failure, FriendshipStatus>> getFriendshipStatus(
    String userId1,
    String userId2,
  ) async {
    return garderAppel(() async {
      final status = await dataSource.getFriendshipStatus(userId1, userId2);
      return Right(status);
    }, sinon: (e) => ServerFailure(e.toString()));
  }

  @override
  Stream<Either<Failure, List<FriendEntity>>> getFriends(String userId) {
    return dataSource
        .getFriends(userId)
        .map((models) {
          return Right<Failure, List<FriendEntity>>(
            models.map((m) => m.toEntity()).toList(),
          );
        })
        .handleError((error) {
          return Left<Failure, List<FriendEntity>>(
            ServerFailure(error.toString()),
          );
        });
  }

  @override
  Future<Either<Failure, void>> removeFriend(
    String userId,
    String friendId,
  ) async {
    return garderAppel(() async {
      await dataSource.removeFriend(userId, friendId);
      return const Right(null);
    }, sinon: (e) => ServerFailure(e.toString()));
  }

  @override
  Future<Either<Failure, bool>> areFriends(
    String userId1,
    String userId2,
  ) async {
    return garderAppel(() async {
      final result = await dataSource.areFriends(userId1, userId2);
      return Right(result);
    }, sinon: (e) => ServerFailure(e.toString()));
  }

  @override
  Future<Either<Failure, List<FriendEntity>>> searchFriends(
    String userId,
    String query,
  ) async {
    return garderAppel(() async {
      final models = await dataSource.searchFriends(userId, query);
      return Right(models.map((m) => m.toEntity()).toList());
    }, sinon: (e) => ServerFailure(e.toString()));
  }
}
