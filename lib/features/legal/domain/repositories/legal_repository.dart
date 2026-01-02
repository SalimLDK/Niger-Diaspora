import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/legal_entity.dart';

/// Interface du repository pour la gestion des contenus légaux
abstract class LegalRepository {
  /// Récupère les Conditions Générales d'Utilisation
  Future<Either<Failure, LegalContent>> getTerms();

  /// Récupère la Politique de Confidentialité
  Future<Either<Failure, LegalContent>> getPrivacyPolicy();

  /// Récupère le Code de Conduite
  Future<Either<Failure, LegalContent>> getCodeOfConduct();

  /// Récupère un contenu légal par son type
  Future<Either<Failure, LegalContent>> getLegalContent(LegalContentType type);

  /// Récupère tous les contenus légaux
  Future<Either<Failure, List<LegalContent>>> getAllLegalContent();

  /// Récupère l'acceptation de l'utilisateur
  Future<Either<Failure, LegalAcceptance?>> getUserAcceptance(String userId);

  /// Sauvegarde l'acceptation de l'utilisateur
  Future<Either<Failure, void>> saveUserAcceptance({
    required String userId,
    required LegalAcceptance acceptance,
  });

  /// Vérifie si l'utilisateur doit accepter les nouvelles conditions
  Future<Either<Failure, LegalAcceptanceStatus>> checkAcceptanceStatus(String userId);

  /// Vérifie si une mise à jour des conditions est nécessaire
  Future<Either<Failure, bool>> needsAcceptance(String userId);

  /// Récupère l'historique des acceptations de l'utilisateur
  Future<Either<Failure, List<LegalAcceptance>>> getAcceptanceHistory(String userId);
}
