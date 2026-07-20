import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/payment_account_entity.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';

class PaymentAccountCard extends StatelessWidget {
  final PaymentAccountEntity account;
  final VoidCallback? onTap;

  const PaymentAccountCard({
    super.key,
    required this.account,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Card(
      elevation: account.isDefault ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: account.isDefault
            ? BorderSide(color: theme.colorScheme.primary, width: 2)
            : BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _getTypeColor(theme).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getTypeIcon(),
                  color: _getTypeColor(theme),
                ),
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
                            account.label,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (account.isDefault)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              l10n.defaultAccount,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      account.displayType,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    if (account.maskedNumber != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        account.maskedNumber!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Chevron
              AppIcon(AppIcon.chevronRight,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getTypeIcon() {
    return switch (account.type) {
      PaymentAccountType.stripeConnect => Icons.credit_card_rounded,
      PaymentAccountType.mobileMoney => Icons.phone_android_rounded,
      PaymentAccountType.bankAccount => Icons.account_balance_rounded,
    };
  }

  Color _getTypeColor(ThemeData theme) {
    return switch (account.type) {
      PaymentAccountType.stripeConnect => const Color(0xFF635BFF),
      PaymentAccountType.mobileMoney => const Color(0xFFFF6600),
      PaymentAccountType.bankAccount => theme.colorScheme.primary,
    };
  }
}
