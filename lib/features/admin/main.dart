import 'package:diaspo_niger/core/constants/app_config.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../firebase_options.dart';
import 'presentation/admin_app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Remove # from URL on web
  usePathUrlStrategy();

  // Même source de configuration que `lib/main.dart` : `AppConfig` lit
  // `--dart-define`, puis le `.env` embarqué.
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // .env absent (CI, build avec --dart-define) : AppConfig retombe sur
    // les dart-define.
  }

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Activate Firebase App Check with reCAPTCHA v3 for web
  await FirebaseAppCheck.instance.activate(
    webProvider: ReCaptchaV3Provider(
      '6Ldy7TwsAAAAAI6jQWNmV-I2lkEn31yGG8iRNxTi',
    ),
  );

  // Supabase, avant runApp : les notifiers du panneau et le pont
  // d'authentification passent tous par `Supabase.instance.client`. Cette
  // entrée ne l'initialisait pas — le premier appel, dès la connexion (le
  // pont lit `admin_role`), levait une erreur d'instance non initialisée
  // (audit du 2026-10-14, § 1). Même configuration que `lib/main.dart` ;
  // sans elle, le panneau ne peut rien faire, donc on ne démarre pas.
  if (!AppConfig.isSupabaseConfigured) {
    throw StateError(
      'SUPABASE_URL / SUPABASE_ANON_KEY manquants (.env ou --dart-define) : '
      'le panneau ne peut pas démarrer sans Supabase.',
    );
  }
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
  );

  runApp(const ProviderScope(child: AdminApp()));
}
