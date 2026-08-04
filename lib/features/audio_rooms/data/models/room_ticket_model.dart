import 'package:equatable/equatable.dart';

import '../../domain/entities/room_ticket_entity.dart';

class RoomTicketModel extends Equatable {
  final String id;
  final String roomId;
  final String roomTitle;
  final String buyerId;
  final String buyerName;
  final String sellerId;
  final int priceAmount;
  final String currency;
  final String status;
  final String? purchasedAt;
  final String? usedAt;
  final String? stripePaymentIntentId;
  final int commissionAmount;
  final int sellerAmount;

  const RoomTicketModel({
    this.id = '',
    required this.roomId,
    required this.roomTitle,
    required this.buyerId,
    required this.buyerName,
    required this.sellerId,
    required this.priceAmount,
    this.currency = 'XOF',
    this.status = 'pending',
    this.purchasedAt,
    this.usedAt,
    this.stripePaymentIntentId,
    required this.commissionAmount,
    required this.sellerAmount,
  });

  factory RoomTicketModel.fromJson(Map<String, dynamic> json) {
    return RoomTicketModel(
      id: json['id'] as String? ?? '',
      roomId: json['roomId'] as String? ?? '',
      roomTitle: json['roomTitle'] as String? ?? '',
      buyerId: json['buyerId'] as String? ?? '',
      buyerName: json['buyerName'] as String? ?? '',
      sellerId: json['sellerId'] as String? ?? '',
      priceAmount: json['priceAmount'] as int? ?? 0,
      currency: json['currency'] as String? ?? 'XOF',
      status: json['status'] as String? ?? 'pending',
      purchasedAt: _timestampToString(json['purchasedAt']),
      usedAt: _timestampToString(json['usedAt']),
      stripePaymentIntentId: json['stripePaymentIntentId'] as String?,
      commissionAmount: json['commissionAmount'] as int? ?? 0,
      sellerAmount: json['sellerAmount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'roomId': roomId,
      'roomTitle': roomTitle,
      'buyerId': buyerId,
      'buyerName': buyerName,
      'sellerId': sellerId,
      'priceAmount': priceAmount,
      'currency': currency,
      'status': status,
      'purchasedAt': purchasedAt,
      'usedAt': usedAt,
      'stripePaymentIntentId': stripePaymentIntentId,
      'commissionAmount': commissionAmount,
      'sellerAmount': sellerAmount,
    };
  }
  Map<String, dynamic> toFirestore() {
    return {
      'roomId': roomId,
      'roomTitle': roomTitle,
      'buyerId': buyerId,
      'buyerName': buyerName,
      'sellerId': sellerId,
      'priceAmount': priceAmount,
      'currency': currency,
      'status': status,
      'purchasedAt': purchasedAt ?? DateTime.now().toUtc().toIso8601String(),
      'usedAt': usedAt,
      'stripePaymentIntentId': stripePaymentIntentId,
      'commissionAmount': commissionAmount,
      'sellerAmount': sellerAmount,
    };
  }

  RoomTicketEntity toEntity() {
    return RoomTicketEntity(
      id: id,
      roomId: roomId,
      roomTitle: roomTitle,
      buyerId: buyerId,
      buyerName: buyerName,
      sellerId: sellerId,
      priceAmount: priceAmount,
      currency: currency,
      status: _parseStatus(status),
      purchasedAt: purchasedAt != null ? DateTime.parse(purchasedAt!).toLocal() : DateTime.now(),
      usedAt: usedAt != null ? DateTime.parse(usedAt!).toLocal() : null,
      stripePaymentIntentId: stripePaymentIntentId,
      commissionAmount: commissionAmount,
      sellerAmount: sellerAmount,
    );
  }

  static RoomTicketModel fromEntity(RoomTicketEntity entity) {
    return RoomTicketModel(
      id: entity.id,
      roomId: entity.roomId,
      roomTitle: entity.roomTitle,
      buyerId: entity.buyerId,
      buyerName: entity.buyerName,
      sellerId: entity.sellerId,
      priceAmount: entity.priceAmount,
      currency: entity.currency,
      status: entity.status.name,
      purchasedAt: entity.purchasedAt.toUtc().toIso8601String(),
      usedAt: entity.usedAt?.toUtc().toIso8601String(),
      stripePaymentIntentId: entity.stripePaymentIntentId,
      commissionAmount: entity.commissionAmount,
      sellerAmount: entity.sellerAmount,
    );
  }

  RoomTicketModel copyWith({
    String? id,
    String? roomId,
    String? roomTitle,
    String? buyerId,
    String? buyerName,
    String? sellerId,
    int? priceAmount,
    String? currency,
    String? status,
    String? purchasedAt,
    String? usedAt,
    String? stripePaymentIntentId,
    int? commissionAmount,
    int? sellerAmount,
  }) {
    return RoomTicketModel(
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

  static RoomTicketStatus _parseStatus(String status) {
    switch (status) {
      case 'pending':
        return RoomTicketStatus.pending;
      case 'active':
        return RoomTicketStatus.active;
      case 'used':
        return RoomTicketStatus.used;
      case 'failed':
        return RoomTicketStatus.failed;
      case 'refunded':
        return RoomTicketStatus.refunded;
      default:
        return RoomTicketStatus.pending;
    }
  }

  static String? _timestampToString(dynamic timestamp) {
    if (timestamp == null) return null;
    if (timestamp is String) return timestamp;
    return null;
  }

  @override
  List<Object?> get props => [
        id,
        roomId,
        roomTitle,
        buyerId,
        buyerName,
        sellerId,
        priceAmount,
        currency,
        status,
        purchasedAt,
        usedAt,
        stripePaymentIntentId,
        commissionAmount,
        sellerAmount,
      ];
}
