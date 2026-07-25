import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/call_entity.dart';
import '../providers/call_provider.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';

/// Provider to track if we're currently on the call screen
final isOnCallScreenProvider = StateProvider<bool>((ref) => false);

/// Floating indicator showing active call when user navigates away from call screen
class ActiveCallIndicator extends ConsumerStatefulWidget {
  const ActiveCallIndicator({super.key});

  @override
  ConsumerState<ActiveCallIndicator> createState() =>
      _ActiveCallIndicatorState();
}

class _ActiveCallIndicatorState extends ConsumerState<ActiveCallIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _durationTimer;
  Duration _displayedDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _durationTimer?.cancel();
    super.dispose();
  }

  void _startDurationTimer(Duration initialDuration) {
    _displayedDuration = initialDuration;
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _displayedDuration += const Duration(seconds: 1);
        });
      }
    });
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final callState = ref.watch(currentCallProvider);
    final isOnCallScreen = ref.watch(isOnCallScreenProvider);
    final l10n = AppLocalizations.of(context)!;

    // Only show if there's an active call and we're not on the call screen
    final shouldShow =
        callState.call != null && callState.isConnected && !isOnCallScreen;

    if (!shouldShow) {
      _durationTimer?.cancel();
      return const SizedBox.shrink();
    }

    // Start or update duration timer
    if (_durationTimer == null || !_durationTimer!.isActive) {
      _startDurationTimer(callState.duration ?? Duration.zero);
    }

    final call = callState.call!;
    final isVideo = call.type == CallType.video;

    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 16,
      right: 16,
      child: GestureDetector(
        onTap: () {
          // Defer navigation to avoid triggering context.push() while the
          // navigator is locked (e.g. mid-transition after a pop).
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.push('/calls/${call.id}');
          });
        },
        child: ScaleTransition(
          scale: _pulseAnimation,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.success,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.success.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Pulsing call icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: AppIcon(isVideo ? AppIcon.video : AppIcon.call,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                // Call info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.callInProgress,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDuration(_displayedDuration),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                // Tap to return indicator
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.touch_app,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        l10n.returnToCall,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact floating pill indicator for active call
class ActiveCallPill extends ConsumerStatefulWidget {
  const ActiveCallPill({super.key});

  @override
  ConsumerState<ActiveCallPill> createState() => _ActiveCallPillState();
}

class _ActiveCallPillState extends ConsumerState<ActiveCallPill> {
  Timer? _durationTimer;
  Duration _displayedDuration = Duration.zero;

  @override
  void dispose() {
    _durationTimer?.cancel();
    super.dispose();
  }

  void _startDurationTimer(Duration initialDuration) {
    _displayedDuration = initialDuration;
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _displayedDuration += const Duration(seconds: 1);
        });
      }
    });
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final callState = ref.watch(currentCallProvider);
    final isOnCallScreen = ref.watch(isOnCallScreenProvider);

    // Only show if there's an active call and we're not on the call screen
    final shouldShow =
        callState.call != null && callState.isConnected && !isOnCallScreen;

    if (!shouldShow) {
      _durationTimer?.cancel();
      return const SizedBox.shrink();
    }

    // Start or update duration timer
    if (_durationTimer == null || !_durationTimer!.isActive) {
      _startDurationTimer(callState.duration ?? Duration.zero);
    }

    final call = callState.call!;
    final isVideo = call.type == CallType.video;

    return Positioned(
      top: MediaQuery.of(context).padding.top + 4,
      right: 16,
      child: GestureDetector(
        onTap: () {
          // Navigate back to call screen
          context.push('/calls/${call.id}');
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.success,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.success.withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(isVideo ? AppIcon.video : AppIcon.call,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                _formatDuration(_displayedDuration),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
