import 'package:flutter/material.dart';
import '../../../../core/theme/design_kit.dart';
import '../../../../core/theme/adaptive_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/search_empty_state.dart';
import '../../../../shared/widgets/sheet_handle.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/marketplace/domain/entities/order_entity.dart';
import '../../../../features/marketplace/domain/entities/product_entity.dart';
import '../../../../features/marketplace/presentation/providers/marketplace_provider.dart';
import '../../../../features/marketplace/presentation/widgets/product_card.dart';

class MarketplaceScreen extends ConsumerStatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  ConsumerState<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends ConsumerState<MarketplaceScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final category = ref.read(selectedCategoryProvider);
      final country = ref.read(selectedCountryProvider);
      ref.invalidate(productsProvider(category: category, country: country));
    });
    _searchController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showCountryPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollController) => _CountryPickerSheet(
          scrollController: scrollController,
          onCountrySelected: (Country? country) {
            ref.read(selectedCountryProvider.notifier).select(country);
            Navigator.pop(ctx);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final selectedCountry = ref.watch(selectedCountryProvider);
    final productsAsync = ref.watch(
      productsProvider(category: selectedCategory, country: selectedCountry),
    );
    final cartItemCount = ref.watch(
      cartNotifierProvider.select(
        (items) => items.fold<int>(0, (total, item) => total + item.quantity),
      ),
    );
    // Badge côté vendeur : commandes payées en attente d'expédition
    // (même logique d'action que dans my_orders_screen.dart).
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final pendingSellerOrders =
        currentUser == null
            ? 0
            : ref
                    .watch(watchSellerOrdersProvider(currentUser.id))
                    .valueOrNull
                    ?.where((o) => o.status == OrderStatus.paid)
                    .length ??
                0;

    return Scaffold(
      backgroundColor: context.backgroundColor,
      // En-tête plat (§12b) : « Boutique » en serif — le mot « Marketplace »
      // disparaît — avec le panier et les commandes en actions carrées.
      appBar: AppBar(
        backgroundColor: context.backgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.textPrimaryColor),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        title: const DesignTitle('Boutique', size: 24),
        actions: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart_outlined),
                onPressed: () => context.push('/marketplace/cart'),
              ),
              if (cartItemCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Center(
                        child: Text(
                          cartItemCount > 99 ? '99+' : cartItemCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.receipt_long_outlined),
                onPressed: () => context.push('/marketplace/my-orders'),
              ),
              if (pendingSellerOrders > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Center(
                        child: Text(
                          pendingSellerOrders > 99
                              ? '99+'
                              : pendingSellerOrders.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.inventory_2_outlined),
            onPressed: () => context.push('/marketplace/my-listings'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Recherche + filtre pays fusionnés sur la même ligne (§12b) — le
          // pays n'est plus une rangée séparée sous la barre.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: DesignSearchField(
                    controller: _searchController,
                    hintText: 'Rechercher un produit',
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                    },
                    onClear: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _showCountryPicker(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          selectedCountry?.flag ?? '🌍',
                          style: const TextStyle(fontSize: 18),
                        ),
                        if (selectedCountry != null) ...[
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => ref
                                .read(selectedCountryProvider.notifier)
                                .select(null),
                            child: Icon(
                              Icons.close,
                              size: 16,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Category filter
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _FilterChip(
                  label: 'Tout',
                  isSelected: selectedCategory == null,
                  onTap:
                      () => ref
                          .read(selectedCategoryProvider.notifier)
                          .select(null),
                ),
                ...ProductCategory.values.map(
                  (category) => _FilterChip(
                    label: category.label,
                    isSelected: selectedCategory == category,
                    onTap:
                        () => ref
                            .read(selectedCategoryProvider.notifier)
                            .select(category),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Products grid
          Expanded(
            child:
                _searchQuery.isNotEmpty
                    ? _SearchResults(query: _searchQuery)
                    : productsAsync.when(
                      skipLoadingOnRefresh: true,
                      data: (products) {
                        if (products.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.storefront_outlined,
                                  size: 64,
                                  color: theme.colorScheme.outline,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  AppLocalizations.of(context)!
                                      .marketplaceNoProductsTitle,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: theme.colorScheme.outline,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  AppLocalizations.of(context)!
                                      .marketplaceNoProductsHint,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.outline,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return RefreshIndicator(
                          onRefresh: () async {
                            ref.invalidate(productsProvider);
                          },
                          child: GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  childAspectRatio: 0.7,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                ),
                            itemCount: products.length,
                            itemBuilder: (context, index) {
                              return ProductCard(
                                product: products[index],
                                onTap:
                                    () => context.push(
                                      '/marketplace/${products[index].id}',
                                    ),
                              );
                            },
                          ),
                        );
                      },
                      loading:
                          () =>
                              const Center(child: CircularProgressIndicator()),
                      error:
                          (error, _) => Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 48,
                                  color: theme.colorScheme.error,
                                ),
                                const SizedBox(height: 16),
                                Text('Erreur: $error'),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed:
                                      () => ref.invalidate(productsProvider),
                                  child: const Text('Reessayer'),
                                ),
                              ],
                            ),
                          ),
                    ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/marketplace/create'),
        icon: const Icon(Icons.add),
        label: const Text('Vendre'),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label, style: const TextStyle(fontSize: 13)),
        selected: isSelected,
        onSelected: (_) => onTap(),
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }
}

class _CountryPickerSheet extends StatelessWidget {
  final ScrollController scrollController;
  final void Function(Country?) onCountrySelected;

  const _CountryPickerSheet({
    required this.scrollController,
    required this.onCountrySelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Handle
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: SheetHandle(),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Choisir un pays',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Divider(),
          // Country list grouped by region
          Expanded(
            child: ListView(
              controller: scrollController,
              children: [
                // "All countries" option
                ListTile(
                  leading: const Text('🌍', style: TextStyle(fontSize: 24)),
                  title: const Text('Tous les pays'),
                  dense: true,
                  onTap: () => onCountrySelected(null),
                ),
                const Divider(),
                for (final region in Region.values) ...[
                  // Region header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      '${region.flag} ${region.label}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Countries in this region
                  ...getCountriesByRegion(region).map(
                    (country) => ListTile(
                      leading: Text(
                        country.flag,
                        style: const TextStyle(fontSize: 24),
                      ),
                      title: Text(country.label),
                      dense: true,
                      onTap: () => onCountrySelected(country),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchResults extends ConsumerWidget {
  final String query;

  const _SearchResults({required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final searchAsync = ref.watch(searchProductsProvider(query));
    final category = ref.watch(selectedCategoryProvider);
    final country = ref.watch(selectedCountryProvider);
    final hasFilters = category != null || country != null;

    return searchAsync.when(
      data: (all) {
        // La recherche ignorait les filtres actifs : on cherchait « partout »
        // alors que la grille au-dessus était filtrée. On applique donc les
        // filtres, et on offre la sortie « chercher partout » de la maquette.
        final products = hasFilters
            ? all
                .where((p) =>
                    (category == null || p.category == category) &&
                    (country == null || p.country == country),)
                .toList()
            : all;

        if (products.isEmpty) {
          return SearchEmptyState(
            query: query,
            // Si des résultats existent hors des filtres, la meilleure action
            // est de les montrer — pas de proposer de vendre quelque chose.
            primaryActionLabel: hasFilters && all.isNotEmpty
                ? l10n.marketplaceSearchEverywhere(all.length)
                : l10n.marketplaceSellItem,
            onPrimaryAction: hasFilters && all.isNotEmpty
                ? () {
                    ref.read(selectedCategoryProvider.notifier).select(null);
                    ref.read(selectedCountryProvider.notifier).select(null);
                  }
                : () => context.push('/marketplace/create'),
            onClearFilters: hasFilters
                ? () {
                    ref.read(selectedCategoryProvider.notifier).select(null);
                    ref.read(selectedCountryProvider.notifier).select(null);
                  }
                : null,
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.7,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            return ProductCard(
              product: products[index],
              onTap: () => context.push('/marketplace/${products[index].id}'),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Erreur: $error')),
    );
  }
}
