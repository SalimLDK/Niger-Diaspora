import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

/// Supported currencies in the app
enum Currency {
  // Major currencies
  xof, // Franc CFA (BCEAO)
  eur, // Euro
  usd, // US Dollar
  gbp, // British Pound
  cad, // Canadian Dollar
  chf, // Swiss Franc
  // African currencies
  ngn, // Nigerian Naira
  ghs, // Ghanaian Cedi
  mad, // Moroccan Dirham
  zar, // South African Rand
  xaf, // Franc CFA (BEAC)
  kes, // Kenyan Shilling
  egp, // Egyptian Pound
  tzs, // Tanzanian Shilling
  etb, // Ethiopian Birr
  // Asian currencies
  cny, // Chinese Yuan
  jpy, // Japanese Yen
  inr, // Indian Rupee
  krw, // Korean Won
  sgd, // Singapore Dollar
  hkd, // Hong Kong Dollar
  thb, // Thai Baht
  myr, // Malaysian Ringgit
  php, // Philippine Peso
  idr, // Indonesian Rupiah
  vnd, // Vietnamese Dong
  pkr, // Pakistani Rupee
  // European currencies (non-Euro)
  sek, // Swedish Krona
  nok, // Norwegian Krone
  dkk, // Danish Krone
  pln, // Polish Zloty
  czk, // Czech Koruna
  try_, // Turkish Lira (try_ because 'try' is reserved)
  rub, // Russian Ruble
  // Americas
  mxn, // Mexican Peso
  ars, // Argentine Peso
  clp, // Chilean Peso
  cop, // Colombian Peso
  // Other international currencies
  aud, // Australian Dollar
  nzd, // New Zealand Dollar
  brl, // Brazilian Real
  aed, // UAE Dirham
  sar, // Saudi Riyal
  qar, // Qatari Riyal
  kwd, // Kuwaiti Dinar
}

extension CurrencyExtension on Currency {
  String get code {
    switch (this) {
      // Major currencies
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
      // African currencies
      case Currency.ngn:
        return 'NGN';
      case Currency.ghs:
        return 'GHS';
      case Currency.mad:
        return 'MAD';
      case Currency.zar:
        return 'ZAR';
      case Currency.xaf:
        return 'XAF';
      case Currency.kes:
        return 'KES';
      case Currency.egp:
        return 'EGP';
      case Currency.tzs:
        return 'TZS';
      case Currency.etb:
        return 'ETB';
      // Asian currencies
      case Currency.cny:
        return 'CNY';
      case Currency.jpy:
        return 'JPY';
      case Currency.inr:
        return 'INR';
      case Currency.krw:
        return 'KRW';
      case Currency.sgd:
        return 'SGD';
      case Currency.hkd:
        return 'HKD';
      case Currency.thb:
        return 'THB';
      case Currency.myr:
        return 'MYR';
      case Currency.php:
        return 'PHP';
      case Currency.idr:
        return 'IDR';
      case Currency.vnd:
        return 'VND';
      case Currency.pkr:
        return 'PKR';
      // European currencies
      case Currency.sek:
        return 'SEK';
      case Currency.nok:
        return 'NOK';
      case Currency.dkk:
        return 'DKK';
      case Currency.pln:
        return 'PLN';
      case Currency.czk:
        return 'CZK';
      case Currency.try_:
        return 'TRY';
      case Currency.rub:
        return 'RUB';
      // Americas
      case Currency.mxn:
        return 'MXN';
      case Currency.ars:
        return 'ARS';
      case Currency.clp:
        return 'CLP';
      case Currency.cop:
        return 'COP';
      // Other international
      case Currency.aud:
        return 'AUD';
      case Currency.nzd:
        return 'NZD';
      case Currency.brl:
        return 'BRL';
      case Currency.aed:
        return 'AED';
      case Currency.sar:
        return 'SAR';
      case Currency.qar:
        return 'QAR';
      case Currency.kwd:
        return 'KWD';
    }
  }

