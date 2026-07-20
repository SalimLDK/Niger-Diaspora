import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// Service for receiving media/text shared from other apps into Diaspo Niger.
/// Wraps receive_sharing_intent and exposes a Riverpod provider.
class SharedMediaService {
  SharedMediaService() {
    _mediaStreamSubscription = ReceiveSharingIntent.instance
        .getMediaStream()
        .listen(
          _onMediaReceived,
          onError: (Object error) {
            debugPrint('SharedMediaService stream error: $error');
          },
        );

    // Also handle the case where the app was launched from a share intent.
    ReceiveSharingIntent.instance.getInitialMedia().then(_onInitialMedia).catchError(
      (Object error) {
        debugPrint('SharedMediaService initial media error: $error');
      },
    );
  }

  StreamSubscription<List<SharedMediaFile>>? _mediaStreamSubscription;

  final _controller = StreamController<List<SharedMediaFile>>.broadcast();

  /// Emits whenever new shared media is received while the app is running.
  Stream<List<SharedMediaFile>> get mediaStream => _controller.stream;

  /// Media received when the app was launched from a share intent.
  List<SharedMediaFile>? _initialMedia;

  /// Whether initial media has already been consumed.
  bool _initialConsumed = false;

  void _onMediaReceived(List<SharedMediaFile> value) {
    if (value.isNotEmpty) {
      _controller.add(value);
    }
  }

  void _onInitialMedia(List<SharedMediaFile> value) {
    _initialMedia = value.isNotEmpty ? value : null;
  }

  /// Returns media received when the app was cold-started from a share intent.
  /// Only returns a non-null value once; subsequent calls return null until reset.
  List<SharedMediaFile>? consumeInitialMedia() {
    if (_initialConsumed) return null;
    _initialConsumed = true;
    return _initialMedia;
  }

  /// Resets the initial media state so future cold starts can be detected.
  void resetInitialMedia() {
    _initialMedia = null;
    _initialConsumed = false;
  }

  /// Cleans up resources.
  void dispose() {
    _mediaStreamSubscription?.cancel();
    _controller.close();
  }
}

/// Provider for the shared media service.
final sharedMediaServiceProvider = Provider<SharedMediaService>((ref) {
  final service = SharedMediaService();
  ref.onDispose(service.dispose);
  return service;
});

/// Stream of shared media received while the app is in the foreground.
final sharedMediaStreamProvider = StreamProvider<List<SharedMediaFile>>((ref) {
  return ref.watch(sharedMediaServiceProvider).mediaStream;
});

/// Extension helpers to interpret receive_sharing_intent values.
extension SharedMediaFileX on SharedMediaFile {
  bool get isImage => type == SharedMediaType.image;
  bool get isVideo => type == SharedMediaType.video;
  bool get isText => type == SharedMediaType.text || type == SharedMediaType.url;
  bool get isFile => type == SharedMediaType.file;

  /// The actual local file path, when available.
  String get localPath => path;

  /// The shared text content, when the incoming type is text.
  String? get sharedText => message;

  /// Whether the file currently exists on disk.
  bool get exists => File(localPath).existsSync();
}
