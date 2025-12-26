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
    debugPrint('Firebase already initialized: $e');
  }

  // Initialize preferences service FIRST
  await PreferencesService.instance.initialize();

  // Initialize Stripe for payments
  await StripeService.instance.initialize();

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
  // Debug mode: uses DebugProvider (requires adding token to console)
  // Release mode: uses PlayIntegrity (requires SHA-256 in console)
  await FirebaseAppCheck.instance.activate(
    androidProvider:
        kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
    appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
  );

  // Set up background message handler
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Initialize notification service
  await NotificationService().initialize();

  // Initialize Background Location Service
  await BackgroundLocationService().initialize();

  // Initialize Online Status Service
  await OnlineStatusService.instance.initialize();

  // Initialize Hive for local storage
  await Hive.initFlutter();

  // Initialize cache service for offline mode
  await CacheService.instance.initialize();

  runApp(const ProviderScope(child: NigerDiasporaApp()));
}
