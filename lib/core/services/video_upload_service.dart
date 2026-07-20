import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:video_compress/video_compress.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

/// Result of a video upload operation
class VideoUploadResult {
  final String videoUrl;
  final String? thumbnailUrl;
  final int durationSeconds;
  final int fileSizeBytes;

  const VideoUploadResult({
    required this.videoUrl,
    this.thumbnailUrl,
    required this.durationSeconds,
    required this.fileSizeBytes,
  });
}

/// Result of a video pick operation
class VideoPickResult {
  final File? file;
  final bool cancelled;
  final String? errorMessage;

  const VideoPickResult({this.file, this.cancelled = false, this.errorMessage});

  factory VideoPickResult.success(File file) => VideoPickResult(file: file);
  factory VideoPickResult.cancelled() => const VideoPickResult(cancelled: true);
  factory VideoPickResult.error(String msg) => VideoPickResult(errorMessage: msg);

  bool get isSuccess => file != null;
}

const int _maxVideoSizeBytes = 600 * 1024 * 1024; // 600 MB

class VideoUploadService {
  static final VideoUploadService _instance = VideoUploadService._internal();
  factory VideoUploadService() => _instance;
  VideoUploadService._internal();

  static VideoUploadService get instance => _instance;

  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  UploadTask? _activeUploadTask;

  /// Stream of compression progress (0.0 – 1.0).
  ///
  /// [VideoCompress.compressProgress$] is an [ObservableBuilder<double>]:
  ///   - subscribe(callback) → Subscription(unsubscribe)
  ///   - no .value, no addListener/removeListener
  /// We wrap it in a broadcast StreamController to expose a proper Stream.
  Stream<double> get compressionProgressStream {
    Subscription? sub;
    // late so the lambda can reference controller after it is assigned.
    late final StreamController<double> controller;
    controller = StreamController<double>.broadcast(
      onListen: () {
        sub = VideoCompress.compressProgress$.subscribe((p) {
          if (!controller.isClosed) controller.add((p / 100.0).clamp(0.0, 1.0));
        });
      },
      onCancel: () {
        sub?.unsubscribe();
        sub = null;
      },
    );
    return controller.stream;
  }

  /// Cancel an in-progress upload (does not cancel compression).
  Future<void> cancelUpload() async {
    try {
      await _activeUploadTask?.cancel();
    } catch (_) {}
    _activeUploadTask = null;
  }

