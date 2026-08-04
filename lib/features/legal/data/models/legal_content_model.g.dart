// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'legal_content_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$LegalContentModelImpl _$$LegalContentModelImplFromJson(
  Map<String, dynamic> json,
) => _$LegalContentModelImpl(
  id: json['id'] as String,
  type: json['type'] as String,
  title: json['title'] as String,
  version: json['version'] as String,
  sections:
      (json['sections'] as List<dynamic>)
          .map((e) => LegalSectionModel.fromJson(e as Map<String, dynamic>))
          .toList(),
  updatedAt: const LocalDateTimeConverter().fromJson(json['updatedAt']),
  summary: json['summary'] as String?,
);

Map<String, dynamic> _$$LegalContentModelImplToJson(
  _$LegalContentModelImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'type': instance.type,
  'title': instance.title,
  'version': instance.version,
  'sections': instance.sections,
  'updatedAt': const LocalDateTimeConverter().toJson(instance.updatedAt),
  'summary': instance.summary,
};

_$LegalSectionModelImpl _$$LegalSectionModelImplFromJson(
  Map<String, dynamic> json,
) => _$LegalSectionModelImpl(
  title: json['title'] as String,
  content: json['content'] as String,
  order: (json['order'] as num?)?.toInt(),
);

Map<String, dynamic> _$$LegalSectionModelImplToJson(
  _$LegalSectionModelImpl instance,
) => <String, dynamic>{
  'title': instance.title,
  'content': instance.content,
  'order': instance.order,
};

_$UserLegalAcceptanceImpl _$$UserLegalAcceptanceImplFromJson(
  Map<String, dynamic> json,
) => _$UserLegalAcceptanceImpl(
  termsVersion: json['termsVersion'] as String,
  privacyVersion: json['privacyVersion'] as String,
  acceptedAt: const LocalDateTimeConverter().fromJson(json['acceptedAt']),
);

Map<String, dynamic> _$$UserLegalAcceptanceImplToJson(
  _$UserLegalAcceptanceImpl instance,
) => <String, dynamic>{
  'termsVersion': instance.termsVersion,
  'privacyVersion': instance.privacyVersion,
  'acceptedAt': const LocalDateTimeConverter().toJson(instance.acceptedAt),
};
