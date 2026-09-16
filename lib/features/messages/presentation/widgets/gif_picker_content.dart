import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/adaptive_colors.dart';
import '../../../../core/theme/design_kit.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../gifs/data/datasources/gif_remote_datasource.dart';
import '../../../gifs/domain/entities/gif_entity.dart';
import '../../../gifs/presentation/providers/gif_provider.dart';

/// Onglet « GIFs » du picker : recherche Tenor/Giphy, avec bascule entre les
/// GIFs classiques et les stickers (médias à fond transparent).
class GifPickerContent extends ConsumerStatefulWidget {
  final void Function(GifEntity gif) onGifSelected;

  const GifPickerContent({super.key, required this.onGifSelected});

  @override
  ConsumerState<GifPickerContent> createState() => _GifPickerContentState();
}

/// Largeur maximale d'une vignette de la grille, en dp.
const double _tailleVignette = 110;

class _GifPickerContentState extends ConsumerState<GifPickerContent> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final query = ref.watch(gifSearchQueryProvider);
    final type = ref.watch(gifContentTypeProvider);
    final resultsAsync = ref.watch(gifResultsProvider((query, type)));

    return Column(
      children: [
        // En-tête de section (fiche 26b : « des en-têtes, pas des sous-onglets »)
        // portant la bascule GIFs / stickers transparents — même fournisseur,
        // deux médias différents. La recherche, elle, vit dans la loupe de la
        // coque, et la note « données réduites » dans son pied.
        DesignSectionLabel(
          query.isEmpty ? l10n.trending : l10n.searchResults,
          color: context.repereColor,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          trailing: _buildTypeToggle(context, l10n, type),
        ),
        Expanded(
          child: resultsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, __) {
              // Une clé absente côté serveur est un état durable : le dire
              // autrement qu'une panne, et ne pas proposer de réessayer —
              // réessayer n'y changerait rien.
              final nonConfigure = error is GifProvidersUnavailableException;
              return _EmptyState(
                icon:
                    nonConfigure
                        ? Icons.key_off_outlined
                        : Icons.cloud_off_outlined,
                message:
                    nonConfigure
                        ? l10n.gifProviderNotConfigured
                        : l10n.gifLoadError,
                retryLabel: nonConfigure ? null : l10n.retry,
                onRetry:
                    nonConfigure
                        ? null
                        : () => ref.invalidate(
                          gifResultsProvider((query, type)),
                        ),
              );
            },
            data: (gifs) {
              if (gifs.isEmpty) {
                return _EmptyState(
                  icon: Icons.search_off_outlined,
                  message: l10n.gifNoResults,
                );
              }
              return _buildGrid(gifs);
            },
          ),
        ),
      ],
    );
  }

  /// Bascule GIFs / stickers transparents (même fournisseur).
  Widget _buildTypeToggle(
    BuildContext context,
    AppLocalizations l10n,
    GifContentType type,
  ) {
    return SegmentedButton<GifContentType>(
      segments: [
        ButtonSegment(value: GifContentType.gif, label: Text(l10n.gifs)),
        ButtonSegment(
          value: GifContentType.sticker,
          label: Text(l10n.stickers),
        ),
      ],
      selected: {type},
      showSelectedIcon: false,
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 11)),
      ),
      onSelectionChanged:
          (selection) =>
              ref.read(gifContentTypeProvider.notifier).state = selection.first,
    );
  }

  Widget _buildGrid(List<GifEntity> gifs) {
    // Décodage à la taille réellement affichée : une vignette fait ~110 dp de
    // large, le média d'origine bien plus. Sans cette borne, chaque image de
    // la grille occupe en mémoire sa taille de fichier décodée — et un GIF
    // décode *toutes* ses trames.
    final memCacheWidth =
        (_tailleVignette * MediaQuery.devicePixelRatioOf(context)).round();

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      // Colonnes déduites de la largeur (≈110 dp par vignette) : ~3-4 en
      // portrait, ~7-8 en paysage. Vignettes plus compactes = plus de GIFs
      // visibles d'un coup.
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: _tailleVignette,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
      ),
      itemCount: gifs.length,
      itemBuilder: (context, index) {
        final gif = gifs[index];
        return GestureDetector(
          onTap: () => widget.onGifSelected(gif),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: gif.previewUrl,
              fit: BoxFit.cover,
              memCacheWidth: memCacheWidth,
              placeholder: (_, __) => Container(
                color: context.surfaceVariantColor,
              ),
              errorWidget: (_, __, ___) => Container(
                color: context.surfaceVariantColor,
                child: Icon(
                  Icons.broken_image,
                  size: 20,
                  color: context.textSecondaryColor,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  /// Sans [onRetry], aucun bouton : proposer de recharger ce qui ne peut pas
  /// changer donne une porte qui ne mène nulle part.
  final String? retryLabel;
  final VoidCallback? onRetry;

  const _EmptyState({
    required this.icon,
    required this.message,
    this.retryLabel,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 40,
              color: context.textSecondaryColor.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.textSecondaryColor,
                fontSize: 13,
              ),
            ),
            if (onRetry != null && retryLabel != null) ...[
              const SizedBox(height: 8),
              TextButton(onPressed: onRetry, child: Text(retryLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
