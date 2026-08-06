import 'package:diaspo_niger/core/errors/app_error_messages.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/services/cache_service.dart';
import '../../../messages/domain/repositories/message_repository.dart';
import '../../domain/entities/group_entity.dart';
import '../../domain/repositories/group_repository.dart';
import '../datasources/group_remote_datasource.dart';
import '../datasources/group_request_datasource.dart';
import '../models/group_model.dart';
import '../../domain/entities/group_request_entity.dart';

class GroupRepositoryImpl implements GroupRepository {
  final GroupRemoteDataSource remoteDataSource;
  final GroupRequestDataSource requestDataSource;
  final NetworkInfo networkInfo;
  final CacheService cacheService;
  final MessageRepository messageRepository;

  GroupRepositoryImpl({
    required this.remoteDataSource,
    required this.requestDataSource,
    required this.networkInfo,
    required this.messageRepository,
    CacheService? cacheService,
  }) : cacheService = cacheService ?? CacheService.instance;

  @override
  Either<Failure, List<GroupEntity>> getCachedGroups() {
    try {
      final cachedData = cacheService.getAllCachedGroups();
      final entities =
          cachedData
              .map((data) => GroupModel.fromJson(data).toEntity())
              .toList();
      return Right(entities);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<GroupEntity>>> getGroups() async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }
    try {
      final groups = await remoteDataSource.getGroups();
      return Right(groups.map((g) => g.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      // Tout le reste — PostgrestException, erreur de session, décodage —
      // s'échappait de ce `catch` limité à ServerException : le Future
      // remontait en exception, `result.fold` n'était jamais atteint, et
      // l'écran gardait son état précédent sans rien dire. C'est ainsi que
      // « Découvrir » annonçait « Aucun groupe public » avec trois groupes
      // publics en base, et que « Créer le groupe » restait sans effet.
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<GroupEntity>>> getGroupsByCategory(
    GroupCategory category,
  ) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }
    try {
      final groups = await remoteDataSource.getGroupsByCategory(category.name);
      return Right(groups.map((g) => g.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      // Tout le reste — PostgrestException, erreur de session, décodage —
      // s'échappait de ce `catch` limité à ServerException : le Future
      // remontait en exception, `result.fold` n'était jamais atteint, et
      // l'écran gardait son état précédent sans rien dire. C'est ainsi que
      // « Découvrir » annonçait « Aucun groupe public » avec trois groupes
      // publics en base, et que « Créer le groupe » restait sans effet.
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, GroupEntity>> getGroupById(String groupId) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }
    try {
      final group = await remoteDataSource.getGroupById(groupId);
      return Right(group.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      // Tout le reste — PostgrestException, erreur de session, décodage —
      // s'échappait de ce `catch` limité à ServerException : le Future
      // remontait en exception, `result.fold` n'était jamais atteint, et
      // l'écran gardait son état précédent sans rien dire. C'est ainsi que
      // « Découvrir » annonçait « Aucun groupe public » avec trois groupes
      // publics en base, et que « Créer le groupe » restait sans effet.
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Stream<Either<Failure, GroupEntity?>> getGroupStream(String groupId) {
    try {
      return remoteDataSource
          .getGroupStream(groupId)
          .map<Either<Failure, GroupEntity?>>((groupModel) {
            if (groupModel == null) {
              return const Right(null);
            }
            return Right(groupModel.toEntity());
          })
          .handleError((error) {
            if (error is ServerException) {
              return Left(ServerFailure(error.message));
            }
            return Left(ServerFailure(error.toString()));
          });
    } catch (e) {
      return Stream.value(Left(ServerFailure(e.toString())));
    }
  }

  @override
  Future<Either<Failure, GroupEntity>> createGroup(GroupEntity group) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }
    try {
      final groupModel = GroupModel.fromEntity(group);
      final created = await remoteDataSource.createGroup(groupModel);

      // Le groupe existe désormais côté serveur. Ce qui suit est accessoire :
      // si la création de la conversation échoue, on ne doit pas faire croire
      // que la création a échoué — sinon l'écran affiche une erreur alors que
      // le groupe est bel et bien créé.
      try {
        await messageRepository.createGroupConversation(
          creatorId: created.creatorId,
          participantIds: created.memberIds,
          groupName: created.name,
          groupImageUrl: created.imageUrl,
          groupId: created.id,
        );
      } catch (e) {
        debugPrint('createGroup: étape accessoire échouée — $e');
      }

      return Right(created.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      // Un PostgrestException (RLS, RPC absente…) n'est pas une
      // ServerException : sans ce filet, il traversait le dépôt, le notifier
      // et l'écran, et le bouton restait muet.
      return Left(ServerFailure('$e'));
    }
  }

  @override
  Future<Either<Failure, GroupEntity>> updateGroup(GroupEntity group) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }
    try {
      final groupModel = GroupModel.fromEntity(group);
      final updated = await remoteDataSource.updateGroup(groupModel);
      return Right(updated.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      // Tout le reste — PostgrestException, erreur de session, décodage —
      // s'échappait de ce `catch` limité à ServerException : le Future
      // remontait en exception, `result.fold` n'était jamais atteint, et
      // l'écran gardait son état précédent sans rien dire. C'est ainsi que
      // « Découvrir » annonçait « Aucun groupe public » avec trois groupes
      // publics en base, et que « Créer le groupe » restait sans effet.
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteGroup(String groupId) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }
    try {
      await remoteDataSource.deleteGroup(groupId);

      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      // Tout le reste — PostgrestException, erreur de session, décodage —
      // s'échappait de ce `catch` limité à ServerException : le Future
      // remontait en exception, `result.fold` n'était jamais atteint, et
      // l'écran gardait son état précédent sans rien dire. C'est ainsi que
      // « Découvrir » annonçait « Aucun groupe public » avec trois groupes
      // publics en base, et que « Créer le groupe » restait sans effet.
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> joinGroup(String groupId, String userId) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }
    try {
      await remoteDataSource.joinGroup(groupId, userId);

      // Ajoute immédiatement userId aux participants de la conversation du
      // groupe : sans cet appel, le groupe restait absent de l'onglet
      // Messages jusqu'à ce qu'un autre déclencheur (galerie média du
      // groupe, etc.) retrouve la conversation et rattrape le manque.
      // Non-bloquant : un échec ici ne doit pas faire échouer le join.
      await messageRepository.findGroupConversationByGroupId(
        groupId: groupId,
        userId: userId,
      );

      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      // Tout le reste — PostgrestException, erreur de session, décodage —
      // s'échappait de ce `catch` limité à ServerException : le Future
      // remontait en exception, `result.fold` n'était jamais atteint, et
      // l'écran gardait son état précédent sans rien dire. C'est ainsi que
      // « Découvrir » annonçait « Aucun groupe public » avec trois groupes
      // publics en base, et que « Créer le groupe » restait sans effet.
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> leaveGroup(
    String groupId,
    String userId,
  ) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }
    try {
      await remoteDataSource.leaveGroup(groupId, userId);

      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      // Tout le reste — PostgrestException, erreur de session, décodage —
      // s'échappait de ce `catch` limité à ServerException : le Future
      // remontait en exception, `result.fold` n'était jamais atteint, et
      // l'écran gardait son état précédent sans rien dire. C'est ainsi que
      // « Découvrir » annonçait « Aucun groupe public » avec trois groupes
      // publics en base, et que « Créer le groupe » restait sans effet.
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> removeMember(
    String groupId,
    String userId,
  ) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }
    try {
      await remoteDataSource.removeMember(groupId, userId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      // Tout le reste — PostgrestException, erreur de session, décodage —
      // s'échappait de ce `catch` limité à ServerException : le Future
      // remontait en exception, `result.fold` n'était jamais atteint, et
      // l'écran gardait son état précédent sans rien dire. C'est ainsi que
      // « Découvrir » annonçait « Aucun groupe public » avec trois groupes
      // publics en base, et que « Créer le groupe » restait sans effet.
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<GroupEntity>>> getMyGroups(String userId) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }
    try {
      final groups = await remoteDataSource.getMyGroups(userId);
      return Right(groups.map((g) => g.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      // Tout le reste — PostgrestException, erreur de session, décodage —
      // s'échappait de ce `catch` limité à ServerException : le Future
      // remontait en exception, `result.fold` n'était jamais atteint, et
      // l'écran gardait son état précédent sans rien dire. C'est ainsi que
      // « Découvrir » annonçait « Aucun groupe public » avec trois groupes
      // publics en base, et que « Créer le groupe » restait sans effet.
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<GroupEntity>>> searchGroups(String query) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }
    try {
      final groups = await remoteDataSource.searchGroups(query);
      return Right(groups.map((g) => g.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      // Tout le reste — PostgrestException, erreur de session, décodage —
      // s'échappait de ce `catch` limité à ServerException : le Future
      // remontait en exception, `result.fold` n'était jamais atteint, et
      // l'écran gardait son état précédent sans rien dire. C'est ainsi que
      // « Découvrir » annonçait « Aucun groupe public » avec trois groupes
      // publics en base, et que « Créer le groupe » restait sans effet.
      return Left(ServerFailure(e.toString()));
    }
  }

  // Join Requests
  @override
  Future<Either<Failure, void>> requestToJoinGroup({
    required String groupId,
    required String groupName,
    String? groupImageUrl,
    required String requesterId,
    required String requesterName,
    String? requesterPhotoUrl,
    String? message,
  }) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }
    try {
      await requestDataSource.requestToJoinGroup(
        groupId: groupId,
        groupName: groupName,
        groupImageUrl: groupImageUrl,
        requesterId: requesterId,
        requesterName: requesterName,
        requesterPhotoUrl: requesterPhotoUrl,
        message: message,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      // Tout le reste — PostgrestException, erreur de session, décodage —
      // s'échappait de ce `catch` limité à ServerException : le Future
      // remontait en exception, `result.fold` n'était jamais atteint, et
      // l'écran gardait son état précédent sans rien dire. C'est ainsi que
      // « Découvrir » annonçait « Aucun groupe public » avec trois groupes
      // publics en base, et que « Créer le groupe » restait sans effet.
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> approveJoinRequest(String requestId) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }
    try {
      await requestDataSource.approveJoinRequest(requestId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      // Tout le reste — PostgrestException, erreur de session, décodage —
      // s'échappait de ce `catch` limité à ServerException : le Future
      // remontait en exception, `result.fold` n'était jamais atteint, et
      // l'écran gardait son état précédent sans rien dire. C'est ainsi que
      // « Découvrir » annonçait « Aucun groupe public » avec trois groupes
      // publics en base, et que « Créer le groupe » restait sans effet.
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> rejectJoinRequest(String requestId) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }
    try {
      await requestDataSource.rejectJoinRequest(requestId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      // Tout le reste — PostgrestException, erreur de session, décodage —
      // s'échappait de ce `catch` limité à ServerException : le Future
      // remontait en exception, `result.fold` n'était jamais atteint, et
      // l'écran gardait son état précédent sans rien dire. C'est ainsi que
      // « Découvrir » annonçait « Aucun groupe public » avec trois groupes
      // publics en base, et que « Créer le groupe » restait sans effet.
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Stream<Either<Failure, List<GroupRequestEntity>>> getPendingRequests(
    String groupId,
  ) {
    try {
      return requestDataSource
          .getPendingRequests(groupId)
          .map<Either<Failure, List<GroupRequestEntity>>>((models) {
            return Right(models.map((m) => m.toEntity()).toList());
          })
          .handleError((error) {
            if (error is ServerException) {
              return Left(ServerFailure(error.message));
            }
            return Left(ServerFailure(error.toString()));
          });
    } catch (e) {
      return Stream.value(Left(ServerFailure(e.toString())));
    }
  }

  @override
  Stream<Either<Failure, List<GroupRequestEntity>>> getMyGroupRequests(
    String userId,
  ) {
    try {
      return requestDataSource
          .getMyGroupRequests(userId)
          .map<Either<Failure, List<GroupRequestEntity>>>((models) {
            return Right(models.map((m) => m.toEntity()).toList());
          })
          .handleError((error) {
            if (error is ServerException) {
              return Left(ServerFailure(error.message));
            }
            return Left(ServerFailure(error.toString()));
          });
    } catch (e) {
      return Stream.value(Left(ServerFailure(e.toString())));
    }
  }

  @override
  Future<Either<Failure, GroupEntity>> ensureOfficialGroup({
    required String countryCode,
    required String countryName,
  }) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure(AppErrorMessages.networkError));
    }
    try {
      final model = await remoteDataSource.ensureOfficialGroup(
        countryCode: countryCode,
        countryName: countryName,
      );
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
