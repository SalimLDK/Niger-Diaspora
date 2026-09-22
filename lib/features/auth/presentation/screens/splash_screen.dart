import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../../../core/theme/design_kit.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

/// Écran d'attente au démarrage — c'est l'`initialLocation` du routeur, donc
/// le tout premier écran Flutter que voit l'utilisateur.
///
/// Le sigle « DN » et le cercle de progression sont en **vert**
/// (`AppColors.secondary`) depuis le 2026-09-07, sur demande produit ; ils
/// étaient sur l'orange primaire. La teinte est volontairement **fixe** et ne
/// suit pas l'accent choisi par le compte (orange ou vert, cf. `AppThemeColor`
/// dans `app.dart`) : ne pas la « corriger » vers `AppColors.primary` ni vers
/// `adaptivePrimaryGradient` en croyant réparer une incohérence de thème.
///
/// Le sigle lui-même vit dans [DesignBrandMark] : cet écran était le seul des
/// trois qui le dessinaient à respecter la consigne ci-dessus.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: context.surfaceVariantColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const DesignBrandMark(size: 120, withGlow: true),
            const SizedBox(height: 24),
            Text(
              l10n.appTitle,
              style: Theme.of(
                context,
              ).textTheme.displayMedium?.copyWith(color: context.textPrimaryColor),
            ),
            const SizedBox(height: 8),
            // Était écrit en dur, sans accent (« nigerienne »), et restait en
            // français sur un téléphone en anglais — vu sur SM A515F le
            // 2026-09-22, build Play 1.2.2+26.
            Text(
              l10n.splashTagline,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: context.textSecondaryColor),
            ),
            const SizedBox(height: 48),
            // Le filet du cercle (`backgroundColor`) est posé ici aussi : sans
            // lui, il retombe sur `progressIndicatorTheme.circularTrackColor`,
            // qui suit l'accent du compte — un compte en thème Orange gardait
            // un anneau brun-orangé autour de l'arc vert (vu sur SM A515F).
            CircularProgressIndicator(
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.secondary,
              ),
              backgroundColor: AppColors.secondary.withValues(alpha: 0.2),
            ),
          ],
        ),
      ),
    );
  }
}
