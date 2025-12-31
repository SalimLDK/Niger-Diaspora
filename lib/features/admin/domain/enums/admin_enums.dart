import 'package:flutter/material.dart';

/// Rôles d'administration disponibles dans l'application
enum AdminRole {
  none,
  superAdmin,
  contentMod,
  businessMod,
  financeMod;

  /// Nom d'affichage du rôle
  String get displayName {
    switch (this) {
      case AdminRole.none:
        return 'Aucun';
      case AdminRole.superAdmin:
        return 'Super Administrateur';
      case AdminRole.contentMod:
        return 'Modérateur Contenu';
      case AdminRole.businessMod:
        return 'Modérateur Business';
      case AdminRole.financeMod:
        return 'Modérateur Finance';
    }
  }

  /// Nom court du rôle
  String get shortName {
    switch (this) {
      case AdminRole.none:
        return 'Aucun';
      case AdminRole.superAdmin:
        return 'SuperAdmin';
      case AdminRole.contentMod:
        return 'ContentMod';
      case AdminRole.businessMod:
        return 'BusinessMod';
      case AdminRole.financeMod:
        return 'FinanceMod';
    }
  }

  /// Description du rôle
  String get description {
    switch (this) {
      case AdminRole.none:
        return 'Pas de droits d\'administration';
      case AdminRole.superAdmin:
        return 'Accès complet à toutes les fonctionnalités admin';
      case AdminRole.contentMod:
        return 'Modération du contenu, rapports et utilisateurs';
      case AdminRole.businessMod:
        return 'Gestion des entreprises et du marketplace';
      case AdminRole.financeMod:
        return 'Gestion des transactions et finances';
    }
  }

  /// Icône du rôle
  IconData get icon {
    switch (this) {
      case AdminRole.none:
        return Icons.person_outline;
      case AdminRole.superAdmin:
        return Icons.admin_panel_settings;
      case AdminRole.contentMod:
        return Icons.article_outlined;
      case AdminRole.businessMod:
        return Icons.business_outlined;
      case AdminRole.financeMod:
        return Icons.account_balance_outlined;
    }
  }

  /// Couleur associée au rôle
  Color get color {
    switch (this) {
      case AdminRole.none:
        return Colors.grey;
      case AdminRole.superAdmin:
        return const Color(0xFF8B5CF6); // Violet
      case AdminRole.contentMod:
        return const Color(0xFF3B82F6); // Bleu
      case AdminRole.businessMod:
        return const Color(0xFF10B981); // Vert
      case AdminRole.financeMod:
        return const Color(0xFFF59E0B); // Orange
    }
  }

  /// Vérifie si c'est un rôle admin (non-none)
  bool get isAdmin => this != AdminRole.none;

  /// Convertit depuis une chaîne
  static AdminRole fromString(String? value) {
    if (value == null) return AdminRole.none;
    return AdminRole.values.firstWhere(
      (role) => role.name == value,
      orElse: () => AdminRole.none,
    );
  }
}

/// Permissions granulaires pour le contrôle d'accès
enum AdminPermission {
  // Dashboard
  viewDashboard,

  // Gestion des utilisateurs
  viewUsers,
  banUsers,
  verifyProfiles,
  promoteAdmins,

  // Gestion des entreprises
  viewBusinesses,
  verifyBusinesses,
  boostBusinesses,
  deleteBusinesses,

  // Modération de contenu
  viewContent,
  moderateEvents,
  moderateGroups,
  viewReports,
  resolveReports,

  // Marketplace
  viewMarketplace,
  moderateProducts,
  viewOrders,
  resolveDisputes,

  // Transactions
  viewTransactions,
  refundTransactions,
  completeTransactions,

  // Analytics
  viewAnalytics,

  // Notifications
  sendNotifications,

  // Paramètres
  viewSettings,
  updateSettings,

  // Feature Flags
  viewFeatureFlags,
  toggleFeatureFlags,

  // Logs d'audit
  viewAuditLogs,

  // Gestion des rôles (SuperAdmin uniquement)
  manageRoles;

