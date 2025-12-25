import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/exceptions.dart';
import '../../domain/repositories/onboarding_repository.dart';
import '../datasources/onboarding_local_datasource.dart';
import '../datasources/onboarding_remote_datasource.dart';

class OnboardingRepositoryImpl implements OnboardingRepository {
  final OnboardingLocalDataSource _localDataSource;
  final OnboardingRemoteDataSource _remoteDataSource;

  OnboardingRepositoryImpl({
    required OnboardingLocalDataSource localDataSource,
    required OnboardingRemoteDataSource remoteDataSource,
  })  : _localDataSource = localDataSource,
        _remoteDataSource = remoteDataSource;

  @override
  Future<Either<Failure, bool>> hasSeenOnboarding() async {
    try {
      // Check local first for speed
      final localResult = await _localDataSource.hasSeenOnboarding();
      if (localResult) {
        return const Right(true);
      }

      // If not in local, check remote
      final remoteResult = await _remoteDataSource.hasSeenOnboarding();
      if (remoteResult) {
        // Sync to local
        await _localDataSource.setOnboardingComplete();
      }
      return Right(remoteResult);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> markOnboardingComplete() async {
    try {
      // Update both local and remote
      await Future.wait([
        _localDataSource.setOnboardingComplete(),
        _remoteDataSource.setOnboardingComplete(),
      ]);
      return const Right(null);
    } on ServerException catch (e) {
      // Even if remote fails, local is updated
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> hasSeenCoachMarks() async {
    try {
      final result = await _localDataSource.hasSeenCoachMarks();
      return Right(result);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> markCoachMarksComplete() async {
    try {
      await _localDataSource.setCoachMarksComplete();
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
