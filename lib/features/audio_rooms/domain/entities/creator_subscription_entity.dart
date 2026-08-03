import 'package:equatable/equatable.dart';

import '../../../../core/services/currency_service.dart';

/// Status of a creator subscription
enum CreatorSubscriptionStatus {
  /// Subscription is active
  active,

  /// Subscription is past due (payment failed)
  pastDue,

  /// Subscription cancelled but still active until period end
  cancelledActive,

  /// Subscription has ended
  cancelled,

  /// Subscription expired
  expired,
}

/// Entity representing a subscription to a creator
class CreatorSubscriptionEntity extends Equatable {
  /// Unique identifier
  final String id;

  /// ID of the creator being subscribed to
  final String creatorId;

  /// Name of the creator
  final String creatorName;

  /// Photo URL of the creator
  final String? creatorPhotoUrl;

  /// ID of the subscriber
  final String subscriberId;

  /// Name of the subscriber
  final String subscriberName;

  /// Monthly price in cents
  final int monthlyPrice;

  /// Currency code
  final String currency;

  /// Status of the subscription
  final CreatorSubscriptionStatus status;

  /// When the subscription started
  final DateTime startedAt;

  /// Current period start date
  final DateTime currentPeriodStart;

  /// Current period end date
  final DateTime currentPeriodEnd;

  /// When the subscription was cancelled (if cancelled)
  final DateTime? cancelledAt;

  /// Stripe Subscription ID
  final String? stripeSubscriptionId;

  /// Stripe Customer ID
  final String? stripeCustomerId;

  /// Platform commission amount per month in cents (20%)
  final int commissionAmount;

  /// Creator's net amount per month in cents
  final int creatorAmount;

  /// Total amount paid so far
  final int totalPaid;

  /// Number of months subscribed
  final int monthsSubscribed;

  const CreatorSubscriptionEntity({
    required this.id,
    required this.creatorId,
    required this.creatorName,
    this.creatorPhotoUrl,
    required this.subscriberId,
    required this.subscriberName,
    required this.monthlyPrice,
    required this.currency,
    required this.status,
    required this.startedAt,
    required this.currentPeriodStart,
    required this.currentPeriodEnd,
    this.cancelledAt,
    this.stripeSubscriptionId,
    this.stripeCustomerId,
    required this.commissionAmount,
    required this.creatorAmount,
    this.totalPaid = 0,
    this.monthsSubscribed = 0,
  });

  /// Commission de la plateforme sur un abonnement créateur (20 %).
  ///
  /// ⚠ **Volontairement laissée à 20 %, contrairement aux 15 % des salons.**
  /// Aucune Edge Function ne traite les abonnements : il n'existe aucun taux
  /// serveur qui ferait foi ici, et l'écart peut être délibéré (économie
  /// différente sur du revenu récurrent). À confirmer au moment d'écrire le
  /// backend — l'aligner d'office aurait été inventer une règle métier.
  static int calculateCommission(int amount) => (amount * 0.20).round();

  /// Calculate creator amount (80%)
  static int calculateCreatorAmount(int amount) => amount - calculateCommission(amount);

  /// Whether the subscription is currently active
  bool get isActive =>
      status == CreatorSubscriptionStatus.active ||
      status == CreatorSubscriptionStatus.cancelledActive;

  /// Whether the subscription will renew
  bool get willRenew => status == CreatorSubscriptionStatus.active;

  /// Days remaining in current period
  int get daysRemaining {
    final now = DateTime.now();
    if (now.isAfter(currentPeriodEnd)) return 0;
    return currentPeriodEnd.difference(now).inDays;
  }

  /// Format price for display
  String get formattedPrice =>
      '${CurrencyService.instance.formatMinor(monthlyPrice, CurrencyExtension.fromCode(currency))}/mois';

  /// Suggested subscription prices in XOF
  static const List<int> suggestedPricesXOF = [1000, 2000, 5000, 10000];

  /// Suggested subscription prices in EUR
  static const List<int> suggestedPricesEUR = [2, 5, 10, 20];

  CreatorSubscriptionEntity copyWith({
    String? id,
    String? creatorId,
    String? creatorName,
    String? creatorPhotoUrl,
    String? subscriberId,
    String? subscriberName,
    int? monthlyPrice,
    String? currency,
    CreatorSubscriptionStatus? status,
    DateTime? startedAt,
    DateTime? currentPeriodStart,
    DateTime? currentPeriodEnd,
    DateTime? cancelledAt,
    String? stripeSubscriptionId,
    String? stripeCustomerId,
    int? commissionAmount,
    int? creatorAmount,
    int? totalPaid,
    int? monthsSubscribed,
  }) {
    return CreatorSubscriptionEntity(
      id: id ?? this.id,
      creatorId: creatorId ?? this.creatorId,
      creatorName: creatorName ?? this.creatorName,
      creatorPhotoUrl: creatorPhotoUrl ?? this.creatorPhotoUrl,
      subscriberId: subscriberId ?? this.subscriberId,
      subscriberName: subscriberName ?? this.subscriberName,
      monthlyPrice: monthlyPrice ?? this.monthlyPrice,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      currentPeriodStart: currentPeriodStart ?? this.currentPeriodStart,
      currentPeriodEnd: currentPeriodEnd ?? this.currentPeriodEnd,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      stripeSubscriptionId: stripeSubscriptionId ?? this.stripeSubscriptionId,
      stripeCustomerId: stripeCustomerId ?? this.stripeCustomerId,
      commissionAmount: commissionAmount ?? this.commissionAmount,
      creatorAmount: creatorAmount ?? this.creatorAmount,
      totalPaid: totalPaid ?? this.totalPaid,
      monthsSubscribed: monthsSubscribed ?? this.monthsSubscribed,
    );
  }

  @override
  List<Object?> get props => [
        id,
        creatorId,
        subscriberId,
        status,
        startedAt,
        currentPeriodEnd,
      ];
}
