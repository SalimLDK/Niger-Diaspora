import 'package:diaspo_niger/core/theme/admin_colors.dart';
import 'package:diaspo_niger/features/admin/presentation/providers/admin_provider.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

// Ce que l'écran Signalements dit d'un signalement : où mène « Voir le
// contenu », la couleur et le libellé d'un statut, l'icône et le libellé d'un
// type de cible. Des fonctions pures, hors de l'écran, pour être testées.

/// Route de la fiche du contenu signalé, ou null quand il n'y en a pas
/// (message sans conversation connue, type inconnu).
String? routeContenuSignale(ReportEntity report) {
  switch (report.targetType) {
    case 'user':
      return '/profile/${report.targetId}';
    case 'group':
      return '/groups/${report.targetId}';
    case 'event':
      return '/events/${report.targetId}';
    case 'business':
      return '/businesses/${report.targetId}';
    // La cible est l'avis ; la fiche qui le porte est dans l'instantané
    // posé par `avis_signaler`.
    case 'business_review':
      final fiche = report.contentSnapshot?.metadata?['business_id'];
      return fiche is String ? '/businesses/$fiche' : null;
    case 'product':
      return '/marketplace/${report.targetId}';
    case 'message':
    case 'conversation':
      if (report.conversationId != null) {
        return '/messages/${report.conversationId}';
      }
      return null;
    default:
      return null;
  }
}

/// Écran du panneau où voir ce qu'un signalement vise, ou null quand le panneau
/// n'en a pas. « Voir le contenu » poussait une route de l'app mobile
/// (`/profile/<id>`) dans un `MaterialApp` qui n'en connaît que deux et sans
/// GoRouter : le bouton levait une erreur et ne faisait rien (vu en ligne le
/// 2026-10-15). Les messages et conversations n'ont pas d'écran ici : leur
/// contenu est chiffré et le panneau ne le lit pas.
String? destinationContenuSignale(String targetType) {
  switch (targetType) {
    case 'user':
      return 'users';
    case 'business':
    case 'business_review':
      return 'businesses';
    case 'product':
      return 'marketplace';
    case 'group':
    case 'event':
      return 'content';
    default:
      return null;
  }
}

Color couleurStatutSignalement(String status) {
  switch (status) {
    case 'pending':
    case 'reviewing':
      return AdminColors.statusAmber;
    case 'escalated':
      return AdminColors.statusRed;
    case 'resolved':
      return AdminColors.statusGreen;
    case 'dismissed':
      return AdminColors.statusGray;
    default:
      return AdminColors.actionBlueLight;
  }
}

String libelleStatutSignalement(AppLocalizations l10n, String status) {
  switch (status) {
    case 'pending':
      return l10n.adminPending;
    case 'reviewing':
      return l10n.adminReviewingLabel;
    case 'escalated':
      return l10n.adminEscalatedLabel;
    case 'resolved':
      return l10n.adminResolvedLabel;
    case 'dismissed':
      return l10n.adminDismissedLabel;
    default:
      return status;
  }
}

IconData iconeTypeSignalement(String type) {
  switch (type) {
    case 'user':
      return Icons.person_rounded;
    case 'message':
      return Icons.message_rounded;
    case 'conversation':
      return Icons.chat_bubble_rounded;
    case 'event':
      return Icons.event_rounded;
    case 'group':
      return Icons.group_rounded;
    case 'business':
      return Icons.store_rounded;
    case 'business_review':
      return Icons.rate_review_rounded;
    case 'product':
      return Icons.shopping_bag_rounded;
    default:
      return Icons.report_rounded;
  }
}

String libelleTypeSignalement(AppLocalizations l10n, String type) {
  switch (type) {
    case 'user':
      return l10n.user;
    case 'message':
      return l10n.adminMessage;
    case 'conversation':
      return l10n.conversation;
    case 'event':
      return l10n.eventLabel;
    case 'group':
      return l10n.group;
    case 'business':
      return l10n.reportTypeBusiness;
    case 'business_review':
      return l10n.reviews;
    case 'product':
      return l10n.reportTypeProduct;
    default:
      return type;
  }
}
