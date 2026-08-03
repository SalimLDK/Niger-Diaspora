import 'package:flutter/widgets.dart';
import '../../l10n/app_localizations.dart';
import 'failures.dart';

/// Classe utilitaire pour convertir les Failures en messages user-friendly localisés
class FailureMapper {
  /// Convertit un Failure en message user-friendly localisé
  static String toUserFriendlyMessage(Failure failure, BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return switch (failure) {
      NetworkFailure() => l10n.errorNetwork,
      CacheFailure() => l10n.errorCache,
      AuthFailure() => l10n.errorAuth,
      ServerFailure() => _mapServerFailure(failure, l10n),
      ValidationFailure() => failure.message, // Messages de validation déjà user-friendly
      _ => l10n.errorUnknown,
    };
  }

  /// Convertit un message d'erreur technique en message user-friendly
  static String toUserFriendlyString(String technicalMessage, BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final lowerMsg = technicalMessage.toLowerCase();

    // Erreurs réseau
    if (lowerMsg.contains('socketexception') ||
        lowerMsg.contains('no internet') ||
        lowerMsg.contains('connection') ||
        lowerMsg.contains('network') ||
        lowerMsg.contains('timeout')) {
      return l10n.errorNetwork;
    }

    // Erreurs d'authentification
    if (lowerMsg.contains('permission') ||
        lowerMsg.contains('unauthorized') ||
        lowerMsg.contains('unauthenticated') ||
        lowerMsg.contains('auth')) {
      return l10n.errorAuth;
    }

    // Erreurs serveur
    if (lowerMsg.contains('server') ||
        lowerMsg.contains('firebase') ||
        lowerMsg.contains('exception')) {
      return l10n.errorServer;
    }

    // Erreurs de cache
    if (lowerMsg.contains('cache') || lowerMsg.contains('storage')) {
      return l10n.errorCache;
    }

    // Si le message est déjà en français et lisible, le garder
    if (_isUserFriendlyMessage(technicalMessage)) {
      return technicalMessage;
    }

    return l10n.errorUnknown;
  }

  static String _mapServerFailure(ServerFailure failure, AppLocalizations l10n) {
    final msg = failure.message.toLowerCase();

    // Mapper les messages techniques courants vers les messages localisés
    if (msg.contains('network') || msg.contains('connexion')) {
      return l10n.errorNetwork;
    }
    if (msg.contains('timeout') || msg.contains('expir')) {
      return l10n.errorTimeout;
    }
    if (msg.contains('permission') || msg.contains('autorisation')) {
      return l10n.errorAuth;
    }

    // Si le message semble déjà user-friendly (pas de termes techniques), le garder
    if (_isUserFriendlyMessage(failure.message)) {
      return failure.message;
    }

    return l10n.errorServer;
  }

  /// Vérifie si un message est déjà user-friendly (pas de jargon technique)
  static bool _isUserFriendlyMessage(String message) {
    final technicalTerms = [
      'exception',
      'error:',
      'failed to',
      'null',
      'undefined',
      'stacktrace',
      'firebase',
      'socket',
      'http',
      '404',
      '500',
      '403',
      'timeout',
      'refused',
      'denied',
    ];

    final lowerMsg = message.toLowerCase();
    for (final term in technicalTerms) {
      if (lowerMsg.contains(term)) {
        return false;
      }
    }

    // Un message user-friendly commence généralement par une majuscule
    // et ne contient pas de caractères techniques comme {}[]
    return !message.contains('{') &&
           !message.contains('[') &&
           !message.contains('Exception');
  }
}
