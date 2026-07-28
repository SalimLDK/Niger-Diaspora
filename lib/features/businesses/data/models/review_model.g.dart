// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'review_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ReviewModelImpl _$$ReviewModelImplFromJson(Map<String, dynamic> json) =>
    _$ReviewModelImpl(
      id: json['id'] as String,
      businessId: json['businessId'] as String,
      userId: json['userId'] as String,
      userDisplayName: json['userDisplayName'] as String,
      userPhotoUrl: json['userPhotoUrl'] as String?,
      rating: (json['rating'] as num).toInt(),
      title: json['title'] as String?,
      content: json['content'] as String,
      imageUrls:
          (json['imageUrls'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      helpfulCount: (json['helpfulCount'] as num?)?.toInt() ?? 0,
      helpfulByUserIds:
          (json['helpfulByUserIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      status: json['status'] as String? ?? 'published',
      ownerReply: json['ownerReply'] as String?,
      ownerReplyAt: json['ownerReplyAt'] as String?,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
    );

Map<String, dynamic> _$$ReviewModelImplToJson(_$ReviewModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'businessId': instance.businessId,
      'userId': instance.userId,
      'userDisplayName': instance.userDisplayName,
      'userPhotoUrl': instance.userPhotoUrl,
      'rating': instance.rating,
      'title': instance.title,
      'content': instance.content,
      'imageUrls': instance.imageUrls,
      'helpfulCount': instance.helpfulCount,
      'helpfulByUserIds': instance.helpfulByUserIds,
      'status': instance.status,
      'ownerReply': instance.ownerReply,
      'ownerReplyAt': instance.ownerReplyAt,
      'createdAt': instance.createdAt,
      'updatedAt': instance.updatedAt,
    };
