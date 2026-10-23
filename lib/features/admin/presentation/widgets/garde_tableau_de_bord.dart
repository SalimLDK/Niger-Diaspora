import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/constants/role_permissions.dart';
import '../../domain/enums/admin_enums.dart';
import '../providers/permission_provider.dart';
import '../providers/second_facteur_provider.dart';

/// Garde de la route `/dashboard`.
///
/// `/dashboard` était une route nommée sans garde : atteignable par URL sans
/// connexion ; le rail était vide (`AdminRole.none`) mais `loadDashboardStats`
/// partait quand même (audit du 2026-10-14, § 8). Le tableau de bord ne se
/// construit qu'une fois **deux** choses lues :
///
/// 1. le rôle, dans le jeton — sans rôle (pas de session, ou un compte sans
///    claim admin), c'est l'écran de connexion qui s'affiche, à la même
///    adresse ;
/// 2. les facteurs enrôlés sur le compte — un admin connecté **sans second
///    facteur** voit l'enrôlement, pas le tableau de bord
///    (`docs/deploiement/MFA_ADMIN.md`). L'écran de connexion fait le même
///    tri à la connexion ; la garde le refait pour l'adresse tapée à la main
///    avec une session ouverte avant l'enrôlement.
///
/// Pendant chaque lecture : un indicateur, pas l'écran de connexion.
/// `adminRoleProvider` (synchrone) rend `none` tant que le flux n'a rien
/// émis, ce qui confondrait « pas encore lu » et « refusé » — le jeton est
/// renouvelé de force au premier passage, ça prend un aller-retour. Les
/// facteurs ne sont lus qu'avec un rôle : un compte sans droits n'y touche
/// pas.
class GardeTableauDeBord extends ConsumerWidget {
  const GardeTableauDeBord({
    super.key,
    required this.tableauDeBord,
    required this.connexion,
    required this.enrolement,
  });

  final Widget tableauDeBord;
  final Widget connexion;
  final Widget enrolement;

  static const _attente = Scaffold(
    body: Center(child: CircularProgressIndicator()),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(currentAdminRoleProvider)
        .when(
          loading: () => _attente,
          error: (_, __) => connexion,
          data: (role) {
            if (!role.hasPermission(AdminPermission.viewDashboard)) {
              return connexion;
            }
            return ref
                .watch(facteursEnrolesProvider)
                .when(
                  loading: () => _attente,
                  // Facteurs illisibles : on ne sait pas, donc ni le tableau
                  // de bord (qui exige un facteur) ni l'enrôlement (qui
                  // exige une session saine) — la connexion, comme pour un
                  // jeton illisible.
                  error: (_, __) => connexion,
                  data: (facteurs) =>
                      facteurs.isEmpty ? enrolement : tableauDeBord,
                );
          },
        );
  }
}
