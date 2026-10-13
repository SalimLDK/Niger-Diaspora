import 'package:diaspo_niger/core/errors/app_error_messages.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/garde_appel.dart';
import '../../../../core/services/connectivity_service.dart';
import '../../../profile/data/models/profile_model.dart';
import '../../../groups/domain/entities/group_entity.dart';
import '../../../friends/domain/entities/friend_entity.dart';
import '../../../messages/domain/entities/conversation_entity.dart';
import '../../domain/entities/search_result.dart';
import '../../domain/repositories/search_repository.dart';
import '../datasources/search_remote_datasource.dart';

/// Implémentation du repository de recherche
class SearchRepositoryImpl implements SearchRepository {
  final SearchRemoteDataSource remoteDataSource;
  final ConnectivityService connectivityService;

  SearchRepositoryImpl({
    required this.remoteDataSource,
    required this.connectivityService,
  });

  @override
  Future<Either<Failure, SearchResult>> searchAll({
    required String query,
    required String? userId,
    int limit = 20,
  }) async {
    return garderAppel(() async {
      final isConnected = await connectivityService.isConnected();

      if (!isConnected) {
        return Left(NetworkFailure(AppErrorMessages.networkError));
      }

      final result = await remoteDataSource.searchAll(
        query: query,
        userId: userId,
        limit: limit,
      );

      // Sauvegarder la recherche récente
      if (userId != null && query.trim().isNotEmpty) {
        await remoteDataSource.saveRecentSearch(
          userId: userId,
          query: query,
        );
      }

      return Right(result.toEntity());
    }, sinon: (e) {
      debugPrint('SearchRepository: Unexpected error: $e');
      return const ServerFailure('Erreur lors de la recherche');
    });
  }

  @override
  Future<Either<Failure, List<ProfileModel>>> searchProfiles({
    required String query,
    int limit = 20,
  }) async {
    return garderAppel(() async {
      final isConnected = await connectivityService.isConnected();

      if (!isConnected) {
        return Left(NetworkFailure(AppErrorMessages.networkError));
      }

      final result = await remoteDataSource.searchProfiles(
        query: query,
        limit: limit,
      );

      return Right(result);
    }, sinon: (e) {
      debugPrint('SearchRepository: Error searching profiles: $e');
      return const ServerFailure('Erreur lors de la recherche de profils');
    });
  }

  @override
  Future<Either<Failure, List<GroupEntity>>> searchGroups({
    required String query,
    int limit = 20,
  }) async {
    return garderAppel(() async {
      final isConnected = await connectivityService.isConnected();

      if (!isConnected) {
        return Left(NetworkFailure(AppErrorMessages.networkError));
      }

      final result = await remoteDataSource.searchGroups(
        query: query,
        limit: limit,
      );

      return Right(result.map((g) => g.toEntity()).toList());
    }, sinon: (e) {
      debugPrint('SearchRepository: Error searching groups: $e');
      return const ServerFailure('Erreur lors de la recherche de groupes');
    });
  }

  @override
  Future<Either<Failure, List<FriendEntity>>> searchFriends({
    required String userId,
    required String query,
    int limit = 20,
  }) async {
    return garderAppel(() async {
      final isConnected = await connectivityService.isConnected();

      if (!isConnected) {
        return Left(NetworkFailure(AppErrorMessages.networkError));
      }

      final result = await remoteDataSource.searchFriends(
        userId: userId,
        query: query,
        limit: limit,
      );

      return Right(result.map((f) => f.toEntity()).toList());
    }, sinon: (e) {
      debugPrint('SearchRepository: Error searching friends: $e');
      return const ServerFailure('Erreur lors de la recherche d\'amis');
    });
  }

  @override
  Future<Either<Failure, List<ConversationEntity>>> searchConversations({
    required String userId,
    required String query,
    int limit = 20,
  }) async {
    return garderAppel(() async {
      final isConnected = await connectivityService.isConnected();

      if (!isConnected) {
        return Left(NetworkFailure(AppErrorMessages.networkError));
      }

      final result = await remoteDataSource.searchConversations(
        userId: userId,
        query: query,
        limit: limit,
      );

      return Right(result.map((c) => c.toEntity()).toList());
    }, sinon: (e) {
      debugPrint('SearchRepository: Error searching conversations: $e');
      return const ServerFailure('Erreur lors de la recherche de conversations');
    });
  }

  @override
  Future<Either<Failure, List<String>>> getRecentSearches({
    required String userId,
    int limit = 10,
  }) async {
    return garderAppel(() async {
      final result = await remoteDataSource.getRecentSearches(
        userId: userId,
        limit: limit,
      );
      return Right(result);
    }, sinon: (e) {
      debugPrint('SearchRepository: Error getting recent searches: $e');
      return const CacheFailure('Erreur lors de la récupération des recherches récentes');
    });
  }

  @override
  Future<Either<Failure, void>> saveRecentSearch({
    required String userId,
    required String query,
  }) async {
    return garderAppel(() async {
      await remoteDataSource.saveRecentSearch(userId: userId, query: query);
      return const Right(null);
    }, sinon: (e) {
      debugPrint('SearchRepository: Error saving recent search: $e');
      return const CacheFailure('Erreur lors de la sauvegarde de la recherche');
    });
  }

  @override
  Future<Either<Failure, void>> removeRecentSearch({
    required String userId,
    required String query,
  }) async {
    return garderAppel(() async {
      await remoteDataSource.removeRecentSearch(userId: userId, query: query);
      return const Right(null);
    }, sinon: (e) {
      debugPrint('SearchRepository: Error removing recent search: $e');
      return const CacheFailure('Erreur lors de la suppression de la recherche');
    });
  }

  @override
  Future<Either<Failure, void>> clearRecentSearches({
    required String userId,
  }) async {
    return garderAppel(() async {
      await remoteDataSource.clearRecentSearches(userId: userId);
      return const Right(null);
    }, sinon: (e) {
      debugPrint('SearchRepository: Error clearing recent searches: $e');
      return const CacheFailure('Erreur lors de la suppression des recherches');
    });
  }
}
