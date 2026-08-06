import 'package:flutter/material.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/adaptive_colors.dart';

/// Légende flottante pour la carte indiquant les types de pins
class MapLegend extends StatelessWidget {
  const MapLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Semantics(
      label: 'Légende: Vert pour les amis, Orange pour les membres, Bleu pour les ambassades',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: context.surfaceColor.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: context.borderColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LegendItem(
              color: AppColors.secondary,
              label: l10n.friends,
            ),
            _buildDivider(context),
            _LegendItem(
              color: AppColors.primary,
              label: l10n.member,
            ),
            _buildDivider(context),
            _LegendItem(
              color: Color(0xFF1976D2),
              label: l10n.embassies,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Container(
      height: 16,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: context.borderColor.withValues(alpha: 0.4),
    );
  }
}

/// Item individuel de la légende
class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pastille de couleur : aplat, comme les repères posés sur la carte.
        //
        // Le dégradé et l'ombre colorée ont sauté — une légende sert à
        // rapprocher une couleur d'un libellé, la nuancer brouille justement
        // ce rapprochement. Le liseré blanc reste : il détache la pastille du
        // fond de carte, clair comme sombre.
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
        ),
        const SizedBox(width: 6),
        // Label
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: context.textSecondaryColor,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

/// Version compacte de la légende (icônes seulement)
class MapLegendCompact extends StatelessWidget {
  final VoidCallback? onTap;

  const MapLegendCompact({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: context.surfaceColor.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDot(AppColors.secondary),
            const SizedBox(width: 4),
            _buildDot(AppColors.primary),
            const SizedBox(width: 4),
            _buildDot(const Color(0xFF1976D2)),
            const SizedBox(width: 4),
            Icon(
              Icons.info_outline,
              size: 14,
              color: context.textTertiaryColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDot(Color color) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
    );
  }
}
