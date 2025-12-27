import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// Service de compression d'images automatique pour optimiser les uploads
class ImageCompressorService {
  /// Compresse une image selon les paramètres donnés
  Future<File> compressImage(
    File imageFile, {
    int maxWidth = 1920,
    int maxHeight = 1920,
    int quality = 85,
  }) async {
    try {
      // Obtenir le répertoire temporaire
      final tempDir = await getTemporaryDirectory();
      final targetPath = path.join(
        tempDir.path,
        'compressed_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      // Compresser l'image
      final result = await FlutterImageCompress.compressAndGetFile(
        imageFile.absolute.path,
        targetPath,
        quality: quality,
        minWidth: maxWidth,
        minHeight: maxHeight,
        format: CompressFormat.jpeg,
      );

      if (result == null) {
        // Si la compression échoue, retourner le fichier original
        return imageFile;
      }

      return File(result.path);
    } catch (e) {
      debugPrint('Erreur de compression: $e');
      // En cas d'erreur, retourner le fichier original
      return imageFile;
    }
  }

  /// Compresse une image en mémoire et retourne les bytes
  Future<Uint8List?> compressImageToBytes(
    File imageFile, {
    int quality = 85,
  }) async {
    try {
      return await FlutterImageCompress.compressWithFile(
        imageFile.absolute.path,
        quality: quality,
      );
    } catch (e) {
      debugPrint('Erreur de compression en bytes: $e');
      return null;
    }
  }

  /// Obtient la taille d'un fichier en bytes
  Future<int> getFileSize(File file) async {
    try {
      return await file.length();
    } catch (e) {
      return 0;
    }
  }

  /// Formate la taille d'un fichier en format lisible
  String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  /// Vérifie si un fichier nécessite une compression
  Future<bool> needsCompression(File file, {int maxSizeInMB = 5}) async {
    final size = await getFileSize(file);
    return size > (maxSizeInMB * 1024 * 1024);
  }
}
