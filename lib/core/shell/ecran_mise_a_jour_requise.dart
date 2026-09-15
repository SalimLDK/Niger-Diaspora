import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_colors.dart';
import '../services/app_review_service.dart';
import '../theme/adaptive_colors.dart';
import '../../l10n/app_localizations.dart';

/// L'écran qui se substitue à l'application quand la version installée est en
/// deçà du minimum exigé (plan MLS, préalable à la phase 6).
///
/// **Il n'a pas de sortie, et c'est tout son intérêt** : le gel de `messages`
/// n'est tenable que si un vieux build ne peut plus écrire. Un bandeau qu'on
/// ignore ne suffit pas — c'est précisément ce que le projet avait jusqu'ici,
/// et pourquoi la phase 6 restait inapplicable.
///
/// Il ne s'affiche que sur décision de `miseAJourObligatoire`, qui refuse de
/// bloquer dans quatre cas — dont celui où le store ne sert pas encore la
/// version exigée. C'est là que vit la sécurité, pas ici.
class EcranMiseAJourRequise extends StatelessWidget {
  const EcranMiseAJourRequise({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: context.backgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.system_update, size: 56, color: AppColors.success),
                const SizedBox(height: 20),
                Text(
                  l10n.majObligatoireTitre,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.majObligatoireTexte,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: context.textSecondaryColor,
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _ouvrirLeStore,
                    child: Text(l10n.majObligatoireAction),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _ouvrirLeStore() async {
    final url = Platform.isIOS
        ? AppReviewService.appStoreUrl
        : AppReviewService.playStoreUrl;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    // Sans `catch`, une plateforme sans navigateur ferait remonter une
    // exception dans un écran dont on ne peut pas sortir.
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // L'écran reste affiché : la personne peut chercher l'application dans
      // son store à la main.
    }
  }
}
