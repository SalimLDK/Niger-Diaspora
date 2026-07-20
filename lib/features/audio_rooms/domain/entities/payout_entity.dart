import 'package:equatable/equatable.dart';

/// Status of a payout request
enum PayoutStatus {
  /// Payout request pending review
  pending,

  /// Payout is being processed
  processing,

  /// Payout completed successfully
  completed,

  /// Payout failed
  failed,

  /// Payout was cancelled
  cancelled,
}

/// Entity representing a payout request from a creator
class PayoutEntity extends Equatable {
  /// Unique identifier
  final String id;

  /// Creator's user ID
  final String creatorId;

  /// Creator's display name (denormalized)
  final String creatorName;

  /// Amount requested in cents
  final int amount;

  /// Currency code
  final String currency;

  /// Status of the payout
  final PayoutStatus status;

  /// When the payout was requested
  final DateTime requestedAt;

  /// When the payout was processed
  final DateTime? processedAt;

  /// When the payout was completed
  final DateTime? completedAt;

  /// Stripe Transfer ID (once processed)
  final String? stripeTransferId;

  /// Stripe Payout ID (once sent to bank)
  final String? stripePayoutId;

  /// Creator's Stripe Connect Account ID
  final String stripeAccountId;

  /// Error message if failed
  final String? errorMessage;

  /// Platform fee deducted (if any additional fees)
  final int platformFee;

  /// Net amount sent to creator
  final int netAmount;

  /// Bank account last 4 digits (for display)
  final String? bankLast4;

  /// Payout method (bank_account, card, instant)
  final String payoutMethod;

  /// Estimated arrival date
  final DateTime? estimatedArrival;

  const PayoutEntity({
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

  /// Whether the payout can be cancelled
  bool get canCancel => status == PayoutStatus.pending;

  /// Whether the payout is in a final state
  bool get isFinal =>
      status == PayoutStatus.completed ||
      status == PayoutStatus.failed ||
      status == PayoutStatus.cancelled;

  /// Format amount for display
  String get formattedAmount => '${(amount / 100).toStringAsFixed(2)} $currency';

  /// Format net amount for display
  String get formattedNetAmount => '${(netAmount / 100).toStringAsFixed(2)} $currency';

  /// Status label in French
  String get statusLabel => switch (status) {
        PayoutStatus.pending => 'En attente',
        PayoutStatus.processing => 'En cours',
        PayoutStatus.completed => 'Terminé',
        PayoutStatus.failed => 'Échoué',
        PayoutStatus.cancelled => 'Annulé',
      };

  PayoutEntity copyWith({
    String? id,
    String? creatorId,
    String? creatorName,
    int? amount,
    String? currency,
    PayoutStatus? status,
    DateTime? requestedAt,
    DateTime? processedAt,
    DateTime? completedAt,
    String? stripeTransferId,
    String? stripePayoutId,
    String? stripeAccountId,
    String? errorMessage,
    int? platformFee,
    int? netAmount,
    String? bankLast4,
    String? payoutMethod,
    DateTime? estimatedArrival,
  }) {
    return PayoutEntity(
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

  @override
  List<Object?> get props => [
        id,
        creatorId,
        amount,
        status,
        requestedAt,
      ];
}

/// Stripe Connect account status
enum StripeAccountStatus {
  /// Account not created yet
  none,

  /// Onboarding started but not complete
  incomplete,

  /// Account requires additional information
  requiresAction,

  /// Account is restricted (limited functionality)
  restricted,

  /// Account is fully enabled
  enabled,

  /// Account is disabled/rejected
  disabled,
}

/// Entity representing a creator's Stripe Connect account
class StripeConnectAccountEntity extends Equatable {
  /// Stripe Connect Account ID
  final String accountId;

  /// Account status
  final StripeAccountStatus status;

  /// Whether charges are enabled
  final bool chargesEnabled;

  /// Whether payouts are enabled
  final bool payoutsEnabled;

  /// Whether details have been submitted
  final bool detailsSubmitted;

  /// Requirements that need to be filled
  final List<String> currentlyDue;

  /// Requirements that will be needed eventually
  final List<String> eventuallyDue;

  /// Errors on the account
  final List<String> errors;

  /// Default currency for the account
  final String defaultCurrency;

  /// Country of the account
  final String country;

  /// Business type (individual, company)
  final String businessType;

  /// When the account was created
  final DateTime createdAt;

  /// External account info (bank/card)
  final String? externalAccountLast4;
  final String? externalAccountBankName;

  const StripeConnectAccountEntity({
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

  /// Whether the account is fully set up and can receive payouts
  bool get isFullyEnabled => chargesEnabled && payoutsEnabled && detailsSubmitted;

  /// Whether onboarding needs to continue
  bool get needsOnboarding => !detailsSubmitted || currentlyDue.isNotEmpty;

  /// Status label in French
  String get statusLabel => switch (status) {
        StripeAccountStatus.none => 'Non configuré',
        StripeAccountStatus.incomplete => 'Configuration incomplète',
        StripeAccountStatus.requiresAction => 'Action requise',
        StripeAccountStatus.restricted => 'Restreint',
        StripeAccountStatus.enabled => 'Activé',
        StripeAccountStatus.disabled => 'Désactivé',
      };

  @override
  List<Object?> get props => [
        accountId,
        status,
        chargesEnabled,
        payoutsEnabled,
      ];
}

/// Fallback payout limits by currency (in cents)
///
/// NOTE: Prefer using AudioRoomsSettingsEntity.getMinPayoutAmount() and
/// AudioRoomsSettingsEntity.getMaxPayoutAmount() which are configurable via admin settings.
/// This class provides fallback/default values.
class PayoutLimits {
  static const Map<String, int> minimumPayout = {
    'XOF': 500000,    // 5,000 XOF
    'EUR': 1000,      // 10 EUR
    'USD': 1000,      // 10 USD
    'GBP': 1000,      // 10 GBP
    'CAD': 1500,      // 15 CAD
    'CHF': 1000,      // 10 CHF
  };

  static const Map<String, int> maximumPayout = {
    'XOF': 100000000, // 1,000,000 XOF
    'EUR': 1000000,   // 10,000 EUR
    'USD': 1000000,   // 10,000 USD
    'GBP': 1000000,   // 10,000 GBP
    'CAD': 1500000,   // 15,000 CAD
    'CHF': 1000000,   // 10,000 CHF
  };

  /// Get minimum payout for a currency (fallback values)
  static int getMinimum(String currency) =>
      minimumPayout[currency.toUpperCase()] ?? 1000;

  /// Get maximum payout for a currency (fallback values)
  static int getMaximum(String currency) =>
      maximumPayout[currency.toUpperCase()] ?? 1000000;

  /// Check if amount meets minimum (using fallback values)
  static bool meetsMinimum(int amount, String currency) =>
      amount >= getMinimum(currency);

  /// Check if amount is within limits (using fallback values)
  static bool isWithinLimits(int amount, String currency) =>
      amount >= getMinimum(currency) && amount <= getMaximum(currency);
}
