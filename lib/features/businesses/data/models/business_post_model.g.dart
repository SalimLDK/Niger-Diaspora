// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'business_post_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$BusinessPostModelImpl _$$BusinessPostModelImplFromJson(
  Map<String, dynamic> json,
) => _$BusinessPostModelImpl(
  id: json['id'] as String,
  businessId: json['businessId'] as String,
  title: json['title'] as String,
  content: json['content'] as String,
  type: json['type'] as String? ?? 'announcement',
  imageUrls:
      (json['imageUrls'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  originalPrice: (json['originalPrice'] as num?)?.toDouble(),
  discountedPrice: (json['discountedPrice'] as num?)?.toDouble(),
  discountPercent: (json['discountPercent'] as num?)?.toInt(),
  offerStartDate: json['offerStartDate'] as String?,
  offerEndDate: json['offerEndDate'] as String?,
  promoCode: json['promoCode'] as String?,
  viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
  likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
  isActive: json['isActive'] as bool? ?? true,
  createdAt: json['createdAt'] as String?,
  updatedAt: json['updatedAt'] as String?,
);

Map<String, dynamic> _$$BusinessPostModelImplToJson(
  _$BusinessPostModelImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'businessId': instance.businessId,
  'title': instance.title,
  'content': instance.content,
  'type': instance.type,
  'imageUrls': instance.imageUrls,
  'originalPrice': instance.originalPrice,
  'discountedPrice': instance.discountedPrice,
  'discountPercent': instance.discountPercent,
  'offerStartDate': instance.offerStartDate,
  'offerEndDate': instance.offerEndDate,
  'promoCode': instance.promoCode,
  'viewCount': instance.viewCount,
  'likeCount': instance.likeCount,
  'isActive': instance.isActive,
  'createdAt': instance.createdAt,
  'updatedAt': instance.updatedAt,
};
