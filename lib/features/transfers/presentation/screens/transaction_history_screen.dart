import 'package:flutter/material.dart';
import '../../../../core/theme/design_kit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/standard_search_bar.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/transaction_entity.dart';
import '../providers/transfer_provider.dart';
import '../../../../core/theme/adaptive_colors.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

class TransactionHistoryScreen extends ConsumerStatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  ConsumerState<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState
    extends ConsumerState<TransactionHistoryScreen> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  TransactionStatus? _statusFilter;
  DateTimeRange? _dateFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: context.backgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: DesignTitle(l10n.transferHistory, size: 22),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterDialog(context),
          ),
        ],
      ),
      body:
          user == null
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  // Search bar
                  StandardSearchBar(
                    controller: _searchController,
                    hintText: l10n.searchByRecipient,
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                    },
                  ),
                  if (_statusFilter != null || _dateFilter != null)
                    _buildActiveFilters(),
                  Expanded(child: _buildTransactionsList(user.id)),
                ],
              ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/transfers/send'),
        icon: const Icon(Icons.send),
        label: Text(l10n.transferSend),
      ),
    );
  }

  Widget _buildActiveFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: context.surfaceVariantColor,
      child: Row(
        children: [
          Text(l10n.transferActiveFilters),
          if (_statusFilter != null)
            Chip(
              label: Text(_statusFilter!.label),
              onDeleted: () {
                setState(() => _statusFilter = null);
              },
              deleteIcon: const Icon(Icons.close, size: 16),
            ),
          if (_dateFilter != null) ...[
            const SizedBox(width: 8),
            Chip(
              label: Text(_formatDateRange(_dateFilter!)),
              onDeleted: () {
                setState(() => _dateFilter = null);
              },
              deleteIcon: const Icon(Icons.close, size: 16),
            ),
          ],
          const Spacer(),
          TextButton(
            onPressed: () {
              setState(() {
                _statusFilter = null;
                _dateFilter = null;
              });
            },
            child: Text(l10n.transferClearAll),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsList(String userId) {
    final transactionsStream = ref.watch(watchUserTransactionsProvider(userId));

    return transactionsStream.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:
          (error, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: AppColors.error),
                const SizedBox(height: 16),
                Text('Erreur: $error'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed:
                      () =>
                          ref.invalidate(watchUserTransactionsProvider(userId)),
                  child: const Text('Reessayer'),
                ),
              ],
            ),
          ),
      data: (transactions) {
        // Apply search filter
        var filtered = transactions;
        if (_searchQuery.isNotEmpty) {
          final lowerQuery = _searchQuery.toLowerCase();
          filtered =
              filtered.where((t) {
                return (t.recipientName?.toLowerCase().contains(lowerQuery) ??
                        false) ||
                    t.id.toLowerCase().contains(lowerQuery);
              }).toList();
        }

        // Apply status and date filters
        filtered =
            filtered.where((t) {
              if (_statusFilter != null && t.status != _statusFilter) {
                return false;
              }
              if (_dateFilter != null && t.createdAt != null) {
                if (t.createdAt!.isBefore(_dateFilter!.start) ||
                    t.createdAt!.isAfter(_dateFilter!.end)) {
                  return false;
                }
              }
              return true;
            }).toList();

        if (filtered.isEmpty) {
          return _buildEmptyState();
        }

        // Group by date
        final grouped = _groupByDate(filtered);

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 80),
          itemCount: grouped.length,
          itemBuilder: (context, index) {
            final date = grouped.keys.elementAt(index);
            final dayTransactions = grouped[date]!;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDateHeader(date),
                ...dayTransactions.map((t) => _buildTransactionTile(t)),
              ],
            );
          },
        );
      },
    );
  }

  Map<String, List<TransactionEntity>> _groupByDate(
    List<TransactionEntity> transactions,
  ) {
    final grouped = <String, List<TransactionEntity>>{};
    final dateFormat = DateFormat('dd MMMM yyyy', 'fr_FR');

    for (final transaction in transactions) {
      final dateKey =
          transaction.createdAt != null
              ? dateFormat.format(transaction.createdAt!)
              : l10n.adminUnknownDate;

      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(transaction);
    }

    return grouped;
  }

  Widget _buildDateHeader(String date) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        date,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: context.textSecondaryColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildTransactionTile(TransactionEntity transaction) {
    final currencyFormat = NumberFormat.currency(
      locale: 'fr_FR',
      symbol: transaction.currency,
    );
    final timeFormat = DateFormat('HH:mm', 'fr_FR');
    final statusInfo = _getStatusInfo(transaction.status);

    // Un transfert qui n'est pas arrivé montre où il en est (§16c) : la
    // frise remplace le simple badge de statut, qui ne disait pas si
    // l'argent avait bougé.
    final enCours = transaction.status == TransactionStatus.pending ||
        transaction.status == TransactionStatus.processing;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kDesignRadius),
        side: BorderSide(color: context.borderColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
      ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: statusInfo.color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(statusInfo.icon, color: statusInfo.color),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                transaction.recipientName ?? 'Beneficiaire inconnu',
                style: const TextStyle(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              currencyFormat.format(transaction.amount),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: statusInfo.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                statusInfo.label,
                style: TextStyle(
                  fontSize: 11,
                  color: statusInfo.color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (transaction.createdAt != null)
              Text(
                timeFormat.format(transaction.createdAt!),
                style: TextStyle(color: context.textTertiaryColor, fontSize: 12),
              ),
            const Spacer(),
            Text(
              '${transaction.amountInXof.toStringAsFixed(0)} XOF',
              style: TextStyle(color: context.textSecondaryColor, fontSize: 12),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/transfers/${transaction.id}'),
      ),
          if (enCours)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: _TransferProgress(status: transaction.status),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final hasFilters = _statusFilter != null || _dateFilter != null;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasFilters ? Icons.filter_list_off : Icons.receipt_long_outlined,
            size: 64,
            color: context.textTertiaryColor,
          ),
          const SizedBox(height: 16),
          Text(
            hasFilters ? 'Aucun transfert trouve' : 'Aucun transfert effectue',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: context.textSecondaryColor),
          ),
          const SizedBox(height: 8),
          Text(
            hasFilters
                ? 'Essayez de modifier vos filtres'
                : 'Envoyez de l\'argent a vos proches au Niger',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: context.textTertiaryColor),
          ),
          if (!hasFilters) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.push('/transfers/send'),
              icon: const Icon(Icons.send),
              label: const Text('Envoyer de l\'argent'),
            ),
          ],
        ],
      ),
    );
  }

  void _showFilterDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.5,
            minChildSize: 0.3,
            maxChildSize: 0.8,
            expand: false,
            builder:
                (context, scrollController) => SingleChildScrollView(
                  controller: scrollController,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              l10n.filterTransfers,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          l10n.status,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildStatusFilterChip(null, l10n.all),
                            ...TransactionStatus.values.map(
                              (status) =>
                                  _buildStatusFilterChip(status, status.label),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Periode',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildPeriodChip(null, l10n.toutes),
                            _buildPeriodChip(
                              DateTimeRange(
                                start: DateTime.now().subtract(
                                  const Duration(days: 7),
                                ),
                                end: DateTime.now(),
                              ),
                              l10n.last7Days,
                            ),
                            _buildPeriodChip(
                              DateTimeRange(
                                start: DateTime.now().subtract(
                                  const Duration(days: 30),
                                ),
                                end: DateTime.now(),
                              ),
                              l10n.last30Days,
                            ),
                            _buildPeriodChip(
                              DateTimeRange(
                                start: DateTime.now().subtract(
                                  const Duration(days: 90),
                                ),
                                end: DateTime.now(),
                              ),
                              l10n.last3Months,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final range = await showDateRangePicker(
                              context: context,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                              initialDateRange: _dateFilter,
                            );
                            if (range != null) {
                              if (!context.mounted) return;
                              setState(() => _dateFilter = range);
                              Navigator.pop(context);
                            }
                          },
                          icon: const Icon(Icons.date_range),
                          label: const Text('Choisir une periode'),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(l10n.transferApplyFilters),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ),
    );
  }

  Widget _buildStatusFilterChip(TransactionStatus? status, String label) {
    final isSelected = _statusFilter == status;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _statusFilter = selected ? status : null;
        });
      },
      selectedColor: AppColors.primary.withValues(alpha: 0.2),
      checkmarkColor: AppColors.primary,
    );
  }

  Widget _buildPeriodChip(DateTimeRange? range, String label) {
    final isSelected =
        _dateFilter?.start == range?.start && _dateFilter?.end == range?.end;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _dateFilter = selected ? range : null;
        });
        Navigator.pop(context);
      },
      selectedColor: AppColors.primary.withValues(alpha: 0.2),
      checkmarkColor: AppColors.primary,
    );
  }

  String _formatDateRange(DateTimeRange range) {
    final format = DateFormat('dd/MM', 'fr_FR');
    return '${format.format(range.start)} - ${format.format(range.end)}';
  }

  _StatusInfo _getStatusInfo(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.pending:
        return _StatusInfo(Icons.schedule, AppColors.warning, l10n.transferStatusPending);
      case TransactionStatus.processing:
        return _StatusInfo(Icons.sync, AppColors.info, l10n.transferStatusProcessing);
      case TransactionStatus.completed:
        return _StatusInfo(Icons.check_circle, AppColors.success, 'Termine');
      case TransactionStatus.failed:
        return _StatusInfo(Icons.error, AppColors.error, 'Echoue');
      case TransactionStatus.refunded:
        return _StatusInfo(Icons.replay, AppColors.info, 'Rembourse');
      case TransactionStatus.cancelled:
        return _StatusInfo(Icons.cancel, context.textTertiaryColor, 'Annule');
    }
  }
}

