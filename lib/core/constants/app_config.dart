import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../services/remote_config_service.dart';

/// Application configuration for API keys and environment settings.
///
/// This file centralizes all configuration constants including Stripe keys,
/// environment detection, and other API configurations.
class AppConfig {
  // Prevent instantiation
  AppConfig._();

  // ============================================
  // ENVIRONMENT CONFIGURATION
  // ============================================

  /// Whether the app is running in production mode.
  /// Set via --dart-define=PRODUCTION=true during build
  static const bool isProduction = bool.fromEnvironment(
    'PRODUCTION',
    defaultValue: false,
  );

  /// Whether the app is in debug mode
  static const bool isDebug = !isProduction;

  // ============================================
  // HELPER: read --dart-define first, then .env
  // ============================================

  /// Ordre : `--dart-define` (fige au build) > configuration distante
  /// (`app-config`, modifiable sans republier) > `.env` embarque > repli.
  ///
  /// Le `.env` reste le filet : [RemoteConfigService.value] rend null tant que
  /// la configuration distante n'est pas chargee -- au premier lancement, hors
  /// ligne, ou si la fonction n'est pas deployee, l'app demarre comme avant.
  /// C'est aussi ce qui rend l'ordre de demarrage sur : `SUPABASE_URL` et
  /// `SUPABASE_ANON_KEY` sont lus avant l'appel distant et viennent forcement
  /// du `.env` -- ils ouvrent la connexion qui sert a joindre `app-config`.
  static String _read(String dartDefineKey, {String fallback = ''}) {
    final fromDartDefine = String.fromEnvironment(dartDefineKey);
    if (fromDartDefine.isNotEmpty) {
      return fromDartDefine;
    }
    final fromRemote = RemoteConfigService.instance.value(dartDefineKey);
    if (fromRemote != null) {
      return fromRemote;
    }
    try {
      final fromDotEnv = dotenv.env[dartDefineKey];
      if (fromDotEnv != null && fromDotEnv.isNotEmpty) {
        return fromDotEnv;
      }
    } catch (_) {
      // dotenv may not be loaded yet in some contexts
    }
    return fallback;
  }

  // ============================================
  // SUPABASE CONFIGURATION
  // ============================================

  static String get supabaseUrl => _read('SUPABASE_URL');

  static String get supabaseAnonKey => _read('SUPABASE_ANON_KEY');

  static bool get isSupabaseConfigured {
    return supabaseUrl.isNotEmpty &&
        supabaseAnonKey.isNotEmpty &&
        supabaseUrl.startsWith('https://');
  }

  // ============================================
  // STRIPE CONFIGURATION
  // ============================================

  /// Stripe publishable key from build arguments.
  /// This key is safe to expose in the Flutter app.
  /// Set via --dart-define=STRIPE_PUBLISHABLE_KEY=pk_xxx
  static const String _publishableKeyFromEnv = String.fromEnvironment(
    'STRIPE_PUBLISHABLE_KEY',
    defaultValue: '',
  );

  /// Test publishable key for development.
  /// In development: Set via --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_xxx
  /// Get your key from: https://dashboard.stripe.com/test/apikeys
  /// WARNING: Never commit real API keys to version control
  static const String _testPublishableKey = 'pk_test_51SiMSAPg6wD0IqJlzZp3k6cvuopQV1miWhawS72kvR9vVYbZqojcPrx8ZkviF5xhGiGglYJaupOQKcT9puYpEU4500y6jREukt';

  /// Merchant identifier for Apple Pay
  static const String stripeMerchantIdentifier = 'merchant.com.diasponiger';

  /// Get the active Stripe publishable key based on environment.
  ///
  /// - In production: Uses key from build arguments
  /// - In development: Uses hardcoded test key
  static String get stripePublishableKey {
    if (isProduction && _publishableKeyFromEnv.isNotEmpty) {
      return _publishableKeyFromEnv;
    }
    return _testPublishableKey;
  }

  /// Validate that Stripe is properly configured
  static bool get isStripeConfigured {
    final key = stripePublishableKey;
    return key.isNotEmpty &&
        key != 'pk_test_REPLACE_WITH_YOUR_TEST_KEY' &&
        (key.startsWith('pk_test_') || key.startsWith('pk_live_'));
  }

