import 'package:diaspo_niger/core/theme/admin_colors.dart';
import 'package:diaspo_niger/core/theme/design_kit.dart';
import 'package:flutter/material.dart';

/// La carte des écrans d'accès au panneau : même boîte, même icône, même
/// titre que l'écran de connexion, pour que le défi et l'enrôlement du
/// second facteur se lisent comme sa suite. Défilante : sur un petit écran,
/// le QR code et le champ du code ne doivent jamais déborder.
class CarteAccesAdmin extends StatelessWidget {
  const CarteAccesAdmin({
    super.key,
    required this.titre,
    required this.children,
  });

  final String titre;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.bg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AdminColors.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AdminColors.actionBlue,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: DesignTitle(
                    titre,
                    style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    accent: AdminColors.titleDot,
                  ),
                ),
                const SizedBox(height: 12),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Le message d'erreur des écrans d'accès, rouge sur fond rouge pâle — la
/// même boîte que l'écran de connexion.
class BoiteErreurAdmin extends StatelessWidget {
  const BoiteErreurAdmin(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.only(bottom: 16),
      color: AdminColors.statusRed.withValues(alpha: 0.1),
      child: Text(
        message,
        style: const TextStyle(color: AdminColors.statusRed),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// Le bouton principal des écrans d'accès : plein, bleu d'action, et un
/// indicateur à la place du libellé tant que l'action est en cours — le
/// bouton est alors désactivé, et réactivé dès que le résultat est connu.
class BoutonPrincipalAdmin extends StatelessWidget {
  const BoutonPrincipalAdmin({
    super.key,
    required this.libelle,
    required this.onPressed,
    this.enCours = false,
  });

  final String libelle;
  final VoidCallback? onPressed;
  final bool enCours;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton(
        onPressed: enCours ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AdminColors.actionBlue,
          foregroundColor: Colors.white,
        ),
        child: enCours
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(libelle),
      ),
    );
  }
}
