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
import 'core/utils/logs_release.dart';
import 'core/constants/app_config.dart';
import 'core/services/notification_service.dart';
import 'core/services/cache_service.dart';
import 'core/services/google_maps_service.dart';
import 'core/services/preferences_service.dart';
import 'core/services/remote_config_service.dart';
import 'core/services/stripe_service.dart';
import 'core/services/background_location_service.dart';
import 'core/services/location_publisher_service.dart';
import 'core/services/online_status_service.dart';
import 'core/services/crypto/derived_key_store.dart';
import 'core/services/encryption_service.dart';

import 'package:timezone/data/latest_all.dart' as tz;

/// Ce que voit l'usager quand un widget lève.
///
/// Par défaut Flutter peint son écran rouge en affichant le message brut de
/// l'exception. Hors ligne, ça donnait ceci à l'écran, en clair :
///
///     ServerFailure(ClientException with SocketException: Failed host
///     lookup: 'zyrfkcjjrhddpfxcgezo.supabase.co',
///     uri=.../rest/v1/users?select=%2A&id=eq.<UID>)
///
/// Soit l'identifiant du projet Supabase **et** celui du compte, livrés à qui
/// regarde l'écran. D'où ce rendu neutre — posé en debug aussi, pour que ce
/// chemin soit réellement exercé : la pile, elle, continue de sortir en
/// console via le `presentError` de `FlutterError.onError`, on ne perd rien.
///
/// Trois contraintes dictent la forme de ce widget. Il peut être rendu
/// **n'importe où** dans l'arbre, y compris sans `Directionality` ni `Theme`
/// au-dessus, et sous des contraintes minuscules — d'où le `Directionality`
/// explicite, les couleurs en dur choisies sur `platformBrightness` plutôt
/// que sur le thème, et le `FittedBox` qui évite un débordement quand le
/// widget ne remplace qu'une petite zone.
Widget construireEcranErreurNeutre(FlutterErrorDetails details) {
  // Lu sur le binding, pas sur `PlatformDispatcher.instance` : c'est le seul
  // des deux qu'un test puisse forcer (`platformBrightnessTestValue`). En
  // production les deux rendent la même chose.
  final sombre =
      WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark;
  final fond = sombre ? const Color(0xFF121212) : const Color(0xFFF7F7F7);
  final texte = sombre ? const Color(0xFFF5F5F5) : const Color(0xFF1A1A1A);
  final secondaire =
      sombre ? const Color(0xFFBDBDBD) : const Color(0xFF616161);

  return Directionality(
    textDirection: TextDirection.ltr,
    // Sans `DefaultTextStyle`, Flutter peint le texte avec son style de
    // secours : chasse fixe et double soulignement jaune. Vu tel quel sur
    // SM A515F le 2026-09-08 — les couleurs etaient bonnes, le rendu non.
    // Un `ErrorWidget` n'a par definition aucun `Material` au-dessus de lui,
    // donc rien ne fournit ce style : il faut le poser ici.
    child: DefaultTextStyle(
      style: TextStyle(
        color: texte,
        decoration: TextDecoration.none,
        fontFamily: null,
      ),
      child: ColoredBox(
      color: fond,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline_rounded, size: 36, color: secondaire),
                const SizedBox(height: 10),
                Text(
                  'Une erreur est survenue',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: texte,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Revenez en arrière puis réessayez.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: secondaire,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    ),
  );
}

/// Point d'entrée. Le démarrage réel est dans [_demarrer] pour qu'il tourne
/// entier dans la zone muette de release — voir `logs_release.dart`.
void main() => demarrerSansLogsEnRelease(_demarrer);

Future<void> _demarrer() async {
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

  // Configuration publique servie par l'Edge Function `app-config`, pour
  // pouvoir changer une cle sans republier d'APK. Placee ici : apres Supabase
  // (qui porte l'appel) et apres les preferences (qui portent le cache), mais
  // avant Maps / Stripe / LiveKit / liens profonds, qui la consomment.
  // N'echoue jamais et ne bloque jamais : hors ligne ou fonction absente,
  // AppConfig retombe sur le `.env` embarque.
  await RemoteConfigService.instance.initialize();

  // Initialize encryption service for message encryption/decryption
  await EncryptionService.instance.initialize();

  // Version de clé dérivée déjà connue, relue depuis le keystore — sans réseau.
  // Sans cette reprise, `versionCourante` serait nul au démarrage et TOUT
  // retomberait sur la clé globale jusqu'au premier aller-retour vers
  // `crypto-keys` : le branchement ne servirait à rien hors ligne, c'est-à-dire
  // précisément quand on en a besoin.
  await DerivedKeyStore.instance.reprendreDepuisLeCache();

  // Pass all uncaught "fatal" errors from the framework to Crashlytics
  //
  // En debug, on presente AUSSI l'erreur en console. Sans ce
  // `presentError`, l'affectation ci-dessous remplace le gestionnaire par
  // defaut de Flutter et AUCUNE pile d'exception ne sort jamais -- ni dans
  // `flutter run`, ni dans logcat. Un ecran rouge s'affiche alors sans
  // qu'on puisse savoir d'ou il vient.
  FlutterError.onError = (details) {
    if (kDebugMode) FlutterError.presentError(details);
    FirebaseCrashlytics.instance.recordFlutterError(details);
  };

  // Un widget qui lève ne doit jamais montrer son exception (voir la
  // docstring de la fonction).
  ErrorWidget.builder = construireEcranErreurNeutre;

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
