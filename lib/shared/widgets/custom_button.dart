import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';

/// Bouton personnalise avec support du loading et des variantes
enum CustomButtonVariant { primary, secondary, tertiary, outlined }

enum CustomButtonSize { small, medium, large }

class CustomButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  final bool isLoading;
  final bool isDisabled;
  final Color? backgroundColor;
  final Color? textColor;
  final double? width;
  final Widget? icon;
  final CustomButtonVariant variant;
  final CustomButtonSize size;

  const CustomButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.isLoading = false,
    this.isDisabled = false,
    this.backgroundColor,
    this.textColor,
    this.width,
    this.icon,
    this.variant = CustomButtonVariant.primary,
    this.size = CustomButtonSize.medium,
  });

  /// Constructeur pour bouton primaire
  const CustomButton.primary({
    super.key,
    required this.onPressed,
    required this.label,
    this.isLoading = false,
    this.isDisabled = false,
    this.width,
    this.icon,
    this.size = CustomButtonSize.medium,
  })  : variant = CustomButtonVariant.primary,
        backgroundColor = null,
        textColor = null;

  /// Constructeur pour bouton secondaire (outlined)
  const CustomButton.secondary({
    super.key,
    required this.onPressed,
    required this.label,
    this.isLoading = false,
    this.isDisabled = false,
    this.width,
    this.icon,
    this.size = CustomButtonSize.medium,
  })  : variant = CustomButtonVariant.outlined,
        backgroundColor = null,
        textColor = null;

  /// Constructeur pour bouton tertiary (ghost)
  const CustomButton.tertiary({
    super.key,
    required this.onPressed,
    required this.label,
    this.isLoading = false,
    this.isDisabled = false,
    this.width,
    this.icon,
    this.size = CustomButtonSize.medium,
  })  : variant = CustomButtonVariant.tertiary,
        backgroundColor = null,
        textColor = null;

  EdgeInsetsGeometry get _padding {
    switch (size) {
      case CustomButtonSize.small:
        return const EdgeInsets.symmetric(horizontal: 16, vertical: 10);
      case CustomButtonSize.medium:
        return AppSpacing.buttonPadding;
      case CustomButtonSize.large:
        return const EdgeInsets.symmetric(horizontal: 32, vertical: 20);
    }
  }

  double get _fontSize {
    switch (size) {
      case CustomButtonSize.small:
        return 14;
      case CustomButtonSize.medium:
        return 16;
      case CustomButtonSize.large:
        return 18;
    }
  }

  double get _iconSize {
    switch (size) {
      case CustomButtonSize.small:
        return 18;
      case CustomButtonSize.medium:
        return 20;
      case CustomButtonSize.large:
        return 24;
    }
  }

  double get _spinnerSize {
    switch (size) {
      case CustomButtonSize.small:
        return 16;
      case CustomButtonSize.medium:
        return 20;
      case CustomButtonSize.large:
        return 24;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isEnabled = !isDisabled && !isLoading && onPressed != null;

    // Couleurs selon le theme et la variante
    final primaryColor = isDark ? AppColors.primaryLight : AppColors.primary;
    final onPrimaryColor =
        isDark ? AppColors.textInverseDark : AppColors.textInverse;
    final disabledBg = isDark ? AppColors.borderDark : AppColors.border;
    final disabledFg =
        isDark ? AppColors.textDisabledDark : AppColors.textDisabled;

    Widget buttonChild = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          IconTheme(
            data: IconThemeData(size: _iconSize),
            child: icon!,
          ),
          SizedBox(width: AppSpacing.spacing8),
        ],
        Text(
          label,
          style: TextStyle(
            fontSize: _fontSize,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );

    if (isLoading) {
      buttonChild = SizedBox(
        height: _spinnerSize,
        width: _spinnerSize,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            variant == CustomButtonVariant.primary
                ? onPrimaryColor
                : primaryColor,
          ),
        ),
      );
    }

    Widget button;

    switch (variant) {
      case CustomButtonVariant.primary:
        button = ElevatedButton(
          onPressed: isEnabled ? onPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: backgroundColor ?? primaryColor,
            foregroundColor: textColor ?? onPrimaryColor,
            disabledBackgroundColor: disabledBg,
            disabledForegroundColor: disabledFg,
            padding: _padding,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: AppSpacing.elevationSM,
          ),
          child: buttonChild,
        );
        break;

      case CustomButtonVariant.outlined:
        button = OutlinedButton(
          onPressed: isEnabled ? onPressed : null,
          style: OutlinedButton.styleFrom(
            foregroundColor: textColor ?? primaryColor,
            padding: _padding,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            side: BorderSide(
              color: isEnabled ? primaryColor : disabledBg,
              width: AppSpacing.borderWidthMedium,
            ),
          ),
          child: buttonChild,
        );
        break;

      case CustomButtonVariant.secondary:
        button = ElevatedButton(
          onPressed: isEnabled ? onPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor:
                isDark ? AppColors.surfaceElevatedDark : AppColors.surface,
            foregroundColor: textColor ?? primaryColor,
            disabledBackgroundColor: disabledBg,
            disabledForegroundColor: disabledFg,
            padding: _padding,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: isDark ? AppColors.borderDark : AppColors.border,
                width: 1,
              ),
            ),
            elevation: 0,
          ),
          child: buttonChild,
        );
        break;

      case CustomButtonVariant.tertiary:
        button = TextButton(
          onPressed: isEnabled ? onPressed : null,
          style: TextButton.styleFrom(
            foregroundColor: textColor ?? primaryColor,
            padding: _padding,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: buttonChild,
        );
        break;
    }

    if (width != null) {
      return SizedBox(width: width, child: button);
    }

    return button;
  }
}
