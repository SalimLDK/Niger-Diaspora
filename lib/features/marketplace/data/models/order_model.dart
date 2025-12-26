import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/order_entity.dart';

part 'order_model.freezed.dart';
part 'order_model.g.dart';

@freezed
class OrderModel with _$OrderModel {
  const OrderModel._();

  const factory OrderModel({
    required String id,
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
    @Default('pending') String status,
    @Default('notCreated') String escrowStatus,
    String? escrowId,
    String? shippingAddress,
    String? trackingNumber,
    String? buyerNote,
    String? sellerNote,
    @TimestampConverter() DateTime? createdAt,
    @TimestampConverter() DateTime? paidAt,
    @TimestampConverter() DateTime? shippedAt,
    @TimestampConverter() DateTime? deliveredAt,
    @TimestampConverter() DateTime? completedAt,
    @TimestampConverter() DateTime? cancelledAt,
    String? cancellationReason,
  }) = _OrderModel;

  factory OrderModel.fromJson(Map<String, dynamic> json) =>
      _$OrderModelFromJson(json);

  factory OrderModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return OrderModel.fromJson({
      'id': doc.id,
      ...data,
    });
  }

  factory OrderModel.fromEntity(OrderEntity entity) {
    return OrderModel(
      id: entity.id,
      productId: entity.productId,
      productTitle: entity.productTitle,
      productImageUrl: entity.productImageUrl,
      buyerId: entity.buyerId,
      buyerName: entity.buyerName,
      sellerId: entity.sellerId,
      sellerName: entity.sellerName,
      amount: entity.amount,
      platformFee: entity.platformFee,
      sellerAmount: entity.sellerAmount,
      currency: entity.currency,
      quantity: entity.quantity,
      status: entity.status.name,
      escrowStatus: entity.escrowStatus.name,
      escrowId: entity.escrowId,
      shippingAddress: entity.shippingAddress,
      trackingNumber: entity.trackingNumber,
      buyerNote: entity.buyerNote,
      sellerNote: entity.sellerNote,
      createdAt: entity.createdAt,
      paidAt: entity.paidAt,
      shippedAt: entity.shippedAt,
      deliveredAt: entity.deliveredAt,
      completedAt: entity.completedAt,
      cancelledAt: entity.cancelledAt,
      cancellationReason: entity.cancellationReason,
    );
  }

  OrderEntity toEntity() {
    return OrderEntity(
      id: id,
      productId: productId,
      productTitle: productTitle,
      productImageUrl: productImageUrl,
      buyerId: buyerId,
      buyerName: buyerName,
      sellerId: sellerId,
      sellerName: sellerName,
      amount: amount,
      platformFee: platformFee,
      sellerAmount: sellerAmount,
      currency: currency,
      quantity: quantity,
      status: OrderStatus.values.firstWhere(
        (e) => e.name == status,
        orElse: () => OrderStatus.pending,
      ),
      escrowStatus: EscrowStatus.values.firstWhere(
        (e) => e.name == escrowStatus,
        orElse: () => EscrowStatus.notCreated,
      ),
      escrowId: escrowId,
      shippingAddress: shippingAddress,
      trackingNumber: trackingNumber,
      buyerNote: buyerNote,
      sellerNote: sellerNote,
      createdAt: createdAt,
      paidAt: paidAt,
      shippedAt: shippedAt,
      deliveredAt: deliveredAt,
      completedAt: completedAt,
      cancelledAt: cancelledAt,
      cancellationReason: cancellationReason,
    );
  }

  Map<String, dynamic> toFirestore() {
    final json = toJson();
    json.remove('id');
    return json;
  }
}

class TimestampConverter implements JsonConverter<DateTime?, dynamic> {
  const TimestampConverter();

  @override
  DateTime? fromJson(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.parse(value);
    return null;
  }

  @override
  dynamic toJson(DateTime? date) {
    if (date == null) return null;
    return Timestamp.fromDate(date);
  }
}
