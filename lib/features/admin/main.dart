import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import '../../firebase_options.dart';
import 'presentation/admin_app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Remove # from URL on web
  usePathUrlStrategy();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Activate Firebase App Check with reCAPTCHA v3 for web
  await FirebaseAppCheck.instance.activate(
    webProvider: ReCaptchaV3Provider(
      '6Ldy7TwsAAAAAI6jQWNmV-I2lkEn31yGG8iRNxTi',
    ),
  );

  runApp(const ProviderScope(child: AdminApp()));
}
