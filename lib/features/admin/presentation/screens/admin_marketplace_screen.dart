import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../marketplace/domain/entities/product_entity.dart';
import '../providers/admin_provider.dart';

class AdminMarketplaceScreen extends ConsumerStatefulWidget {
  const AdminMarketplaceScreen({super.key});

  @override
  ConsumerState<AdminMarketplaceScreen> createState() => _AdminMarketplaceScreenState();
}

class _AdminMarketplaceScreenState extends ConsumerState<AdminMarketplaceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Modern color palette (matching dashboard)
  static const Color _primaryColor = Color(0xFF6366F1);
  static const Color _cardColor = Colors.white;
  static const Color _textPrimary = Color(0xFF1E293B);
  static const Color _textSecondary = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adminMarketplaceNotifierProvider.notifier).fetchAllProducts();
      ref.read(adminMarketplaceNotifierProvider.notifier).fetchOrders();
      ref.read(adminMarketplaceNotifierProvider.notifier).fetchDisputes();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminMarketplaceNotifierProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPageHeader(state),
        const SizedBox(height: 24),
        // Tabs
        Container(
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(8),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: _primaryColor,
            unselectedLabelColor: _textSecondary,
            indicatorColor: _primaryColor,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.w600),
            tabs: [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.shopping_bag_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text('Produits (${state.products.length})'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.receipt_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text('Commandes (${state.orders.length})'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.gavel_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text('Litiges (${state.disputes.length})'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: state.isLoading
              ? _buildLoadingState()
              : state.error != null
                  ? _buildErrorState(state.error!)
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildProductsList(state.products),
                        _buildOrdersList(state.orders),
                        _buildDisputesList(state.disputes),
                      ],
                    ),
        ),
      ],
    );
  }

  Widget _buildPageHeader(AdminMarketplaceState state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gestion Marketplace',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: _textPrimary,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Produits, commandes et litiges',
              style: TextStyle(
                fontSize: 14,
                color: _textSecondary,
              ),
            ),
          ],
        ),
        Row(
          children: [
            if (state.disputes.isNotEmpty) _buildDisputeBadge(state.disputes.length),
            const SizedBox(width: 12),
            _buildRefreshButton(),
          ],
        ),
      ],
    );
  }

  Widget _buildDisputeBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEF4444).withAlpha(50),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        '$count litiges',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildRefreshButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          ref.read(adminMarketplaceNotifierProvider.notifier).fetchAllProducts();
          ref.read(adminMarketplaceNotifierProvider.notifier).fetchOrders();
          ref.read(adminMarketplaceNotifierProvider.notifier).fetchDisputes();
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.refresh_rounded,
            color: _textSecondary,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildProductsList(List<ProductEntity> products) {
    if (products.isEmpty) {
      return _buildEmptyState(Icons.shopping_bag_rounded, 'Aucun produit trouvé');
    }

    return ListView.builder(
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return _buildProductCard(product);
      },
    );
  }

  Widget _buildProductCard(ProductEntity product) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Image
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: const Color(0xFFF1F5F9),
                image: product.imageUrls.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(product.imageUrls.first),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: product.imageUrls.isEmpty
                  ? const Icon(Icons.image_rounded, color: _textSecondary, size: 24)
                  : null,
            ),
            const SizedBox(width: 16),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          product.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: _textPrimary,
                          ),
                        ),
                      ),
                      _buildAvailabilityBadge(product.isAvailable),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${product.price.toStringAsFixed(0)} ${product.currency}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF10B981),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Vendeur: ${product.sellerName ?? product.sellerId}',
                    style: const TextStyle(
                      color: _textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // Actions
            PopupMenuButton<String>(
              onSelected: (value) => _handleProductAction(value, product),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.more_vert_rounded, color: _textSecondary, size: 20),
              ),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: product.isAvailable ? 'disable' : 'enable',
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: (product.isAvailable ? const Color(0xFFF59E0B) : const Color(0xFF10B981)).withAlpha(20),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          product.isAvailable ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                          color: product.isAvailable ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(product.isAvailable ? 'Désactiver' : 'Activer'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withAlpha(20),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.delete_rounded, color: Color(0xFFEF4444), size: 16),
                      ),
                      const SizedBox(width: 12),
                      const Text('Supprimer'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailabilityBadge(bool isAvailable) {
    final color = isAvailable ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Text(
        isAvailable ? 'Disponible' : 'Indisponible',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildOrdersList(List<Map<String, dynamic>> orders) {
    if (orders.isEmpty) {
      return _buildEmptyState(Icons.receipt_rounded, 'Aucune commande trouvée');
    }

    return ListView.builder(
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        final status = order['status'] as String? ?? 'pending';
        return _buildOrderCard(order, status);
      },
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order, String status) {
    final statusColor = _getOrderStatusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.receipt_rounded, color: statusColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Commande #${order['id']?.substring(0, 8) ?? 'N/A'}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Montant: ${order['totalAmount'] ?? 'N/A'} ${order['currency'] ?? ''}',
                    style: const TextStyle(
                      color: _textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildOrderStatusChip(status),
                      if (order['hasDispute'] == true) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'LITIGE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderStatusChip(String status) {
    final color = _getOrderStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildDisputesList(List<Map<String, dynamic>> disputes) {
    if (disputes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                size: 48,
                color: Color(0xFF10B981),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Aucun litige en cours',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _textPrimary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: disputes.length,
      itemBuilder: (context, index) {
        final dispute = disputes[index];
        return _buildDisputeCard(dispute);
      },
    );
  }

  Widget _buildDisputeCard(Map<String, dynamic> dispute) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withAlpha(10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEF4444).withAlpha(30)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444).withAlpha(20),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.gavel_rounded, color: Color(0xFFEF4444), size: 20),
        ),
        title: Text(
          'Litige #${dispute['id']?.substring(0, 8) ?? 'N/A'}',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: _textPrimary,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Montant: ${dispute['totalAmount'] ?? 'N/A'} ${dispute['currency'] ?? ''}',
              style: const TextStyle(color: _textSecondary, fontSize: 13),
            ),
            Text(
              'Raison: ${dispute['disputeReason'] ?? 'Non spécifiée'}',
              style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12),
            ),
          ],
        ),
        children: [
          const Divider(),
          _buildDisputeDetails(dispute),
        ],
      ),
    );
  }

  Widget _buildDisputeDetails(Map<String, dynamic> dispute) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailRow('Acheteur', dispute['buyerId'] ?? 'N/A'),
        _buildDetailRow('Vendeur', dispute['sellerId'] ?? 'N/A'),
        if (dispute['disputeDescription'] != null) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              dispute['disputeDescription'],
              style: const TextStyle(fontSize: 13, color: _textPrimary),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _buildActionButton(
              label: 'Acheteur',
              icon: Icons.person_rounded,
              color: const Color(0xFF3B82F6),
              isOutlined: true,
              onPressed: () => _resolveDispute(dispute, 'buyer_favor'),
            ),
            const SizedBox(width: 8),
            _buildActionButton(
              label: 'Vendeur',
              icon: Icons.store_rounded,
              color: const Color(0xFF8B5CF6),
              isOutlined: true,
              onPressed: () => _resolveDispute(dispute, 'seller_favor'),
            ),
            const SizedBox(width: 8),
            _buildActionButton(
              label: 'Rembourser',
              icon: Icons.money_off_rounded,
              color: const Color(0xFFF59E0B),
              onPressed: () => _resolveDispute(dispute, 'refund'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(color: _textSecondary, fontSize: 13),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: _textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    bool isOutlined = false,
  }) {
    if (isOutlined) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Color _getOrderStatusColor(String status) {
    switch (status) {
      case 'pending':
        return const Color(0xFFF59E0B);
      case 'confirmed':
        return const Color(0xFF3B82F6);
      case 'shipped':
        return const Color(0xFF8B5CF6);
      case 'delivered':
        return const Color(0xFF10B981);
      case 'cancelled':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF64748B);
    }
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 10),
              ],
            ),
            child: const CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation(_primaryColor),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Chargement...',
            style: TextStyle(color: _textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 10),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFEF4444)),
            ),
            const SizedBox(height: 24),
            const Text(
              'Erreur de chargement',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textPrimary),
            ),
            const SizedBox(height: 8),
            Text(error, textAlign: TextAlign.center, style: const TextStyle(color: _textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: _textSecondary.withAlpha(100)),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: _textSecondary, fontSize: 16)),
        ],
      ),
    );
  }

  Future<void> _handleProductAction(String action, ProductEntity product) async {
    final notifier = ref.read(adminMarketplaceNotifierProvider.notifier);
    final currentAdmin = ref.read(currentAdminProvider);

    if (currentAdmin == null) {
      _showSnackBar('Erreur: Admin non connecté');
      return;
    }

    switch (action) {
      case 'enable':
        await notifier.toggleProductAvailability(product.id, true, adminId: currentAdmin.id, adminName: currentAdmin.name);
        _showSnackBar('Produit activé');
        break;
      case 'disable':
        await notifier.toggleProductAvailability(product.id, false, adminId: currentAdmin.id, adminName: currentAdmin.name);
        _showSnackBar('Produit désactivé');
        break;
      case 'delete':
        final confirm = await _showConfirmation(
          'Supprimer le produit',
          'Êtes-vous sûr de vouloir supprimer ce produit ?',
        );
        if (confirm == true) {
          await notifier.deleteProduct(product.id, adminId: currentAdmin.id, adminName: currentAdmin.name);
          _showSnackBar('Produit supprimé');
        }
        break;
    }
  }

  Future<void> _resolveDispute(Map<String, dynamic> dispute, String resolution) async {
    final currentAdmin = ref.read(currentAdminProvider);
    if (currentAdmin == null) {
      _showSnackBar('Erreur: Admin non connecté');
      return;
    }

    final note = await _showTextDialog('Résoudre le litige', 'Note de résolution:');
    if (note != null) {
      await ref.read(adminMarketplaceNotifierProvider.notifier).resolveDispute(
        dispute['id'],
        resolution,
        note,
        adminId: currentAdmin.id,
        adminName: currentAdmin.name,
      );
      _showSnackBar('Litige résolu');
    }
  }

  Future<bool?> _showConfirmation(String title, String content) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  Future<String?> _showTextDialog(String title, String label) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
