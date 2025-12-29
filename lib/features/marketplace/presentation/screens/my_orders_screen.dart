import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/currency_provider.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../core/services/stripe_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/order_entity.dart';
import '../providers/marketplace_provider.dart';

class MyOrdersScreen extends ConsumerStatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  ConsumerState<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends ConsumerState<MyOrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider).valueOrNull;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mes commandes')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes commandes'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Mes achats'),
            Tab(text: 'Mes ventes'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _OrdersList(
            ordersAsync: ref.watch(watchBuyerOrdersProvider(currentUser.id)),
            emptyMessage: 'Vous n\'avez pas encore passe de commande',
            emptyIcon: Icons.shopping_bag_outlined,
            isBuyer: true,
          ),
          _OrdersList(
            ordersAsync: ref.watch(watchSellerOrdersProvider(currentUser.id)),
            emptyMessage: 'Vous n\'avez pas encore recu de commande',
            emptyIcon: Icons.store_outlined,
            isBuyer: false,
          ),
        ],
      ),
    );
  }
}

/// Represents a group of orders from/to the same person or same session
class _OrderGroup {
  final String oderId;
  final String personId;
  final String? personName;
  final List<OrderEntity> orders;
  final DateTime? latestDate;
  final String? sessionId;

  _OrderGroup({
    required this.oderId,
    required this.personId,
    this.personName,
    required this.orders,
    this.latestDate,
    this.sessionId,
  });

  double get totalAmount =>
      orders.fold(0.0, (sum, order) => sum + order.amount);

  String get currency => orders.isNotEmpty ? orders.first.currency : 'XOF';

  /// Get the dominant status for the group
  OrderStatus get dominantStatus {
    // Priority: pending > paid > shipped > delivered > completed
    if (orders.any((o) => o.status == OrderStatus.pending)) {
      return OrderStatus.pending;
    }
    if (orders.any((o) => o.status == OrderStatus.paid)) {
      return OrderStatus.paid;
    }
    if (orders.any((o) => o.status == OrderStatus.shipped)) {
      return OrderStatus.shipped;
    }
    if (orders.any((o) => o.status == OrderStatus.delivered)) {
      return OrderStatus.delivered;
    }
    return orders.first.status;
  }
}

class _OrdersList extends ConsumerWidget {
  final AsyncValue<List<OrderEntity>> ordersAsync;
  final String emptyMessage;
  final IconData emptyIcon;
  final bool isBuyer;

  const _OrdersList({
    required this.ordersAsync,
    required this.emptyMessage,
    required this.emptyIcon,
    required this.isBuyer,
  });

  /// Group orders by sessionId (same cart checkout) OR by seller/buyer + time
  List<_OrderGroup> _groupOrders(List<OrderEntity> orders) {
    final List<_OrderGroup> groups = [];

    // Sort orders by date first
    final sortedOrders = List<OrderEntity>.from(orders)
      ..sort((a, b) {
        final dateA = a.createdAt ?? DateTime(1970);
        final dateB = b.createdAt ?? DateTime(1970);
        return dateB.compareTo(dateA);
      });

    for (final order in sortedOrders) {
      final personId = isBuyer ? order.sellerId : order.buyerId;
      final orderDate = order.createdAt ?? DateTime(1970);
      final sessionId = order.sessionId;

      // Find existing group with same sessionId OR (same person + close timestamp)
      final existingGroupIndex = groups.indexWhere((g) {
        // First priority: same sessionId
        if (sessionId != null && sessionId.isNotEmpty) {
          return g.orders.any((o) => o.sessionId == sessionId);
        }
        // Fallback: same person + within 5 minutes
        if (g.personId != personId) return false;
        for (final existingOrder in g.orders) {
          final existingDate = existingOrder.createdAt ?? DateTime(1970);
          final diff = orderDate.difference(existingDate).abs();
          if (diff.inMinutes <= 5) return true;
        }
        return false;
      });

      if (existingGroupIndex != -1) {
        // Add to existing group
        groups[existingGroupIndex].orders.add(order);
      } else {
        // Create new group
        groups.add(_OrderGroup(
          oderId: order.id,
          personId: personId,
          personName: isBuyer ? order.sellerName : order.buyerName,
          orders: [order],
          latestDate: orderDate,
          sessionId: sessionId,
        ));
      }
    }

    // Sort groups by latest date
    groups.sort((a, b) {
      final dateA = a.latestDate ?? DateTime(1970);
      final dateB = b.latestDate ?? DateTime(1970);
      return dateB.compareTo(dateA);
    });

    return groups;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return ordersAsync.when(
      data: (orders) {
        if (orders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(emptyIcon, size: 64, color: theme.colorScheme.outline),
                const SizedBox(height: 16),
                Text(
                  emptyMessage,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                if (isBuyer)
                  ElevatedButton(
                    onPressed: () => context.go('/marketplace'),
                    child: const Text('Decouvrir les produits'),
                  ),
              ],
            ),
          );
        }

        final groupedOrders = _groupOrders(orders);

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: groupedOrders.length,
          itemBuilder: (context, index) {
            final group = groupedOrders[index];
            return _OrderGroupCard(group: group, isBuyer: isBuyer);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text('Erreur: $error'),
          ],
        ),
      ),
    );
  }
}

