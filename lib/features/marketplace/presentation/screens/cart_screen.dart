import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/services/security_gate_provider.dart';
import '../../../../core/services/security_gate_service.dart';
import '../../../../shared/widgets/price_text.dart';
import '../providers/marketplace_provider.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cartItems = ref.watch(cartNotifierProvider);
    final cartNotifier = ref.read(cartNotifierProvider.notifier);

    if (cartItems.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Panier')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.shopping_cart_outlined,
                size: 64,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                'Votre panier est vide',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go('/marketplace'),
                child: const Text('Decouvrir les produits'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Panier (${cartNotifier.itemCount})'),
        actions: [
          TextButton(
            onPressed: () {
              cartNotifier.clearCart();
            },
            child: const Text('Vider'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: cartItems.length,
              itemBuilder: (context, index) {
                final item = cartItems[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () {
                      context.push('/marketplace/${item.product.id}');
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          // Image
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 80,
                              height: 80,
                              child:
                                  item.product.imageUrls.isNotEmpty
                                      ? CachedNetworkImage(
                                        imageUrl: item.product.imageUrls.first,
                                        fit: BoxFit.cover,
                                      )
                                      : Container(
                                        color:
                                            theme
                                                .colorScheme
                                                .surfaceContainerHighest,
                                        child: const Icon(Icons.image_outlined),
                                      ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.product.title,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                PriceText(
                                  amount: item.product.price,
                                  currency: item.product.currency,
                                  style: TextStyle(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // Quantity controls
                                Row(
                                  children: [
                                    IconButton.outlined(
                                      onPressed:
                                          item.quantity > 1
                                              ? () =>
                                                  cartNotifier.updateQuantity(
                                                    item.product.id,
                                                    item.quantity - 1,
                                                  )
                                              : null,
                                      icon: const Icon(Icons.remove, size: 16),
                                      constraints: const BoxConstraints(
                                        minWidth: 32,
                                        minHeight: 32,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      child: Text(
                                        '${item.quantity}',
                                        style: theme.textTheme.titleSmall,
                                      ),
                                    ),
                                    IconButton.outlined(
                                      onPressed:
                                          item.quantity < item.product.quantity
                                              ? () =>
                                                  cartNotifier.updateQuantity(
                                                    item.product.id,
                                                    item.quantity + 1,
                                                  )
                                              : null,
                                      icon: const Icon(Icons.add, size: 16),
                                      constraints: const BoxConstraints(
                                        minWidth: 32,
                                        minHeight: 32,
                                      ),
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      onPressed:
                                          () => cartNotifier.removeFromCart(
                                            item.product.id,
                                          ),
                                      icon: const Icon(Icons.delete_outline),
                                      color: theme.colorScheme.error,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // Bottom summary
          Container(
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
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Total', style: theme.textTheme.titleMedium),
                          if (cartNotifier.hasMultipleCurrencies)
                            Text(
                              '(converti)',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                        ],
                      ),
                      Consumer(
                        builder: (context, ref, _) {
                          final formattedTotal = ref.watch(
                            formattedCartTotalProvider,
                          );
                          return Text(
                            formattedTotal,
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _CheckoutButton(
                    cartItems: cartItems,
                    totalAmount: cartNotifier.totalAmount,
                    onSuccess: () {
                      cartNotifier.clearCart();
                      context.go('/marketplace');
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckoutButton extends ConsumerStatefulWidget {
  final List<CartItem> cartItems;
  final double totalAmount;
  final VoidCallback onSuccess;

  const _CheckoutButton({
    required this.cartItems,
    required this.totalAmount,
    required this.onSuccess,
  });

  @override
  ConsumerState<_CheckoutButton> createState() => _CheckoutButtonState();
}

class _CheckoutButtonState extends ConsumerState<_CheckoutButton> {
  bool _isProcessing = false;

  Future<void> _processCheckout() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // Vérification de sécurité Play Integrity
      final securityGate = ref.read(securityGateProvider);
      final canProceed = await securityGate.checkAndShowDialog(
        context,
        level: SecurityLevel.playStoreRequired,
        customTitle: 'Achat sécurisé',
        customMessage:
            'Les achats sur le marketplace nécessitent l\'installation '
            'de l\'application depuis Google Play Store.',
      );

      if (!canProceed) {
        setState(() => _isProcessing = false);
        return;
      }

      final repository = ref.read(marketplaceRepositoryProvider);
      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser == null) {
        throw Exception('Utilisateur non connecté');
      }

      // Generate a unique session ID for this checkout
      final sessionId = const Uuid().v4();

      // Create orders for each cart item with the same sessionId
      for (final item in widget.cartItems) {
        final result = await repository.createOrder(
          product: item.product,
          buyerId: currentUser.uid,
          buyerName: currentUser.displayName,
          quantity: item.quantity,
          sessionId: sessionId,
          buyerNote: null,
        );

        // Check for errors
        result.fold(
          (failure) => throw Exception(failure.message),
          (_) {}, // Success, continue
        );
      }

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Commande(s) créée(s) avec succès !'),
          backgroundColor: Colors.green,
        ),
      );

      // Call success callback
      widget.onSuccess();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isProcessing ? null : _processCheckout,
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
        ),
        child:
            _isProcessing
                ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                : const Text(
                  'Commander',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
      ),
    );
  }
}
