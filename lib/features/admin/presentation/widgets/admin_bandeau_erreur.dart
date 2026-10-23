import 'package:diaspo_niger/core/theme/admin_colors.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Bandeau d'erreur posé **au-dessus** d'une liste qui a encore des données.
///
/// Les écrans du panneau rendaient `state.error != null` en page d'erreur
/// pleine, à la place de la liste. Depuis que chaque action du panneau pose
/// son refus dans `state.error` (zéro ligne sous RLS, journal d'audit
/// refusé), bannir un utilisateur faisait disparaître toute la liste jusqu'au
/// prochain chargement — sans bouton de reprise sur certains écrans. La page
/// pleine ne vaut que quand il n'y a rien d'autre à montrer ; sinon, ce
/// bandeau, que l'admin referme d'un tap (`effacerErreur` du notifier).
class AdminBandeauErreur extends StatelessWidget {
  const AdminBandeauErreur({
    super.key,
    required this.message,
    required this.onFermer,
  });

  final String message;
  final VoidCallback onFermer;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AdminColors.statusRed.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AdminColors.statusRed.withAlpha(60)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AdminColors.statusRed,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AdminColors.statusRed),
            ),
          ),
          IconButton(
            tooltip: AppLocalizations.of(context)!.close,
            icon: const Icon(Icons.close_rounded, size: 18),
            color: AdminColors.statusRed,
            onPressed: onFermer,
          ),
        ],
      ),
    );
  }
}
