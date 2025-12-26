// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'embassy_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$EmbassyModelImpl _$$EmbassyModelImplFromJson(
  Map<String, dynamic> json,
) => _$EmbassyModelImpl(
  id: json['id'] as String,
  name: json['name'] as String,
  country: json['country'] as String,
  city: json['city'] as String,
  address: json['address'] as String,
  phone: json['phone'] as String?,
  email: json['email'] as String?,
  website: json['website'] as String?,
  latitude: (json['latitude'] as num?)?.toDouble(),
  longitude: (json['longitude'] as num?)?.toDouble(),
  imageUrl: json['imageUrl'] as String?,
  type: json['type'] as String? ?? 'embassy',
  services:
      (json['services'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  openingHours:
      (json['openingHours'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ) ??
      const {},
  isVerified: json['isVerified'] as bool? ?? false,
  isSuspended: json['isSuspended'] as bool? ?? false,
  verifiedAt: _timestampToDateTime(json['verifiedAt']),
  rejectionReason: json['rejectionReason'] as String?,
  jurisdictionCountries:
      (json['jurisdictionCountries'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  activities:
      (json['activities'] as List<dynamic>?)
          ?.map((e) => EmbassyActivityModel.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  news:
      (json['news'] as List<dynamic>?)
          ?.map((e) => EmbassyNewsModel.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);

Map<String, dynamic> _$$EmbassyModelImplToJson(_$EmbassyModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'country': instance.country,
      'city': instance.city,
      'address': instance.address,
      'phone': instance.phone,
      'email': instance.email,
      'website': instance.website,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'imageUrl': instance.imageUrl,
      'type': instance.type,
      'services': instance.services,
      'openingHours': instance.openingHours,
      'isVerified': instance.isVerified,
      'isSuspended': instance.isSuspended,
      'verifiedAt': _dateTimeToTimestamp(instance.verifiedAt),
      'rejectionReason': instance.rejectionReason,
      'jurisdictionCountries': instance.jurisdictionCountries,
      'activities': instance.activities,
      'news': instance.news,
    };