class _OrderGroupCard extends StatelessWidget {
  final _OrderGroup group;
  final bool isBuyer;

  const _OrderGroupCard({required this.group, required this.isBuyer});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with person name and total
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isBuyer ? Icons.store : Icons.person,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isBuyer
                            ? 'Vendeur: ${group.personName ?? 'Inconnu'}'
                            : 'Acheteur: ${group.personName ?? 'Inconnu'}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (group.latestDate != null)
                        Text(
                          dateFormat.format(group.latestDate!),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                    ],
                  ),
                ),
                Consumer(
                  builder: (context, ref, _) {
                    final currencyService = ref.watch(currencyServiceProvider);
                    final currency = CurrencyExtension.fromCode(group.currency);
                    final formatted = currencyService.format(group.totalAmount, currency);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          formatted,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        Text(
                          '${group.orders.length} article${group.orders.length > 1 ? 's' : ''}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          // Products list
          ...group.orders.map(
            (order) => _OrderItemRow(order: order, isBuyer: isBuyer),
          ),
        ],
      ),
    );
  }
}

class _OrderItemRow extends ConsumerWidget {
  final OrderEntity order;
  final bool isBuyer;

  const _OrderItemRow({required this.order, required this.isBuyer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => context.push('/marketplace/${order.productId}'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                // Product image
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 60,
                    height: 60,
                    child: order.productImageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: order.productImageUrl!,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              color: theme.colorScheme.surfaceContainerHighest,
                              child: const Icon(Icons.image_outlined, size: 24),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              color: theme.colorScheme.surfaceContainerHighest,
                              child: const Icon(Icons.image_outlined, size: 24),
                            ),
                          )
                        : Container(
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: const Icon(Icons.image_outlined, size: 24),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                // Product details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.productTitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            'Qte: ${order.quantity}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Builder(
                            builder: (context) {
                              final currencyService = ref.watch(currencyServiceProvider);
                              final currency = CurrencyExtension.fromCode(order.currency);
                              final formatted = currencyService.format(order.amount, currency);
                              return Text(
                                formatted,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Status chip
                _StatusChip(status: order.status),
              ],
            ),
            // Actions for this specific order
            if (_showActions(order.status, isBuyer)) ...[
              const SizedBox(height: 8),
              _OrderActions(order: order, isBuyer: isBuyer),
            ],
          ],
        ),
      ),
    );
  }

  bool _showActions(OrderStatus status, bool isBuyer) {
    if (isBuyer) {
      return status == OrderStatus.pending ||
          status == OrderStatus.shipped ||
          status == OrderStatus.delivered;
    } else {
      return status == OrderStatus.pending || status == OrderStatus.paid;
    }
  }
}

