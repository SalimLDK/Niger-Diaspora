import 'package:diaspo_niger/core/theme/admin_colors.dart';
import 'package:diaspo_niger/features/admin/presentation/providers/admin_provider.dart';
import 'package:flutter/material.dart';

/// Copie du contenu au moment du signalement (texte, image, vidéo, fichier),
/// affichée dans la fiche d'un signalement : ce qui a été vu, même si le
/// contenu a été supprimé depuis.
///
/// [libelle] et [date] arrivent déjà localisés et mis en forme : le widget ne
/// dépend ni de la locale ni de l'écran qui l'héberge.
class ApercuContenuSignale extends StatelessWidget {
  const ApercuContenuSignale({
    super.key,
    required this.snapshot,
    required this.libelle,
    this.date,
  });

  final ContentSnapshotData snapshot;
  final String libelle;
  final String? date;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AdminColors.statusAmberBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AdminColors.statusAmber.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _icone(snapshot.contentType),
                size: 16,
                color: AdminColors.statusAmber,
              ),
              const SizedBox(width: 8),
              Text(
                libelle,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AdminColors.statusAmber,
                ),
              ),
              const Spacer(),
              if (date != null)
                Text(
                  date!,
                  style: TextStyle(
                    fontSize: 10,
                    color: AdminColors.statusAmber.withAlpha(180),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Image preview
          if (snapshot.imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                snapshot.imageUrl!,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 80,
                  color: AdminColors.statusGrayBg,
                  child: const Center(child: Icon(Icons.broken_image)),
                ),
              ),
            ),

          // Video placeholder
          if (snapshot.videoUrl != null && snapshot.imageUrl == null)
            Container(
              height: 80,
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Icon(Icons.play_circle_outline, size: 40, color: AdminColors.text2),
              ),
            ),

          // Text content
          if (snapshot.text != null && snapshot.text!.isNotEmpty) ...[
            if (snapshot.imageUrl != null || snapshot.videoUrl != null)
              const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                snapshot.text!,
                style: const TextStyle(fontSize: 13, color: AdminColors.text),
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],

          // File name
          if (snapshot.fileName != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.attach_file, size: 14, color: AdminColors.text2),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    snapshot.fileName!,
                    style: const TextStyle(fontSize: 12, color: AdminColors.text2),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static IconData _icone(String? contentType) {
    switch (contentType) {
      case 'text':
        return Icons.chat_bubble_outline;
      case 'image':
        return Icons.image_outlined;
      case 'video':
        return Icons.videocam_outlined;
      case 'file':
        return Icons.attach_file;
      case 'product':
        return Icons.shopping_bag_outlined;
      case 'user':
        return Icons.person_outline;
      case 'group':
        return Icons.group_outlined;
      default:
        return Icons.description_outlined;
    }
  }
}
