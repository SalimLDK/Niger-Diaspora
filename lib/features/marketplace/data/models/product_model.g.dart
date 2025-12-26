// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ProductModelImpl _$$ProductModelImplFromJson(Map<String, dynamic> json) =>
    _$ProductModelImpl(
      id: json['id'] as String,
      sellerId: json['sellerId'] as String,
      sellerName: json['sellerName'] as String?,
      sellerPhotoUrl: json['sellerPhotoUrl'] as String?,
      title: json['title'] as String,
      description: json['description'] as String,
      price: (json['price'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'XOF',
      imageUrls:
          (json['imageUrls'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      category: json['category'] as String? ?? 'other',
      condition: json['condition'] as String? ?? 'newProduct',
      location: json['location'] as String?,
      isAvailable: json['isAvailable'] as bool? ?? true,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
          const [],
      isTaxable: json['isTaxable'] as bool? ?? true,
      customTaxRate: (json['customTaxRate'] as num?)?.toDouble(),
      taxIncludedInPrice: json['taxIncludedInPrice'] as bool? ?? false,
      createdAt: const TimestampConverter().fromJson(json['createdAt']),
      updatedAt: const TimestampConverter().fromJson(json['updatedAt']),
    );

Map<String, dynamic> _$$ProductModelImplToJson(_$ProductModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sellerId': instance.sellerId,
      'sellerName': instance.sellerName,
      'sellerPhotoUrl': instance.sellerPhotoUrl,
      'title': instance.title,
      'description': instance.description,
      'price': instance.price,
      'currency': instance.currency,
      'imageUrls': instance.imageUrls,
      'category': instance.category,
      'condition': instance.condition,
      'location': instance.location,
      'isAvailable': instance.isAvailable,
      'quantity': instance.quantity,
      'viewCount': instance.viewCount,
      'tags': instance.tags,
      'isTaxable': instance.isTaxable,
      'customTaxRate': instance.customTaxRate,
      'taxIncludedInPrice': instance.taxIncludedInPrice,
      'createdAt': const TimestampConverter().toJson(instance.createdAt),
      'updatedAt': const TimestampConverter().toJson(instance.updatedAt),
    };
