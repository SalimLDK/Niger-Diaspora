import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/adaptive_colors.dart';
import '../../domain/entities/message_entity.dart';
import '../providers/media_dechiffre_provider.dart';
import 'blurhash_image.dart';

/// Rend un média chiffré lisible par les bulles existantes.
///
/// Les bulles image, document et audio lisent `message.fileUrl`. Pour un
/// média chiffré, cette URL pointe sur un blob illisible. La barrière
/// télécharge et déchiffre le fichier (une fois, via le cache), puis rappelle
/// [builder] avec une copie du message dont `fileUrl` est `file://<chemin>`
/// — la forme que ces bulles savent déjà afficher pour un envoi en cours.
///
/// Un message sans média chiffré passe tel quel : aucun coût sur l'existant.
class MediaChiffreGate extends ConsumerWidget {
  final MessageEntity message;
  final Widget Function(BuildContext context, MessageEntity resolu) builder;

  /// Rapport largeur/hauteur du gabarit d'attente, pour que la bulle ne
  /// saute pas quand l'image arrive.
  final double aspectRatio;

  const MediaChiffreGate({
    super.key,
    required this.message,
    required this.builder,
    this.aspectRatio = 1.5,
  });

  /// Forme locale d'un [MessageEntity] dont le média est déjà sur disque.
  static MessageEntity resolu(MessageEntity message, String chemin) =>
      message.copyWith(fileUrl: 'file://$chemin', mediaExpired: false);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = message.mediaChiffre;
    if (media == null) return builder(context, message);

    final demande = DemandeMediaDechiffre(message.id, media);
    final etat = ref.watch(mediaDechiffreProvider(demande));

    return etat.when(
      data: (chemin) => builder(context, resolu(message, chemin)),
      loading: () => _Gabarit(
        aspectRatio: aspectRatio,
        blurhash: message.blurhash,
        child: const SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
      error: (_, __) => _Gabarit(
        aspectRatio: aspectRatio,
        blurhash: message.blurhash,
        child: InkWell(
          onTap: () => ref.invalidate(mediaDechiffreProvider(demande)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, color: context.textTertiaryColor),
              const SizedBox(height: 6),
              Text(
                'Média chiffré illisible — appuyer pour réessayer',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.textTertiaryColor, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Gabarit extends StatelessWidget {
  final double aspectRatio;
  final String? blurhash;
  final Widget child;

  const _Gabarit({
    required this.aspectRatio,
    required this.blurhash,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (blurhash != null && blurhash!.isNotEmpty)
              BlurhashImage(blurhash: blurhash!)
            else
              ColoredBox(color: context.surfaceVariantColor),
            Center(child: Padding(padding: const EdgeInsets.all(12), child: child)),
          ],
        ),
      ),
    );
  }
}
