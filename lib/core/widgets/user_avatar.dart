import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../theme/adaptive_colors.dart';

/// Shape of the avatar
enum AvatarShape { circle, roundedSquare }

/// A reusable avatar widget that displays user photo or initials as fallback
class UserAvatar extends StatelessWidget {
  /// The URL of the user's photo (can be null)
  final String? photoUrl;

  /// The display name to extract initials from
  final String? displayName;

  /// Size of the avatar (width and height)
  final double size;

  /// Shape of the avatar
  final AvatarShape shape;

  /// Border radius for rounded square shape (ignored for circle)
  final double borderRadius;

  /// Font size for initials (auto-calculated if null)
  final double? fontSize;

  /// Whether to use gradient background (otherwise uses solid color)
  final bool useGradient;

  /// Background color when not using gradient
  final Color? backgroundColor;

  /// Text color for initials
  final Color? textColor;

  /// Icon to show when no name is available
  final IconData fallbackIcon;

  /// Optional child widget to overlay (e.g., online status indicator)
  final Widget? overlay;

  const UserAvatar({
    super.key,
    this.photoUrl,
    this.displayName,
    this.size = 48,
    this.shape = AvatarShape.circle,
    this.borderRadius = 16,
    this.fontSize,
    this.useGradient = true,
    this.backgroundColor,
    this.textColor,
    this.fallbackIcon = Icons.person,
    this.overlay,
  });

  /// Extract initials from display name
  String _getInitials(String? name) {
    if (name == null || name.trim().isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  BorderRadius _getBorderRadius() {
    return shape == AvatarShape.circle
        ? BorderRadius.circular(size / 2)
        : BorderRadius.circular(borderRadius);
  }

  @override
  Widget build(BuildContext context) {
    final initials = _getInitials(displayName);
    final calculatedFontSize = fontSize ?? (size * 0.4);
    final hasValidPhoto = photoUrl != null && photoUrl!.isNotEmpty;

    Widget avatarContent;

    if (hasValidPhoto) {
      avatarContent = CachedNetworkImage(
        imageUrl: photoUrl!,
        fit: BoxFit.cover,
        width: size,
        height: size,
        placeholder: (_, __) => _buildPlaceholder(context, initials, calculatedFontSize),
        errorWidget: (_, __, ___) => _buildPlaceholder(context, initials, calculatedFontSize),
      );
    } else {
      avatarContent = _buildPlaceholder(context, initials, calculatedFontSize);
    }

    Widget avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: useGradient ? context.adaptivePrimaryGradient : null,
        color: useGradient ? null : (backgroundColor ?? context.adaptivePrimaryColor),
        borderRadius: _getBorderRadius(),
      ),
      child: ClipRRect(
        borderRadius: _getBorderRadius(),
        child: avatarContent,
      ),
    );

    if (overlay != null) {
      avatar = Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          overlay!,
        ],
      );
    }

    return avatar;
  }

  Widget _buildPlaceholder(BuildContext context, String initials, double fontSize) {
    final color = textColor ?? AppColors.white;

    // If we have a name, show initials
    if (displayName != null && displayName!.trim().isNotEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: useGradient ? context.adaptivePrimaryGradient : null,
          color: useGradient ? null : (backgroundColor ?? context.adaptivePrimaryColor),
          borderRadius: _getBorderRadius(),
        ),
        child: Center(
          child: Text(
            initials,
            style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    // No name available, show icon
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: useGradient ? context.adaptivePrimaryGradient : null,
        color: useGradient ? null : (backgroundColor ?? context.adaptivePrimaryColor),
        borderRadius: _getBorderRadius(),
      ),
      child: Center(
        child: Icon(
          fallbackIcon,
          color: color,
          size: size * 0.5,
        ),
      ),
    );
  }
}
