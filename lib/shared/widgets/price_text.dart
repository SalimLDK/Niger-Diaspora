import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/currency_provider.dart';
import '../../core/services/currency_service.dart';

/// Widget reutilisable pour afficher les prix avec formatage et conversion optionnelle
class PriceText extends ConsumerWidget {
  /// Le montant a afficher
  final double amount;

  /// La devise originale du prix (code ISO ex: 'XOF', 'EUR')
  final String currency;

  /// Si true, convertit vers la devise preferee de l'utilisateur
  final bool convertToPreferred;

  /// Si true, affiche le prix original et le prix converti
  final bool showBothPrices;

  /// Style du texte principal
  final TextStyle? style;

  /// Style du texte secondaire (quand showBothPrices est true)
  final TextStyle? secondaryStyle;

  /// Si true, affiche le symbole de la devise
  final bool showSymbol;

  /// Texte optionnel avant le prix (ex: "Total: ")
  final String? prefix;

  /// Texte optionnel apres le prix
  final String? suffix;

  /// Alignement du texte principal
  final TextAlign? textAlign;

  const PriceText({
    super.key,
    required this.amount,
    required this.currency,
    this.convertToPreferred = false,
    this.showBothPrices = false,
    this.style,
    this.secondaryStyle,
    this.showSymbol = true,
    this.prefix,
    this.suffix,
    this.textAlign,
  });

  /// Constructeur pour les prix de produits
  factory PriceText.product({
    Key? key,
    required double price,
    required String currency,
    TextStyle? style,
    bool showConversion = false,
  }) {
    return PriceText(
      key: key,
      amount: price,
      currency: currency,
      convertToPreferred: showConversion,
      showBothPrices: showConversion,
      style: style,
    );
  }

  /// Constructeur pour les totaux de panier
  factory PriceText.cartTotal({
    Key? key,
    required double amount,
    required String currency,
    TextStyle? style,
    String? prefix,
  }) {
    return PriceText(
      key: key,
      amount: amount,
      currency: currency,
      convertToPreferred: true,
      showBothPrices: false,
      style: style,
      prefix: prefix,
    );
  }

  /// Constructeur simple sans conversion
  factory PriceText.simple({
    Key? key,
    required double amount,
    required String currency,
    TextStyle? style,
  }) {
    return PriceText(
      key: key,
      amount: amount,
      currency: currency,
      convertToPreferred: false,
      showBothPrices: false,
      style: style,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencyService = ref.watch(currencyServiceProvider);
    final preferredCurrencyAsync = ref.watch(userCurrencyPreferenceProvider);
    final preferredCurrency =
        preferredCurrencyAsync.valueOrNull ?? Currency.eur;

    final originalCurrency = CurrencyExtension.fromCode(currency);

    // Formater le prix original
    final formattedOriginal = currencyService.format(
      amount,
      originalCurrency,
      showSymbol: showSymbol,
    );

    // Verifier si la conversion est necessaire
    final needsConversion =
        convertToPreferred && originalCurrency != preferredCurrency;

    if (!needsConversion) {
      return Text(
        '${prefix ?? ''}$formattedOriginal${suffix ?? ''}',
        style: style,
        textAlign: textAlign,
      );
    }

    // Convertir et formater
    final convertedAmount = currencyService.convert(
      amount,
      originalCurrency,
      preferredCurrency,
    );
    final formattedConverted = currencyService.format(
      convertedAmount,
      preferredCurrency,
      showSymbol: showSymbol,
    );

    if (showBothPrices) {
      final theme = Theme.of(context);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${prefix ?? ''}$formattedOriginal${suffix ?? ''}',
            style: style,
            textAlign: textAlign,
          ),
          Text(
            '~ $formattedConverted',
            style: secondaryStyle ??
                style?.copyWith(
                  fontSize: (style?.fontSize ?? 14) * 0.85,
                  color: theme.colorScheme.outline,
                ) ??
                TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.outline,
                ),
          ),
        ],
      );
    }

    return Text(
      '${prefix ?? ''}$formattedConverted${suffix ?? ''}',
      style: style,
      textAlign: textAlign,
    );
  }
}

/// Widget pour afficher un prix avec indication de conversion
class PriceWithConversionIndicator extends ConsumerWidget {
  final double amount;
  final String currency;
  final TextStyle? style;
  final bool showIndicator;

  const PriceWithConversionIndicator({
    super.key,
    required this.amount,
    required this.currency,
    this.style,
    this.showIndicator = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencyService = ref.watch(currencyServiceProvider);
    final preferredCurrencyAsync = ref.watch(userCurrencyPreferenceProvider);
    final preferredCurrency =
        preferredCurrencyAsync.valueOrNull ?? Currency.eur;

    final originalCurrency = CurrencyExtension.fromCode(currency);
    final isConverted = originalCurrency != preferredCurrency;

    final displayAmount = isConverted
        ? currencyService.convert(amount, originalCurrency, preferredCurrency)
        : amount;

    final displayCurrency = isConverted ? preferredCurrency : originalCurrency;

    final formattedPrice = currencyService.format(displayAmount, displayCurrency);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(formattedPrice, style: style),
        if (showIndicator && isConverted) ...[
          const SizedBox(width: 4),
          Tooltip(
            message: 'Converti depuis ${originalCurrency.name}',
            child: Icon(
              Icons.swap_horiz,
              size: (style?.fontSize ?? 14) * 0.9,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ],
    );
  }
}
