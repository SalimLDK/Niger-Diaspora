import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

enum ImageUploadType {
  profile,
  event,
  group,
  message,
  product,
  business,
}

class ImageUploadService {
  static final ImageUploadService _instance = ImageUploadService._internal();
  factory ImageUploadService() => _instance;
  ImageUploadService._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  /// Pick an image from gallery
  Future<File?> pickImageFromGallery({int maxWidth = 1024, int maxHeight = 1024}) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: maxWidth.toDouble(),
        maxHeight: maxHeight.toDouble(),
        imageQuality: 85,
      );

      if (pickedFile == null) return null;

      return File(pickedFile.path);
    } catch (e) {
      debugPrint('Error picking image from gallery: $e');
      return null;
    }
  }

  /// Pick an image from camera
  Future<File?> pickImageFromCamera({int maxWidth = 1024, int maxHeight = 1024}) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: maxWidth.toDouble(),
        maxHeight: maxHeight.toDouble(),
        imageQuality: 85,
      );

      if (pickedFile == null) return null;

      return File(pickedFile.path);
    } catch (e) {
      debugPrint('Error picking image from camera: $e');
      return null;
    }
  }

  /// Pick multiple images from gallery
  Future<List<File>> pickMultipleImages({int maxImages = 5}) async {
    try {
      final List<XFile> pickedFiles = await _picker.pickMultiImage(
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFiles.isEmpty) return [];

      final files = pickedFiles.take(maxImages).map((xFile) => File(xFile.path)).toList();
      return files;
    } catch (e) {
      debugPrint('Error picking multiple images: $e');
      return [];
    }
  }

  /// Compress an image file
  Future<File?> compressImage(File file, {int quality = 85, int minWidth = 800, int minHeight = 800}) async {
    try {
      final dir = await getTemporaryDirectory();
      final targetPath = path.join(
        dir.path,
        '${DateTime.now().millisecondsSinceEpoch}_compressed.jpg',
      );

      final XFile? result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: quality,
        minWidth: minWidth,
        minHeight: minHeight,
      );

      if (result == null) return null;

      return File(result.path);
    } catch (e) {
      debugPrint('Error compressing image: $e');
      return file; // Return original if compression fails
    }
  }

  /// Upload an image to Firebase Storage
  Future<String?> uploadImage({
    required File file,
    required ImageUploadType type,
    required String id,
    String? customPath,
    void Function(double progress)? onProgress,
  }) async {
    try {
      // Compress image first
      final compressedFile = await compressImage(file);
      if (compressedFile == null) return null;

      // Generate storage path
      final storagePath = customPath ?? _getStoragePath(type, id);
      final ref = _storage.ref().child(storagePath);

      // Upload with progress tracking
      final uploadTask = ref.putFile(
        compressedFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      if (onProgress != null) {
        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          onProgress(progress);
        });
      }

      await uploadTask;

      // Get download URL
      final downloadUrl = await ref.getDownloadURL();
      debugPrint('Image uploaded successfully: $downloadUrl');

      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }

  /// Upload multiple images
  Future<List<String>> uploadMultipleImages({
    required List<File> files,
    required ImageUploadType type,
    required String id,
    void Function(int current, int total, double progress)? onProgress,
  }) async {
    final List<String> urls = [];

    for (int i = 0; i < files.length; i++) {
      final url = await uploadImage(
        file: files[i],
        type: type,
        id: '${id}_${DateTime.now().millisecondsSinceEpoch}_$i',
        onProgress: (progress) {
          onProgress?.call(i + 1, files.length, progress);
        },
      );

      if (url != null) {
        urls.add(url);
      }
    }

    return urls;
  }

  /// Delete an image from Firebase Storage
  Future<bool> deleteImage(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
      debugPrint('Image deleted successfully');
      return true;
    } catch (e) {
      debugPrint('Error deleting image: $e');
      return false;
    }
  }

  /// Get storage path based on type
  String _getStoragePath(ImageUploadType type, String id) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    switch (type) {
      case ImageUploadType.profile:
        return 'profiles/$id/photo_$timestamp.jpg';
      case ImageUploadType.event:
        return 'events/$id/image_$timestamp.jpg';
      case ImageUploadType.group:
        return 'groups/$id/image_$timestamp.jpg';
      case ImageUploadType.message:
        return 'messages/$id/image_$timestamp.jpg';
      case ImageUploadType.product:
        return 'products/$id/image_$timestamp.jpg';
      case ImageUploadType.business:
        return 'businesses/$id/image_$timestamp.jpg';
    }
  }
}
