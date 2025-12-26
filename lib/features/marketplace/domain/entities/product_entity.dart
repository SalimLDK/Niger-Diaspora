import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'product_entity.freezed.dart';

@freezed
class ProductEntity with _$ProductEntity {
  const factory ProductEntity({
    required String id,
    required String sellerId,
    String? sellerName,
    String? sellerPhotoUrl,
    required String title,
    required String description,
    required double price,
    @Default('XOF') String currency,
    @Default([]) List<String> imageUrls,
    @Default(ProductCategory.other) ProductCategory category,
    @Default(ProductCondition.newProduct) ProductCondition condition,
    String? location,
    @Default(true) bool isAvailable,
    @Default(1) int quantity,
    @Default(0) int viewCount,
    @Default([]) List<String> tags,
    // Tax settings - seller can customize
    @Default(true) bool isTaxable,
    double? customTaxRate, // null = use category default, 0 = exempt
    @Default(false) bool taxIncludedInPrice, // Is tax already in the displayed price?
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _ProductEntity;

  const ProductEntity._();

  /// Get effective tax rate based on settings
  double get effectiveTaxRate {
    if (!isTaxable) return 0.0;
    if (customTaxRate != null) return customTaxRate!;
    // Default rates by category
    return _getDefaultTaxRate(category);
  }

  /// Calculate tax amount for this product
  double getTaxAmount(int qty) {
    if (!isTaxable || taxIncludedInPrice) return 0.0;
    return price * qty * effectiveTaxRate;
  }

  /// Get price excluding tax (if tax was included)
  double get priceExcludingTax {
    if (!taxIncludedInPrice || !isTaxable) return price;
    return price / (1 + effectiveTaxRate);
  }

  /// Get total price including tax
  double getTotalWithTax(int qty) {
    if (taxIncludedInPrice) return price * qty;
    return (price * qty) + getTaxAmount(qty);
  }

  static double _getDefaultTaxRate(ProductCategory category) {
    switch (category) {
      case ProductCategory.alimentation:
        return 0.0; // Food exempt
      case ProductCategory.artisanat:
        return 0.10; // Reduced for artisans
      default:
        return 0.19; // Standard 19%
    }
  }
}

enum ProductCategory {
  artisanat,
  alimentation,
  vetements,
  services,
  immobilier,
  electronique,
  other,
}

enum ProductCondition {
  newProduct,
  likeNew,
  used,
  forParts,
}

extension ProductCategoryExtension on ProductCategory {
  String get label {
    switch (this) {
      case ProductCategory.artisanat:
        return 'Artisanat';
      case ProductCategory.alimentation:
        return 'Alimentation';
      case ProductCategory.vetements:
        return 'Vetements';
      case ProductCategory.services:
        return 'Services';
      case ProductCategory.immobilier:
        return 'Immobilier';
      case ProductCategory.electronique:
        return 'Electronique';
      case ProductCategory.other:
        return 'Autres';
    }
  }

  IconData get icon {
    switch (this) {
      case ProductCategory.artisanat:
        return Icons.handyman;
      case ProductCategory.alimentation:
        return Icons.restaurant;
      case ProductCategory.vetements:
        return Icons.checkroom;
      case ProductCategory.services:
        return Icons.miscellaneous_services;
      case ProductCategory.immobilier:
        return Icons.home;
      case ProductCategory.electronique:
        return Icons.devices;
      case ProductCategory.other:
        return Icons.category;
    }
  }
}

extension ProductConditionExtension on ProductCondition {
  String get label {
    switch (this) {
      case ProductCondition.newProduct:
        return 'Neuf';
      case ProductCondition.likeNew:
        return 'Comme neuf';
      case ProductCondition.used:
        return 'Occasion';
      case ProductCondition.forParts:
        return 'Pour pieces';
    }
  }
}
