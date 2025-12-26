// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'business_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$BusinessModelImpl _$$BusinessModelImplFromJson(
  Map<String, dynamic> json,
) => _$BusinessModelImpl(
  id: json['id'] as String,
  ownerId: json['ownerId'] as String,
  ownerName: json['ownerName'] as String?,
  name: json['name'] as String,
  description: json['description'] as String,
  category: json['category'] as String? ?? 'other',
  photoUrls:
      (json['photoUrls'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  logoUrl: json['logoUrl'] as String?,
  phone: json['phone'] as String?,
  email: json['email'] as String?,
  website: json['website'] as String?,
  address: json['address'] as String?,
  city: json['city'] as String?,
  country: json['country'] as String?,
  latitude: (json['latitude'] as num?)?.toDouble(),
  longitude: (json['longitude'] as num?)?.toDouble(),
  openingHours: json['openingHours'] as Map<String, dynamic>? ?? const {},
  isVerified: json['isVerified'] as bool? ?? false,
  isBoosted: json['isBoosted'] as bool? ?? false,
  boostExpiresAt:
      json['boostExpiresAt'] == null
          ? null
          : DateTime.parse(json['boostExpiresAt'] as String),
  averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0.0,
  reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
  viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
  tags:
      (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  services:
      (json['services'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  createdAt:
      json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
  updatedAt:
      json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$$BusinessModelImplToJson(_$BusinessModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'ownerId': instance.ownerId,
      'ownerName': instance.ownerName,
      'name': instance.name,
      'description': instance.description,
      'category': instance.category,
      'photoUrls': instance.photoUrls,
      'logoUrl': instance.logoUrl,
      'phone': instance.phone,
      'email': instance.email,
      'website': instance.website,
      'address': instance.address,
      'city': instance.city,
      'country': instance.country,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'openingHours': instance.openingHours,
      'isVerified': instance.isVerified,
      'isBoosted': instance.isBoosted,
      'boostExpiresAt': instance.boostExpiresAt?.toIso8601String(),
      'averageRating': instance.averageRating,
      'reviewCount': instance.reviewCount,
      'viewCount': instance.viewCount,
      'tags': instance.tags,
      'services': instance.services,
      'createdAt': instance.createdAt?.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };
