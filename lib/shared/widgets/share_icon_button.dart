import 'package:flutter/material.dart';

import 'app_icon.dart';

/// Tuile « Partager via » : une pastille d'icône au-dessus d'un libellé.
///
/// À poser directement dans un `Row` — elle se déclare `Expanded`, chaque
/// tuile prend donc une part égale de la largeur (~68 dp sur les fiches de
/// partage du profil et du groupe).
///
/// Le libellé reste sur **une** ligne, quelle que soit l'échelle de police :
/// à 1,3 (le réglage du Pixel), « WhatsApp » et « Facebook » ne tiennent plus
/// dans 68 dp et se coupaient en plein mot (« WhatsAp / p »). Il rétrécit pour
/// tenir plutôt que de passer à la ligne.
class ShareIconButton extends StatelessWidget {
  /// Icone Material (fallback) ou glyphe SVG de marque via [asset].
  final IconData? icon;
  final String? asset;
  final Color color;
  final Color? iconColor;
  final String label;
  final VoidCallback onTap;

  const ShareIconButton({
    super.key,
    this.icon,
    this.asset,
    required this.color,
    this.iconColor,
    required this.label,
    required this.onTap,
  }) : assert(icon != null || asset != null);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: asset != null
                      ? AppIcon(asset!,
                          color: iconColor ?? Colors.white, size: 18)
                      : Icon(icon, color: iconColor ?? Colors.white, size: 18),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
