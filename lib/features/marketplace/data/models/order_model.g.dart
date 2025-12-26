// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$OrderModelImpl _$$OrderModelImplFromJson(Map<String, dynamic> json) =>
    _$OrderModelImpl(
      id: json['id'] as String,
      productId: json['productId'] as String,
      productTitle: json['productTitle'] as String,
      productImageUrl: json['productImageUrl'] as String?,
      buyerId: json['buyerId'] as String,
      buyerName: json['buyerName'] as String?,
      sellerId: json['sellerId'] as String,
      sellerName: json['sellerName'] as String?,
      amount: (json['amount'] as num).toDouble(),
      platformFee: (json['platformFee'] as num).toDouble(),
      sellerAmount: (json['sellerAmount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'XOF',
      quantity: (json['quantity'] as num).toInt(),
      status: json['status'] as String? ?? 'pending',
      escrowStatus: json['escrowStatus'] as String? ?? 'notCreated',
      escrowId: json['escrowId'] as String?,
      shippingAddress: json['shippingAddress'] as String?,
      trackingNumber: json['trackingNumber'] as String?,
      buyerNote: json['buyerNote'] as String?,
      sellerNote: json['sellerNote'] as String?,
      createdAt: const TimestampConverter().fromJson(json['createdAt']),
      paidAt: const TimestampConverter().fromJson(json['paidAt']),
      shippedAt: const TimestampConverter().fromJson(json['shippedAt']),
      deliveredAt: const TimestampConverter().fromJson(json['deliveredAt']),
      completedAt: const TimestampConverter().fromJson(json['completedAt']),
      cancelledAt: const TimestampConverter().fromJson(json['cancelledAt']),
      cancellationReason: json['cancellationReason'] as String?,
    );

Map<String, dynamic> _$$OrderModelImplToJson(_$OrderModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'productId': instance.productId,
      'productTitle': instance.productTitle,
      'productImageUrl': instance.productImageUrl,
      'buyerId': instance.buyerId,
      'buyerName': instance.buyerName,
      'sellerId': instance.sellerId,
      'sellerName': instance.sellerName,
      'amount': instance.amount,
      'platformFee': instance.platformFee,
      'sellerAmount': instance.sellerAmount,
      'currency': instance.currency,
      'quantity': instance.quantity,
      'status': instance.status,
      'escrowStatus': instance.escrowStatus,
      'escrowId': instance.escrowId,
      'shippingAddress': instance.shippingAddress,
      'trackingNumber': instance.trackingNumber,
      'buyerNote': instance.buyerNote,
      'sellerNote': instance.sellerNote,
      'createdAt': const TimestampConverter().toJson(instance.createdAt),
      'paidAt': const TimestampConverter().toJson(instance.paidAt),
      'shippedAt': const TimestampConverter().toJson(instance.shippedAt),
      'deliveredAt': const TimestampConverter().toJson(instance.deliveredAt),
      'completedAt': const TimestampConverter().toJson(instance.completedAt),
      'cancelledAt': const TimestampConverter().toJson(instance.cancelledAt),
      'cancellationReason': instance.cancellationReason,
    };
