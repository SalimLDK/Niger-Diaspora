import 'package:flutter/material.dart';

/// Poignée canonique des feuilles modales (§16) : barre 40×4 centrée, rayon
/// pilule. Clair = `#D8CCB8` (sable) ; sombre = blanc atténué pour rester
/// visible sur une surface foncée.
///
/// Remplace les poignées ad hoc (`Container(width: 40, height: 4, …)`) pour
/// que toutes les feuilles partagent la même règle.
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.22)
              : const Color(0xFFD8CCB8),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}
