import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'administrative_request_model.freezed.dart';
part 'administrative_request_model.g.dart';

/// Types of administrative requests
enum AdministrativeRequestType {
  passportRenewal,
  passportNewRequest,
  visaApplication,
  birthCertificate,
  marriageCertificate,
  deathCertificate,
  consularId,
  legalDocument,
  laissezPasser,
  powerOfAttorney,
  inscription,
  other,
}

/// Status of administrative request
enum AdministrativeRequestStatus {
  draft,
  submitted,
  received,
  processing,
  additionalInfoRequired,
  completed,
  rejected,
  cancelled,
}

/// Converter to handle Firestore Timestamp to DateTime conversion
class RequestTimestampConverter implements JsonConverter<DateTime?, dynamic> {
  const RequestTimestampConverter();

  @override
  DateTime? fromJson(dynamic json) {
    if (json == null) return null;
    if (json is DateTime) return json;
    if (json is Timestamp) return json.toDate();
    if (json is int) return DateTime.fromMillisecondsSinceEpoch(json);
    return null;
  }

  @override
  dynamic toJson(DateTime? dateTime) {
    if (dateTime == null) return null;
    return Timestamp.fromDate(dateTime);
  }
}

@freezed
class AdministrativeRequestModel with _$AdministrativeRequestModel {
  const AdministrativeRequestModel._();

  const factory AdministrativeRequestModel({
    required String id,
    required String userId,
    required String embassyId,
    required AdministrativeRequestType requestType,
    @Default(AdministrativeRequestStatus.draft)
    AdministrativeRequestStatus status,
    // Pre-filled form data from user profile
    String? fullName,
    String? dateOfBirth,
    String? placeOfBirth,
    String? nationality,
    String? currentAddress,
    String? phone,
    String? email,
    String? passportNumber,
    String? passportExpiryDate,
    // Dynamic form data
    @Default({}) Map<String, dynamic> additionalData,
    // Attachments
    @Default([]) List<String> attachments,
    // Notes and comments
    String? userNotes,
    String? embassyNotes,
    String? rejectionReason,
    // Timestamps
    @RequestTimestampConverter() DateTime? createdAt,
    @RequestTimestampConverter() DateTime? submittedAt,
    @RequestTimestampConverter() DateTime? processedAt,
    @RequestTimestampConverter() DateTime? completedAt,
    // Tracking
    String? trackingNumber,
    String? processedBy,
    // User info for display
    String? userName,
    String? userPhotoUrl,
    // Embassy info for display
    String? embassyName,
    String? embassyCountry,
  }) = _AdministrativeRequestModel;

  factory AdministrativeRequestModel.fromJson(Map<String, dynamic> json) =>
      _$AdministrativeRequestModelFromJson(json);

  factory AdministrativeRequestModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    data['id'] = doc.id;
    return AdministrativeRequestModel.fromJson(data);
  }

  Map<String, dynamic> toFirestore() {
    final json = toJson();
    json.remove('id');
    return json;
  }

  /// Get a human-readable label for the request type
  String get requestTypeLabel {
    switch (requestType) {
      case AdministrativeRequestType.passportRenewal:
        return 'Renouvellement de passeport';
      case AdministrativeRequestType.passportNewRequest:
        return 'Nouvelle demande de passeport';
      case AdministrativeRequestType.visaApplication:
        return 'Demande de visa';
      case AdministrativeRequestType.birthCertificate:
        return 'Acte de naissance';
      case AdministrativeRequestType.marriageCertificate:
        return 'Acte de mariage';
      case AdministrativeRequestType.deathCertificate:
        return 'Acte de décès';
      case AdministrativeRequestType.consularId:
        return 'Carte consulaire';
      case AdministrativeRequestType.legalDocument:
        return 'Document légal';
      case AdministrativeRequestType.laissezPasser:
        return 'Laissez-passer';
      case AdministrativeRequestType.powerOfAttorney:
        return 'Procuration';
      case AdministrativeRequestType.inscription:
        return 'Inscription consulaire';
      case AdministrativeRequestType.other:
        return 'Autre demande';
    }
  }

  /// Get a human-readable label for the status
  String get statusLabel {
    switch (status) {
      case AdministrativeRequestStatus.draft:
        return 'Brouillon';
      case AdministrativeRequestStatus.submitted:
        return 'Soumise';
      case AdministrativeRequestStatus.received:
        return 'Reçue';
      case AdministrativeRequestStatus.processing:
        return 'En cours de traitement';
      case AdministrativeRequestStatus.additionalInfoRequired:
        return 'Informations supplémentaires requises';
      case AdministrativeRequestStatus.completed:
        return 'Terminée';
      case AdministrativeRequestStatus.rejected:
        return 'Rejetée';
      case AdministrativeRequestStatus.cancelled:
        return 'Annulée';
    }
  }
}
