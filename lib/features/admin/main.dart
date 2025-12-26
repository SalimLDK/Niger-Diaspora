import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_strategy/url_strategy.dart';

import '../../firebase_options.dart';
import 'presentation/admin_app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Remove # from URL on web
  setPathUrlStrategy();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const ProviderScope(child: AdminApp()));
}
