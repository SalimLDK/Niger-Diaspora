import 'package:diaspo_niger/l10n/app_localizations.dart';

import '../domain/entities/report_entity.dart';

/// Libelles d'affichage des enumerations de signalement.
///
/// Ils vivaient dans `ReportEntity`, sous des getters commentes « Label
/// localise » qui rendaient du francais en dur : une entite n'a pas de
/// `BuildContext`, donc rien ne pouvait les traduire. La correspondance
/// enumeration -> libelle appartient a la presentation ; l'entite ne garde que
/// la donnee.
extension ReportTargetTypeLabel on ReportTargetType {
  String label(AppLocalizations l10n) => switch (this) {
    ReportTargetType.user => l10n.user,
    ReportTargetType.message => l10n.message,
    ReportTargetType.conversation => l10n.reportTypeConversation,
    ReportTargetType.group => l10n.group,
    ReportTargetType.event => l10n.reportTypeEvent,
    ReportTargetType.business => l10n.reportTypeBusiness,
    ReportTargetType.product => l10n.reportTypeProduct,
  };
}

extension ReportReasonLabel on ReportReason {
  String label(AppLocalizations l10n) => switch (this) {
    ReportReason.spam => l10n.reportReasonSpam,
    ReportReason.harassment => l10n.reportReasonHarassment,
    ReportReason.inappropriate => l10n.reportReasonInappropriate,
    // `violenceThreats` et non `reportReasonViolence` : le premier vaut
    // « Violence ou menaces », exactement ce qu'affichait l'entite.
    ReportReason.violence => l10n.violenceThreats,
    ReportReason.hateSpeech => l10n.reportReasonHateSpeech,
    ReportReason.scam => l10n.reportReasonScam,
    ReportReason.impersonation => l10n.reportReasonImpersonation,
    ReportReason.other => l10n.reportReasonOther,
  };
}

extension ReportStatusLabel on ReportStatus {
  String label(AppLocalizations l10n) => switch (this) {
    ReportStatus.pending => l10n.statusPending,
    ReportStatus.underReview => l10n.reportStatusUnderReview,
    ReportStatus.resolved => l10n.adminResolvedLabel,
    ReportStatus.dismissed => l10n.adminDismissedLabel,
  };
}
