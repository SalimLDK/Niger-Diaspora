// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'business_boost_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$BusinessBoostModelImpl _$$BusinessBoostModelImplFromJson(
  Map<String, dynamic> json,
) => _$BusinessBoostModelImpl(
  id: json['id'] as String,
  businessId: json['businessId'] as String,
  userId: json['userId'] as String,
  type: json['type'] as String? ?? 'standard',
  duration: json['duration'] as String? ?? 'days7',
  amount: (json['amount'] as num).toDouble(),
  currency: json['currency'] as String? ?? 'XOF',
  startDate: const LocalDateTimeConverter().fromJson(json['startDate']),
  endDate: const LocalDateTimeConverter().fromJson(json['endDate']),
  status: json['status'] as String? ?? 'active',
  paymentReference: json['paymentReference'] as String?,
  createdAt: const LocalDateTimeNullableConverter().fromJson(json['createdAt']),
);

Map<String, dynamic> _$$BusinessBoostModelImplToJson(
  _$BusinessBoostModelImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'businessId': instance.businessId,
  'userId': instance.userId,
  'type': instance.type,
  'duration': instance.duration,
  'amount': instance.amount,
  'currency': instance.currency,
  'startDate': const LocalDateTimeConverter().toJson(instance.startDate),
  'endDate': const LocalDateTimeConverter().toJson(instance.endDate),
  'status': instance.status,
  'paymentReference': instance.paymentReference,
  'createdAt': const LocalDateTimeNullableConverter().toJson(
    instance.createdAt,
  ),
};
