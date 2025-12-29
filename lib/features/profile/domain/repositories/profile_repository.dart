import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/profile_entity.dart';

abstract class ProfileRepository {
  Future<Either<Failure, ProfileEntity>> getProfile(String userId);
  Either<Failure, ProfileEntity?> getCachedProfile(String userId);
  Future<Either<Failure, ProfileEntity>> updateProfile(ProfileEntity profile);
  Future<Either<Failure, String>> uploadProfilePhoto(
    String userId,
    String filePath,
  );
  Future<Either<Failure, void>> updateLocation(
    String userId,
    double latitude,
    double longitude,
  );
  Future<Either<Failure, List<ProfileEntity>>> getNearbyProfiles(
    double latitude,
    double longitude,
    double radiusKm,
  );
  Future<Either<Failure, List<ProfileEntity>>> searchProfiles(String query);
  Stream<Either<Failure, ProfileEntity>> getUserStream(String userId);
  Future<Either<Failure, void>> updateOnlineStatus(
    String userId,
    bool isOnline,
    DateTime lastSeen,
  );
  Future<Either<Failure, void>> updateOnlineStatusVisibility(
    String userId,
    bool showStatus,
  );
}
