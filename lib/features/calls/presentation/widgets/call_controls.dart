import 'package:flutter/material.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';
import '../../../../l10n/app_localizations.dart';

/// Widget for call control buttons (mute, camera, speaker, hangup)
class CallControls extends StatelessWidget {
  final bool isMuted;
  final bool isCameraOff;
  final bool isSpeakerOn;
  final bool isVideoCall;
  final VoidCallback onMutePressed;
  final VoidCallback onCameraPressed;
  final VoidCallback onSpeakerPressed;
  final VoidCallback onSwitchCameraPressed;
  final VoidCallback onHangupPressed;

  const CallControls({
    super.key,
    required this.isMuted,
    required this.isCameraOff,
    required this.isSpeakerOn,
    required this.isVideoCall,
    required this.onMutePressed,
    required this.onCameraPressed,
    required this.onSpeakerPressed,
    required this.onSwitchCameraPressed,
    required this.onHangupPressed,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.7),
          ],
        ),
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Mute button
            _ControlButton(
              icon: (color) => isMuted
                  ? AppIcon(AppIcon.micOff, color: color, size: 28)
                  : AppIcon(AppIcon.mic, color: color, size: 28),
              label: isMuted ? l10n.callEnable : l10n.callMute,
              isActive: !isMuted,
              onPressed: onMutePressed,
            ),

            // Camera button (only for video calls)
            if (isVideoCall) ...[
              _ControlButton(
                icon: (color) => isCameraOff
                    ? AppIcon(AppIcon.videocamOff, color: color, size: 28)
                    : AppIcon(AppIcon.video, color: color, size: 28),
                label: isCameraOff ? l10n.callEnable : l10n.callCamera,
                isActive: !isCameraOff,
                onPressed: onCameraPressed,
              ),
              _ControlButton(
                icon: (color) => Icon(Icons.flip_camera_ios, color: color, size: 28),
                label: l10n.callFlipCamera,
                isActive: true,
                onPressed: onSwitchCameraPressed,
              ),
            ],

            // Speaker button
            _ControlButton(
              icon: (color) => Icon(
                isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                color: color,
                size: 28,
              ),
              label: isSpeakerOn ? l10n.callSpeaker : l10n.callEarpiece,
              isActive: isSpeakerOn,
              onPressed: onSpeakerPressed,
            ),

            // Hangup button
            _HangupButton(onPressed: onHangupPressed, label: l10n.callHangUp),
          ],
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final Widget Function(Color color) icon;
  final String label;
  final bool isActive;
  final VoidCallback onPressed;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? Colors.white.withValues(alpha: 0.2) : Colors.white,
          ),
          child: IconButton(
            icon: icon(isActive ? Colors.white : Colors.black87),
            onPressed: onPressed,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _HangupButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;

  const _HangupButton({required this.onPressed, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.red,
          ),
          child: IconButton(
            icon: const Icon(
              Icons.call_end,
              color: Colors.white,
              size: 32,
            ),
            onPressed: onPressed,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
