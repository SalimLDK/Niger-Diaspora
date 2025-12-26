import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_config.dart';

/// Service for managing Stripe payment operations.
///
/// This service handles:
/// - Stripe SDK initialization
/// - Payment intent creation via Cloud Functions
/// - Payment sheet presentation
/// - Payment flow management
class StripeService {
  static StripeService? _instance;
  static StripeService get instance {
    _instance ??= StripeService._();
    return _instance!;
  }

  StripeService._();

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  bool _isInitialized = false;

  /// Initialize Stripe SDK with publishable key.
  ///
  /// This must be called before any Stripe operations.
  /// Typically called during app startup in main.dart.
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('Stripe already initialized');
      return;
    }

    try {
      // Validate configuration
      if (!AppConfig.isStripeConfigured) {
        debugPrint(
          '⚠️ Stripe not configured properly. '
          'Please set your Stripe publishable key in app_config.dart',
        );
        return;
      }

      // Set publishable key
      Stripe.publishableKey = AppConfig.stripePublishableKey;

      // Set merchant identifier for Apple Pay
      Stripe.merchantIdentifier = AppConfig.stripeMerchantIdentifier;

      // Apply Stripe settings
      await Stripe.instance.applySettings();

      _isInitialized = true;

      debugPrint(
        '✅ Stripe initialized successfully '
        '(${AppConfig.isProduction ? 'PRODUCTION' : 'TEST'} mode)',
      );
    } catch (e) {
      debugPrint('❌ Error initializing Stripe: $e');
      rethrow;
    }
  }

  /// Create a payment intent via Cloud Function and present payment sheet.
  ///
  /// Returns the payment intent ID if successful, null otherwise.
  Future<String?> processPayment({
    required double amount,
    required String currency,
    required String userId,
    required String transactionId,
    Map<String, dynamic>? metadata,
  }) async {
    if (!_isInitialized) {
      throw StateError('Stripe not initialized. Call initialize() first.');
    }

    try {
      debugPrint('Creating payment intent for transaction: $transactionId');

      // 1. Create payment intent via Cloud Function
      final paymentData = await _createPaymentIntent(
        amount: amount,
        currency: currency,
        userId: userId,
        transactionId: transactionId,
        metadata: metadata,
      );

      if (paymentData == null) {
        debugPrint('Failed to create payment intent');
        return null;
      }

      final clientSecret = paymentData['clientSecret'] as String;
      final paymentIntentId = paymentData['paymentIntentId'] as String;

      debugPrint('Payment intent created: $paymentIntentId');

      // 2. Initialize payment sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'Diaspo Niger',
          style: ThemeMode.system,
          billingDetailsCollectionConfiguration:
              const BillingDetailsCollectionConfiguration(
                name: CollectionMode.always,
                email: CollectionMode.always,
              ),
        ),
      );

      debugPrint('Payment sheet initialized');

      // 3. Present payment sheet
      await Stripe.instance.presentPaymentSheet();

      debugPrint('✅ Payment completed successfully');
      return paymentIntentId;
    } on StripeException catch (e) {
      debugPrint('❌ Stripe error: ${e.error.localizedMessage}');

      // User cancelled the payment
      if (e.error.code == FailureCode.Canceled) {
        debugPrint('Payment cancelled by user');
        return null;
      }

      rethrow;
    } catch (e) {
      debugPrint('❌ Payment error: $e');
      rethrow;
    }
  }

  /// Create payment intent by calling Cloud Function.
  ///
  /// This communicates with Firebase Cloud Functions to create
  /// a payment intent on the backend (where the secret key is stored).
  Future<Map<String, dynamic>?> _createPaymentIntent({
    required double amount,
    required String currency,
    required String userId,
    required String transactionId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // Note: You'll need to create a Cloud Function endpoint
      // For now, we'll create a document that a Cloud Function can listen to

      final requestDoc = _firestore.collection('payment_intents').doc();

      await requestDoc.set({
        'amount': amount,
        'currency': currency.toLowerCase(),
        'userId': userId,
        'transactionId': transactionId,
        'metadata': metadata ?? {},
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Wait for Cloud Function to process and add clientSecret
      final snapshot = await requestDoc.snapshots().firstWhere((snapshot) {
        final data = snapshot.data();
        return data != null &&
            (data['status'] == 'created' || data['status'] == 'error');
      }, orElse: () => throw Exception('Payment intent creation timeout'));

      final data = snapshot.data();
      if (data == null || data['status'] == 'error') {
        throw Exception(data?['error'] ?? 'Failed to create payment intent');
      }

      return {
        'clientSecret': data['clientSecret'],
        'paymentIntentId': data['paymentIntentId'],
      };
    } catch (e) {
      debugPrint('Error creating payment intent: $e');
      rethrow;
    }
  }

  /// Check if a payment was successful
  Future<bool> checkPaymentStatus(String paymentIntentId) async {
    try {
      // Query the payment intent document
      final querySnapshot =
          await _firestore
              .collection('payment_intents')
              .where('paymentIntentId', isEqualTo: paymentIntentId)
              .limit(1)
              .get();

      if (querySnapshot.docs.isEmpty) {
        return false;
      }

      final data = querySnapshot.docs.first.data();
      return data['status'] == 'succeeded';
    } catch (e) {
      debugPrint('Error checking payment status: $e');
      return false;
    }
  }

  /// Validate Stripe configuration (for debugging)
  bool validateConfiguration() {
    return AppConfig.isStripeConfigured && _isInitialized;
  }
}
