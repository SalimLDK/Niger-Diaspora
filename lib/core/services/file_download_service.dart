import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

/// Service for downloading files and saving to gallery
class FileDownloadService {
  static final FileDownloadService _instance = FileDownloadService._internal();
  factory FileDownloadService() => _instance;
  FileDownloadService._internal();

  final Dio _dio = Dio();

  /// Download an image and save it to the device gallery
  /// Returns true if successful, false otherwise
  Future<bool> downloadImageToGallery(
    String imageUrl, {
    String? fileName,
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
    void Function(int, int)? onProgress,
  }) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$fileName';

      await _dio.download(url, filePath, onReceiveProgress: onProgress);

      final file = File(filePath);
      if (await file.exists()) {
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
