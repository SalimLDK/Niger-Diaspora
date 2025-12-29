// import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure storage service for sensitive data like session IDs, tokens, etc.
/// Uses Flutter Secure Storage which encrypts data at rest.
class SecurePreferencesService {
  static SecurePreferencesService? _instance;
  static SecurePreferencesService get instance {
    _instance ??= SecurePreferencesService._();
    return _instance!;
  }

  SecurePreferencesService._();

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  // ============================
  // SECURE STORAGE KEYS
  // ============================

  static const String _keySessionId = 'secure_session_id';
  static const String _keyAuthToken = 'secure_auth_token';
  static const String _keyRefreshToken = 'secure_refresh_token';

  // ============================
  // SESSION MANAGEMENT
  // ============================

  /// Get the current session ID
  Future<String?> getSessionId() async {
    try {
      return await _secureStorage.read(key: _keySessionId);
    } catch (e) {
      // debugPrint('Error reading session ID: $e');
      return null;
    }
  }

  /// Set the session ID
  Future<void> setSessionId(String sessionId) async {
    try {
      await _secureStorage.write(key: _keySessionId, value: sessionId);
    } catch (e) {
      // debugPrint('Error writing session ID: $e');
    }
  }

  /// Clear the session ID
  Future<void> clearSessionId() async {
    try {
      await _secureStorage.delete(key: _keySessionId);
    } catch (e) {
      // debugPrint('Error clearing session ID: $e');
    }
  }

  // ============================
  // AUTH TOKEN MANAGEMENT
  // ============================

  /// Get the auth token
  Future<String?> getAuthToken() async {
    try {
      return await _secureStorage.read(key: _keyAuthToken);
    } catch (e) {
      // debugPrint('Error reading auth token: $e');
      return null;
    }
  }

  /// Set the auth token
  Future<void> setAuthToken(String token) async {
    try {
      await _secureStorage.write(key: _keyAuthToken, value: token);
    } catch (e) {
      // debugPrint('Error writing auth token: $e');
    }
  }

  /// Clear the auth token
  Future<void> clearAuthToken() async {
    try {
      await _secureStorage.delete(key: _keyAuthToken);
    } catch (e) {
      // debugPrint('Error clearing auth token: $e');
    }
  }

  // ============================
  // REFRESH TOKEN MANAGEMENT
  // ============================

  /// Get the refresh token
  Future<String?> getRefreshToken() async {
    try {
      return await _secureStorage.read(key: _keyRefreshToken);
    } catch (e) {
      // debugPrint('Error reading refresh token: $e');
      return null;
    }
  }

  /// Set the refresh token
  Future<void> setRefreshToken(String token) async {
    try {
      await _secureStorage.write(key: _keyRefreshToken, value: token);
    } catch (e) {
      // debugPrint('Error writing refresh token: $e');
    }
  }

  /// Clear the refresh token
  Future<void> clearRefreshToken() async {
    try {
      await _secureStorage.delete(key: _keyRefreshToken);
    } catch (e) {
      // debugPrint('Error clearing refresh token: $e');
    }
  }

  // ============================
  // GENERIC SECURE STORAGE
  // ============================

  /// Read a secure value by key
  Future<String?> read(String key) async {
    try {
      return await _secureStorage.read(key: key);
    } catch (e) {
      // debugPrint('Error reading secure value for key $key: $e');
      return null;
    }
  }

  /// Write a secure value
  Future<void> write(String key, String value) async {
    try {
      await _secureStorage.write(key: key, value: value);
    } catch (e) {
      // debugPrint('Error writing secure value for key $key: $e');
    }
  }

  /// Delete a secure value
  Future<void> delete(String key) async {
    try {
      await _secureStorage.delete(key: key);
    } catch (e) {
      // debugPrint('Error deleting secure value for key $key: $e');
    }
  }

  /// Check if a key exists
  Future<bool> containsKey(String key) async {
    try {
      return await _secureStorage.containsKey(key: key);
    } catch (e) {
      // debugPrint('Error checking key $key: $e');
      return false;
    }
  }

  // ============================
  // CLEAR ALL SECURE DATA
  // ============================

  /// Clear all secure storage data (use with caution - typically on logout)
  Future<void> clearAll() async {
    try {
      await _secureStorage.deleteAll();
      // debugPrint('All secure storage data cleared');
    } catch (e) {
      // debugPrint('Error clearing all secure storage: $e');
    }
  }

  /// Clear only auth-related data (session, tokens)
  Future<void> clearAuthData() async {
    try {
      await Future.wait([
        clearSessionId(),
        clearAuthToken(),
        clearRefreshToken(),
      ]);
      // debugPrint('Auth data cleared from secure storage');
    } catch (e) {
      // debugPrint('Error clearing auth data: $e');
    }
  }
}
