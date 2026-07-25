import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/group_entity.dart';

import '../entities/group_request_entity.dart'; // Ensure import

abstract class GroupRepository {
  Either<Failure, List<GroupEntity>> getCachedGroups();
  Future<Either<Failure, List<GroupEntity>>> getGroups();
  Future<Either<Failure, List<GroupEntity>>> getGroupsByCategory(
    GroupCategory category,
  );
  Future<Either<Failure, GroupEntity>> getGroupById(String groupId);
  Stream<Either<Failure, GroupEntity?>> getGroupStream(String groupId);
  Future<Either<Failure, GroupEntity>> createGroup(GroupEntity group);
  Future<Either<Failure, GroupEntity>> updateGroup(GroupEntity group);
  Future<Either<Failure, void>> deleteGroup(String groupId);
  Future<Either<Failure, void>> joinGroup(String groupId, String userId);
  Future<Either<Failure, void>> leaveGroup(String groupId, String userId);
  Future<Either<Failure, void>> removeMember(String groupId, String userId);
  Future<Either<Failure, List<GroupEntity>>> getMyGroups(String userId);
  Future<Either<Failure, List<GroupEntity>>> searchGroups(String query);

  // Join Requests
  Future<Either<Failure, void>> requestToJoinGroup({
    required String groupId,
    required String groupName,
    String? groupImageUrl,
    required String requesterId,
    required String requesterName,
    String? requesterPhotoUrl,
    String? message,
  });
  Future<Either<Failure, void>> approveJoinRequest(String requestId);
  Future<Either<Failure, void>> rejectJoinRequest(String requestId);
  Stream<Either<Failure, List<GroupRequestEntity>>> getPendingRequests(
    String groupId,
  );
  Stream<Either<Failure, List<GroupRequestEntity>>> getMyGroupRequests(
    String userId,
  );

  /// Get or create the official country group and return it.
  Future<Either<Failure, GroupEntity>> ensureOfficialGroup({
    required String countryCode,
    required String countryName,
  });
}
