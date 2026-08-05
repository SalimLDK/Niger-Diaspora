import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'firebase_options.dart';
import 'app.dart';
import 'core/constants/app_config.dart';
import 'core/services/notification_service.dart';
import 'core/services/cache_service.dart';
import 'core/services/google_maps_service.dart';
import 'core/services/preferences_service.dart';
import 'core/services/stripe_service.dart';
import 'core/services/background_location_service.dart';
import 'core/services/location_publisher_service.dart';
import 'core/services/online_status_service.dart';
import 'core/services/encryption_service.dart';

import 'package:timezone/data/latest_all.dart' as tz;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();

  // Load .env file if present (development configuration)
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // .env may be absent in CI or production builds using --dart-define
  }

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

  // Initialize Supabase if configured
  if (AppConfig.isSupabaseConfigured) {
    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        publishableKey: AppConfig.supabaseAnonKey,
      );
    } catch (e) {
      debugPrint('Supabase initialization failed: $e');
    }
  } else {
    debugPrint(
      'Supabase not configured. Set SUPABASE_URL and SUPABASE_ANON_KEY via .env or --dart-define.',
    );
  }

  // Initialize preferences service FIRST
  await PreferencesService.instance.initialize();

  // Initialize encryption service for message encryption/decryption
  await EncryptionService.instance.initialize();

  // Pass all uncaught "fatal" errors from the framework to Crashlytics
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;

  // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

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

  // Set up background message handler (skip on web)
  //
  // Reste ici : c'est un enregistrement synchrone, et il doit être en place
  // avant qu'un message puisse arriver.
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  // Initialize Hive for local storage
  await Hive.initFlutter();

  // Initialize cache service for offline mode
  //
  // Reste bloquant : `FeedNotifier` lit le cache avant même d'interroger le
  // réseau (repli hors ligne), donc la boîte doit être ouverte.
  await CacheService.instance.initialize();

  runApp(const ProviderScope(child: NigerDiasporaApp()));

  // Tout ce qui suit n'est nécessaire à aucun premier rendu : le faire après
  // `runApp` rend la main au routeur ~3 s plus tôt sur un démarrage à froid.
  // Mesuré le 2026-08-04 sur SM A515F (build debug) : ~11 s entre l'intent et
  // la création de GoRouter, dont ~7,5 s AVANT la première ligne de `main()`
  // (process Android, SDK Firebase natifs, enregistrement des plugins).
  // Seule la dernière tranche était de notre ressort.
  unawaited(_initServicesSecondaires());
}

/// Services dont aucun écran de démarrage ne dépend.
///
/// Chacun est isolé : l'échec de l'un ne doit pas empêcher les autres. Le
/// précédent enchaînement d'`await` dans `main()` avait déjà causé ça une fois
/// — un échec du SDK Stripe natif interrompait tout le reste, App Check et
/// Crashlytics compris.
Future<void> _initServicesSecondaires() async {
  Future<void> tenter(String nom, Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      debugPrint('main: initialisation « $nom » échouée: $e');
    }
  }

  // En premier du lot : le rendu de la carte a besoin de ce réglage avant
  // qu'un écran carte s'affiche, ce qui demande au moins une navigation.
  await tenter('Google Maps', GoogleMapsService.instance.initialize);

  if (!kIsWeb) {
    // `processPayment()` réinitialise le SDK à la demande via
    // `validateConfiguration()` : le paiement ne dépend pas de cet appel.
    await tenter('Stripe', StripeService.instance.initialize);
    await tenter('notifications', NotificationService().initialize);
    await tenter(
      'localisation en arrière-plan',
      BackgroundLocationService().initialize,
    );
    // Publication de la position au premier plan, tous écrans confondus : sans
    // elle, un membre n'émettait sa position que depuis l'écran carte et
    // disparaissait de celle des autres au bout de cinq minutes.
    // (Ajouté par Jules avant `runApp` ; différé ici comme les autres — rien
    // au premier rendu n'en dépend, et quelques secondes de décalage sont sans
    // effet sur une fenêtre de cinq minutes.)
    await tenter(
      'publication de position',
      LocationPublisherService.instance.initialize,
    );
  }

  await tenter('statut en ligne', OnlineStatusService.instance.initialize);
  await tenter(
    'Performance Monitoring',
    () => FirebasePerformance.instance.setPerformanceCollectionEnabled(true),
  );

  // Jeton de debug App Check : appel réseau, et purement informatif.
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

}
