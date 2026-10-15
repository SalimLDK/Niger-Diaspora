import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/admin_bandeau_erreur.dart';
import 'package:diaspo_niger/core/theme/admin_colors.dart';
import '../../../transfers/domain/entities/transaction_entity.dart';
import '../providers/admin_provider.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:diaspo_niger/core/theme/design_kit.dart';
import 'package:diaspo_niger/features/admin/presentation/widgets/admin_charger_plus.dart';

class AdminTransactionsScreen extends ConsumerStatefulWidget {
  const AdminTransactionsScreen({super.key});

  @override
  ConsumerState<AdminTransactionsScreen> createState() =>
      _AdminTransactionsScreenState();
}

class _AdminTransactionsScreenState
    extends ConsumerState<AdminTransactionsScreen>
    with SingleTickerProviderStateMixin {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  late TabController _tabController;

  // Modern color palette (matching dashboard)
  static const Color _primaryColor = AdminColors.actionBlue;
  static const Color _cardColor = AdminColors.surface;
  static const Color _textPrimary = AdminColors.text;
  static const Color _textSecondary = AdminColors.text2;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(adminTransactionsNotifierProvider.notifier).fetchAllTransactions());
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminTransactionsNotifierProvider);

    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPageHeader(),
                const SizedBox(height: 24),
                // Stats cards
                _buildSectionTitle(l10n.adminTransferVolume),
                const SizedBox(height: 16),
                _buildStatsCards(state),
                const SizedBox(height: 24),
                // Currency breakdown
                if (state.volumeByCurrency.isNotEmpty) ...[
                  _buildSectionTitle(l10n.adminByCurrency),
                  const SizedBox(height: 12),
                  _buildCurrencyBreakdown(state),
                  const SizedBox(height: 24),
                ],
              ],
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              tabBar: Container(
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
                  isScrollable: true,
                  tabs: [
                    Tab(text: 'Toutes (${state.transactions.length}${state.encorePlus.contains(FiltreTransferts.toutes) ? '+' : ''})'),
                    Tab(text: 'En attente (${state.nbEnAttente})'),
                    Tab(text: 'Échouées (${state.nbEchouees})'),
                    Tab(
                      text: 'Complétées (${state.completedTransactions.length}${state.encorePlus.contains(FiltreTransferts.completees) ? '+' : ''})',
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: SizedBox(height: 16),
          ),
        ];
      },
      body: state.isLoading
          ? _buildLoadingState()
          : state.error != null && state.transactions.isEmpty
              ? _buildErrorState(state.error!)
              : Column(
                  children: [
                    // Une erreur posée après une action (zéro ligne, journal
                    // refusé) ne doit pas effacer la liste.
                    if (state.error != null)
                      AdminBandeauErreur(
                        message: state.error!,
                        onFermer: ref
                            .read(adminTransactionsNotifierProvider.notifier)
                            .effacerErreur,
                      ),
                    Expanded(
                      child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTransactionsList(state, FiltreTransferts.toutes),
                    _buildTransactionsList(state, FiltreTransferts.enAttente),
                    _buildTransactionsList(state, FiltreTransferts.echouees),
                    _buildTransactionsList(state, FiltreTransferts.completees),
                  ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildPageHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DesignTitle(
              l10n.adminTransferMonitoringTitle,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: _textPrimary,
              ),
              accent: AdminColors.titleDot,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.adminTransferMonitoringSubtitle,
              style: TextStyle(
                fontSize: 14,
                color: _textSecondary,
              ),
            ),
          ],
        ),
        _buildRefreshButton(),
      ],
    );
  }

  Widget _buildRefreshButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          unawaited(ref.read(adminTransactionsNotifierProvider.notifier).fetchAllTransactions());
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AdminColors.statusGrayBg,
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

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: _textPrimary,
      ),
    );
  }

  Widget _buildStatsCards(AdminTransactionsState state) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _buildStatCard(
          title: l10n.adminTotalVolumeUSD,
          value: '\$${state.totalVolumeUSD.toStringAsFixed(2)}',
          icon: Icons.account_balance_wallet_rounded,
          gradient: const [AdminColors.statusGreen, AdminColors.statusGreenStrong],
        ),
        _buildStatCard(
          title: l10n.adminFeesCollectedUSD,
          value: '\$${state.totalFeesUSD.toStringAsFixed(2)}',
          icon: Icons.payments_rounded,
          gradient: const [AdminColors.actionBlueLight, AdminColors.actionBlue],
        ),
        _buildStatCard(
          title: l10n.adminPending,
          value: state.nbEnAttente.toString(),
          icon: Icons.pending_rounded,
          gradient: const [AdminColors.statusAmber, AdminColors.statusAmberStrong],
        ),
        _buildStatCard(
          title: l10n.adminFailedPlural,
          value: state.nbEchouees.toString(),
          icon: Icons.error_rounded,
          gradient: state.nbEchouees > 0
              ? const [AdminColors.statusRed, AdminColors.statusRedStrong]
              : const [AdminColors.statusGray, AdminColors.statusGray],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required List<Color> gradient,
  }) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradient),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: _textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: _textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencyBreakdown(AdminTransactionsState state) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Wrap(
        spacing: 24,
        runSpacing: 12,
        children: state.volumeByCurrency.entries.map((entry) {
          final fees = state.feesByCurrency[entry.key] ?? 0;
          return _buildCurrencyItem(
            currency: entry.key,
            volume: entry.value,
            fees: fees,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCurrencyItem({
    required String currency,
    required double volume,
    required double fees,
  }) {
    final currencyColors = {
      'EUR': AdminColors.actionBlueLight,
      'USD': AdminColors.statusGreen,
      'CAD': AdminColors.statusRed,
      'GBP': AdminColors.statusPurple,
      'CHF': AdminColors.statusAmber,
      'XOF': AdminColors.statusGreen,
    };

    final color = currencyColors[currency] ?? _primaryColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  currency,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                volume.toStringAsFixed(2),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Frais: ${fees.toStringAsFixed(2)} $currency',
            style: TextStyle(
              fontSize: 11,
              color: _textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsList(
    AdminTransactionsState state,
    FiltreTransferts filtre,
  ) {
    final transactions = state.liste(filtre);
    if (transactions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: DesignEmptyState(
            icon: Icons.receipt_long_rounded,
            title: 'Aucune transaction trouvée',
            body: 'Rien dans cet onglet pour le moment.',
          ),
        ),
      );
    }

    final encorePlus = state.encorePlus.contains(filtre);
    return ListView.builder(
      itemCount: transactions.length + (encorePlus ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == transactions.length) {
          return AdminChargerPlus(
            enCours: state.chargementPlus == filtre,
            onPressed: () => unawaited(
              ref
                  .read(adminTransactionsNotifierProvider.notifier)
                  .chargerPlus(filtre),
            ),
          );
        }
        return _buildTransactionCard(transactions[index]);
      },
    );
  }

  Widget _buildTransactionCard(TransactionEntity transaction) {
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
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _getStatusColor(transaction.status).withAlpha(20),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            _getStatusIcon(transaction.status),
            color: _getStatusColor(transaction.status),
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                '${transaction.amount.toStringAsFixed(2)} ${transaction.currency}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: _textPrimary,
                ),
              ),
            ),
            _buildStatusChip(transaction.status),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '→ ${transaction.recipientName ?? transaction.recipientId}',
              style: const TextStyle(color: _textSecondary),
            ),
            Text(
              'ID: ${transaction.id.substring(0, 12)}...',
              style: TextStyle(color: _textSecondary.withAlpha(150), fontSize: 12),
            ),
          ],
        ),
        children: [
          _buildTransactionDetails(transaction),
        ],
      ),
    );
  }

  Widget _buildTransactionDetails(TransactionEntity transaction) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: 8),
        _buildDetailRow('Expéditeur', transaction.senderId),
        _buildDetailRow(
          'Destinataire',
          transaction.recipientName ?? transaction.recipientId,
        ),
        _buildDetailRow(
          'Téléphone destinataire',
          transaction.recipientPhone ?? 'N/A',
        ),
        const Divider(height: 24),
        _buildDetailRow(
          l10n.adminAmountHeader,
          '${transaction.amount.toStringAsFixed(2)} ${transaction.currency}',
        ),
        _buildDetailRow(
          l10n.adminAmountXofHeader,
          '${transaction.amountInXof.toStringAsFixed(0)} XOF',
        ),
        _buildDetailRow(
          l10n.exchangeRate,
          transaction.exchangeRate.toStringAsFixed(4),
        ),
        _buildDetailRow(
          l10n.adminFees,
          '${transaction.fee.toStringAsFixed(2)} ${transaction.currency}',
        ),
        _buildDetailRow(
          l10n.totalDebited,
          '${transaction.totalCharged.toStringAsFixed(2)} ${transaction.currency}',
        ),
        const Divider(height: 24),
        _buildDetailRow(
          'Fournisseur',
          transaction.provider.name.toUpperCase(),
        ),
        if (transaction.paymentIntentId != null)
          _buildDetailRow(
            'Payment Intent',
            transaction.paymentIntentId!,
          ),
        if (transaction.mynitaReference != null)
          _buildDetailRow(
            'Réf. MyNita',
            transaction.mynitaReference!,
          ),
        if (transaction.failureReason != null)
          _buildDetailRow(
            l10n.adminFailReasonHeader,
            transaction.failureReason!,
            isError: true,
          ),
        if (transaction.createdAt != null)
          _buildDetailRow(
            'Créée le',
            _formatDate(transaction.createdAt!),
          ),
        if (transaction.completedAt != null)
          _buildDetailRow(
            'Complétée le',
            _formatDate(transaction.completedAt!),
          ),
        const SizedBox(height: 16),
        _buildActionButtons(transaction),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isError = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: const TextStyle(
                color: _textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isError ? AdminColors.statusRed : _textPrimary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(TransactionEntity transaction) {
    final notifier = ref.read(adminTransactionsNotifierProvider.notifier);
    final currentAdmin = ref.read(currentAdminProvider);

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (transaction.status == TransactionStatus.pending) ...[
          _buildActionButton(
            label: l10n.adminMarkFailedAction,
            icon: Icons.error_rounded,
            color: AdminColors.statusRed,
            isOutlined: true,
            onPressed: () async {
              if (currentAdmin == null) {
                _showSnackBar(l10n.adminNotConnected);
                return;
              }
              final reason = await _showTextDialog(
                l10n.adminMarkAsFailedTitle,
                'Raison de l\'échec:',
              );
              if (reason != null && reason.isNotEmpty) {
                final ok = await notifier.markAsFailed(transaction.id, reason, adminId: currentAdmin.id, adminName: currentAdmin.name);
                _montrerBilan(ok, l10n.adminTransactionFailed);
              }
            },
          ),
          const SizedBox(width: 8),
          _buildActionButton(
            label: l10n.adminComplete,
            icon: Icons.check_rounded,
            color: AdminColors.statusGreen,
            onPressed: () async {
              if (currentAdmin == null) {
                _showSnackBar(l10n.adminNotConnected);
                return;
              }
              final confirm = await _showConfirmation(
                l10n.adminMarkCompleteTitle,
                l10n.adminMarkCompleteConfirm,
              );
              if (confirm == true) {
                final ok = await notifier.markAsCompleted(transaction.id, adminId: currentAdmin.id, adminName: currentAdmin.name);
                _montrerBilan(ok, l10n.adminTransactionCompleted);
              }
            },
          ),
        ],
        if (transaction.status == TransactionStatus.completed)
          _buildActionButton(
            label: l10n.adminRefund,
            icon: Icons.undo_rounded,
            color: AdminColors.statusAmber,
            onPressed: () async {
              if (currentAdmin == null) {
                _showSnackBar(l10n.adminNotConnected);
                return;
              }
              // « Rembourser » promettait un remboursement qui n'a pas lieu :
              // refundTransaction pose `status = 'refunded'` et rien d'autre,
              // aucun appel Stripe n'existe dans le dépôt (audit du
              // 2026-10-14, § 8). Le libellé et la ligne d'aide le disent.
              final reason = await _showTextDialog(
                'Marquer la transaction remboursée',
                l10n.adminRefundReasonLabel,
                aide:
                    "Aucun remboursement n'est déclenché ici : seul le statut "
                    'passe à « remboursée ». Le remboursement réel se fait '
                    'chez le prestataire de paiement, à part.',
              );
              if (reason != null && reason.isNotEmpty) {
                final ok = await notifier.refundTransaction(transaction.id, reason, adminId: currentAdmin.id, adminName: currentAdmin.name);
                _montrerBilan(ok, l10n.adminTransactionRefunded);
              }
            },
          ),
      ],
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
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Color _getStatusColor(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.pending:
        return AdminColors.statusAmber;
      case TransactionStatus.processing:
        return AdminColors.actionBlueLight;
      case TransactionStatus.completed:
        return AdminColors.statusGreen;
      case TransactionStatus.failed:
        return AdminColors.statusRed;
      case TransactionStatus.refunded:
        return AdminColors.statusPurple;
      case TransactionStatus.cancelled:
        return AdminColors.statusGray;
    }
  }

  IconData _getStatusIcon(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.pending:
        return Icons.pending_rounded;
      case TransactionStatus.processing:
        return Icons.sync_rounded;
      case TransactionStatus.completed:
        return Icons.check_circle_rounded;
      case TransactionStatus.failed:
        return Icons.error_rounded;
      case TransactionStatus.refunded:
        return Icons.undo_rounded;
      case TransactionStatus.cancelled:
        return Icons.cancel_rounded;
    }
  }

  Widget _buildStatusChip(TransactionStatus status) {
    String label;
    switch (status) {
      case TransactionStatus.pending:
        label = l10n.adminPending;
        break;
      case TransactionStatus.processing:
        label = l10n.adminTransactionInProgress;
        break;
      case TransactionStatus.completed:
        label = l10n.adminTransactionCompletedLabel;
        break;
      case TransactionStatus.failed:
        label = 'Échouée';
        break;
      case TransactionStatus.refunded:
        label = 'Remboursée';
        break;
      case TransactionStatus.cancelled:
        label = 'Annulée';
        break;
    }
    return DesignBadge(
      label,
      tone: switch (status) {
        TransactionStatus.pending ||
        TransactionStatus.processing => DesignBadgeTone.review,
        TransactionStatus.completed => DesignBadgeTone.verified,
        TransactionStatus.failed => DesignBadgeTone.failed,
        TransactionStatus.refunded ||
        TransactionStatus.cancelled => DesignBadgeTone.archived,
      },
    );
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
                BoxShadow(
                  color: Colors.black.withAlpha(8),
                  blurRadius: 10,
                ),
              ],
            ),
            child: const CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation(_primaryColor),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Chargement des transactions...',
            style: TextStyle(
              color: _textSecondary,
              fontSize: 14,
            ),
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
            BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 10,
            ),
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
              child: const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: AdminColors.statusRed,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.adminErrorOccurred,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            _buildActionButton(
              label: l10n.retry,
              icon: Icons.refresh_rounded,
              color: _primaryColor,
              onPressed: () {
                unawaited(ref.read(adminTransactionsNotifierProvider.notifier).fetchAllTransactions());
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<bool?> _showConfirmation(String title, String content) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.adminCancelAction),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
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

  /// [aide] : une ligne au-dessus du champ, pour dire ce que l'action fait
  /// — et surtout ce qu'elle ne fait pas.
  Future<String?> _showTextDialog(String title, String label, {String? aide}) {
    final controller = TextEditingController();
    final champ = TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      maxLines: 3,
    );
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title),
        content: aide == null
            ? champ
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    aide,
                    style: const TextStyle(color: AdminColors.text2),
                  ),
                  const SizedBox(height: 16),
                  champ,
                ],
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.adminCancelAction),
          ),
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
  /// Avant, le succès s'affichait quoi qu'il arrive — et côté Postgres,
  /// rembourser, compléter ou échouer une transaction n'a aucune policy
  /// admin : zéro ligne à chaque fois (audit du 2026-10-14, § 5).
  void _montrerBilan(bool ok, String succes) {
    if (!mounted) return;
    if (ok) {
      _showSnackBar(succes);
      return;
    }
    _showSnackBar(
      ref.read(adminTransactionsNotifierProvider).error ?? l10n.loadingError,
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

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget tabBar;

  _TabBarDelegate({required this.tabBar});

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: AdminColors.bg,
      child: tabBar,
    );
  }

  @override
  double get maxExtent => 56;

  @override
  double get minExtent => 56;

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar;
  }
}
