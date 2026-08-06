import 'package:freezed_annotation/freezed_annotation.dart';

part 'report_entity.freezed.dart';

/// Snapshot du contenu signalé (préservé même après suppression)
@freezed
class ContentSnapshot with _$ContentSnapshot {
  const factory ContentSnapshot({
    /// Texte du message ou description
    String? text,
    /// URL de l'image (si applicable)
    String? imageUrl,
    /// URL de la vidéo (si applicable)
    String? videoUrl,
    /// URL du fichier/document (si applicable)
    String? fileUrl,
    /// Nom du fichier
    String? fileName,
    /// Type de contenu (text, image, video, audio, file, product)
    String? contentType,
    /// Données additionnelles (ex: infos produit, profil)
    Map<String, dynamic>? metadata,
    /// Date de capture
    DateTime? capturedAt,
  }) = _ContentSnapshot;
}

/// Types de contenu pouvant être signalé
enum ReportTargetType {
  user,
  message,
  conversation,
  group,
  event,
  business,
  product,
}

/// Statuts possibles d'un signalement
enum ReportStatus {
  pending,
  underReview,
  resolved,
  dismissed,
}

/// Raisons prédéfinies pour un signalement
enum ReportReason {
  spam,
  harassment,
  inappropriate,
  violence,
  hateSpeech,
  scam,
  impersonation,
  other,
}

@freezed
class ReportEntity with _$ReportEntity {
  const ReportEntity._();

  const factory ReportEntity({
    required String id,
    required String reporterId,
    String? reporterName,
    String? reporterPhotoUrl,
    required ReportTargetType targetType,
    required String targetId,
    String? targetName,
    String? targetPreview,
    String? conversationId,
    required ReportReason reason,
    String? description,
    /// Snapshot du contenu au moment du signalement
    ContentSnapshot? contentSnapshot,
    /// ID de la personne signalée (pour notification)
    String? reportedUserId,
    @Default(ReportStatus.pending) ReportStatus status,
    String? adminNote,
    String? reviewedBy,
    String? reviewerName,
    String? resolution,
    DateTime? createdAt,
    DateTime? reviewedAt,
    /// Indique si la personne signalée a été notifiée
    @Default(false) bool reportedUserNotified,
  }) = _ReportEntity;

  /// Vérifie si le signalement est en attente de traitement
  bool get isPending =>
      status == ReportStatus.pending || status == ReportStatus.underReview;

  /// Vérifie si le signalement a été traité
  bool get isProcessed =>
      status == ReportStatus.resolved || status == ReportStatus.dismissed;
}
