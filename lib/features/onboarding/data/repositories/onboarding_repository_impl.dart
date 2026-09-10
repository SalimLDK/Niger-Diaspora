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

  /// Lecture commune aux quatre drapeaux.
  ///
  /// **Un `Left` veut dire « on ne sait pas », jamais « pas fait ».** Les
  /// quatre lectures répondaient `Right(false)` dès que quelque chose se
  /// passait mal — pas d'utilisateur, session Supabase pas encore lisible,
  /// réseau — et `false` est précisément la valeur qui rejoue tout
  /// l'onboarding. Le repli appartient à `OnboardingNotifier`, qui sait ce
  /// que chaque écran coûte quand on le montre à tort ; ici on se contente de
  /// dire ce qu'on a pu établir.
  Future<Either<Failure, bool>> _lireDrapeau({
    required String nom,
    required Future<bool> Function(String uid) local,
    required Future<bool?> Function() distant,
    required Future<void> Function(String uid) memoriser,
  }) async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        return Left(ServerFailure('Lecture de $nom sans utilisateur connecte'));
      }

      // Le local d'abord, pour la vitesse : il n'est écrit qu'après coup et ne
      // redescend jamais à `false`, donc un « oui » local fait foi.
      if (await local(user.uid)) return const Right(true);

      final valeur = await distant();
      if (valeur == null) {
        return Left(ServerFailure('Lecture de $nom indeterminee'));
      }

      // On ne mémorise que ce qui a été lu. Figer un repli en local le
      // rendrait définitif : plus aucune lecture ultérieure ne le corrigerait,
      // puisque le local court-circuite le distant deux lignes plus haut.
      if (valeur) await memoriser(user.uid);
      return Right(valeur);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> hasSeenOnboarding() => _lireDrapeau(
    nom: 'has_seen_onboarding',
    local: _localDataSource.hasSeenOnboarding,
    distant: _remoteDataSource.hasSeenOnboarding,
    memoriser: _localDataSource.setOnboardingComplete,
  );

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
  Future<Either<Failure, bool>> hasSeenCoachMarks() => _lireDrapeau(
    nom: 'has_seen_coach_marks',
    local: _localDataSource.hasSeenCoachMarks,
    distant: _remoteDataSource.hasSeenCoachMarks,
    memoriser: _localDataSource.setCoachMarksComplete,
  );

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
  Future<Either<Failure, bool>> hasGivenConsent() => _lireDrapeau(
    nom: 'has_given_consent',
    local: _localDataSource.hasGivenConsent,
    distant: _remoteDataSource.hasGivenConsent,
    memoriser: _localDataSource.setConsentGiven,
  );

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
  Future<Either<Failure, bool>> hasCompletedProfileConfig() => _lireDrapeau(
    nom: 'profile_config_complete',
    local: _localDataSource.hasCompletedProfileConfig,
    distant: _remoteDataSource.hasCompletedProfileConfig,
    memoriser: _localDataSource.setProfileConfigComplete,
  );

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
