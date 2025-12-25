import 'package:freezed_annotation/freezed_annotation.dart';

part 'legal_content_model.freezed.dart';
part 'legal_content_model.g.dart';

@freezed
class LegalContentModel with _$LegalContentModel {
  const factory LegalContentModel({
    required String id,
    required String type, // 'terms' ou 'privacy'
    required String title,
    required String version,
    required List<LegalSectionModel> sections,
    required DateTime updatedAt,
    String? summary, // Résumé des changements pour les mises à jour
  }) = _LegalContentModel;

  factory LegalContentModel.fromJson(Map<String, dynamic> json) =>
      _$LegalContentModelFromJson(json);
}

@freezed
class LegalSectionModel with _$LegalSectionModel {
  const factory LegalSectionModel({
    required String title,
    required String content,
    int? order,
  }) = _LegalSectionModel;

  factory LegalSectionModel.fromJson(Map<String, dynamic> json) =>
      _$LegalSectionModelFromJson(json);
}

@freezed
class UserLegalAcceptance with _$UserLegalAcceptance {
  const factory UserLegalAcceptance({
    required String termsVersion,
    required String privacyVersion,
    required DateTime acceptedAt,
  }) = _UserLegalAcceptance;

  factory UserLegalAcceptance.fromJson(Map<String, dynamic> json) =>
      _$UserLegalAcceptanceFromJson(json);
}
