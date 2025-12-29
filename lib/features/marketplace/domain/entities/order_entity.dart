import 'package:freezed_annotation/freezed_annotation.dart';

part 'order_entity.freezed.dart';

@freezed
class OrderEntity with _$OrderEntity {
  const factory OrderEntity({
    required String id,
    /// Session ID to group orders from the same cart checkout
    String? sessionId,
    required String productId,
    required String productTitle,
    String? productImageUrl,
    required String buyerId,
    String? buyerName,
    required String sellerId,
    String? sellerName,
    required double amount,
    required double platformFee,
    required double sellerAmount,
    @Default('XOF') String currency,
    required int quantity,
    @Default(OrderStatus.pending) OrderStatus status,
    @Default(EscrowStatus.notCreated) EscrowStatus escrowStatus,
    String? escrowId,
    String? shippingAddress,
    String? trackingNumber,
    String? buyerNote,
    String? sellerNote,
    DateTime? createdAt,
    DateTime? paidAt,
    DateTime? shippedAt,
    DateTime? deliveredAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
    String? cancellationReason,
  }) = _OrderEntity;
}

enum OrderStatus {
  pending,
  paid,
  shipped,
  delivered,
  completed,
  disputed,
  refunded,
  cancelled,
}

enum EscrowStatus {
  notCreated,
  holding,
  released,
  refunded,
}

extension OrderStatusExtension on OrderStatus {
  String get label {
    switch (this) {
      case OrderStatus.pending:
        return 'En attente';
      case OrderStatus.paid:
        return 'Paye';
      case OrderStatus.shipped:
        return 'Expedie';
      case OrderStatus.delivered:
        return 'Livre';
      case OrderStatus.completed:
        return 'Termine';
      case OrderStatus.disputed:
        return 'En litige';
      case OrderStatus.refunded:
        return 'Rembourse';
      case OrderStatus.cancelled:
        return 'Annule';
    }
  }

  bool get isActive {
    return this == OrderStatus.pending ||
        this == OrderStatus.paid ||
        this == OrderStatus.shipped;
  }
}

extension EscrowStatusExtension on EscrowStatus {
  String get label {
    switch (this) {
      case EscrowStatus.notCreated:
        return 'Non cree';
      case EscrowStatus.holding:
        return 'En attente';
      case EscrowStatus.released:
        return 'Libere';
      case EscrowStatus.refunded:
        return 'Rembourse';
    }
  }
}