  String get symbol {
    switch (this) {
      // Major currencies
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
      // African currencies
      case Currency.ngn:
        return '\u20A6';
      case Currency.ghs:
        return 'GH\u20B5';
      case Currency.mad:
        return 'DH';
      case Currency.zar:
        return 'R';
      case Currency.xaf:
        return 'FCFA';
      case Currency.kes:
        return 'KSh';
      case Currency.egp:
        return 'E\u00A3';
      case Currency.tzs:
        return 'TSh';
      case Currency.etb:
        return 'Br';
      // Asian currencies
      case Currency.cny:
        return '\u00A5';
      case Currency.jpy:
        return '\u00A5';
      case Currency.inr:
        return '\u20B9';
      case Currency.krw:
        return '\u20A9';
      case Currency.sgd:
        return 'S\$';
      case Currency.hkd:
        return 'HK\$';
      case Currency.thb:
        return '\u0E3F';
      case Currency.myr:
        return 'RM';
      case Currency.php:
        return '\u20B1';
      case Currency.idr:
        return 'Rp';
      case Currency.vnd:
        return '\u20AB';
      case Currency.pkr:
        return '\u20A8';
      // European currencies
      case Currency.sek:
        return 'kr';
      case Currency.nok:
        return 'kr';
      case Currency.dkk:
        return 'kr';
      case Currency.pln:
        return 'z\u0142';
      case Currency.czk:
        return 'K\u010D';
      case Currency.try_:
        return '\u20BA';
      case Currency.rub:
        return '\u20BD';
      // Americas
      case Currency.mxn:
        return 'MX\$';
      case Currency.ars:
        return 'AR\$';
      case Currency.clp:
        return 'CL\$';
      case Currency.cop:
        return 'CO\$';
      // Other international
      case Currency.aud:
        return 'A\$';
      case Currency.nzd:
        return 'NZ\$';
      case Currency.brl:
        return 'R\$';
      case Currency.aed:
        return 'AED';
      case Currency.sar:
        return 'SAR';
      case Currency.qar:
        return 'QAR';
      case Currency.kwd:
        return 'KD';
    }
  }

  String get name {
    switch (this) {
      // Major currencies
      case Currency.xof:
        return 'Franc CFA (BCEAO)';
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
      // African currencies
      case Currency.ngn:
        return 'Naira';
      case Currency.ghs:
        return 'Cedi';
      case Currency.mad:
        return 'Dirham Marocain';
      case Currency.zar:
        return 'Rand';
      case Currency.xaf:
        return 'Franc CFA (BEAC)';
      case Currency.kes:
        return 'Shilling Kenyan';
      case Currency.egp:
        return 'Livre Egyptienne';
      case Currency.tzs:
        return 'Shilling Tanzanien';
      case Currency.etb:
        return 'Birr Ethiopien';
      // Asian currencies
      case Currency.cny:
        return 'Yuan';
      case Currency.jpy:
        return 'Yen';
      case Currency.inr:
        return 'Roupie Indienne';
      case Currency.krw:
        return 'Won';
      case Currency.sgd:
        return 'Dollar Singapourien';
      case Currency.hkd:
        return 'Dollar Hong Kong';
      case Currency.thb:
        return 'Baht';
      case Currency.myr:
        return 'Ringgit';
      case Currency.php:
        return 'Peso Philippin';
      case Currency.idr:
        return 'Roupie Indonesienne';
      case Currency.vnd:
        return 'Dong';
      case Currency.pkr:
        return 'Roupie Pakistanaise';
      // European currencies
      case Currency.sek:
        return 'Couronne Suedoise';
      case Currency.nok:
        return 'Couronne Norvegienne';
      case Currency.dkk:
        return 'Couronne Danoise';
      case Currency.pln:
        return 'Zloty';
      case Currency.czk:
        return 'Couronne Tcheque';
      case Currency.try_:
        return 'Livre Turque';
      case Currency.rub:
        return 'Rouble';
      // Americas
      case Currency.mxn:
        return 'Peso Mexicain';
      case Currency.ars:
        return 'Peso Argentin';
      case Currency.clp:
        return 'Peso Chilien';
      case Currency.cop:
        return 'Peso Colombien';
      // Other international
      case Currency.aud:
        return 'Dollar Australien';
      case Currency.nzd:
        return 'Dollar Neo-Zelandais';
      case Currency.brl:
        return 'Real';
      case Currency.aed:
        return 'Dirham EAU';
      case Currency.sar:
        return 'Riyal Saoudien';
      case Currency.qar:
        return 'Riyal Qatari';
      case Currency.kwd:
        return 'Dinar Koweitien';
    }
  }