class _StatusInfo {
  final IconData icon;
  final Color color;
  final String label;

  _StatusInfo(this.icon, this.color, this.label);
}

/// Frise « Débité → En route → Disponible » (§16c).
///
/// Les trois jalons sont les états que le domaine connaît déjà :
/// `pending` = débité, `processing` = en route, `completed` = disponible.
/// Rien n'est inventé — un transfert échoué, remboursé ou annulé n'affiche
/// pas de frise du tout, il n'a pas de trajet à raconter.
class _TransferProgress extends StatelessWidget {
  final TransactionStatus status;

  const _TransferProgress({required this.status});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Jalon atteint : 0 = débité, 1 = en route, 2 = disponible.
    final atteint = status == TransactionStatus.processing ? 1 : 0;
    // Pas `const` : `l10n.…` est un getter résolu à l'exécution.
    final jalons = ['Débité', 'En route', l10n.adminAvailable];
    final accent = context.adaptiveSecondaryColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: List.generate(5, (i) {
            // Alternance pastille / segment de liaison.
            if (i.isOdd) {
              final franchi = atteint >= (i + 1) ~/ 2;
              return Expanded(
                child: Container(
                  height: 2,
                  color: franchi
                      ? accent
                      : context.borderColor,
                ),
              );
            }
            final index = i ~/ 2;
            final fait = index <= atteint;
            return Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: fait ? accent : context.surfaceVariantColor,
                border: Border.all(
                  color: fait ? accent : context.borderColor,
                  width: 1.5,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(jalons.length, (i) {
            final fait = i <= atteint;
            return Text(
              jalons[i],
              style: TextStyle(
                fontSize: 11,
                fontWeight: fait ? FontWeight.w600 : FontWeight.w400,
                color: fait ? context.textPrimaryColor : context.textTertiaryColor,
              ),
            );
          }),
        ),
      ],
    );
  }
}
