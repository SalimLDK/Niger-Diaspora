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
  startDate: DateTime.parse(json['startDate'] as String),
  endDate: DateTime.parse(json['endDate'] as String),
  status: json['status'] as String? ?? 'active',
  paymentReference: json['paymentReference'] as String?,
  createdAt:
      json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
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
  'startDate': instance.startDate.toIso8601String(),
  'endDate': instance.endDate.toIso8601String(),
  'status': instance.status,
  'paymentReference': instance.paymentReference,
  'createdAt': instance.createdAt?.toIso8601String(),
};
