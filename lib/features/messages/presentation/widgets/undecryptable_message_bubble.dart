import 'package:flutter/material.dart';

import '../../../../core/services/e2ee/undecryptable_placeholders.dart';
import '../../../../core/theme/adaptive_colors.dart';

/// Le seul texte qu'on montre pour un message dont le contenu n'a pas pu être
/// lu : la bulle, l'aperçu de réponse et la citation le partagent.
const String kLibelleMessageIndisponible =
    'Message indisponible sur cet appareil';

/// Ce qu'une **citation** (ou le bandeau « répondre à ») doit afficher pour un
/// message texte : le contenu, sauf s'il est vide ou n'est que le marqueur
/// technique de la couche crypto.
///
/// Vu sur appareil le 2026-10-16 : répondre à un message illisible recopiait
/// `[🔐 E2EE — session requise]` dans la citation, tel quel, dans la bulle de
/// la réponse — alors que le message cité s'affichait proprement en bulle
/// « indisponible » au-dessus.
String contenuCitationAffichable(String content) =>
    isUndecryptableContent(content) ? kLibelleMessageIndisponible : content;

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
              kLibelleMessageIndisponible,
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
