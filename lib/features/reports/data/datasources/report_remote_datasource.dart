import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/firebase_collections.dart';
import '../../../../core/errors/exceptions.dart';
import '../../domain/entities/report_entity.dart';
import '../../domain/repositories/report_repository.dart';
import '../models/report_model.dart';

abstract class ReportRemoteDataSource {
  /// Soumettre un nouveau signalement
  Future<ReportModel> submitReport({
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
    ContentSnapshotModel? contentSnapshot,
    String? reportedUserId,
  });

  /// Notifier l'utilisateur signalé après résolution
  Future<void> notifyReportedUser({
    required String reportId,
    required String reportedUserId,
    required String resolution,
    required bool contentRemoved,
  });

  /// Stream des signalements de l'utilisateur
  Stream<List<ReportModel>> getMyReports(String userId);

  /// Récupérer un signalement par ID
  Future<ReportModel?> getReportById(String reportId);

  /// Vérifier si l'utilisateur a déjà signalé ce contenu
  Future<bool> hasAlreadyReported({
    required String reporterId,
    required ReportTargetType targetType,
    required String targetId,
  });

  // ============ Admin Methods ============

  /// Stream de tous les signalements (admin)
  Stream<List<ReportModel>> getAllReports({
    ReportStatus? status,
    ReportTargetType? targetType,
    int limit = 100,
  });

  /// Récupérer les signalements en attente (admin)
  Future<List<ReportModel>> getPendingReports({int limit = 50});

  /// Récupérer le nombre de signalements en attente
  Future<int> getPendingReportsCount();

  /// Mettre à jour le statut d'un signalement
  Future<void> updateReportStatus({
    required String reportId,
    required ReportStatus status,
    required String reviewedBy,
    required String reviewerName,
    String? adminNote,
    String? resolution,
  });

  /// Supprimer le contenu signalé
  Future<void> deleteReportedContent({
    required ReportTargetType targetType,
    required String targetId,
    String? conversationId,
  });

  /// Récupérer les statistiques des signalements
  Future<ReportStatistics> getReportStatistics();
}

class ReportRemoteDataSourceImpl implements ReportRemoteDataSource {
  final FirebaseFirestore _firestore;

  ReportRemoteDataSourceImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _reportsCollection =>
      _firestore.collection(FirebaseCollections.reports);

  @override
  Future<ReportModel> submitReport({
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
    ContentSnapshotModel? contentSnapshot,
    String? reportedUserId,
  }) async {
    try {
      // Vérifier si déjà signalé
      final alreadyReported = await hasAlreadyReported(
        reporterId: reporterId,
        targetType: targetType,
        targetId: targetId,
      );

      if (alreadyReported) {
        throw ServerException('Vous avez déjà signalé ce contenu');
      }

      final data = <String, dynamic>{
        'reporterId': reporterId,
        'reporterName': reporterName,
        'reporterPhotoUrl': reporterPhotoUrl,
        'targetType': targetType.name,
        'targetId': targetId,
        'targetName': targetName,
        'targetPreview': targetPreview,
        'conversationId': conversationId,
        'reason': reason.name,
        'description': description,
        'status': ReportStatus.pending.name,
        'createdAt': FieldValue.serverTimestamp(),
        'reportedUserNotified': false,
      };

      // Ajouter le snapshot si disponible
      if (contentSnapshot != null) {
        data['contentSnapshot'] = contentSnapshot.toMap();
      }

      // Ajouter l'ID de l'utilisateur signalé
      if (reportedUserId != null) {
        data['reportedUserId'] = reportedUserId;
      }

      final docRef = await _reportsCollection.add(data);

      final doc = await docRef.get();
      return ReportModel.fromFirestore(doc);
    } on FirebaseException catch (e) {
      throw ServerException(
        e.message ?? 'Erreur lors de la soumission du signalement',
      );
    }
  }

