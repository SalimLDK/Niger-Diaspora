import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/group_entity.dart';

abstract class GroupRepository {
  Future<Either<Failure, List<GroupEntity>>> getGroups();
  Future<Either<Failure, List<GroupEntity>>> getGroupsByCategory(GroupCategory category);
  Future<Either<Failure, GroupEntity>> getGroupById(String groupId);
  Future<Either<Failure, GroupEntity>> createGroup(GroupEntity group);
  Future<Either<Failure, GroupEntity>> updateGroup(GroupEntity group);
  Future<Either<Failure, void>> deleteGroup(String groupId);
  Future<Either<Failure, void>> joinGroup(String groupId, String userId);
  Future<Either<Failure, void>> leaveGroup(String groupId, String userId);
  Future<Either<Failure, List<GroupEntity>>> getMyGroups(String userId);
  Future<Either<Failure, List<GroupEntity>>> searchGroups(String query);
}
