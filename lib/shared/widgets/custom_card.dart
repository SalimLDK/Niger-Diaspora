import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_shadows.dart';

/// Carte personnalisee avec support du theme et des shadows premium
class CustomCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final bool showBorder;
  final bool elevated;

  const CustomCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.borderRadius,
    this.backgroundColor,
    this.showBorder = false,
    this.elevated = true,
  });

  /// Carte simple sans elevation
  const CustomCard.flat({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.borderRadius,
    this.backgroundColor,
    this.showBorder = true,
  }) : elevated = false;

  /// Carte avec elevation prononcee
  const CustomCard.elevated({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.borderRadius,
    this.backgroundColor,
    this.showBorder = false,
  }) : elevated = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Couleurs selon le theme
    final bgColor = backgroundColor ??
        (isDark ? AppColors.surfaceDark : AppColors.surface);
    final borderColor = isDark ? AppColors.borderDark : AppColors.border;

    // Shadows
    final shadows = elevated
        ? (isDark ? AppShadows.shadowMediumDark : AppShadows.shadowMedium)
        : null;

    // Border
    final border = (showBorder || isDark)
        ? Border.all(color: borderColor, width: 1)
        : null;

    Widget cardContent = Container(
      padding: padding ?? AppSpacing.cardPadding,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: borderRadius ?? AppSpacing.borderRadiusLG,
        border: border,
        boxShadow: shadows,
      ),
      child: child,
    );

    if (onTap != null) {
      cardContent = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius ?? AppSpacing.borderRadiusLG,
          child: cardContent,
        ),
      );
    }

    if (margin != null) {
      return Padding(padding: margin!, child: cardContent);
    }

    return cardContent;
  }
}

/// Carte de statistique avec icone, valeur et label
class StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color? iconColor;
  final Color? iconBackgroundColor;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.iconColor,
    this.iconBackgroundColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final defaultIconColor = isDark ? AppColors.primaryLight : AppColors.primary;
    final defaultIconBg = isDark
        ? AppColors.primaryLight.withValues(alpha: 0.15)
        : AppColors.primaryLighter;

    return CustomCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.spacing12),
            decoration: BoxDecoration(
              color: iconBackgroundColor ?? defaultIconBg,
              borderRadius: AppSpacing.borderRadiusMD,
            ),
            child: Icon(
              icon,
              color: iconColor ?? defaultIconColor,
              size: AppSpacing.iconSizeLG,
            ),
          ),
          const SizedBox(width: AppSpacing.spacing16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.spacing4),
                Text(
                  label,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte de membre/profil avec avatar
class MemberCard extends StatelessWidget {
  final String name;
  final String? subtitle;
  final String? avatarUrl;
  final Widget? trailing;
  final VoidCallback? onTap;
  final double avatarSize;

  const MemberCard({
    super.key,
    required this.name,
    this.subtitle,
    this.avatarUrl,
    this.trailing,
    this.onTap,
    this.avatarSize = AppSpacing.avatarSizeMD,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return CustomCard(
      onTap: onTap,
      child: Row(
        children: [
          // Avatar
          Container(
            width: avatarSize,
            height: avatarSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? AppColors.borderDark : AppColors.border,
              image: avatarUrl != null
                  ? DecorationImage(
                      image: NetworkImage(avatarUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: avatarUrl == null
                ? Icon(
                    Icons.person_rounded,
                    color: isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiary,
                    size: avatarSize * 0.5,
                  )
                : null,
          ),
          const SizedBox(width: AppSpacing.spacing12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: theme.textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.spacing4),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          // Trailing
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.spacing12),
            trailing!,
          ],
        ],
      ),
    );
  }
}
