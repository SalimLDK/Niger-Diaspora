import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/services/notification_service.dart';
import '../../domain/entities/profile_entity.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_remote_datasource.dart';
import '../models/profile_model.dart';
import '../../../../core/utils/string_utils.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final ProfileRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  ProfileRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, ProfileEntity>> getProfile(String userId) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('Pas de connexion internet'));
    }

    try {
      final profile = await remoteDataSource.getProfile(userId);
      return Right(profile.toEntity());
    } on ServerException catch (e) {
      if (e.message.contains('non trouvé')) {
        return Right(
          ProfileEntity(
            id: userId,
            displayName: 'Utilisateur supprimé',
            photoUrl: null,
            bio: 'Ce profil n\'existe plus.',
          ),
        );
      }
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, ProfileEntity>> updateProfile(
    ProfileEntity profile,
  ) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('Pas de connexion internet'));
    }

    try {
      // 1. Get current profile to check if location changed
      ProfileModel? oldProfile;
      try {
        oldProfile = await remoteDataSource.getProfile(profile.id);
      } catch (_) {
        // Ignore error if profile fetch fails, treating as new location setup
      }

      // 2. Update profile
      final profileModel = ProfileModel.fromEntity(profile);
      final updatedProfile = await remoteDataSource.updateProfile(profileModel);

      // 3. Handle topic subscriptions if location changed
      if (oldProfile?.currentCountry != profile.currentCountry ||
          oldProfile?.currentCity != profile.currentCity) {
        // Unsubscribe from old topics if they exist
        if (oldProfile?.currentCountry != null) {
          final country = StringUtils.normalizeTopic(
            oldProfile!.currentCountry!,
          );
          await NotificationService().unsubscribeFromTopic('events_$country');

          if (oldProfile.currentCity != null) {
            final city = StringUtils.normalizeTopic(oldProfile.currentCity!);
            await NotificationService().unsubscribeFromTopic(
              'events_${country}_$city',
            );
          }
        }

        // Subscribe to new topics
        if (profile.currentCountry != null) {
          final country = StringUtils.normalizeTopic(profile.currentCountry!);
          await NotificationService().subscribeToTopic('events_$country');

          if (profile.currentCity != null) {
            final city = StringUtils.normalizeTopic(profile.currentCity!);
            await NotificationService().subscribeToTopic(
              'events_${country}_$city',
            );
          }
        }
      }

      return Right(updatedProfile.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, String>> uploadProfilePhoto(
    String userId,
    String filePath,
  ) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('Pas de connexion internet'));
    }

    try {
      final url = await remoteDataSource.uploadProfilePhoto(userId, filePath);
      return Right(url);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> updateLocation(
    String userId,
    double latitude,
    double longitude,
  ) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('Pas de connexion internet'));
    }

    try {
      await remoteDataSource.updateLocation(userId, latitude, longitude);

      // Check for nearby members (5km)
      try {
        final nearbyProfiles = await remoteDataSource.getNearbyProfiles(
          latitude,
          longitude,
          5.0, // 5km radius
        );

        // Filter out current user
        final otherMembers =
            nearbyProfiles.where((p) => p.id != userId).toList();

        if (otherMembers.isNotEmpty) {
          await NotificationService().showProximityNotification(
            otherMembers.length,
          );
        }
      } catch (e) {
        // Silently fail for proximity check to not bloat main logic errors
        debugPrint('Error checking nearby members: $e');
      }

      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<ProfileEntity>>> getNearbyProfiles(
    double latitude,
    double longitude,
    double radiusKm,
  ) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('Pas de connexion internet'));
    }

    try {
      final profiles = await remoteDataSource.getNearbyProfiles(
        latitude,
        longitude,
        radiusKm,
      );
      return Right(profiles.map((p) => p.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<ProfileEntity>>> searchProfiles(
    String query,
  ) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('Pas de connexion internet'));
    }

    try {
      final profiles = await remoteDataSource.searchProfiles(query);
      return Right(profiles.map((p) => p.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Stream<Either<Failure, ProfileEntity>> getUserStream(String userId) {
    return remoteDataSource
        .getUserStream(userId)
        .map((model) {
          return Right<Failure, ProfileEntity>(model.toEntity());
        })
        .handleError((error) {
          if (error is ServerException) {
            if (error.message.contains('non trouvé')) {
              return Right<Failure, ProfileEntity>(
                ProfileEntity(
                  id: userId,
                  displayName: 'Utilisateur supprimé',
                  photoUrl: null,
                  bio: 'Ce profil n\'existe plus.',
                ),
              );
            }
            return Left<Failure, ProfileEntity>(ServerFailure(error.message));
          }
          return Left<Failure, ProfileEntity>(ServerFailure(error.toString()));
        });
  }

  @override
  Future<Either<Failure, void>> updateOnlineStatus(
    String userId,
    bool isOnline,
    DateTime lastSeen,
  ) async {
    // Note: status updates usually happen silently/background, so we might skip connectivity check or handle it gratefully
    // But for consistency we check it
    if (!await networkInfo.isConnected) {
      // For online status, we might just ignore if offline
      return const Left(NetworkFailure('Pas de connexion internet'));
    }

    try {
      await remoteDataSource.updateOnlineStatus(userId, isOnline, lastSeen);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> updateOnlineStatusVisibility(
    String userId,
    bool showStatus,
  ) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('Pas de connexion internet'));
    }

    try {
      await remoteDataSource.updateOnlineStatusVisibility(userId, showStatus);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
