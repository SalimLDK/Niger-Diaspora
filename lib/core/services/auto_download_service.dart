import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../../features/messages/domain/entities/message_entity.dart';
import 'file_download_service.dart';
import 'preferences_service.dart';

/// Automatically downloads media messages to the device's private app folder
/// according to the per-type mode configured in [PreferencesService].
///
/// Modes:
///   'always'    – download on WiFi and mobile data
///   'wifi_only' – download only when on WiFi
///   'never'     – never auto-download; user must tap manually
class AutoDownloadService {
  static final AutoDownloadService _instance = AutoDownloadService._();
  factory AutoDownloadService() => _instance;
  AutoDownloadService._();

  final FileDownloadService _fileService = FileDownloadService();
  final Connectivity _connectivity = Connectivity();

  // Prevent duplicate concurrent downloads for the same message
  final Set<String> _inProgress = {};

  Future<bool> _isWifi() async {
    final results = await _connectivity.checkConnectivity();
    return results.contains(ConnectivityResult.wifi);
  }

  bool _shouldDownload(String mode, bool isWifi) {
    switch (mode) {
      case 'always':
        return true;
      case 'wifi_only':
        return isWifi;
      case 'never':
        return false;
      default:
        return false;
    }
  }

  String _modeForType(MessageType type) {
    final prefs = PreferencesService.instance;
    switch (type) {
      case MessageType.image:
        return prefs.autoDownloadImagesMode;
      case MessageType.audio:
      case MessageType.voiceNote:
        return prefs.autoDownloadAudioMode;
      case MessageType.video:
        return prefs.autoDownloadVideoMode;
      case MessageType.file:
        return prefs.autoDownloadFilesMode;
      default:
        return 'never';
    }
  }

  String _fallbackExtension(MessageType type) {
    switch (type) {
      case MessageType.image:
        return '.jpg';
      case MessageType.audio:
      case MessageType.voiceNote:
        return '.m4a';
      case MessageType.video:
        return '.mp4';
      default:
        return '';
    }
  }

  /// Try to auto-download [message] to app private storage.
  /// Silent — never throws; errors are only debugPrinted.
  Future<void> tryDownload(MessageEntity message) async {
    final type = message.type;
    if (type != MessageType.image &&
        type != MessageType.audio &&
        type != MessageType.voiceNote &&
        type != MessageType.video &&
        type != MessageType.file) {
      return;
    }

    if (message.mediaExpired || message.fileUrl == null) return;
    if (_inProgress.contains(message.id)) return;

    // Skip if already saved locally
    final existing = await _fileService.getDownloadedPath(message.id);
    if (existing != null && File(existing).existsSync()) return;

    _inProgress.add(message.id);
    try {
      final isWifi = await _isWifi();
      if (!_shouldDownload(_modeForType(type), isWifi)) return;

      final fileName =
          message.fileName?.isNotEmpty == true
              ? message.fileName!
              : '${message.id}${_fallbackExtension(type)}';

      await _fileService.downloadToAppDirectory(
        message.fileUrl!,
        fileName: fileName,
        messageId: message.id,
      );
    } catch (e) {
      debugPrint('[AutoDownload] Failed for ${message.id}: $e');
    } finally {
      _inProgress.remove(message.id);
    }
  }
}
