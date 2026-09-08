import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/utils/date_parsing.dart';
import '../../domain/entities/embassy_entity.dart';
import 'embassy_activity_model.dart';
import 'embassy_news_model.dart';

part 'embassy_model.freezed.dart';
part 'embassy_model.g.dart';

/// Dates de l'annuaire, lisibles depuis les trois provenances du module.
///
/// L'annuaire vient désormais de Supabase (chaînes ISO 8601), mais la même
/// classe sert encore aux écrans d'administration adossés à Firestore
/// (`Timestamp`) et au cache local (chaînes ISO relues telles quelles).
///
/// `toJson` écrit une **chaîne ISO en UTC**, jamais un `Timestamp` : l'ancienne
/// version renvoyait un `Timestamp`, que `jsonEncode` ne sait pas sérialiser.
/// Le cache local appelant `jsonEncode(model.toJson())`, toute fiche portant un
/// `verifiedAt` faisait échouer la mise en cache — et l'exception, non
/// rattrapée par le dépôt qui ne guette que `ServerException`, remontait
/// jusqu'à l'écran. Le défaut restait invisible tant que la table était vide.
class EmbassyDateConverter implements JsonConverter<DateTime?, dynamic> {
  const EmbassyDateConverter();

  @override
  DateTime? fromJson(dynamic json) {
    if (json is Timestamp) return json.toDate().toLocal();
    return tryParseLocalDate(json);
  }

  @override
  dynamic toJson(DateTime? dateTime) => toIsoUtcOrNull(dateTime);
}

@freezed
class EmbassyModel with _$EmbassyModel {
  const EmbassyModel._();

  const factory EmbassyModel({
    required String id,
    required String name,
    required String country,
    required String city,
    required String address,
    String? phone,
    @Default([]) List<String> additionalPhones,
    String? fax,
    String? email,
    String? website,
    double? latitude,
    double? longitude,
    String? imageUrl,
    @Default(EmbassyPostType.embassy) String type,
    @Default([]) List<String> services,
    @Default({}) Map<String, String> openingHours,
    @Default(false) bool isVerified,
    @Default(false) bool isSuspended,
    @EmbassyDateConverter() DateTime? verifiedAt,
    String? rejectionReason,
    @Default([]) List<String> jurisdictionCountries,
    @Default([]) List<EmbassyActivityModel> activities,
    @Default([]) List<EmbassyNewsModel> news,
    // Availability fields
    @Default(false) bool isTemporarilyClosed,
    String? closureMessage,
    @EmbassyDateConverter() DateTime? reopenDate,
    @Default([]) List<String> upcomingServices,
    // Traçabilité de la fiche
    String? source,
    String? sourceUrl,
    @EmbassyDateConverter() DateTime? sourceCheckedAt,
    String? dataNotes,
  }) = _EmbassyModel;

  factory EmbassyModel.fromJson(Map<String, dynamic> json) =>
      _$EmbassyModelFromJson(json);

  factory EmbassyModel.fromEntity(EmbassyEntity entity) {
    return EmbassyModel(
      id: entity.id,
      name: entity.name,
      country: entity.country,
      city: entity.city,
      address: entity.address,
      phone: entity.phone,
      additionalPhones: entity.additionalPhones,
      fax: entity.fax,
      email: entity.email,
      website: entity.website,
      latitude: entity.latitude,
      longitude: entity.longitude,
      imageUrl: entity.imageUrl,
      // `type` était figé à 'embassy' ici : un consulat repassait ambassade
      // dès qu'il traversait le modèle.
      type: entity.type,
      services: entity.services,
      openingHours: entity.openingHours,
      isVerified: entity.isVerified,
      isSuspended: entity.isSuspended,
      verifiedAt: entity.verifiedAt,
      rejectionReason: entity.rejectionReason,
      jurisdictionCountries: entity.jurisdictionCountries,
      activities:
          entity.activities
              .map((e) => EmbassyActivityModel.fromEntity(e))
              .toList(),
      news: entity.news.map((e) => EmbassyNewsModel.fromEntity(e)).toList(),
      isTemporarilyClosed: entity.isTemporarilyClosed,
      closureMessage: entity.closureMessage,
      reopenDate: entity.reopenDate,
      upcomingServices: entity.upcomingServices,
      source: entity.source,
      sourceUrl: entity.sourceUrl,
      sourceCheckedAt: entity.sourceCheckedAt,
      dataNotes: entity.dataNotes,
    );
  }

  EmbassyEntity toEntity() {
    return EmbassyEntity(
      id: id,
      name: name,
      country: country,
      city: city,
      address: address,
      phone: phone,
      additionalPhones: additionalPhones,
      fax: fax,
      email: email,
      website: website,
      // Surtout pas `?? 0.0` : aucune fiche officielle ne porte de coordonnées,
      // et (0, 0) est un point réel, dans le golfe de Guinée. Le garde
      // `latitude != null` de la fiche de détail devenait toujours vrai, et le
      // bouton « voir sur la carte » y envoyait les 32 postes.
      latitude: latitude,
      longitude: longitude,
      imageUrl: imageUrl,
      type: type,
      services: services,
      openingHours: openingHours,
      isVerified: isVerified,
      isSuspended: isSuspended,
      verifiedAt: verifiedAt,
      rejectionReason: rejectionReason,
      jurisdictionCountries: jurisdictionCountries,
      activities: activities.map((e) => e.toEntity()).toList(),
      news: news.map((e) => e.toEntity()).toList(),
      isTemporarilyClosed: isTemporarilyClosed,
      closureMessage: closureMessage,
      reopenDate: reopenDate,
      upcomingServices: upcomingServices,
      source: source,
      sourceUrl: sourceUrl,
      sourceCheckedAt: sourceCheckedAt,
      dataNotes: dataNotes,
    );
  }
}
