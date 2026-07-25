import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../core/services/ringtone_service.dart';
import '../../../../core/services/user_link_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../groups/domain/entities/group_entity.dart';
import '../../domain/entities/call_entity.dart';
import '../providers/call_provider.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';

/// Full-screen overlay for incoming calls
/// Now a ConsumerStatefulWidget to listen for call status changes
class IncomingCallOverlay extends ConsumerStatefulWidget {
  final CallEntity call;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  /// Called when user accepts a video call as audio-only (saves bandwidth)
  final VoidCallback? onAcceptAudioOnly;

  const IncomingCallOverlay({
    super.key,
    required this.call,
    required this.onAccept,
    required this.onDecline,
    this.onAcceptAudioOnly,
  });

  @override
  ConsumerState<IncomingCallOverlay> createState() =>
      _IncomingCallOverlayState();
}

class _IncomingCallOverlayState extends ConsumerState<IncomingCallOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  final _ringtoneService = RingtoneService();
  Timer? _missedCallTimer;
  bool _isDismissing = false;

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

    // D├®marrer la sonnerie et la vibration
    _ringtoneService.startRinging(
      isVideoCall: widget.call.type == CallType.video,
    );

    // D├®marrer le timeout d'appel manqu├® (45 secondes)
    _startMissedCallTimeout();
  }

  void _startMissedCallTimeout() {
    _missedCallTimer = Timer(const Duration(seconds: 45), () {
      if (mounted && !_isDismissing) {
        debugPrint('IncomingCallOverlay: Timeout reached, marking as missed');
        _dismissOverlay();
        widget.onDecline();
      }
    });
  }

  void _dismissOverlay() {
    if (_isDismissing) return;
    _isDismissing = true;
    _ringtoneService.stopRinging();
    _missedCallTimer?.cancel();
    // L'overlay sera retir├® automatiquement car incomingCallProvider retournera null
  }

  @override
  void dispose() {
    _missedCallTimer?.cancel();
    _ringtoneService.stopRinging();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isVideoCall = widget.call.type == CallType.video;

    // ├ëcouter les changements de status de l'appel pour d├®tecter
    // si l'appelant a annul├® l'appel
    ref.listen<AsyncValue<CallEntity?>>(callByIdProvider(widget.call.id), (
      previous,
      next,
    ) {
      final call = next.valueOrNull;

      if (call == null) {
        // Appel supprim├® de la base de donn├®es
        debugPrint('IncomingCallOverlay: Call document deleted, dismissing');
        _dismissOverlay();
        return;
      }

      // L'appelant a annul├® l'appel (status terminal)
      if (call.status == CallStatus.ended ||
          call.status == CallStatus.missed ||
          call.status == CallStatus.declined) {
        debugPrint(
          'IncomingCallOverlay: Caller cancelled (${call.status}), dismissing',
        );
        _dismissOverlay();
      }
    });

    return Material(
      color: Colors.black.withValues(alpha: 0.95),
      child: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),

            // Call type indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  isVideoCall
                      ? const AppIcon(
                          AppIcon.video,
                          color: Colors.white,
                          size: 20,
                        )
                      : const AppIcon(
                          AppIcon.call,
                          color: Colors.white,
                          size: 20,
                        ),
                  const SizedBox(width: 8),
                  Text(
                    isVideoCall
                        ? l10n.incomingVideoCall
                        : l10n.incomingAudioCall,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Caller avatar with pulse animation
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: child,
                );
              },
              child: _buildAvatar(),
            ),

            const SizedBox(height: 24),

            // Caller name
            Text(
              widget.call.callerName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            // Status
            Text(
              l10n.incomingCallStatus,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 16),

            // Unknown caller warning and common groups
            _buildLinkStatusWidget(l10n),

            const Spacer(flex: 3),

            // Action buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Decline button
                      _ActionButton(
                        icon: const Icon(Icons.call_end, color: Colors.white, size: 32),
                        label: l10n.callDecline,
                        color: Colors.red,
                        onPressed: () {
                          _ringtoneService.stopRinging();
                          widget.onDecline();
                        },
                      ),

                      // Accept button (video for video calls, audio for audio calls)
                      _ActionButton(
                        icon: isVideoCall
                            ? const AppIcon(
                                AppIcon.video,
                                color: Colors.white,
                                size: 32,
                              )
                            : const AppIcon(
                                AppIcon.call,
                                color: Colors.white,
                                size: 32,
                              ),
                        label: l10n.callAccept,
                        color: Colors.green,
                        onPressed: () {
                          _ringtoneService.stopRinging();
                          widget.onAccept();
                        },
                      ),
                    ],
                  ),

                  // Audio-only button for video calls (saves bandwidth on weak network)
                  if (isVideoCall && widget.onAcceptAudioOnly != null) ...[
                    const SizedBox(height: 24),
                    GestureDetector(
                      onTap: () {
                        _ringtoneService.stopRinging();
                        widget.onAcceptAudioOnly!();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const AppIcon(AppIcon.call,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              l10n.answerAudioOnly,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.3),
            blurRadius: 30,
            spreadRadius: 10,
          ),
        ],
      ),
      child: ClipOval(
        child:
            widget.call.callerPhotoUrl != null
                ? CachedNetworkImage(
                  imageUrl: widget.call.callerPhotoUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => _buildDefaultAvatar(),
                  errorWidget: (_, __, ___) => _buildDefaultAvatar(),
                )
                : _buildDefaultAvatar(),
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      color: Colors.grey[700],
      child: Center(
        child: Text(
          widget.call.callerName.isNotEmpty
              ? widget.call.callerName[0].toUpperCase()
              : '?',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 56,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildLinkStatusWidget(AppLocalizations l10n) {
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    if (currentUser == null) return const SizedBox.shrink();

    final callerId = widget.call.callerId;
    final linkAsync = ref.watch(
      userLinkProvider((currentUserId: currentUser.id, otherUserId: callerId)),
    );
    final commonGroupsAsync = ref.watch(
      commonGroupsProvider((currentUserId: currentUser.id, otherUserId: callerId)),
    );

    return linkAsync.when(
      data: (linkType) {
        // If there's a link (friend or message exchange), don't show warning
        if (linkType != UserLinkType.none) {
          return const SizedBox.shrink();
        }

        // No link - show warning
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              // Warning banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppIcon(AppIcon.warning,
                      color: Colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        l10n.callerNotInContacts,
                        style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),

              // Common groups
              commonGroupsAsync.when(
                data: (groups) {
                  if (groups.isEmpty) return const SizedBox.shrink();
                  return _buildCommonGroupsWidget(l10n, groups);
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildCommonGroupsWidget(AppLocalizations l10n, List<GroupEntity> groups) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppIcon(
              AppIcon.groups,
              color: Colors.white70,
              size: 16,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '${l10n.commonGroups}: ${groups.map((g) => g.name).take(2).join(', ')}${groups.length > 2 ? '...' : ''}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final Widget icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onPressed,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: icon,
          ),
        ),
        const SizedBox(height: 12),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
      ],
    );
  }
}
