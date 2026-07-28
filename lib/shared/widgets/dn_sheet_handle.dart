import 'package:flutter/material.dart';

import '../../core/theme/dn_theme.dart';

/// Poignée de feuille pour les surfaces à palette DNColors (salons audio &
/// podcasts) : barre 40×4 rayon pilule, couleur `context.dn.onSurface4`
/// (thème-aware). Équivalent DN de `SheetHandle` (qui, lui, vaut `#D8CCB8`
/// pour le fil) — les deux palettes cohabitent, on ne mélange pas.
class DnSheetHandle extends StatelessWidget {
  const DnSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: context.dn.onSurface4,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}
