import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/adaptive_colors.dart';
import '../../../../shared/widgets/sheet_handle.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/payment_account_entity.dart';
import '../providers/payment_account_provider.dart';
import '../widgets/payment_account_card.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';

class PaymentAccountsScreen extends ConsumerWidget {
  const PaymentAccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final currentUser = ref.watch(currentUserAsyncProvider).valueOrNull;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.paymentAccounts)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final accountsAsync = ref.watch(paymentAccountsProvider(currentUser.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.paymentAccounts),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/payment-accounts/add'),
        icon: AppIcon(AppIcon.add, color: Theme.of(context).iconTheme.color!),
        label: Text(l10n.addPaymentAccount),
      ),
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppIcon(AppIcon.error, size: 48, color: context.errorColor),
              const SizedBox(height: 16),
              Text('${l10n.error}: $error'),
            ],
          ),
        ),
        data: (accounts) {
          if (accounts.isEmpty) {
            return _buildEmptyState(context, l10n, theme);
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: accounts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final account = accounts[index];
              return PaymentAccountCard(
                account: account,
                onTap: () => _showAccountOptions(
                  context,
                  ref,
                  account,
                  currentUser.id,
                  l10n,
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 80,
              color: theme.colorScheme.primary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.noPaymentAccounts,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.paymentAccountRequired,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.push('/payment-accounts/add'),
              icon: AppIcon(AppIcon.add, color: Theme.of(context).iconTheme.color!),
              label: Text(l10n.addPaymentAccount),
            ),
          ],
        ),
      ),
    );
  }

  void _showAccountOptions(
    BuildContext context,
    WidgetRef ref,
    PaymentAccountEntity account,
    String userId,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: SheetHandle(),
            ),
            const SizedBox(height: 16),
            Text(
              account.label,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (!account.isDefault)
              ListTile(
                leading: AppIcon(AppIcon.starBorder, color: theme.iconTheme.color),
                title: Text(l10n.setAsDefault),
                onTap: () {
                  Navigator.pop(sheetContext);
                  ref
                      .read(paymentAccountNotifierProvider.notifier)
                      .setDefault(userId, account.id);
                },
              ),
            ListTile(
              leading: AppIcon(AppIcon.delete, color: theme.colorScheme.error),
              title: Text(
                l10n.deletePaymentAccount,
                style: TextStyle(color: theme.colorScheme.error),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _confirmDelete(context, ref, account, userId, l10n);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    PaymentAccountEntity account,
    String userId,
    AppLocalizations l10n,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.deletePaymentAccount),
        content: Text('${l10n.confirmDeletePaymentAccount}\n\n"${account.label}"'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              ref
                  .read(paymentAccountNotifierProvider.notifier)
                  .deleteAccount(userId, account.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.accountDeleted)),
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }
}
