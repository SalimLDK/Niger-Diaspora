import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/adaptive_colors.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

/// Écran d'attente au démarrage — c'est l'`initialLocation` du routeur, donc
/// le tout premier écran Flutter que voit l'utilisateur.
///
/// Le sigle « DN » et le cercle de progression sont en **vert**
/// (`AppColors.secondary` / `secondaryGradient`) depuis le 2026-09-07, sur
/// demande produit ; ils étaient sur l'orange primaire. La teinte est
/// volontairement **fixe** et ne suit pas l'accent choisi par le compte
/// (orange ou vert, cf. `AppThemeColor` dans `app.dart`) : ne pas la
/// « corriger » vers `AppColors.primary` ni vers `adaptivePrimaryGradient`
/// en croyant réparer une incohérence de thème.
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
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: AppColors.secondaryGradient,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.secondary.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  'DN',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: AppColors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.appTitle,
              style: Theme.of(
                context,
              ).textTheme.displayMedium?.copyWith(color: context.textPrimaryColor),
            ),
            const SizedBox(height: 8),
            Text(
              'Connecter la diaspora nigerienne',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: context.textSecondaryColor),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.secondary),
            ),
          ],
        ),
      ),
    );
  }
}
