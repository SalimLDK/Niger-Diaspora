
import '../../domain/entities/payout_entity.dart';

/// Firestore model for PayoutEntity
class PayoutModel {
  final String id;
  final String creatorId;
  final String creatorName;
  final int amount;
  final String currency;
  final String status;
  final String requestedAt;
  final String? processedAt;
  final String? completedAt;
  final String? stripeTransferId;
  final String? stripePayoutId;
  final String stripeAccountId;
  final String? errorMessage;
  final int platformFee;
  final int netAmount;
  final String? bankLast4;
  final String payoutMethod;
  final String? estimatedArrival;

  const PayoutModel({
    required this.id,
    required this.creatorId,
    required this.creatorName,
    required this.amount,
    required this.currency,
    required this.status,
    required this.requestedAt,
    this.processedAt,
    this.completedAt,
    this.stripeTransferId,
    this.stripePayoutId,
    required this.stripeAccountId,
    this.errorMessage,
    this.platformFee = 0,
    required this.netAmount,
    this.bankLast4,
    this.payoutMethod = 'bank_account',
    this.estimatedArrival,
  });

  factory PayoutModel.fromJson(Map<String, dynamic> json) {
    return PayoutModel(
      id: json['id'] as String? ?? '',
      creatorId: json['creatorId'] as String? ?? '',
      creatorName: json['creatorName'] as String? ?? '',
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      currency: json['currency'] as String? ?? 'xof',
      status: json['status'] as String? ?? 'pending',
      requestedAt: json['requestedAt'] as String? ?? DateTime.now().toIso8601String(),
      processedAt: json['processedAt'] as String?,
      completedAt: json['completedAt'] as String?,
      stripeTransferId: json['stripeTransferId'] as String?,
      stripePayoutId: json['stripePayoutId'] as String?,
      stripeAccountId: json['stripeAccountId'] as String? ?? '',
      errorMessage: json['errorMessage'] as String?,
      platformFee: (json['platformFee'] as num?)?.toInt() ?? 0,
      netAmount: (json['netAmount'] as num?)?.toInt() ?? 0,
      bankLast4: json['bankLast4'] as String?,
      payoutMethod: json['payoutMethod'] as String? ?? 'bank_account',
      estimatedArrival: json['estimatedArrival'] as String?,
    );
  }

  Map<String, dynamic> toJson() => toFirestore()..['id'] = id;

  Map<String, dynamic> toFirestore() {
    return {
      'creatorId': creatorId,
      'creatorName': creatorName,
      'amount': amount,
      'currency': currency,
      'status': status,
      'requestedAt': DateTime.now().toIso8601String(),
      'stripeAccountId': stripeAccountId,
      'platformFee': platformFee,
      'netAmount': netAmount,
      'payoutMethod': payoutMethod,
      if (processedAt != null) 'processedAt': processedAt,
      if (completedAt != null) 'completedAt': completedAt,
      if (stripeTransferId != null) 'stripeTransferId': stripeTransferId,
      if (stripePayoutId != null) 'stripePayoutId': stripePayoutId,
      if (errorMessage != null) 'errorMessage': errorMessage,
      if (bankLast4 != null) 'bankLast4': bankLast4,
      if (estimatedArrival != null) 'estimatedArrival': estimatedArrival,
    };
  }

  PayoutEntity toEntity() {
    return PayoutEntity(
      id: id,
      creatorId: creatorId,
      creatorName: creatorName,
      amount: amount,
      currency: currency,
      status: _parseStatus(status),
      requestedAt: DateTime.parse(requestedAt).toLocal(),
      processedAt: processedAt != null ? DateTime.parse(processedAt!).toLocal() : null,
      completedAt: completedAt != null ? DateTime.parse(completedAt!).toLocal() : null,
      stripeTransferId: stripeTransferId,
      stripePayoutId: stripePayoutId,
      stripeAccountId: stripeAccountId,
      errorMessage: errorMessage,
      platformFee: platformFee,
      netAmount: netAmount,
      bankLast4: bankLast4,
      payoutMethod: payoutMethod,
      estimatedArrival: estimatedArrival != null ? DateTime.parse(estimatedArrival!).toLocal() : null,
    );
  }

  static PayoutStatus _parseStatus(String status) {
    return switch (status) {
      'pending' => PayoutStatus.pending,
      'processing' => PayoutStatus.processing,
      'completed' => PayoutStatus.completed,
      'failed' => PayoutStatus.failed,
      'cancelled' => PayoutStatus.cancelled,
      _ => PayoutStatus.pending,
    };
  }

