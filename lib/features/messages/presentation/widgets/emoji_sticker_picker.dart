import 'dart:io';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart' as emoji_picker;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/adaptive_colors.dart';
import '../../../../core/theme/design_kit.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../gifs/domain/entities/gif_entity.dart';
import '../../../gifs/presentation/providers/gif_provider.dart';
import '../../../stickers/domain/entities/sticker_entity.dart';
import '../../../stickers/presentation/providers/sticker_provider.dart';
import 'gif_picker_content.dart';
import 'sticker_picker_content.dart';

/// Onglets du panneau, **dans l'ordre d'affichage de la fiche 26b**.
///
/// Une énumération et non un index : le nombre d'onglets change de façon
/// asynchrone (l'onglet Stickers n'apparaît qu'une fois les packs chargés).
/// Avec un index, son arrivée en tête décalerait silencieusement la sélection —
/// et le bouton emoji du composeur, qui demandait « l'onglet 0 », ouvrirait les
/// stickers.
enum MessagePickerTab { stickers, gif, emojis }

/// Le chrome (barre d'onglets + ligne d'info) se resserre sous ce seuil.
///
/// En paysage le panneau tombe à ~160 dp : la fiche empile une barre de 48 et
/// un pied de 50, il ne resterait que 62 dp de contenu. Fonction pure pour
/// être testable sans monter de widget, comme `computeMessagePickerHeight`.
bool pickerUsesCompactChrome(double height) => height < 190;

/// Panneau emojis / GIFs / stickers du composeur (fiche 26b).
class EmojiStickerPicker extends ConsumerStatefulWidget {
  /// Callback when an emoji is selected
  final void Function(emoji_picker.Category? category, emoji_picker.Emoji emoji)
      onEmojiSelected;

  /// Callback when backspace is pressed
  final VoidCallback? onBackspacePressed;

  /// Callback when a sticker is selected
  final void Function(StickerEntity sticker)? onStickerSelected;

  /// Callback when a GIF (or Tenor/Giphy sticker) is selected
  final void Function(GifEntity gif)? onGifSelected;

  /// Callback when the picker should be closed
  final VoidCallback? onClose;

  /// Height of the picker
  final double height;

  /// Onglet ouvert au montage, s'il est disponible.
  final MessagePickerTab initialTab;

  const EmojiStickerPicker({
    super.key,
    required this.onEmojiSelected,
    this.onBackspacePressed,
    this.onStickerSelected,
    this.onGifSelected,
    this.onClose,
    this.height = 300,
    this.initialTab = MessagePickerTab.emojis,
  });

  @override
  ConsumerState<EmojiStickerPicker> createState() => _EmojiStickerPickerState();
}

class _EmojiStickerPickerState extends ConsumerState<EmojiStickerPicker> {
  late MessagePickerTab _tab = widget.initialTab;

  /// Onglets déjà ouverts : les autres ne sont pas construits, pour ne pas
  /// lancer un `trending` Tenor/Giphy chez quelqu'un qui n'ouvre jamais l'onglet.
  late final Set<MessagePickerTab> _visited = {widget.initialTab};

  bool _searchOpen = false;
  final TextEditingController _searchController = TextEditingController();
  String _stickerQuery = '';

  /// Ouvre la vue de recherche interne du paquet emoji (elle est plein cadre,
  /// avec son propre bouton retour : une seconde barre dans la coque se
  /// désynchroniserait de celle-là).
  VoidCallback? _showEmojiSearch;

