import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/adaptive_colors.dart';
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

class _GifPickerContentState extends ConsumerState<GifPickerContent> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Sans clé API, l'onglet n'a aucun contenu à montrer : on le dit clairement
    // plutôt que d'afficher une erreur réseau opaque.
    if (!ref.watch(isGifConfiguredProvider)) {
      return _EmptyState(
        icon: Icons.key_off_outlined,
        message: l10n.gifProviderNotConfigured,
      );
    }

    final query = ref.watch(gifSearchQueryProvider);
    final type = ref.watch(gifContentTypeProvider);
    final resultsAsync = ref.watch(gifResultsProvider((query, type)));

    return Column(
      children: [
        _buildToolbar(context, l10n, type),
        Expanded(
          child: resultsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => _EmptyState(
              icon: Icons.cloud_off_outlined,
              message: l10n.gifLoadError,
            ),
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

  Widget _buildToolbar(
    BuildContext context,
    AppLocalizations l10n,
    GifContentType type,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 38,
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: l10n.searchGifs,
                  prefixIcon: const Icon(Icons.search, size: 18),
                  filled: true,
                  fillColor: context.surfaceVariantColor,
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(19),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (value) =>
                    ref.read(gifSearchQueryProvider.notifier).state = value,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Bascule GIFs / stickers transparents (même fournisseur).
          SegmentedButton<GifContentType>(
            segments: [
              ButtonSegment(
                value: GifContentType.gif,
                label: Text(l10n.gifs),
              ),
              ButtonSegment(
                value: GifContentType.sticker,
                label: Text(l10n.stickers),
              ),
            ],
            selected: {type},
            showSelectedIcon: false,
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12)),
            ),
            onSelectionChanged: (selection) =>
                ref.read(gifContentTypeProvider.notifier).state =
                    selection.first,
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(List<GifEntity> gifs) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      // Colonnes déduites de la largeur (≈110 dp par vignette) : ~3-4 en
      // portrait, ~7-8 en paysage. Vignettes plus compactes = plus de GIFs
      // visibles d'un coup.
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 110,
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

  const _EmptyState({required this.icon, required this.message});

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
          ],
        ),
      ),
    );
  }
}
