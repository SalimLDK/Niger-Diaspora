import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/livekit_service.dart';
import '../../../../core/theme/dn_colors.dart';
import '../../../../core/theme/dn_text.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/live_podcast_provider.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';

/// Live video podcast screen.
///
/// Pass `isHost: true` (via GoRouter extra) to show the host controls.
/// Pass `livekitRoomName` and `episodeTitle` for viewer mode.
class LivePodcastScreen extends ConsumerStatefulWidget {
  final String podcastId;
  final bool isHost;
  final String? livekitRoomName;
  final String? episodeTitle;
  final String hostName;

  const LivePodcastScreen({
    super.key,
    required this.podcastId,
    required this.hostName,
    this.isHost = false,
    this.livekitRoomName,
    this.episodeTitle,
  });

  @override
  ConsumerState<LivePodcastScreen> createState() => _LivePodcastScreenState();
}

class _LivePodcastScreenState extends ConsumerState<LivePodcastScreen> {
  bool _isMuted = false;
  bool _isCameraOff = false;

  @override
  void dispose() {
    // Provider's onDispose handles LiveKit cleanup
    super.dispose();
  }

  Future<void> _startLive() async {
    await ref.read(livePodcastProvider.notifier).startLive(
          podcastId: widget.podcastId,
          hostName: widget.hostName,
          episodeTitle: widget.episodeTitle,
        );
  }

  Future<void> _endLive() async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.audioRoomEndRoomConfirm),
        content: Text(l10n.audioRoomEndRoomWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.audioRoomEndLabel, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await ref.read(livePodcastProvider.notifier).endLive();
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final liveState = ref.watch(livePodcastProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: widget.isHost
            ? _HostView(
                liveState: liveState,
                isMuted: _isMuted,
                isCameraOff: _isCameraOff,
                onStartLive: _startLive,
                onEndLive: _endLive,
                onToggleMute: () async {
                  await LiveKitService.instance.toggleMute();
                  setState(() => _isMuted = !_isMuted);
                },
                onToggleCamera: () async {
                  await LiveKitService.instance.toggleCamera();
                  setState(() => _isCameraOff = !_isCameraOff);
                },
              )
            : _ViewerView(
                liveState: liveState,
                episodeTitle: widget.episodeTitle,
                onLeave: () async {
                  final navigator = Navigator.of(context);
                  await ref.read(livePodcastProvider.notifier).leaveAsViewer();
                  if (mounted) navigator.pop();
                },
              ),
      ),
    );
  }
}

// ─── Host view ────────────────────────────────────────────────────────────────

class _HostView extends StatelessWidget {
  final LivePodcastState liveState;
  final bool isMuted;
  final bool isCameraOff;
  final VoidCallback onStartLive;
  final VoidCallback onEndLive;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleCamera;

  const _HostView({
    required this.liveState,
    required this.isMuted,
    required this.isCameraOff,
    required this.onStartLive,
    required this.onEndLive,
    required this.onToggleMute,
    required this.onToggleCamera,
  });

