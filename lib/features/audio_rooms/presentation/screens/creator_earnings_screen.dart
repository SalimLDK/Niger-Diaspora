import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/payout_entity.dart';
import '../providers/monetization_provider.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';
import 'package:diaspo_niger/core/errors/error_handler.dart';

/// Screen for creators to view their earnings and request payouts.
class CreatorEarningsScreen extends ConsumerStatefulWidget {
  const CreatorEarningsScreen({super.key});

  @override
  ConsumerState<CreatorEarningsScreen> createState() =>
      _CreatorEarningsScreenState();
}

class _CreatorEarningsScreenState extends ConsumerState<CreatorEarningsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(monetizationNotifierProvider.notifier).getOrCreateCreatorProfile();
      ref.read(monetizationNotifierProvider.notifier).getCreatorEarnings();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final monetizationState = ref.watch(monetizationNotifierProvider);
    final currentUser = ref.watch(currentUserAsyncProvider).valueOrNull;
    final theme = Theme.of(context);

    final payoutsAsync = currentUser != null
        ? ref.watch(creatorPayoutsProvider(currentUser.id))
        : const AsyncData(<PayoutEntity>[]);

    final profile = monetizationState.creatorProfile;
    final earnings = monetizationState.earnings;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.creatorEarningsTitle),
        actions: [
          IconButton(
            icon: AppIcon(AppIcon.refresh, color: theme.iconTheme.color!),
            onPressed: () {
              ref
                  .read(monetizationNotifierProvider.notifier)
                  .getCreatorEarnings();
              ref
                  .read(stripeConnectNotifierProvider.notifier)
                  .refreshAccountStatus();
            },
          ),
        ],
      ),
      body: monetizationState.isLoading && profile == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await ref
                    .read(monetizationNotifierProvider.notifier)
                    .getCreatorEarnings();
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Balance card
                  _BalanceCard(
                    availableBalance: profile?.availableBalance ?? 0,
                    currency: profile?.subscriptionCurrency ?? 'XOF',
                    isStripeReady: profile?.isStripeAccountComplete ?? false,
                  ),
                  const SizedBox(height: 16),

                  // Earnings breakdown
                  if (earnings != null) ...[
                    _EarningsBreakdown(earnings: earnings),
                    const SizedBox(height: 16),
                  ],

                  // Stripe Connect section
                  _StripeConnectSection(
                    stripeAccountId: profile?.stripeAccountId,
                    isComplete: profile?.isStripeAccountComplete ?? false,
                  ),
                  const SizedBox(height: 16),

                  // Payout history
                  Text(
                    l10n.payoutHistoryTitle,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  payoutsAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text(
                      ErrorHandler.instance.getShortMessage(
                        ErrorHandler.instance.handleException(e),
                      ),
                    ),
                    data: (payouts) {
                      if (payouts.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              l10n.noWithdrawalsYet,
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ),
                        );
                      }
                      return Column(
                        children: payouts
                            .map((p) => _PayoutTile(payout: p))
                            .toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }
}

class _BalanceCard extends ConsumerWidget {
  final int availableBalance;
  final String currency;
  final bool isStripeReady;

  const _BalanceCard({
    required this.availableBalance,
    required this.currency,
    required this.isStripeReady,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payoutState = ref.watch(payoutNotifierProvider);
    final balanceFormatted = (availableBalance / 100).toStringAsFixed(2);

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.availableBalance,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '$balanceFormatted $currency',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: availableBalance > 0
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey,
                  ),
            ),
            const SizedBox(height: 16),
            if (payoutState.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  payoutState.error!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: availableBalance > 0 && isStripeReady
                    ? () => _showPayoutDialog(context, ref)
                    : null,
                icon: payoutState.isRequesting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.account_balance_wallet),
                label: Text(
                  payoutState.isRequesting
                      ? AppLocalizations.of(context)!.processingEllipsis
                      : AppLocalizations.of(context)!.withdrawEarnings,
                ),
              ),
            ),
            if (!isStripeReady)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  AppLocalizations.of(context)!.stripeConnectRequired,
                  style: TextStyle(color: Colors.orange[700], fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showPayoutDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(ctx)!.withdrawalRequestTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${AppLocalizations.of(ctx)!.availableBalance}: ${(availableBalance / 100).toStringAsFixed(2)} $currency',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(ctx)!.withdrawalAmountLabel,
                suffix: Text(currency),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(ctx)!.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              final value = double.tryParse(controller.text.trim());
              if (value == null || value <= 0) return;
              final amountCents = (value * 100).round();
              Navigator.pop(ctx);
              await ref.read(payoutNotifierProvider.notifier).requestPayout(
                    amount: amountCents,
                    currency: currency,
                  );
            },
            child: Text(AppLocalizations.of(ctx)!.confirm),
          ),
        ],
      ),
    );
  }
}

