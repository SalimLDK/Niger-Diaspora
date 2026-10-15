import 'package:diaspo_niger/core/theme/design_kit.dart';
import 'package:flutter/material.dart';

/// Dernière ligne d'une liste paginée du panneau : « Charger plus », ou un
/// sablier pendant que la page suivante arrive.
///
/// Les écrans du panneau en portaient chacun une copie ; la brique visuelle
/// est celle de `design_kit.dart` (`DesignSecondaryButton`).
class AdminChargerPlus extends StatelessWidget {
  const AdminChargerPlus({
    super.key,
    required this.enCours,
    required this.onPressed,
  });

  final bool enCours;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: enCours
            ? const CircularProgressIndicator()
            : DesignSecondaryButton(
                label: 'Charger plus',
                onPressed: onPressed,
              ),
      ),
    );
  }
}
