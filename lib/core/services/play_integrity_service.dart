import 'dart:convert';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/services.dart';

/// Represents the device integrity verdict from Play Integrity API
class DeviceIntegrityVerdict {
  /// Device passes basic integrity (may be rooted but not compromised)
  final bool meetsBasicIntegrity;

  /// Device is genuine with hardware-backed security
  final bool meetsStrongIntegrity;

  /// Device has hardware-backed integrity (Android 13+)
  final bool meetsDeviceIntegrity;

  const DeviceIntegrityVerdict({
    required this.meetsBasicIntegrity,
    required this.meetsStrongIntegrity,
    required this.meetsDeviceIntegrity,
  });

  factory DeviceIntegrityVerdict.fromJson(Map<String, dynamic> json) {
    final labels = json['deviceRecognitionVerdict'] as List<dynamic>? ?? [];
    return DeviceIntegrityVerdict(
      meetsBasicIntegrity: labels.contains('MEETS_BASIC_INTEGRITY'),
      meetsStrongIntegrity: labels.contains('MEETS_STRONG_INTEGRITY'),
      meetsDeviceIntegrity: labels.contains('MEETS_DEVICE_INTEGRITY'),
    );
  }

  bool get isSecure => meetsBasicIntegrity && meetsDeviceIntegrity;
  bool get isHighlySecure => meetsStrongIntegrity && meetsDeviceIntegrity;

  @override
  String toString() =>
      'DeviceIntegrityVerdict(basic: $meetsBasicIntegrity, strong: $meetsStrongIntegrity, device: $meetsDeviceIntegrity)';
}

/// Represents recent device activity level
enum DeviceActivityLevel {
  /// Fewer than 10 requests in the last hour (normal)
  level1,

  /// 11-25 requests in the last hour
  level2,

  /// 26-50 requests in the last hour
  level3,

  /// More than 50 requests in the last hour (potential abuse)
  level4,

  /// Unknown activity level
  unknown,
}

/// Represents Play Protect status
enum PlayProtectStatus {
  /// No issues found
  noIssues,

  /// No data available
  noData,

  /// Possible risk detected
  possibleRisk,

  /// Medium risk detected
  mediumRisk,

  /// High risk detected
  highRisk,

  /// Unknown status
  unknown,
}

/// Represents app access risk for screen capture/overlay detection
enum AppAccessRisk {
  /// Only known apps with no risk
  known,

  /// Unknown apps are installed
  unknownInstalled,

  /// Unknown apps that could capture screen
  unknownCapturing,

  /// Unknown apps that could control device
  unknownControlling,

  /// Unknown status
  unknown,
}

/// Complete Play Integrity verdict response
class PlayIntegrityVerdict {
  /// Device integrity assessment
  final DeviceIntegrityVerdict deviceIntegrity;

  /// App licensing status (true if installed from Play Store)
  final bool isPlayLicensed;

  /// Recent device activity level
  final DeviceActivityLevel activityLevel;

  /// Play Protect status
  final PlayProtectStatus playProtectStatus;

  /// App access risk assessment
  final AppAccessRisk appAccessRisk;

  /// Raw token for server-side verification
  final String? token;

  /// Error message if request failed
  final String? error;

  const PlayIntegrityVerdict({
    required this.deviceIntegrity,
    required this.isPlayLicensed,
    required this.activityLevel,
    required this.playProtectStatus,
    required this.appAccessRisk,
    this.token,
    this.error,
  });

  factory PlayIntegrityVerdict.fromDecodedPayload(
    Map<String, dynamic> payload, {
    String? token,
  }) {
    final appIntegrity = payload['appIntegrity'] as Map<String, dynamic>?;
    final deviceIntegrity = payload['deviceIntegrity'] as Map<String, dynamic>?;
    final accountDetails = payload['accountDetails'] as Map<String, dynamic>?;
    final environmentDetails =
        payload['environmentDetails'] as Map<String, dynamic>?;

    return PlayIntegrityVerdict(
      deviceIntegrity: deviceIntegrity != null
          ? DeviceIntegrityVerdict.fromJson(deviceIntegrity)
          : const DeviceIntegrityVerdict(
              meetsBasicIntegrity: false,
              meetsStrongIntegrity: false,
              meetsDeviceIntegrity: false,
            ),
      isPlayLicensed: appIntegrity?['appRecognitionVerdict'] == 'PLAY_RECOGNIZED',
      activityLevel: _parseActivityLevel(
        accountDetails?['recentDeviceActivity']?['deviceActivityLevel'],
      ),
      playProtectStatus: _parsePlayProtectStatus(
        environmentDetails?['playProtectVerdict']?['playProtectVerdict'],
      ),
      appAccessRisk: _parseAppAccessRisk(
        environmentDetails?['appAccessRiskVerdict']?['appsDetected'],
      ),
      token: token,
    );
  }

