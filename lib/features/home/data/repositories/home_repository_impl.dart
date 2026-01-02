import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/cache_service.dart';
import '../../../../core/services/connectivity_service.dart';
import '../../domain/entities/home_content.dart';
import '../../domain/repositories/home_repository.dart';
import '../datasources/home_remote_datasource.dart';
import '../models/home_content_model.dart';

/// Implémentation du repository Home avec support offline
class HomeRepositoryImpl implements HomeRepository {
  final HomeRemoteDataSource remoteDataSource;
  final CacheService cacheService;
  final ConnectivityService connectivityService;

  static const String _cacheKey = 'home_content';

  HomeRepositoryImpl({
    required this.remoteDataSource,
    required this.cacheService,
    required this.connectivityService,
  });

  @override
  Future<Either<Failure, HomeContent>> getHomeContent({
    required String userId,
    double? latitude,
    double? longitude,
    int nearbyMembersLimit = 10,
    int upcomingEventsLimit = 5,
  }) async {
    try {
      final isConnected = await connectivityService.isConnected();

      if (isConnected) {
        // Récupérer depuis le serveur
        final result = await remoteDataSource.getHomeContent(
          userId: userId,
          latitude: latitude,
          longitude: longitude,
          nearbyMembersLimit: nearbyMembersLimit,
          upcomingEventsLimit: upcomingEventsLimit,
        );

        // Mettre en cache
        await _cacheHomeContent(result);

        return Right(result.toEntity());
      } else {
        // Mode offline - récupérer depuis le cache
        final cached = _getCachedHomeContent();
        if (cached != null) {
          return Right(cached.toEntity());
        }
        return const Left(NetworkFailure('Pas de connexion internet'));
      }
    } on ServerException catch (e) {
      debugPrint('HomeRepository: Server error: $e');

      // Essayer le cache en cas d'erreur serveur
      final cached = _getCachedHomeContent();
      if (cached != null) {
        return Right(cached.toEntity());
      }

      return Left(ServerFailure(e.message));
    } catch (e) {
      debugPrint('HomeRepository: Unexpected error: $e');
      return const Left(ServerFailure('Erreur inattendue'));
    }
  }

  @override
  Future<Either<Failure, HomeStats>> getHomeStats({
    required String userId,
  }) async {
    try {
      final isConnected = await connectivityService.isConnected();

      if (isConnected) {
        final result = await remoteDataSource.getHomeStats(userId: userId);
        return Right(result.toEntity());
      } else {
        // Essayer le cache
        final cached = _getCachedHomeContent();
        if (cached != null) {
          return Right(cached.stats.toEntity());
        }
        return const Left(NetworkFailure('Pas de connexion internet'));
      }
    } catch (e) {
      debugPrint('HomeRepository: Error getting stats: $e');
      return const Left(ServerFailure('Erreur lors de la récupération des statistiques'));
    }
  }

  @override
  Future<Either<Failure, List<NearbyMember>>> getNearbyMembers({
    required String userId,
    required double latitude,
    required double longitude,
    double radiusKm = 50,
    int limit = 20,
  }) async {
    try {
      final isConnected = await connectivityService.isConnected();

      if (!isConnected) {
        // En mode offline, retourner les données cachées
        final cached = _getCachedHomeContent();
        if (cached != null) {
          return Right(cached.nearbyMembers.map((m) => m.toEntity()).toList());
        }
        return const Left(NetworkFailure('Pas de connexion internet'));
      }

      final result = await remoteDataSource.getNearbyMembers(
        userId: userId,
        latitude: latitude,
        longitude: longitude,
        radiusKm: radiusKm,
        limit: limit,
      );

      return Right(result.map((m) => m.toEntity()).toList());
    } catch (e) {
      debugPrint('HomeRepository: Error getting nearby members: $e');
      return const Left(ServerFailure('Erreur lors de la récupération des membres proches'));
    }
  }

  @override
  Future<Either<Failure, List<UpcomingEvent>>> getUpcomingEvents({
    required String userId,
    int limit = 10,
  }) async {
    try {
      final isConnected = await connectivityService.isConnected();

      if (!isConnected) {
        final cached = _getCachedHomeContent();
        if (cached != null) {
          return Right(cached.upcomingEvents.map((e) => e.toEntity()).toList());
        }
        return const Left(NetworkFailure('Pas de connexion internet'));
      }

      final result = await remoteDataSource.getUpcomingEvents(
        userId: userId,
        limit: limit,
      );

      return Right(result.map((e) => e.toEntity()).toList());
    } catch (e) {
      debugPrint('HomeRepository: Error getting upcoming events: $e');
      return const Left(ServerFailure('Erreur lors de la récupération des événements'));
    }
  }

  @override
  Future<Either<Failure, HomeContent>> refreshHomeContent({
    required String userId,
    double? latitude,
    double? longitude,
  }) async {
    // Force refresh depuis le serveur
    try {
      final result = await remoteDataSource.getHomeContent(
        userId: userId,
        latitude: latitude,
        longitude: longitude,
      );

      await _cacheHomeContent(result);
      return Right(result.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      debugPrint('HomeRepository: Error refreshing content: $e');
      return const Left(ServerFailure('Erreur lors du rafraîchissement'));
    }
  }

  /// Met en cache le contenu Home
  Future<void> _cacheHomeContent(HomeContentModel content) async {
    try {
      await cacheService.cacheProfile(_cacheKey, content.toJson());
    } catch (e) {
      debugPrint('HomeRepository: Error caching content: $e');
    }
  }

  /// Récupère le contenu Home depuis le cache
  HomeContentModel? _getCachedHomeContent() {
    try {
      final cached = cacheService.getCachedProfile(_cacheKey);
      if (cached != null) {
        return HomeContentModel.fromJson(cached);
      }
    } catch (e) {
      debugPrint('HomeRepository: Error reading cache: $e');
    }
    return null;
  }
}
