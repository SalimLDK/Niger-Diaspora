import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/services/notification_service.dart';
import '../../domain/entities/group_entity.dart';
import '../../domain/repositories/group_repository.dart';
import '../datasources/group_remote_datasource.dart';
import '../models/group_model.dart';

class GroupRepositoryImpl implements GroupRepository {
  final GroupRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  GroupRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, List<GroupEntity>>> getGroups() async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('Pas de connexion internet'));
    }
    try {
      final groups = await remoteDataSource.getGroups();
      return Right(groups.map((g) => g.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<GroupEntity>>> getGroupsByCategory(
    GroupCategory category,
  ) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('Pas de connexion internet'));
    }
    try {
      final groups = await remoteDataSource.getGroupsByCategory(category.name);
      return Right(groups.map((g) => g.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, GroupEntity>> getGroupById(String groupId) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('Pas de connexion internet'));
    }
    try {
      final group = await remoteDataSource.getGroupById(groupId);
      return Right(group.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, GroupEntity>> createGroup(GroupEntity group) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('Pas de connexion internet'));
    }
    try {
      final groupModel = GroupModel.fromEntity(group);
      final created = await remoteDataSource.createGroup(groupModel);

      // Subscribe to group topic
      await NotificationService().subscribeToTopic('group_${created.id}');

      return Right(created.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, GroupEntity>> updateGroup(GroupEntity group) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('Pas de connexion internet'));
    }
    try {
      final groupModel = GroupModel.fromEntity(group);
      final updated = await remoteDataSource.updateGroup(groupModel);
      return Right(updated.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> deleteGroup(String groupId) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('Pas de connexion internet'));
    }
    try {
      await remoteDataSource.deleteGroup(groupId);

      // Unsubscribe from group topic
      await NotificationService().unsubscribeFromTopic('group_$groupId');

      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> joinGroup(String groupId, String userId) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('Pas de connexion internet'));
    }
    try {
      await remoteDataSource.joinGroup(groupId, userId);

      // Subscribe to group topic
      await NotificationService().subscribeToTopic('group_$groupId');

      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> leaveGroup(
    String groupId,
    String userId,
  ) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('Pas de connexion internet'));
    }
    try {
      await remoteDataSource.leaveGroup(groupId, userId);

      // Unsubscribe from group topic
      await NotificationService().unsubscribeFromTopic('group_$groupId');

      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<GroupEntity>>> getMyGroups(String userId) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('Pas de connexion internet'));
    }
    try {
      final groups = await remoteDataSource.getMyGroups(userId);
      return Right(groups.map((g) => g.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<GroupEntity>>> searchGroups(String query) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('Pas de connexion internet'));
    }
    try {
      final groups = await remoteDataSource.searchGroups(query);
      return Right(groups.map((g) => g.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
