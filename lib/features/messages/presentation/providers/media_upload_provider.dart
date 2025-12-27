import 'dart:async';
import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'media_upload_provider.g.dart';

/// State for media upload with progress and cancellation support
enum MediaUploadStatus { idle, uploading, success, error, cancelled }

class MediaUploadState {
  final MediaUploadStatus status;
  final double progress; // 0.0 to 1.0
  final String? fileName;
  final File? file;
  final bool isImage;
  final String? caption;
  final String? error;
  final String? conversationId;

  const MediaUploadState({
    this.status = MediaUploadStatus.idle,
    this.progress = 0.0,
    this.fileName,
    this.file,
    this.isImage = true,
    this.caption,
    this.error,
    this.conversationId,
  });

  MediaUploadState copyWith({
    MediaUploadStatus? status,
    double? progress,
    String? fileName,
    File? file,
    bool? isImage,
    String? caption,
    String? error,
    String? conversationId,
  }) {
    return MediaUploadState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      fileName: fileName ?? this.fileName,
      file: file ?? this.file,
      isImage: isImage ?? this.isImage,
      caption: caption ?? this.caption,
      error: error,
      conversationId: conversationId ?? this.conversationId,
    );
  }

  bool get isUploading => status == MediaUploadStatus.uploading;
  bool get isIdle => status == MediaUploadStatus.idle;
  bool get hasFile => file != null;
}

/// Provider for managing media upload state with progress and cancellation
@riverpod
class MediaUpload extends _$MediaUpload {
  Completer<void>? _cancelCompleter;
  bool _isCancelled = false;

  @override
  MediaUploadState build() {
    return const MediaUploadState();
  }

  /// Start an upload with the given file
  void startUpload({
    required File file,
    required String conversationId,
    required bool isImage,
    String? caption,
  }) {
    _isCancelled = false;
    _cancelCompleter = Completer<void>();

    state = MediaUploadState(
      status: MediaUploadStatus.uploading,
      progress: 0.0,
      file: file,
      fileName: file.path.split('/').last.split('\\').last,
      isImage: isImage,
      caption: caption,
      conversationId: conversationId,
    );
  }

  /// Update the upload progress (0.0 to 1.0)
  void updateProgress(double progress) {
    if (state.isUploading) {
      state = state.copyWith(progress: progress.clamp(0.0, 1.0));
    }
  }

  /// Mark upload as successful
  void markSuccess() {
    state = state.copyWith(status: MediaUploadStatus.success, progress: 1.0);
    // Auto reset after short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (state.status == MediaUploadStatus.success) {
        reset();
      }
    });
  }

  /// Mark upload as failed with error message
  void markError(String errorMessage) {
    state = state.copyWith(
      status: MediaUploadStatus.error,
      error: errorMessage,
    );
  }

  /// Cancel the current upload
  void cancel() {
    if (state.isUploading) {
      _isCancelled = true;
      _cancelCompleter?.complete();
      state = state.copyWith(status: MediaUploadStatus.cancelled);
      // Auto reset after short delay
      Future.delayed(const Duration(milliseconds: 300), reset);
    }
  }

  /// Check if upload was cancelled
  bool get isCancelled => _isCancelled;

  /// Get the cancellation future (can be used for upload task cancellation)
  Future<void>? get cancellationFuture => _cancelCompleter?.future;

  /// Reset to idle state
  void reset() {
    _isCancelled = false;
    _cancelCompleter = null;
    state = const MediaUploadState();
  }
}