  String get flag {
    switch (this) {
      // Major currencies
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
      // African currencies
      case Currency.ngn:
        return '\u{1F1F3}\u{1F1EC}'; // Nigeria flag
      case Currency.ghs:
        return '\u{1F1EC}\u{1F1ED}'; // Ghana flag
      case Currency.mad:
        return '\u{1F1F2}\u{1F1E6}'; // Morocco flag
      case Currency.zar:
        return '\u{1F1FF}\u{1F1E6}'; // South Africa flag
      case Currency.xaf:
        return '\u{1F1E8}\u{1F1F2}'; // Cameroon flag (BEAC)
      case Currency.kes:
        return '\u{1F1F0}\u{1F1EA}'; // Kenya flag
      case Currency.egp:
        return '\u{1F1EA}\u{1F1EC}'; // Egypt flag
      case Currency.tzs:
        return '\u{1F1F9}\u{1F1FF}'; // Tanzania flag
      case Currency.etb:
        return '\u{1F1EA}\u{1F1F9}'; // Ethiopia flag
      // Asian currencies
      case Currency.cny:
        return '\u{1F1E8}\u{1F1F3}'; // China flag
      case Currency.jpy:
        return '\u{1F1EF}\u{1F1F5}'; // Japan flag
      case Currency.inr:
        return '\u{1F1EE}\u{1F1F3}'; // India flag
      case Currency.krw:
        return '\u{1F1F0}\u{1F1F7}'; // South Korea flag
      case Currency.sgd:
        return '\u{1F1F8}\u{1F1EC}'; // Singapore flag
      case Currency.hkd:
        return '\u{1F1ED}\u{1F1F0}'; // Hong Kong flag
      case Currency.thb:
        return '\u{1F1F9}\u{1F1ED}'; // Thailand flag
      case Currency.myr:
        return '\u{1F1F2}\u{1F1FE}'; // Malaysia flag
      case Currency.php:
        return '\u{1F1F5}\u{1F1ED}'; // Philippines flag
      case Currency.idr:
        return '\u{1F1EE}\u{1F1E9}'; // Indonesia flag
      case Currency.vnd:
        return '\u{1F1FB}\u{1F1F3}'; // Vietnam flag
      case Currency.pkr:
        return '\u{1F1F5}\u{1F1F0}'; // Pakistan flag
      // European currencies
      case Currency.sek:
        return '\u{1F1F8}\u{1F1EA}'; // Sweden flag
      case Currency.nok:
        return '\u{1F1F3}\u{1F1F4}'; // Norway flag
      case Currency.dkk:
        return '\u{1F1E9}\u{1F1F0}'; // Denmark flag
      case Currency.pln:
        return '\u{1F1F5}\u{1F1F1}'; // Poland flag
      case Currency.czk:
        return '\u{1F1E8}\u{1F1FF}'; // Czech Republic flag
      case Currency.try_:
        return '\u{1F1F9}\u{1F1F7}'; // Turkey flag
      case Currency.rub:
        return '\u{1F1F7}\u{1F1FA}'; // Russia flag
      // Americas
      case Currency.mxn:
        return '\u{1F1F2}\u{1F1FD}'; // Mexico flag
      case Currency.ars:
        return '\u{1F1E6}\u{1F1F7}'; // Argentina flag
      case Currency.clp:
        return '\u{1F1E8}\u{1F1F1}'; // Chile flag
      case Currency.cop:
        return '\u{1F1E8}\u{1F1F4}'; // Colombia flag
      // Other international
      case Currency.aud:
        return '\u{1F1E6}\u{1F1FA}'; // Australia flag
      case Currency.nzd:
        return '\u{1F1F3}\u{1F1FF}'; // New Zealand flag
      case Currency.brl:
        return '\u{1F1E7}\u{1F1F7}'; // Brazil flag
      case Currency.aed:
        return '\u{1F1E6}\u{1F1EA}'; // UAE flag
      case Currency.sar:
        return '\u{1F1F8}\u{1F1E6}'; // Saudi Arabia flag
      case Currency.qar:
        return '\u{1F1F6}\u{1F1E6}'; // Qatar flag
      case Currency.kwd:
        return '\u{1F1F0}\u{1F1FC}'; // Kuwait flag
    }
  }

