import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/constants/role_permissions.dart';
import '../../domain/enums/admin_enums.dart';
import '../providers/permission_provider.dart';

/// Garde de la route `/dashboard`.
///
/// `/dashboard` était une route nommée sans garde : atteignable par URL sans
/// connexion ; le rail était vide (`AdminRole.none`) mais `loadDashboardStats`
/// partait quand même (audit du 2026-10-14, § 8). Le tableau de bord ne se
/// construit qu'une fois le rôle lu dans le jeton ; sans rôle — pas de
/// session, ou un compte sans claim admin —, c'est l'écran de connexion qui
/// s'affiche, à la même adresse.
///
/// Pendant la lecture du jeton : un indicateur, pas l'écran de connexion.
/// `adminRoleProvider` (synchrone) rend `none` tant que le flux n'a rien
/// émis, ce qui confondrait « pas encore lu » et « refusé » — le jeton est
/// renouvelé de force au premier passage, ça prend un aller-retour.
class GardeTableauDeBord extends ConsumerWidget {
  const GardeTableauDeBord({
    super.key,
    required this.tableauDeBord,
    required this.connexion,
  });

  final Widget tableauDeBord;
  final Widget connexion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(currentAdminRoleProvider)
        .when(
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => connexion,
          data: (role) => role.hasPermission(AdminPermission.viewDashboard)
              ? tableauDeBord
              : connexion,
        );
  }
}
