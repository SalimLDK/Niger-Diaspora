/// Tax categories for products and services
enum TaxCategory {
  /// Standard VAT rate (19% in Niger)
  standard,

  /// Reduced rate for essential goods
  reduced,

  /// Zero-rated (taxable but at 0%)
  zeroRated,

  /// Exempt from VAT
  exempt,
}

extension TaxCategoryExtension on TaxCategory {
  String get label {
    switch (this) {
      case TaxCategory.standard:
        return 'Standard';
      case TaxCategory.reduced:
        return 'Reduit';
      case TaxCategory.zeroRated:
        return 'Taux zero';
      case TaxCategory.exempt:
        return 'Exonere';
    }
  }

  String get description {
    switch (this) {
      case TaxCategory.standard:
        return 'Taux standard de TVA';
      case TaxCategory.reduced:
        return 'Taux reduit pour produits essentiels';
      case TaxCategory.zeroRated:
        return 'Taxable a 0%';
      case TaxCategory.exempt:
        return 'Exonere de TVA';
    }
  }
}

/// Product categories and their tax treatment
enum ProductTaxType {
  /// General merchandise - Standard VAT
  general,

  /// Food products - Often exempt or reduced
  food,

  /// Handmade/Artisanal - May have exemptions
  artisanat,

  /// Health/Medical - Usually exempt
  health,

  /// Education/Books - Usually exempt
  education,

  /// Services - Standard VAT
  services,

  /// Real estate - Special rules
  realEstate,

  /// Electronics - Standard VAT
  electronics,

  /// Clothing - Standard VAT (may have reduced for essentials)
  clothing,
}

extension ProductTaxTypeExtension on ProductTaxType {
  TaxCategory get defaultTaxCategory {
    switch (this) {
      case ProductTaxType.food:
        return TaxCategory.exempt; // Basic food often exempt
      case ProductTaxType.health:
        return TaxCategory.exempt;
      case ProductTaxType.education:
        return TaxCategory.exempt;
      case ProductTaxType.artisanat:
        return TaxCategory.reduced; // Support local artisans
      case ProductTaxType.realEstate:
        return TaxCategory.zeroRated;
      default:
        return TaxCategory.standard;
    }
  }
}

/// Tax calculation result
class TaxBreakdown {
  final double subtotal;
  final double taxAmount;
  final double platformFee;
  final double total;
  final double taxRate;
  final TaxCategory category;
  final bool isTaxable;
  final String? exemptionReason;

  const TaxBreakdown({
    required this.subtotal,
    required this.taxAmount,
    required this.platformFee,
    required this.total,
    required this.taxRate,
    required this.category,
    required this.isTaxable,
    this.exemptionReason,
  });

  Map<String, dynamic> toJson() => {
        'subtotal': subtotal,
        'taxAmount': taxAmount,
        'platformFee': platformFee,
        'total': total,
        'taxRate': taxRate,
        'category': category.name,
        'isTaxable': isTaxable,
        'exemptionReason': exemptionReason,
      };

  factory TaxBreakdown.fromJson(Map<String, dynamic> json) => TaxBreakdown(
        subtotal: (json['subtotal'] as num).toDouble(),
        taxAmount: (json['taxAmount'] as num).toDouble(),
        platformFee: (json['platformFee'] as num).toDouble(),
        total: (json['total'] as num).toDouble(),
        taxRate: (json['taxRate'] as num).toDouble(),
        category: TaxCategory.values.firstWhere(
          (e) => e.name == json['category'],
          orElse: () => TaxCategory.standard,
        ),
        isTaxable: json['isTaxable'] as bool? ?? true,
        exemptionReason: json['exemptionReason'] as String?,
      );
}

/// Tax service for calculating taxes on products and services
class TaxService {
  static TaxService? _instance;
  static TaxService get instance => _instance ??= TaxService._();
  TaxService._();

  // Tax rates for Niger (can be configured per country)
  static const Map<String, TaxConfig> _countryTaxConfigs = {
    'NE': TaxConfig(
      countryCode: 'NE',
      countryName: 'Niger',
      standardRate: 0.19, // 19% TVA
      reducedRate: 0.10, // 10% reduced
      platformFeeRate: 0.05, // 5% platform fee
      currency: 'XOF',
    ),
    'FR': TaxConfig(
      countryCode: 'FR',
      countryName: 'France',
      standardRate: 0.20, // 20% TVA
      reducedRate: 0.055, // 5.5% reduced
      platformFeeRate: 0.05,
      currency: 'EUR',
    ),
    'DEFAULT': TaxConfig(
      countryCode: 'DEFAULT',
      countryName: 'Default',
      standardRate: 0.19,
      reducedRate: 0.10,
      platformFeeRate: 0.05,
      currency: 'XOF',
    ),
  };

  // Categories exempt from tax
  static const List<String> _exemptCategories = [
    'alimentation', // Food
    'sante', // Health
    'education', // Education
  ];

  // Categories with reduced tax
  static const List<String> _reducedCategories = [
    'artisanat', // Handmade goods
  ];

  String _currentCountry = 'NE';

  /// Set the current country for tax calculations
  void setCountry(String countryCode) {
    _currentCountry = countryCode.toUpperCase();
  }

  /// Get tax configuration for a country
  TaxConfig getConfig([String? countryCode]) {
    final code = countryCode?.toUpperCase() ?? _currentCountry;
    return _countryTaxConfigs[code] ?? _countryTaxConfigs['DEFAULT']!;
  }

  /// Check if a product category is taxable
  bool isCategoryTaxable(String category) {
    return !_exemptCategories.contains(category.toLowerCase());
  }

