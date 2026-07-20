import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'app_file_encryption_service.dart';

/// Service for downloading and managing podcast episodes offline
class PodcastDownloadService {
  final Dio _dio;

  PodcastDownloadService({Dio? dio}) : _dio = dio ?? Dio();

  /// Get the download directory for podcasts
  Future<Directory> get _downloadDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final downloadDir = Directory('${appDir.path}/podcasts');
    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }
    return downloadDir;
  }

  /// Returns the path of the encrypted episode file on disk (.m4a.enc).
  Future<String> getLocalPath(String episodeId) async {
    final dir = await _downloadDir;
    return '${dir.path}/$episodeId.m4a.enc';
  }

  /// Legacy unencrypted path — kept for backward compatibility.
  Future<String> _legacyPath(String episodeId) async {
    final dir = await _downloadDir;
    return '${dir.path}/$episodeId.m4a';
  }

  /// Returns true if the episode is downloaded (encrypted or legacy plaintext).
  Future<bool> isDownloaded(String episodeId) async {
    final encPath = await getLocalPath(episodeId);
    if (await File(encPath).exists()) return true;
    // Backward compat: accept old unencrypted files
    final legacy = await _legacyPath(episodeId);
    return File(legacy).exists();
  }

  /// Returns the decrypted episode as a temporary [File] ready for playback,
  /// or `null` if the episode is not downloaded.
  ///
  /// For legacy unencrypted files, returns the file directly without copying.
  /// The returned temp file is overwritten on each call; do not hold a
  /// long-lived reference to it.
  Future<File?> decryptForPlayback(String episodeId) async {
    final encPath = await getLocalPath(episodeId);
    final encFile = File(encPath);

    if (await encFile.exists()) {
      return AppFileEncryptionService.instance.decryptToTemp(
        encFile,
        '${episodeId}_play.m4a',
      );
    }

    // Legacy: unencrypted file still on disk
    final legacy = File(await _legacyPath(episodeId));
    if (await legacy.exists()) return legacy;

    return null;
  }

  /// Get downloaded file size in bytes (reads the encrypted file size).
  Future<int> getDownloadedSize(String episodeId) async {
    final encPath = await getLocalPath(episodeId);
    final encFile = File(encPath);
    if (await encFile.exists()) return encFile.length();
    // Legacy
    final legacy = File(await _legacyPath(episodeId));
    if (await legacy.exists()) return legacy.length();
    return 0;
  }

  /// Downloads an episode, encrypts it on disk, and returns the encrypted
  /// file path on success, or `null` on failure.
  Future<String?> downloadEpisode({
    required String episodeId,
    required String audioUrl,
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final encPath = await getLocalPath(episodeId);
    final encFile = File(encPath);

    // Already downloaded (encrypted)
    if (await encFile.exists()) {
      debugPrint('PodcastDownloadService: Episode already downloaded');
      return encPath;
    }

    // Temp path for the raw download
    final tempDir = await getTemporaryDirectory();
    final tempPath = '${tempDir.path}/${episodeId}_dl.m4a';

    try {
      // Download raw audio to temp location
      await _dio.download(
        audioUrl,
        tempPath,
        onReceiveProgress: (received, total) {
          if (total > 0 && onProgress != null) {
            onProgress(received / total);
          }
        },
        cancelToken: cancelToken,
      );

      // Encrypt to the final location
      await AppFileEncryptionService.instance.encryptFile(
        File(tempPath),
        encFile,
      );

      debugPrint('PodcastDownloadService: Encrypted episode saved to $encPath');
      return encPath;
    } catch (e) {
      debugPrint('PodcastDownloadService: Error downloading: $e');
      // Clean up any partial files
      try {
        if (await File(tempPath).exists()) await File(tempPath).delete();
        if (await encFile.exists()) await encFile.delete();
      } catch (_) {}
      return null;
    } finally {
      // Always delete the plaintext temp file
      try {
        final temp = File(tempPath);
        if (await temp.exists()) await temp.delete();
      } catch (_) {}
    }
  }

  /// Deletes a downloaded episode (encrypted and any legacy plaintext copy).
  Future<bool> deleteDownload(String episodeId) async {
    bool deleted = false;
    try {
      final encFile = File(await getLocalPath(episodeId));
      if (await encFile.exists()) {
        await encFile.delete();
        deleted = true;
      }
      final legacy = File(await _legacyPath(episodeId));
      if (await legacy.exists()) {
        await legacy.delete();
        deleted = true;
      }
      if (deleted) {
        debugPrint('PodcastDownloadService: Deleted $episodeId');
      }
      return deleted;
    } catch (e) {
      debugPrint('PodcastDownloadService: Error deleting: $e');
      return false;
    }
  }

  /// Get total size of all downloaded episodes in bytes
  Future<int> getTotalDownloadedSize() async {
    try {
      final dir = await _downloadDir;
      if (!await dir.exists()) return 0;

      int totalSize = 0;
      await for (final entity in dir.list()) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
      return totalSize;
    } catch (e) {
      debugPrint('PodcastDownloadService: Error getting total size: $e');
      return 0;
    }
  }

  /// Delete all downloaded episodes
  Future<void> clearAllDownloads() async {
    try {
      final dir = await _downloadDir;
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        await dir.create();
      }
      debugPrint('PodcastDownloadService: Cleared all downloads');
    } catch (e) {
      debugPrint('PodcastDownloadService: Error clearing downloads: $e');
    }
  }

  /// Returns IDs of all downloaded episodes (encrypted and legacy).
  Future<List<String>> getDownloadedEpisodeIds() async {
    try {
      final dir = await _downloadDir;
      if (!await dir.exists()) return [];

      final ids = <String>{};
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        final name = entity.path.split('/').last;
        if (name.endsWith('.m4a.enc')) {
          ids.add(name.replaceAll('.m4a.enc', ''));
        } else if (name.endsWith('.m4a')) {
          ids.add(name.replaceAll('.m4a', ''));
        }
      }
      return ids.toList();
    } catch (e) {
      debugPrint('PodcastDownloadService: Error listing downloads: $e');
      return [];
    }
  }

  /// Format bytes to human readable string
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

