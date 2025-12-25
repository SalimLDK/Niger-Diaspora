import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/blocked_user_entity.dart';
import '../../domain/repositories/blocked_users_repository.dart';
import '../datasources/blocked_users_datasource.dart';

class BlockedUsersRepositoryImpl implements BlockedUsersRepository {
  final BlockedUsersDataSource dataSource;

  BlockedUsersRepositoryImpl({required this.dataSource});

  @override
  Stream<Either<Failure, List<BlockedUserEntity>>> getBlockedUsers(String userId) {
    return dataSource.getBlockedUsers(userId).map((models) {
      return Right<Failure, List<BlockedUserEntity>>(
        models.map((m) => m.toEntity()).toList(),
      );
    }).handleError((error) {
      return Left<Failure, List<BlockedUserEntity>>(
        ServerFailure(error.toString()),
      );
    });
  }

  @override
  Future<Either<Failure, void>> blockUser(
    String currentUserId,
    String targetUserId,
    String targetDisplayName,
    String? targetPhotoUrl,
  ) async {
    try {
      await dataSource.blockUser(currentUserId, targetUserId, targetDisplayName, targetPhotoUrl);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> unblockUser(String currentUserId, String targetUserId) async {
    try {
      await dataSource.unblockUser(currentUserId, targetUserId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
