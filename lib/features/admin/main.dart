import 'dart:async';

import 'package:diaspo_niger/core/constants/app_config.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:diaspo_niger/core/services/supabase_auth_bridge.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../firebase_options.dart';
import 'cle_site_recaptcha.dart';
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

  // Activate Firebase App Check with reCAPTCHA v3 for web.
  // La clé vient de `--dart-define=ADMIN_RECAPTCHA_SITE_KEY` (repli : la clé
  // du projet, voir cle_site_recaptcha.dart). Le domaine servi doit figurer
  // dans les domaines autorisés de cette clé (console reCAPTCHA), sinon App
  // Check échoue en silence : docs/deploiement/HEBERGEMENT_ADMIN.md.
  await FirebaseAppCheck.instance.activate(
    webProvider: ReCaptchaV3Provider(cleSiteRecaptchaAdmin),
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

  // Session Supabase : le panneau n'en avait JAMAIS à l'ouverture. Le pont
  // `SupabaseAuthBridge.syncWithFirebase` ne partait qu'au moment de se
  // connecter ; un rechargement de page (session Firebase restaurée) ou un
  // retour le lendemain partait donc sous `anon`, et chaque requête du
  // panneau rendait 401 / « permission denied for function » — liste des
  // utilisateurs vide, compteurs à zéro (vu en ligne le 2026-10-15, aucun appel
  // à `auth-firebase-exchange` au chargement). On échange le jeton de la
  // session restaurée AVANT le premier écran, puis à chaque changement de
  // compte ; le pont déduplique les appels simultanés.
  final auth = FirebaseAuth.instance;
  final restauree = await auth.authStateChanges().first;
  if (restauree != null) {
    try {
      await SupabaseAuthBridge.instance
          .syncWithFirebase(restauree)
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('Admin: session Supabase non rétablie au démarrage ($e)');
    }
  }
  auth.authStateChanges().listen((user) {
    if (user != null) {
      unawaited(SupabaseAuthBridge.instance.syncWithFirebase(user));
    }
  });

  runApp(const ProviderScope(child: AdminApp()));
}