  /// Pick a video from the device gallery
  Future<VideoPickResult> pickVideoFromGallery({
    Duration maxDuration = const Duration(hours: 3),
  }) async {
    try {
      final XFile? picked = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: maxDuration,
      );
      if (picked == null) return VideoPickResult.cancelled();
      final file = File(picked.path);
      final sizeBytes = await file.length();
      if (sizeBytes > _maxVideoSizeBytes) {
        return VideoPickResult.error(
          'La vidéo dépasse la limite de 600 Mo. Veuillez choisir une vidéo plus courte.',
        );
      }
      return VideoPickResult.success(file);
    } catch (e) {
      debugPrint('VideoUploadService: pickVideoFromGallery error: $e');
      return VideoPickResult.error('Erreur lors de la sélection de la vidéo');
    }
  }

  /// Generate a thumbnail image from a local video file.
  /// Returns null if generation fails.
  Future<File?> generateThumbnail(String videoPath) async {
    try {
      final dir = await getTemporaryDirectory();
      final thumbnailPath = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: dir.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 640,
        quality: 75,
      );
      if (thumbnailPath == null) return null;
      return File(thumbnailPath);
    } catch (e) {
      debugPrint('VideoUploadService: generateThumbnail error: $e');
      return null;
    }
  }

  /// Compress a video file.
  /// Returns the original file if compression fails.
  Future<File?> compress(File file) async {
    try {
      final MediaInfo? info = await VideoCompress.compressVideo(
        file.path,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
        includeAudio: true,
      );
      if (info?.file == null) return file;
      return info!.file!;
    } catch (e) {
      debugPrint('VideoUploadService: compress error: $e');
      return file;
    }
  }

  /// Get video duration in seconds without full compression.
  Future<int> getVideoDuration(String videoPath) async {
    try {
      final MediaInfo info = await VideoCompress.getMediaInfo(videoPath);
      return ((info.duration ?? 0) / 1000).round();
    } catch (_) {
      return 0;
    }
  }

  /// Upload a video episode to Firebase Storage.
  ///
  /// Compresses the video, generates a thumbnail, uploads both,
  /// and returns a [VideoUploadResult] with all URLs and metadata.
  ///
  /// [podcastId] and [episodeId] define the Storage path.
  Future<VideoUploadResult?> uploadEpisodeVideo({
    required File file,
    required String podcastId,
    required String episodeId,
    void Function(double progress)? onProgress,
  }) async {
    if (FirebaseAuth.instance.currentUser == null) {
      throw Exception('Utilisateur non connecté');
    }

    final durationSeconds = await getVideoDuration(file.path);

    // Compress video
    final compressedFile = await compress(file) ?? file;
    final fileSizeBytes = await compressedFile.length();

    // Generate thumbnail
    final thumbnailFile = await generateThumbnail(file.path);

    // Upload video
    final videoStoragePath =
        'podcasts/$podcastId/episodes/$episodeId/video_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final videoUrl = await _uploadFile(
      file: compressedFile,
      storagePath: videoStoragePath,
      contentType: 'video/mp4',
      onProgress: onProgress,
    );
    if (videoUrl == null) return null;

    // Upload thumbnail (best-effort, no progress tracking)
    String? thumbnailUrl;
    if (thumbnailFile != null) {
      final thumbPath =
          'podcasts/$podcastId/episodes/$episodeId/thumbnail_${DateTime.now().millisecondsSinceEpoch}.jpg';
      thumbnailUrl = await _uploadFile(
        file: thumbnailFile,
        storagePath: thumbPath,
        contentType: 'image/jpeg',
      );
    }

    return VideoUploadResult(
      videoUrl: videoUrl,
      thumbnailUrl: thumbnailUrl,
      durationSeconds: durationSeconds,
      fileSizeBytes: fileSizeBytes,
    );
  }

  /// Upload a replay video to Firebase Storage.
  Future<VideoUploadResult?> uploadReplayVideo({
    required File file,
    required String roomId,
    void Function(double progress)? onProgress,
  }) async {
    if (FirebaseAuth.instance.currentUser == null) {
      throw Exception('Utilisateur non connecté');
    }

    final durationSeconds = await getVideoDuration(file.path);
    final fileSizeBytes = await file.length();
    final thumbnailFile = await generateThumbnail(file.path);

    final videoStoragePath =
        'audio-rooms/$roomId/replay/video_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final videoUrl = await _uploadFile(
      file: file,
      storagePath: videoStoragePath,
      contentType: 'video/mp4',
      onProgress: onProgress,
    );
    if (videoUrl == null) return null;

    String? thumbnailUrl;
    if (thumbnailFile != null) {
      final thumbPath =
          'audio-rooms/$roomId/replay/thumbnail_${DateTime.now().millisecondsSinceEpoch}.jpg';
      thumbnailUrl = await _uploadFile(
        file: thumbnailFile,
        storagePath: thumbPath,
        contentType: 'image/jpeg',
      );
    }

    return VideoUploadResult(
      videoUrl: videoUrl,
      thumbnailUrl: thumbnailUrl,
      durationSeconds: durationSeconds,
      fileSizeBytes: fileSizeBytes,
    );
  }

  /// Upload a feed post video to Firebase Storage.
  ///
  /// Compresses the video, generates a thumbnail, uploads both under the
  /// `posts/<postId>/` prefix (same as [ImageUploadService]) and returns a
  /// [VideoUploadResult] with the URLs and metadata.
  Future<VideoUploadResult?> uploadPostVideo({
    required File file,
    required String postId,
    void Function(double progress)? onProgress,
  }) async {
    if (FirebaseAuth.instance.currentUser == null) {
      throw Exception('Utilisateur non connecté');
    }

    final durationSeconds = await getVideoDuration(file.path);

    // Compress video
    final compressedFile = await compress(file) ?? file;
    final fileSizeBytes = await compressedFile.length();

    // Generate thumbnail (best-effort)
    final thumbnailFile = await generateThumbnail(file.path);

    final ts = DateTime.now().millisecondsSinceEpoch;
    final videoUrl = await _uploadFile(
      file: compressedFile,
      storagePath: 'posts/$postId/video_$ts.mp4',
      contentType: 'video/mp4',
      onProgress: onProgress,
    );
    if (videoUrl == null) return null;

    String? thumbnailUrl;
    if (thumbnailFile != null) {
      thumbnailUrl = await _uploadFile(
        file: thumbnailFile,
        storagePath: 'posts/$postId/thumbnail_$ts.jpg',
        contentType: 'image/jpeg',
      );
    }

    return VideoUploadResult(
      videoUrl: videoUrl,
      thumbnailUrl: thumbnailUrl,
      durationSeconds: durationSeconds,
      fileSizeBytes: fileSizeBytes,
    );
  }

  /// Delete a video from Firebase Storage by URL.
  Future<bool> deleteVideo(String url) async {
    try {
      await _storage.refFromURL(url).delete();
      return true;
    } catch (e) {
      debugPrint('VideoUploadService: deleteVideo error: $e');
      return false;
    }
  }

  Future<String?> _uploadFile({
    required File file,
    required String storagePath,
    required String contentType,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final ref = _storage.ref().child(storagePath);
      final uploadTask = ref.putFile(
        file,
        SettableMetadata(contentType: contentType),
      );
      _activeUploadTask = uploadTask;

      StreamSubscription<TaskSnapshot>? sub;
      if (onProgress != null) {
        sub = uploadTask.snapshotEvents.listen(
          (snapshot) {
            final p = snapshot.bytesTransferred / snapshot.totalBytes;
            onProgress(p.clamp(0.0, 1.0));
          },
          cancelOnError: true,
        );
      }

      try {
        await uploadTask;
      } finally {
        await sub?.cancel();
        _activeUploadTask = null;
      }

      return await ref.getDownloadURL();
    } on FirebaseException catch (e) {
      debugPrint('VideoUploadService: Firebase upload error ${e.code}: ${e.message}');
      if (e.code == 'unauthorized') {
        throw Exception('Permission refusée. Vérifiez vos droits de publication.');
      }
      rethrow;
    } catch (e) {
      debugPrint('VideoUploadService: upload error: $e');
      return null;
    }
  }

  /// Cancels any ongoing video compression.
  Future<void> cancelCompression() async {
    try {
      await VideoCompress.cancelCompression();
    } catch (_) {}
  }

  /// Gets the extension-stripped base name of a file for display.
  static String displayName(File file) =>
      path.basenameWithoutExtension(file.path);
}