  /// Capturé tant que le contexte est vivant : lire le `ProviderScope` depuis
  /// `dispose()` remonte un arbre déjà désactivé.
  ProviderContainer? _container;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _container = ProviderScope.containerOf(context, listen: false);
  }

  @override
  void dispose() {
    _searchController.dispose();
    // Le filtre GIF est un provider global : sans remise à zéro, la requête
    // d'une conversation ressortirait dans la suivante.
    _resetGifQuery();
    super.dispose();
  }

  void _resetGifQuery() {
    _container?.read(gifSearchQueryProvider.notifier).state = '';
  }

  bool get _hasGifs => widget.onGifSelected != null;

  @override
  Widget build(BuildContext context) {
    final hasStickers =
        widget.onStickerSelected != null &&
        (ref.watch(allUserPacksProvider).valueOrNull?.isNotEmpty ?? false);

    final onglets = <MessagePickerTab>[
      if (hasStickers) MessagePickerTab.stickers,
      if (_hasGifs) MessagePickerTab.gif,
      MessagePickerTab.emojis,
    ];
    // Jamais de setState en build : l'onglet demandé peut ne pas (encore)
    // exister, on retombe sur le premier disponible sans toucher à l'état.
    final actif = onglets.contains(_tab) ? _tab : onglets.first;
    final compact = pickerUsesCompactChrome(widget.height);

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: context.surfaceColor,
        border: Border(
          top: BorderSide(color: context.borderColor, width: 0.5),
        ),
      ),
      child: Column(
        children: [
          _header(context, onglets, actif, compact),
          Expanded(child: _body(context, actif)),
          if (!compact) _infoLine(context, actif),
        ],
      ),
    );
  }

  // ── Barre d'onglets ───────────────────────────────────────────────────────

  Widget _header(
    BuildContext context,
    List<MessagePickerTab> onglets,
    MessagePickerTab actif,
    bool compact,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final padding =
        compact
            ? const EdgeInsets.fromLTRB(12, 6, 12, 2)
            : const EdgeInsets.fromLTRB(12, 10, 12, 4);

    if (_searchOpen) {
      return Padding(padding: padding, child: _searchRow(context, actif));
    }

    return Padding(
      padding: padding,
      child: Row(
        children: [
          for (final onglet in onglets) ...[
            DesignFilterChip(
              label: _label(l10n, onglet),
              selected: onglet == actif,
              compact: true,
              onTap: () => _select(onglet),
            ),
            const SizedBox(width: 8),
          ],
          const Spacer(),
          _roundButton(
            context,
            icon: Icons.search,
            tooltip: l10n.searchTitle,
            size: compact ? 30 : 34,
            onTap: () => _openSearch(actif),
          ),
          if (widget.onClose != null) ...[
            const SizedBox(width: 8),
            _roundButton(
              context,
              icon: Icons.keyboard_rounded,
              tooltip: l10n.showKeyboard,
              size: compact ? 30 : 34,
              onTap: widget.onClose!,
            ),
          ],
        ],
      ),
    );
  }

  String _label(AppLocalizations l10n, MessagePickerTab onglet) {
    switch (onglet) {
      case MessagePickerTab.stickers:
        return l10n.stickers;
      case MessagePickerTab.gif:
        // La fiche écrit « GIF » au singulier sur la pilule.
        return 'GIF';
      case MessagePickerTab.emojis:
        return l10n.emojis;
    }
  }

  Widget _roundButton(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required double size,
    required VoidCallback onTap,
  }) {
    return Material(
      color: context.surfaceVariantColor,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, size: 17, color: context.textSecondaryColor),
          ),
        ),
      ),
    );
  }

  Widget _searchRow(BuildContext context, MessagePickerTab actif) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 34,
            child: TextField(
              controller: _searchController,
              autofocus: true,
              textInputAction: TextInputAction.search,
              style: const TextStyle(fontSize: 13.5),
              decoration: InputDecoration(
                isDense: true,
                hintText:
                    actif == MessagePickerTab.gif
                        ? l10n.searchGifs
                        : l10n.searchStickers,
                prefixIcon: const Icon(Icons.search, size: 17),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 34,
                  minHeight: 34,
                ),
                filled: true,
                fillColor: context.surfaceVariantColor,
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(17),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) => _onQueryChanged(actif, value),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _roundButton(
          context,
          icon: Icons.close,
          tooltip: l10n.cancel,
          size: 34,
          onTap: _closeSearch,
        ),
      ],
    );
  }

  // ── Corps ─────────────────────────────────────────────────────────────────

  Widget _body(BuildContext context, MessagePickerTab actif) {
    // IndexedStack et non TabBarView : la fiche pose des pilules, pas des
    // onglets balayables, et une vue paginée qui contient elle-même des grilles
    // verticales se dispute les gestes dans un panneau de 160 dp.
    final ordre = MessagePickerTab.values;
    return IndexedStack(
      index: ordre.indexOf(actif),
      sizing: StackFit.expand,
      children: [
        for (final onglet in ordre)
          if (_visited.contains(onglet))
            _tabContent(context, onglet)
          else
            const SizedBox.shrink(),
      ],
    );
  }

  Widget _tabContent(BuildContext context, MessagePickerTab onglet) {
    switch (onglet) {
      case MessagePickerTab.stickers:
        if (widget.onStickerSelected == null) return const SizedBox.shrink();
        return StickerPickerContent(
          query: _stickerQuery,
          onStickerSelected: (sticker) {
            ref.read(stickerActionsProvider.notifier).addToRecent(sticker);
            widget.onStickerSelected!(sticker);
          },
        );
      case MessagePickerTab.gif:
        if (widget.onGifSelected == null) return const SizedBox.shrink();
        return GifPickerContent(onGifSelected: widget.onGifSelected!);
      case MessagePickerTab.emojis:
        return _emojiPicker(context);
    }
  }

  Widget _emojiPicker(BuildContext context) {
    // On mesure la hauteur réelle du slot (LayoutBuilder) au lieu de supposer
    // `widget.height - 44` : la barre d'onglets peut dépasser sa hauteur
    // nominale quand la police système est agrandie.
    return LayoutBuilder(
      builder:
          (context, constraints) => emoji_picker.EmojiPicker(
            onEmojiSelected: widget.onEmojiSelected,
            onBackspacePressed: widget.onBackspacePressed,
            // On enveloppe la vue par défaut sans la remplacer : le seul but
            // est de capter `showSearchView`, que la loupe de la coque appelle.
            customWidget: (config, state, showSearchView) {
              _showEmojiSearch = showSearchView;
              return emoji_picker.DefaultEmojiPickerView(
                config,
                state,
                showSearchView,
              );
            },
            config: emoji_picker.Config(
              height: constraints.maxHeight,
              checkPlatformCompatibility: true,
              emojiViewConfig: emoji_picker.EmojiViewConfig(
                columns: 8,
                emojiSizeMax: 28 * (Platform.isIOS ? 1.30 : 1.0),
                backgroundColor: context.surfaceColor,
              ),
              categoryViewConfig: emoji_picker.CategoryViewConfig(
                backgroundColor: context.surfaceColor,
                indicatorColor: context.adaptivePrimaryColor,
                iconColorSelected: context.adaptivePrimaryColor,
                iconColor: context.textTertiaryColor,
              ),
              // La barre d'action basse portait le bouton de recherche : c'est
              // la loupe de la coque qui le remplace, via `customWidget`.
              bottomActionBarConfig: const emoji_picker.BottomActionBarConfig(
                enabled: false,
              ),
              searchViewConfig: emoji_picker.SearchViewConfig(
                backgroundColor: context.surfaceColor,
                buttonIconColor: context.textSecondaryColor,
              ),
            ),
          ),
    );
  }

  // ── Ligne d'info ──────────────────────────────────────────────────────────

  /// Pied de la fiche 26b. Absent de l'onglet Émojis : il n'y a rien à
  /// télécharger, et c'est justement la hauteur qui manque en paysage.
  Widget _infoLine(BuildContext context, MessagePickerTab actif) {
    if (actif == MessagePickerTab.emojis) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final texte =
        actif == MessagePickerTab.stickers
            ? l10n.stickerDataSaverNote
            : l10n.gifDataSaverNote;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: context.borderColor, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: context.textTertiaryColor,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              texte,
              style: TextStyle(
                fontSize: 11.5,
                color: context.textTertiaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Interactions ──────────────────────────────────────────────────────────

  void _select(MessagePickerTab onglet) {
    setState(() {
      _tab = onglet;
      _visited.add(onglet);
      // Chaque onglet a sa propre recherche : on ne traîne pas celle du
      // précédent, qui filtrerait un contenu qu'elle ne décrit pas.
      _searchOpen = false;
      _searchController.clear();
      _stickerQuery = '';
    });
    _resetGifQuery();
  }

  void _openSearch(MessagePickerTab actif) {
    if (actif == MessagePickerTab.emojis) {
      _showEmojiSearch?.call();
      return;
    }
    setState(() => _searchOpen = true);
  }

  void _closeSearch() {
    setState(() {
      _searchOpen = false;
      _searchController.clear();
      _stickerQuery = '';
    });
    _resetGifQuery();
  }

  void _onQueryChanged(MessagePickerTab actif, String value) {
    if (actif == MessagePickerTab.gif) {
      ref.read(gifSearchQueryProvider.notifier).state = value;
    } else {
      setState(() => _stickerQuery = value);
    }
  }
}
