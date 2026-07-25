import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../utils/wakelock_helper.dart';

/// Service for managing proximity sensor during calls
///
/// Handles screen on/off based on proximity sensor state (phone near ear).
/// This prevents accidental touches during audio calls.
class ProximityService {
  static final ProximityService _instance = ProximityService._internal();
  factory ProximityService() => _instance;
  ProximityService._internal();

  static ProximityService get instance => _instance;

  static const _channel = MethodChannel('com.diasponiger.diaspo_niger/proximity');
  static const _eventChannel = EventChannel('com.diasponiger.diaspo_niger/proximity_events');

  StreamSubscription? _proximitySubscription;
  bool _isEnabled = false;
  bool _isNear = false;
  bool _screenOff = false;

  /// Whether the proximity sensor is currently enabled
  bool get isEnabled => _isEnabled;

  /// Whether the phone is currently near something (e.g., ear)
  bool get isNear => _isNear;

  /// Stream of proximity changes (true = near, false = far)
  final _proximityController = StreamController<bool>.broadcast();
  Stream<bool> get proximityStream => _proximityController.stream;

  /// Enable proximity sensor monitoring (for audio calls)
  Future<void> enable() async {
    if (_isEnabled) return;

    try {
      if (Platform.isAndroid) {
        await _enableAndroid();
      } else if (Platform.isIOS) {
        await _enableIOS();
      }
      _isEnabled = true;
      debugPrint('ProximityService: Enabled');
    } catch (e) {
      debugPrint('ProximityService: Error enabling: $e');
      // Fallback: just use wakelock without proximity
    }
  }

  /// Disable proximity sensor monitoring
  Future<void> disable() async {
    if (!_isEnabled) return;

    try {
      _proximitySubscription?.cancel();
    } catch (e) {
      // Ignore - channel may already be detached
    }
    _proximitySubscription = null;

    try {
      if (Platform.isAndroid) {
        await _disableAndroid();
      } else if (Platform.isIOS) {
        await _disableIOS();
      }
    } catch (e) {
      // Ignore MissingPluginException during cleanup
      if (!e.toString().contains('MissingPluginException')) {
        debugPrint('ProximityService: Error disabling platform: $e');
      }
    }

    // Ensure screen is back on
    if (_screenOff) {
      try {
        await _turnScreenOn();
      } catch (e) {
        // Ignore errors during cleanup
      }
    }

    _isEnabled = false;
    _isNear = false;
    debugPrint('ProximityService: Disabled');
  }

  /// Android-specific implementation
  Future<void> _enableAndroid() async {
    try {
      // Try to enable proximity sensor via platform channel
      await _channel.invokeMethod('enableProximitySensor');

      // Listen for proximity events
      _proximitySubscription = _eventChannel
          .receiveBroadcastStream()
          .listen(_onProximityEvent);
    } catch (e) {
      debugPrint('ProximityService: Android platform channel not available: $e');
      // Fallback implementation using sensors_plus or similar could be added here
    }
  }

  Future<void> _disableAndroid() async {
    try {
      await _channel.invokeMethod('disableProximitySensor');
    } catch (e) {
      // Ignore MissingPluginException during cleanup
      if (!e.toString().contains('MissingPluginException')) {
        debugPrint('ProximityService: Error disabling Android proximity: $e');
      }
    }
  }

  /// iOS-specific implementation (uses UIDevice.proximityMonitoringEnabled)
  Future<void> _enableIOS() async {
    try {
      await _channel.invokeMethod('enableProximitySensor');

      _proximitySubscription = _eventChannel
          .receiveBroadcastStream()
          .listen(_onProximityEvent);
    } catch (e) {
      debugPrint('ProximityService: iOS platform channel not available: $e');
    }
  }

  Future<void> _disableIOS() async {
    try {
      await _channel.invokeMethod('disableProximitySensor');
    } catch (e) {
      debugPrint('ProximityService: Error disabling iOS proximity: $e');
    }
  }

  /// Handle proximity sensor events
  void _onProximityEvent(dynamic event) {
    final isNear = event as bool? ?? false;

    if (isNear != _isNear) {
      _isNear = isNear;
      _proximityController.add(isNear);

      if (isNear) {
        _turnScreenOff();
      } else {
        _turnScreenOn();
      }

      debugPrint('ProximityService: Proximity changed - isNear: $isNear');
    }
  }

  /// Turn screen off (phone near ear)
  Future<void> _turnScreenOff() async {
    if (_screenOff) return;

    try {
      // On Android, we can use WindowManager flags via platform channel
      // On iOS, proximity sensor automatically dims the screen
      if (Platform.isAndroid) {
        await _channel.invokeMethod('turnScreenOff');
      }

      // Disable wakelock to allow screen to turn off
      await WakelockHelper.disable();
      _screenOff = true;

      debugPrint('ProximityService: Screen turned off');
    } catch (e) {
      debugPrint('ProximityService: Error turning screen off: $e');
    }
  }

  /// Turn screen back on (phone away from ear)
  Future<void> _turnScreenOn() async {
    if (!_screenOff) return;

    try {
      if (Platform.isAndroid) {
        await _channel.invokeMethod('turnScreenOn');
      }

      // Re-enable wakelock to keep screen on
      await WakelockHelper.enable();
      _screenOff = false;

      debugPrint('ProximityService: Screen turned on');
    } catch (e) {
      debugPrint('ProximityService: Error turning screen on: $e');
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    await disable();
    await _proximityController.close();
  }
}
