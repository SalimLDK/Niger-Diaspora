import 'dart:developer' as dev;
import 'package:diaspo_niger/core/errors/app_error_messages.dart';
import 'package:dartz/dartz.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/report_entity.dart';
import '../../domain/repositories/report_repository.dart';
import '../datasources/report_remote_datasource.dart';
import '../models/report_model.dart';

class ReportRepositoryImpl implements ReportRepository {
  final ReportRemoteDataSource remoteDataSource;

  ReportRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, ReportEntity>> submitReport({
    required String reporterId,
    required String reporterName,
    String? reporterPhotoUrl,
    required ReportTargetType targetType,
    required String targetId,
    String? targetName,
    String? targetPreview,
    String? conversationId,
    required ReportReason reason,
    String? description,
    ContentSnapshot? contentSnapshot,
    String? reportedUserId,
  }) async {
    try {
      final report = await remoteDataSource.submitReport(
        reporterId: reporterId,
        reporterName: reporterName,
        reporterPhotoUrl: reporterPhotoUrl,
        targetType: targetType,
        targetId: targetId,
        targetName: targetName,
        targetPreview: targetPreview,
        conversationId: conversationId,
        reason: reason,
        description: description,
        contentSnapshot: contentSnapshot != null
            ? ContentSnapshotModel.fromEntity(contentSnapshot)
            : null,
        reportedUserId: reportedUserId,
      );
      return Right(report.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      dev.log('Erreur inattendue', name: 'report_repository_impl', error: e);
      return Left(ServerFailure(AppErrorMessages.unexpectedError));
    }
  }

  @override
  Future<Either<Failure, void>> notifyReportedUser({
    required String reportId,
    required String reportedUserId,
    required String resolution,
    required bool contentRemoved,
  }) async {
    try {
      await remoteDataSource.notifyReportedUser(
        reportId: reportId,
        reportedUserId: reportedUserId,
        resolution: resolution,
        contentRemoved: contentRemoved,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      dev.log('Erreur inattendue', name: 'report_repository_impl', error: e);
      return Left(ServerFailure(AppErrorMessages.unexpectedError));
    }
  }

  @override
  Stream<Either<Failure, List<ReportEntity>>> getMyReports(String userId) {
    return remoteDataSource.getMyReports(userId).map((reports) {
      return Right<Failure, List<ReportEntity>>(
        reports.map((r) => r.toEntity()).toList(),
      );
    }).handleError((error) {
      return Left<Failure, List<ReportEntity>>(
        ServerFailure(error.toString()),
      );
    });
  }

  @override
  Future<Either<Failure, ReportEntity?>> getReportById(String reportId) async {
    try {
      final report = await remoteDataSource.getReportById(reportId);
      return Right(report?.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      dev.log('Erreur inattendue', name: 'report_repository_impl', error: e);
      return Left(ServerFailure(AppErrorMessages.unexpectedError));
    }
  }

  @override
  Future<Either<Failure, bool>> hasAlreadyReported({
    required String reporterId,
    required ReportTargetType targetType,
    required String targetId,
  }) async {
    try {
      final hasReported = await remoteDataSource.hasAlreadyReported(
        reporterId: reporterId,
        targetType: targetType,
        targetId: targetId,
      );
      return Right(hasReported);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      dev.log('Erreur inattendue', name: 'report_repository_impl', error: e);
      return Left(ServerFailure(AppErrorMessages.unexpectedError));
    }
  }

  @override
  Stream<Either<Failure, List<ReportEntity>>> getAllReports({
    ReportStatus? status,
    ReportTargetType? targetType,
    int limit = 100,
  }) {
    return remoteDataSource
        .getAllReports(status: status, targetType: targetType, limit: limit)
        .map((reports) {
      return Right<Failure, List<ReportEntity>>(
        reports.map((r) => r.toEntity()).toList(),
      );
    }).handleError((error) {
      return Left<Failure, List<ReportEntity>>(
        ServerFailure(error.toString()),
      );
    });
  }

  @override
  Future<Either<Failure, List<ReportEntity>>> getPendingReports({
    int limit = 50,
  }) async {
    try {
      final reports = await remoteDataSource.getPendingReports(limit: limit);
      return Right(reports.map((r) => r.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      dev.log('Erreur inattendue', name: 'report_repository_impl', error: e);
      return Left(ServerFailure(AppErrorMessages.unexpectedError));
    }
  }

  @override
  Future<Either<Failure, int>> getPendingReportsCount() async {
    try {
      final count = await remoteDataSource.getPendingReportsCount();
      return Right(count);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      dev.log('Erreur inattendue', name: 'report_repository_impl', error: e);
      return Left(ServerFailure(AppErrorMessages.unexpectedError));
    }
  }

  @override
  Future<Either<Failure, void>> updateReportStatus({
    required String reportId,
    required ReportStatus status,
    required String reviewedBy,
    required String reviewerName,
    String? adminNote,
    String? resolution,
  }) async {
    try {
      await remoteDataSource.updateReportStatus(
        reportId: reportId,
        status: status,
        reviewedBy: reviewedBy,
        reviewerName: reviewerName,
        adminNote: adminNote,
        resolution: resolution,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      dev.log('Erreur inattendue', name: 'report_repository_impl', error: e);
      return Left(ServerFailure(AppErrorMessages.unexpectedError));
    }
  }

  @override
  Future<Either<Failure, void>> resolveReport({
    required String reportId,
    required String reviewedBy,
    required String reviewerName,
    required String resolution,
    String? adminNote,
  }) async {
    return updateReportStatus(
      reportId: reportId,
      status: ReportStatus.resolved,
      reviewedBy: reviewedBy,
      reviewerName: reviewerName,
      resolution: resolution,
      adminNote: adminNote,
    );
  }

  @override
  Future<Either<Failure, void>> dismissReport({
    required String reportId,
    required String reviewedBy,
    required String reviewerName,
    required String reason,
  }) async {
    return updateReportStatus(
      reportId: reportId,
      status: ReportStatus.dismissed,
      reviewedBy: reviewedBy,
      reviewerName: reviewerName,
      resolution: reason,
    );
  }

  @override
  Future<Either<Failure, void>> deleteReportedContent({
    required String reportId,
    required ReportTargetType targetType,
    required String targetId,
    required String reviewedBy,
    required String reviewerName,
    String? conversationId,
  }) async {
    try {
      // Supprimer le contenu
      await remoteDataSource.deleteReportedContent(
        targetType: targetType,
        targetId: targetId,
        conversationId: conversationId,
      );

      // Marquer le signalement comme résolu
      await remoteDataSource.updateReportStatus(
        reportId: reportId,
        status: ReportStatus.resolved,
        reviewedBy: reviewedBy,
        reviewerName: reviewerName,
        resolution: 'Contenu supprimé',
      );

      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      dev.log('Erreur inattendue', name: 'report_repository_impl', error: e);
      return Left(ServerFailure(AppErrorMessages.unexpectedError));
    }
  }

  @override
  Future<Either<Failure, ReportStatistics>> getReportStatistics() async {
    try {
      final stats = await remoteDataSource.getReportStatistics();
      return Right(stats);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      dev.log('Erreur inattendue', name: 'report_repository_impl', error: e);
      return Left(ServerFailure(AppErrorMessages.unexpectedError));
    }
  }
}
