import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/preferences_service.dart';

part 'shared_preferences_provider.g.dart';

/// Provider for SharedPreferences instance
@riverpod
Future<SharedPreferences> sharedPreferences(Ref ref) async {
  return await SharedPreferences.getInstance();
}

/// Provider for PreferencesService singleton
@riverpod
PreferencesService preferencesService(Ref ref) {
  return PreferencesService.instance;
}
