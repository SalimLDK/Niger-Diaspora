// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'embassy_activity_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$EmbassyActivityModelImpl _$$EmbassyActivityModelImplFromJson(
  Map<String, dynamic> json,
) => _$EmbassyActivityModelImpl(
  id: json['id'] as String,
  title: json['title'] as String,
  description: json['description'] as String,
  date: DateTime.parse(json['date'] as String),
  location: json['location'] as String,
  imageUrl: json['imageUrl'] as String?,
);

Map<String, dynamic> _$$EmbassyActivityModelImplToJson(
  _$EmbassyActivityModelImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'description': instance.description,
  'date': instance.date.toIso8601String(),
  'location': instance.location,
  'imageUrl': instance.imageUrl,
};
