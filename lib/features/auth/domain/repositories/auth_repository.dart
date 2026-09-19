import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/account_deletion_status.dart';
import '../entities/user_entity.dart';

abstract class AuthRepository {
  Future<Either<Failure, UserEntity>> signInWithEmail({
    required String email,
    required String password,
  });

  Future<Either<Failure, UserEntity>> signInWithGoogle();

  Future<Either<Failure, UserEntity>> signInWithApple();

  Future<Either<Failure, UserEntity>> signUp({
    required String email,
    required String password,
    required String displayName,
  });

  Future<Either<Failure, void>> signOut();

  /// Demande la suppression du compte : désactivation immédiate, suppression
  /// définitive à l'échéance rendue. Ne supprime pas le compte Firebase.
  Future<Either<Failure, DateTime>> requestAccountDeletion();

  Future<Either<Failure, void>> cancelAccountDeletion();

  /// `Right(null)` = aucune suppression en cours. Une session Supabase absente
  /// est un `Left`, jamais un `Right(null)`.
  Future<Either<Failure, AccountDeletionStatus?>> accountDeletionStatus();

  Future<Either<Failure, void>> reauthenticateWithPassword(String password);

  Future<Either<Failure, UserEntity?>> getCurrentUser();

  Stream<UserEntity?> get authStateChanges;

  Future<Either<Failure, void>> sendPasswordResetEmail(String email);
}
