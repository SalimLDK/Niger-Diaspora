// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recipient_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$RecipientModelImpl _$$RecipientModelImplFromJson(Map<String, dynamic> json) =>
    _$RecipientModelImpl(
      id: json['id'] as String,
      userId: json['userId'] as String,
      fullName: json['fullName'] as String,
      phone: json['phone'] as String,
      email: json['email'] as String?,
      type: json['type'] as String? ?? 'mobileWallet',
      bankName: json['bankName'] as String?,
      bankAccountNumber: json['bankAccountNumber'] as String?,
      mobileProvider: json['mobileProvider'] as String?,
      city: json['city'] as String?,
      address: json['address'] as String?,
      isFavorite: json['isFavorite'] as bool? ?? false,
      createdAt: const TimestampConverter().fromJson(json['createdAt']),
      lastUsedAt: const TimestampConverter().fromJson(json['lastUsedAt']),
    );

Map<String, dynamic> _$$RecipientModelImplToJson(
  _$RecipientModelImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'userId': instance.userId,
  'fullName': instance.fullName,
  'phone': instance.phone,
  'email': instance.email,
  'type': instance.type,
  'bankName': instance.bankName,
  'bankAccountNumber': instance.bankAccountNumber,
  'mobileProvider': instance.mobileProvider,
  'city': instance.city,
  'address': instance.address,
  'isFavorite': instance.isFavorite,
  'createdAt': const TimestampConverter().toJson(instance.createdAt),
  'lastUsedAt': const TimestampConverter().toJson(instance.lastUsedAt),
};
