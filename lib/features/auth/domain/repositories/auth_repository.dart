import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/account_deletion_status.dart';
import '../entities/second_facteur.dart';
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

  // --- Second facteur (Firebase Auth multi-facteur, TOTP) -------------------
  //
  // Pourquoi ici et pas dans un service du panneau : un défi naît d'une
  // connexion (`signInWithEmail` rend `Left(SecondFacteurRequisFailure)`) et
  // sa résolution EST la fin de cette connexion — pont Supabase, profil,
  // jeton FCM. Le parcours : `docs/deploiement/MFA_ADMIN.md`.

  /// Les facteurs enrôlés sur le compte courant. Vide = aucun ; `Left` sans
  /// session — jamais un `Right([])` qui ferait passer « pas connecté » pour
  /// « pas enrôlé ».
  Future<Either<Failure, List<FacteurEnrole>>> facteursEnroles();

  /// Génère un secret TOTP pour le compte courant. Exige une connexion
  /// récente (`requires-recent-login` sinon) et TOTP activé sur le projet.
  Future<Either<Failure, SecretTotp>> commencerEnrolementTotp();

  /// Vérifie [code] contre [secret] et enrôle le facteur sous [libelle].
  Future<Either<Failure, void>> terminerEnrolementTotp({
    required SecretTotp secret,
    required String code,
    required String libelle,
  });

  /// Achève une connexion interrompue par [SecondFacteurRequisFailure] :
  /// [code] prouve le facteur TOTP de [defi], puis la session se termine
  /// comme après [signInWithEmail].
  Future<Either<Failure, UserEntity>> resoudreSecondFacteur({
    required DefiSecondFacteur defi,
    required String code,
  });
}
