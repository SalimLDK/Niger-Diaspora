import 'package:diaspo_niger/core/theme/admin_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/admin_dashboard_screen.dart';
import 'screens/admin_login_screen.dart';

class AdminApp extends ConsumerWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'DiaspoNiger Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          // Back-office : bleu d'action (l'orange est réservé au grand public).
          seedColor: AdminColors.actionBlue,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: AdminColors.bg,
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(),
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const AdminLoginScreen(),
        '/dashboard': (context) => const AdminDashboardScreen(),
      },
    );
  }
}
