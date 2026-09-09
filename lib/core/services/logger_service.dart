import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warning, error }

/// Service de logging centralisé
///
/// Rien n'est écrit hors mode debug, quel que soit le niveau : `debugPrint`
/// écrit aussi en release (cf. `foundation/print.dart`), où la sortie part
/// dans logcat — lisible par quiconque branche l'appareil.
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
    if (!kDebugMode) return;

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