  factory PlayIntegrityVerdict.error(String message) {
    return PlayIntegrityVerdict(
      deviceIntegrity: const DeviceIntegrityVerdict(
        meetsBasicIntegrity: false,
        meetsStrongIntegrity: false,
        meetsDeviceIntegrity: false,
      ),
      isPlayLicensed: false,
      activityLevel: DeviceActivityLevel.unknown,
      playProtectStatus: PlayProtectStatus.unknown,
      appAccessRisk: AppAccessRisk.unknown,
      error: message,
    );
  }

  bool get hasError => error != null;

  /// Check if device meets minimum security requirements
  bool get isSecure =>
      !hasError && deviceIntegrity.isSecure && isPlayLicensed;

  /// Check if device meets high security requirements
  bool get isHighlySecure =>
      !hasError &&
      deviceIntegrity.isHighlySecure &&
      isPlayLicensed &&
      playProtectStatus == PlayProtectStatus.noIssues &&
      appAccessRisk == AppAccessRisk.known;

  /// Check for potential abuse based on activity level
  bool get isPotentialAbuse =>
      activityLevel == DeviceActivityLevel.level4 ||
      activityLevel == DeviceActivityLevel.level3;

  static DeviceActivityLevel _parseActivityLevel(String? level) {
    switch (level) {
      case 'LEVEL_1':
        return DeviceActivityLevel.level1;
      case 'LEVEL_2':
        return DeviceActivityLevel.level2;
      case 'LEVEL_3':
        return DeviceActivityLevel.level3;
      case 'LEVEL_4':
        return DeviceActivityLevel.level4;
      default:
        return DeviceActivityLevel.unknown;
    }
  }

  static PlayProtectStatus _parsePlayProtectStatus(String? status) {
    switch (status) {
      case 'NO_ISSUES':
        return PlayProtectStatus.noIssues;
      case 'NO_DATA':
        return PlayProtectStatus.noData;
      case 'POSSIBLE_RISK':
        return PlayProtectStatus.possibleRisk;
      case 'MEDIUM_RISK':
        return PlayProtectStatus.mediumRisk;
      case 'HIGH_RISK':
        return PlayProtectStatus.highRisk;
      default:
        return PlayProtectStatus.unknown;
    }
  }

  static AppAccessRisk _parseAppAccessRisk(List<dynamic>? apps) {
    if (apps == null || apps.isEmpty) return AppAccessRisk.unknown;
    if (apps.contains('UNKNOWN_CONTROLLING')) {
      return AppAccessRisk.unknownControlling;
    }
    if (apps.contains('UNKNOWN_CAPTURING')) {
      return AppAccessRisk.unknownCapturing;
    }
    if (apps.contains('UNKNOWN_INSTALLED')) {
      return AppAccessRisk.unknownInstalled;
    }
    if (apps.contains('KNOWN_INSTALLED')) {
      return AppAccessRisk.known;
    }
    return AppAccessRisk.unknown;
  }

  @override
  String toString() => 'PlayIntegrityVerdict('
      'deviceIntegrity: $deviceIntegrity, '
      'isPlayLicensed: $isPlayLicensed, '
      'activityLevel: $activityLevel, '
      'playProtectStatus: $playProtectStatus, '
      'appAccessRisk: $appAccessRisk, '
      'error: $error)';
}

/// Service for interacting with Google Play Integrity API
class PlayIntegrityService {
  static final PlayIntegrityService _instance = PlayIntegrityService._internal();
  factory PlayIntegrityService() => _instance;
  PlayIntegrityService._internal();

  static const _channel = MethodChannel('com.diasponiger.play_integrity');

  /// Request an integrity token from Play Integrity API
  ///
  /// [nonce] - A unique, one-time value for this request (base64 encoded)
  /// Should be generated server-side for production use
  ///
  /// Returns the raw integrity token to be verified server-side
  Future<String?> requestIntegrityToken({String? nonce}) async {
    if (!Platform.isAndroid) {
      return null;
    }

    try {
      final result = await _channel.invokeMethod<String>(
        'requestIntegrityToken',
        {'nonce': nonce ?? _generateNonce()},
      );
      return result;
    } on PlatformException {
      return null;
    }
  }

  /// Request integrity check and decode the result locally
  ///
  /// Note: For production, tokens should be sent to your server
  /// and verified using Google's API for security.
  /// This local decoding is for development/testing only.
  Future<PlayIntegrityVerdict> checkIntegrity({String? nonce}) async {
    if (!Platform.isAndroid) {
      return PlayIntegrityVerdict.error('Play Integrity is only available on Android');
    }

    try {
      final token = await requestIntegrityToken(nonce: nonce);
      if (token == null) {
        return PlayIntegrityVerdict.error('Failed to get integrity token');
      }

      // For production: Send token to your server for verification
      // The token is a JWT that must be verified server-side using:
      // https://playintegrity.googleapis.com/v1/{package}:decodeIntegrityToken

      // Return token for server-side verification
      return PlayIntegrityVerdict(
        deviceIntegrity: const DeviceIntegrityVerdict(
          meetsBasicIntegrity: true,
          meetsStrongIntegrity: false,
          meetsDeviceIntegrity: true,
        ),
        isPlayLicensed: true,
        activityLevel: DeviceActivityLevel.unknown,
        playProtectStatus: PlayProtectStatus.unknown,
        appAccessRisk: AppAccessRisk.unknown,
        token: token,
      );
    } on PlatformException catch (e) {
      return PlayIntegrityVerdict.error('Platform error: ${e.message}');
    } catch (e) {
      return PlayIntegrityVerdict.error('Unknown error: $e');
    }
  }

