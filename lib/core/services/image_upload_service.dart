import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'permission_service.dart';

enum ImageUploadType { profile, event, group, message, product, business, post }

/// Result of an image pick operation
class ImagePickResult {
  final File? file;
  final List<File> files;
  final bool permissionDenied;
  final PermissionResult? permissionResult;
  final String? errorMessage;

  const ImagePickResult({
    this.file,
    this.files = const [],
    this.permissionDenied = false,
    this.permissionResult,
    this.errorMessage,
  });

  /// Success result with a single file
  factory ImagePickResult.success(File file) => ImagePickResult(file: file);

  /// Success result with multiple files
  factory ImagePickResult.successMultiple(List<File> files) =>
      ImagePickResult(files: files);

  /// Permission denied result
  factory ImagePickResult.permissionDenied(PermissionResult result) =>
      ImagePickResult(
        permissionDenied: true,
        permissionResult: result,
        errorMessage: PermissionService.getCameraPermissionDeniedMessage(result),
      );

  /// Cancelled by user
  factory ImagePickResult.cancelled() => const ImagePickResult();

  /// Error result
  factory ImagePickResult.error(String message) =>
      ImagePickResult(errorMessage: message);

  bool get isSuccess => file != null || files.isNotEmpty;
  bool get isCancelled => !isSuccess && !permissionDenied && errorMessage == null;
}

/// Configuration for image uploads - can be set from admin settings
class ImageUploadConfig {
  final int maxWidth;
  final int maxHeight;
  final int quality;
  final int maxImagesPerUpload;
  final int minWidthForCompression;

  const ImageUploadConfig({
    this.maxWidth = 1024,
    this.maxHeight = 1024,
    this.quality = 85,
    this.maxImagesPerUpload = 5,
    this.minWidthForCompression = 800,
  });
}

class ImageUploadService {
  static final ImageUploadService _instance = ImageUploadService._internal();
  factory ImageUploadService() => _instance;
  ImageUploadService._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  /// Current configuration - can be updated from admin settings
  ImageUploadConfig _config = const ImageUploadConfig();

  /// Update configuration from admin settings
  void setConfig(ImageUploadConfig config) {
    _config = config;
  }

  /// Get current configuration
  ImageUploadConfig get config => _config;

