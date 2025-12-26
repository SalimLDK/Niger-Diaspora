import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'currency_service.dart';

part 'currency_provider.g.dart';

// ============ SERVICE PROVIDERS ============

@riverpod
CurrencyService currencyService(Ref ref) {
  final service = CurrencyService.instance;
  // Initialize in background
  service.initialize();
  return service;
}

// ============ USER CURRENCY PREFERENCE ============

@riverpod
class UserCurrencyPreference extends _$UserCurrencyPreference {
  static const String _prefKey = 'user_preferred_currency';

  @override
  Future<Currency> build() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_prefKey);
    if (code != null) {
      return CurrencyExtension.fromCode(code);
    }
    // Default based on locale or XOF
    return Currency.eur; // Default for diaspora users
  }

  Future<void> setCurrency(Currency currency) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, currency.code);
    state = AsyncData(currency);
  }
}

// ============ EXCHANGE RATES ============

@riverpod
Future<double> exchangeRateForCurrency(
  Ref ref,
  Currency fromCurrency,
  Currency toCurrency,
) async {
  final service = ref.watch(currencyServiceProvider);
  return service.getRate(fromCurrency, toCurrency);
}

@riverpod
Future<Map<String, double>> allExchangeRates(Ref ref, Currency base) async {
  final service = ref.watch(currencyServiceProvider);
  return service.getRatesSummary(base);
}

// ============ CURRENCY CONVERSION ============

@riverpod
String convertedAmount(
  Ref ref,
  double amount,
  Currency fromCurrency,
  Currency toCurrency,
) {
  final service = ref.watch(currencyServiceProvider);
  return service.convertAndFormat(amount, fromCurrency, toCurrency);
}

@riverpod
String formattedAmount(Ref ref, double amount, Currency currency) {
  final service = ref.watch(currencyServiceProvider);
  return service.format(amount, currency);
}

// ============ AVAILABLE CURRENCIES ============

@riverpod
List<Currency> availableCurrencies(Ref ref) {
  return Currency.values;
}

// ============ CURRENCY SELECTOR STATE ============

@riverpod
class SelectedDisplayCurrency extends _$SelectedDisplayCurrency {
  @override
  Currency build() {
    // Try to get user preference, default to EUR
    final prefAsync = ref.watch(userCurrencyPreferenceProvider);
    return prefAsync.valueOrNull ?? Currency.eur;
  }

  void select(Currency currency) {
    state = currency;
    // Also save as preference
    ref.read(userCurrencyPreferenceProvider.notifier).setCurrency(currency);
  }
}