class _EarningsBreakdown extends StatelessWidget {
  final Map<String, int> earnings;

  const _EarningsBreakdown({required this.earnings});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    String fmt(int cents) => (cents / 100).toStringAsFixed(2);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.earningsBreakdown,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _EarningRow(
              label: l10n.tipEarningsLabel,
              icon: Icons.favorite,
              color: Colors.pinkAccent,
              value: fmt(earnings['tips'] ?? 0),
            ),
            _EarningRow(
              label: l10n.ticketEarningsLabel,
              icon: Icons.confirmation_num,
              color: Colors.deepPurple,
              value: fmt(earnings['tickets'] ?? 0),
            ),
            _EarningRow(
              label: l10n.subscriptionEarningsLabel,
              icon: Icons.star,
              color: Colors.amber,
              value: fmt(earnings['subscriptions'] ?? 0),
            ),
            _EarningRow(
              label: l10n.replayEarningsLabel,
              icon: Icons.replay,
              color: Colors.teal,
              value: fmt(earnings['replays'] ?? 0),
            ),
            const Divider(),
            _EarningRow(
              label: l10n.totalLabel,
              icon: Icons.account_balance,
              color: Theme.of(context).colorScheme.primary,
              value: fmt(earnings['total'] ?? 0),
              bold: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _EarningRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final String value;
  final bool bold;

  const _EarningRow({
    required this.label,
    required this.icon,
    required this.color,
    required this.value,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: bold ? Theme.of(context).colorScheme.primary : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _StripeConnectSection extends ConsumerWidget {
  final String? stripeAccountId;
  final bool isComplete;

  const _StripeConnectSection({
    required this.stripeAccountId,
    required this.isComplete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectState = ref.watch(stripeConnectNotifierProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                isComplete
                    ? const AppIcon(AppIcon.checkCircle, color: Colors.green, size: 20)
                    : const AppIcon(AppIcon.warning, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context)!.stripeConnectAccount,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isComplete
                  ? AppLocalizations.of(context)!.stripeAccountActive
                  : stripeAccountId != null
                      ? AppLocalizations.of(context)!.incompleteStripeConfig
                      : AppLocalizations.of(context)!.createStripePrompt,
              style: TextStyle(color: Colors.grey[700], fontSize: 13),
            ),
            if (connectState.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  connectState.error!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            const SizedBox(height: 12),
            if (isComplete)
              OutlinedButton.icon(
                onPressed: connectState.isLoading
                    ? null
                    : () async {
                        final url = await ref
                            .read(stripeConnectNotifierProvider.notifier)
                            .getDashboardLink();
                        if (url != null) {
                          await launchUrl(
                            Uri.parse(url),
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      },
                icon: connectState.isLoading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.open_in_new),
                label: Text(AppLocalizations.of(context)!.stripeDashboardButton),
              )
            else
              ElevatedButton.icon(
                onPressed: connectState.isLoading
                    ? null
                    : () async {
                        final url = stripeAccountId != null
                            ? await ref
                                .read(stripeConnectNotifierProvider.notifier)
                                .continueOnboarding()
                            : await ref
                                .read(stripeConnectNotifierProvider.notifier)
                                .startOnboarding();
                        if (url != null) {
                          await launchUrl(
                            Uri.parse(url),
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      },
                icon: connectState.isLoading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : AppIcon(AppIcon.bank, color: isComplete ? Colors.green : Colors.orange),
                label: Text(
                  stripeAccountId != null
                      ? AppLocalizations.of(context)!.continueSetupButton
                      : AppLocalizations.of(context)!.createStripeButton,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PayoutTile extends StatelessWidget {
  final PayoutEntity payout;

  const _PayoutTile({required this.payout});

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (payout.status) {
      PayoutStatus.completed => Colors.green,
      PayoutStatus.failed => Colors.red,
      PayoutStatus.cancelled => Colors.grey,
      PayoutStatus.processing => Colors.blue,
      PayoutStatus.pending => Colors.orange,
    };

    final l10n = AppLocalizations.of(context)!;
    final statusLabel = switch (payout.status) {
      PayoutStatus.completed => l10n.statusCompleted,
      PayoutStatus.failed => l10n.statusFailed,
      PayoutStatus.cancelled => l10n.statusCancelled,
      PayoutStatus.processing => l10n.statusProcessing,
      PayoutStatus.pending => l10n.statusPending,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.15),
          child: Icon(Icons.account_balance_wallet, color: statusColor),
        ),
        title: Text(
          '${(payout.amount / 100).toStringAsFixed(2)} ${payout.currency}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${payout.requestedAt.day}/${payout.requestedAt.month}/${payout.requestedAt.year}',
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            statusLabel,
            style: TextStyle(
              color: statusColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
