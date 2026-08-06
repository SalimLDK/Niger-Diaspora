import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:diaspo_niger/shared/widgets/app_icon.dart';
import '../../domain/enums/admin_enums.dart';
import '../../domain/constants/role_permissions.dart';
import '../providers/permission_provider.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

/// Widget qui protège son contenu selon les permissions de l'utilisateur.
///
/// Si l'utilisateur n'a pas la permission requise, affiche [fallback] ou rien.
class PermissionGuard extends ConsumerWidget {
  /// La permission requise pour afficher le contenu
  final AdminPermission permission;

  /// Le widget à afficher si l'utilisateur a la permission
  final Widget child;

  /// Le widget à afficher si l'utilisateur n'a pas la permission (optionnel)
  final Widget? fallback;

  /// Si true, affiche le child pendant le chargement
  final bool showWhileLoading;

  const PermissionGuard({
    required this.permission,
    required this.child,
    this.fallback,
    this.showWhileLoading = false,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roleAsync = ref.watch(currentAdminRoleProvider);

    return roleAsync.when(
      loading: () => showWhileLoading ? child : (fallback ?? const SizedBox.shrink()),
      error: (_, __) => fallback ?? const SizedBox.shrink(),
      data: (role) {
        final hasPermission = role.hasPermission(permission);
        if (hasPermission) {
          return child;
        }
        return fallback ?? const SizedBox.shrink();
      },
    );
  }
}

/// Widget qui protège son contenu si l'utilisateur a au moins une des permissions.
class AnyPermissionGuard extends ConsumerWidget {
  /// Les permissions dont au moins une est requise
  final Set<AdminPermission> permissions;

  /// Le widget à afficher si l'utilisateur a au moins une permission
  final Widget child;

  /// Le widget à afficher si l'utilisateur n'a aucune des permissions
  final Widget? fallback;

  const AnyPermissionGuard({
    required this.permissions,
    required this.child,
    this.fallback,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roleAsync = ref.watch(currentAdminRoleProvider);

    return roleAsync.when(
      loading: () => fallback ?? const SizedBox.shrink(),
      error: (_, __) => fallback ?? const SizedBox.shrink(),
      data: (role) {
        final hasAnyPermission = role.hasAnyPermission(permissions);
        if (hasAnyPermission) {
          return child;
        }
        return fallback ?? const SizedBox.shrink();
      },
    );
  }
}

/// Widget qui affiche son contenu uniquement pour les SuperAdmin.
class SuperAdminGuard extends ConsumerWidget {
  final Widget child;
  final Widget? fallback;

  const SuperAdminGuard({
    required this.child,
    this.fallback,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSuperAdmin = ref.watch(isSuperAdminProvider);

    if (isSuperAdmin) {
      return child;
    }
    return fallback ?? const SizedBox.shrink();
  }
}

/// Widget qui affiche un message "Accès non autorisé" pour les écrans protégés
class UnauthorizedScreen extends StatelessWidget {
  final String? message;

  const UnauthorizedScreen({
    this.message,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accès refusé'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const AppIcon(
              AppIcon.lock,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              message ?? 'Vous n\'avez pas les permissions nécessaires pour accéder à cette page.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const AppIcon(AppIcon.arrowBack),
              label: Text(l10n.adminBack),
            ),
          ],
        ),
      ),
    );
  }
}

/// Extension pour faciliter la protection des widgets
extension PermissionGuardExtension on Widget {
  /// Protège ce widget avec une permission
  Widget guardedBy(AdminPermission permission, {Widget? fallback}) {
    return PermissionGuard(
      permission: permission,
      fallback: fallback,
      child: this,
    );
  }

  /// Protège ce widget pour les SuperAdmin uniquement
  Widget superAdminOnly({Widget? fallback}) {
    return SuperAdminGuard(
      fallback: fallback,
      child: this,
    );
  }
}