  @override
  Future<void> notifyReportedUser({
    required String reportId,
    required String reportedUserId,
    required String resolution,
    required bool contentRemoved,
  }) async {
    try {
      // Créer une notification pour l'utilisateur signalé.
      //
      // Écrite dans Supabase, pas dans Firestore : c'est Supabase que lit
      // l'écran des notifications. Ce `.add()` déposait la notification dans
      // une collection que plus personne n'affiche — l'utilisateur signalé
      // n'apprenait donc jamais que son signalement avait été traité.
      //
      // La RPC est `SECURITY DEFINER` : elle autorise l'écriture d'une
      // notification destinée à quelqu'un d'autre, que la RLS refuserait.
      await Supabase.instance.client.rpc(
        'create_user_notification',
        params: {
          'p_user_id': reportedUserId,
          'p_type': 'report_resolved',
          'p_title': contentRemoved ? 'Contenu supprimé' : 'Signalement traité',
          'p_body': contentRemoved
              ? 'Un contenu que vous avez publié a été signalé et supprimé pour violation de nos règles communautaires.'
              : 'Un signalement concernant votre contenu a été examiné. Aucune action n\'a été prise.',
          'p_data': {
            'reportId': reportId,
            'resolution': resolution,
            'contentRemoved': contentRemoved,
          },
        },
      );

      // Marquer le report comme notifié
      await _reportsCollection.doc(reportId).update({
        'reportedUserNotified': true,
      });
    } on FirebaseException catch (e) {
      throw ServerException(
        e.message ?? 'Erreur lors de la notification',
      );
    }
  }

