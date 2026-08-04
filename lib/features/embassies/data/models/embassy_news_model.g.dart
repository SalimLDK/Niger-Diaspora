// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'embassy_news_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$EmbassyNewsModelImpl _$$EmbassyNewsModelImplFromJson(
  Map<String, dynamic> json,
) => _$EmbassyNewsModelImpl(
  id: json['id'] as String,
  title: json['title'] as String,
  content: json['content'] as String,
  date: const LocalDateTimeConverter().fromJson(json['date']),
  imageUrl: json['imageUrl'] as String?,
);

Map<String, dynamic> _$$EmbassyNewsModelImplToJson(
  _$EmbassyNewsModelImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'content': instance.content,
  'date': const LocalDateTimeConverter().toJson(instance.date),
  'imageUrl': instance.imageUrl,
};
