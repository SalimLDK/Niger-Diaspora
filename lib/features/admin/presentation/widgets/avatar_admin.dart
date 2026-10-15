import 'package:diaspo_niger/core/theme/admin_colors.dart';
import 'package:flutter/material.dart';

/// Avatar d'une carte du panneau : la photo si elle charge, sinon l'initiale
/// sur fond dégradé.
///
/// La carte de l'écran Utilisateurs peignait la photo par `DecorationImage`
/// sans repli : quand le chargement échoue — CORS sur le web, lien mort —, la
/// pastille restait **blanche**, sans initiale ni rien (vu en ligne le
/// 2026-10-15 sur le compte de Mariam Kone). `errorBuilder` ramène l'initiale.
/// `WebHtmlElementStrategy.prefer` : voir le commentaire sur `Image.network`.
class AvatarAdmin extends StatelessWidget {
  const AvatarAdmin({
    super.key,
    required this.nom,
    this.photoUrl,
    this.taille = 48,
  });

  /// Nom, e-mail ou identifiant : sa première lettre sert d'initiale.
  final String? nom;
  final String? photoUrl;
  final double taille;

  /// Première lettre, en majuscule ; `U` quand il n'y a rien à lire.
  static String initiale(String? nom) {
    final texte = nom?.trim() ?? '';
    return texte.isEmpty ? 'U' : String.fromCharCode(texte.runes.first).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final rayon = BorderRadius.circular(12);
    final repli = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: rayon,
        gradient: const LinearGradient(
          colors: [AdminColors.actionBlue, AdminColors.actionBlueLight],
        ),
      ),
      child: Center(
        child: Text(
          initiale(nom),
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: taille * 0.375,
          ),
        ),
      ),
    );

    final url = photoUrl?.trim();
    return SizedBox(
      width: taille,
      height: taille,
      child: url == null || url.isEmpty
          ? repli
          : ClipRRect(
              borderRadius: rayon,
              child: Image.network(
                url,
                width: taille,
                height: taille,
                fit: BoxFit.cover,
                // Élément `<img>` plutôt que `fetch` : 205 des 224 photos sont
                // des adresses Firebase Storage à `token=` qui ne renvoient
                // AUCUN en-tête CORS ; CanvasKit les charge par `fetch` et les
                // refuse. Un `<img>` ne demande pas de CORS.
                webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                errorBuilder: (_, __, ___) => repli,
                loadingBuilder: (_, enfant, progression) =>
                    progression == null ? enfant : repli,
              ),
            ),
    );
  }
}
