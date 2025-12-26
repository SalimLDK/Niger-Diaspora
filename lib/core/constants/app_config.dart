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
  /// Test publishable key for development.
  /// Get it from: https://dashboard.stripe.com/test/apikeys
  static const String _testPublishableKey =
      'pk_test_51SiMSAPg6wD0IqJlzZp3k6cvuopQV1miWhawS72kvR9vVYbZqojcPrx8ZkviF5xhGiGglYJaupOQKcT9puYpEU4500y6jREukt';

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

  /// Get configuration info for debugging
  static Map<String, dynamic> get configInfo => {
    'environment': isProduction ? 'production' : 'development',
    'stripeConfigured': isStripeConfigured,
    'stripeKeyType':
        stripePublishableKey.startsWith('pk_test_')
            ? 'test'
            : stripePublishableKey.startsWith('pk_live_')
            ? 'live'
            : 'invalid',
  };
}
