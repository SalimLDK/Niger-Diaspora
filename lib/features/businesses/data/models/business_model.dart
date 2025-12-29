import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/business_entity.dart';

part 'business_model.freezed.dart';
part 'business_model.g.dart';

@freezed
class BusinessModel with _$BusinessModel {
  const BusinessModel._();

  const factory BusinessModel({
    required String id,
    required String ownerId,
    String? ownerName,
    required String name,
    required String description,
    @Default('other') String category,
    @Default([]) List<String> photoUrls,
    String? logoUrl,
    String? phone,
    String? email,
    String? website,
    String? address,
    String? city,
    String? country,
    double? latitude,
    double? longitude,
    @Default({}) Map<String, dynamic> openingHours,
    @Default(false) bool isVerified,
    @Default(false) bool isBoosted,
    DateTime? boostExpiresAt,
    @Default(0.0) double averageRating,
    @Default(0) int reviewCount,
    @Default(0) int viewCount,
    @Default([]) List<String> tags,
    @Default([]) List<String> services,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _BusinessModel;

  factory BusinessModel.fromJson(Map<String, dynamic> json) =>
      _$BusinessModelFromJson(json);

  /// Factory pour créer un BusinessModel depuis un document Firestore
  /// Gère correctement la conversion des Timestamps en DateTime
  factory BusinessModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    // Convertir les Timestamps en strings ISO8601 pour la désérialisation JSON
    final processedData = <String, dynamic>{
      ...data,
      'id': doc.id,
    };

    // Conversion des timestamps
    if (data['createdAt'] is Timestamp) {
      processedData['createdAt'] = (data['createdAt'] as Timestamp).toDate().toIso8601String();
    }
    if (data['updatedAt'] is Timestamp) {
      processedData['updatedAt'] = (data['updatedAt'] as Timestamp).toDate().toIso8601String();
    }
    if (data['boostExpiresAt'] is Timestamp) {
      processedData['boostExpiresAt'] = (data['boostExpiresAt'] as Timestamp).toDate().toIso8601String();
    }

    // Assurer que les listes sont bien des List<String>
    if (data['photoUrls'] != null) {
      processedData['photoUrls'] = (data['photoUrls'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    }
    if (data['tags'] != null) {
      processedData['tags'] = (data['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    }
    if (data['services'] != null) {
      processedData['services'] = (data['services'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    }

    return BusinessModel.fromJson(processedData);
  }

  BusinessEntity toEntity() => BusinessEntity(
        id: id,
        ownerId: ownerId,
        ownerName: ownerName,
        name: name,
        description: description,
        category: _parseCategory(category),
        photoUrls: photoUrls,
        logoUrl: logoUrl,
        phone: phone,
        email: email,
        website: website,
        address: address,
        city: city,
        country: country,
        latitude: latitude,
        longitude: longitude,
        openingHours: _parseOpeningHours(openingHours),
        isVerified: isVerified,
        isBoosted: isBoosted,
        boostExpiresAt: boostExpiresAt,
        averageRating: averageRating,
        reviewCount: reviewCount,
        viewCount: viewCount,
        tags: tags,
        services: services,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  static BusinessCategory _parseCategory(String value) {
    return BusinessCategory.values.firstWhere(
      (e) => e.name == value,
      orElse: () => BusinessCategory.other,
    );
  }

  static Map<String, OpeningHours> _parseOpeningHours(Map<String, dynamic> data) {
    final result = <String, OpeningHours>{};
    data.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        result[key] = OpeningHours.fromJson(value);
      }
    });
    return result;
  }

  static Map<String, dynamic> _openingHoursToJson(Map<String, OpeningHours> data) {
    final result = <String, dynamic>{};
    data.forEach((key, value) {
      result[key] = value.toJson();
    });
    return result;
  }

  factory BusinessModel.fromEntity(BusinessEntity entity) => BusinessModel(
        id: entity.id,
        ownerId: entity.ownerId,
        ownerName: entity.ownerName,
        name: entity.name,
        description: entity.description,
        category: entity.category.name,
        photoUrls: entity.photoUrls,
        logoUrl: entity.logoUrl,
        phone: entity.phone,
        email: entity.email,
        website: entity.website,
        address: entity.address,
        city: entity.city,
        country: entity.country,
        latitude: entity.latitude,
        longitude: entity.longitude,
        openingHours: _openingHoursToJson(entity.openingHours),
        isVerified: entity.isVerified,
        isBoosted: entity.isBoosted,
        boostExpiresAt: entity.boostExpiresAt,
        averageRating: entity.averageRating,
        reviewCount: entity.reviewCount,
        viewCount: entity.viewCount,
        tags: entity.tags,
        services: entity.services,
        createdAt: entity.createdAt,
        updatedAt: entity.updatedAt,
      );
}
