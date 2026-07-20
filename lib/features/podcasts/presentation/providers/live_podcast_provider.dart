import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/livekit_service.dart';

class LivePodcastState {
  final bool isLive;
  final bool isConnecting;
  final String? episodeId;
  final String? livekitRoomName;
  final int viewerCount;
  final String? error;

  const LivePodcastState({
    this.isLive = false,
    this.isConnecting = false,
    this.episodeId,
    this.livekitRoomName,
    this.viewerCount = 0,
    this.error,
  });

  LivePodcastState copyWith({
    bool? isLive,
    bool? isConnecting,
    String? episodeId,
    String? livekitRoomName,
    int? viewerCount,
    String? error,
  }) => LivePodcastState(
        isLive: isLive ?? this.isLive,
        isConnecting: isConnecting ?? this.isConnecting,
        episodeId: episodeId ?? this.episodeId,
        livekitRoomName: livekitRoomName ?? this.livekitRoomName,
        viewerCount: viewerCount ?? this.viewerCount,
        error: error,
      );
}

final livePodcastProvider =
    NotifierProvider<LivePodcastNotifier, LivePodcastState>(
  LivePodcastNotifier.new,
);

class LivePodcastNotifier extends Notifier<LivePodcastState> {
  @override
  LivePodcastState build() {
    ref.onDispose(() {
      if (LiveKitService.instance.isConnected) {
        LiveKitService.instance.leaveRoom();
      }
    });
    return const LivePodcastState();
  }

  /// Start a live video podcast as host.
  Future<void> startLive({
    required String podcastId,
    required String hostName,
    String? episodeTitle,
  }) async {
    state = state.copyWith(isConnecting: true, error: null);
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('startLivePodcast');
      final result = await callable.call<Map<dynamic, dynamic>>({
        'podcastId': podcastId,
        'episodeTitle': episodeTitle ?? 'Live',
      });

      final episodeId = result.data['episodeId'] as String;
      final livekitRoomName = result.data['livekitRoomName'] as String;
      final hostToken = result.data['hostToken'] as String;

      await LiveKitService.instance.joinRoomWithToken(
        roomName: livekitRoomName,
        token: hostToken,
        participantName: hostName,
        enableVideo: true,
      );

      state = state.copyWith(
        isLive: true,
        isConnecting: false,
        episodeId: episodeId,
        livekitRoomName: livekitRoomName,
      );
    } catch (e) {
      debugPrint('LivePodcastNotifier.startLive error: $e');
      state = state.copyWith(
        isConnecting: false,
        error: 'Impossible de démarrer le direct : $e',
      );
    }
  }

  /// End the live podcast as host.
  Future<void> endLive() async {
    final episodeId = state.episodeId;
    if (episodeId == null) return;

    try {
      await LiveKitService.instance.leaveRoom();
      final callable =
          FirebaseFunctions.instance.httpsCallable('endLivePodcast');
      await callable.call<void>({'episodeId': episodeId});
    } catch (e) {
      debugPrint('LivePodcastNotifier.endLive error: $e');
    }
    state = const LivePodcastState();
  }

  /// Join a live podcast as viewer.
  Future<void> joinAsViewer({
    required String livekitRoomName,
    required String viewerName,
    required String podcastId,
  }) async {
    state = state.copyWith(isConnecting: true, error: null, livekitRoomName: livekitRoomName);
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('getLiveKitToken');
      final result = await callable.call<Map<dynamic, dynamic>>({
        'roomName': livekitRoomName,
        'participantName': viewerName,
      });
      final token = result.data['token'] as String;
      await LiveKitService.instance.joinRoomWithToken(
        roomName: livekitRoomName,
        token: token,
        participantName: viewerName,
        enableVideo: false,
      );
      state = state.copyWith(isLive: true, isConnecting: false);
    } catch (e) {
      debugPrint('LivePodcastNotifier.joinAsViewer error: $e');
      state = state.copyWith(
        isConnecting: false,
        error: 'Impossible de rejoindre le direct : $e',
      );
    }
  }

  /// Leave as viewer.
  Future<void> leaveAsViewer() async {
    await LiveKitService.instance.leaveRoom();
    state = const LivePodcastState();
  }

  void updateViewerCount(int count) =>
      state = state.copyWith(viewerCount: count);
}
