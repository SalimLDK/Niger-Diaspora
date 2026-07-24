import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Result of a permission request
enum PermissionResult {
  granted,
  denied,
  permanentlyDenied,
  restricted,
}

/// Service for handling app permissions (camera, photos, etc.)
class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  /// Request camera permission
  /// Returns [PermissionResult] indicating the outcome
  Future<PermissionResult> requestCameraPermission() async {
    var status = await Permission.camera.status;

    if (status.isGranted) {
      return PermissionResult.granted;
    }

    if (status.isPermanentlyDenied) {
      return PermissionResult.permanentlyDenied;
    }

    if (status.isRestricted) {
      return PermissionResult.restricted;
    }

    // Request the permission
    status = await Permission.camera.request();

    if (status.isGranted) {
      return PermissionResult.granted;
    } else if (status.isPermanentlyDenied) {
      return PermissionResult.permanentlyDenied;
    } else {
      return PermissionResult.denied;
    }
  }

  /// Request photo library permission (for picking images from gallery)
  /// Returns [PermissionResult] indicating the outcome
  Future<PermissionResult> requestPhotoLibraryPermission() async {
    // On Android 13+, we need READ_MEDIA_IMAGES
    // On older Android, we need READ_EXTERNAL_STORAGE
    // permission_handler handles this automatically with Permission.photos
    Permission permission;
    if (Platform.isAndroid) {
      // Use photos permission which maps to the correct permission based on API level
      permission = Permission.photos;
    } else {
      permission = Permission.photos;
    }

    var status = await permission.status;

    if (status.isGranted || status.isLimited) {
      return PermissionResult.granted;
    }

    if (status.isPermanentlyDenied) {
      return PermissionResult.permanentlyDenied;
    }

    if (status.isRestricted) {
      return PermissionResult.restricted;
    }

    // Request the permission
    status = await permission.request();

    if (status.isGranted || status.isLimited) {
      return PermissionResult.granted;
    } else if (status.isPermanentlyDenied) {
      return PermissionResult.permanentlyDenied;
    } else {
      return PermissionResult.denied;
    }
  }

  /// Check if camera permission is granted without requesting
  Future<bool> hasCameraPermission() async {
    final status = await Permission.camera.status;
    return status.isGranted;
  }

  /// Check if photo library permission is granted without requesting
  Future<bool> hasPhotoLibraryPermission() async {
    final status = await Permission.photos.status;
    return status.isGranted || status.isLimited;
  }

  /// Show a dialog explaining why permission is needed and offering to open settings
  static Future<bool> showPermissionDeniedDialog({
    required BuildContext context,
    required String title,
    required String message,
    bool showSettingsButton = true,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          if (showSettingsButton)
            TextButton(
              onPressed: () async {
                Navigator.pop(context, true);
                await openAppSettings();
              },
              child: const Text('Ouvrir les paramètres'),
            ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Get a user-friendly message for camera permission denial
  static String getCameraPermissionDeniedMessage(PermissionResult result) {
    switch (result) {
      case PermissionResult.permanentlyDenied:
        return 'L\'accès à la caméra a été refusé. Veuillez l\'activer dans les paramètres de l\'application.';
      case PermissionResult.restricted:
        return 'L\'accès à la caméra est restreint sur cet appareil.';
      case PermissionResult.denied:
        return 'L\'accès à la caméra est nécessaire pour prendre des photos.';
      case PermissionResult.granted:
        return '';
    }
  }

  static String getCameraPermissionDeniedMessageLocalized(
    PermissionResult result,
  ) =>
      getCameraPermissionDeniedMessage(result);

  /// Get a user-friendly message for photo library permission denial
  static String getPhotoLibraryPermissionDeniedMessage(PermissionResult result) {
    switch (result) {
      case PermissionResult.permanentlyDenied:
        return 'L\'accès aux photos a été refusé. Veuillez l\'activer dans les paramètres de l\'application.';
      case PermissionResult.restricted:
        return 'L\'accès aux photos est restreint sur cet appareil.';
      case PermissionResult.denied:
        return 'L\'accès aux photos est nécessaire pour sélectionner des images.';
      case PermissionResult.granted:
        return '';
    }
  }
}
