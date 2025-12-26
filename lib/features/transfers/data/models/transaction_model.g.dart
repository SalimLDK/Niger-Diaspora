// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TransactionModelImpl _$$TransactionModelImplFromJson(
  Map<String, dynamic> json,
) => _$TransactionModelImpl(
  id: json['id'] as String,
  senderId: json['senderId'] as String,
  recipientId: json['recipientId'] as String,
  recipientName: json['recipientName'] as String?,
  recipientPhone: json['recipientPhone'] as String?,
  amount: (json['amount'] as num).toDouble(),
  currency: json['currency'] as String,
  exchangeRate: (json['exchangeRate'] as num).toDouble(),
  amountInXof: (json['amountInXof'] as num).toDouble(),
  fee: (json['fee'] as num).toDouble(),
  totalCharged: (json['totalCharged'] as num).toDouble(),
  status: json['status'] as String? ?? 'pending',
  provider: json['provider'] as String? ?? 'stripe',
  paymentIntentId: json['paymentIntentId'] as String?,
  stripeChargeId: json['stripeChargeId'] as String?,
  mynitaReference: json['mynitaReference'] as String?,
  failureReason: json['failureReason'] as String?,
  createdAt: const TimestampConverter().fromJson(json['createdAt']),
  completedAt: const TimestampConverter().fromJson(json['completedAt']),
  notes: json['notes'] as String?,
);

Map<String, dynamic> _$$TransactionModelImplToJson(
  _$TransactionModelImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'senderId': instance.senderId,
  'recipientId': instance.recipientId,
  'recipientName': instance.recipientName,
  'recipientPhone': instance.recipientPhone,
  'amount': instance.amount,
  'currency': instance.currency,
  'exchangeRate': instance.exchangeRate,
  'amountInXof': instance.amountInXof,
  'fee': instance.fee,
  'totalCharged': instance.totalCharged,
  'status': instance.status,
  'provider': instance.provider,
  'paymentIntentId': instance.paymentIntentId,
  'stripeChargeId': instance.stripeChargeId,
  'mynitaReference': instance.mynitaReference,
  'failureReason': instance.failureReason,
  'createdAt': const TimestampConverter().toJson(instance.createdAt),
  'completedAt': const TimestampConverter().toJson(instance.completedAt),
  'notes': instance.notes,
};
