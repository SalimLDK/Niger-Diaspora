import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

import '../../../../core/theme/adaptive_colors.dart';
import '../../../../shared/widgets/app_icon.dart';
import '../../../kit/design_kit.dart';

/// Briques communes aux écrans d'authentification, transcrites des maquettes
/// « Bon retour. » / « Créer un compte. » / « Configuration du profil ».
///
/// Tout passe par `adaptive_colors.dart` : les maquettes sont en clair (crème
/// + terracotta), et ces mêmes composants doivent rester lisibles quand le
/// système est en mode nuit.

/// Rayon commun aux champs, boutons et cartes de ces écrans.
const double kAuthRadius = 14;

/// Hauteur commune aux champs et aux boutons pleine largeur.
const double kAuthControlHeight = 54;

/// Page d'authentification : fond crème, contenu défilant, pied de page
/// optionnel épinglé en bas quand la page ne remplit pas l'écran.
class AuthScaffold extends StatelessWidget {
  final Widget child;
  final Widget? footer;

  /// Rangée d'en-tête (flèche retour, titre de section, compteur d'étape).
  final Widget? header;

  const AuthScaffold({
    super.key,
    required this.child,
    this.footer,
    this.header,
  });

  @override
  Widget build(BuildContext context) {
    // Le pied de page est sorti du défilement et épinglé en bas. Le garder
    // dans la colonne défilante imposait un `Spacer`, donc un enfant flexible
    // sous une hauteur non bornée : la page ne se peignait plus du tout.
    return Scaffold(
      backgroundColor: context.backgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (header != null) ...[
                      header!,
                      const SizedBox(height: 18),
                    ],
                    child,
                  ],
                ),
              ),
            ),
            if (footer != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
                child: footer!,
              ),
          ],
        ),
      ),
    );
  }
}

/// Pastille de marque : carré arrondi terracotta portant l'initiale, aligné à
/// gauche (les maquettes ont abandonné le gros logo centré « DN »).
class AuthBrandMark extends StatelessWidget {
  const AuthBrandMark({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: context.adaptivePrimaryColor,
          borderRadius: BorderRadius.circular(kAuthRadius),
        ),
        alignment: Alignment.center,
        child: Text(
          'D',
          style: GoogleFonts.playfairDisplay(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: context.onPrimaryColor,
            height: 1,
          ),
        ),
      ),
    );
  }
}

/// Titre de page : serif gras aligné à gauche, terminé par un point d'accent.
///
/// Simple alias de [DesignTitle] : le titre est le même sur les écrans
/// d'authentification, l'onboarding et la configuration du profil.
class AuthTitle extends StatelessWidget {
  final String text;
  final double size;

  const AuthTitle(this.text, {super.key, this.size = 29});

  @override
  Widget build(BuildContext context) => DesignTitle(text, size: size);
}

/// Libellé au-dessus d'un champ, avec une action optionnelle à droite
/// (« Oublié ? », « Optionnel »).
class AuthFieldLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;

  const AuthFieldLabel(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          text,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: context.textPrimaryColor,
          ),
        ),
        if (trailing != null) ...[const Spacer(), trailing!],
      ],
    );
  }
}

/// Champ de saisie des maquettes : surface pleine, bordure fine, bordure
/// d'accent au focus, bordure rouge + icône en erreur.
class AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool enabled;
  final String? helperText;
  final Widget? suffix;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final TextCapitalization textCapitalization;

  const AuthTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.keyboardType,
    this.obscureText = false,
    this.enabled = true,
    this.helperText,
    this.suffix,
    this.validator,
    this.onChanged,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(kAuthRadius);
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: color, width: width),
        );

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      enabled: enabled,
      onChanged: onChanged,
      textCapitalization: textCapitalization,
      validator: validator,
      style: TextStyle(fontSize: 15.5, color: context.textPrimaryColor),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          fontSize: 15.5,
          color: context.textTertiaryColor,
        ),
        helperText: helperText,
        helperStyle: TextStyle(
          fontSize: 12.5,
          color: context.textTertiaryColor,
        ),
        errorStyle: TextStyle(fontSize: 12.5, color: context.errorColor),
        filled: true,
        fillColor: context.surfaceColor,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 17,
        ),
        suffixIcon: suffix,
        suffixIconConstraints: const BoxConstraints(minWidth: 48),
        border: border(context.borderColor),
        enabledBorder: border(context.borderColor),
        focusedBorder: border(context.adaptivePrimaryColor, 1.6),
        errorBorder: border(context.errorColor, 1.4),
        focusedErrorBorder: border(context.errorColor, 1.6),
        disabledBorder: border(context.borderColor),
      ),
    );
  }
}

/// Œil de bascule pour les champs mot de passe.
class AuthObscureToggle extends StatelessWidget {
  final bool obscured;
  final ValueChanged<bool> onChanged;

  const AuthObscureToggle({
    super.key,
    required this.obscured,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => onChanged(!obscured),
      icon: Icon(
        obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        size: 21,
        color: context.textTertiaryColor,
      ),
      splashRadius: 20,
    );
  }
}

/// Séparateur « ou » entre les deux modes de connexion.
class AuthDivider extends StatelessWidget {
  final String label;

  const AuthDivider({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final line = Expanded(child: Divider(color: context.borderColor, height: 1));
    return Row(
      children: [
        line,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: context.textTertiaryColor),
          ),
        ),
        line,
      ],
    );
  }
}

/// Bouton principal pleine largeur (terracotta plein).
class AuthPrimaryButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  final bool isLoading;

  const AuthPrimaryButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) =>
      DesignPrimaryButton(
        label: label,
        onPressed: onPressed,
        isLoading: isLoading,
      );
}

/// Bouton secondaire contour (« Précédent »).
class AuthSecondaryButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;

  const AuthSecondaryButton({
    super.key,
    required this.onPressed,
    required this.label,
  });

  @override
  Widget build(BuildContext context) =>
      DesignSecondaryButton(label: label, onPressed: onPressed);
}

/// « Pas encore de compte ? S'inscrire » centré sous le bouton principal.
class AuthFooterLink extends StatelessWidget {
  final String question;
  final String action;
  final VoidCallback onTap;

  const AuthFooterLink({
    super.key,
    required this.question,
    required this.action,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          question,
          style: TextStyle(fontSize: 13.5, color: context.textSecondaryColor),
        ),
        const SizedBox(width: 5),
        GestureDetector(
          onTap: onTap,
          child: Text(
            action,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: context.adaptivePrimaryColor,
            ),
          ),
        ),
      ],
    );
  }
}

/// Mention chiffrement en pied de page.
class AuthEncryptionNote extends StatelessWidget {
  const AuthEncryptionNote({super.key});

  @override
  Widget build(BuildContext context) {
    final color = context.textTertiaryColor;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AppIcon(AppIcon.lock, size: 13, color: color),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            AppLocalizations.of(context)!.e2eeFooterNote,
            style: TextStyle(fontSize: 12.5, color: color),
          ),
        ),
      ],
    );
  }
}
