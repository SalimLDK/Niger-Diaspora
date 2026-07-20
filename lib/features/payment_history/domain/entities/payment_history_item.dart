import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

enum PaymentType {
  ticket,
  tip,
  marketplaceOrder,
  payout,
  transfer,
}

enum PaymentStatus {
  pending,
  processing,
  completed,
  failed,
  cancelled,
  refunded,
}

class PaymentHistoryItem {
  final String id;
  final PaymentType type;
  final PaymentStatus status;
  final int amount;
  final String currency;
  final int? commissionAmount;
  final int? netAmount;
  final String description;
  final String? counterpartyName;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? reference;

  const PaymentHistoryItem({
    required this.id,
    required this.type,
    required this.status,
    required this.amount,
    required this.currency,
    this.commissionAmount,
    this.netAmount,
    required this.description,
    this.counterpartyName,
    required this.createdAt,
    this.completedAt,
    this.reference,
  });

  factory PaymentHistoryItem.fromMap(Map<String, dynamic> data) {
    return PaymentHistoryItem(
      id: data['id'] as String? ?? '',
      type: PaymentType.values.firstWhere(
        (t) => t.name == data['type'],
        orElse: () => PaymentType.ticket,
      ),
      status: PaymentStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => PaymentStatus.pending,
      ),
      amount: (data['amount'] as num?)?.toInt() ?? 0,
      currency: data['currency'] as String? ?? 'XOF',
      commissionAmount: (data['commissionAmount'] as num?)?.toInt(),
      netAmount: (data['netAmount'] as num?)?.toInt(),
      description: data['description'] as String? ?? '',
      counterpartyName: data['counterpartyName'] as String?,
      createdAt: data['createdAt'] != null
          ? DateTime.parse(data['createdAt'] as String)
          : DateTime.now(),
      completedAt: data['completedAt'] != null
          ? DateTime.parse(data['completedAt'] as String)
          : null,
      reference: data['reference'] as String?,
    );
  }

  String get displayType {
    return switch (type) {
      PaymentType.ticket => 'Ticket',
      PaymentType.tip => 'Tip',
      PaymentType.marketplaceOrder => 'Vente',
      PaymentType.payout => 'Versement',
      PaymentType.transfer => 'Transfert',
    };
  }

  /// Returns the localized display type using l10n.
  String localizedDisplayType(AppLocalizations l10n) {
    return switch (type) {
      PaymentType.ticket => l10n.paymentTypeTicket,
      PaymentType.tip => l10n.paymentTypeTip,
      PaymentType.marketplaceOrder => l10n.paymentTypeSale,
      PaymentType.payout => l10n.paymentTypePayout,
      PaymentType.transfer => l10n.paymentTypeTransfer,
    };
  }

  IconInfo get iconInfo {
    return switch (type) {
      PaymentType.ticket => IconInfo.ticket,
      PaymentType.tip => IconInfo.tip,
      PaymentType.marketplaceOrder => IconInfo.marketplaceOrder,
      PaymentType.payout => IconInfo.payout,
      PaymentType.transfer => IconInfo.transfer,
    };
  }
}

class IconInfo {
  final IconData icon;
  final Color color;

  const IconInfo(this.icon, this.color);

  // Static constants for tree-shaking support
  static const ticket = IconInfo(Icons.confirmation_number, Color(0xFF4CAF50));
  static const tip = IconInfo(Icons.volunteer_activism, Color(0xFFFF9800));
  static const marketplaceOrder = IconInfo(Icons.shopping_bag, Color(0xFF2196F3));
  static const payout = IconInfo(Icons.account_balance, Color(0xFF9C27B0));
  static const transfer = IconInfo(Icons.swap_horiz, Color(0xFF607D8B));
}
