import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for downloading files and saving to gallery
class FileDownloadService {
  static final FileDownloadService _instance = FileDownloadService._internal();
  factory FileDownloadService() => _instance;
  FileDownloadService._internal();

  final Dio _dio = Dio();

  static const String _downloadKeyPrefix = 'media_dl_';

  /// Records a local file path for a message after a successful download.
  Future<void> trackDownload(String messageId, String localPath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_downloadKeyPrefix$messageId', localPath);
    } catch (e) {
      debugPrint('Error tracking download: $e');
    }
  }

  /// Returns the locally saved path for a message, or null if not downloaded.
  Future<String?> getDownloadedPath(String messageId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('$_downloadKeyPrefix$messageId');
    } catch (e) {
      debugPrint('Error getting downloaded path: $e');
      return null;
    }
  }

  /// Download an image and save it to the device gallery
  /// Returns true if successful, false otherwise
  Future<bool> downloadImageToGallery(
    String imageUrl, {
    String? fileName,
    String? messageId,
    void Function(int, int)? onProgress,
  }) async {
    try {
      // Generate file name if not provided
      final name =
          fileName ??
          'niger_diaspora_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/$name';

      // Download the file
      await _dio.download(imageUrl, tempPath, onReceiveProgress: onProgress);

      // Save to gallery
      await Gal.putImage(tempPath, album: 'Diaspo Niger');

      // If tracking is needed, copy to app documents (persistent) before
      // deleting the temp file, and record that persistent path.
      if (messageId != null) {
        try {
          final appDir = await getApplicationDocumentsDirectory();
          final appPath = '${appDir.path}/$name';
          await File(tempPath).copy(appPath);
          await trackDownload(messageId, appPath);
        } catch (_) {
          // Tracking failure is non-fatal
        }
      }

      // Clean up temp file
      final tempFile = File(tempPath);
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      return true;
    } catch (e) {
      debugPrint('Error downloading image to gallery: $e');
      return false;
    }
  }

  /// Download a file to the app's documents directory
  /// Returns the downloaded file or null if failed
  Future<File?> downloadToAppDirectory(
    String url, {
    required String fileName,
    String? messageId,
    void Function(int, int)? onProgress,
  }) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$fileName';

      await _dio.download(url, filePath, onReceiveProgress: onProgress);

      final file = File(filePath);
      if (await file.exists()) {
        if (messageId != null) {
          await trackDownload(messageId, filePath);
        }
        return file;
      }
      return null;
    } catch (e) {
      debugPrint('Error downloading file: $e');
      return null;
    }
  }

  /// Download a file to a temporary directory
  /// Returns the downloaded file or null if failed
  Future<File?> downloadToTemp(
    String url, {
    String? fileName,
    void Function(int, int)? onProgress,
  }) async {
    try {
      final name =
          fileName ?? 'download_${DateTime.now().millisecondsSinceEpoch}';
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/$name';

      await _dio.download(url, filePath, onReceiveProgress: onProgress);

      final file = File(filePath);
      if (await file.exists()) {
        return file;
      }
      return null;
    } catch (e) {
      debugPrint('Error downloading file to temp: $e');
      return null;
    }
  }

  /// Check if permission to save to gallery is granted
  Future<bool> hasGalleryPermission() async {
    try {
      return await Gal.hasAccess();
    } catch (e) {
      debugPrint('Error checking gallery permission: $e');
      return false;
    }
  }

  /// Request permission to save to gallery
  Future<bool> requestGalleryPermission() async {
    try {
      return await Gal.requestAccess();
    } catch (e) {
      debugPrint('Error requesting gallery permission: $e');
      return false;
    }
  }
}
