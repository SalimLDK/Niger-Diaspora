import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Callback type for PiP actions
typedef PipActionCallback = void Function(String action, Map<String, dynamic>? data);

/// Service for Picture-in-Picture (PiP) mode during video calls.
///
/// Allows the video call to continue in a small floating window
/// when the user leaves the app.
///
/// Supported on:
/// - Android 8.0+ (API 26+)
/// - iOS 15+ (with AVPictureInPictureController)
class PipService {
  static const _channel = MethodChannel('com.diasponiger.diaspo_niger/pip');

  static PipService? _instance;
  static PipService get instance => _instance ??= PipService._();

  PipService._() {
    // Listen for PiP mode changes from native side
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  /// Stream controller for PiP mode changes
  final _pipModeController = ValueNotifier<bool>(false);

  /// Callback for PiP action buttons (mute, endCall)
  PipActionCallback? onPipAction;

  /// Current PiP mode state
  ValueListenable<bool> get pipModeNotifier => _pipModeController;

  /// Whether device is currently in PiP mode
  bool get isInPipMode => _pipModeController.value;

  /// Handle method calls from native side
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onPipModeChanged':
        final isInPipMode = call.arguments['isInPipMode'] as bool? ?? false;
        _pipModeController.value = isInPipMode;
        debugPrint('PipService: PiP mode changed to $isInPipMode');
        break;
      case 'onPipAction':
        final action = call.arguments['action'] as String?;
        if (action != null) {
          debugPrint('PipService: PiP action received: $action');
          final data = Map<String, dynamic>.from(call.arguments as Map);
          data.remove('action');
          onPipAction?.call(action, data.isEmpty ? null : data);
        }
        break;
    }
  }

  /// Check if PiP is supported on this device
  Future<bool> isPipSupported() async {
    // PiP is supported on Android 8.0+ (API 26+) and iOS 15+
    if (!Platform.isAndroid && !Platform.isIOS) {
      return false;
    }

    try {
      final result = await _channel.invokeMethod<bool>('isPipSupported');
      return result ?? false;
    } catch (e) {
      debugPrint('PipService: Error checking PiP support: $e');
      return false;
    }
  }

  /// Check if currently in PiP mode
  Future<bool> isPipActive() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return false;
    }

    try {
      final result = await _channel.invokeMethod<bool>('isPipActive');
      return result ?? false;
    } catch (e) {
      debugPrint('PipService: Error checking PiP active: $e');
      return false;
    }
  }

  /// Enter PiP mode manually
  /// Returns true if successfully entered PiP mode
  Future<bool> enterPipMode() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return false;
    }

    try {
      final result = await _channel.invokeMethod<bool>('enterPip');
      return result ?? false;
    } catch (e) {
      debugPrint('PipService: Error entering PiP mode: $e');
      return false;
    }
  }

  /// Set video call state to enable/disable automatic PiP
  ///
  /// When [active] is true and [autoPipEnabled] is true, the app will
  /// automatically enter PiP mode when the user presses home or switches apps.
  Future<void> setVideoCallActive({
    required bool active,
    bool autoPipEnabled = true,
  }) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return;
    }

    try {
      await _channel.invokeMethod('setVideoCallActive', {
        'active': active,
        'autoPipEnabled': autoPipEnabled,
      });
      debugPrint('PipService: Video call active=$active, autoPip=$autoPipEnabled');
    } catch (e) {
      // Ignore MissingPluginException during cleanup (channel may be detached)
      if (!e.toString().contains('MissingPluginException')) {
        debugPrint('PipService: Error setting video call state: $e');
      }
    }
  }

  /// Update mute state for PiP button display (Android only)
  Future<void> updateMuteState(bool isMuted) async {
    if (!Platform.isAndroid) {
      return;
    }

    try {
      await _channel.invokeMethod('updateMuteState', {'isMuted': isMuted});
    } catch (e) {
      debugPrint('PipService: Error updating mute state: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _pipModeController.dispose();
  }
}
