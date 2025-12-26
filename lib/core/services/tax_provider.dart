import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'tax_service.dart';

part 'tax_provider.g.dart';

// ============ SERVICE PROVIDER ============

@riverpod
TaxService taxService(Ref ref) {
  return TaxService.instance;
}

// ============ TAX CALCULATION ============

@riverpod
TaxBreakdown calculateProductTax(
  Ref ref, {
  required double amount,
  required String category,
  required int quantity,
  double? customTaxRate,
  bool isTaxExemptSeller = false,
}) {
  final service = ref.watch(taxServiceProvider);

  // If seller set custom tax rate, use it
  if (customTaxRate != null) {
    final subtotal = amount * quantity;
    final taxAmount = subtotal * customTaxRate;
    final platformFee = subtotal * 0.05; // 5% platform fee

    return TaxBreakdown(
      subtotal: subtotal,
      taxAmount: taxAmount,
      platformFee: platformFee,
      total: subtotal + taxAmount,
      taxRate: customTaxRate,
      category: customTaxRate > 0 ? TaxCategory.standard : TaxCategory.exempt,
      isTaxable: customTaxRate > 0,
      exemptionReason: customTaxRate == 0 ? 'Exonere par le vendeur' : null,
    );
  }

  return service.calculateTax(
    amount: amount,
    productCategory: category,
    quantity: quantity,
    isTaxExemptSeller: isTaxExemptSeller,
  );
}

@riverpod
TaxBreakdown calculateCartTax(
  Ref ref,
  List<CartTaxItem> items,
) {
  final service = ref.watch(taxServiceProvider);
  return service.calculateCartTax(items: items);
}

// ============ TAX RATES ============

@riverpod
double taxRateForCategory(Ref ref, String category) {
  final service = ref.watch(taxServiceProvider);
  return service.getTaxRate(category);
}

@riverpod
bool isCategoryTaxable(Ref ref, String category) {
  final service = ref.watch(taxServiceProvider);
  return service.isCategoryTaxable(category);
}

@riverpod
TaxCategory taxCategoryFor(Ref ref, String productCategory) {
  final service = ref.watch(taxServiceProvider);
  return service.getTaxCategory(productCategory);
}

// ============ TAX CONFIG ============

@riverpod
TaxConfig currentTaxConfig(Ref ref) {
  final service = ref.watch(taxServiceProvider);
  return service.getConfig();
}

// ============ SELLER TAX SETTINGS ============

/// Settings for how a seller wants to handle taxes
class SellerTaxSettings {
  final bool collectTax;
  final double? customTaxRate; // null = use default, 0 = exempt, >0 = custom rate
  final bool includeTaxInPrice; // Price shown includes tax or tax added at checkout
  final bool isTaxExempt; // Seller is tax exempt (small business, etc.)
  final String? taxId; // Tax identification number

  const SellerTaxSettings({
    this.collectTax = true,
    this.customTaxRate,
    this.includeTaxInPrice = false,
    this.isTaxExempt = false,
    this.taxId,
  });

  Map<String, dynamic> toJson() => {
        'collectTax': collectTax,
        'customTaxRate': customTaxRate,
        'includeTaxInPrice': includeTaxInPrice,
        'isTaxExempt': isTaxExempt,
        'taxId': taxId,
      };

  factory SellerTaxSettings.fromJson(Map<String, dynamic> json) =>
      SellerTaxSettings(
        collectTax: json['collectTax'] as bool? ?? true,
        customTaxRate: (json['customTaxRate'] as num?)?.toDouble(),
        includeTaxInPrice: json['includeTaxInPrice'] as bool? ?? false,
        isTaxExempt: json['isTaxExempt'] as bool? ?? false,
        taxId: json['taxId'] as String?,
      );

  SellerTaxSettings copyWith({
    bool? collectTax,
    double? customTaxRate,
    bool? includeTaxInPrice,
    bool? isTaxExempt,
    String? taxId,
  }) =>
      SellerTaxSettings(
        collectTax: collectTax ?? this.collectTax,
        customTaxRate: customTaxRate ?? this.customTaxRate,
        includeTaxInPrice: includeTaxInPrice ?? this.includeTaxInPrice,
        isTaxExempt: isTaxExempt ?? this.isTaxExempt,
        taxId: taxId ?? this.taxId,
      );

  /// Get effective tax rate
  double getEffectiveTaxRate(String category) {
    if (isTaxExempt || !collectTax) return 0.0;
    if (customTaxRate != null) return customTaxRate!;
    return TaxService.instance.getTaxRate(category);
  }
}

/// Product-level tax settings (overrides seller defaults)
class ProductTaxSettings {
  final bool? isTaxable; // null = use seller/category default
  final double? customTaxRate; // null = use default
  final TaxCategory? taxCategory; // null = auto-detect from product category

  const ProductTaxSettings({
    this.isTaxable,
    this.customTaxRate,
    this.taxCategory,
  });

  Map<String, dynamic> toJson() => {
        'isTaxable': isTaxable,
        'customTaxRate': customTaxRate,
        'taxCategory': taxCategory?.name,
      };

  factory ProductTaxSettings.fromJson(Map<String, dynamic> json) =>
      ProductTaxSettings(
        isTaxable: json['isTaxable'] as bool?,
        customTaxRate: (json['customTaxRate'] as num?)?.toDouble(),
        taxCategory: json['taxCategory'] != null
            ? TaxCategory.values.firstWhere(
                (e) => e.name == json['taxCategory'],
                orElse: () => TaxCategory.standard,
              )
            : null,
      );

  ProductTaxSettings copyWith({
    bool? isTaxable,
    double? customTaxRate,
    TaxCategory? taxCategory,
  }) =>
      ProductTaxSettings(
        isTaxable: isTaxable ?? this.isTaxable,
        customTaxRate: customTaxRate ?? this.customTaxRate,
        taxCategory: taxCategory ?? this.taxCategory,
      );
}

// ============ AVAILABLE TAX OPTIONS FOR UI ============

@riverpod
List<TaxOption> availableTaxOptions(Ref ref) {
  return [
    const TaxOption(
      id: 'default',
      label: 'Automatique',
      description: 'Taxe calculee selon la categorie du produit',
      rate: null,
    ),
    const TaxOption(
      id: 'exempt',
      label: 'Exonere',
      description: 'Pas de taxe sur ce produit',
      rate: 0.0,
    ),
    const TaxOption(
      id: 'standard',
      label: 'TVA Standard (19%)',
      description: 'Taux standard de TVA',
      rate: 0.19,
    ),
    const TaxOption(
      id: 'reduced',
      label: 'TVA Reduite (10%)',
      description: 'Taux reduit pour produits essentiels',
      rate: 0.10,
    ),
    const TaxOption(
      id: 'custom',
      label: 'Personnalise',
      description: 'Definir un taux personnalise',
      rate: null,
      isCustom: true,
    ),
  ];
}

/// Tax option for UI selection
class TaxOption {
  final String id;
  final String label;
  final String description;
  final double? rate;
  final bool isCustom;

  const TaxOption({
    required this.id,
    required this.label,
    required this.description,
    required this.rate,
    this.isCustom = false,
  });
}
