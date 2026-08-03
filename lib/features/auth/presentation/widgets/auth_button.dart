import 'package:flutter/material.dart';
import '../../../../core/theme/adaptive_colors.dart';

class AuthButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String icon;
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
    required this.icon,
    required this.label,
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
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          side: BorderSide(
            color: context.borderStrongColor,
            width: 2,
          ),
        ),
        child: isLoading
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
                  Text(
                    icon,
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
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