  /// Pick an image from gallery
  /// Returns [ImagePickResult] with detailed status information
  Future<ImagePickResult> pickImageFromGalleryWithResult({
    int? maxWidth,
    int? maxHeight,
  }) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: (maxWidth ?? _config.maxWidth).toDouble(),
        maxHeight: (maxHeight ?? _config.maxHeight).toDouble(),
        imageQuality: _config.quality,
      );

      if (pickedFile == null) return ImagePickResult.cancelled();

      return ImagePickResult.success(File(pickedFile.path));
    } on PlatformException catch (e) {
      if (e.code == 'photo_access_denied') {
        return ImagePickResult(
          permissionDenied: true,
          permissionResult: PermissionResult.permanentlyDenied,
          errorMessage: PermissionService.getPhotoLibraryPermissionDeniedMessage(
            PermissionResult.permanentlyDenied,
          ),
        );
      }
      return ImagePickResult.error(
        e.message ?? 'Erreur lors de la sélection de l\'image',
      );
    } catch (e) {
      return ImagePickResult.error('Erreur lors de la sélection de l\'image');
    }
  }

  /// Pick an image from gallery (legacy method for backward compatibility)
  Future<File?> pickImageFromGallery({int? maxWidth, int? maxHeight}) async {
    final result = await pickImageFromGalleryWithResult(
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    );
    return result.file;
  }

  /// Pick an image from camera
  /// Returns [ImagePickResult] with detailed status information
  Future<ImagePickResult> pickImageFromCameraWithResult({
    int? maxWidth,
    int? maxHeight,
  }) async {
    try {
      // Request camera permission first
      final permissionResult =
          await PermissionService().requestCameraPermission();

      if (permissionResult != PermissionResult.granted) {
        return ImagePickResult.permissionDenied(permissionResult);
      }

      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: (maxWidth ?? _config.maxWidth).toDouble(),
        maxHeight: (maxHeight ?? _config.maxHeight).toDouble(),
        imageQuality: _config.quality,
      );

      if (pickedFile == null) return ImagePickResult.cancelled();

      return ImagePickResult.success(File(pickedFile.path));
    } on PlatformException catch (e) {
      if (e.code == 'camera_access_denied') {
        return ImagePickResult.permissionDenied(
          PermissionResult.permanentlyDenied,
        );
      }
      return ImagePickResult.error(e.message ?? 'Erreur lors de la prise de photo');
    } catch (e) {
      return ImagePickResult.error('Erreur lors de la prise de photo');
    }
  }

  /// Pick an image from camera (legacy method for backward compatibility)
  /// Prefer using [pickImageFromCameraWithResult] for better error handling
  Future<File?> pickImageFromCamera({int? maxWidth, int? maxHeight}) async {
    final result = await pickImageFromCameraWithResult(
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    );
    return result.file;
  }

  /// Pick multiple images from gallery
  /// Returns [ImagePickResult] with detailed status information
  Future<ImagePickResult> pickMultipleImagesWithResult({int? maxImages}) async {
    try {
      final List<XFile> pickedFiles = await _picker.pickMultiImage(
        maxWidth: _config.maxWidth.toDouble(),
        maxHeight: _config.maxHeight.toDouble(),
        imageQuality: _config.quality,
      );

      if (pickedFiles.isEmpty) return ImagePickResult.cancelled();

      final limit = maxImages ?? _config.maxImagesPerUpload;
      final files =
          pickedFiles.take(limit).map((xFile) => File(xFile.path)).toList();
      return ImagePickResult.successMultiple(files);
    } on PlatformException catch (e) {
      if (e.code == 'photo_access_denied') {
        return ImagePickResult(
          permissionDenied: true,
          permissionResult: PermissionResult.permanentlyDenied,
          errorMessage: PermissionService.getPhotoLibraryPermissionDeniedMessage(
            PermissionResult.permanentlyDenied,
          ),
        );
      }
      return ImagePickResult.error(
        e.message ?? 'Erreur lors de la sélection des images',
      );
    } catch (e) {
      return ImagePickResult.error('Erreur lors de la sélection des images');
    }
  }

  /// Pick multiple images from gallery (legacy method for backward compatibility)
  Future<List<File>> pickMultipleImages({int? maxImages}) async {
    final result = await pickMultipleImagesWithResult(maxImages: maxImages);
    return result.files;
  }

  /// Compress an image file
  Future<File?> compressImage(
    File file, {
    int? quality,
    int? minWidth,
    int? minHeight,
  }) async {
    try {
      final dir = await getTemporaryDirectory();
      final targetPath = path.join(
        dir.path,
        '${DateTime.now().millisecondsSinceEpoch}_compressed.jpg',
      );

      final XFile? result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: quality ?? _config.quality,
        minWidth: minWidth ?? _config.minWidthForCompression,
        minHeight: minHeight ?? _config.minWidthForCompression,
      );

      if (result == null) return null;

      return File(result.path);
    } catch (e) {
      // debugPrint('Error compressing image: $e');
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
      // Check authentication first
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        // debugPrint('❌ Upload failed: User not authenticated');
        throw Exception('User must be logged in to upload files');
      }

      // Compress image first
      final compressedFile = await compressImage(file);
      if (compressedFile == null) {
        // debugPrint('❌ Upload failed: Image compression failed');
        return null;
      }

      // Generate storage path
      final storagePath = customPath ?? _getStoragePath(type, id);
      final ref = _storage.ref().child(storagePath);

      // debugPrint('📤 Uploading image to: $storagePath');

      // Upload with progress tracking
      final uploadTask = ref.putFile(
        compressedFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      StreamSubscription<TaskSnapshot>? progressSubscription;
      if (onProgress != null) {
        progressSubscription = uploadTask.snapshotEvents.listen(
          (TaskSnapshot snapshot) {
            final progress = snapshot.bytesTransferred / snapshot.totalBytes;
            onProgress(progress);
          },
          onError: (e) {
            // debugPrint('Progress tracking error: $e');
          },
          cancelOnError: true,
        );
      }

      try {
        await uploadTask;
      } finally {
        // Always cancel the subscription when done
        await progressSubscription?.cancel();
      }

      // Get download URL
      final downloadUrl = await ref.getDownloadURL();
      // debugPrint('✅ Image uploaded successfully: $downloadUrl');

      return downloadUrl;
    } on FirebaseException catch (e) {
      // Handle specific Firebase Storage errors
      switch (e.code) {
        case 'unauthorized':
          // debugPrint(
          //   '❌ Upload failed: Unauthorized - Check Firebase Storage rules and user authentication',
          // );
          // debugPrint('   User ID: ${FirebaseAuth.instance.currentUser?.uid}');
          // debugPrint('   Error: ${e.message}');
          throw Exception(
            'You do not have permission to upload files. Please check your account permissions.',
          );

        case 'canceled':
          // debugPrint('⚠️ Upload canceled by user');
          return null;

        case 'unknown':
        case 'network-request-failed':
          // debugPrint('❌ Upload failed: Network error - ${e.message}');
          throw Exception(
            'Network connection failed. Please check your internet connection and try again.',
          );

        case 'retry-limit-exceeded':
          // debugPrint('❌ Upload failed: Too many retries');
          throw Exception(
            'Upload failed after multiple attempts. Please try again later.',
          );

        case 'invalid-checksum':
          // debugPrint('❌ Upload failed: File corrupted during upload');
          throw Exception('File upload was corrupted. Please try again.');

        default:
          // debugPrint('❌ Upload failed: ${e.code} - ${e.message}');
          throw Exception('Upload failed: ${e.message ?? 'Unknown error'}');
      }
    } catch (e) {
      // debugPrint('❌ Unexpected error uploading image: $e');
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
      // debugPrint('Image deleted successfully');
      return true;
    } catch (e) {
      // debugPrint('Error deleting image: $e');
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
      case ImageUploadType.post:
        return 'posts/$id/image_$timestamp.jpg';
    }
  }
}
