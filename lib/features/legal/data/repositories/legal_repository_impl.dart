import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/connectivity_service.dart';
import '../../domain/entities/legal_entity.dart';
import '../../domain/repositories/legal_repository.dart';
import '../datasources/legal_remote_datasource.dart';
import '../models/legal_content_model.dart';

/// Implémentation du repository pour la gestion des contenus légaux
class LegalRepositoryImpl implements LegalRepository {
  final LegalRemoteDataSource remoteDataSource;
  final ConnectivityService connectivityService;

  LegalRepositoryImpl({
    required this.remoteDataSource,
    required this.connectivityService,
  });

  @override
  Future<Either<Failure, LegalContent>> getTerms() async {
    return getLegalContent(LegalContentType.terms);
  }

  @override
  Future<Either<Failure, LegalContent>> getPrivacyPolicy() async {
    return getLegalContent(LegalContentType.privacy);
  }

  @override
  Future<Either<Failure, LegalContent>> getCodeOfConduct() async {
    return getLegalContent(LegalContentType.conduct);
  }

  @override
  Future<Either<Failure, LegalContent>> getLegalContent(LegalContentType type) async {
    try {
      final LegalContentModel model;

      switch (type) {
        case LegalContentType.terms:
          model = await remoteDataSource.getTerms();
          break;
        case LegalContentType.privacy:
          model = await remoteDataSource.getPrivacyPolicy();
          break;
        case LegalContentType.conduct:
          model = await remoteDataSource.getCodeOfConduct();
          break;
      }

      return Right(_mapModelToEntity(model));
    } on ServerException catch (e) {
      debugPrint('LegalRepository: Server error: $e');
      return Left(ServerFailure(e.message));
    } on CacheException catch (e) {
      debugPrint('LegalRepository: Cache error: $e');
      return Left(CacheFailure(e.message));
    } catch (e) {
      debugPrint('LegalRepository: Unexpected error: $e');
      return const Left(ServerFailure('Erreur lors du chargement du contenu légal'));
    }
  }

  @override
  Future<Either<Failure, List<LegalContent>>> getAllLegalContent() async {
    try {
      final results = await Future.wait([
        remoteDataSource.getTerms(),
        remoteDataSource.getPrivacyPolicy(),
        remoteDataSource.getCodeOfConduct(),
      ]);

      final contents = results.map((model) => _mapModelToEntity(model)).toList();
      return Right(contents);
    } on ServerException catch (e) {
      debugPrint('LegalRepository: Server error: $e');
      return Left(ServerFailure(e.message));
    } catch (e) {
      debugPrint('LegalRepository: Unexpected error: $e');
      return const Left(ServerFailure('Erreur lors du chargement des contenus légaux'));
    }
  }

  @override
  Future<Either<Failure, LegalAcceptance?>> getUserAcceptance(String userId) async {
    try {
      final acceptance = await remoteDataSource.getUserAcceptance(userId);

      if (acceptance == null) {
        return const Right(null);
      }

      return Right(_mapAcceptanceModelToEntity(acceptance));
    } on ServerException catch (e) {
      debugPrint('LegalRepository: Server error: $e');
      return Left(ServerFailure(e.message));
    } catch (e) {
      debugPrint('LegalRepository: Unexpected error: $e');
      return const Left(ServerFailure('Erreur lors de la récupération de l\'acceptation'));
    }
  }

  @override
  Future<Either<Failure, void>> saveUserAcceptance({
    required String userId,
    required LegalAcceptance acceptance,
  }) async {
    try {
      final isConnected = await connectivityService.isConnected();

      if (!isConnected) {
        return const Left(NetworkFailure('Pas de connexion internet'));
      }

      final model = UserLegalAcceptance(
        termsVersion: acceptance.termsVersion,
        privacyVersion: acceptance.privacyVersion,
        acceptedAt: acceptance.acceptedAt,
      );

      await remoteDataSource.saveUserAcceptance(userId, model);
      return const Right(null);
    } on ServerException catch (e) {
      debugPrint('LegalRepository: Server error: $e');
      return Left(ServerFailure(e.message));
    } catch (e) {
      debugPrint('LegalRepository: Unexpected error: $e');
      return const Left(ServerFailure('Erreur lors de la sauvegarde de l\'acceptation'));
    }
  }

  @override
  Future<Either<Failure, LegalAcceptanceStatus>> checkAcceptanceStatus(String userId) async {
    try {
      final acceptance = await remoteDataSource.getUserAcceptance(userId);

      if (acceptance == null) {
        return const Right(LegalAcceptanceStatus.neverAccepted);
      }

      final needsUpdate = await remoteDataSource.needsAcceptance(userId);

      if (needsUpdate) {
        return const Right(LegalAcceptanceStatus.needsUpdate);
      }

      return const Right(LegalAcceptanceStatus.upToDate);
    } on ServerException catch (e) {
      debugPrint('LegalRepository: Server error: $e');
      return Left(ServerFailure(e.message));
    } catch (e) {
      debugPrint('LegalRepository: Unexpected error: $e');
      return const Left(ServerFailure('Erreur lors de la vérification du statut'));
    }
  }

  @override
  Future<Either<Failure, bool>> needsAcceptance(String userId) async {
    try {
      final result = await remoteDataSource.needsAcceptance(userId);
      return Right(result);
    } on ServerException catch (e) {
      debugPrint('LegalRepository: Server error: $e');
      return Left(ServerFailure(e.message));
    } catch (e) {
      debugPrint('LegalRepository: Unexpected error: $e');
      return const Left(ServerFailure('Erreur lors de la vérification'));
    }
  }

  @override
  Future<Either<Failure, List<LegalAcceptance>>> getAcceptanceHistory(String userId) async {
    // Cette fonctionnalité nécessiterait un stockage historique
    // Pour l'instant, retourner juste l'acceptation actuelle si elle existe
    try {
      final acceptance = await remoteDataSource.getUserAcceptance(userId);

      if (acceptance == null) {
        return const Right([]);
      }

      return Right([_mapAcceptanceModelToEntity(acceptance)]);
    } on ServerException catch (e) {
      debugPrint('LegalRepository: Server error: $e');
      return Left(ServerFailure(e.message));
    } catch (e) {
      debugPrint('LegalRepository: Unexpected error: $e');
      return const Left(ServerFailure('Erreur lors de la récupération de l\'historique'));
    }
  }

  /// Convertit un modèle de contenu légal en entité
  LegalContent _mapModelToEntity(LegalContentModel model) {
    return LegalContent(
      id: model.id,
      type: LegalContentTypeX.fromString(model.type),
      title: model.title,
      version: model.version,
      sections: model.sections.map((s) => LegalSection(
        title: s.title,
        content: s.content,
        order: s.order ?? 0,
      )).toList(),
      updatedAt: model.updatedAt,
      summary: model.summary,
    );
  }

  /// Convertit un modèle d'acceptation en entité
  LegalAcceptance _mapAcceptanceModelToEntity(UserLegalAcceptance model) {
    return LegalAcceptance(
      termsVersion: model.termsVersion,
      privacyVersion: model.privacyVersion,
      acceptedAt: model.acceptedAt,
    );
  }
}
