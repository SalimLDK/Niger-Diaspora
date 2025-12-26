import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/product_entity.dart';
import '../providers/marketplace_provider.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  final String productId;

  const ProductDetailScreen({super.key, required this.productId});

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  int _currentImageIndex = 0;
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    // Increment view count
    Future.microtask(() {
      ref
          .read(productNotifierProvider.notifier)
          .incrementViewCount(widget.productId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final productAsync = ref.watch(productProvider(widget.productId));
    final currentUser = ref.watch(currentUserProvider).valueOrNull;

    return Scaffold(
      body: productAsync.when(
        data: (product) {
          final isOwner = currentUser?.id == product.sellerId;

          return CustomScrollView(
            slivers: [
              // App bar with images
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                actions: [
                  if (isOwner)
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed:
                          () => context.push(
                            '/marketplace/${product.id}/edit',
                            extra: product,
                          ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.share),
                    onPressed: () {
                      // Share functionality
                    },
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background:
                      product.imageUrls.isNotEmpty
                          ? Stack(
                            fit: StackFit.expand,
                            children: [
                              PageView.builder(
                                itemCount: product.imageUrls.length,
                                onPageChanged: (index) {
                                  setState(() => _currentImageIndex = index);
                                },
                                itemBuilder: (context, index) {
                                  return CachedNetworkImage(
                                    imageUrl: product.imageUrls[index],
                                    fit: BoxFit.cover,
                                  );
                                },
                              ),
                              if (product.imageUrls.length > 1)
                                Positioned(
                                  bottom: 16,
                                  left: 0,
                                  right: 0,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: List.generate(
                                      product.imageUrls.length,
                                      (index) => Container(
                                        width: 8,
                                        height: 8,
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color:
                                              _currentImageIndex == index
                                                  ? Colors.white
                                                  : Colors.white54,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          )
                          : Container(
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: Icon(
                              Icons.image_outlined,
                              size: 64,
                              color: theme.colorScheme.outline,
                            ),
                          ),
                ),
              ),

              // Content
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title and price
                      Text(
                        product.title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${product.price.toStringAsFixed(0)} ${product.currency}',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Badges
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _InfoChip(
                            icon: product.category.icon,
                            label: product.category.label,
                          ),
                          _InfoChip(
                            icon: Icons.sell_outlined,
                            label: product.condition.label,
                          ),
                          if (product.location != null)
                            _InfoChip(
                              icon: Icons.location_on_outlined,
                              label: product.location!,
                            ),
                          _InfoChip(
                            icon: Icons.inventory_2_outlined,
                            label: '${product.quantity} disponible(s)',
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Description
                      Text(
                        'Description',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        product.description,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 24),

                      // Seller info
                      Text(
                        'Vendeur',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundImage:
                              product.sellerPhotoUrl != null
                                  ? CachedNetworkImageProvider(
                                    product.sellerPhotoUrl!,
                                  )
                                  : null,
                          child:
                              product.sellerPhotoUrl == null
                                  ? const Icon(Icons.person)
                                  : null,
                        ),
                        title: Text(product.sellerName ?? 'Vendeur'),
                        subtitle: const Text('Voir le profil'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          // Navigate to seller profile
                        },
                      ),
                      const SizedBox(height: 24),

                      // Stats
                      Row(
                        children: [
                          _StatItem(
                            icon: Icons.visibility_outlined,
                            value: '${product.viewCount}',
                            label: 'vues',
                          ),
                          const SizedBox(width: 24),
                          _StatItem(
                            icon: Icons.access_time,
                            value: _formatDate(product.createdAt),
                            label: 'publie',
                          ),
                        ],
                      ),
                      const SizedBox(height: 100), // Space for bottom bar
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
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
                        () => ref.invalidate(productProvider(widget.productId)),
                    child: const Text('Reessayer'),
                  ),
                ],
              ),
            ),
      ),
      bottomNavigationBar: productAsync.whenOrNull(
        data: (product) {
          final isOwner = currentUser?.id == product.sellerId;
          final canBuy =
              product.isAvailable && product.quantity > 0 && !isOwner;

          if (isOwner) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _deleteProduct(product.id),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Supprimer'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed:
                            () => context.push(
                              '/marketplace/${product.id}/edit',
                              extra: product,
                            ),
                        icon: const Icon(Icons.edit),
                        label: const Text('Modifier'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return SafeArea(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Quantity selector
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.colorScheme.outline),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove),
                          onPressed:
                              _quantity > 1
                                  ? () => setState(() => _quantity--)
                                  : null,
                        ),
                        Text('$_quantity', style: theme.textTheme.titleMedium),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed:
                              _quantity < product.quantity
                                  ? () => setState(() => _quantity++)
                                  : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Add to cart button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed:
                          canBuy
                              ? () {
                                ref
                                    .read(cartNotifierProvider.notifier)
                                    .addToCart(product, quantity: _quantity);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('Ajoute au panier'),
                                    action: SnackBarAction(
                                      label: 'Voir',
                                      onPressed:
                                          () =>
                                              context.push('/marketplace/cart'),
                                    ),
                                  ),
                                );
                              }
                              : null,
                      icon: const Icon(Icons.add_shopping_cart),
                      label: const Text('Ajouter au panier'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _deleteProduct(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Supprimer le produit'),
            content: const Text(
              'Etes-vous sur de vouloir supprimer ce produit?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Supprimer'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      final success = await ref
          .read(productNotifierProvider.notifier)
          .deleteProduct(id);
      if (success && mounted) {
        context.pop();
      }
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return "Aujourd'hui";
    } else if (diff.inDays == 1) {
      return 'Hier';
    } else if (diff.inDays < 7) {
      return 'Il y a ${diff.inDays} jours';
    } else if (diff.inDays < 30) {
      return 'Il y a ${(diff.inDays / 7).floor()} semaines';
    } else {
      return 'Il y a ${(diff.inDays / 30).floor()} mois';
    }
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(label, style: theme.textTheme.labelMedium),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.outline),
        const SizedBox(width: 8),
        Text(
          '$value $label',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }
}
