import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/pip_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/group_call_entity.dart';
import '../../domain/entities/group_participant_entity.dart';
import '../providers/group_call_provider.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';

/// Screen for group video/audio calls
///
/// Supports both mesh (2-4 participants) and SFU (5+) modes
/// with automatic switching based on participant count.
class GroupCallScreen extends ConsumerStatefulWidget {
  final String callId;
  final bool isInitiator;
  final bool isVideo;
  final List<String>? initialParticipantIds;

  const GroupCallScreen({
    super.key,
    required this.callId,
    this.isInitiator = false,
    this.isVideo = false,
    this.initialParticipantIds,
  });

  @override
  ConsumerState<GroupCallScreen> createState() => _GroupCallScreenState();
}

class _GroupCallScreenState extends ConsumerState<GroupCallScreen>
    with WidgetsBindingObserver {
  final PipService _pipService = PipService.instance;
  bool _showControls = true;
  bool _showQualitySelector = false;
  String? _selectedParticipantId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCall();

    // Enable PiP (Picture-in-Picture) for group calls
    _pipService.setVideoCallActive(active: true, autoPipEnabled: true);
    _pipService.onPipAction = _handlePipAction;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Clean up PiP
    _pipService.onPipAction = null;
    _pipService.setVideoCallActive(active: false);
    super.dispose();
  }

  /// Handle PiP action button clicks (Mute, End Call)
  void _handlePipAction(String action, Map<String, dynamic>? data) {
    if (!mounted) return;
    debugPrint('GroupCallScreen: PiP action received: $action');
    switch (action) {
      case 'mute':
        ref.read(currentGroupCallProvider.notifier).toggleMute();
        final callState = ref.read(currentGroupCallProvider);
        _pipService.updateMuteState(callState.isMuted);
        break;
      case 'endCall':
        _endCall();
        break;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final notifier = ref.read(currentGroupCallProvider.notifier);

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // Disable camera when app goes to background
        notifier.setCameraEnabled(false);
        break;
      case AppLifecycleState.resumed:
        // Re-enable camera if it was on before
        final callState = ref.read(currentGroupCallProvider);
        if (!callState.isCameraOff) {
          notifier.setCameraEnabled(true);
        }
        break;
      default:
        break;
    }
  }

  Future<void> _initializeCall() async {
    final notifier = ref.read(currentGroupCallProvider.notifier);

    if (widget.isInitiator) {
      await notifier.createGroupCall(
        name: 'Group Call ${widget.callId}',
        participantIds: widget.initialParticipantIds ?? [],
        type: widget.isVideo ? GroupCallType.video : GroupCallType.audio,
      );
    } else {
      await notifier.joinGroupCall(
        callId: widget.callId,
        enableVideo: widget.isVideo,
      );
    }
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  void _hideQualitySelector() {
    setState(() {
      _showQualitySelector = false;
      _selectedParticipantId = null;
    });
  }

  Future<void> _endCall() async {
    await ref.read(currentGroupCallProvider.notifier).leaveCall();
    if (mounted) {
      context.pop();
    }
  }

  void _onParticipantTap(GroupParticipantEntity participant) {
    setState(() {
      _selectedParticipantId = participant.oderId;
      _showQualitySelector = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final callState = ref.watch(currentGroupCallProvider);

    // Handle call ended
    if (callState.status == GroupCallStatus.ended) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.pop();
        }
      });
    }

    // Handle errors
    if (callState.error != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const AppIcon(AppIcon.error,
                color: Colors.red,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.groupCallDisconnected,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                callState.error!,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.pop(),
                child: Text(l10n.groupCallLeave),
              ),
            ],
          ),
        ),
      );
    }

    // Loading state
    if (callState.status == GroupCallStatus.waiting &&
        callState.participants.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                color: Colors.white,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.groupCallConnecting,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: GestureDetector(
          onTap: _toggleControls,
          child: Stack(
            children: [
              // Participant grid
              _buildParticipantGrid(callState),

              // Top bar with call info
              AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                top: _showControls ? 0 : -100,
                left: 0,
                right: 0,
                child: _buildTopBar(l10n, callState),
              ),

              // Bottom controls - secondary controls can hide, hangup always visible
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildModernCallControls(l10n, callState),
              ),

              // Quality selector modal
              if (_showQualitySelector && _selectedParticipantId != null)
                _buildQualitySelector(l10n, callState),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildParticipantGrid(GroupCallState callState) {
    final participants = callState.participants;
    final speakingIds = callState.speakingParticipantIds;

    if (participants.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    // Calculate grid layout
    final count = participants.length;
    int crossAxisCount;
    if (count <= 1) {
      crossAxisCount = 1;
    } else if (count <= 4) {
      crossAxisCount = 2;
    } else if (count <= 9) {
      crossAxisCount = 3;
    } else {
      crossAxisCount = 4;
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.82,
      ),
      itemCount: participants.length,
      itemBuilder: (context, index) {
        final participant = participants[index];
        final isSpeaking = speakingIds.contains(participant.oderId);

        return _buildParticipantTile(
          participant,
          isSpeaking: isSpeaking,
          isVideo: callState.isVideo,
          onTap: () => _onParticipantTap(participant),
        );
      },
    );
  }

  Widget _buildParticipantTile(
    GroupParticipantEntity participant, {
    required bool isSpeaking,
    required bool isVideo,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
          // Orateur actif encadré 2 px #32E252 (§12).
          border: isSpeaking
              ? Border.all(color: const Color(0xFF32E252), width: 2)
              : null,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Avatar or video placeholder
            if (participant.isCameraOff || !isVideo)
              Center(
                child: CircleAvatar(
                  radius: 40,
                  backgroundImage: participant.photoUrl != null
                      ? NetworkImage(participant.photoUrl!)
                      : null,
                  child: participant.photoUrl == null
                      ? Text(
                          participant.displayName.isNotEmpty
                              ? participant.displayName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(fontSize: 32),
                        )
                      : null,
                ),
              ),

            // Name and status
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        participant.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  // Badge VIDÉO quand la caméra du participant est active.
                  if (isVideo && !participant.isCameraOff)
                    Container(
                      margin: const EdgeInsets.only(left: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF32E252),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'VIDÉO',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  if (participant.isMuted)
                    Container(
                      margin: const EdgeInsets.only(left: 4),
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.8),
                        shape: BoxShape.circle,
                      ),
                      child: const AppIcon(
                        AppIcon.micOff,
                        color: Colors.white,
                        size: 12,
                      ),
                    ),
                ],
              ),
            ),

            // Host indicator
            if (participant.isHost)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.host,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

            // Hand raised indicator
            if (participant.hasHandRaised)
              const Positioned(
                top: 8,
                right: 8,
                child: Icon(
                  Icons.back_hand,
                  color: Colors.amber,
                  size: 24,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Build WhatsApp-style call controls - single row with hangup in center
  Widget _buildModernCallControls(AppLocalizations l10n, GroupCallState callState) {
    return Container(
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
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 40, 20, 32),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: _buildWhatsAppControls(callState),
          ),
        ),
      ),
    );
  }

  /// Build WhatsApp-style controls: [left] [HANGUP] [right]
  List<Widget> _buildWhatsAppControls(GroupCallState callState) {
    if (callState.isVideo) {
      // Video: Flip | Camera | HANGUP | Mute | ScreenShare
      return [
        _buildWhatsAppButton(
          icon: Icon(
            Icons.cameraswitch_rounded,
            color: Colors.white,
            size: 24,
          ),
          isActive: true,
          onPressed: () => ref.read(currentGroupCallProvider.notifier).switchCamera(),
        ),
        _buildWhatsAppButton(
          icon: AppIcon(
            callState.isCameraOff ? AppIcon.videocamOff : AppIcon.video,
            color: !callState.isCameraOff ? Colors.white : Colors.white60,
            size: 24,
          ),
          isActive: !callState.isCameraOff,
          onPressed: () => ref.read(currentGroupCallProvider.notifier).toggleCamera(),
        ),
        _buildWhatsAppHangupButton(),
        _buildWhatsAppButton(
          icon: AppIcon(
            callState.isMuted ? AppIcon.micOff : AppIcon.mic,
            color: !callState.isMuted ? Colors.white : Colors.white60,
            size: 24,
          ),
          isActive: !callState.isMuted,
          onPressed: () => ref.read(currentGroupCallProvider.notifier).toggleMute(),
        ),
        _buildWhatsAppButton(
          icon: Icon(
            callState.isScreenSharing
                ? Icons.stop_screen_share_rounded
                : Icons.screen_share_rounded,
            color: !callState.isScreenSharing ? Colors.white : Colors.white60,
            size: 24,
          ),
          isActive: !callState.isScreenSharing,
          onPressed: () => ref.read(currentGroupCallProvider.notifier).toggleScreenShare(),
        ),
      ];
    } else {
      // Audio: ScreenShare | (placeholder) | HANGUP | Mute | (placeholder)
      return [
        _buildWhatsAppButton(
          icon: Icon(
            callState.isScreenSharing
                ? Icons.stop_screen_share_rounded
                : Icons.screen_share_rounded,
            color: !callState.isScreenSharing ? Colors.white : Colors.white60,
            size: 24,
          ),
          isActive: !callState.isScreenSharing,
          onPressed: () => ref.read(currentGroupCallProvider.notifier).toggleScreenShare(),
        ),
        const SizedBox(width: 48),
        _buildWhatsAppHangupButton(),
        _buildWhatsAppButton(
          icon: AppIcon(
            callState.isMuted ? AppIcon.micOff : AppIcon.mic,
            color: !callState.isMuted ? Colors.white : Colors.white60,
            size: 24,
          ),
          isActive: !callState.isMuted,
          onPressed: () => ref.read(currentGroupCallProvider.notifier).toggleMute(),
        ),
        const SizedBox(width: 48),
      ];
    }
  }

  /// WhatsApp-style control button (48x48 circle)
  Widget _buildWhatsAppButton({
    required Widget icon,
    required bool isActive,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.15),
        ),
        child: icon,
      ),
    );
  }

  /// WhatsApp-style hangup button (64x64, red, center)
  Widget _buildWhatsAppHangupButton() {
    return GestureDetector(
      onTap: _endCall,
      child: Container(
        width: 64,
        height: 64,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.red,
        ),
        child: const Icon(
          Icons.call_end_rounded,
          color: Colors.white,
          size: 30,
        ),
      ),
    );
  }

  Widget _buildTopBar(AppLocalizations l10n, GroupCallState callState) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.7),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          // Back button
          IconButton(
            icon: const AppIcon(AppIcon.arrowBack, color: Colors.white),
            onPressed: _endCall,
          ),

          const SizedBox(width: 8),

          // Call info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.groupCallTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  l10n.groupCallParticipants(callState.participants.length),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Mode indicator (mesh/SFU)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: callState.mode == GroupCallMode.sfu
                  ? Colors.blue.withValues(alpha: 0.3)
                  : Colors.green.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              callState.mode == GroupCallMode.sfu
                  ? l10n.groupCallSfuMode
                  : l10n.groupCallMeshMode,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
              ),
            ),
          ),

          const SizedBox(width: 8),

          // E2EE indicator
          GestureDetector(
            onTap: () => _showE2EEInfo(l10n, callState),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: callState.isE2EEEnabled
                    ? Colors.green.withValues(alpha: 0.3)
                    : Colors.orange.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: callState.isE2EEEnabled
                  ? const AppIcon(AppIcon.lock, color: Colors.white, size: 16)
                  : const AppIcon(
                      AppIcon.lockOpen,
                      color: Colors.white,
                      size: 16,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQualitySelector(AppLocalizations l10n, GroupCallState callState) {
    final participant = callState.participants
        .where((p) => p.oderId == _selectedParticipantId)
        .firstOrNull;

    if (participant == null) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: _hideQualitySelector,
      child: Container(
        color: Colors.black54,
        child: Center(
          child: GestureDetector(
            onTap: () {}, // Prevent closing when tapping on the modal
            child: Container(
              margin: const EdgeInsets.all(32),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.groupCallVideoQuality,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    participant.displayName,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildQualityOption(
                    l10n.groupCallVideoQualityLow,
                    VideoQuality.low,
                    participant.videoQuality,
                    l10n,
                  ),
                  _buildQualityOption(
                    l10n.groupCallVideoQualityMedium,
                    VideoQuality.medium,
                    participant.videoQuality,
                    l10n,
                  ),
                  _buildQualityOption(
                    l10n.groupCallVideoQualityHigh,
                    VideoQuality.high,
                    participant.videoQuality,
                    l10n,
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _hideQualitySelector,
                    child: Text(l10n.cancel),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQualityOption(
    String label,
    VideoQuality quality,
    VideoQuality currentQuality,
    AppLocalizations l10n,
  ) {
    final isSelected = quality == currentQuality;

    return ListTile(
      leading: isSelected
          ? const AppIcon(AppIcon.checkCircle, color: Colors.green)
          : const AppIcon(AppIcon.circleOutline, color: Colors.white54),
      title: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      onTap: () {
        ref.read(currentGroupCallProvider.notifier).setVideoQuality(
              _selectedParticipantId!,
              quality,
            );
        _hideQualitySelector();
      },
    );
  }

  void _showE2EEInfo(AppLocalizations l10n, GroupCallState callState) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.groupCallE2eeVerify),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                callState.isE2EEEnabled
                    ? const AppIcon(AppIcon.lock, color: Colors.green)
                    : const AppIcon(AppIcon.lockOpen, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    callState.isE2EEEnabled
                        ? l10n.groupCallE2eeEnabled
                        : l10n.groupCallE2eeDisabled,
                  ),
                ),
              ],
            ),
            if (callState.isE2EEEnabled &&
                callState.e2eeVerificationCode != null) ...[
              const SizedBox(height: 16),
              Text(l10n.groupCallE2eeVerifyHint),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  callState.e2eeVerificationCode!,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }
}
