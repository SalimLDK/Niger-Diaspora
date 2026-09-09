import 'package:flutter/material.dart';

import '../../../../core/theme/adaptive_colors.dart';

/// Ce qu'une bulle affiche quand son texte n'a JAMAIS pu être lu sur cet
/// appareil, et qu'aucune copie claire ne dort dans le cache local.
///
/// **Pourquoi une bulle plutôt que le marqueur brut.** La couche crypto pose
/// un marqueur technique — `[Message illisible]`, `🔐 Message chiffré`,
/// `[🔐 E2EE — session requise]` — utile aux gardes internes, jamais destiné à
/// être lu. Affiché tel quel, il apprend à l'utilisateur un vocabulaire qui
/// n'est pas le sien et ne dit rien d'actionnable.
///
/// **Pourquoi aucun bouton.** Trois causes mènent ici, dont une seule est
/// réparable depuis la bulle. Un bouton qui échoue deux fois sur trois coûte
/// plus cher qu'un bouton absent — et le bandeau en tête de discussion
/// (`_buildE2eeRestoreBanner`) porte déjà le remède, une fois, au bon endroit,
/// au lieu de le répéter sur chaque bulle du fil.
class UndecryptableMessageBubble extends StatelessWidget {
  const UndecryptableMessageBubble({super.key});

  @override
  Widget build(BuildContext context) {
    final couleur = context.textTertiaryColor;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.visibility_off_outlined,
            size: 14,
            color: context.iconTertiaryColor,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Message indisponible sur cet appareil',
              style: TextStyle(
                fontSize: 13,
                color: couleur,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
