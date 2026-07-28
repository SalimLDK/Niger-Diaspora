import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/image_upload_service.dart';
import '../../core/services/permission_service.dart';
import '../../core/theme/adaptive_colors.dart';
import 'sheet_handle.dart';

class ImagePickerDialog extends StatelessWidget {
  final Function(File file) onImageSelected;
  final bool allowMultiple;
  final int maxImages;

  const ImagePickerDialog({
    super.key,
    required this.onImageSelected,
    this.allowMultiple = false,
    this.maxImages = 5,
  });

  static Future<File?> show(BuildContext context) async {
    return showModalBottomSheet<File>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _ImagePickerSheet(
        onImageSelected: (file) => Navigator.pop(context, file),
      ),
    );
  }

  static Future<List<File>?> showMultiple(BuildContext context, {int maxImages = 5}) async {
    return showModalBottomSheet<List<File>>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _MultiImagePickerSheet(
        maxImages: maxImages,
        onImagesSelected: (files) => Navigator.pop(context, files),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _ImagePickerSheet(onImageSelected: onImageSelected);
  }
}

class _ImagePickerSheet extends StatelessWidget {
  final Function(File file) onImageSelected;

  const _ImagePickerSheet({required this.onImageSelected});

  Future<void> _handleCameraResult(
    BuildContext context,
    ImagePickResult result,
  ) async {
    if (result.isSuccess && result.file != null) {
      onImageSelected(result.file!);
    } else if (result.permissionDenied) {
      Navigator.pop(context);
      _showPermissionError(context, result);
    } else if (result.errorMessage != null) {
      Navigator.pop(context);
      _showError(context, result.errorMessage!);
    }
  }

  Future<void> _handleGalleryResult(
    BuildContext context,
    ImagePickResult result,
  ) async {
    if (result.isSuccess && result.file != null) {
      onImageSelected(result.file!);
    } else if (result.permissionDenied) {
      Navigator.pop(context);
      _showPermissionError(context, result);
    } else if (result.errorMessage != null) {
      Navigator.pop(context);
      _showError(context, result.errorMessage!);
    }
  }

  void _showPermissionError(BuildContext context, ImagePickResult result) {
    final isPermanent =
        result.permissionResult == PermissionResult.permanentlyDenied;

    PermissionService.showPermissionDeniedDialog(
      context: context,
      title: 'Permission requise',
      message: result.errorMessage ?? 'Permission refusée',
      showSettingsButton: isPermanent,
    );
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHandle(),
          const SizedBox(height: 20),
          Text(
            'Choisir une image',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: context.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _OptionButton(
                icon: Icons.camera_alt,
                label: 'Caméra',
                onTap: () async {
                  final result =
                      await ImageUploadService().pickImageFromCameraWithResult();
                  if (context.mounted) {
                    _handleCameraResult(context, result);
                  }
                },
              ),
              _OptionButton(
                icon: Icons.photo_library,
                label: 'Galerie',
                onTap: () async {
                  final result =
                      await ImageUploadService().pickImageFromGalleryWithResult();
                  if (context.mounted) {
                    _handleGalleryResult(context, result);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

class _MultiImagePickerSheet extends StatelessWidget {
  final int maxImages;
  final Function(List<File> files) onImagesSelected;

  const _MultiImagePickerSheet({
    required this.maxImages,
    required this.onImagesSelected,
  });

  Future<void> _handleCameraResult(
    BuildContext context,
    ImagePickResult result,
  ) async {
    if (result.isSuccess && result.file != null) {
      onImagesSelected([result.file!]);
    } else if (result.permissionDenied) {
      Navigator.pop(context);
      _showPermissionError(context, result);
    } else if (result.errorMessage != null) {
      Navigator.pop(context);
      _showError(context, result.errorMessage!);
    }
  }

  Future<void> _handleGalleryResult(
    BuildContext context,
    ImagePickResult result,
  ) async {
    if (result.isSuccess && result.files.isNotEmpty) {
      onImagesSelected(result.files);
    } else if (result.permissionDenied) {
      Navigator.pop(context);
      _showPermissionError(context, result);
    } else if (result.errorMessage != null) {
      Navigator.pop(context);
      _showError(context, result.errorMessage!);
    }
  }

  void _showPermissionError(BuildContext context, ImagePickResult result) {
    final isPermanent =
        result.permissionResult == PermissionResult.permanentlyDenied;

    PermissionService.showPermissionDeniedDialog(
      context: context,
      title: 'Permission requise',
      message: result.errorMessage ?? 'Permission refusée',
      showSettingsButton: isPermanent,
    );
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHandle(),
          const SizedBox(height: 20),
          Text(
            'Choisir des images',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: context.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Maximum $maxImages images',
            style: TextStyle(
              fontSize: 14,
              color: context.textTertiaryColor,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _OptionButton(
                icon: Icons.camera_alt,
                label: 'Caméra',
                onTap: () async {
                  final result =
                      await ImageUploadService().pickImageFromCameraWithResult();
                  if (context.mounted) {
                    _handleCameraResult(context, result);
                  }
                },
              ),
              _OptionButton(
                icon: Icons.photo_library,
                label: 'Galerie',
                onTap: () async {
                  final result =
                      await ImageUploadService().pickMultipleImagesWithResult(
                    maxImages: maxImages,
                  );
                  if (context.mounted) {
                    _handleGalleryResult(context, result);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

class _OptionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _OptionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: context.adaptivePrimaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              icon,
              size: 32,
              color: context.adaptivePrimaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: context.textPrimaryColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget for displaying an image with upload progress
class ImageUploadPreview extends StatelessWidget {
  final File file;
  final double? progress;
  final VoidCallback? onRemove;

  const ImageUploadPreview({
    super.key,
    required this.file,
    this.progress,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            file,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        if (progress != null && progress! < 1.0)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: CircularProgressIndicator(
                  value: progress,
                  color: AppColors.white,
                  strokeWidth: 3,
                ),
              ),
            ),
          ),
        if (onRemove != null)
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
