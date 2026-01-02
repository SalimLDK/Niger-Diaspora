import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/legal_entity.dart';
import '../repositories/legal_repository.dart';

/// Use case pour récupérer les CGU
class GetTerms {
  final LegalRepository repository;

  GetTerms(this.repository);

  Future<Either<Failure, LegalContent>> call() {
    return repository.getTerms();
  }
}

/// Use case pour récupérer la politique de confidentialité
class GetPrivacyPolicy {
  final LegalRepository repository;

  GetPrivacyPolicy(this.repository);

  Future<Either<Failure, LegalContent>> call() {
    return repository.getPrivacyPolicy();
  }
}

/// Use case pour récupérer le code de conduite
class GetCodeOfConduct {
  final LegalRepository repository;

  GetCodeOfConduct(this.repository);

  Future<Either<Failure, LegalContent>> call() {
    return repository.getCodeOfConduct();
  }
}

/// Use case pour récupérer un contenu légal par type
class GetLegalContent {
  final LegalRepository repository;

  GetLegalContent(this.repository);

  Future<Either<Failure, LegalContent>> call(LegalContentType type) {
    return repository.getLegalContent(type);
  }
}

/// Use case pour récupérer tous les contenus légaux
class GetAllLegalContent {
  final LegalRepository repository;

  GetAllLegalContent(this.repository);

  Future<Either<Failure, List<LegalContent>>> call() {
    return repository.getAllLegalContent();
  }
}

/// Use case pour vérifier le statut d'acceptation
class CheckAcceptanceStatus {
  final LegalRepository repository;

  CheckAcceptanceStatus(this.repository);

  Future<Either<Failure, LegalAcceptanceStatus>> call(String userId) {
    return repository.checkAcceptanceStatus(userId);
  }
}

/// Use case pour vérifier si l'utilisateur doit accepter les conditions
class NeedsAcceptance {
  final LegalRepository repository;

  NeedsAcceptance(this.repository);

  Future<Either<Failure, bool>> call(String userId) {
    return repository.needsAcceptance(userId);
  }
}

/// Use case pour accepter les conditions légales
class AcceptLegalTerms {
  final LegalRepository repository;

  AcceptLegalTerms(this.repository);

  Future<Either<Failure, void>> call({
    required String userId,
    required String termsVersion,
    required String privacyVersion,
    String? conductVersion,
  }) {
    final acceptance = LegalAcceptance(
      termsVersion: termsVersion,
      privacyVersion: privacyVersion,
      acceptedAt: DateTime.now(),
      conductVersion: conductVersion,
    );

    return repository.saveUserAcceptance(
      userId: userId,
      acceptance: acceptance,
    );
  }
}

/// Use case pour récupérer l'acceptation actuelle de l'utilisateur
class GetUserAcceptance {
  final LegalRepository repository;

  GetUserAcceptance(this.repository);

  Future<Either<Failure, LegalAcceptance?>> call(String userId) {
    return repository.getUserAcceptance(userId);
  }
}

/// Use case pour récupérer l'historique des acceptations
class GetAcceptanceHistory {
  final LegalRepository repository;

  GetAcceptanceHistory(this.repository);

  Future<Either<Failure, List<LegalAcceptance>>> call(String userId) {
    return repository.getAcceptanceHistory(userId);
  }
}

/// Use case combiné pour gérer tout le flux d'acceptation légale
class ManageLegalAcceptance {
  final LegalRepository repository;

  ManageLegalAcceptance(this.repository);

  /// Vérifie si l'utilisateur doit accepter les conditions
  Future<Either<Failure, bool>> needsAcceptance(String userId) {
    return repository.needsAcceptance(userId);
  }

  /// Récupère le statut d'acceptation détaillé
  Future<Either<Failure, LegalAcceptanceStatus>> getStatus(String userId) {
    return repository.checkAcceptanceStatus(userId);
  }

  /// Accepte toutes les conditions actuelles
  Future<Either<Failure, void>> acceptAll({
    required String userId,
  }) async {
    // Récupérer les versions actuelles
    final termsResult = await repository.getTerms();
    final privacyResult = await repository.getPrivacyPolicy();

    return termsResult.fold(
      (failure) => Left(failure),
      (terms) => privacyResult.fold(
        (failure) => Left(failure),
        (privacy) async {
          final acceptance = LegalAcceptance(
            termsVersion: terms.version,
            privacyVersion: privacy.version,
            acceptedAt: DateTime.now(),
          );

          return repository.saveUserAcceptance(
            userId: userId,
            acceptance: acceptance,
          );
        },
      ),
    );
  }
}