/// Provider for the podcast download service
final podcastDownloadServiceProvider = Provider<PodcastDownloadService>((ref) {
  return PodcastDownloadService();
});

/// Download state for tracking active downloads
class DownloadState {
  final String episodeId;
  final double progress;
  final bool isDownloading;
  final bool isCompleted;
  final String? error;
  final CancelToken? cancelToken;

  const DownloadState({
    required this.episodeId,
    this.progress = 0,
    this.isDownloading = false,
    this.isCompleted = false,
    this.error,
    this.cancelToken,
  });

  DownloadState copyWith({
    String? episodeId,
    double? progress,
    bool? isDownloading,
    bool? isCompleted,
    String? error,
    CancelToken? cancelToken,
  }) {
    return DownloadState(
      episodeId: episodeId ?? this.episodeId,
      progress: progress ?? this.progress,
      isDownloading: isDownloading ?? this.isDownloading,
      isCompleted: isCompleted ?? this.isCompleted,
      error: error ?? this.error,
      cancelToken: cancelToken ?? this.cancelToken,
    );
  }
}

/// Notifier for managing download states
final downloadManagerProvider =
    NotifierProvider<DownloadManagerNotifier, Map<String, DownloadState>>(
  DownloadManagerNotifier.new,
);

class DownloadManagerNotifier extends Notifier<Map<String, DownloadState>> {
  @override
  Map<String, DownloadState> build() => {};

  PodcastDownloadService get _service =>
      ref.read(podcastDownloadServiceProvider);

  /// Start downloading an episode
  Future<void> startDownload({
    required String episodeId,
    required String audioUrl,
  }) async {
    // Check if already downloading
    if (state[episodeId]?.isDownloading == true) return;

    final cancelToken = CancelToken();

    state = {
      ...state,
      episodeId: DownloadState(
        episodeId: episodeId,
        isDownloading: true,
        cancelToken: cancelToken,
      ),
    };

    final result = await _service.downloadEpisode(
      episodeId: episodeId,
      audioUrl: audioUrl,
      onProgress: (progress) {
        state = {
          ...state,
          episodeId: state[episodeId]!.copyWith(progress: progress),
        };
      },
      cancelToken: cancelToken,
    );

    if (result != null) {
      state = {
        ...state,
        episodeId: DownloadState(
          episodeId: episodeId,
          progress: 1.0,
          isDownloading: false,
          isCompleted: true,
        ),
      };
    } else {
      state = {
        ...state,
        episodeId: DownloadState(
          episodeId: episodeId,
          isDownloading: false,
          error: 'Téléchargement échoué',
        ),
      };
    }
  }

  /// Cancel a download
  void cancelDownload(String episodeId) {
    final downloadState = state[episodeId];
    if (downloadState?.cancelToken != null) {
      downloadState!.cancelToken!.cancel();
    }
    state = Map.from(state)..remove(episodeId);
  }

  /// Delete a downloaded episode
  Future<void> deleteDownload(String episodeId) async {
    await _service.deleteDownload(episodeId);
    state = Map.from(state)..remove(episodeId);
  }

  /// Clear download state for an episode
  void clearState(String episodeId) {
    state = Map.from(state)..remove(episodeId);
  }
}

/// Provider to check if a specific episode is downloaded
final isEpisodeDownloadedProvider =
    FutureProvider.family<bool, String>((ref, episodeId) async {
  final service = ref.watch(podcastDownloadServiceProvider);
  return service.isDownloaded(episodeId);
});

/// Provider to get the playback-ready local path for a downloaded episode.
/// Returns the decrypted temp file path, or null if not downloaded.
final episodeLocalPathProvider =
    FutureProvider.family<String?, String>((ref, episodeId) async {
  final service = ref.watch(podcastDownloadServiceProvider);
  final file = await service.decryptForPlayback(episodeId);
  return file?.path;
});

/// Provider for total downloaded size
final totalDownloadedSizeProvider = FutureProvider<int>((ref) async {
  final service = ref.watch(podcastDownloadServiceProvider);
  return service.getTotalDownloadedSize();
});
