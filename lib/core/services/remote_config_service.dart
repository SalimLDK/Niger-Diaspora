import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'preferences_service.dart';

/// Configuration publique servie par l'Edge Function `app-config`.
///
/// Permet de changer une clé côté serveur sans republier d'APK. Ce n'est pas
/// un mécanisme de confidentialité : ce que l'endpoint renvoie est public par
/// construction. Sa liste blanche ne contient que des valeurs déjà extractibles
/// de l'APK aujourd'hui.
///
/// Ordre de résolution dans [AppConfig] : `--dart-define` d'abord, puis cette
/// configuration distante, puis le `.env` embarqué. Le `.env` reste donc le
/// filet : au premier lancement hors ligne, ou si la fonction est indisponible,
/// l'app démarre exactement comme avant.
class RemoteConfigService {
  RemoteConfigService._();

  static final RemoteConfigService instance = RemoteConfigService._();

  static const String _functionName = 'app-config';
  static const String _cacheKey = 'remote_config_cache_v1';

  /// Au-delà, on démarre sur le cache ou le `.env` : la configuration ne doit
  /// jamais retarder le premier écran.
  static const Duration _timeout = Duration(seconds: 4);

  Map<String, String> _values = const {};
  bool _initialized = false;

  /// True si une configuration distante (fraîche ou en cache) est chargée.
  bool get isLoaded => _values.isNotEmpty;

  /// Valeur distante pour [key], ou null — l'appelant retombe alors sur le
  /// `.env`. Retourne null tant que [initialize] n'a pas été appelé, ce qui
  /// rend l'ordre de démarrage inoffensif : `SUPABASE_URL` est lu avant, et
  /// doit continuer à venir du `.env`.
  String? value(String key) {
    if (!_initialized) return null;
    final v = _values[key];
    return (v != null && v.isNotEmpty) ? v : null;
  }

  /// À appeler après `Supabase.initialize` et `PreferencesService.initialize`.
  /// N'échoue jamais : toute erreur laisse l'app sur le `.env`.
  Future<void> initialize() async {
    // Le cache d'abord : il rend le démarrage indépendant du réseau, et sert
    // de repli immédiat si l'appel échoue.
    _values = _readCache();
    _initialized = true;

    try {
      final response = await Supabase.instance.client.functions
          .invoke(_functionName)
          .timeout(_timeout);

      if (response.status != 200) {
        debugPrint('RemoteConfig: HTTP ${response.status}, cache/.env conservés');
        return;
      }

      final body = response.data as Map<String, dynamic>?;
      final config = body?['config'] as Map<String, dynamic>?;
      if (config == null || config.isEmpty) return;

      final fresh = <String, String>{};
      config.forEach((k, v) {
        if (v is String && v.isNotEmpty) fresh[k] = v;
      });
      if (fresh.isEmpty) return;

      _values = fresh;
      await _writeCache(fresh);
    } catch (e) {
      // Hors ligne, fonction non déployée, Supabase non initialisé : tous ces
      // cas doivent être silencieux et non bloquants.
      debugPrint('RemoteConfig indisponible ($e) — cache/.env conservés');
    }
  }

  Map<String, String> _readCache() {
    try {
      final raw = PreferencesService.instance.prefs.getString(_cacheKey);
      if (raw == null || raw.isEmpty) return const {};
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return const {};
    }
  }

  Future<void> _writeCache(Map<String, String> values) async {
    try {
      await PreferencesService.instance.prefs
          .setString(_cacheKey, jsonEncode(values));
    } catch (_) {
      // Un cache non écrit n'est pas une erreur : le prochain démarrage
      // refera l'appel.
    }
  }
}
