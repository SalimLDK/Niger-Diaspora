import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/report_entity.dart';

abstract class ReportRepository {
  /// Soumettre un nouveau signalement
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
  });

  /// Notifier l'utilisateur signalé après résolution
  Future<Either<Failure, void>> notifyReportedUser({
    required String reportId,
    required String reportedUserId,
    required String resolution,
    required bool contentRemoved,
  });

  /// Stream des signalements de l'utilisateur courant
  Stream<Either<Failure, List<ReportEntity>>> getMyReports(String userId);

  /// Récupérer un signalement par ID
  Future<Either<Failure, ReportEntity?>> getReportById(String reportId);

  /// Vérifier si l'utilisateur a déjà signalé ce contenu
  Future<Either<Failure, bool>> hasAlreadyReported({
    required String reporterId,
    required ReportTargetType targetType,
    required String targetId,
  });

  // ============ Admin Methods ============

  /// Stream de tous les signalements (admin)
  Stream<Either<Failure, List<ReportEntity>>> getAllReports({
    ReportStatus? status,
    ReportTargetType? targetType,
    int limit = 100,
  });

  /// Récupérer les signalements en attente (admin)
  Future<Either<Failure, List<ReportEntity>>> getPendingReports({
    int limit = 50,
  });

  /// Récupérer le nombre de signalements en attente (admin)
  Future<Either<Failure, int>> getPendingReportsCount();

  /// Mettre à jour le statut d'un signalement (admin)
  Future<Either<Failure, void>> updateReportStatus({
    required String reportId,
    required ReportStatus status,
    required String reviewedBy,
    required String reviewerName,
    String? adminNote,
    String? resolution,
  });

  /// Résoudre un signalement (admin)
  Future<Either<Failure, void>> resolveReport({
    required String reportId,
    required String reviewedBy,
    required String reviewerName,
    required String resolution,
    String? adminNote,
  });

  /// Rejeter un signalement (admin)
  Future<Either<Failure, void>> dismissReport({
    required String reportId,
    required String reviewedBy,
    required String reviewerName,
    required String reason,
  });

  /// Supprimer le contenu signalé et résoudre le signalement (admin)
  Future<Either<Failure, void>> deleteReportedContent({
    required String reportId,
    required ReportTargetType targetType,
    required String targetId,
    required String reviewedBy,
    required String reviewerName,
    String? conversationId,
  });

  /// Récupérer les statistiques des signalements (admin)
  Future<Either<Failure, ReportStatistics>> getReportStatistics();
}

/// Statistiques des signalements
class ReportStatistics {
  final int totalReports;
  final int pendingReports;
  final int resolvedReports;
  final int dismissedReports;
  final Map<ReportTargetType, int> byTargetType;
  final Map<ReportReason, int> byReason;

  const ReportStatistics({
    required this.totalReports,
    required this.pendingReports,
    required this.resolvedReports,
    required this.dismissedReports,
    required this.byTargetType,
    required this.byReason,
  });

  factory ReportStatistics.empty() => const ReportStatistics(
        totalReports: 0,
        pendingReports: 0,
        resolvedReports: 0,
        dismissedReports: 0,
        byTargetType: {},
        byReason: {},
      );
}
