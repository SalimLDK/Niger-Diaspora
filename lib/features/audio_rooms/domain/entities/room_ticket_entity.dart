import 'package:equatable/equatable.dart';

/// Status of a room ticket
enum RoomTicketStatus {
  /// Payment pending
  pending,

  /// Payment completed, ticket active
  active,

  /// Ticket used (room attended)
  used,

  /// Payment failed
  failed,

  /// Ticket refunded
  refunded,
}

/// Entity representing a purchased ticket for a paid audio room
class RoomTicketEntity extends Equatable {
  /// Unique identifier
  final String id;

  /// ID of the audio room
  final String roomId;

  /// Title of the room (denormalized for display)
  final String roomTitle;

  /// ID of the buyer
  final String buyerId;

  /// Name of the buyer (denormalized)
  final String buyerName;

  /// ID of the host/seller
  final String sellerId;

  /// Price in cents
  final int priceAmount;

  /// Currency code (e.g., XOF, EUR)
  final String currency;

  /// Status of the ticket
  final RoomTicketStatus status;

  /// When the ticket was purchased
  final DateTime purchasedAt;

  /// When the ticket was used (room joined)
  final DateTime? usedAt;

  /// Stripe Payment Intent ID
  final String? stripePaymentIntentId;

  /// Platform commission amount in cents (15%)
  final int commissionAmount;

  /// Seller's net amount in cents
  final int sellerAmount;

  const RoomTicketEntity({
    required this.id,
    required this.roomId,
    required this.roomTitle,
    required this.buyerId,
    required this.buyerName,
    required this.sellerId,
    required this.priceAmount,
    required this.currency,
    required this.status,
    required this.purchasedAt,
    this.usedAt,
    this.stripePaymentIntentId,
    required this.commissionAmount,
    required this.sellerAmount,
  });

  /// Calculate commission (15%)
  static int calculateCommission(int amount) => (amount * 0.15).round();

  /// Calculate seller amount (85%)
  static int calculateSellerAmount(int amount) => amount - calculateCommission(amount);

  /// Whether the ticket can be used
  bool get canUse => status == RoomTicketStatus.active;

  /// Whether the ticket has been used
  bool get isUsed => status == RoomTicketStatus.used;

  /// Format price for display
  String get formattedPrice => '${(priceAmount / 100).toStringAsFixed(0)} $currency';

  RoomTicketEntity copyWith({
    String? id,
    String? roomId,
    String? roomTitle,
    String? buyerId,
    String? buyerName,
    String? sellerId,
    int? priceAmount,
    String? currency,
    RoomTicketStatus? status,
    DateTime? purchasedAt,
    DateTime? usedAt,
    String? stripePaymentIntentId,
    int? commissionAmount,
    int? sellerAmount,
  }) {
    return RoomTicketEntity(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      roomTitle: roomTitle ?? this.roomTitle,
      buyerId: buyerId ?? this.buyerId,
      buyerName: buyerName ?? this.buyerName,
      sellerId: sellerId ?? this.sellerId,
      priceAmount: priceAmount ?? this.priceAmount,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      purchasedAt: purchasedAt ?? this.purchasedAt,
      usedAt: usedAt ?? this.usedAt,
      stripePaymentIntentId: stripePaymentIntentId ?? this.stripePaymentIntentId,
      commissionAmount: commissionAmount ?? this.commissionAmount,
      sellerAmount: sellerAmount ?? this.sellerAmount,
    );
  }

  @override
  List<Object?> get props => [
        id,
        roomId,
        buyerId,
        status,
        purchasedAt,
      ];
}
