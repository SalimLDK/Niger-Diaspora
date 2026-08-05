import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/adaptive_colors.dart';
import '../../../../core/theme/design_kit.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../stickers/domain/entities/sticker_entity.dart';
import '../../../stickers/domain/entities/sticker_pack_entity.dart';
import '../../../stickers/presentation/providers/sticker_provider.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';

/// Contenu de l'onglet Stickers du composeur (fiche 26b).
///
/// Un seul défilement, des **sections à en-tête** — « RÉCEMMENT UTILISÉS »,
/// « FAVORIS », puis un en-tête par pack. Auparavant chaque groupe était un
/// sous-onglet iconique (horloge, cœur, vignette de pack) : trois barres
/// d'onglets empilées dans un panneau qui fait 200 dp de haut.
class StickerPickerContent extends ConsumerWidget {
  final void Function(StickerEntity sticker) onStickerSelected;

  /// Filtre saisi dans la loupe de la coque. Les packs de l'utilisateur sont
  /// déjà tous en mémoire (une seule requête) : le filtre est local, il n'y a
  /// pas de recherche serveur pour les stickers.
  final String query;

  const StickerPickerContent({
    super.key,
    required this.onStickerSelected,
    this.query = '',
  });

  /// Un sticker correspond s'il porte l'emoji cherché, ou si son pack en porte
  /// le nom : `StickerEntity.emoji` est souvent vide en base, le nom du pack
  /// est le seul repli qui remonte quelque chose.
  bool _matches(StickerEntity sticker, String packName) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    return (sticker.emoji?.toLowerCase().contains(q) ?? false) ||
        packName.toLowerCase().contains(q);
  }

  List<StickerEntity> _filter(List<StickerEntity> stickers, String packName) =>
      stickers.where((s) => _matches(s, packName)).toList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final packsAsync = ref.watch(allUserPacksProvider);
    final recentsAsync = ref.watch(recentStickersProvider);
    final favoritesAsync = ref.watch(favoriteStickersProvider);

    if (packsAsync.isLoading && !packsAsync.hasValue) {
      return const Center(child: CircularProgressIndicator());
    }
    if (packsAsync.hasError && !packsAsync.hasValue) {
      return _message(context, l10n.errorLoadingStickers);
    }

    final packs = packsAsync.valueOrNull ?? const <StickerPackEntity>[];
    // Les récents et les favoris viennent de plusieurs packs : on ne peut pas
    // leur attacher un nom de pack, seul l'emoji les filtre.
    final recents = _filter(recentsAsync.valueOrNull ?? const [], '');
    final favorites = _filter(favoritesAsync.valueOrNull ?? const [], '');

    final sections = <_Section>[
      if (recents.isNotEmpty) _Section(l10n.stickerRecentlyUsed, recents),
      if (favorites.isNotEmpty) _Section(l10n.favorites, favorites),
      for (final pack in packs)
        if (_filter(pack.stickers, pack.name).isNotEmpty)
          _Section(pack.name, _filter(pack.stickers, pack.name)),
    ];

    if (sections.isEmpty) {
      return _message(
        context,
        query.isEmpty
            ? l10n.noRecentStickers
            : l10n.searchNoResultsFor(query),
      );
    }

    return CustomScrollView(
      slivers: [
        for (var i = 0; i < sections.length; i++) ...[
          SliverToBoxAdapter(
            child: DesignSectionLabel(
              sections[i].title,
              color: context.repereColor,
              padding: EdgeInsets.fromLTRB(12, i == 0 ? 8 : 12, 12, 6),
            ),
          ),
          _grid(context, sections[i].stickers),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
      ],
    );
  }

  /// Fiche 26b : 4 colonnes à la largeur de référence (390 dp), tuiles carrées
  /// rayon 14, gouttière 8. Le compte est déduit de la largeur plutôt que figé
  /// à 4 : en paysage, 4 colonnes donneraient des tuiles de ~180 dp.
  Widget _grid(BuildContext context, List<StickerEntity> stickers) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          final colonnes =
              ((constraints.crossAxisExtent + 8) / 93).floor().clamp(4, 12);
          return SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: colonnes,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _tile(context, stickers[index]),
              childCount: stickers.length,
            ),
          );
        },
      ),
    );
  }

  Widget _tile(BuildContext context, StickerEntity sticker) {
    return GestureDetector(
      onTap: () => onStickerSelected(sticker),
      onLongPress: () => _showStickerOptions(context, sticker),
      child: Container(
        decoration: BoxDecoration(
          // La fiche donne un fond de tuile visible ; les stickers flottaient
          // jusqu'ici sur le fond du panneau.
          color: context.surfaceVariantColor,
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.all(4),
        child: CachedNetworkImage(
          imageUrl: sticker.url,
          fit: BoxFit.contain,
          placeholder: (_, __) => const SizedBox.shrink(),
          errorWidget:
              (_, __, ___) => Icon(
                Icons.broken_image,
                color: context.textTertiaryColor,
                size: 20,
              ),
        ),
      ),
    );
  }

  Widget _message(BuildContext context, String texte) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          texte,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: context.textSecondaryColor),
        ),
      ),
    );
  }

  void _showStickerOptions(BuildContext context, StickerEntity sticker) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (sheetContext) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 100,
                    height: 100,
                    child: CachedNetworkImage(
                      imageUrl: sticker.url,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: AppIcon(
                      AppIcon.send,
                      color: Theme.of(sheetContext).iconTheme.color!,
                    ),
                    title: Text(l10n.send),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      onStickerSelected(sticker);
                    },
                  ),
                  Consumer(
                    builder:
                        (context, ref, _) => ListTile(
                          leading: AppIcon(
                            AppIcon.heart,
                            color: Theme.of(sheetContext).iconTheme.color!,
                          ),
                          title: Text(l10n.addToFavorites),
                          onTap: () {
                            ref
                                .read(stickerActionsProvider.notifier)
                                .toggleFavorite(sticker);
                            Navigator.pop(sheetContext);
                          },
                        ),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}

class _Section {
  final String title;
  final List<StickerEntity> stickers;

  const _Section(this.title, this.stickers);
}
