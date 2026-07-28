import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/adaptive_colors.dart';
import '../../../../shared/widgets/sheet_handle.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/sticker_pack_entity.dart';
import '../providers/sticker_provider.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';

/// Screen for browsing and managing sticker packs
class StickerPacksScreen extends ConsumerWidget {
  const StickerPacksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final officialPacksAsync = ref.watch(officialStickerPacksProvider);
    final publicPacksAsync = ref.watch(publicStickerPacksProvider);
    final userPacksAsync = ref.watch(userStickerPacksProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.stickerPacks),
        actions: [
          IconButton(
            icon: AppIcon(AppIcon.add, color: context.textSecondaryColor),
            onPressed: () => _navigateToCreatePack(context),
            tooltip: l10n.createStickerPack,
          ),
        ],
      ),
      body: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            TabBar(
              labelColor: context.adaptivePrimaryColor,
              unselectedLabelColor: context.textSecondaryColor,
              indicatorColor: context.adaptivePrimaryColor,
              tabs: [
                Tab(text: l10n.officialPacks),
                Tab(text: l10n.communityPacks),
                Tab(text: l10n.myStickerPacks),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  // Official packs
                  _buildPacksList(
                    context,
                    ref,
                    officialPacksAsync,
                    isOfficial: true,
                  ),
                  // Community packs
                  _buildPacksList(
                    context,
                    ref,
                    publicPacksAsync,
                    isOfficial: false,
                  ),
                  // User's packs
                  _buildPacksList(
                    context,
                    ref,
                    userPacksAsync,
                    isUserPacks: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPacksList(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<StickerPackEntity>> packsAsync, {
    bool isOfficial = false,
    bool isUserPacks = false,
  }) {
    final l10n = AppLocalizations.of(context)!;

    return packsAsync.when(
      data: (packs) {
        if (packs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.emoji_emotions_outlined,
                  size: 64,
                  color: context.textSecondaryColor.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.noStickerPacks,
                  style: TextStyle(
                    color: context.textSecondaryColor,
                    fontSize: 16,
                  ),
                ),
                if (!isUserPacks) ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.browseStickers,
                    style: TextStyle(
                      color: context.textSecondaryColor.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: packs.length,
          itemBuilder: (context, index) {
            final pack = packs[index];
            return _StickerPackCard(
              pack: pack,
              isUserPacks: isUserPacks,
              onTap: () => _showPackDetails(context, ref, pack),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text(
          'Error: $error',
          style: TextStyle(color: context.errorColor),
        ),
      ),
    );
  }

  void _navigateToCreatePack(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateStickerPackScreen(),
      ),
    );
  }

  void _showPackDetails(
    BuildContext context,
    WidgetRef ref,
    StickerPackEntity pack,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _PackDetailsSheet(pack: pack),
    );
  }
}

/// Card widget for displaying a sticker pack
class _StickerPackCard extends StatelessWidget {
  final StickerPackEntity pack;
  final bool isUserPacks;
  final VoidCallback onTap;

  const _StickerPackCard({
    required this.pack,
    required this.isUserPacks,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: context.surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: context.borderColor,
          width: 0.5,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: pack.thumbnailUrl,
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    width: 64,
                    height: 64,
                    color: context.surfaceVariantColor,
                  ),
                  errorWidget: (_, __, ___) => Container(
                    width: 64,
                    height: 64,
                    color: context.surfaceVariantColor,
                    child: Icon(
                      Icons.emoji_emotions,
                      color: context.textSecondaryColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            pack.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: context.textPrimaryColor,
                            ),
                          ),
                        ),
                        if (pack.isOfficial)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: context.adaptivePrimaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Official',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: context.adaptivePrimaryColor,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${pack.stickerCount} stickers',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.textSecondaryColor,
                      ),
                    ),
                    if (pack.creatorName != null && !pack.isOfficial) ...[
                      const SizedBox(height: 2),
                      Text(
                        'by ${pack.creatorName}',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textSecondaryColor.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                    if (isUserPacks && pack.status != StickerPackStatus.approved)
                      _buildStatusBadge(context, pack.status),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AppIcon(AppIcon.chevronRight,
                color: context.textSecondaryColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, StickerPackStatus status) {
    final l10n = AppLocalizations.of(context)!;
    Color color;
    String text;

    switch (status) {
      case StickerPackStatus.pending:
        color = Colors.orange;
        text = l10n.stickerPackPending;
        break;
      case StickerPackStatus.rejected:
        color = context.errorColor;
        text = l10n.stickerPackRejected;
        break;
      case StickerPackStatus.approved:
        color = Colors.green;
        text = l10n.stickerPackApproved;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

/// Bottom sheet showing pack details
class _PackDetailsSheet extends ConsumerWidget {
  final StickerPackEntity pack;

  const _PackDetailsSheet({required this.pack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final userHasPackAsync = ref.watch(userHasPackProvider(pack.id));
    final actionsState = ref.watch(stickerActionsProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: SheetHandle(),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: pack.thumbnailUrl,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pack.name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: context.textPrimaryColor,
                          ),
                        ),
                        Text(
                          '${pack.stickerCount} stickers',
                          style: TextStyle(
                            fontSize: 13,
                            color: context.textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Add/Remove button
                  userHasPackAsync.when(
                    data: (hasPack) => ElevatedButton(
                      onPressed: actionsState.isLoading
                          ? null
                          : () => _togglePack(ref, hasPack),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: hasPack
                            ? context.surfaceVariantColor
                            : context.adaptivePrimaryColor,
                        foregroundColor: hasPack
                            ? context.textPrimaryColor
                            : Colors.white,
                      ),
                      child: Text(
                        hasPack ? l10n.removeStickerPack : l10n.addStickerPack,
                      ),
                    ),
                    loading: () => const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Sticker grid
            Expanded(
              child: GridView.builder(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                ),
                itemCount: pack.stickers.length,
                itemBuilder: (context, index) {
                  final sticker = pack.stickers[index];
                  return CachedNetworkImage(
                    imageUrl: sticker.url,
                    fit: BoxFit.contain,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _togglePack(WidgetRef ref, bool hasPack) {
    final actions = ref.read(stickerActionsProvider.notifier);
    if (hasPack) {
      actions.removePackFromUser(pack.id);
    } else {
      actions.addPackToUser(pack.id);
    }
  }
}

/// Screen for creating a new sticker pack
class CreateStickerPackScreen extends ConsumerStatefulWidget {
  const CreateStickerPackScreen({super.key});

  @override
  ConsumerState<CreateStickerPackScreen> createState() =>
      _CreateStickerPackScreenState();
}

class _CreateStickerPackScreenState
    extends ConsumerState<CreateStickerPackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.createStickerPack),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: l10n.stickerPackName,
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: l10n.stickerPackDescription,
                  border: const OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              const Spacer(),
              Text(
                'Coming soon: Upload your own sticker packs!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.textSecondaryColor,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
