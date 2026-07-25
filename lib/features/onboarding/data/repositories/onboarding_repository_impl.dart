import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/exceptions.dart';
import '../../domain/repositories/onboarding_repository.dart';
import '../datasources/onboarding_local_datasource.dart';
import '../datasources/onboarding_remote_datasource.dart';

class OnboardingRepositoryImpl implements OnboardingRepository {
  final OnboardingLocalDataSource _localDataSource;
  final OnboardingRemoteDataSource _remoteDataSource;
  final FirebaseAuth _firebaseAuth;

  OnboardingRepositoryImpl({
    required OnboardingLocalDataSource localDataSource,
    required OnboardingRemoteDataSource remoteDataSource,
    required FirebaseAuth firebaseAuth,
  }) : _localDataSource = localDataSource,
       _remoteDataSource = remoteDataSource,
       _firebaseAuth = firebaseAuth;

  @override
  Future<Either<Failure, bool>> hasSeenOnboarding() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        // Safe default if called when unauthenticated
        return const Right(false);
      }

      // Check local first for speed
      final localResult = await _localDataSource.hasSeenOnboarding(user.uid);
      if (localResult) {
        return const Right(true);
      }

      // If not in local, check remote
      final remoteResult = await _remoteDataSource.hasSeenOnboarding();
      if (remoteResult) {
        // Sync to local
        await _localDataSource.setOnboardingComplete(user.uid);
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
      final user = _firebaseAuth.currentUser;

      // Update remote always if possible
      final remoteFuture = _remoteDataSource.setOnboardingComplete();

      // Update local only if we have a user
      Future<void> localFuture = Future.value();
      if (user != null) {
        localFuture = _localDataSource.setOnboardingComplete(user.uid);
      }

      await Future.wait([localFuture, remoteFuture]);

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
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        return const Right(false);
      }

      // Check local first for speed
      final localResult = await _localDataSource.hasSeenCoachMarks(user.uid);
      if (localResult) {
        return const Right(true);
      }

      // If not in local, check remote
      final remoteResult = await _remoteDataSource.hasSeenCoachMarks();
      if (remoteResult) {
        // Sync to local
        await _localDataSource.setCoachMarksComplete(user.uid);
      }
      return Right(remoteResult);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> markCoachMarksComplete() async {
    try {
      final user = _firebaseAuth.currentUser;

      // Update remote always if possible
      final remoteFuture = _remoteDataSource.setCoachMarksComplete();

      // Update local only if we have a user
      Future<void> localFuture = Future.value();
      if (user != null) {
        localFuture = _localDataSource.setCoachMarksComplete(user.uid);
      }

      await Future.wait([localFuture, remoteFuture]);

      return const Right(null);
    } on ServerException catch (e) {
      // Even if remote fails, local is updated
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> hasGivenConsent() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        return const Right(false);
      }

      final localResult = await _localDataSource.hasGivenConsent(user.uid);
      if (localResult) {
        return const Right(true);
      }

      final remoteResult = await _remoteDataSource.hasGivenConsent();
      if (remoteResult) {
        await _localDataSource.setConsentGiven(user.uid);
      }
      return Right(remoteResult);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> markConsentGiven() async {
    try {
      final user = _firebaseAuth.currentUser;

      final remoteFuture = _remoteDataSource.setConsentGiven();

      Future<void> localFuture = Future.value();
      if (user != null) {
        localFuture = _localDataSource.setConsentGiven(user.uid);
      }

      await Future.wait([localFuture, remoteFuture]);

      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> hasCompletedProfileConfig() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        return const Right(false);
      }

      final localResult =
          await _localDataSource.hasCompletedProfileConfig(user.uid);
      if (localResult) {
        return const Right(true);
      }

      final remoteResult = await _remoteDataSource.hasCompletedProfileConfig();
      if (remoteResult) {
        await _localDataSource.setProfileConfigComplete(user.uid);
      }
      return Right(remoteResult);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> markProfileConfigComplete() async {
    try {
      final user = _firebaseAuth.currentUser;

      final remoteFuture = _remoteDataSource.setProfileConfigComplete();

      Future<void> localFuture = Future.value();
      if (user != null) {
        localFuture = _localDataSource.setProfileConfigComplete(user.uid);
      }

      await Future.wait([localFuture, remoteFuture]);

      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
