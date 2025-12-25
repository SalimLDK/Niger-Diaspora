// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'group_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$GroupModelImpl _$$GroupModelImplFromJson(
  Map<String, dynamic> json,
) => _$GroupModelImpl(
  id: json['id'] as String,
  name: json['name'] as String,
  description: json['description'] as String,
  imageUrl: json['imageUrl'] as String?,
  creatorId: json['creatorId'] as String,
  creatorName: json['creatorName'] as String?,
  adminIds:
      (json['adminIds'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  memberIds:
      (json['memberIds'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  category: json['category'] as String? ?? 'other',
  isPrivate: json['isPrivate'] as bool? ?? false,
  location: json['location'] as String?,
  tags:
      (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  createdAt:
      json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$$GroupModelImplToJson(_$GroupModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'imageUrl': instance.imageUrl,
      'creatorId': instance.creatorId,
      'creatorName': instance.creatorName,
      'adminIds': instance.adminIds,
      'memberIds': instance.memberIds,
      'category': instance.category,
      'isPrivate': instance.isPrivate,
      'location': instance.location,
      'tags': instance.tags,
      'createdAt': instance.createdAt?.toIso8601String(),
    };
