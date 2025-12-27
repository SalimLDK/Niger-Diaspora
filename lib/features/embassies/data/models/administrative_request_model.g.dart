// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'administrative_request_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AdministrativeRequestModelImpl _$$AdministrativeRequestModelImplFromJson(
  Map<String, dynamic> json,
) => _$AdministrativeRequestModelImpl(
  id: json['id'] as String,
  userId: json['userId'] as String,
  embassyId: json['embassyId'] as String,
  requestType: $enumDecode(
    _$AdministrativeRequestTypeEnumMap,
    json['requestType'],
  ),
  status:
      $enumDecodeNullable(
        _$AdministrativeRequestStatusEnumMap,
        json['status'],
      ) ??
      AdministrativeRequestStatus.draft,
  fullName: json['fullName'] as String?,
  dateOfBirth: json['dateOfBirth'] as String?,
  placeOfBirth: json['placeOfBirth'] as String?,
  nationality: json['nationality'] as String?,
  currentAddress: json['currentAddress'] as String?,
  phone: json['phone'] as String?,
  email: json['email'] as String?,
  passportNumber: json['passportNumber'] as String?,
  passportExpiryDate: json['passportExpiryDate'] as String?,
  additionalData: json['additionalData'] as Map<String, dynamic>? ?? const {},
  attachments:
      (json['attachments'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  userNotes: json['userNotes'] as String?,
  embassyNotes: json['embassyNotes'] as String?,
  rejectionReason: json['rejectionReason'] as String?,
  createdAt: const RequestTimestampConverter().fromJson(json['createdAt']),
  submittedAt: const RequestTimestampConverter().fromJson(json['submittedAt']),
  processedAt: const RequestTimestampConverter().fromJson(json['processedAt']),
  completedAt: const RequestTimestampConverter().fromJson(json['completedAt']),
  trackingNumber: json['trackingNumber'] as String?,
  processedBy: json['processedBy'] as String?,
  userName: json['userName'] as String?,
  userPhotoUrl: json['userPhotoUrl'] as String?,
  embassyName: json['embassyName'] as String?,
  embassyCountry: json['embassyCountry'] as String?,
);

Map<String, dynamic> _$$AdministrativeRequestModelImplToJson(
  _$AdministrativeRequestModelImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'userId': instance.userId,
  'embassyId': instance.embassyId,
  'requestType': _$AdministrativeRequestTypeEnumMap[instance.requestType]!,
  'status': _$AdministrativeRequestStatusEnumMap[instance.status]!,
  'fullName': instance.fullName,
  'dateOfBirth': instance.dateOfBirth,
  'placeOfBirth': instance.placeOfBirth,
  'nationality': instance.nationality,
  'currentAddress': instance.currentAddress,
  'phone': instance.phone,
  'email': instance.email,
  'passportNumber': instance.passportNumber,
  'passportExpiryDate': instance.passportExpiryDate,
  'additionalData': instance.additionalData,
  'attachments': instance.attachments,
  'userNotes': instance.userNotes,
  'embassyNotes': instance.embassyNotes,
  'rejectionReason': instance.rejectionReason,
  'createdAt': const RequestTimestampConverter().toJson(instance.createdAt),
  'submittedAt': const RequestTimestampConverter().toJson(instance.submittedAt),
  'processedAt': const RequestTimestampConverter().toJson(instance.processedAt),
  'completedAt': const RequestTimestampConverter().toJson(instance.completedAt),
  'trackingNumber': instance.trackingNumber,
  'processedBy': instance.processedBy,
  'userName': instance.userName,
  'userPhotoUrl': instance.userPhotoUrl,
  'embassyName': instance.embassyName,
  'embassyCountry': instance.embassyCountry,
};

const _$AdministrativeRequestTypeEnumMap = {
  AdministrativeRequestType.passportRenewal: 'passportRenewal',
  AdministrativeRequestType.passportNewRequest: 'passportNewRequest',
  AdministrativeRequestType.visaApplication: 'visaApplication',
  AdministrativeRequestType.birthCertificate: 'birthCertificate',
  AdministrativeRequestType.marriageCertificate: 'marriageCertificate',
  AdministrativeRequestType.deathCertificate: 'deathCertificate',
  AdministrativeRequestType.consularId: 'consularId',
  AdministrativeRequestType.legalDocument: 'legalDocument',
  AdministrativeRequestType.laissezPasser: 'laissezPasser',
  AdministrativeRequestType.powerOfAttorney: 'powerOfAttorney',
  AdministrativeRequestType.inscription: 'inscription',
  AdministrativeRequestType.other: 'other',
};

const _$AdministrativeRequestStatusEnumMap = {
  AdministrativeRequestStatus.draft: 'draft',
  AdministrativeRequestStatus.submitted: 'submitted',
  AdministrativeRequestStatus.received: 'received',
  AdministrativeRequestStatus.processing: 'processing',
  AdministrativeRequestStatus.additionalInfoRequired: 'additionalInfoRequired',
  AdministrativeRequestStatus.completed: 'completed',
  AdministrativeRequestStatus.rejected: 'rejected',
  AdministrativeRequestStatus.cancelled: 'cancelled',
};