  PayoutModel copyWith({
    String? id,
    String? creatorId,
    String? creatorName,
    int? amount,
    String? currency,
    String? status,
    String? requestedAt,
    String? processedAt,
    String? completedAt,
    String? stripeTransferId,
    String? stripePayoutId,
    String? stripeAccountId,
    String? errorMessage,
    int? platformFee,
    int? netAmount,
    String? bankLast4,
    String? payoutMethod,
    String? estimatedArrival,
  }) {
    return PayoutModel(
      id: id ?? this.id,
      creatorId: creatorId ?? this.creatorId,
      creatorName: creatorName ?? this.creatorName,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      requestedAt: requestedAt ?? this.requestedAt,
      processedAt: processedAt ?? this.processedAt,
      completedAt: completedAt ?? this.completedAt,
      stripeTransferId: stripeTransferId ?? this.stripeTransferId,
      stripePayoutId: stripePayoutId ?? this.stripePayoutId,
      stripeAccountId: stripeAccountId ?? this.stripeAccountId,
      errorMessage: errorMessage ?? this.errorMessage,
      platformFee: platformFee ?? this.platformFee,
      netAmount: netAmount ?? this.netAmount,
      bankLast4: bankLast4 ?? this.bankLast4,
      payoutMethod: payoutMethod ?? this.payoutMethod,
      estimatedArrival: estimatedArrival ?? this.estimatedArrival,
    );
  }
}

/// Firestore model for Stripe Connect Account
class StripeConnectAccountModel {
  final String accountId;
  final String status;
  final bool chargesEnabled;
  final bool payoutsEnabled;
  final bool detailsSubmitted;
  final List<String> currentlyDue;
  final List<String> eventuallyDue;
  final List<String> errors;
  final String defaultCurrency;
  final String country;
  final String businessType;
  final String createdAt;
  final String? externalAccountLast4;
  final String? externalAccountBankName;

  const StripeConnectAccountModel({
    required this.accountId,
    required this.status,
    this.chargesEnabled = false,
    this.payoutsEnabled = false,
    this.detailsSubmitted = false,
    this.currentlyDue = const [],
    this.eventuallyDue = const [],
    this.errors = const [],
    this.defaultCurrency = 'xof',
    this.country = 'NE',
    this.businessType = 'individual',
    required this.createdAt,
    this.externalAccountLast4,
    this.externalAccountBankName,
  });

  factory StripeConnectAccountModel.fromMap(Map<String, dynamic> data) {
    return StripeConnectAccountModel(
      accountId: data['accountId'] as String,
      status: data['status'] as String? ?? 'none',
      chargesEnabled: data['chargesEnabled'] as bool? ?? false,
      payoutsEnabled: data['payoutsEnabled'] as bool? ?? false,
      detailsSubmitted: data['detailsSubmitted'] as bool? ?? false,
      currentlyDue: List<String>.from(data['currentlyDue'] ?? []),
      eventuallyDue: List<String>.from(data['eventuallyDue'] ?? []),
      errors: List<String>.from(data['errors'] ?? []),
      defaultCurrency: data['defaultCurrency'] as String? ?? 'xof',
      country: data['country'] as String? ?? 'NE',
      businessType: data['businessType'] as String? ?? 'individual',
      createdAt: data['createdAt'] as String? ?? '',
      externalAccountLast4: data['externalAccountLast4'] as String?,
      externalAccountBankName: data['externalAccountBankName'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'accountId': accountId,
      'status': status,
      'chargesEnabled': chargesEnabled,
      'payoutsEnabled': payoutsEnabled,
      'detailsSubmitted': detailsSubmitted,
      'currentlyDue': currentlyDue,
      'eventuallyDue': eventuallyDue,
      'errors': errors,
      'defaultCurrency': defaultCurrency,
      'country': country,
      'businessType': businessType,
      'createdAt': createdAt,
      if (externalAccountLast4 != null) 'externalAccountLast4': externalAccountLast4,
      if (externalAccountBankName != null) 'externalAccountBankName': externalAccountBankName,
    };
  }

  StripeConnectAccountEntity toEntity() {
    return StripeConnectAccountEntity(
      accountId: accountId,
      status: _parseStatus(status),
      chargesEnabled: chargesEnabled,
      payoutsEnabled: payoutsEnabled,
      detailsSubmitted: detailsSubmitted,
      currentlyDue: currentlyDue,
      eventuallyDue: eventuallyDue,
      errors: errors,
      defaultCurrency: defaultCurrency,
      country: country,
      businessType: businessType,
      createdAt: DateTime.parse(createdAt).toLocal(),
      externalAccountLast4: externalAccountLast4,
      externalAccountBankName: externalAccountBankName,
    );
  }

  static StripeAccountStatus _parseStatus(String status) {
    return switch (status) {
      'none' => StripeAccountStatus.none,
      'incomplete' => StripeAccountStatus.incomplete,
      'requires_action' => StripeAccountStatus.requiresAction,
      'restricted' => StripeAccountStatus.restricted,
      'enabled' => StripeAccountStatus.enabled,
      'disabled' => StripeAccountStatus.disabled,
      _ => StripeAccountStatus.none,
    };
  }
}
