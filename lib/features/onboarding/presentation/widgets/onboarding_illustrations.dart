import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/adaptive_colors.dart';

/// Illustrations des 5 écrans d'onboarding (maquettes 14a → 14e).
///
/// Compositions vectorielles (cercle teinté + pictogramme Material + pastilles
/// d'accent), pas des images bitmap : elles s'adaptent nativement au thème
/// sombre et à la couleur d'accent choisie par la personne (orange ou vert),
/// ce qu'un PNG figé ne peut pas faire.

/// Pastille décorative, cerclée de la couleur de fond de la carte pour se
/// détacher du cercle central.
class _IllustrationDot extends StatelessWidget {
  final double size;
  final Color color;
  final Color ringColor;

  const _IllustrationDot({
    required this.size,
    required this.color,
    required this.ringColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: ringColor, width: 3),
      ),
    );
  }
}

/// Badge circulaire plein (avatar, bulle) porté par certaines compositions.
class _IllustrationBadge extends StatelessWidget {
  final double size;
  final Color color;
  final Color ringColor;
  final IconData icon;
  final double iconSize;

  const _IllustrationBadge({
    required this.size,
    required this.color,
    required this.ringColor,
    required this.icon,
    required this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: ringColor, width: 4),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: iconSize, color: AppColors.white),
    );
  }
}

/// Fond commun à toutes les compositions : cercle teinté + pictogramme central.
class _IllustrationCore extends StatelessWidget {
  final IconData icon;
  final Color accent;

  const _IllustrationCore({required this.icon, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      height: 104,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 44, color: accent),
    );
  }
}

/// Écran 1 — « la diaspora » : globe entouré de pastilles de villes.
class WelcomeIllustration extends StatelessWidget {
  const WelcomeIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    final accent = context.adaptivePrimaryColor;
    final ring = context.surfaceVariantColor;
    return SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _IllustrationCore(icon: Icons.public_rounded, accent: accent),
          Positioned(
            top: 6,
            right: 14,
            child: _IllustrationDot(
              size: 20,
              color: context.goldColor,
              ringColor: ring,
            ),
          ),
          Positioned(
            bottom: 14,
            left: 2,
            child: _IllustrationDot(
              size: 16,
              color: context.identityColor,
              ringColor: ring,
            ),
          ),
          Positioned(
            bottom: 0,
            right: 32,
            child: _IllustrationDot(size: 12, color: accent, ringColor: ring),
          ),
        ],
      ),
    );
  }
}

/// Écran 2 — « carte des membres » : deux avatars superposés.
class MembersIllustration extends StatelessWidget {
  const MembersIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    final accent = context.adaptivePrimaryColor;
    final ring = context.surfaceVariantColor;
    return SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _IllustrationCore(
            icon: Icons.person_rounded,
            accent: context.identityColor,
          ),
          Positioned(
            top: 12,
            right: 6,
            child: _IllustrationBadge(
              size: 40,
              color: accent,
              ringColor: ring,
              icon: Icons.person_rounded,
              iconSize: 20,
            ),
          ),
          Positioned(
            bottom: 10,
            left: 8,
            child: _IllustrationDot(
              size: 16,
              color: context.goldColor,
              ringColor: ring,
            ),
          ),
        ],
      ),
    );
  }
}

/// Écran 3 — « rejoindre un groupe » : pictogramme groupe et pastilles
/// éparpillées, comme des membres qui se rassemblent.
class GroupsIllustration extends StatelessWidget {
  const GroupsIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    final accent = context.adaptivePrimaryColor;
    final ring = context.surfaceVariantColor;
    return SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _IllustrationCore(icon: Icons.groups_rounded, accent: accent),
          Positioned(
            top: 8,
            left: 14,
            child: _IllustrationDot(
              size: 14,
              color: context.identityColor,
              ringColor: ring,
            ),
          ),
          Positioned(
            top: 28,
            left: 0,
            child: _IllustrationDot(
              size: 10,
              color: context.goldColor,
              ringColor: ring,
            ),
          ),
          Positioned(
            bottom: 6,
            right: 16,
            child: _IllustrationDot(
              size: 18,
              color: context.goldColor,
              ringColor: ring,
            ),
          ),
        ],
      ),
    );
  }
}

/// Écran 4 — « fête de la République » : pictogramme événement et pastilles
/// aux couleurs du drapeau, fixes (indépendantes de la couleur d'accent
/// choisie par la personne, puisqu'elles représentent le drapeau).
class EventsIllustration extends StatelessWidget {
  const EventsIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    final ring = context.surfaceVariantColor;
    return SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _IllustrationCore(
            icon: Icons.event_rounded,
            accent: context.adaptivePrimaryColor,
          ),
          Positioned(
            top: 6,
            right: 22,
            child: _IllustrationDot(
              size: 14,
              color: AppColors.primary,
              ringColor: ring,
            ),
          ),
          Positioned(
            top: 22,
            right: 2,
            child: _IllustrationDot(
              size: 12,
              color: AppColors.white,
              ringColor: context.borderStrongColor,
            ),
          ),
          Positioned(
            bottom: 10,
            left: 14,
            child: _IllustrationDot(
              size: 16,
              color: AppColors.secondary,
              ringColor: ring,
            ),
          ),
        ],
      ),
    );
  }
}

/// Écran 5 — « rester connectés » : deux bulles de discussion superposées.
class ConnectedIllustration extends StatelessWidget {
  const ConnectedIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    final accent = context.adaptivePrimaryColor;
    final ring = context.surfaceVariantColor;
    return SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _IllustrationCore(icon: Icons.chat_bubble_rounded, accent: accent),
          Positioned(
            top: 16,
            left: 4,
            child: _IllustrationBadge(
              size: 34,
              color: context.identityColor,
              ringColor: ring,
              icon: Icons.chat_bubble_rounded,
              iconSize: 16,
            ),
          ),
          Positioned(
            bottom: 6,
            right: 22,
            child: _IllustrationDot(
              size: 16,
              color: context.goldColor,
              ringColor: ring,
            ),
          ),
        ],
      ),
    );
  }
}