  /// Check if a product category has reduced tax
  bool isCategoryReduced(String category) {
    return _reducedCategories.contains(category.toLowerCase());
  }

  /// Get tax category for a product category
  TaxCategory getTaxCategory(String productCategory) {
    final category = productCategory.toLowerCase();

    if (_exemptCategories.contains(category)) {
      return TaxCategory.exempt;
    }
    if (_reducedCategories.contains(category)) {
      return TaxCategory.reduced;
    }
    return TaxCategory.standard;
  }

  /// Get tax rate for a category
  double getTaxRate(String productCategory, [String? countryCode]) {
    final config = getConfig(countryCode);
    final taxCategory = getTaxCategory(productCategory);

    switch (taxCategory) {
      case TaxCategory.standard:
        return config.standardRate;
      case TaxCategory.reduced:
        return config.reducedRate;
      case TaxCategory.zeroRated:
      case TaxCategory.exempt:
        return 0.0;
    }
  }

  /// Calculate tax breakdown for a product
  TaxBreakdown calculateTax({
    required double amount,
    required String productCategory,
    required int quantity,
    bool includePlatformFee = true,
    bool isTaxExemptSeller = false,
    String? countryCode,
  }) {
    final config = getConfig(countryCode);
    final subtotal = amount * quantity;
    final taxCategory = getTaxCategory(productCategory);

    // Check if taxable
    final isTaxable =
        taxCategory != TaxCategory.exempt && !isTaxExemptSeller;

    // Calculate tax
    double taxRate = 0.0;
    double taxAmount = 0.0;
    String? exemptionReason;

    if (isTaxable) {
      taxRate = getTaxRate(productCategory, countryCode);
      taxAmount = subtotal * taxRate;
    } else {
      if (taxCategory == TaxCategory.exempt) {
        exemptionReason = 'Categorie exoneree de TVA';
      } else if (isTaxExemptSeller) {
        exemptionReason = 'Vendeur exonere de TVA';
      }
    }

    // Platform fee (always applied)
    final platformFee = includePlatformFee ? subtotal * config.platformFeeRate : 0.0;

    // Total
    final total = subtotal + taxAmount;

    return TaxBreakdown(
      subtotal: subtotal,
      taxAmount: taxAmount,
      platformFee: platformFee,
      total: total,
      taxRate: taxRate,
      category: taxCategory,
      isTaxable: isTaxable,
      exemptionReason: exemptionReason,
    );
  }

  /// Calculate tax for multiple items (cart)
  TaxBreakdown calculateCartTax({
    required List<CartTaxItem> items,
    bool includePlatformFee = true,
    String? countryCode,
  }) {
    final config = getConfig(countryCode);

    double totalSubtotal = 0.0;
    double totalTax = 0.0;

    for (final item in items) {
      final breakdown = calculateTax(
        amount: item.price,
        productCategory: item.category,
        quantity: item.quantity,
        includePlatformFee: false,
        isTaxExemptSeller: item.isTaxExemptSeller,
        countryCode: countryCode,
      );
      totalSubtotal += breakdown.subtotal;
      totalTax += breakdown.taxAmount;
    }

    final platformFee =
        includePlatformFee ? totalSubtotal * config.platformFeeRate : 0.0;
    final total = totalSubtotal + totalTax;

    // Determine overall tax category
    final hasExempt = items.any((i) =>
        getTaxCategory(i.category) == TaxCategory.exempt || i.isTaxExemptSeller);
    final allExempt = items.every((i) =>
        getTaxCategory(i.category) == TaxCategory.exempt || i.isTaxExemptSeller);

    TaxCategory overallCategory;
    if (allExempt) {
      overallCategory = TaxCategory.exempt;
    } else if (hasExempt) {
      overallCategory = TaxCategory.reduced; // Mixed
    } else {
      overallCategory = TaxCategory.standard;
    }

    return TaxBreakdown(
      subtotal: totalSubtotal,
      taxAmount: totalTax,
      platformFee: platformFee,
      total: total,
      taxRate: totalSubtotal > 0 ? totalTax / totalSubtotal : 0.0,
      category: overallCategory,
      isTaxable: totalTax > 0,
      exemptionReason: allExempt ? 'Tous les articles sont exoneres' : null,
    );
  }

  /// Format tax amount for display
  String formatTax(double amount, {String currency = 'XOF'}) {
    if (currency == 'XOF') {
      return '${amount.toStringAsFixed(0)} FCFA';
    }
    return '${amount.toStringAsFixed(2)} $currency';
  }

  /// Get tax summary text
  String getTaxSummary(TaxBreakdown breakdown) {
    if (!breakdown.isTaxable) {
      return breakdown.exemptionReason ?? 'Exonere de TVA';
    }
    final ratePercent = (breakdown.taxRate * 100).toStringAsFixed(0);
    return 'TVA $ratePercent%';
  }
}

/// Tax configuration for a country
class TaxConfig {
  final String countryCode;
  final String countryName;
  final double standardRate;
  final double reducedRate;
  final double platformFeeRate;
  final String currency;

  const TaxConfig({
    required this.countryCode,
    required this.countryName,
    required this.standardRate,
    required this.reducedRate,
    required this.platformFeeRate,
    required this.currency,
  });
}

/// Item for cart tax calculation
class CartTaxItem {
  final String productId;
  final String category;
  final double price;
  final int quantity;
  final bool isTaxExemptSeller;

  const CartTaxItem({
    required this.productId,
    required this.category,
    required this.price,
    required this.quantity,
    this.isTaxExemptSeller = false,
  });
}
