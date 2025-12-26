import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'business_entity.freezed.dart';

@freezed
class BusinessEntity with _$BusinessEntity {
  const factory BusinessEntity({
    required String id,
    required String ownerId,
    String? ownerName,
    required String name,
    required String description,
    @Default(BusinessCategory.other) BusinessCategory category,
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
    @Default({}) Map<String, OpeningHours> openingHours,
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
  }) = _BusinessEntity;
}

class OpeningHours {
  final String open;
  final String close;
  final bool isClosed;

  const OpeningHours({
    required this.open,
    required this.close,
    this.isClosed = false,
  });

  factory OpeningHours.fromJson(Map<String, dynamic> json) => OpeningHours(
        open: json['open'] as String? ?? '09:00',
        close: json['close'] as String? ?? '18:00',
        isClosed: json['isClosed'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'open': open,
        'close': close,
        'isClosed': isClosed,
      };

  OpeningHours copyWith({
    String? open,
    String? close,
    bool? isClosed,
  }) =>
      OpeningHours(
        open: open ?? this.open,
        close: close ?? this.close,
        isClosed: isClosed ?? this.isClosed,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OpeningHours &&
          runtimeType == other.runtimeType &&
          open == other.open &&
          close == other.close &&
          isClosed == other.isClosed;

  @override
  int get hashCode => open.hashCode ^ close.hashCode ^ isClosed.hashCode;
}

enum BusinessCategory {
  restaurant,
  commerce,
  services,
  sante,
  juridique,
  education,
  beaute,
  transport,
  immobilier,
  artisanat,
  technologie,
  other,
}

extension BusinessCategoryExtension on BusinessCategory {
  String get label {
    switch (this) {
      case BusinessCategory.restaurant:
        return 'Restaurant';
      case BusinessCategory.commerce:
        return 'Commerce';
      case BusinessCategory.services:
        return 'Services';
      case BusinessCategory.sante:
        return 'Sante';
      case BusinessCategory.juridique:
        return 'Juridique';
      case BusinessCategory.education:
        return 'Education';
      case BusinessCategory.beaute:
        return 'Beaute';
      case BusinessCategory.transport:
        return 'Transport';
      case BusinessCategory.immobilier:
        return 'Immobilier';
      case BusinessCategory.artisanat:
        return 'Artisanat';
      case BusinessCategory.technologie:
        return 'Technologie';
      case BusinessCategory.other:
        return 'Autre';
    }
  }

  IconData get icon {
    switch (this) {
      case BusinessCategory.restaurant:
        return Icons.restaurant;
      case BusinessCategory.commerce:
        return Icons.store;
      case BusinessCategory.services:
        return Icons.miscellaneous_services;
      case BusinessCategory.sante:
        return Icons.local_hospital;
      case BusinessCategory.juridique:
        return Icons.gavel;
      case BusinessCategory.education:
        return Icons.school;
      case BusinessCategory.beaute:
        return Icons.spa;
      case BusinessCategory.transport:
        return Icons.local_shipping;
      case BusinessCategory.immobilier:
        return Icons.home_work;
      case BusinessCategory.artisanat:
        return Icons.handyman;
      case BusinessCategory.technologie:
        return Icons.computer;
      case BusinessCategory.other:
        return Icons.business;
    }
  }
}
