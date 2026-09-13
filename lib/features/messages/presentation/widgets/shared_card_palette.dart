import 'package:flutter/material.dart';

import '../../../../core/theme/adaptive_colors.dart';

/// Couleurs des cartes posées dans une bulle (post partagé, événement).
///
/// Les deux cartes portaient chacune un accent en dur — sarcelle pour le
/// post, violet pour l'événement — posé tel quel sur la bulle envoyée
/// `#009600` : le nom de l'auteur, « Voir la publication → » et
/// « Voir l'événement → » y étaient quasi invisibles (constaté sur le Pixel
/// le 2026-09-12). Et un voile blanc à 15 % éclaircissait le vert sous un
/// texte blanc, ce qui dégradait encore le contraste.
///
/// Sur une bulle envoyée : texte blanc sur un voile SOMBRE. Sur une bulle
/// reçue : l'accent du thème, qui suit le clair et le sombre.
class SharedCardPalette {
  final Color accent;
  final Color title;
  final Color body;
  final BoxDecoration decoration;

  const SharedCardPalette._({
    required this.accent,
    required this.title,
    required this.body,
    required this.decoration,
  });

  factory SharedCardPalette.of(BuildContext context, {required bool isMe}) {
    if (isMe) {
      return SharedCardPalette._(
        accent: Colors.white,
        title: Colors.white,
        body: Colors.white.withValues(alpha: 0.9),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
        ),
      );
    }
    return SharedCardPalette._(
      accent: context.adaptivePrimaryColor,
      title: context.textPrimaryColor,
      body: context.textSecondaryColor,
      decoration: BoxDecoration(
        color: context.isDarkMode
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.borderColor),
      ),
    );
  }
}
