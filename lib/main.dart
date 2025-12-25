import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'firebase_options.dart';
import 'app.dart';
import 'core/services/notification_service.dart';
import 'core/services/cache_service.dart';
import 'core/services/google_maps_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Google Maps renderer FIRST (fixes visual glitches)
  await GoogleMapsService.instance.initialize();

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

  // Initialize Hive for local storage
  await Hive.initFlutter();

  // Initialize cache service for offline mode
  await CacheService.instance.initialize();

  runApp(const ProviderScope(child: NigerDiasporaApp()));
}
