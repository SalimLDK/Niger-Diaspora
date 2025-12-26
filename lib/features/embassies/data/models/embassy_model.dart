import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/embassy_entity.dart';
import 'embassy_activity_model.dart';
import 'embassy_news_model.dart';

part 'embassy_model.freezed.dart';
part 'embassy_model.g.dart';

@freezed
class EmbassyModel with _$EmbassyModel {
  const EmbassyModel._();

  const factory EmbassyModel({
    required String id,
    required String name,
    required String country,
    required String city,
    required String address,
    @JsonKey(name: 'phone')
    String? phone, // Adjusted to match entity field if possible or map
    String? email,
    String? website,
    double? latitude,
    double? longitude,
    String? imageUrl,
    @Default('embassy') String type,
    @Default([]) List<String> services,
    @Default({}) Map<String, String> openingHours,
    @Default(false) bool isVerified,
    @Default(false) bool isSuspended,
    @JsonKey(fromJson: _timestampToDateTime, toJson: _dateTimeToTimestamp)
    DateTime? verifiedAt,
    String? rejectionReason,
    @Default([]) List<String> jurisdictionCountries,
    @Default([]) List<EmbassyActivityModel> activities,
    @Default([]) List<EmbassyNewsModel> news,
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
      email: entity.email,
      website: entity.website,
      latitude: entity.latitude,
      longitude: entity.longitude,
      imageUrl: entity.imageUrl,
      type: 'embassy', // Default or from entity if available
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
      email: email,
      website: website,
      latitude: latitude ?? 0.0,
      longitude: longitude ?? 0.0,
      imageUrl: imageUrl,
      services: services,
      openingHours: openingHours,
      isVerified: isVerified,
      isSuspended: isSuspended,
      verifiedAt: verifiedAt,
      rejectionReason: rejectionReason,
      jurisdictionCountries: jurisdictionCountries,
      activities: activities.map((e) => e.toEntity()).toList(),
      news: news.map((e) => e.toEntity()).toList(),
    );
  }
}

DateTime? _timestampToDateTime(dynamic json) {
  if (json == null) return null;
  if (json is DateTime) return json;
  if (json is Timestamp) return json.toDate();
  if (json is int) return DateTime.fromMillisecondsSinceEpoch(json);
  return null;
}

dynamic _dateTimeToTimestamp(DateTime? dateTime) {
  if (dateTime == null) return null;
  return Timestamp.fromDate(dateTime);
}