  // ============================================
  // REVENUECAT CONFIGURATION
  // ============================================

  /// RevenueCat API key for Android from build arguments.
  /// Set via --dart-define=REVENUECAT_API_KEY_ANDROID=xxx
  static const String _revenueCatApiKeyAndroidFromEnv = String.fromEnvironment(
    'REVENUECAT_API_KEY_ANDROID',
    defaultValue: '',
  );

  /// RevenueCat API key for iOS from build arguments.
  /// Set via --dart-define=REVENUECAT_API_KEY_IOS=xxx
  static const String _revenueCatApiKeyIosFromEnv = String.fromEnvironment(
    'REVENUECAT_API_KEY_IOS',
    defaultValue: '',
  );

  /// Get the active RevenueCat API key for Android.
  static String get revenueCatApiKeyAndroid => _revenueCatApiKeyAndroidFromEnv;

  /// Get the active RevenueCat API key for iOS.
  static String get revenueCatApiKeyIos => _revenueCatApiKeyIosFromEnv;

  /// Validate that RevenueCat is properly configured.
  static bool get isRevenueCatConfigured {
    return revenueCatApiKeyAndroid.isNotEmpty || revenueCatApiKeyIos.isNotEmpty;
  }

  // ============================================
  // GOOGLE SIGN-IN CONFIGURATION
  // ============================================

  /// OAuth 2.0 Web Client ID (client_type 3) from google-services.json.
  /// Required as [GoogleSignIn.serverClientId] so Android returns an idToken
  /// usable by Firebase Auth.
  /// Override via --dart-define=GOOGLE_WEB_CLIENT_ID=xxx.apps.googleusercontent.com
  static const String _googleWebClientIdFromEnv = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '',
  );

  static const String _defaultGoogleWebClientId =
      '539228418594-7br2d2ribbog8sdutpeiteoe89l21gjv.apps.googleusercontent.com';

  static String get googleWebClientId =>
      _googleWebClientIdFromEnv.isNotEmpty
          ? _googleWebClientIdFromEnv
          : _defaultGoogleWebClientId;

  // ============================================
  // SERVICES PILOTABLES A DISTANCE
  // ============================================
  //
  // Ces trois valeurs lisaient `dotenv.env[...]` en direct, ce qui court-circuitait
  // `--dart-define` comme la configuration distante. Elles passent desormais par
  // [_read], donc par la meme cascade que tout le reste.

  static String get deepLinkBaseUrl =>
      _read('DEEP_LINK_BASE_URL', fallback: 'https://diasponiger.web.app');

  static String get livekitServerUrl =>
      _read('LIVEKIT_SERVER_URL', fallback: 'wss://livekit.diasponiger.com');

  static String get googleMapsApiKey => _read('GOOGLE_MAPS_API_KEY');

  // ============================================
  // GIFS (GIPHY / TENOR)
  // ============================================
  //
  // Aucune clé ici, volontairement. `GIPHY_API_KEY` et `TENOR_API_KEY` sont
  // détenues par l'Edge Function `gif-proxy` : le `.env` est déclaré comme
  // asset dans pubspec.yaml, donc tout ce qu'il contient part dans l'APK et
  // s'extrait avec un simple dézippage. Ces deux clés-là portent quota et
  // facturation, contrairement aux clés publiques (Firebase, Maps, reCAPTCHA)
  // qui restent ici faute de pouvoir en sortir.
  //
  // Voir lib/features/gifs/data/datasources/.

  /// Get configuration info for debugging
  static Map<String, dynamic> get configInfo => {
    'environment': isProduction ? 'production' : 'development',
    'supabaseConfigured': isSupabaseConfigured,
    'stripeConfigured': isStripeConfigured,
    'revenueCatConfigured': isRevenueCatConfigured,
    'stripeKeyType':
        stripePublishableKey.startsWith('pk_test_')
            ? 'test'
            : stripePublishableKey.startsWith('pk_live_')
            ? 'live'
            : 'invalid',
  };
}