  /// Number of decimal places for this currency
  int get decimals {
    switch (this) {
      // Currencies with no decimals
      case Currency.xof:
      case Currency.xaf:
      case Currency.jpy:
      case Currency.krw:
      case Currency.vnd:
      case Currency.idr:
      case Currency.clp:
      case Currency.cop:
        return 0;
      // Kuwaiti Dinar uses 3 decimals
      case Currency.kwd:
        return 3;
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
    'timestamp': timestamp.toUtc().toIso8601String(),
  };

  factory ExchangeRate.fromJson(Map<String, dynamic> json) => ExchangeRate(
    from: CurrencyExtension.fromCode(json['from'] as String),
    to: CurrencyExtension.fromCode(json['to'] as String),
    rate: (json['rate'] as num).toDouble(),
    timestamp: DateTime.parse(json['timestamp'] as String).toLocal(),
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

  // API configuration
  String? _apiKey;
  int _refreshIntervalMinutes = 60;
  Timer? _refreshTimer;
  bool _isInitialized = false;

  // Default fallback rates (XOF-based) - Used when API is unavailable
  // EUR/XOF is fixed at 655.957 (CFA zone peg)
  // These can be overridden by admin settings via setFallbackRates()
  // Note: Most rates are fetched from API, these are just fallbacks
  Map<String, double> _fallbackRates = {
    // Major currencies to XOF
    'EUR_XOF': 655.957, // Fixed rate (CFA peg)
    'USD_XOF': 615.0,
    'GBP_XOF': 780.0,
    'CAD_XOF': 455.0,
    'CHF_XOF': 690.0,
    // African currencies to XOF
    'NGN_XOF': 0.40,
    'GHS_XOF': 50.0,
    'MAD_XOF': 62.0,
    'ZAR_XOF': 34.0,
    'XAF_XOF': 1.0, // 1:1 parity between BCEAO and BEAC CFA
    'KES_XOF': 4.8,
    'EGP_XOF': 12.5,
    'TZS_XOF': 0.24,
    'ETB_XOF': 11.0,
    // Asian currencies to XOF
    'CNY_XOF': 85.0,
    'JPY_XOF': 4.1,
    'INR_XOF': 7.4,
    'KRW_XOF': 0.46,
    'SGD_XOF': 460.0,
    'HKD_XOF': 79.0,
    'THB_XOF': 17.5,
    'MYR_XOF': 138.0,
    'PHP_XOF': 11.0,
    'IDR_XOF': 0.039,
    'VND_XOF': 0.025,
    'PKR_XOF': 2.2,
    // European currencies to XOF
    'SEK_XOF': 59.0,
    'NOK_XOF': 58.0,
    'DKK_XOF': 88.0,
    'PLN_XOF': 155.0,
    'CZK_XOF': 27.0,
    'TRY_XOF': 18.5,
    'RUB_XOF': 6.8,
    // Americas currencies to XOF
    'MXN_XOF': 36.0,
    'ARS_XOF': 0.72,
    'CLP_XOF': 0.68,
    'COP_XOF': 0.15,
    // Other currencies to XOF
    'AUD_XOF': 400.0,
    'NZD_XOF': 370.0,
    'BRL_XOF': 125.0,
    'AED_XOF': 167.0,
    'SAR_XOF': 164.0,
    'QAR_XOF': 169.0,
    'KWD_XOF': 2000.0,
    // XOF to major currencies (inverse rates)
    'XOF_EUR': 0.001524,
    'XOF_USD': 0.001626,
    'XOF_GBP': 0.001282,
    'XOF_CAD': 0.002198,
    'XOF_CHF': 0.001449,
    // XOF to African currencies
    'XOF_NGN': 2.5,
    'XOF_GHS': 0.02,
    'XOF_MAD': 0.016,
    'XOF_ZAR': 0.029,
    'XOF_XAF': 1.0,
    'XOF_KES': 0.208,
    'XOF_EGP': 0.08,
    'XOF_TZS': 4.17,
    'XOF_ETB': 0.091,
    // XOF to Asian currencies
    'XOF_CNY': 0.012,
    'XOF_JPY': 0.244,
    'XOF_INR': 0.135,
    'XOF_KRW': 2.17,
    'XOF_SGD': 0.00217,
    'XOF_HKD': 0.0127,
    'XOF_THB': 0.057,
    'XOF_MYR': 0.00725,
    'XOF_PHP': 0.091,
    'XOF_IDR': 25.6,
    'XOF_VND': 40.0,
    'XOF_PKR': 0.455,
    // XOF to European currencies
    'XOF_SEK': 0.017,
    'XOF_NOK': 0.017,
    'XOF_DKK': 0.0114,
    'XOF_PLN': 0.00645,
    'XOF_CZK': 0.037,
    'XOF_TRY': 0.054,
    'XOF_RUB': 0.147,
    // XOF to Americas currencies
    'XOF_MXN': 0.028,
    'XOF_ARS': 1.39,
    'XOF_CLP': 1.47,
    'XOF_COP': 6.67,
    // XOF to other currencies
    'XOF_AUD': 0.0025,
    'XOF_NZD': 0.0027,
    'XOF_BRL': 0.008,
    'XOF_AED': 0.006,
    'XOF_SAR': 0.0061,
    'XOF_QAR': 0.0059,
    'XOF_KWD': 0.0005,
  };

  /// Set the API key from Firestore admin settings
  /// If a valid key is provided, triggers an immediate rate fetch
  void setApiKey(String? apiKey) {
    final oldKey = _apiKey;
    _apiKey = apiKey;

    // If we got a new valid key, fetch rates immediately
    if (apiKey != null &&
        apiKey.isNotEmpty &&
        apiKey != 'YOUR_API_KEY' &&
        apiKey != oldKey) {
      debugPrint('CurrencyService: API key configured, fetching rates...');
      fetchRates();
    }
  }

  /// Set the refresh interval and restart the timer
  void setRefreshInterval(int minutes) {
    if (minutes < 1) minutes = 1; // Minimum 1 minute
    if (minutes > 1440) minutes = 1440; // Maximum 24 hours

    if (_refreshIntervalMinutes != minutes) {
      _refreshIntervalMinutes = minutes;
      _startPeriodicRefresh();
    }
  }

  /// Start or restart the periodic refresh timer
  void _startPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      Duration(minutes: _refreshIntervalMinutes),
      (_) => fetchRates(),
    );
    debugPrint('CurrencyService: Periodic refresh set to $_refreshIntervalMinutes minutes');
  }

