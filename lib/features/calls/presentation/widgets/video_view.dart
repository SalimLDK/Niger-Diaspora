import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';

/// Widget to display a WebRTC video stream
class VideoView extends StatelessWidget {
  final RTCVideoRenderer renderer;
  final bool mirror;
  final bool objectFit;
  final Widget? placeholder;

  const VideoView({
    super.key,
    required this.renderer,
    this.mirror = false,
    this.objectFit = true,
    this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    if (renderer.srcObject == null) {
      return placeholder ??
          Container(
            color: Colors.black,
            child: const Center(
              child: Icon(
                Icons.videocam_off,
                color: Colors.white54,
                size: 64,
              ),
            ),
          );
    }

    return RTCVideoView(
      renderer,
      mirror: mirror,
      objectFit: objectFit
          ? RTCVideoViewObjectFit.RTCVideoViewObjectFitCover
          : RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
    );
  }
}

/// Widget for displaying local video in a small overlay
class LocalVideoOverlay extends StatelessWidget {
  final RTCVideoRenderer renderer;
  final VoidCallback? onTap;

  const LocalVideoOverlay({
    super.key,
    required this.renderer,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      right: 16,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 120,
          height: 160,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: VideoView(
            renderer: renderer,
            mirror: true,
            placeholder: Container(
              color: Colors.grey[800],
              child: const Center(
                child: AppIcon(AppIcon.person,
                  color: Colors.white54,
                  size: 40,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
