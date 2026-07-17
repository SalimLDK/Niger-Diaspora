class ServerException implements Exception {
  final String message;

  ServerException(this.message);

  @override
  String toString() => 'ServerException: $message';
}

class CacheException implements Exception {
  final String message;

  CacheException(this.message);

  @override
  String toString() => 'CacheException: $message';
}

class NetworkException implements Exception {
  final String message;

  NetworkException(this.message);

  @override
  String toString() => 'NetworkException: $message';
}

class AuthException implements Exception {
  final String message;
  final String? code;

  AuthException(this.message, {this.code});

  @override
  String toString() => 'AuthException: $message (code: $code)';
}

class ValidationException implements Exception {
  final String message;

  ValidationException(this.message);

  @override
  String toString() => 'ValidationException: $message';
}

/// Thrown when a requested resource genuinely does not exist (row absent).
///
/// Distinct from [ServerException] so callers can tell "l'entité a été
/// supprimée / n'existe pas" apart from a transient failure (réseau, RLS,
/// session non établie). Ne jamais l'utiliser pour une simple erreur de
/// chargement — sinon un profil temporairement illisible serait affiché
/// comme définitivement supprimé.
class NotFoundException implements Exception {
  final String message;

  NotFoundException(this.message);

  @override
  String toString() => 'NotFoundException: $message';
}

/// Thrown for permanent E2EE failures that are not worth retrying
/// (missing keys, uninitialized service, no Signal session available).
class E2EEException extends ServerException {
  E2EEException(super.message);

  @override
  String toString() => 'E2EEException: $message';
}
