import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'firebase_options.dart';
import 'app.dart';
import 'core/services/notification_service.dart';
import 'core/services/cache_service.dart';
import 'core/services/google_maps_service.dart';
import 'core/services/preferences_service.dart';
import 'core/services/stripe_service.dart';
import 'core/services/background_location_service.dart';
import 'core/services/online_status_service.dart';
import 'core/services/encryption_service.dart';

import 'package:timezone/data/latest_all.dart' as tz;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();

  // Initialize Firebase
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    // debugPrint('Firebase already initialized: $e');
  }

  // Initialize preferences service FIRST
  await PreferencesService.instance.initialize();

  // Initialize encryption service for message encryption/decryption
  await EncryptionService.instance.initialize();

  // Initialize Stripe for payments (skip on web as flutter_stripe is not web-compatible)
  if (!kIsWeb) {
    await StripeService.instance.initialize();
  }

  // Initialize Google Maps renderer FIRST (fixes visual glitches)
  await GoogleMapsService.instance.initialize();

  // Pass all uncaught "fatal" errors from the framework to Crashlytics
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;

  // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // Initialize Performance Monitoring
  await FirebasePerformance.instance.setPerformanceCollectionEnabled(true);

  // Activate Firebase App Check
  // Android: Debug mode uses DebugProvider, Release uses PlayIntegrity
  // iOS: Debug mode uses DebugProvider, Release uses AppAttest
  // Web: Uses ReCaptchaV3Provider
  await FirebaseAppCheck.instance.activate(
    // Web Provider - ReCAPTCHA v3
    webProvider: ReCaptchaV3Provider(
      '6Ldy7TwsAAAAAI6jQWNmV-I2lkEn31yGG8iRNxTi',
    ),
    // Android Provider
    androidProvider:
        kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
    // iOS/macOS Provider
    appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
  );

  // In debug mode on mobile platforms, get and print the debug token for easy registration
  if (!kIsWeb && kDebugMode) {
    try {
      final token = await FirebaseAppCheck.instance.getToken();
      if (token != null) {
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        debugPrint('🔐 FIREBASE APP CHECK DEBUG TOKEN');
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        debugPrint('Token: $token');
        debugPrint('');
        debugPrint('📋 Pour enregistrer ce token:');
        debugPrint('1. Firebase Console → App Check → Applications');
        debugPrint('2. Cliquez sur com.diasponiger.diasponiger');
        debugPrint('3. Onglet "Debug tokens"');
        debugPrint('4. Cliquez "Add debug token"');
        debugPrint('5. Collez le token ci-dessus');
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      }
    } catch (e) {
      debugPrint('⚠️ Erreur lors de la récupération du debug token: $e');
    }
  }

  // Set up background message handler (skip on web)
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Initialize notification service
    await NotificationService().initialize();

    // Initialize Background Location Service
    await BackgroundLocationService().initialize();
  }

  // Initialize Online Status Service
  await OnlineStatusService.instance.initialize();

  // Initialize Hive for local storage
  await Hive.initFlutter();

  // Initialize cache service for offline mode
  await CacheService.instance.initialize();

  runApp(const ProviderScope(child: NigerDiasporaApp()));
}
