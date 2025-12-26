import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

/// Supported currencies in the app
enum Currency {
  xof, // Franc CFA (BCEAO)
  eur, // Euro
  usd, // US Dollar
  gbp, // British Pound
  cad, // Canadian Dollar
  chf, // Swiss Franc
}

extension CurrencyExtension on Currency {
  String get code {
    switch (this) {
      case Currency.xof:
        return 'XOF';
      case Currency.eur:
        return 'EUR';
      case Currency.usd:
        return 'USD';
      case Currency.gbp:
        return 'GBP';
      case Currency.cad:
        return 'CAD';
      case Currency.chf:
        return 'CHF';
    }
  }

  String get symbol {
    switch (this) {
      case Currency.xof:
        return 'FCFA';
      case Currency.eur:
        return '\u20AC';
      case Currency.usd:
        return '\$';
      case Currency.gbp:
        return '\u00A3';
      case Currency.cad:
        return 'CA\$';
      case Currency.chf:
        return 'CHF';
    }
  }

  String get name {
    switch (this) {
      case Currency.xof:
        return 'Franc CFA';
      case Currency.eur:
        return 'Euro';
      case Currency.usd:
        return 'Dollar US';
      case Currency.gbp:
        return 'Livre Sterling';
      case Currency.cad:
        return 'Dollar Canadien';
      case Currency.chf:
        return 'Franc Suisse';
    }
  }

  String get flag {
    switch (this) {
      case Currency.xof:
        return '\u{1F1F3}\u{1F1EA}'; // Niger flag
      case Currency.eur:
        return '\u{1F1EA}\u{1F1FA}'; // EU flag
      case Currency.usd:
        return '\u{1F1FA}\u{1F1F8}'; // US flag
      case Currency.gbp:
        return '\u{1F1EC}\u{1F1E7}'; // UK flag
      case Currency.cad:
        return '\u{1F1E8}\u{1F1E6}'; // Canada flag
      case Currency.chf:
        return '\u{1F1E8}\u{1F1ED}'; // Switzerland flag
    }
  }

  /// Number of decimal places for this currency
  int get decimals {
    switch (this) {
      case Currency.xof:
        return 0; // CFA has no decimals
      default:
        return 2;
    }
  }

  static Currency fromCode(String code) {
    return Currency.values.firstWhere(
      (c) => c.code == code.toUpperCase(),
      orElse: () => Currency.xof,
    );
  }
}

/// Exchange rate data
class ExchangeRate {
  final Currency from;
  final Currency to;
  final double rate;
  final DateTime timestamp;

  const ExchangeRate({
    required this.from,
    required this.to,
    required this.rate,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'from': from.code,
    'to': to.code,
    'rate': rate,
    'timestamp': timestamp.toIso8601String(),
  };

  factory ExchangeRate.fromJson(Map<String, dynamic> json) => ExchangeRate(
    from: CurrencyExtension.fromCode(json['from'] as String),
    to: CurrencyExtension.fromCode(json['to'] as String),
    rate: (json['rate'] as num).toDouble(),
    timestamp: DateTime.parse(json['timestamp'] as String),
  );

  bool get isStale =>
      DateTime.now().difference(timestamp) > const Duration(hours: 1);
}

/// Currency service for exchange rates and conversions
class CurrencyService {
  static CurrencyService? _instance;
  static CurrencyService get instance => _instance ??= CurrencyService._();
  CurrencyService._();

  static const String _cacheKey = 'exchange_rates_cache';
  static const String _lastFetchKey = 'exchange_rates_last_fetch';

  // Fallback rates (XOF-based) - Used when API is unavailable
  // EUR/XOF is fixed at 655.957 (CFA zone peg)
  static const Map<String, double> _fallbackRates = {
    'EUR_XOF': 655.957, // Fixed rate (CFA peg)
    'USD_XOF': 615.0,
    'GBP_XOF': 780.0,
    'CAD_XOF': 455.0,
    'CHF_XOF': 690.0,
    'XOF_EUR': 0.001524,
    'XOF_USD': 0.001626,
    'XOF_GBP': 0.001282,
    'XOF_CAD': 0.002198,
    'XOF_CHF': 0.001449,
  };

  Map<String, ExchangeRate> _cachedRates = {};
  DateTime? _lastFetch;

  /// Initialize the service and load cached rates
  Future<void> initialize() async {
    await _loadCachedRates();
    // Fetch fresh rates in background
    fetchRates();
  }

