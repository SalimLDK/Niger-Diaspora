// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search_result_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SearchResultModelImpl _$$SearchResultModelImplFromJson(
  Map<String, dynamic> json,
) => _$SearchResultModelImpl(
  query: json['query'] as String,
  profiles:
      (json['profiles'] as List<dynamic>?)
          ?.map((e) => ProfileModel.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  groups:
      (json['groups'] as List<dynamic>?)
          ?.map((e) => GroupModel.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  friends:
      (json['friends'] as List<dynamic>?)
          ?.map((e) => FriendModel.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  conversations:
      (json['conversations'] as List<dynamic>?)
          ?.map((e) => ConversationModel.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  searchedAt: json['searchedAt'] as String?,
);

Map<String, dynamic> _$$SearchResultModelImplToJson(
  _$SearchResultModelImpl instance,
) => <String, dynamic>{
  'query': instance.query,
  'profiles': instance.profiles,
  'groups': instance.groups,
  'friends': instance.friends,
  'conversations': instance.conversations,
  'searchedAt': instance.searchedAt,
};
