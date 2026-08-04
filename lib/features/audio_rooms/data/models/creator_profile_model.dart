import 'package:equatable/equatable.dart';

import '../../domain/entities/creator_profile_entity.dart';

class CreatorProfileModel extends Equatable {
  final String id;
  final String userId;
  final String displayName;
  final String? photoUrl;
  final String? bio;
  final bool isMonetizationEnabled;
  final int subscriptionPrice;
  final String subscriptionCurrency;
  final int subscriberCount;
  final int totalSubscriptionEarnings;
  final int totalTipEarnings;
  final int totalTicketEarnings;
  final int totalReplayEarnings;
  final int currentMonthEarnings;
  final int availableBalance;
  final String? stripeAccountId;
  final bool isStripeAccountComplete;
  final String? createdAt;
  final int totalRoomsHosted;
  final int totalHoursHosted;
  final double averageRating;
  final int totalRatings;

  const CreatorProfileModel({
    this.id = '',
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
    this.createdAt,
    this.totalRoomsHosted = 0,
    this.totalHoursHosted = 0,
    this.averageRating = 0.0,
    this.totalRatings = 0,
  });

  factory CreatorProfileModel.fromJson(Map<String, dynamic> json) {
    return CreatorProfileModel(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      photoUrl: json['photoUrl'] as String?,
      bio: json['bio'] as String?,
      isMonetizationEnabled: json['isMonetizationEnabled'] as bool? ?? false,
      subscriptionPrice: json['subscriptionPrice'] as int? ?? 0,
      subscriptionCurrency: json['subscriptionCurrency'] as String? ?? 'XOF',
      subscriberCount: json['subscriberCount'] as int? ?? 0,
      totalSubscriptionEarnings: json['totalSubscriptionEarnings'] as int? ?? 0,
      totalTipEarnings: json['totalTipEarnings'] as int? ?? 0,
      totalTicketEarnings: json['totalTicketEarnings'] as int? ?? 0,
      totalReplayEarnings: json['totalReplayEarnings'] as int? ?? 0,
      currentMonthEarnings: json['currentMonthEarnings'] as int? ?? 0,
      availableBalance: json['availableBalance'] as int? ?? 0,
      stripeAccountId: json['stripeAccountId'] as String?,
      isStripeAccountComplete: json['isStripeAccountComplete'] as bool? ?? false,
      createdAt: _timestampToString(json['createdAt']),
      totalRoomsHosted: json['totalRoomsHosted'] as int? ?? 0,
      totalHoursHosted: json['totalHoursHosted'] as int? ?? 0,
      averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0.0,
      totalRatings: json['totalRatings'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'bio': bio,
      'isMonetizationEnabled': isMonetizationEnabled,
      'subscriptionPrice': subscriptionPrice,
      'subscriptionCurrency': subscriptionCurrency,
      'subscriberCount': subscriberCount,
      'totalSubscriptionEarnings': totalSubscriptionEarnings,
      'totalTipEarnings': totalTipEarnings,
      'totalTicketEarnings': totalTicketEarnings,
      'totalReplayEarnings': totalReplayEarnings,
      'currentMonthEarnings': currentMonthEarnings,
      'availableBalance': availableBalance,
      'stripeAccountId': stripeAccountId,
      'isStripeAccountComplete': isStripeAccountComplete,
      'createdAt': createdAt,
      'totalRoomsHosted': totalRoomsHosted,
      'totalHoursHosted': totalHoursHosted,
      'averageRating': averageRating,
      'totalRatings': totalRatings,
    };
  }
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'bio': bio,
      'isMonetizationEnabled': isMonetizationEnabled,
      'subscriptionPrice': subscriptionPrice,
      'subscriptionCurrency': subscriptionCurrency,
      'subscriberCount': subscriberCount,
      'totalSubscriptionEarnings': totalSubscriptionEarnings,
      'totalTipEarnings': totalTipEarnings,
      'totalTicketEarnings': totalTicketEarnings,
      'totalReplayEarnings': totalReplayEarnings,
      'currentMonthEarnings': currentMonthEarnings,
      'availableBalance': availableBalance,
      'stripeAccountId': stripeAccountId,
      'isStripeAccountComplete': isStripeAccountComplete,
      'createdAt': createdAt ?? DateTime.now().toIso8601String(),
      'totalRoomsHosted': totalRoomsHosted,
      'totalHoursHosted': totalHoursHosted,
      'averageRating': averageRating,
      'totalRatings': totalRatings,
    };
  }

  CreatorProfileEntity toEntity() {
    return CreatorProfileEntity(
      userId: userId,
      displayName: displayName,
      photoUrl: photoUrl,
      bio: bio,
      isMonetizationEnabled: isMonetizationEnabled,
      subscriptionPrice: subscriptionPrice,
      subscriptionCurrency: subscriptionCurrency,
      subscriberCount: subscriberCount,
      totalSubscriptionEarnings: totalSubscriptionEarnings,
      totalTipEarnings: totalTipEarnings,
      totalTicketEarnings: totalTicketEarnings,
      totalReplayEarnings: totalReplayEarnings,
      currentMonthEarnings: currentMonthEarnings,
      availableBalance: availableBalance,
      stripeAccountId: stripeAccountId,
      isStripeAccountComplete: isStripeAccountComplete,
      createdAt: createdAt != null ? DateTime.parse(createdAt!).toLocal() : DateTime.now(),
      totalRoomsHosted: totalRoomsHosted,
      totalHoursHosted: totalHoursHosted,
      averageRating: averageRating,
      totalRatings: totalRatings,
    );
  }

  static CreatorProfileModel fromEntity(CreatorProfileEntity entity) {
    return CreatorProfileModel(
      userId: entity.userId,
      displayName: entity.displayName,
      photoUrl: entity.photoUrl,
      bio: entity.bio,
      isMonetizationEnabled: entity.isMonetizationEnabled,
      subscriptionPrice: entity.subscriptionPrice,
      subscriptionCurrency: entity.subscriptionCurrency,
      subscriberCount: entity.subscriberCount,
      totalSubscriptionEarnings: entity.totalSubscriptionEarnings,
      totalTipEarnings: entity.totalTipEarnings,
      totalTicketEarnings: entity.totalTicketEarnings,
      totalReplayEarnings: entity.totalReplayEarnings,
      currentMonthEarnings: entity.currentMonthEarnings,
      availableBalance: entity.availableBalance,
      stripeAccountId: entity.stripeAccountId,
      isStripeAccountComplete: entity.isStripeAccountComplete,
      createdAt: entity.createdAt.toIso8601String(),
      totalRoomsHosted: entity.totalRoomsHosted,
      totalHoursHosted: entity.totalHoursHosted,
      averageRating: entity.averageRating,
      totalRatings: entity.totalRatings,
    );
  }

  CreatorProfileModel copyWith({
    String? id,
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
    String? createdAt,
    int? totalRoomsHosted,
    int? totalHoursHosted,
    double? averageRating,
    int? totalRatings,
  }) {
    return CreatorProfileModel(
      id: id ?? this.id,
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

  static String? _timestampToString(dynamic timestamp) {
    if (timestamp == null) return null;
    if (timestamp is String) return timestamp;
    return null;
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        displayName,
        photoUrl,
        bio,
        isMonetizationEnabled,
        subscriptionPrice,
        subscriberCount,
        totalSubscriptionEarnings,
        totalTipEarnings,
        totalTicketEarnings,
        totalReplayEarnings,
        currentMonthEarnings,
        availableBalance,
        stripeAccountId,
        isStripeAccountComplete,
        createdAt,
        totalRoomsHosted,
        totalHoursHosted,
        averageRating,
        totalRatings,
      ];
}
