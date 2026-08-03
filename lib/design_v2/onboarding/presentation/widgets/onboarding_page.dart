import 'package:flutter/material.dart';

import '../../../kit/design_kit.dart';

/// Contenu d'un écran d'onboarding (maquettes 14a → 14e).
///
/// Les maquettes ont abandonné le grand pictogramme centré et le texte
/// centré : chaque écran est désormais un bloc d'illustration en haut, puis
/// un titre serif aligné à gauche, une promesse, et deux puces de réassurance.
class OnboardingPageData {
  /// Surtitre en petites capitales (« NIAMEY · PARIS · … »), écran 1 seulement.
  final String? eyebrow;

  /// Titre, coupé manuellement pour reproduire la césure des maquettes.
  final String title;

  final String description;

  /// Légende de l'emplacement d'illustration.
  final String illustrationCaption;

  /// Pictogramme de l'emplacement, ignoré si [brandMark] est vrai.
  final IconData? icon;

  /// Écran de bienvenue : pastille de marque au lieu du pictogramme.
  final bool brandMark;

  /// Puces de réassurance sous la promesse (aucune sur le 1er et le dernier).
  final List<String> bullets;

  const OnboardingPageData({
    required this.title,
    required this.description,
    required this.illustrationCaption,
    this.eyebrow,
    this.icon,
    this.brandMark = false,
    this.bullets = const [],
  });
}

class OnboardingPage extends StatelessWidget {
  final OnboardingPageData data;

  /// Bloc libre affiché à la place des puces (carte d'autorisations du
  /// dernier écran).
  final Widget? footer;

  const OnboardingPage({super.key, required this.data, this.footer});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DesignIllustration(
            caption: data.illustrationCaption,
            icon: data.icon,
            brandMark: data.brandMark,
          ),
          const SizedBox(height: 28),
          if (data.eyebrow != null) ...[
            DesignEyebrow(data.eyebrow!),
            const SizedBox(height: 12),
          ],
          DesignTitle(data.title, size: 30),
          const SizedBox(height: 12),
          DesignBody(data.description),
          if (data.bullets.isNotEmpty) ...[
            const SizedBox(height: 20),
            ...data.bullets.map(DesignCheckBullet.new),
          ],
          if (footer != null) ...[const SizedBox(height: 20), footer!],
        ],
      ),
    );
  }
}
