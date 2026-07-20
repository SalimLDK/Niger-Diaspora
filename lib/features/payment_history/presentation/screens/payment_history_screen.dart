import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/adaptive_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/payment_history_item.dart';
import '../providers/payment_history_provider.dart';

class PaymentHistoryScreen extends ConsumerWidget {
  const PaymentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final currentUser = ref.watch(currentUserAsyncProvider).valueOrNull;
    final filter = ref.watch(paymentHistoryFilterProvider);

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.paymentHistory)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final historyAsync = ref.watch(paymentHistoryProvider(currentUser.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.paymentHistory),
      ),
      body: Column(
        children: [
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _FilterChip(
                  label: l10n.allTransactions,
                  selected: filter.type == null,
                  onSelected: () {
                    ref.read(paymentHistoryFilterProvider.notifier).state =
                        filter.copyWith(clearType: true);
                  },
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: l10n.tickets,
                  selected: filter.type == PaymentType.ticket,
                  onSelected: () {
                    ref.read(paymentHistoryFilterProvider.notifier).state =
                        filter.copyWith(type: PaymentType.ticket);
                  },
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: l10n.tips,
                  selected: filter.type == PaymentType.tip,
                  onSelected: () {
                    ref.read(paymentHistoryFilterProvider.notifier).state =
                        filter.copyWith(type: PaymentType.tip);
                  },
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: l10n.sales,
                  selected: filter.type == PaymentType.marketplaceOrder,
                  onSelected: () {
                    ref.read(paymentHistoryFilterProvider.notifier).state =
                        filter.copyWith(type: PaymentType.marketplaceOrder);
                  },
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: l10n.payouts,
                  selected: filter.type == PaymentType.payout,
                  onSelected: () {
                    ref.read(paymentHistoryFilterProvider.notifier).state =
                        filter.copyWith(type: PaymentType.payout);
                  },
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: historyAsync.when(
              data: (items) {
                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 64,
                          color: context.textTertiaryColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.noTransactions,
                          style: TextStyle(
                            fontSize: 16,
                            color: context.textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(paymentHistoryProvider(currentUser.id));
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      return _PaymentHistoryCard(
                        item: items[index],
                        onTap: () {
                          context.push(
                            '/payment-history/${items[index].id}',
                            extra: items[index],
                          );
                        },
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Text('${l10n.error}: $error'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        HapticFeedback.selectionClick();
        onSelected();
      },
    );
  }
}

class _PaymentHistoryCard extends StatelessWidget {
  final PaymentHistoryItem item;
  final VoidCallback? onTap;

  const _PaymentHistoryCard({required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final formatter = NumberFormat('#,###', 'fr_FR');
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final iconInfo = item.iconInfo;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: context.borderColor.withValues(alpha: 0.5),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconInfo.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  iconInfo.icon,
                  color: iconInfo.color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.description,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          dateFormat.format(item.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: context.textTertiaryColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusChip(status: item.status, l10n: l10n),
                      ],
                    ),
                  ],
                ),
              ),

              // Amount
              Text(
                '${formatter.format(item.amount)} ${item.currency}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final PaymentStatus status;
  final AppLocalizations l10n;

  const _StatusChip({required this.status, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      PaymentStatus.pending => (l10n.statusPending, const Color(0xFFFF9800)),
      PaymentStatus.processing => (l10n.statusProcessing, const Color(0xFF2196F3)),
      PaymentStatus.completed => (l10n.statusCompleted, const Color(0xFF4CAF50)),
      PaymentStatus.failed => (l10n.statusFailed, const Color(0xFFF44336)),
      PaymentStatus.cancelled => (l10n.statusCancelled, const Color(0xFF9E9E9E)),
      PaymentStatus.refunded => (l10n.statusRefunded, const Color(0xFF9C27B0)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