  /// Nom d'affichage de la permission
  String get displayName {
    switch (this) {
      case AdminPermission.viewDashboard:
        return 'Voir le tableau de bord';
      case AdminPermission.viewUsers:
        return 'Voir les utilisateurs';
      case AdminPermission.banUsers:
        return 'Bannir des utilisateurs';
      case AdminPermission.verifyProfiles:
        return 'Vérifier les profils';
      case AdminPermission.promoteAdmins:
        return 'Promouvoir des admins';
      case AdminPermission.viewBusinesses:
        return 'Voir les entreprises';
      case AdminPermission.verifyBusinesses:
        return 'Vérifier les entreprises';
      case AdminPermission.boostBusinesses:
        return 'Booster les entreprises';
      case AdminPermission.deleteBusinesses:
        return 'Supprimer les entreprises';
      case AdminPermission.viewContent:
        return 'Voir le contenu';
      case AdminPermission.moderateEvents:
        return 'Modérer les événements';
      case AdminPermission.moderateGroups:
        return 'Modérer les groupes';
      case AdminPermission.viewReports:
        return 'Voir les signalements';
      case AdminPermission.resolveReports:
        return 'Résoudre les signalements';
      case AdminPermission.viewMarketplace:
        return 'Voir le marketplace';
      case AdminPermission.moderateProducts:
        return 'Modérer les produits';
      case AdminPermission.viewOrders:
        return 'Voir les commandes';
      case AdminPermission.resolveDisputes:
        return 'Résoudre les litiges';
      case AdminPermission.viewTransactions:
        return 'Voir les transactions';
      case AdminPermission.refundTransactions:
        return 'Rembourser des transactions';
      case AdminPermission.completeTransactions:
        return 'Compléter des transactions';
      case AdminPermission.viewAnalytics:
        return 'Voir les analytics';
      case AdminPermission.sendNotifications:
        return 'Envoyer des notifications';
      case AdminPermission.viewSettings:
        return 'Voir les paramètres';
      case AdminPermission.updateSettings:
        return 'Modifier les paramètres';
      case AdminPermission.viewFeatureFlags:
        return 'Voir les feature flags';
      case AdminPermission.toggleFeatureFlags:
        return 'Modifier les feature flags';
      case AdminPermission.viewAuditLogs:
        return 'Voir les logs d\'audit';
      case AdminPermission.manageRoles:
        return 'Gérer les rôles admin';
    }
  }

  /// Catégorie de la permission
  String get category {
    switch (this) {
      case AdminPermission.viewDashboard:
        return 'Dashboard';
      case AdminPermission.viewUsers:
      case AdminPermission.banUsers:
      case AdminPermission.verifyProfiles:
      case AdminPermission.promoteAdmins:
        return 'Utilisateurs';
      case AdminPermission.viewBusinesses:
      case AdminPermission.verifyBusinesses:
      case AdminPermission.boostBusinesses:
      case AdminPermission.deleteBusinesses:
        return 'Entreprises';
      case AdminPermission.viewContent:
      case AdminPermission.moderateEvents:
      case AdminPermission.moderateGroups:
      case AdminPermission.viewReports:
      case AdminPermission.resolveReports:
        return 'Contenu';
      case AdminPermission.viewMarketplace:
      case AdminPermission.moderateProducts:
      case AdminPermission.viewOrders:
      case AdminPermission.resolveDisputes:
        return 'Marketplace';
      case AdminPermission.viewTransactions:
      case AdminPermission.refundTransactions:
      case AdminPermission.completeTransactions:
        return 'Transactions';
      case AdminPermission.viewAnalytics:
        return 'Analytics';
      case AdminPermission.sendNotifications:
        return 'Notifications';
      case AdminPermission.viewSettings:
      case AdminPermission.updateSettings:
        return 'Paramètres';
      case AdminPermission.viewFeatureFlags:
      case AdminPermission.toggleFeatureFlags:
        return 'Feature Flags';
      case AdminPermission.viewAuditLogs:
        return 'Audit';
      case AdminPermission.manageRoles:
        return 'Rôles';
    }
  }
}
