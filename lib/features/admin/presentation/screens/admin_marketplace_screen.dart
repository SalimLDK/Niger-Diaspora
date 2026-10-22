import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/admin_bandeau_erreur.dart';
import 'package:diaspo_niger/core/theme/admin_colors.dart';
import '../../../marketplace/domain/entities/product_entity.dart';
import '../providers/admin_provider.dart';
import '../../../../shared/widgets/app_icon.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:diaspo_niger/core/theme/design_kit.dart';
import 'package:diaspo_niger/features/admin/presentation/widgets/admin_charger_plus.dart';

class AdminMarketplaceScreen extends ConsumerStatefulWidget {
  const AdminMarketplaceScreen({super.key});

  @override
  ConsumerState<AdminMarketplaceScreen> createState() => _AdminMarketplaceScreenState();
}

class _AdminMarketplaceScreenState extends ConsumerState<AdminMarketplaceScreen>
    with SingleTickerProviderStateMixin {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  late TabController _tabController;
  final _searchController = TextEditingController();
  Timer? _debounceRecherche;

  // Modern color palette (matching dashboard)
  static const Color _primaryColor = AdminColors.actionBlue;
  static const Color _cardColor = AdminColors.surface;
  static const Color _textPrimary = AdminColors.text;
  static const Color _textSecondary = AdminColors.text2;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(adminMarketplaceNotifierProvider.notifier).fetchAllProducts());
      unawaited(ref.read(adminMarketplaceNotifierProvider.notifier).fetchOrders());
      unawaited(ref.read(adminMarketplaceNotifierProvider.notifier).fetchDisputes());
    });
  }

  @override
  void dispose() {
    _debounceRecherche?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// La recherche part au serveur, un court instant après la dernière frappe.
  void _surRecherche(String value) {
    setState(() {});
    _debounceRecherche?.cancel();
    _debounceRecherche = Timer(const Duration(milliseconds: 400), () {
      unawaited(ref.read(adminMarketplaceNotifierProvider.notifier).rechercher(value));
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminMarketplaceNotifierProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPageHeader(state),
        const SizedBox(height: 16),
        DesignSearchField(
          controller: _searchController,
          hintText: l10n.searchPlaceholder,
          onChanged: _surRecherche,
          onClear: () {
            _searchController.clear();
            _surRecherche('');
          },
          active: _searchController.text.isNotEmpty,
        ),
        const SizedBox(height: 16),
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
                    Text(l10n.adminTabWithCount(l10n.adminProducts, '${state.products.length}${state.encorePlus.contains(ListeMarketplace.produits) ? '+' : ''}')),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.receipt_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text(l10n.adminTabWithCount(l10n.adminOrdersName, '${state.orders.length}${state.encorePlus.contains(ListeMarketplace.commandes) ? '+' : ''}')),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.gavel_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text(l10n.adminTabWithCount(l10n.adminDisputesName, '${state.disputes.length}${state.encorePlus.contains(ListeMarketplace.litiges) ? '+' : ''}')),
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
              : state.error != null &&
                      state.products.isEmpty &&
                      state.orders.isEmpty &&
                      state.disputes.isEmpty
                  ? _buildErrorState(state.error!)
                  : Column(
                      children: [
                        // Une erreur posée après une action (zéro ligne,
                        // journal refusé) ne doit pas effacer la liste.
                        if (state.error != null)
                          AdminBandeauErreur(
                            message: state.error!,
                            onFermer: ref
                                .read(adminMarketplaceNotifierProvider.notifier)
                                .effacerErreur,
                          ),
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _buildProductsList(state),
                              _buildOrdersList(state),
                              _buildDisputesList(state),
                            ],
                          ),
                        ),
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
            DesignTitle(
              'Gestion Marketplace',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: _textPrimary,
              ),
              accent: AdminColors.titleDot,
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
        color: AdminColors.statusRed,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AdminColors.statusRed.withAlpha(50),
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

  Widget _buildRefreshButton() => Tooltip(
    message: l10n.adminRefresh,
    child: _boutonActualiser(),
  );

  Widget _boutonActualiser() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          unawaited(ref.read(adminMarketplaceNotifierProvider.notifier).fetchAllProducts());
          unawaited(ref.read(adminMarketplaceNotifierProvider.notifier).fetchOrders());
          unawaited(ref.read(adminMarketplaceNotifierProvider.notifier).fetchDisputes());
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AdminColors.statusGrayBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const AppIcon(
            AppIcon.refresh,
            color: _textSecondary,
            size: 20,
          ),
        ),
      ),
    );
  }

  /// Dernière ligne d'une liste : « Charger plus », ou le sablier en cours.
  Widget _ligneChargerPlus(AdminMarketplaceState state, ListeMarketplace liste) {
    return AdminChargerPlus(
      enCours: state.chargementPlus == liste,
      onPressed: () => unawaited(
        ref.read(adminMarketplaceNotifierProvider.notifier).chargerPlus(liste),
      ),
    );
  }

  Widget _buildProductsList(AdminMarketplaceState state) {
    final products = state.products;
    if (products.isEmpty) {
      return _buildEmptyState(Icons.shopping_bag_rounded, l10n.noProductFound);
    }

    final encorePlus = state.encorePlus.contains(ListeMarketplace.produits);
    return ListView.builder(
      itemCount: products.length + (encorePlus ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == products.length) {
          return _ligneChargerPlus(state, ListeMarketplace.produits);
        }
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
                color: AdminColors.statusGrayBg,
                image: product.imageUrls.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(product.imageUrls.first),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: product.imageUrls.isEmpty
                  ? const AppIcon(AppIcon.image, color: _textSecondary, size: 24)
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
                      color: AdminColors.statusGreen,
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
              tooltip: l10n.moreActions,
              onSelected: (value) => _handleProductAction(value, product),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AdminColors.statusGrayBg,
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
                          color: (product.isAvailable ? AdminColors.statusAmber : AdminColors.statusGreen).withAlpha(20),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          product.isAvailable ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                          color: product.isAvailable ? AdminColors.statusAmber : AdminColors.statusGreen,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(product.isAvailable ? l10n.disable : l10n.enable),
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
                          color: AdminColors.statusRed.withAlpha(20),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const AppIcon(AppIcon.delete, color: AdminColors.statusRed, size: 16),
                      ),
                      const SizedBox(width: 12),
                      Text(l10n.adminDelete),
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
    return DesignBadge(
      isAvailable ? l10n.adminAvailable : l10n.adminUnavailable,
      tone: isAvailable ? DesignBadgeTone.verified : DesignBadgeTone.failed,
    );
  }

  Widget _buildOrdersList(AdminMarketplaceState state) {
    final orders = state.orders;
    if (orders.isEmpty) {
      return _buildEmptyState(Icons.receipt_rounded, l10n.adminNoOrders);
    }

    final encorePlus = state.encorePlus.contains(ListeMarketplace.commandes);
    return ListView.builder(
      itemCount: orders.length + (encorePlus ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == orders.length) {
          return _ligneChargerPlus(state, ListeMarketplace.commandes);
        }
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
                            color: AdminColors.statusRed,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            l10n.adminDisputeBadge,
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

  Widget _buildDisputesList(AdminMarketplaceState state) {
    final disputes = state.disputes;
    if (disputes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AdminColors.statusGreen.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: const AppIcon(
                AppIcon.checkCircle,
                size: 48,
                color: AdminColors.statusGreen,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.adminNoDisputes,
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

    final encorePlus = state.encorePlus.contains(ListeMarketplace.litiges);
    return ListView.builder(
      itemCount: disputes.length + (encorePlus ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == disputes.length) {
          return _ligneChargerPlus(state, ListeMarketplace.litiges);
        }
        final dispute = disputes[index];
        return _buildDisputeCard(dispute);
      },
    );
  }

  Widget _buildDisputeCard(Map<String, dynamic> dispute) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AdminColors.statusRed.withAlpha(10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminColors.statusRed.withAlpha(30)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AdminColors.statusRed.withAlpha(20),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.gavel_rounded, color: AdminColors.statusRed, size: 20),
        ),
        title: Text(
          l10n.adminDisputeNumber(dispute['id']?.substring(0, 8) ?? 'N/A'),
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
              style: const TextStyle(color: AdminColors.statusRed, fontSize: 12),
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
        _buildDetailRow(l10n.adminBuyer, dispute['buyerId'] ?? 'N/A'),
        _buildDetailRow(l10n.adminSeller, dispute['sellerId'] ?? 'N/A'),
        if (dispute['disputeDescription'] != null) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AdminColors.bg,
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
              label: l10n.adminBuyer,
              icon: Icons.person_rounded,
              color: AdminColors.actionBlueLight,
              isOutlined: true,
              onPressed: () => _resolveDispute(dispute, 'buyer_favor'),
            ),
            const SizedBox(width: 8),
            _buildActionButton(
              label: l10n.adminSeller,
              icon: Icons.store_rounded,
              color: AdminColors.statusPurple,
              isOutlined: true,
              onPressed: () => _resolveDispute(dispute, 'seller_favor'),
            ),
            const SizedBox(width: 8),
            _buildActionButton(
              label: l10n.adminRefund,
              icon: Icons.money_off_rounded,
              color: AdminColors.statusAmber,
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
        return AdminColors.statusAmber;
      case 'confirmed':
        return AdminColors.actionBlueLight;
      case 'shipped':
        return AdminColors.statusPurple;
      case 'delivered':
        return AdminColors.statusGreen;
      case 'cancelled':
        return AdminColors.statusRed;
      default:
        return AdminColors.statusGray;
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
          Text(
            l10n.adminLoading,
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
                color: AdminColors.statusRed.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: const AppIcon(AppIcon.error, size: 48, color: AdminColors.statusRed),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.adminLoadingError,
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
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: DesignEmptyState(
          icon: icon,
          title: message,
          body: l10n.adminEmptyListBody,
        ),
      ),
    );
  }

  Future<void> _handleProductAction(String action, ProductEntity product) async {
    final notifier = ref.read(adminMarketplaceNotifierProvider.notifier);
    final currentAdmin = ref.read(currentAdminProvider);

    if (currentAdmin == null) {
      _showSnackBar(l10n.adminNotConnected);
      return;
    }

    switch (action) {
      case 'enable':
        final motif = await _showTextDialog(l10n.marAdmRestoreTitle, l10n.marAdmReasonLabel);
        if (motif == null || motif.isEmpty) return;
        final ok = await notifier.toggleProductAvailability(product.id, true, motif: motif);
        _montrerBilan(ok, l10n.adminProductActivated);
        break;
      case 'disable':
        final motif = await _showTextDialog(l10n.marAdmHideTitle, l10n.marAdmReasonLabel);
        if (motif == null || motif.isEmpty) return;
        final ok = await notifier.toggleProductAvailability(product.id, false, motif: motif);
        _montrerBilan(ok, l10n.adminProductDeactivated);
        break;
      case 'delete':
        final motif = await _showTextDialog(
          l10n.marAdmDeleteTitle,
          l10n.marAdmReasonLabel,
          aide: l10n.marAdmDeleteWarn,
        );
        if (motif == null || motif.isEmpty) return;
        final ok = await notifier.deleteProduct(product.id, motif: motif);
        _montrerBilan(ok, l10n.adminProductDeleted);
        break;
    }
  }

  Future<void> _resolveDispute(Map<String, dynamic> dispute, String resolution) async {
    final currentAdmin = ref.read(currentAdminProvider);
    if (currentAdmin == null) {
      _showSnackBar(l10n.adminNotConnected);
      return;
    }

    final note = await _showTextDialog(
      l10n.adminResolveDisputeTitle,
      l10n.adminProcessReportPrompt,
      aide: l10n.marAdmDisputeWarn,
    );
    if (note != null && note.isNotEmpty) {
      final ok = await ref.read(adminMarketplaceNotifierProvider.notifier).resolveDispute(
        dispute['id'],
        resolution,
        note,
      );
      _montrerBilan(ok, l10n.adminDisputeResolved);
    }
  }


  Future<String?> _showTextDialog(String title, String label, {String? aide}) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (aide != null) ...[
              Text(aide, style: const TextStyle(fontSize: 12, color: AdminColors.text2)),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: label,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.adminCancelAction)),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(l10n.adminConfirmAction),
          ),
        ],
      ),
    );
  }

  /// Le libellé de succès ne s'affiche que si le notifier a rendu vrai ;
  /// sinon son `state.error` (zéro ligne sous RLS, journal d'audit refusé…).
  /// Avant, le succès s'affichait quoi qu'il arrive (audit du 2026-10-14,
  /// § 5).
  void _montrerBilan(bool ok, String succes) {
    if (!mounted) return;
    if (ok) {
      _showSnackBar(succes);
      return;
    }
    _showSnackBar(
      ref.read(adminMarketplaceNotifierProvider).error ?? l10n.loadingError,
      isError: true,
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AdminColors.statusRed : null,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
