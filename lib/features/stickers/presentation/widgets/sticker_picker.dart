import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/adaptive_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/sticker_entity.dart';
import '../../domain/entities/sticker_pack_entity.dart';
import '../providers/sticker_provider.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';

/// Widget for picking and sending stickers
/// Similar to emoji picker but for stickers
class StickerPicker extends ConsumerStatefulWidget {
  /// Callback when a sticker is selected
  final void Function(StickerEntity sticker) onStickerSelected;

  /// Callback when the picker should be closed
  final VoidCallback? onClose;

  /// Height of the picker
  final double height;

  const StickerPicker({
    super.key,
    required this.onStickerSelected,
    this.onClose,
    this.height = 300,
  });

  @override
  ConsumerState<StickerPicker> createState() => _StickerPickerState();
}

class _StickerPickerState extends ConsumerState<StickerPicker>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _updateTabController(int length) {
    if (_tabController.length != length) {
      _tabController.dispose();
      _tabController = TabController(
        length: length,
        vsync: this,
        initialIndex: _selectedTabIndex.clamp(0, length - 1),
      );
      _tabController.addListener(() {
        if (_tabController.indexIsChanging) {
          setState(() {
            _selectedTabIndex = _tabController.index;
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

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: context.surfaceColor,
        border: Border(top: BorderSide(color: context.borderColor, width: 0.5)),
      ),
      child: allPacksAsync.when(
        data: (packs) {
          // Calculate total tabs: Recent + Favorites + Packs + Add button
          final totalTabs = 2 + packs.length;
          _updateTabController(totalTabs);

          return Column(
            children: [
              // Tab bar
              _buildTabBar(
                context,
                packs,
                recentStickersAsync,
                favoriteStickersAsync,
              ),
              // Sticker grid
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Recent stickers tab
                    _buildRecentTab(recentStickersAsync),
                    // Favorites tab
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
        error:
            (error, stack) => Center(
              child: Text(
                AppLocalizations.of(context)!.stickerLoadError,
                style: TextStyle(color: context.textSecondaryColor),
              ),
            ),
      ),
    );
  }

  Widget _buildTabBar(
    BuildContext context,
    List<StickerPackEntity> packs,
    AsyncValue<List<StickerEntity>> recentAsync,
    AsyncValue<List<StickerEntity>> favoritesAsync,
  ) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: context.borderColor, width: 0.5),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: context.adaptivePrimaryColor,
        indicatorWeight: 2,
        labelColor: context.adaptivePrimaryColor,
        unselectedLabelColor: context.textSecondaryColor,
        tabAlignment: TabAlignment.start,
        tabs: [
          // Recent tab
          Tab(icon: AppIcon(AppIcon.clock, color: Theme.of(context).iconTheme.color!, size: 24)),
          // Favorites tab
          Tab(icon: AppIcon(AppIcon.heart, color: Theme.of(context).iconTheme.color!, size: 24)),
          // Pack tabs with thumbnails
          ...packs.map(
            (pack) => Tab(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: CachedNetworkImage(
                  imageUrl: pack.thumbnailUrl,
                  width: 28,
                  height: 28,
                  fit: BoxFit.cover,
                  placeholder:
                      (_, __) => Container(
                        width: 28,
                        height: 28,
                        color: context.surfaceVariantColor,
                      ),
                  errorWidget:
                      (_, __, ___) => Container(
                        width: 28,
                        height: 28,
                        color: context.surfaceVariantColor,
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
            message: l10n.stickerNoRecent,
          );
        }
        return _buildStickerGrid(stickers);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error:
          (_, __) => _buildEmptyState(
            icon: Icons.error_outline,
            message: l10n.stickerRecentLoadError,
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
            message: l10n.stickerNoFavorites,
            subtitle: l10n.stickerAddFavoritesHint,
          );
        }
        return _buildStickerGrid(stickers);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error:
          (_, __) => _buildEmptyState(
            icon: Icons.error_outline,
            message: l10n.stickerFavoritesLoadError,
          ),
    );
  }

  Widget _buildPackTab(StickerPackEntity pack) {
    final l10n = AppLocalizations.of(context)!;
    if (pack.stickers.isEmpty) {
      return _buildEmptyState(
        icon: Icons.emoji_emotions,
        message: l10n.stickerPackEmpty,
      );
    }
    return _buildStickerGrid(pack.stickers);
  }

  Widget _buildStickerGrid(List<StickerEntity> stickers) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
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
      onTap: () => _onStickerTap(sticker),
      onLongPress: () => _onStickerLongPress(sticker),
      child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
        child: CachedNetworkImage(
          imageUrl: sticker.url,
          fit: BoxFit.contain,
          placeholder:
              (_, __) => Container(
                decoration: BoxDecoration(
                  color: context.surfaceVariantColor,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
          errorWidget:
              (_, __, ___) => Container(
                decoration: BoxDecoration(
                  color: context.surfaceVariantColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.broken_image,
                  color: context.textSecondaryColor,
                  size: 24,
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
            size: 48,
            color: context.textSecondaryColor.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(color: context.textSecondaryColor, fontSize: 14),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: context.textSecondaryColor.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _onStickerTap(StickerEntity sticker) {
    // Add to recent stickers
    ref.read(stickerActionsProvider.notifier).addToRecent(sticker);
    // Call callback
    widget.onStickerSelected(sticker);
  }

  void _onStickerLongPress(StickerEntity sticker) {
    // Show options: Add to favorites, view pack info
    showModalBottomSheet(
      context: context,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (context) => _StickerOptionsSheet(
            sticker: sticker,
            onAddToFavorites: () {
              ref.read(stickerActionsProvider.notifier).toggleFavorite(sticker);
              Navigator.pop(context);
            },
            onSend: () {
              Navigator.pop(context);
              _onStickerTap(sticker);
            },
          ),
    );
  }
}

/// Bottom sheet with sticker options
class _StickerOptionsSheet extends StatelessWidget {
  final StickerEntity sticker;
  final VoidCallback onAddToFavorites;
  final VoidCallback onSend;

  const _StickerOptionsSheet({
    required this.sticker,
    required this.onAddToFavorites,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Sticker preview
            Container(
              width: 120,
              height: 120,
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
              onTap: onSend,
            ),
            ListTile(
              leading: AppIcon(AppIcon.heart, color: Theme.of(context).iconTheme.color!),
              title: Text(AppLocalizations.of(context)!.addToFavorites),
              onTap: onAddToFavorites,
            ),
          ],
        ),
      ),
    );
  }
}