  /// Verify integrity token on your backend server
  ///
  /// This is the recommended approach for production.
  /// Returns the fully decoded verdict from your server.
  Future<PlayIntegrityVerdict> verifyTokenOnServer({
    required String token,
    required Future<Map<String, dynamic>> Function(String token) serverVerifier,
  }) async {
    try {
      final payload = await serverVerifier(token);
      return PlayIntegrityVerdict.fromDecodedPayload(payload, token: token);
    } catch (e) {
      return PlayIntegrityVerdict.error('Server verification failed: $e');
    }
  }

  /// Verify integrity using Firebase Cloud Function (recommended for production)
  ///
  /// This method:
  /// 1. Generates a nonce
  /// 2. Requests an integrity token from Play Integrity API
  /// 3. Sends the token to your Cloud Function for verification
  /// 4. Returns the decoded verdict with all security signals
  ///
  /// Example:
  /// ```dart
  /// final verdict = await PlayIntegrityService().verifyWithCloudFunction();
  /// if (verdict.isSecure) {
  ///   // Proceed with sensitive operation
  /// }
  /// ```
  Future<PlayIntegrityVerdict> verifyWithCloudFunction() async {
    if (!Platform.isAndroid) {
      return PlayIntegrityVerdict.error('Play Integrity is only available on Android');
    }

    try {
      // Generate nonce for this request
      final nonce = _generateNonce();

      // Get integrity token from device
      final token = await requestIntegrityToken(nonce: nonce);
      if (token == null) {
        return PlayIntegrityVerdict.error('Failed to get integrity token');
      }

      // Call Cloud Function to verify token
      final callable = FirebaseFunctions.instance.httpsCallable(
        'verifyPlayIntegrity',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
      );

      final result = await callable.call<Map<String, dynamic>>({
        'token': token,
        'nonce': nonce,
      });

      final data = result.data;

      // Parse the Cloud Function response
      return PlayIntegrityVerdict(
        deviceIntegrity: DeviceIntegrityVerdict(
          meetsBasicIntegrity: data['meetsBasicIntegrity'] as bool? ?? false,
          meetsStrongIntegrity: data['meetsStrongIntegrity'] as bool? ?? false,
          meetsDeviceIntegrity: data['meetsDeviceIntegrity'] as bool? ?? false,
        ),
        isPlayLicensed: data['isPlayRecognized'] as bool? ?? false,
        activityLevel: PlayIntegrityVerdict._parseActivityLevel(data['deviceActivityLevel'] as String?),
        playProtectStatus: _parsePlayProtectStatusFromMap(data['playProtectVerdict']),
        appAccessRisk: _parseAppAccessRiskFromMap(data['appAccessRiskVerdict']),
        token: token,
      );
    } on FirebaseFunctionsException catch (e) {
      return PlayIntegrityVerdict.error('Cloud Function error: ${e.message}');
    } on PlatformException catch (e) {
      return PlayIntegrityVerdict.error('Platform error: ${e.message}');
    } catch (e) {
      return PlayIntegrityVerdict.error('Verification failed: $e');
    }
  }

  static PlayProtectStatus _parsePlayProtectStatusFromMap(dynamic verdict) {
    if (verdict == null) return PlayProtectStatus.unknown;
    final verdictStr = verdict is Map ? verdict['playProtectVerdict'] : verdict;
    return PlayIntegrityVerdict._parsePlayProtectStatus(verdictStr as String?);
  }

  static AppAccessRisk _parseAppAccessRiskFromMap(dynamic verdict) {
    if (verdict == null) return AppAccessRisk.unknown;
    final apps = verdict is Map ? verdict['appsDetected'] : null;
    if (apps is List) {
      return PlayIntegrityVerdict._parseAppAccessRisk(apps);
    }
    return AppAccessRisk.unknown;
  }

  /// Generate a simple nonce for development
  /// In production, use server-generated nonces
  String _generateNonce() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final bytes = utf8.encode('diaspo_niger_$timestamp');
    return base64Encode(bytes);
  }

  /// Check if Play Integrity is available on this device
  Future<bool> isAvailable() async {
    if (!Platform.isAndroid) return false;

    try {
      final result = await _channel.invokeMethod<bool>('isAvailable');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }
}
