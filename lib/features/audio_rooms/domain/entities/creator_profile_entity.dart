import 'package:equatable/equatable.dart';

/// Entity representing a creator's monetization profile
class CreatorProfileEntity extends Equatable {
  /// User ID
  final String userId;

  /// Display name
  final String displayName;

  /// Photo URL
  final String? photoUrl;

  /// Bio/description
  final String? bio;

  /// Whether monetization is enabled
  final bool isMonetizationEnabled;

  /// Monthly subscription price in cents (0 = not offering subscriptions)
  final int subscriptionPrice;

  /// Currency for subscription
  final String subscriptionCurrency;

  /// Total number of subscribers
  final int subscriberCount;

  /// Total earnings from subscriptions (all time) in cents
  final int totalSubscriptionEarnings;

  /// Total earnings from tips (all time) in cents
  final int totalTipEarnings;

  /// Total earnings from ticket sales (all time) in cents
  final int totalTicketEarnings;

  /// Total earnings from replay sales (all time) in cents
  final int totalReplayEarnings;

  /// Current month earnings in cents
  final int currentMonthEarnings;

  /// Available balance for payout in cents
  final int availableBalance;

  /// Stripe Connect Account ID
  final String? stripeAccountId;

  /// Whether Stripe account is fully set up
  final bool isStripeAccountComplete;

  /// When the creator profile was created
  final DateTime createdAt;

  /// Total rooms hosted
  final int totalRoomsHosted;

  /// Total room hours hosted
  final int totalHoursHosted;

  /// Average room rating (0-5)
  final double averageRating;

  /// Total ratings received
  final int totalRatings;

  const CreatorProfileEntity({
    required this.userId,
    required this.displayName,
    this.photoUrl,
    this.bio,
    this.isMonetizationEnabled = false,
    this.subscriptionPrice = 0,
    this.subscriptionCurrency = 'XOF',
    this.subscriberCount = 0,
    this.totalSubscriptionEarnings = 0,
    this.totalTipEarnings = 0,
    this.totalTicketEarnings = 0,
    this.totalReplayEarnings = 0,
    this.currentMonthEarnings = 0,
    this.availableBalance = 0,
    this.stripeAccountId,
    this.isStripeAccountComplete = false,
    required this.createdAt,
    this.totalRoomsHosted = 0,
    this.totalHoursHosted = 0,
    this.averageRating = 0.0,
    this.totalRatings = 0,
  });

  /// Total all-time earnings
  int get totalEarnings =>
      totalSubscriptionEarnings +
      totalTipEarnings +
      totalTicketEarnings +
      totalReplayEarnings;

  /// Whether the creator is offering subscriptions
  bool get hasSubscription => subscriptionPrice > 0;

  /// Whether the creator can receive payouts
  bool get canReceivePayouts => isMonetizationEnabled && isStripeAccountComplete;

  /// Format subscription price for display
  String get formattedSubscriptionPrice =>
      hasSubscription ? '${(subscriptionPrice / 100).toStringAsFixed(0)} $subscriptionCurrency/mois' : 'Non disponible';

  /// Format total earnings for display
  String formatEarnings(int amount, String currency) =>
      '${(amount / 100).toStringAsFixed(0)} $currency';

  CreatorProfileEntity copyWith({
    String? userId,
    String? displayName,
    String? photoUrl,
    String? bio,
    bool? isMonetizationEnabled,
    int? subscriptionPrice,
    String? subscriptionCurrency,
    int? subscriberCount,
    int? totalSubscriptionEarnings,
    int? totalTipEarnings,
    int? totalTicketEarnings,
    int? totalReplayEarnings,
    int? currentMonthEarnings,
    int? availableBalance,
    String? stripeAccountId,
    bool? isStripeAccountComplete,
    DateTime? createdAt,
    int? totalRoomsHosted,
    int? totalHoursHosted,
    double? averageRating,
    int? totalRatings,
  }) {
    return CreatorProfileEntity(
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      bio: bio ?? this.bio,
      isMonetizationEnabled: isMonetizationEnabled ?? this.isMonetizationEnabled,
      subscriptionPrice: subscriptionPrice ?? this.subscriptionPrice,
      subscriptionCurrency: subscriptionCurrency ?? this.subscriptionCurrency,
      subscriberCount: subscriberCount ?? this.subscriberCount,
      totalSubscriptionEarnings: totalSubscriptionEarnings ?? this.totalSubscriptionEarnings,
      totalTipEarnings: totalTipEarnings ?? this.totalTipEarnings,
      totalTicketEarnings: totalTicketEarnings ?? this.totalTicketEarnings,
      totalReplayEarnings: totalReplayEarnings ?? this.totalReplayEarnings,
      currentMonthEarnings: currentMonthEarnings ?? this.currentMonthEarnings,
      availableBalance: availableBalance ?? this.availableBalance,
      stripeAccountId: stripeAccountId ?? this.stripeAccountId,
      isStripeAccountComplete: isStripeAccountComplete ?? this.isStripeAccountComplete,
      createdAt: createdAt ?? this.createdAt,
      totalRoomsHosted: totalRoomsHosted ?? this.totalRoomsHosted,
      totalHoursHosted: totalHoursHosted ?? this.totalHoursHosted,
      averageRating: averageRating ?? this.averageRating,
      totalRatings: totalRatings ?? this.totalRatings,
    );
  }

  @override
  List<Object?> get props => [
        userId,
        isMonetizationEnabled,
        subscriberCount,
        totalEarnings,
        availableBalance,
      ];
}
