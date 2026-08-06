import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/services/notification_service.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;

  AuthRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, UserEntity>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final userModel = await remoteDataSource.signInWithEmail(
        email: email,
        password: password,
      );

      // Save FCM token
      await NotificationService().saveTokenForUser(userModel.id);

      return Right(userModel.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Erreur inattendue: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> signInWithGoogle() async {
    try {
      final userModel = await remoteDataSource.signInWithGoogle();

      // Save FCM token
      await NotificationService().saveTokenForUser(userModel.id);

      return Right(userModel.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Erreur inattendue: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final userModel = await remoteDataSource.signUp(
        email: email,
        password: password,
        displayName: displayName,
      );

      // Save FCM token
      await NotificationService().saveTokenForUser(userModel.id);

      return Right(userModel.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Erreur inattendue: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> signOut() async {
    try {
      final userModel = await remoteDataSource.getCurrentUser();
      if (userModel != null) {
        await NotificationService().removeTokenForUser(userModel.id);
      }

      await remoteDataSource.signOut();
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Erreur inattendue: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteAccount() async {
    try {
      await remoteDataSource.deleteAccount();
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Erreur inattendue: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> reauthenticateWithPassword(
    String password,
  ) async {
    try {
      await remoteDataSource.reauthenticateWithPassword(password);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Erreur inattendue: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, UserEntity?>> getCurrentUser() async {
    try {
      final userModel = await remoteDataSource.getCurrentUser();
      return Right(userModel?.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Erreur inattendue: ${e.toString()}'));
    }
  }

  @override
  Stream<UserEntity?> get authStateChanges {
    return remoteDataSource.authStateChanges.map((userModel) {
      final entity = userModel?.toEntity();
      // Le jeton FCM n'était enregistré qu'à la connexion **explicite**
      // (connexion, inscription, SSO). Au démarrage avec une session déjà
      // ouverte — le cas courant — rien ne l'appelait : `_lastKnownUserId`
      // restait nul, donc un `onTokenRefresh` était rejeté en silence et la
      // base gardait un jeton périmé jusqu'à la prochaine déconnexion.
      // `saveTokenForUser` est idempotente par process, ce flux peut donc
      // émettre autant qu'il veut.
      if (entity != null) {
        NotificationService().saveTokenForUser(entity.id);
      }
      return entity;
    });
  }

  @override
  Future<Either<Failure, void>> sendPasswordResetEmail(String email) async {
    try {
      await remoteDataSource.sendPasswordResetEmail(email);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Erreur inattendue: ${e.toString()}'));
    }
  }
}
