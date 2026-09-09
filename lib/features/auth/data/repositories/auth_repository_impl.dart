import 'dart:async';
import 'dart:developer' as dev;
import 'package:diaspo_niger/core/errors/app_error_messages.dart';
import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/supabase_auth_bridge.dart';
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
      await NotificationService().saveTokenForUser(
        userModel.id,
        displayName: userModel.displayName,
        photoUrl: userModel.photoUrl,
      );

      return Right(userModel.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      dev.log('Erreur inattendue', name: 'auth_repository_impl', error: e);
      return Left(ServerFailure(AppErrorMessages.unexpectedError));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> signInWithGoogle() async {
    try {
      final userModel = await remoteDataSource.signInWithGoogle();

      // Save FCM token
      await NotificationService().saveTokenForUser(
        userModel.id,
        displayName: userModel.displayName,
        photoUrl: userModel.photoUrl,
      );

      return Right(userModel.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      dev.log('Erreur inattendue', name: 'auth_repository_impl', error: e);
      return Left(ServerFailure(AppErrorMessages.unexpectedError));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> signInWithApple() async {
    try {
      final userModel = await remoteDataSource.signInWithApple();

      await NotificationService().saveTokenForUser(
        userModel.id,
        displayName: userModel.displayName,
        photoUrl: userModel.photoUrl,
      );

      return Right(userModel.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      dev.log('Erreur inattendue', name: 'auth_repository_impl', error: e);
      return Left(ServerFailure(AppErrorMessages.unexpectedError));
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
      await NotificationService().saveTokenForUser(
        userModel.id,
        displayName: userModel.displayName,
        photoUrl: userModel.photoUrl,
      );

      return Right(userModel.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      dev.log('Erreur inattendue', name: 'auth_repository_impl', error: e);
      return Left(ServerFailure(AppErrorMessages.unexpectedError));
    }
  }

  /// Rend la main des que la personne est reellement deconnectee, c'est-a-dire
  /// des que le jeton Firebase a quitte le stockage de l'appareil.
  ///
  /// Tout ce qui reste — retrait du jeton FCM en base, revocation de la session
  /// Supabase, oubli du compte Google — est du menage : necessaire, mais rien
  /// n'oblige a le regarder se faire. Il etait attendu ici, en serie, sans
  /// aucun retour visuel : appuyer sur « Deconnexion » laissait l'ecran fige
  /// plusieurs secondes, le temps de sept allers-retours reseau.
  @override
  Future<Either<Failure, void>> signOut() async {
    // Lu localement. `getCurrentUser()` repondait a la meme question au prix de
    // trois allers-retours Supabase (echange du jeton Firebase, upsert du
    // compte, lecture du profil) — pour un uid deja en memoire.
    final userId = remoteDataSource.currentUserId;

    // Le retrait du jeton FCM ecrit dans `users` : il lui faut une session
    // Supabase valide, et la re-minter exige le jeton Firebase que la ligne
    // suivante efface. Elle l'est presque toujours (le pont la renouvelle 5 min
    // avant expiration) et alors on n'attend rien. Sinon on la retablit ici,
    // borne, plutot que de laisser le jeton en base et l'appareil sonner pour
    // le compte precedent.
    //
    // `ensureReadableSession` et non `ensureAuthenticated` : sa docstring vise
    // les lectures, mais c'est sa semantique qu'il faut ici — borner, ne
    // jamais lever, degrader plutot que geler. Se deconnecter ne doit echouer
    // pour aucune raison exterieure au jeton Firebase. Le `try` couvre le
    // reste : la methode traverse `Supabase.instance`, qui leve tant que le
    // SDK n'est pas initialise.
    if (userId != null) {
      try {
        await SupabaseAuthBridge.instance.ensureReadableSession();
      } catch (e) {
        dev.log(
          'Session Supabase non retablie avant deconnexion',
          name: 'auth_repository_impl',
          error: e,
        );
      }
    }

    try {
      await remoteDataSource.signOut();
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      dev.log('Erreur inattendue', name: 'auth_repository_impl', error: e);
      return Left(ServerFailure(AppErrorMessages.unexpectedError));
    }

    unawaited(_menageApresDeconnexion(userId));
    return const Right(null);
  }

  /// Menage distant, best-effort, hors du chemin critique.
  ///
  /// L'ordre compte : la revocation coupe la session Supabase dont le retrait
  /// du jeton FCM a besoin, elle ne vient donc qu'apres lui.
  Future<void> _menageApresDeconnexion(String? userId) async {
    if (userId != null) {
      try {
        await NotificationService().removeTokenForUser(userId).timeout(
          const Duration(seconds: 20),
        );
      } catch (e) {
        dev.log(
          'Retrait du jeton FCM apres deconnexion',
          name: 'auth_repository_impl',
          error: e,
        );
      }
    }
    await remoteDataSource.revokeRemoteSessions();
  }

  @override
  Future<Either<Failure, void>> deleteAccount() async {
    try {
      await remoteDataSource.deleteAccount();
      return const Right(null);
    } on AuthException catch (e) {
      // Porte le code (`requires-recent-login`) jusqu a la presentation.
      return Left(AuthFailure(e.message, code: e.code));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      dev.log('Erreur inattendue', name: 'auth_repository_impl', error: e);
      return Left(ServerFailure(AppErrorMessages.unexpectedError));
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
      dev.log('Erreur inattendue', name: 'auth_repository_impl', error: e);
      return Left(ServerFailure(AppErrorMessages.unexpectedError));
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
      dev.log('Erreur inattendue', name: 'auth_repository_impl', error: e);
      return Left(ServerFailure(AppErrorMessages.unexpectedError));
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
        NotificationService().saveTokenForUser(
          entity.id,
          displayName: entity.displayName,
          photoUrl: entity.photoUrl,
        );
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
      dev.log('Erreur inattendue', name: 'auth_repository_impl', error: e);
      return Left(ServerFailure(AppErrorMessages.unexpectedError));
    }
  }
}
