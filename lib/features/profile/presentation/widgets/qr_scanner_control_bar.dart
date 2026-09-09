import 'package:flutter/material.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import '../../../../core/constants/app_colors.dart';

/// Barre de contrôles du bas de [QrScannerScreen].
///
/// Extraite de l'écran pour être vérifiable sans caméra : `MobileScanner`
/// exige le plugin natif, alors que ce qui casse ici est purement une
/// histoire de largeurs — voir
/// `test/features/profile/qr_scanner_control_bar_overflow_test.dart`.
///
/// La forme « icône au-dessus du label » n'est pas décorative. À deux boutons,
/// l'ancienne rangée icône-à-côté-du-label tenait ; le troisième
/// (« Mon QR Code ») la faisait déborder d'un écran de 360 dp avant même toute
/// échelle de police.
class QrScannerControlBar extends StatelessWidget {
  final bool flashOn;
  final VoidCallback onToggleFlash;
  final VoidCallback onSwitchCamera;
  final VoidCallback onShowMyQrCode;

  const QrScannerControlBar({
    super.key,
    required this.flashOn,
    required this.onToggleFlash,
    required this.onSwitchCamera,
    required this.onShowMyQrCode,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        // La rangée n'a pas de hauteur bornée (elle vit dans un `Positioned`
        // sans `top`) : sans IntrinsicHeight, `stretch` n'a rien à quoi
        // s'étirer. Il donne aux trois tuiles la hauteur de la plus haute,
        // celle dont le label se replie sur deux lignes.
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ControlButton(
                icon: flashOn ? Icons.flash_on : Icons.flash_off,
                label: flashOn ? l10n.flashActive : l10n.flash,
                onTap: onToggleFlash,
                isActive: flashOn,
              ),
              const SizedBox(width: 10),
              _ControlButton(
                icon: Icons.cameraswitch_rounded,
                label: l10n.changeCard,
                onTap: onSwitchCamera,
              ),
              const SizedBox(width: 10),
              // Son propre QR, sans quitter le scanner.
              _ControlButton(
                icon: Icons.qr_code_rounded,
                label: l10n.myQrCode,
                onTap: onShowMyQrCode,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            decoration: BoxDecoration(
              color:
                  isActive
                      ? AppColors.primary.withValues(alpha: 0.9)
                      : Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color:
                    isActive
                        ? AppColors.primary
                        : AppColors.white.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: AppColors.white, size: 24),
                const SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  // Deux lignes plutôt qu'une coupure : à forte échelle de
                  // police, « Mon QR Code » se replie au lieu d'être tronqué.
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
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
