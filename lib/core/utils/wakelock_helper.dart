import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Wraps wakelock_plus calls to avoid [NoActivityException]
/// when the app is in background or the activity is detached.
class WakelockHelper {
  WakelockHelper._();

  static Future<void> enable() async {
    try {
      await WakelockPlus.enable();
    } on Exception catch (e, stack) {
      debugPrint('WakelockHelper.enable ignored: $e');
      debugPrintStack(stackTrace: stack, label: 'WakelockHelper');
    }
  }

  static Future<void> disable() async {
    try {
      await WakelockPlus.disable();
    } on Exception catch (e, stack) {
      debugPrint('WakelockHelper.disable ignored: $e');
      debugPrintStack(stackTrace: stack, label: 'WakelockHelper');
    }
  }
}
