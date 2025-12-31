import '../enums/admin_enums.dart';

/// Mapping des rôles vers leurs permissions
///
/// Définit quelles permissions chaque rôle admin possède.
/// SuperAdmin a toutes les permissions, les autres rôles ont des permissions spécifiques.
const Map<AdminRole, Set<AdminPermission>> rolePermissions = {
  // Aucun rôle = aucune permission
  AdminRole.none: {},

  // SuperAdmin = toutes les permissions
  AdminRole.superAdmin: {
    // Dashboard
    AdminPermission.viewDashboard,

    // Utilisateurs
    AdminPermission.viewUsers,
    AdminPermission.banUsers,
    AdminPermission.verifyProfiles,
    AdminPermission.promoteAdmins,

    // Entreprises
    AdminPermission.viewBusinesses,
    AdminPermission.verifyBusinesses,
    AdminPermission.boostBusinesses,
    AdminPermission.deleteBusinesses,

    // Contenu
    AdminPermission.viewContent,
    AdminPermission.moderateEvents,
    AdminPermission.moderateGroups,
    AdminPermission.viewReports,
    AdminPermission.resolveReports,

    // Marketplace
    AdminPermission.viewMarketplace,
    AdminPermission.moderateProducts,
    AdminPermission.viewOrders,
    AdminPermission.resolveDisputes,

    // Transactions
    AdminPermission.viewTransactions,
    AdminPermission.refundTransactions,
    AdminPermission.completeTransactions,

    // Analytics
    AdminPermission.viewAnalytics,

    // Notifications
    AdminPermission.sendNotifications,

    // Paramètres
    AdminPermission.viewSettings,
    AdminPermission.updateSettings,

    // Feature Flags
    AdminPermission.viewFeatureFlags,
    AdminPermission.toggleFeatureFlags,

    // Audit
    AdminPermission.viewAuditLogs,

    // Gestion des rôles
    AdminPermission.manageRoles,
  },

  // ContentMod = modération de contenu et utilisateurs
  AdminRole.contentMod: {
    // Dashboard
    AdminPermission.viewDashboard,

    // Utilisateurs (sans promotion admin)
    AdminPermission.viewUsers,
    AdminPermission.banUsers,
    AdminPermission.verifyProfiles,

    // Contenu
    AdminPermission.viewContent,
    AdminPermission.moderateEvents,
    AdminPermission.moderateGroups,
    AdminPermission.viewReports,
    AdminPermission.resolveReports,

    // Audit (lecture seule)
    AdminPermission.viewAuditLogs,
  },

  // BusinessMod = gestion des entreprises et marketplace
  AdminRole.businessMod: {
    // Dashboard
    AdminPermission.viewDashboard,

    // Entreprises
    AdminPermission.viewBusinesses,
    AdminPermission.verifyBusinesses,
    AdminPermission.boostBusinesses,
    AdminPermission.deleteBusinesses,

    // Marketplace
    AdminPermission.viewMarketplace,
    AdminPermission.moderateProducts,
    AdminPermission.viewOrders,

    // Audit (lecture seule)
    AdminPermission.viewAuditLogs,
  },

  // FinanceMod = gestion financière
  AdminRole.financeMod: {
    // Dashboard
    AdminPermission.viewDashboard,

    // Transactions
    AdminPermission.viewTransactions,
    AdminPermission.refundTransactions,
    AdminPermission.completeTransactions,

    // Marketplace (pour les litiges)
    AdminPermission.viewMarketplace,
    AdminPermission.viewOrders,
    AdminPermission.resolveDisputes,

    // Analytics
    AdminPermission.viewAnalytics,

    // Audit (lecture seule)
    AdminPermission.viewAuditLogs,
  },
};

/// Extension pour vérifier les permissions d'un rôle
extension AdminRolePermissions on AdminRole {
  /// Obtient les permissions de ce rôle
  Set<AdminPermission> get permissions => rolePermissions[this] ?? {};

  /// Vérifie si ce rôle a une permission spécifique
  bool hasPermission(AdminPermission permission) {
    return permissions.contains(permission);
  }

  /// Vérifie si ce rôle a au moins une des permissions données
  bool hasAnyPermission(Set<AdminPermission> permissionsToCheck) {
    return permissionsToCheck.any((p) => permissions.contains(p));
  }

  /// Vérifie si ce rôle a toutes les permissions données
  bool hasAllPermissions(Set<AdminPermission> permissionsToCheck) {
    return permissionsToCheck.every((p) => permissions.contains(p));
  }
}

/// Liste des rôles admin disponibles (excluant 'none')
final List<AdminRole> availableAdminRoles = AdminRole.values
    .where((role) => role != AdminRole.none)
    .toList();

/// Permissions groupées par catégorie pour l'affichage UI
Map<String, List<AdminPermission>> get permissionsByCategory {
  final Map<String, List<AdminPermission>> grouped = {};
  for (final permission in AdminPermission.values) {
    grouped.putIfAbsent(permission.category, () => []).add(permission);
  }
  return grouped;
}
