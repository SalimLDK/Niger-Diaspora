import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../services/preferences_service.dart';

part 'theme_provider.g.dart';

enum AppThemeMode { light, dark, system }

@riverpod
class ThemeModeNotifier extends _$ThemeModeNotifier {
  final _prefs = PreferencesService.instance;

  @override
  AppThemeMode build() {
    _loadTheme();
    return AppThemeMode.system;
  }

  Future<void> _loadTheme() async {
    final themeString = _prefs.themeMode;

    if (themeString != null) {
      final mode = AppThemeMode.values.firstWhere(
        (e) => e.name == themeString,
        orElse: () => AppThemeMode.system,
      );
      state = mode;
    }
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    state = mode;
    await _prefs.setThemeMode(mode.name);
  }

  ThemeMode get themeMode {
    switch (state) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  bool get isDarkMode {
    if (state == AppThemeMode.system) {
      final brightness =
          SchedulerBinding.instance.platformDispatcher.platformBrightness;
      return brightness == Brightness.dark;
    }
    return state == AppThemeMode.dark;
  }
}

enum AppThemeColor { green, orange }

@riverpod
class ThemeColorNotifier extends _$ThemeColorNotifier {
  final _prefs = PreferencesService.instance;

  @override
  AppThemeColor build() {
    _loadColor();
    return AppThemeColor.green;
  }

  Future<void> _loadColor() async {
    final colorString = _prefs.themeColor;

    if (colorString != null) {
      final color = AppThemeColor.values.firstWhere(
        (e) => e.name == colorString,
        orElse: () => AppThemeColor.green,
      );
      state = color;
    }
  }

  Future<void> setThemeColor(AppThemeColor color) async {
    state = color;
    await _prefs.setThemeColor(color.name);
  }
}
