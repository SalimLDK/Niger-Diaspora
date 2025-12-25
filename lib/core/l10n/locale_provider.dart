import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'locale_provider.g.dart';

@riverpod
class LocaleNotifier extends _$LocaleNotifier {
  static const String _localeKey = 'app_locale';

  static const List<Locale> supportedLocales = [
    Locale('fr'),
    Locale('en'),
  ];

  static const Map<String, String> localeNames = {
    'fr': 'Français',
    'en': 'English',
  };

  @override
  Locale build() {
    _loadLocale();
    return const Locale('fr');
  }

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final localeCode = prefs.getString(_localeKey);

    if (localeCode != null) {
      final locale = supportedLocales.firstWhere(
        (l) => l.languageCode == localeCode,
        orElse: () => const Locale('fr'),
      );
      state = locale;
    }
  }

  Future<void> setLocale(Locale locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, locale.languageCode);
  }

  String get currentLocaleName {
    return localeNames[state.languageCode] ?? 'Français';
  }
}
