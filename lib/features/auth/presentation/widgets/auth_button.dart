import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/theme/adaptive_colors.dart';
import 'auth_scaffold.dart';

/// Bouton de connexion par fournisseur externe.
///
/// [iconAsset] rend le SVG tel quel, sans teinte : le logo Google est
/// multicolore et `AppIcon` l'aplatirait en une seule couleur.
class AuthButton extends StatelessWidget {
  static const googleAsset = 'icon_google.svg';

  final VoidCallback onPressed;

  /// Glyphe texte (ancien usage) — ignoré si [iconAsset] est fourni.
  final String? icon;
  final String? iconAsset;
  final String label;

  /// Null = suit le thème. Les valeurs par défaut étaient figées sur les
  /// jetons clairs (blanc / texte sombre), ce qui rendait le bouton illisible
  /// une fois le thème sombre actif.
  final Color? backgroundColor;
  final Color? textColor;
  final bool isLoading;

  const AuthButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.iconAsset,
    this.backgroundColor,
    this.textColor,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final background = backgroundColor ?? context.surfaceColor;
    final foreground = textColor ?? context.textPrimaryColor;
    return SizedBox(
      width: double.infinity,
      height: kAuthControlHeight,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kAuthRadius),
          ),
          side: BorderSide(color: context.borderColor),
        ),
        child:
            isLoading
                ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(foreground),
                  ),
                )
                : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (iconAsset != null)
                      SvgPicture.asset(
                        'assets/icons/$iconAsset',
                        width: 19,
                        height: 19,
                      )
                    else if (icon != null)
                      Text(icon!, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 12),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                        color: foreground,
                      ),
                    ),
                  ],
                ),
      ),
    );
  }
}
