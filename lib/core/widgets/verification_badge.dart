import 'package:flutter/material.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';

enum VerificationBadgeSize { small, normal }

/// Badge de certification affiché sur les profils vérifiés dans le chat.
/// Positionnez-le via un [Positioned] dans un [Stack] ou inline dans un [Row].
class VerificationBadge extends StatelessWidget {
  final VerificationBadgeSize size;

  const VerificationBadge({
    super.key,
    this.size = VerificationBadgeSize.normal,
  });

  @override
  Widget build(BuildContext context) {
    final double badgeSize = size == VerificationBadgeSize.small ? 14.0 : 18.0;
    final double iconSize = size == VerificationBadgeSize.small ? 9.0 : 12.0;

    return Container(
      width: badgeSize,
      height: badgeSize,
      decoration: BoxDecoration(
        color: const Color(0xFF1D9BF0),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Center(
        child: AppIcon(AppIcon.check,
          color: Colors.white,
          size: iconSize,
        ),
      ),
    );
  }
}