  @override
  Widget build(BuildContext context) {
    final localWidget = LiveKitService.instance.getLocalVideoWidget();

    return Stack(
      fit: StackFit.expand,
      children: [
        // Local camera preview
        if (localWidget != null && !isCameraOff)
          localWidget
        else
          Container(
            color: DNColors.ink,
            child: const Center(
              child: Icon(Icons.videocam_off, color: Colors.white54, size: 64),
            ),
          ),

        // LIVE badge
        if (liveState.isLive)
          const Positioned(
            top: 12,
            left: 16,
            child: _LiveBadge(),
          ),

        // Viewer count
        if (liveState.isLive)
          Positioned(
            top: 12,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.visibility, color: Colors.white, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '${liveState.viewerCount}',
                    style: DNText.mono(size: 11, color: DNColors.paper),
                  ),
                ],
              ),
            ),
          ),

        // Bottom controls
        Positioned(
          bottom: 24,
          left: 16,
          right: 16,
          child: Column(
            children: [
              if (liveState.error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade900,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    liveState.error!,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (liveState.isLive) ...[
                    _CircleBtn(
                      icon: isMuted
                          ? const AppIcon(AppIcon.micOff, color: Colors.white, size: 24)
                          : const AppIcon(AppIcon.mic, color: Colors.white, size: 24),
                      label: isMuted ? AppLocalizations.of(context)!.liveMicMuted : AppLocalizations.of(context)!.liveMicLabel,
                      onTap: onToggleMute,
                    ),
                    _CircleBtn(
                      icon: isCameraOff
                          ? const AppIcon(AppIcon.videocamOff, color: Colors.white, size: 24)
                          : const AppIcon(AppIcon.video, color: Colors.white, size: 24),
                      label: isCameraOff ? AppLocalizations.of(context)!.liveCameraOff : AppLocalizations.of(context)!.liveCameraLabel,
                      onTap: onToggleCamera,
                    ),
                    _CircleBtn(
                      icon: const Icon(Icons.stop_rounded, color: Colors.white, size: 24),
                      label: AppLocalizations.of(context)!.liveEndLabel,
                      color: Colors.red,
                      onTap: onEndLive,
                    ),
                  ] else ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: liveState.isConnecting ? null : onStartLive,
                        icon: liveState.isConnecting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.live_tv),
                        label: Text(
                          liveState.isConnecting
                              ? AppLocalizations.of(context)!.liveConnecting
                              : AppLocalizations.of(context)!.liveStartBroadcast,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Viewer view ──────────────────────────────────────────────────────────────

class _ViewerView extends StatelessWidget {
  final LivePodcastState liveState;
  final String? episodeTitle;
  final VoidCallback onLeave;

  const _ViewerView({
    required this.liveState,
    required this.episodeTitle,
    required this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    // Show the first remote participant's video (the host)
    final remote = LiveKitService.instance.remoteParticipants;
    final hostWidget = remote.isNotEmpty
        ? LiveKitService.instance.getVideoWidget(remote.first)
        : null;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Host video
        if (hostWidget != null)
          hostWidget
        else if (liveState.isConnecting)
          const Center(
            child: CircularProgressIndicator(color: Colors.white),
          )
        else
          Container(
            color: DNColors.ink,
            child: const Center(
              child: Icon(Icons.live_tv, color: Colors.white54, size: 80),
            ),
          ),

        // LIVE + back button
        Positioned(
          top: 12,
          left: 16,
          child: Row(
            children: [
              IconButton(
                icon: const AppIcon(AppIcon.arrowBack, color: Colors.white),
                onPressed: onLeave,
              ),
              const SizedBox(width: 8),
              const _LiveBadge(),
            ],
          ),
        ),

        // Viewer count
        Positioned(
          top: 20,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.visibility, color: Colors.white, size: 14),
                const SizedBox(width: 4),
                Text(
                  '${liveState.viewerCount}',
                  style: DNText.mono(size: 11, color: DNColors.paper),
                ),
              ],
            ),
          ),
        ),

        // Episode title at bottom
        if (episodeTitle != null)
          Positioned(
            bottom: 32,
            left: 16,
            right: 16,
            child: Text(
              episodeTitle!,
              style: DNText.serif(size: 18, color: DNColors.paper),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),

        // Error overlay
        if (liveState.error != null)
          Positioned(
            bottom: 80,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade900,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                liveState.error!,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(AppLocalizations.of(context)!.liveBadge, style: DNText.mono(size: 9, color: DNColors.paper)),
      );
}

class _CircleBtn extends StatelessWidget {
  final Widget icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _CircleBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color == Colors.red ? Colors.red : Colors.white24,
                shape: BoxShape.circle,
              ),
              child: icon,
            ),
            const SizedBox(height: 4),
            Text(label, style: DNText.mono(size: 9, color: DNColors.paper)),
          ],
        ),
      );
}
