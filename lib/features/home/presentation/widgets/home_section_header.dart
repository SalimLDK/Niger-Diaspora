import 'package:flutter/material.dart';
import '../../../../core/theme/adaptive_colors.dart';

class HomeSectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onSeeAll;
  final String seeAllText;

  const HomeSectionHeader({
    super.key,
    required this.title,
    required this.onSeeAll,
    required this.seeAllText,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: context.textPrimaryColor,
          ),
        ),
        // Lien texte simple, aligné sur la maquette (plus de pastille ni de
        // chevron — refonte accueil).
        GestureDetector(
          onTap: onSeeAll,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Text(
              seeAllText,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.adaptivePrimaryColor,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
