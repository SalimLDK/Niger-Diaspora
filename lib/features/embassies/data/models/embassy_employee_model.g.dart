// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'embassy_employee_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$EmbassyEmployeeModelImpl _$$EmbassyEmployeeModelImplFromJson(
  Map<String, dynamic> json,
) => _$EmbassyEmployeeModelImpl(
  id: json['id'] as String,
  embassyId: json['embassyId'] as String,
  name: json['name'] as String,
  role: json['role'] as String,
  title: json['title'] as String?,
  department: json['department'] as String?,
  email: json['email'] as String?,
  phone: json['phone'] as String?,
  photoUrl: json['photoUrl'] as String?,
  isPublic: json['isPublic'] as bool? ?? true,
  isActive: json['isActive'] as bool? ?? true,
  bio: json['bio'] as String?,
  languages:
      (json['languages'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  responsibilities:
      (json['responsibilities'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  linkedUserId: json['linkedUserId'] as String?,
);

Map<String, dynamic> _$$EmbassyEmployeeModelImplToJson(
  _$EmbassyEmployeeModelImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'embassyId': instance.embassyId,
  'name': instance.name,
  'role': instance.role,
  'title': instance.title,
  'department': instance.department,
  'email': instance.email,
  'phone': instance.phone,
  'photoUrl': instance.photoUrl,
  'isPublic': instance.isPublic,
  'isActive': instance.isActive,
  'bio': instance.bio,
  'languages': instance.languages,
  'responsibilities': instance.responsibilities,
  'linkedUserId': instance.linkedUserId,
};
