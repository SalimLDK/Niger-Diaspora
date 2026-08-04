import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../../core/models/country.dart';

export '../../../../core/models/country.dart';

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
    String? location, // City/address details
    Country? country, // Country for filtering
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

  /// Convert to JSON for local storage
  Map<String, dynamic> toJson() => {
    'id': id,
    'sellerId': sellerId,
    'sellerName': sellerName,
    'sellerPhotoUrl': sellerPhotoUrl,
    'title': title,
    'description': description,
    'price': price,
    'currency': currency,
    'imageUrls': imageUrls,
    'category': category.name,
    'condition': condition.name,
    'location': location,
    'country': country?.name,
    'isAvailable': isAvailable,
    'quantity': quantity,
    'viewCount': viewCount,
    'tags': tags,
    'isTaxable': isTaxable,
    'customTaxRate': customTaxRate,
    'taxIncludedInPrice': taxIncludedInPrice,
    'createdAt': createdAt?.toUtc().toIso8601String(),
    'updatedAt': updatedAt?.toUtc().toIso8601String(),
  };

  /// Create from JSON
  static ProductEntity fromJson(Map<String, dynamic> json) {
    return ProductEntity(
      id: json['id'] as String? ?? '',
      sellerId: json['sellerId'] as String? ?? '',
      sellerName: json['sellerName'] as String?,
      sellerPhotoUrl: json['sellerPhotoUrl'] as String?,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'XOF',
      imageUrls: (json['imageUrls'] as List<dynamic>?)?.cast<String>() ?? [],
      category: ProductCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => ProductCategory.other,
      ),
      condition: ProductCondition.values.firstWhere(
        (e) => e.name == json['condition'],
        orElse: () => ProductCondition.newProduct,
      ),
      location: json['location'] as String?,
      country: json['country'] != null
          ? Country.values.firstWhere(
              (e) => e.name == json['country'],
              orElse: () => Country.other,
            )
          : null,
      isAvailable: json['isAvailable'] as bool? ?? true,
      quantity: json['quantity'] as int? ?? 1,
      viewCount: json['viewCount'] as int? ?? 0,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      isTaxable: json['isTaxable'] as bool? ?? true,
      customTaxRate: (json['customTaxRate'] as num?)?.toDouble(),
      taxIncludedInPrice: json['taxIncludedInPrice'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)?.toLocal()
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)?.toLocal()
          : null,
    );
  }

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
