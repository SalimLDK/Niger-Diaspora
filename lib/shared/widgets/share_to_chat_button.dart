import 'package:flutter/material.dart';

/// Bouton plein « Envoyer dans une discussion » des fiches de partage du profil
/// et du groupe. Seule la couleur diffère d'une fiche à l'autre.
///
/// Le libellé reste sur **une** ligne, quelle que soit l'échelle de police : à
/// 1,3 (le réglage du Pixel), « Envoyer dans une discussion » ne tient plus
/// entre l'icône et le bord et passait sur deux lignes, l'icône collée à gauche.
/// Il rétrécit pour tenir.
///
/// La marge horizontale n'était pas posée du tout (`padding` ne donnait que le
/// vertical, ce qui remplace la marge par défaut du bouton) : l'icône touchait le
/// bord. Elle est de 16 dp.
class ShareToChatButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const ShareToChatButton({
    super.key,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.forum_rounded, color: Colors.white),
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
