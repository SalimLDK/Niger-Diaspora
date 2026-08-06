import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/report_remote_datasource.dart';
import '../../data/repositories/report_repository_impl.dart';
import '../../domain/entities/report_entity.dart';
import '../../domain/repositories/report_repository.dart';

part 'report_provider.g.dart';

// ============ Data Layer Providers ============

@riverpod
ReportRemoteDataSource reportRemoteDataSource(Ref ref) {
  return ReportRemoteDataSourceImpl();
}

@riverpod
ReportRepository reportRepository(Ref ref) {
  return ReportRepositoryImpl(
    remoteDataSource: ref.watch(reportRemoteDataSourceProvider),
  );
}

// ============ User Reports Stream ============

@Riverpod(keepAlive: true)
Stream<List<ReportEntity>> myReports(Ref ref) {
  final currentUser = ref.watch(currentUserAsyncProvider).valueOrNull;
  if (currentUser == null) {
    return Stream.value([]);
  }

  final repository = ref.watch(reportRepositoryProvider);
  return repository
      .getMyReports(currentUser.id)
      .map((either) => either.fold((_) => [], (reports) => reports));
}

// ============ Admin Reports Stream ============

@Riverpod(keepAlive: true)
Stream<List<ReportEntity>> allReports(Ref ref) {
  final repository = ref.watch(reportRepositoryProvider);
  return repository.getAllReports().map(
        (either) => either.fold((_) => [], (reports) => reports),
      );
}

@Riverpod(keepAlive: true)
Stream<List<ReportEntity>> pendingReportsStream(Ref ref) {
  final repository = ref.watch(reportRepositoryProvider);
  return repository
      .getAllReports(status: ReportStatus.pending)
      .map((either) => either.fold((_) => [], (reports) => reports));
}

// ============ Submit Report Notifier ============

@riverpod
class SubmitReportNotifier extends _$SubmitReportNotifier {
  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }

  Future<bool> submitReport({
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
    final currentUser = await ref.read(currentUserAsyncProvider.future);
    if (currentUser == null) {
      state = AsyncValue.error(
        'Utilisateur non authentifié',
        StackTrace.current,
      );
      return false;
    }

    state = const AsyncValue.loading();

    final repository = ref.read(reportRepositoryProvider);
    final result = await repository.submitReport(
      reporterId: currentUser.id,
      reporterName: currentUser.displayName ?? 'Utilisateur',
      reporterPhotoUrl: currentUser.photoUrl,
      targetType: targetType,
      targetId: targetId,
      targetName: targetName,
      targetPreview: targetPreview,
      conversationId: conversationId,
      reason: reason,
      description: description,
      contentSnapshot: contentSnapshot,
      reportedUserId: reportedUserId,
    );

    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        // Refresh my reports stream
        ref.invalidate(myReportsProvider);
        return true;
      },
    );
  }

  Future<bool> hasAlreadyReported({
    required ReportTargetType targetType,
    required String targetId,
  }) async {
    final currentUser = await ref.read(currentUserAsyncProvider.future);
    if (currentUser == null) return false;

    final repository = ref.read(reportRepositoryProvider);
    final result = await repository.hasAlreadyReported(
      reporterId: currentUser.id,
      targetType: targetType,
      targetId: targetId,
    );

    return result.fold((_) => false, (hasReported) => hasReported);
  }
}

// ============ Admin Report Management Notifier ============

@riverpod
class AdminReportNotifier extends _$AdminReportNotifier {
  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }

  Future<bool> resolveReport({
    required String reportId,
    required String resolution,
    String? adminNote,
    String? reportedUserId,
    bool notifyUser = true,
  }) async {
    final currentUser = await ref.read(currentUserAsyncProvider.future);
    if (currentUser == null) {
      state = AsyncValue.error(
        'Utilisateur non authentifié',
        StackTrace.current,
      );
      return false;
    }

    state = const AsyncValue.loading();

    final repository = ref.read(reportRepositoryProvider);
    final result = await repository.resolveReport(
      reportId: reportId,
      reviewedBy: currentUser.id,
      reviewerName: currentUser.displayName ?? 'Admin',
      resolution: resolution,
      adminNote: adminNote,
    );

    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (_) async {
        // Notifier l'utilisateur signalé si demandé
        if (notifyUser && reportedUserId != null) {
          await repository.notifyReportedUser(
            reportId: reportId,
            reportedUserId: reportedUserId,
            resolution: resolution,
            contentRemoved: false,
          );
        }
        state = const AsyncValue.data(null);
        ref.invalidate(allReportsProvider);
        ref.invalidate(pendingReportsStreamProvider);
        return true;
      },
    );
  }

  Future<bool> dismissReport({
    required String reportId,
    required String reason,
  }) async {
    final currentUser = await ref.read(currentUserAsyncProvider.future);
    if (currentUser == null) {
      state = AsyncValue.error(
        'Utilisateur non authentifié',
        StackTrace.current,
      );
      return false;
    }

    state = const AsyncValue.loading();

    final repository = ref.read(reportRepositoryProvider);
    final result = await repository.dismissReport(
      reportId: reportId,
      reviewedBy: currentUser.id,
      reviewerName: currentUser.displayName ?? 'Admin',
      reason: reason,
    );

    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        ref.invalidate(allReportsProvider);
        ref.invalidate(pendingReportsStreamProvider);
        return true;
      },
    );
  }

  Future<bool> deleteReportedContent({
    required String reportId,
    required ReportTargetType targetType,
    required String targetId,
    String? conversationId,
    String? reportedUserId,
    bool notifyUser = true,
  }) async {
    final currentUser = await ref.read(currentUserAsyncProvider.future);
    if (currentUser == null) {
      state = AsyncValue.error(
        'Utilisateur non authentifié',
        StackTrace.current,
      );
      return false;
    }

    state = const AsyncValue.loading();

    final repository = ref.read(reportRepositoryProvider);
    final result = await repository.deleteReportedContent(
      reportId: reportId,
      targetType: targetType,
      targetId: targetId,
      reviewedBy: currentUser.id,
      reviewerName: currentUser.displayName ?? 'Admin',
      conversationId: conversationId,
    );

    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (_) async {
        // Notifier l'utilisateur signalé que son contenu a été supprimé
        if (notifyUser && reportedUserId != null) {
          await repository.notifyReportedUser(
            reportId: reportId,
            reportedUserId: reportedUserId,
            resolution: 'Contenu supprimé pour violation des règles',
            contentRemoved: true,
          );
        }
        state = const AsyncValue.data(null);
        ref.invalidate(allReportsProvider);
        ref.invalidate(pendingReportsStreamProvider);
        return true;
      },
    );
  }

  Future<ReportStatistics> getStatistics() async {
    final repository = ref.read(reportRepositoryProvider);
    final result = await repository.getReportStatistics();
    return result.fold(
      (_) => ReportStatistics.empty(),
      (stats) => stats,
    );
  }
}

// ============ Report Statistics Provider ============

@riverpod
Future<ReportStatistics> reportStatistics(Ref ref) async {
  final repository = ref.watch(reportRepositoryProvider);
  final result = await repository.getReportStatistics();
  return result.fold(
    (_) => ReportStatistics.empty(),
    (stats) => stats,
  );
}

// ============ Pending Reports Count Provider ============

@riverpod
Future<int> pendingReportsCount(Ref ref) async {
  final repository = ref.watch(reportRepositoryProvider);
  final result = await repository.getPendingReportsCount();
  return result.fold((_) => 0, (count) => count);
}