  @override
  Stream<List<ReportModel>> getMyReports(String userId) {
    return _reportsCollection
        .where('reporterId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ReportModel.fromFirestore(doc))
          .toList();
    });
  }

  @override
  Future<ReportModel?> getReportById(String reportId) async {
    try {
      final doc = await _reportsCollection.doc(reportId).get();
      if (!doc.exists) return null;
      return ReportModel.fromFirestore(doc);
    } on FirebaseException catch (e) {
      throw ServerException(
        e.message ?? 'Erreur lors de la récupération du signalement',
      );
    }
  }

  @override
  Future<bool> hasAlreadyReported({
    required String reporterId,
    required ReportTargetType targetType,
    required String targetId,
  }) async {
    try {
      final query = await _reportsCollection
          .where('reporterId', isEqualTo: reporterId)
          .where('targetType', isEqualTo: targetType.name)
          .where('targetId', isEqualTo: targetId)
          .limit(1)
          .get();

      return query.docs.isNotEmpty;
    } on FirebaseException {
      return false;
    }
  }

  @override
  Stream<List<ReportModel>> getAllReports({
    ReportStatus? status,
    ReportTargetType? targetType,
    int limit = 100,
  }) {
    Query<Map<String, dynamic>> query = _reportsCollection;

    if (status != null) {
      query = query.where('status', isEqualTo: status.name);
    }

    if (targetType != null) {
      query = query.where('targetType', isEqualTo: targetType.name);
    }

    query = query.orderBy('createdAt', descending: true).limit(limit);

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => ReportModel.fromFirestore(doc))
          .toList();
    });
  }

  @override
  Future<List<ReportModel>> getPendingReports({int limit = 50}) async {
    try {
      final snapshot = await _reportsCollection
          .where('status', isEqualTo: ReportStatus.pending.name)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => ReportModel.fromFirestore(doc))
          .toList();
    } on FirebaseException catch (e) {
      throw ServerException(
        e.message ?? 'Erreur lors de la récupération des signalements',
      );
    }
  }

  @override
  Future<int> getPendingReportsCount() async {
    try {
      final snapshot = await _reportsCollection
          .where('status', isEqualTo: ReportStatus.pending.name)
          .count()
          .get();

      return snapshot.count ?? 0;
    } on FirebaseException {
      return 0;
    }
  }

  @override
  Future<void> updateReportStatus({
    required String reportId,
    required ReportStatus status,
    required String reviewedBy,
    required String reviewerName,
    String? adminNote,
    String? resolution,
  }) async {
    try {
      await _reportsCollection.doc(reportId).update({
        'status': status.name,
        'reviewedBy': reviewedBy,
        'reviewerName': reviewerName,
        'adminNote': adminNote,
        'resolution': resolution,
        'reviewedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw ServerException(
        e.message ?? 'Erreur lors de la mise à jour du signalement',
      );
    }
  }

  @override
  Future<void> deleteReportedContent({
    required ReportTargetType targetType,
    required String targetId,
    String? conversationId,
  }) async {
    try {
      switch (targetType) {
        case ReportTargetType.user:
          // Marquer l'utilisateur comme banni ou désactivé
          await _firestore
              .collection(FirebaseCollections.users)
              .doc(targetId)
              .update({
            'isBanned': true,
            'bannedAt': FieldValue.serverTimestamp(),
          });
          break;

        case ReportTargetType.message:
          if (conversationId != null) {
            // Supprimer le message de la conversation
            await _firestore
                .collection(FirebaseCollections.conversations)
                .doc(conversationId)
                .collection('messages')
                .doc(targetId)
                .delete();
          }
          break;

        case ReportTargetType.conversation:
          await _firestore
              .collection(FirebaseCollections.conversations)
              .doc(targetId)
              .delete();
          break;

        case ReportTargetType.group:
          await _firestore
              .collection(FirebaseCollections.groups)
              .doc(targetId)
              .update({
            'isDeleted': true,
            'deletedAt': FieldValue.serverTimestamp(),
          });
          break;

        case ReportTargetType.event:
          await _firestore
              .collection(FirebaseCollections.events)
              .doc(targetId)
              .update({
            'isCancelled': true,
            'cancelledAt': FieldValue.serverTimestamp(),
          });
          break;

        case ReportTargetType.business:
          await _firestore
              .collection(FirebaseCollections.businesses)
              .doc(targetId)
              .update({
            'status': 'suspended',
            'suspendedAt': FieldValue.serverTimestamp(),
          });
          break;

        case ReportTargetType.product:
          await _firestore
              .collection(FirebaseCollections.products)
              .doc(targetId)
              .update({
            'status': 'removed',
            'removedAt': FieldValue.serverTimestamp(),
          });
          break;
      }
    } on FirebaseException catch (e) {
      throw ServerException(
        e.message ?? 'Erreur lors de la suppression du contenu',
      );
    }
  }

  @override
  Future<ReportStatistics> getReportStatistics() async {
    try {
      final allReports = await _reportsCollection.get();

      int totalReports = allReports.docs.length;
      int pendingReports = 0;
      int resolvedReports = 0;
      int dismissedReports = 0;
      Map<ReportTargetType, int> byTargetType = {};
      Map<ReportReason, int> byReason = {};

      for (final doc in allReports.docs) {
        final data = doc.data();
        final status = data['status'] as String?;
        final targetType = data['targetType'] as String?;
        final reason = data['reason'] as String?;

        // Count by status
        if (status == 'pending' || status == 'underReview') {
          pendingReports++;
        } else if (status == 'resolved') {
          resolvedReports++;
        } else if (status == 'dismissed') {
          dismissedReports++;
        }

        // Count by target type
        if (targetType != null) {
          final type = ReportTargetType.values.firstWhere(
            (e) => e.name == targetType,
            orElse: () => ReportTargetType.user,
          );
          byTargetType[type] = (byTargetType[type] ?? 0) + 1;
        }

        // Count by reason
        if (reason != null) {
          final reasonEnum = ReportReason.values.firstWhere(
            (e) => e.name == reason,
            orElse: () => ReportReason.other,
          );
          byReason[reasonEnum] = (byReason[reasonEnum] ?? 0) + 1;
        }
      }

      return ReportStatistics(
        totalReports: totalReports,
        pendingReports: pendingReports,
        resolvedReports: resolvedReports,
        dismissedReports: dismissedReports,
        byTargetType: byTargetType,
        byReason: byReason,
      );
    } on FirebaseException catch (e) {
      throw ServerException(
        e.message ?? 'Erreur lors de la récupération des statistiques',
      );
    }
  }
}
