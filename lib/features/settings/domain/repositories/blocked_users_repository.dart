import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/blocked_user_entity.dart';

abstract class BlockedUsersRepository {
  Stream<Either<Failure, List<BlockedUserEntity>>> getBlockedUsers(String userId);
  Future<Either<Failure, void>> blockUser(
    String currentUserId,
    String targetUserId,
    String targetDisplayName,
    String? targetPhotoUrl,
  );
  Future<Either<Failure, void>> unblockUser(String currentUserId, String targetUserId);
  Future<Either<Failure, bool>> checkBlockStatus(String currentUserId, String targetUserId);
}