class _StatusChip extends StatelessWidget {
  final OrderStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, bgColor) = _getStatusColors(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  (Color, Color) _getStatusColors(BuildContext context) {
    switch (status) {
      case OrderStatus.pending:
        return (Colors.orange.shade700, Colors.orange.shade50);
      case OrderStatus.paid:
        return (Colors.blue.shade700, Colors.blue.shade50);
      case OrderStatus.shipped:
        return (Colors.purple.shade700, Colors.purple.shade50);
      case OrderStatus.delivered:
        return (Colors.teal.shade700, Colors.teal.shade50);
      case OrderStatus.completed:
        return (Colors.green.shade700, Colors.green.shade50);
      case OrderStatus.disputed:
        return (Colors.red.shade700, Colors.red.shade50);
      case OrderStatus.refunded:
        return (Colors.grey.shade700, Colors.grey.shade200);
      case OrderStatus.cancelled:
        return (Colors.grey.shade700, Colors.grey.shade200);
    }
  }
}

class _OrderActions extends ConsumerStatefulWidget {
  final OrderEntity order;
  final bool isBuyer;

  const _OrderActions({required this.order, required this.isBuyer});

  @override
  ConsumerState<_OrderActions> createState() => _OrderActionsState();
}

class _OrderActionsState extends ConsumerState<_OrderActions> {
  bool _isLoading = false;

  Future<void> _processPayment() async {
    setState(() => _isLoading = true);
    final currentUser = ref.read(currentUserProvider).valueOrNull;
    if (currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Process payment via Stripe
      final paymentIntentId = await StripeService.instance.processPayment(
        amount: widget.order.amount,
        currency: widget.order.currency,
        userId: currentUser.id,
        transactionId: widget.order.id,
        metadata: {
          'orderId': widget.order.id,
          'productId': widget.order.productId,
          'type': 'marketplace_order',
        },
      );

      if (paymentIntentId != null && mounted) {
        // Payment successful, update order status
        final success = await ref
            .read(orderNotifierProvider.notifier)
            .payOrder(widget.order.id, currentUser.id);

        if (mounted) {
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Paiement effectue avec succes!'),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Erreur lors de la mise a jour de la commande'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de paiement: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _confirmDelivery() async {
    setState(() => _isLoading = true);
    final currentUser = ref.read(currentUserProvider).valueOrNull;
    if (currentUser == null) return;

    final success = await ref
        .read(orderNotifierProvider.notifier)
        .confirmDelivery(widget.order.id, currentUser.id);

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Livraison confirmee'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _markAsShipped() async {
    final trackingNumber = await _showTrackingDialog();
    if (trackingNumber == null) return;

    setState(() => _isLoading = true);
    final currentUser = ref.read(currentUserProvider).valueOrNull;
    if (currentUser == null) return;

    final success = await ref
        .read(orderNotifierProvider.notifier)
        .markAsShipped(widget.order.id, currentUser.id, trackingNumber);

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Commande marquee comme expediee'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<String?> _showTrackingDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Numero de suivi'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Entrez le numero de suivi (optionnel)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(8.0),
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (widget.isBuyer) {
      // Buyer actions
      if (widget.order.status == OrderStatus.pending) {
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _processPayment,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
            icon: const Icon(Icons.payment, size: 18),
            label: Builder(
              builder: (context) {
                final currencyService = ref.watch(currencyServiceProvider);
                final currency = CurrencyExtension.fromCode(widget.order.currency);
                final formatted = currencyService.format(widget.order.amount, currency);
                return Text(
                  'Payer $formatted',
                  style: const TextStyle(fontSize: 13),
                );
              },
            ),
          ),
        );
      }
      if (widget.order.status == OrderStatus.shipped) {
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _confirmDelivery,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
            icon: const Icon(Icons.check_circle_outline, size: 18),
            label: const Text(
              'Confirmer la reception',
              style: TextStyle(fontSize: 13),
            ),
          ),
        );
      }
    } else {
      // Seller actions
      if (widget.order.status == OrderStatus.paid) {
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _markAsShipped,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
            icon: const Icon(Icons.local_shipping_outlined, size: 18),
            label: const Text(
              'Marquer comme expedie',
              style: TextStyle(fontSize: 13),
            ),
          ),
        );
      }
    }

    return const SizedBox.shrink();
  }
}
