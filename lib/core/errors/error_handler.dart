import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'failures.dart';
import 'exceptions.dart';
import 'app_error_messages.dart';

/// Gestionnaire centralisé des erreurs
class ErrorHandler {
  static ErrorHandler? _instance;
  static ErrorHandler get instance => _instance ??= ErrorHandler._();

  ErrorHandler._();

  /// Convertit une exception en Failure avec message user-friendly
  Failure handleException(dynamic exception, {String? context}) {
    debugPrint('ErrorHandler: $exception (context: $context)');

    // Firebase Auth Errors
    if (exception is FirebaseAuthException) {
      return _handleFirebaseAuthError(exception);
    }

    // Firebase Firestore Errors
    if (exception is FirebaseException) {
      return _handleFirebaseError(exception);
    }

    // Custom Exceptions
    if (exception is ServerException) {
      return ServerFailure(AppErrorMessages.serverError);
    }

    if (exception is CacheException) {
      return CacheFailure(AppErrorMessages.cacheError);
    }

    if (exception is NetworkException) {
      return NetworkFailure(AppErrorMessages.networkError);
    }

    if (exception is AuthException) {
      return AuthFailure(
        _getAuthMessage(exception.code),
        code: exception.code,
      );
    }

    if (exception is ValidationException) {
      return ValidationFailure(exception.message);
    }

    // Type Error (null issues, type casting)
    if (exception is TypeError) {
      return ServerFailure(AppErrorMessages.dataError);
    }

    // Format Exception (parsing issues)
    if (exception is FormatException) {
      return ValidationFailure(AppErrorMessages.formatError);
    }

    // Generic errors
    return ServerFailure(AppErrorMessages.unexpectedError);
  }

  /// Gère les erreurs Firebase Auth
  AuthFailure _handleFirebaseAuthError(FirebaseAuthException e) {
    return AuthFailure(
      _getAuthMessage(e.code),
      code: e.code,
    );
  }

  /// Gère les erreurs Firebase génériques
  Failure _handleFirebaseError(FirebaseException e) {
    switch (e.plugin) {
      case 'cloud_firestore':
        return _handleFirestoreError(e);
      case 'firebase_storage':
        return ServerFailure(AppErrorMessages.uploadError);
      default:
        return ServerFailure(AppErrorMessages.serverError);
    }
  }

  /// Gère les erreurs Firestore
  Failure _handleFirestoreError(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return ServerFailure(AppErrorMessages.permissionDenied);
      case 'not-found':
        return ServerFailure(AppErrorMessages.notFound);
      case 'already-exists':
        return ServerFailure(AppErrorMessages.alreadyExists);
      case 'resource-exhausted':
        return ServerFailure(AppErrorMessages.tooManyRequests);
      case 'unavailable':
        return NetworkFailure(AppErrorMessages.serviceUnavailable);
      case 'deadline-exceeded':
        return NetworkFailure(AppErrorMessages.timeout);
      default:
        return ServerFailure(AppErrorMessages.serverError);
    }
  }

  /// Retourne le message user-friendly pour les codes d'erreur auth
  String _getAuthMessage(String? code) {
    switch (code) {
      // Sign In Errors
      case 'user-not-found':
        return AppErrorMessages.userNotFound;
      case 'wrong-password':
        return AppErrorMessages.wrongPassword;
      case 'invalid-email':
        return AppErrorMessages.invalidEmail;
      case 'user-disabled':
        return AppErrorMessages.userDisabled;
      case 'invalid-credential':
        return AppErrorMessages.invalidCredential;

      // Sign Up Errors
      case 'email-already-in-use':
        return AppErrorMessages.emailAlreadyInUse;
      case 'weak-password':
        return AppErrorMessages.weakPassword;
      case 'operation-not-allowed':
        return AppErrorMessages.operationNotAllowed;

      // Rate Limiting
      case 'too-many-requests':
        return AppErrorMessages.tooManyRequests;

      // Network
      case 'network-request-failed':
        return AppErrorMessages.networkError;

      // Token/Session
      case 'expired-action-code':
        return AppErrorMessages.expiredCode;
      case 'invalid-action-code':
        return AppErrorMessages.invalidCode;

      // Social Auth
      case 'account-exists-with-different-credential':
        return AppErrorMessages.accountExistsWithDifferentCredential;
      case 'popup-closed-by-user':
        return AppErrorMessages.authCancelled;
      case 'cancelled-popup-request':
        return AppErrorMessages.authCancelled;

      // Requires recent login
      case 'requires-recent-login':
        return AppErrorMessages.requiresRecentLogin;

      default:
        return AppErrorMessages.authError;
    }
  }

  /// Obtient un message court pour les snackbars/toasts
  String getShortMessage(Failure failure) {
    if (failure is NetworkFailure) {
      return AppErrorMessages.networkErrorShort;
    }
    if (failure is AuthFailure) {
      return AppErrorMessages.authErrorShort;
    }
    if (failure is ValidationFailure) {
      return failure.message;
    }
    return AppErrorMessages.errorShort;
  }

  /// Log l'erreur pour le debugging
  void logError(dynamic error, StackTrace? stackTrace, {String? context}) {
    debugPrint('=== ERROR ===');
    debugPrint('Context: $context');
    debugPrint('Error: $error');
    if (stackTrace != null) {
      debugPrint('StackTrace: $stackTrace');
    }
    debugPrint('=============');

    // Ici on pourrait envoyer à Crashlytics
    // FirebaseCrashlytics.instance.recordError(error, stackTrace);
  }
}

/// Extension pour faciliter l'utilisation
extension FailureExtension on Failure {
  /// Message court pour snackbar/toast
  String get shortMessage => ErrorHandler.instance.getShortMessage(this);
}
