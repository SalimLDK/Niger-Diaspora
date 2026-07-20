import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

import '../../../../../core/theme/dn_colors.dart';
import '../../../../../core/theme/dn_text.dart';
import '../../../../../core/theme/dn_theme.dart';

/// Speaker vignette — supports audio-only and video modes.
class SpeakerTile extends StatelessWidget {
  final String name;
  final String role;
  final bool mic;
  final bool video;
  final bool host;
  final bool talking;
  final bool tipping;
  final double size;
  final lk.VideoTrack? videoTrack;

  const SpeakerTile({
    required this.name,
    required this.role,
    this.mic = true,
    this.video = false,
    this.host = false,
    this.talking = false,
    this.tipping = false,
    this.size = 56,
    this.videoTrack,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final ringColor = host
        ? DNColors.terra
        : (talking ? DNColors.leaf : Colors.transparent);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: ringColor,
                borderRadius: BorderRadius.circular(video ? 12 : 999),
              ),
              child: video
                  ? AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: videoTrack != null
                          ? _LiveVideoTile(
                              key: ValueKey(videoTrack),
                              videoTrack: videoTrack!,
                              size: size,
                            )
                          : _VideoTile(key: const ValueKey('placeholder'), name: name, size: size),
                    )
                  : _AvatarCircle(letter: name.isEmpty ? '?' : name[0], size: size),
            ),
            if (tipping)
              const Positioned(
                top: -4,
                right: -4,
                child: Text('🪙', style: TextStyle(fontSize: 16)),
              ),
          ],
        ),
        if (!video) ...[
          const SizedBox(height: 4),
          Text(
            name,
            style: DNText.sans(size: 10, w: FontWeight.w600, color: context.dn.onSurface),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              mic ? '🎙' : '🔇',
              style: TextStyle(
                fontSize: 8,
                color: mic ? context.dn.onSurface : DNColors.danger,
              ),
            ),
            const SizedBox(width: 3),
            Text(role, style: DNText.mono(size: 8, color: context.dn.onSurface3)),
          ],
        ),
      ],
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  final String letter;
  final double size;

  const _AvatarCircle({required this.letter, required this.size});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: context.dn.surfaceVariant,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          letter.toUpperCase(),
          style: DNText.serif(size: size * 0.4, color: context.dn.onSurface2),
        ),
      );
}

class _VideoTile extends StatelessWidget {
  final String name;
  final double size;

  const _VideoTile({super.key, required this.name, required this.size});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: DNColors.ink2,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          name.isEmpty ? '?' : name[0].toUpperCase(),
          style: DNText.serif(size: size * 0.4, color: DNColors.paper),
        ),
      );
}

/// Renders a live LiveKit video track inside the speaker tile.
class _LiveVideoTile extends StatelessWidget {
  final lk.VideoTrack videoTrack;
  final double size;

  const _LiveVideoTile({super.key, required this.videoTrack, required this.size});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: size,
        height: size,
        child: lk.VideoTrackRenderer(videoTrack),
      ),
    );
  }
}
