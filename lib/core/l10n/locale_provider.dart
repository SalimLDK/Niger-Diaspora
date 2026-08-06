import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../errors/app_error_messages.dart';
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
    return _sync(const Locale('fr'));
  }

  /// `AppErrorMessages` est une classe statique qui garde sa propre langue.
  /// Personne n'appelait son `setLocale` : elle restait en français, et ses
  /// traductions anglaises — pourtant écrites — n'étaient jamais atteintes,
  /// alors qu'une dizaine d'écrans affichent ses messages via `ErrorHandler`.
  Locale _sync(Locale locale) {
    AppErrorMessages.setLocale(locale);
    return locale;
  }

  Future<void> _loadLocale() async {
    final localeCode = _prefs.locale;

    if (localeCode != null) {
      final locale = supportedLocales.firstWhere(
        (l) => l.languageCode == localeCode,
        orElse: () => const Locale('fr'),
      );
      state = _sync(locale);
    }
  }

  Future<void> setLocale(Locale locale) async {
    state = _sync(locale);
    await _prefs.setLocale(locale.languageCode);
  }

  String get currentLocaleName {
    return localeNames[state.languageCode] ?? 'Français';
  }
}
