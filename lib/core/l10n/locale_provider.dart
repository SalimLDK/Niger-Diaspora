import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../services/preferences_service.dart';

part 'locale_provider.g.dart';

@riverpod
class LocaleNotifier extends _$LocaleNotifier {
  final _prefs = PreferencesService.instance;

  static const List<Locale> supportedLocales = [Locale('fr'), Locale('en')];

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
    final localeCode = _prefs.locale;

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
    await _prefs.setLocale(locale.languageCode);
  }

  String get currentLocaleName {
    return localeNames[state.languageCode] ?? 'Français';
  }
}
