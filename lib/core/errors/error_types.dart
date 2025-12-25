import 'package:flutter/material.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

import 'failures.dart';

enum ErrorType {
  network,
  server,
  cache,
  auth,
  timeout,
  unknown,
}

extension FailureExtension on Failure {
  ErrorType get errorType {
    if (this is NetworkFailure) {
      final msg = message.toLowerCase();
      if (msg.contains('timeout') || msg.contains('timed out')) {
        return ErrorType.timeout;
      }
      return ErrorType.network;
    }
    if (this is ServerFailure) return ErrorType.server;
    if (this is CacheFailure) return ErrorType.cache;
    if (this is AuthFailure) return ErrorType.auth;
    return ErrorType.unknown;
  }

  String getLocalizedMessage(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (errorType) {
      case ErrorType.network:
        return l10n.errorNetwork;
      case ErrorType.server:
        return l10n.errorServer;
      case ErrorType.cache:
        return l10n.errorCache;
      case ErrorType.auth:
        return l10n.errorAuth;
      case ErrorType.timeout:
        return l10n.errorTimeout;
      case ErrorType.unknown:
        return l10n.errorUnknown;
    }
  }

  IconData get icon {
    switch (errorType) {
      case ErrorType.network:
        return Icons.wifi_off;
      case ErrorType.server:
        return Icons.cloud_off;
      case ErrorType.cache:
        return Icons.storage;
      case ErrorType.auth:
        return Icons.lock_outline;
      case ErrorType.timeout:
        return Icons.timer_off;
      case ErrorType.unknown:
        return Icons.error_outline;
    }
  }

  Color get iconColor {
    switch (errorType) {
      case ErrorType.network:
      case ErrorType.timeout:
        return Colors.orange;
      case ErrorType.server:
        return Colors.red;
      case ErrorType.cache:
        return Colors.blueGrey;
      case ErrorType.auth:
        return Colors.amber;
      case ErrorType.unknown:
        return Colors.grey;
    }
  }
}