  /// Fetch latest exchange rates from API
  Future<void> fetchRates() async {
    try {
      // Using exchangerate-api.com (free tier: 1500 requests/month)
      // You can replace with your preferred API
      const apiKey = 'YOUR_API_KEY'; // Replace with actual key or use env
      const baseUrl = 'https://v6.exchangerate-api.com/v6';

      // For production, use a real API. For now, use fallback rates.
      if (apiKey == 'YOUR_API_KEY') {
        debugPrint(
          'CurrencyService: Using fallback rates (no API key configured)',
        );
        _useLocalRates();
        return;
      }

      final response = await http.get(Uri.parse('$baseUrl/$apiKey/latest/EUR'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final rates = data['conversion_rates'] as Map<String, dynamic>;
        final now = DateTime.now();

        // Store rates relative to EUR
        for (final currency in Currency.values) {
          if (currency == Currency.eur) continue;

          final rate = rates[currency.code];
          if (rate != null) {
            final key = 'EUR_${currency.code}';
            _cachedRates[key] = ExchangeRate(
              from: Currency.eur,
              to: currency,
              rate: (rate as num).toDouble(),
              timestamp: now,
            );

            // Also store inverse
            final inverseKey = '${currency.code}_EUR';
            _cachedRates[inverseKey] = ExchangeRate(
              from: currency,
              to: Currency.eur,
              rate: 1.0 / rate.toDouble(),
              timestamp: now,
            );
          }
        }

        _lastFetch = now;
        await _saveCachedRates();
        debugPrint('CurrencyService: Rates updated successfully');
      }
    } catch (e) {
      debugPrint('CurrencyService: Error fetching rates: $e');
      _useLocalRates();
    }
  }

  void _useLocalRates() {
    final now = DateTime.now();
    _fallbackRates.forEach((key, rate) {
      final parts = key.split('_');
      _cachedRates[key] = ExchangeRate(
        from: CurrencyExtension.fromCode(parts[0]),
        to: CurrencyExtension.fromCode(parts[1]),
        rate: rate,
        timestamp: now,
      );
    });
  }

  /// Get exchange rate between two currencies
  double getRate(Currency from, Currency to) {
    if (from == to) return 1.0;

    // Direct rate
    final directKey = '${from.code}_${to.code}';
    if (_cachedRates.containsKey(directKey)) {
      return _cachedRates[directKey]!.rate;
    }

    // Try via EUR as intermediary
    final fromToEur = '${from.code}_EUR';
    final eurToTo = 'EUR_${to.code}';

    if (_cachedRates.containsKey(fromToEur) &&
        _cachedRates.containsKey(eurToTo)) {
      return _cachedRates[fromToEur]!.rate * _cachedRates[eurToTo]!.rate;
    }

    // Fallback
    if (_fallbackRates.containsKey(directKey)) {
      return _fallbackRates[directKey]!;
    }

    // Last resort: calculate via XOF
    final fromXof = _fallbackRates['${from.code}_XOF'] ?? 1.0;
    final toXof = _fallbackRates['XOF_${to.code}'] ?? 1.0;
    return fromXof * toXof;
  }

  /// Convert amount from one currency to another
  double convert(double amount, Currency from, Currency to) {
    return amount * getRate(from, to);
  }

  /// Format amount with currency symbol
  String format(double amount, Currency currency, {bool showSymbol = true}) {
    final formatted = amount.toStringAsFixed(currency.decimals);

    // Add thousand separators
    final parts = formatted.split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]} ',
    );
    final result = parts.length > 1 ? '$intPart.${parts[1]}' : intPart;

    if (showSymbol) {
      // XOF symbol comes after the amount
      if (currency == Currency.xof) {
        return '$result ${currency.symbol}';
      }
      return '${currency.symbol}$result';
    }
    return result;
  }

  /// Convert and format in one step
  String convertAndFormat(
    double amount,
    Currency from,
    Currency to, {
    bool showSymbol = true,
  }) {
    final converted = convert(amount, from, to);
    return format(converted, to, showSymbol: showSymbol);
  }

  /// Get currency based on country code
  Currency getCurrencyForCountry(String countryCode) {
    switch (countryCode.toUpperCase()) {
      case 'NE': // Niger
      case 'BJ': // Benin
      case 'BF': // Burkina Faso
      case 'CI': // Cote d'Ivoire
      case 'GW': // Guinea-Bissau
      case 'ML': // Mali
      case 'SN': // Senegal
      case 'TG': // Togo
        return Currency.xof;
      case 'FR': // France
      case 'DE': // Germany
      case 'IT': // Italy
      case 'ES': // Spain
      case 'BE': // Belgium
      case 'NL': // Netherlands
      case 'PT': // Portugal
      case 'AT': // Austria
      case 'IE': // Ireland
      case 'FI': // Finland
        return Currency.eur;
      case 'US':
        return Currency.usd;
      case 'GB':
        return Currency.gbp;
      case 'CA':
        return Currency.cad;
      case 'CH':
        return Currency.chf;
      default:
        return Currency.eur; // Default for diaspora
    }
  }

  Future<void> _loadCachedRates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey);
      final lastFetchStr = prefs.getString(_lastFetchKey);

      if (cached != null) {
        final decoded = jsonDecode(cached) as Map<String, dynamic>;
        _cachedRates = decoded.map(
          (key, value) => MapEntry(
            key,
            ExchangeRate.fromJson(value as Map<String, dynamic>),
          ),
        );
      }

      if (lastFetchStr != null) {
        _lastFetch = DateTime.parse(lastFetchStr);
      }

      // If no cache or stale, use fallback
      if (_cachedRates.isEmpty ||
          _lastFetch == null ||
          DateTime.now().difference(_lastFetch!) > const Duration(hours: 24)) {
        _useLocalRates();
      }
    } catch (e) {
      debugPrint('CurrencyService: Error loading cached rates: $e');
      _useLocalRates();
    }
  }

  Future<void> _saveCachedRates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(
        _cachedRates.map((key, value) => MapEntry(key, value.toJson())),
      );
      await prefs.setString(_cacheKey, encoded);
      if (_lastFetch != null) {
        await prefs.setString(_lastFetchKey, _lastFetch!.toIso8601String());
      }
    } catch (e) {
      debugPrint('CurrencyService: Error saving cached rates: $e');
    }
  }

  /// Check if rates need refresh
  bool get needsRefresh =>
      _lastFetch == null ||
      DateTime.now().difference(_lastFetch!) > const Duration(hours: 1);

  /// Get all available currencies
  List<Currency> get availableCurrencies => Currency.values;

  /// Get rates summary for display
  Map<String, double> getRatesSummary(Currency base) {
    final summary = <String, double>{};
    for (final currency in Currency.values) {
      if (currency != base) {
        summary[currency.code] = getRate(base, currency);
      }
    }
    return summary;
  }
}
