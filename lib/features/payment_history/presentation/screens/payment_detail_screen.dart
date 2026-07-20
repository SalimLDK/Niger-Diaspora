import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:go_router/go_router.dart';

import '../../../../core/theme/adaptive_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/payment_history_item.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';

class PaymentDetailScreen extends ConsumerWidget {
  final PaymentHistoryItem item;

  const PaymentDetailScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final formatter = NumberFormat('#,###', 'fr_FR');
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final iconInfo = item.iconInfo;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.transactionDetail),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Icon & Status
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: iconInfo.color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                iconInfo.icon,
                size: 48,
                color: iconInfo.color,
              ),
            ),
            const SizedBox(height: 16),

            // Amount
            Text(
              '${formatter.format(item.amount)} ${item.currency}',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // Status chip
            _buildStatusChip(item.status, l10n),
            const SizedBox(height: 32),

            // Details card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.surfaceColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: context.borderColor.withValues(alpha: 0.5),
                ),
              ),
              child: Column(
                children: [
                  _buildDetailRow(
                    l10n.paymentAccountType,
                    item.localizedDisplayType(l10n),
                    context,
                  ),
                  const Divider(height: 24),
                  _buildDetailRow(
                    l10n.descriptionLabel,
                    item.description,
                    context,
                  ),
                  if (item.counterpartyName != null) ...[
                    const Divider(height: 24),
                    _buildDetailRow(
                      l10n.counterparty,
                      item.counterpartyName!,
                      context,
                    ),
                  ],
                  if (item.commissionAmount != null) ...[
                    const Divider(height: 24),
                    _buildDetailRow(
                      l10n.commission,
                      '${formatter.format(item.commissionAmount)} ${item.currency}',
                      context,
                    ),
                  ],
                  if (item.netAmount != null) ...[
                    const Divider(height: 24),
                    _buildDetailRow(
                      l10n.netAmount,
                      '${formatter.format(item.netAmount)} ${item.currency}',
                      context,
                      isBold: true,
                    ),
                  ],
                  const Divider(height: 24),
                  _buildDetailRow(
                    l10n.dateLabel,
                    dateFormat.format(item.createdAt),
                    context,
                  ),
                  if (item.completedAt != null) ...[
                    const Divider(height: 24),
                    _buildDetailRow(
                      l10n.completedOn,
                      dateFormat.format(item.completedAt!),
                      context,
                    ),
                  ],
                  if (item.reference != null) ...[
                    const Divider(height: 24),
                    _buildDetailRow(
                      l10n.referenceLabel,
                      item.reference!,
                      context,
                      canCopy: true,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Report issue button
            OutlinedButton.icon(
              onPressed: () {
                final localizedType = item.localizedDisplayType(l10n);
                final subject = l10n.reportTransactionSubject(item.id, localizedType);
                final description =
                    '${l10n.reportTransactionIntro}\n'
                    '- ID : ${item.id}\n'
                    '- ${l10n.paymentAccountType} : $localizedType\n'
                    '- ${l10n.grossAmount} : ${formatter.format(item.amount)} ${item.currency}\n'
                    '- ${l10n.dateLabel} : ${dateFormat.format(item.createdAt)}\n'
                    '- Status : ${_localizedStatus(item.status, l10n)}\n'
                    '${item.reference != null ? '- ${l10n.referenceLabel} : ${item.reference}\n' : ''}';
                context.push(
                  '/support/new',
                  extra: {
                    'subject': subject,
                    'description': description,
                    'transactionId': item.id,
                  },
                );
              },
              icon: AppIcon(AppIcon.flag, color: Theme.of(context).iconTheme.color!),
              label: Text(l10n.reportIssue),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(PaymentStatus status, AppLocalizations l10n) {
    final (label, color) = switch (status) {
      PaymentStatus.pending => (l10n.statusPending, const Color(0xFFFF9800)),
      PaymentStatus.processing => (l10n.statusProcessing, const Color(0xFF2196F3)),
      PaymentStatus.completed => (l10n.statusCompleted, const Color(0xFF4CAF50)),
      PaymentStatus.failed => (l10n.statusFailed, const Color(0xFFF44336)),
      PaymentStatus.cancelled => (l10n.statusCancelled, const Color(0xFF9E9E9E)),
      PaymentStatus.refunded => (l10n.statusRefunded, const Color(0xFF9C27B0)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  String _localizedStatus(PaymentStatus status, AppLocalizations l10n) {
    return switch (status) {
      PaymentStatus.pending => l10n.statusPending,
      PaymentStatus.processing => l10n.statusProcessing,
      PaymentStatus.completed => l10n.statusCompleted,
      PaymentStatus.failed => l10n.statusFailed,
      PaymentStatus.cancelled => l10n.statusCancelled,
      PaymentStatus.refunded => l10n.statusRefunded,
    };
  }

  Widget _buildDetailRow(
    String label,
    String value,
    BuildContext context, {
    bool isBold = false,
    bool canCopy = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: context.textSecondaryColor,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: GestureDetector(
            onTap: canCopy
                ? () {
                    Clipboard.setData(ClipboardData(text: value));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(AppLocalizations.of(context)!.copied)),
                    );
                  }
                : null,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                      color: context.textPrimaryColor,
                    ),
                    textAlign: TextAlign.end,
                  ),
                ),
                if (canCopy) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.copy,
                    size: 14,
                    color: context.textTertiaryColor,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