  /// Stop the periodic refresh timer
  void dispose() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  /// Update fallback rates from admin settings
  /// This allows the admin to configure rates that are used when the API is unavailable
  void setFallbackRates({
    required double eurToXof,
    required double usdToXof,
    required double gbpToXof,
    required double cadToXof,
    required double chfToXof,
  }) {
    _fallbackRates = {
      'EUR_XOF': eurToXof,
      'USD_XOF': usdToXof,
      'GBP_XOF': gbpToXof,
      'CAD_XOF': cadToXof,
      'CHF_XOF': chfToXof,
      'XOF_EUR': 1 / eurToXof,
      'XOF_USD': 1 / usdToXof,
      'XOF_GBP': 1 / gbpToXof,
      'XOF_CAD': 1 / cadToXof,
      'XOF_CHF': 1 / chfToXof,
    };
  }

  Map<String, ExchangeRate> _cachedRates = {};
  DateTime? _lastFetch;

  /// Initialize the service and load cached rates
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    await _loadCachedRates();

    // Start periodic refresh timer
    _startPeriodicRefresh();

    // Fetch fresh rates in background if we have an API key
    fetchRates();
  }

  /// Fetch latest exchange rates from API
  Future<void> fetchRates() async {
    try {
      // Using exchangerate-api.com (free tier: 1500 requests/month)
      const baseUrl = 'https://v6.exchangerate-api.com/v6';

      // Check if API key is configured
      if (_apiKey == null || _apiKey!.isEmpty || _apiKey == 'YOUR_API_KEY') {
        debugPrint(
          'CurrencyService: Using fallback rates (no API key configured)',
        );
        _useLocalRates();
        return;
      }

      final response = await http.get(Uri.parse('$baseUrl/$_apiKey/latest/EUR'));

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

  /// Facteur entre unité mineure et unité d'affichage pour cette devise.
  ///
  /// 100 pour l'euro (centimes), **1 pour le FCFA** : XOF et XAF n'ont pas de
  /// subdivision. Les montants de monétisation sont stockés en unité mineure,
  /// comme le veut Stripe, et le code divisait partout par 100 en dur — un
  /// pourboire de 500 FCFA s'affichait donc « 5 FCFA ».
  static int minorUnitFactor(Currency currency) {
    var factor = 1;
    for (var i = 0; i < currency.decimals; i++) {
      factor *= 10;
    }
    return factor;
  }

  /// Unité mineure (stockage, Stripe) → unité d'affichage.
  static double toMajor(int minorAmount, Currency currency) =>
      minorAmount / minorUnitFactor(currency);

  /// Unité d'affichage → unité mineure (stockage, Stripe).
  static int toMinor(double majorAmount, Currency currency) =>
      (majorAmount * minorUnitFactor(currency)).round();

  /// Formate un montant donné en unité mineure.
  String formatMinor(int minorAmount, Currency currency,
          {bool showSymbol = true}) =>
      format(toMajor(minorAmount, currency), currency, showSymbol: showSymbol);

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
      // CFA francs symbol comes after the amount
      if (currency == Currency.xof || currency == Currency.xaf) {
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
      // XOF - BCEAO zone
      case 'NE': // Niger
      case 'BJ': // Benin
      case 'BF': // Burkina Faso
      case 'CI': // Cote d'Ivoire
      case 'GW': // Guinea-Bissau
      case 'ML': // Mali
      case 'SN': // Senegal
      case 'TG': // Togo
        return Currency.xof;
      // XAF - BEAC zone
      case 'CM': // Cameroon
      case 'CF': // Central African Republic
      case 'TD': // Chad
      case 'CG': // Congo
      case 'GQ': // Equatorial Guinea
      case 'GA': // Gabon
        return Currency.xaf;
      // Euro zone
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
      case 'GR': // Greece
      case 'LU': // Luxembourg
      case 'MT': // Malta
      case 'CY': // Cyprus
      case 'SK': // Slovakia
      case 'SI': // Slovenia
      case 'EE': // Estonia
      case 'LV': // Latvia
      case 'LT': // Lithuania
        return Currency.eur;
      // Major currencies
      case 'US':
        return Currency.usd;
      case 'GB':
        return Currency.gbp;
      case 'CA':
        return Currency.cad;
      case 'CH':
        return Currency.chf;
      // African currencies
      case 'NG':
        return Currency.ngn;
      case 'GH':
        return Currency.ghs;
      case 'MA':
        return Currency.mad;
      case 'ZA':
        return Currency.zar;
      case 'KE':
        return Currency.kes;
      case 'EG':
        return Currency.egp;
      case 'TZ':
        return Currency.tzs;
      case 'ET':
        return Currency.etb;
      // Asian currencies
      case 'CN':
        return Currency.cny;
      case 'JP':
        return Currency.jpy;
      case 'IN':
        return Currency.inr;
      case 'KR':
        return Currency.krw;
      case 'SG':
        return Currency.sgd;
      case 'HK':
        return Currency.hkd;
      case 'TH':
        return Currency.thb;
      case 'MY':
        return Currency.myr;
      case 'PH':
        return Currency.php;
      case 'ID':
        return Currency.idr;
      case 'VN':
        return Currency.vnd;
      case 'PK':
        return Currency.pkr;
      // European currencies (non-Euro)
      case 'SE':
        return Currency.sek;
      case 'NO':
        return Currency.nok;
      case 'DK':
        return Currency.dkk;
      case 'PL':
        return Currency.pln;
      case 'CZ':
        return Currency.czk;
      case 'TR':
        return Currency.try_;
      case 'RU':
        return Currency.rub;
      // Americas
      case 'MX':
        return Currency.mxn;
      case 'AR':
        return Currency.ars;
      case 'CL':
        return Currency.clp;
      case 'CO':
        return Currency.cop;
      case 'BR':
        return Currency.brl;
      // Oceania
      case 'AU':
        return Currency.aud;
      case 'NZ':
        return Currency.nzd;
      // Middle East
      case 'AE':
        return Currency.aed;
      case 'SA':
        return Currency.sar;
      case 'QA':
        return Currency.qar;
      case 'KW':
        return Currency.kwd;
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
        _lastFetch = DateTime.parse(lastFetchStr).toLocal();
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
        await prefs.setString(_lastFetchKey, _lastFetch!.toUtc().toIso8601String());
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
