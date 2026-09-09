import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warning, error }

/// Service de logging centralisé
///
/// Rien n'est écrit hors mode debug, quel que soit le niveau : `debugPrint`
/// écrit aussi en release (cf. `foundation/print.dart`), où la sortie part
/// dans logcat — lisible par quiconque branche l'appareil.
///
/// Pour que le silence de la production ne fasse pas perdre les erreurs, le
/// seul niveau `error` est remonté à Crashlytics en non-fatal. Les autres
/// niveaux n'existent qu'en debug.
class LoggerService {
  static void d(String message, [dynamic error, StackTrace? stackTrace]) {
    _log(LogLevel.debug, message, error, stackTrace);
  }

  static void i(String message, [dynamic error, StackTrace? stackTrace]) {
    _log(LogLevel.info, message, error, stackTrace);
  }

  static void w(String message, [dynamic error, StackTrace? stackTrace]) {
    _log(LogLevel.warning, message, error, stackTrace);
  }

  static void e(String message, [dynamic error, StackTrace? stackTrace]) {
    _log(LogLevel.error, message, error, stackTrace);
  }

  static void _log(
    LogLevel level,
    String message, [
    dynamic error,
    StackTrace? stackTrace,
  ]) {
    if (!kDebugMode) {
      if (level == LogLevel.error) _recordToCrashlytics(message, error, stackTrace);
      return;
    }

    final timestamp = DateTime.now().toUtc().toIso8601String();
    final emoji = _getEmoji(level);
    final label = _getLabel(level);

    debugPrint('[$timestamp] $emoji$label: $message');

    if (error != null) {
      debugPrint('  Error: $error');
    }
    if (stackTrace != null) {
      debugPrint('  StackTrace: $stackTrace');
    }
  }

  /// Remonte une erreur de production à Crashlytics.
  ///
  /// Encadré : Crashlytics n'est utilisable qu'après l'initialisation de
  /// Firebase, et un journal ne doit jamais faire tomber l'appelant.
  static void _recordToCrashlytics(
    String message,
    dynamic error,
    StackTrace? stackTrace,
  ) {
    try {
      FirebaseCrashlytics.instance.recordError(
        error ?? message,
        stackTrace,
        reason: message,
        fatal: false,
      );
    } catch (_) {
      // Firebase pas encore prêt : on préfère perdre la remontée que l'app.
    }
  }

  static String _getEmoji(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return '🐛 ';
      case LogLevel.info:
        return 'ℹ️ ';
      case LogLevel.warning:
        return '⚠️ ';
      case LogLevel.error:
        return '❌ ';
    }
  }

  static String _getLabel(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return '[DEBUG]';
      case LogLevel.info:
        return '[INFO]';
      case LogLevel.warning:
        return '[WARN]';
      case LogLevel.error:
        return '[ERROR]';
    }
  }
}
