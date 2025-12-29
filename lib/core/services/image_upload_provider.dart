import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../providers/app_settings_provider.dart';
import 'image_upload_service.dart';

part 'image_upload_provider.g.dart';

@riverpod
ImageUploadService imageUploadService(Ref ref) {
  final service = ImageUploadService();

  // Get media limits from app settings and configure the service
  final mediaLimits = ref.watch(mediaLimitsProvider);
  service.setConfig(ImageUploadConfig(
    maxWidth: mediaLimits.imageMaxWidth,
    maxHeight: mediaLimits.imageMaxHeight,
    quality: mediaLimits.imageQuality,
    maxImagesPerUpload: mediaLimits.maxImagesPerUpload,
    minWidthForCompression: mediaLimits.minWidthForCompression,
  ));

  return service;
}

@riverpod
class ImageUploadNotifier extends _$ImageUploadNotifier {
  @override
  ImageUploadState build() {
    return const ImageUploadState();
  }

  Future<String?> uploadImage({
    required File file,
    required ImageUploadType type,
    required String id,
  }) async {
    state = state.copyWith(isUploading: true, progress: 0);

    final service = ref.read(imageUploadServiceProvider);
    final url = await service.uploadImage(
      file: file,
      type: type,
      id: id,
      onProgress: (progress) {
        state = state.copyWith(progress: progress);
      },
    );

    state = state.copyWith(
      isUploading: false,
      progress: 1.0,
      uploadedUrl: url,
      error: url == null ? 'Erreur lors du téléchargement' : null,
    );

    return url;
  }

  Future<List<String>> uploadMultipleImages({
    required List<File> files,
    required ImageUploadType type,
    required String id,
  }) async {
    state = state.copyWith(
      isUploading: true,
      progress: 0,
      currentIndex: 0,
      totalFiles: files.length,
    );

    final service = ref.read(imageUploadServiceProvider);
    final urls = await service.uploadMultipleImages(
      files: files,
      type: type,
      id: id,
      onProgress: (current, total, progress) {
        state = state.copyWith(
          currentIndex: current,
          totalFiles: total,
          progress: progress,
        );
      },
    );

    state = state.copyWith(
      isUploading: false,
      progress: 1.0,
      uploadedUrls: urls,
    );

    return urls;
  }

  void reset() {
    state = const ImageUploadState();
  }
}

class ImageUploadState {
  final bool isUploading;
  final double progress;
  final int currentIndex;
  final int totalFiles;
  final String? uploadedUrl;
  final List<String> uploadedUrls;
  final String? error;

  const ImageUploadState({
    this.isUploading = false,
    this.progress = 0,
    this.currentIndex = 0,
    this.totalFiles = 0,
    this.uploadedUrl,
    this.uploadedUrls = const [],
    this.error,
  });

  ImageUploadState copyWith({
    bool? isUploading,
    double? progress,
    int? currentIndex,
    int? totalFiles,
    String? uploadedUrl,
    List<String>? uploadedUrls,
    String? error,
  }) {
    return ImageUploadState(
      isUploading: isUploading ?? this.isUploading,
      progress: progress ?? this.progress,
      currentIndex: currentIndex ?? this.currentIndex,
      totalFiles: totalFiles ?? this.totalFiles,
      uploadedUrl: uploadedUrl ?? this.uploadedUrl,
      uploadedUrls: uploadedUrls ?? this.uploadedUrls,
      error: error,
    );
  }
}
