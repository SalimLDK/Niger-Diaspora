import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart' as emoji_picker;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/adaptive_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../gifs/domain/entities/gif_entity.dart';
import '../../../stickers/domain/entities/sticker_entity.dart';
import '../../../stickers/domain/entities/sticker_pack_entity.dart';
import '../../../stickers/presentation/providers/sticker_provider.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';
import 'gif_picker_content.dart';

/// Combined picker for emojis, GIFs and stickers with tabs
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

  /// Initial tab index (0 = emojis, then GIFs/stickers when enabled)
  final int initialTabIndex;

  const EmojiStickerPicker({
    super.key,
    required this.onEmojiSelected,
    this.onBackspacePressed,
    this.onStickerSelected,
    this.onGifSelected,
    this.onClose,
    this.height = 300,
    this.initialTabIndex = 0,
  });

  @override
  ConsumerState<EmojiStickerPicker> createState() => _EmojiStickerPickerState();
}

class _EmojiStickerPickerState extends ConsumerState<EmojiStickerPicker>
    with TickerProviderStateMixin {
  TabController? _mainTabController;

  bool get _hasGifs => widget.onGifSelected != null;

  /// L'onglet Stickers (packs Supabase) n'est proposé que si un pack existe :
  /// sinon il serait systématiquement vide. Résolu en [build] car la
  /// disponibilité des packs est asynchrone. Les stickers « qui marchent »
  /// vivent dans l'onglet GIFs (bascule Stickers Giphy).
  bool _hasStickers = false;

  @override
  void dispose() {
    _mainTabController?.dispose();
    super.dispose();
  }

  /// (Re)construit le contrôleur d'onglets quand leur nombre change, en
  /// conservant au mieux l'onglet courant.
  void _syncController(int tabCount) {
    if (_mainTabController?.length == tabCount) return;
    final previousIndex =
        _mainTabController?.index ?? widget.initialTabIndex;
    _mainTabController?.dispose();
    _mainTabController = TabController(
      length: tabCount,
      vsync: this,
      initialIndex: previousIndex.clamp(0, tabCount - 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    _hasStickers = widget.onStickerSelected != null &&
        (ref.watch(allUserPacksProvider).valueOrNull?.isNotEmpty ?? false);
    _syncController(1 + (_hasGifs ? 1 : 0) + (_hasStickers ? 1 : 0));

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
          // Main tab bar (Emojis / Stickers)
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: context.surfaceColor,
              border: Border(
                bottom: BorderSide(color: context.borderColor, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TabBar(
                    controller: _mainTabController,
                    isScrollable: false,
                    indicatorColor: context.adaptivePrimaryColor,
                    indicatorWeight: 2,
                    labelColor: context.adaptivePrimaryColor,
                    unselectedLabelColor: context.textSecondaryColor,
                    labelStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    tabs: [
                      _buildTab(Icons.emoji_emotions_outlined, l10n.emojis),
                      if (_hasGifs) _buildTab(Icons.gif_box_outlined, l10n.gifs),
                      if (_hasStickers)
                        _buildTab(Icons.sticky_note_2_outlined, l10n.stickers),
                    ],
                  ),
                ),
                // Close button
                if (widget.onClose != null)
                  IconButton(
                    onPressed: widget.onClose,
                    icon: Icon(
                      Icons.keyboard,
                      color: context.textSecondaryColor,
                    ),
                    tooltip: l10n.showKeyboard,
                  ),
              ],
            ),
          ),
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _mainTabController,
              children: [
                // Emoji picker
                _buildEmojiPicker(context),
                // GIFs & stickers Tenor/Giphy
                if (_hasGifs)
                  GifPickerContent(onGifSelected: widget.onGifSelected!),
                // Sticker packs (Supabase)
                if (_hasStickers) _buildStickerPicker(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(IconData icon, String label) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildEmojiPicker(BuildContext context) {
    return emoji_picker.EmojiPicker(
      onEmojiSelected: widget.onEmojiSelected,
      onBackspacePressed: widget.onBackspacePressed,
      config: emoji_picker.Config(
        height: widget.height - 44,
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
        bottomActionBarConfig: const emoji_picker.BottomActionBarConfig(
          enabled: false,
        ),
        searchViewConfig: emoji_picker.SearchViewConfig(
          backgroundColor: context.surfaceColor,
          buttonIconColor: context.textSecondaryColor,
        ),
      ),
    );
  }

  Widget _buildStickerPicker(BuildContext context) {
    return _StickerPickerContent(
      onStickerSelected: (sticker) {
        ref.read(stickerActionsProvider.notifier).addToRecent(sticker);
        widget.onStickerSelected?.call(sticker);
      },
    );
  }
}

/// Internal sticker picker content with sub-tabs for packs
class _StickerPickerContent extends ConsumerStatefulWidget {
  final void Function(StickerEntity sticker) onStickerSelected;

  const _StickerPickerContent({
    required this.onStickerSelected,
  });

  @override
  ConsumerState<_StickerPickerContent> createState() =>
      _StickerPickerContentState();
}

class _StickerPickerContentState extends ConsumerState<_StickerPickerContent>
    with SingleTickerProviderStateMixin {
  TabController? _packTabController;
  int _selectedPackIndex = 0;

  @override
  void dispose() {
    _packTabController?.dispose();
    super.dispose();
  }

  void _updatePackTabController(int length) {
    if (length == 0) return;

    if (_packTabController?.length != length) {
      _packTabController?.dispose();
      _packTabController = TabController(
        length: length,
        vsync: this,
        initialIndex: _selectedPackIndex.clamp(0, length - 1),
      );
      _packTabController!.addListener(() {
        if (!_packTabController!.indexIsChanging) {
          setState(() {
            _selectedPackIndex = _packTabController!.index;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final allPacksAsync = ref.watch(allUserPacksProvider);
    final recentStickersAsync = ref.watch(recentStickersProvider);
    final favoriteStickersAsync = ref.watch(favoriteStickersProvider);

    return allPacksAsync.when(
      data: (packs) {
        // Tabs: Recent + Favorites + Packs
        final totalTabs = 2 + packs.length;
        _updatePackTabController(totalTabs);

        if (_packTabController == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          children: [
            // Pack tab bar
            _buildPackTabBar(context, packs),
            // Sticker grid
            Expanded(
              child: TabBarView(
                controller: _packTabController,
                children: [
                  // Recent stickers
                  _buildRecentTab(recentStickersAsync),
                  // Favorites
                  _buildFavoritesTab(favoriteStickersAsync),
                  // Pack tabs
                  ...packs.map((pack) => _buildPackTab(pack)),
                ],
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text(
          AppLocalizations.of(context)!.errorLoadingStickers,
          style: TextStyle(color: context.textSecondaryColor),
        ),
      ),
    );
  }

  Widget _buildPackTabBar(BuildContext context, List<StickerPackEntity> packs) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: context.surfaceVariantColor,
        border: Border(
          bottom: BorderSide(color: context.borderColor, width: 0.5),
        ),
      ),
      child: TabBar(
        controller: _packTabController,
        isScrollable: true,
        indicatorColor: context.adaptivePrimaryColor,
        indicatorWeight: 2,
        labelColor: context.adaptivePrimaryColor,
        unselectedLabelColor: context.textSecondaryColor,
        tabAlignment: TabAlignment.start,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        tabs: [
          // Recent tab
          Tab(icon: AppIcon(AppIcon.clock, color: Theme.of(context).iconTheme.color!, size: 22)),
          // Favorites tab
          Tab(icon: AppIcon(AppIcon.heart, color: Theme.of(context).iconTheme.color!, size: 22)),
          // Pack tabs with thumbnails
          ...packs.map(
            (pack) => Tab(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: CachedNetworkImage(
                  imageUrl: pack.thumbnailUrl,
                  width: 26,
                  height: 26,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    width: 26,
                    height: 26,
                    color: context.surfaceColor,
                  ),
                  errorWidget: (_, __, ___) => Container(
                    width: 26,
                    height: 26,
                    color: context.surfaceColor,
                    child: Icon(
                      Icons.emoji_emotions,
                      size: 16,
                      color: context.textSecondaryColor,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTab(AsyncValue<List<StickerEntity>> recentAsync) {
    final l10n = AppLocalizations.of(context)!;
    return recentAsync.when(
      data: (stickers) {
        if (stickers.isEmpty) {
          return _buildEmptyState(
            icon: Icons.access_time,
            message: l10n.noRecentStickers,
          );
        }
        return _buildStickerGrid(stickers);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => _buildEmptyState(
        icon: Icons.error_outline,
        message: l10n.errorLoadingRecentStickers,
      ),
    );
  }

  Widget _buildFavoritesTab(AsyncValue<List<StickerEntity>> favoritesAsync) {
    final l10n = AppLocalizations.of(context)!;
    return favoritesAsync.when(
      data: (stickers) {
        if (stickers.isEmpty) {
          return _buildEmptyState(
            icon: Icons.favorite_border,
            message: l10n.noFavoriteStickers,
            subtitle: l10n.addToFavoritesHint,
          );
        }
        return _buildStickerGrid(stickers);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => _buildEmptyState(
        icon: Icons.error_outline,
        message: l10n.errorLoadingFavorites,
      ),
    );
  }

  Widget _buildPackTab(StickerPackEntity pack) {
    final l10n = AppLocalizations.of(context)!;
    if (pack.stickers.isEmpty) {
      return _buildEmptyState(
        icon: Icons.emoji_emotions,
        message: l10n.noStickersInPack,
      );
    }
    return _buildStickerGrid(pack.stickers);
  }

  Widget _buildStickerGrid(List<StickerEntity> stickers) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      // Colonnes déduites de la largeur (≈64 dp par sticker) : ~6 en portrait,
      // ~12 en paysage. Stickers plus compacts = plus visibles d'un coup.
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 64,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
      ),
      itemCount: stickers.length,
      itemBuilder: (context, index) {
        final sticker = stickers[index];
        return _buildStickerItem(sticker);
      },
    );
  }

  Widget _buildStickerItem(StickerEntity sticker) {
    return GestureDetector(
      onTap: () => widget.onStickerSelected(sticker),
      onLongPress: () => _onStickerLongPress(sticker),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
        ),
        child: CachedNetworkImage(
          imageUrl: sticker.url,
          fit: BoxFit.contain,
          placeholder: (_, __) => Container(
            decoration: BoxDecoration(
              color: context.surfaceVariantColor,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          errorWidget: (_, __, ___) => Container(
            decoration: BoxDecoration(
              color: context.surfaceVariantColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.broken_image,
              color: context.textSecondaryColor,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
    String? subtitle,
  }) {
    return Center(
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
            style: TextStyle(
              color: context.textSecondaryColor,
              fontSize: 13,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: context.textSecondaryColor.withValues(alpha: 0.7),
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _onStickerLongPress(StickerEntity sticker) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Sticker preview
              Container(
                width: 100,
                height: 100,
                margin: const EdgeInsets.only(bottom: 16),
                child: CachedNetworkImage(
                  imageUrl: sticker.url,
                  fit: BoxFit.contain,
                ),
              ),
              // Options
              ListTile(
                leading: AppIcon(AppIcon.send, color: Theme.of(context).iconTheme.color!),
                title: Text(AppLocalizations.of(context)!.send),
                onTap: () {
                  Navigator.pop(context);
                  widget.onStickerSelected(sticker);
                },
              ),
              ListTile(
                leading: AppIcon(AppIcon.heart, color: Theme.of(context).iconTheme.color!),
                title: Text(AppLocalizations.of(context)!.addToFavorites),
                onTap: () {
                  ref
                      .read(stickerActionsProvider.notifier)
                      .toggleFavorite(sticker);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
