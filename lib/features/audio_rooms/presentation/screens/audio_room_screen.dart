import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:share_plus/share_plus.dart';

import '../../../../core/services/livekit_service.dart';
import '../../../../core/theme/dn_colors.dart';
import '../../../../core/theme/dn_text.dart';
import '../../../../core/theme/dn_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/audio_room_entity.dart';
import '../../domain/entities/participant_entity.dart';
import '../providers/audio_room_provider.dart';
import '../widgets/_shared/collection_progress_bar.dart';
import '../widgets/_shared/live_dot.dart';
import '../widgets/_shared/listener_grid.dart';
import '../widgets/_shared/mode_chip.dart';
import '../widgets/_shared/speaker_tile.dart';
import '../widgets/_shared/tip_coin_animation.dart';
import '../widgets/send_tip_bottom_sheet.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';

/// /audio-rooms/:roomId — active room with listener / speaker / host / ghost views.
class AudioRoomScreen extends ConsumerStatefulWidget {
  final String roomId;
  final String? roomTitle;

  const AudioRoomScreen({
    super.key,
    required this.roomId,
    this.roomTitle,
  });

  @override
  ConsumerState<AudioRoomScreen> createState() => _AudioRoomScreenState();
}

class _AudioRoomScreenState extends ConsumerState<AudioRoomScreen> {
  AudioRoomSessionNotifier? _sessionNotifier;
  final bool _showTipToast = false;
  final String _tipToastText = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sessionNotifier = ref.read(audioRoomSessionProvider.notifier);
      _sessionNotifier?.joinRoom(widget.roomId);
    });
  }

  @override
  void dispose() {
    Future(() => _sessionNotifier?.leaveRoom());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dn = context.dn;
    final session = ref.watch(audioRoomSessionProvider);
    final currentUser = ref.watch(currentUserAsyncProvider).valueOrNull;
    final room = session.room;

    if (room == null) {
      return Scaffold(
        backgroundColor: dn.surface,
        body: Center(
          child: session.isJoining
              ? const CircularProgressIndicator(color: DNColors.terra)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(widget.roomTitle ?? l10n.audioRoomDefaultTitle,
                        style: DNText.serif(size: 20, color: dn.onSurface),),
                    const SizedBox(height: 8),
                    Text(l10n.audioRoomConnecting,
                        style: DNText.mono(size: 10, color: dn.onSurface3),),
                  ],
                ),
        ),
      );
    }

    final mode = roomModeFrom(room.mode.name);
    final isHost =
        currentUser != null && room.isHost(currentUser.id);
    final isSpeaker =
        currentUser != null && room.isSpeaker(currentUser.id) && !isHost;
    final isGhost = session.isGhostMode;

    return Scaffold(
      body: Container(
        decoration: isGhost
            ? const BoxDecoration(color: DNColors.ink)
            : backgroundForMode(mode, isDark: dn.isDark),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  if (isGhost) _GhostBar(roomId: room.id),

                  // Reconnexion (maquette 3b) : la plomberie LiveKit émettait
                  // déjà l'état, mais rien ne l'affichait — une coupure se
                  // traduisait par un salon silencieux sans explication.
                  const _ConnectionBanner(),

                  _RoomHeader(
                    room: room,
                    mode: mode,
                    isHost: isHost,
                    isSpeaker: isSpeaker,
                    isGhost: isGhost,
                    onLeave: () {
                      ref
                          .read(audioRoomSessionProvider.notifier)
                          .leaveRoom();
                      context.pop();
                    },
                  ),

                  if (mode == RoomMode.ceremony)
                    _ModeBanner(
                      emoji: '💍',
                      label: l10n.ceremonyRoomLabel,
                      color: DNColors.terra,
                    )
                  else if (mode == RoomMode.heritage)
                    _ModeBanner(
                      emoji: '📚',
                      label:
                          'Patrimoine · ${room.heritageLanguage ?? 'Langue locale'} · ${room.heritageRegion ?? ''}',
                      color: DNColors.ochre,
                    ),

                  if ((isHost || isSpeaker) && room.hasActiveCollection)
                    CollectionProgressBar(
                      current: room.collectionAmount / 100,
                      goal: (room.collectionGoal ?? 0) / 100,
                      beneficiary: room.collectionBeneficiary ?? '',
                      contributors: 0,
                    ),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SpeakersSection(
                            session: session,
                            room: room,
                            currentUserId: currentUser?.id,
                            isHost: isHost,
                            isVideoEnabled: room.isVideoEnabled,
                          ),

                          const SizedBox(height: 14),

                          _ListenersSection(session: session),

                          if ((isHost || isSpeaker) &&
                              session.handRaised.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            _HandRaisedSection(
                              raised: session.handRaised,
                              isHost: isHost,
                              onInvite: (userId) => ref
                                  .read(audioRoomSessionProvider.notifier)
                                  .promoteToSpeaker(userId),
                              onDismiss: (userId) => ref
                                  .read(audioRoomSessionProvider.notifier)
                                  .lowerHand(),
                            ),
                          ],

                          if (isHost) ...[
                            const SizedBox(height: 14),
                            _ModerationPanel(
                              session: session,
                              room: room,
                              currentUserId: currentUser.id,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              if (_showTipToast)
                Positioned(
                  bottom: 80,
                  left: 14,
                  right: 14,
                  child: _TipToast(text: _tipToastText),
                ),

              if (_showTipToast) ...[
                const TipCoinAnimation(x: 40, delayMs: 0),
                const TipCoinAnimation(x: 120, delayMs: 200),
                const TipCoinAnimation(x: 80, delayMs: 400),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: _RoomFooter(
        isHost: isHost,
        isSpeaker: isSpeaker,
        isGhost: isGhost,
        isMuted: session.isMuted,
        isCameraOff: session.isCameraOff,
        room: room,
        currentUserId: currentUser?.id ?? '',
        onMute: () =>
            ref.read(audioRoomSessionProvider.notifier).toggleMute(),
        onCamera: () =>
            ref.read(audioRoomSessionProvider.notifier).toggleCamera(),
        onHand: () {
          final p = session.participants
              .where((p) => p.userId == currentUser?.id)
              .firstOrNull;
          if (p?.hasHandRaised == true) {
            ref.read(audioRoomSessionProvider.notifier).lowerHand();
          } else {
            ref.read(audioRoomSessionProvider.notifier).raiseHand();
          }
        },
        onTip: () {
          final target = session.speakers.firstOrNull;
          if (target != null) {
            SendTipBottomSheet.show(
              context,
              roomId: room.id,
              recipient: target,
              roomTitle: room.title,
            );
          }
        },
        onShare: () => SharePlus.instance.share(
          ShareParams(text: 'Rejoins "${room.title}" sur Diaspo Niger !'),
        ),
        onLeave: () {
          ref.read(audioRoomSessionProvider.notifier).leaveRoom();
          context.pop();
        },
        onEnd: () => _confirmEnd(context),
      ),
    );
  }

  Future<void> _confirmEnd(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final dn = context.dn;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: dn.surface,
        title: Text(l10n.audioRoomEndConfirmTitle,
            style: DNText.serif(size: 18, color: dn.onSurface),),
        content: Text(
          l10n.audioRoomEndConfirmMessage,
          style: DNText.sans(size: 13, color: dn.onSurface2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel,
                style: DNText.sans(color: dn.onSurface3),),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.audioRoomEndLabel,
                style: DNText.sans(color: DNColors.danger, w: FontWeight.w600),),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      ref.read(audioRoomSessionProvider.notifier).leaveRoom();
      context.pop();
    }
  }
}

// ─── Ghost bar ────────────────────────────────────────────────────────────────

/// Bandeau d'état de la connexion audio (maquette 3b).
///
/// Invisible tant que la connexion tient — il n'apparaît que pendant une
/// reconnexion ou après une coupure, avec dans ce dernier cas un bouton qui
/// redemande réellement un jeton et rejoint le SFU.
class _ConnectionBanner extends ConsumerWidget {
  const _ConnectionBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(audioRoomConnectionProvider).valueOrNull;

    if (state == null ||
        state == LiveKitRoomState.connected ||
        state == LiveKitRoomState.connecting) {
      return const SizedBox.shrink();
    }

    final isReconnecting = state == LiveKitRoomState.reconnecting;
    final color = isReconnecting ? DNColors.ochre : DNColors.danger;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          if (isReconnecting)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          else
            Icon(Icons.cloud_off_rounded, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isReconnecting
                      ? l10n.audioRoomReconnecting
                      : l10n.audioRoomAudioLost,
                  style: DNText.sans(size: 13, w: FontWeight.w600, color: color),
                ),
                Text(
                  isReconnecting
                      ? l10n.audioRoomReconnectingHint
                      : l10n.audioRoomAudioLostHint,
                  style: DNText.mono(size: 9, color: color),
                ),
              ],
            ),
          ),
          if (!isReconnecting)
            TextButton(
              onPressed: () => ref
                  .read(audioRoomSessionProvider.notifier)
                  .retryAudioConnection(),
              child: Text(
                l10n.retry,
                style: DNText.sans(size: 12, w: FontWeight.w600, color: color),
              ),
            ),
        ],
      ),
    );
  }
}

class _GhostBar extends StatelessWidget {
  final String roomId;

  const _GhostBar({required this.roomId});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      color: const Color(0xFF2A1A0A),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          const Text('👁', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(
            l10n.audioRoomGhostMode,
            style: DNText.mono(size: 9, color: DNColors.paper),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: DNColors.terra,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(l10n.audioRoomSuperAdmin,
                style: DNText.mono(size: 8, color: DNColors.paper),),
          ),
        ],
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _RoomHeader extends StatelessWidget {
  final AudioRoomEntity room;
  final RoomMode mode;
  final bool isHost;
  final bool isSpeaker;
  final bool isGhost;
  final VoidCallback onLeave;

  const _RoomHeader({
    required this.room,
    required this.mode,
    required this.isHost,
    required this.isSpeaker,
    required this.isGhost,
    required this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dn = context.dn;
    final textColor = isGhost || mode == RoomMode.radio
        ? DNColors.paper
        : dn.onSurface;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 6),
      child: Row(
        children: [
          IconButton(
            icon: AppIcon(AppIcon.arrowBack, color: textColor, size: 20),
            onPressed: onLeave,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const LiveDot(),
                    const SizedBox(width: 5),
                    Text(
                      l10n.audioRoomListenersCount(room.listenerCount),
                      style: DNText.mono(size: 9, color: DNColors.terra),
                    ),
                  ],
                ),
                Text(
                  room.title,
                  style: DNText.serif(size: 15, color: textColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (isHost)
            const _RolePill('HOST', DNColors.terra, DNColors.paper)
          else if (isSpeaker)
            const _RolePill('SPEAKER', DNColors.leaf, DNColors.paper)
          else if (isGhost)
            const _RolePill('GHOST', DNColors.terra, DNColors.paper),
          const SizedBox(width: 4),
          ModeChip(mode: mode),
        ],
      ),
    );
  }
}

class _RolePill extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;

  const _RolePill(this.label, this.bg, this.fg);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(label, style: DNText.mono(size: 8, color: fg)),
      );
}

// ─── Mode banner ──────────────────────────────────────────────────────────────

class _ModeBanner extends StatelessWidget {
  final String emoji;
  final String label;
  final Color color;

  const _ModeBanner({
    required this.emoji,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(8),
          color: color.withValues(alpha: 0.07),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label,
                  style: DNText.mono(size: 9, color: context.dn.onSurface2),),
            ),
          ],
        ),
      );
}

// ─── Speakers section ─────────────────────────────────────────────────────────

class _SpeakersSection extends StatelessWidget {
  final AudioRoomSessionState session;
  final AudioRoomEntity room;
  final String? currentUserId;
  final bool isHost;
  final bool isVideoEnabled;

  const _SpeakersSection({
    required this.session,
    required this.room,
    required this.currentUserId,
    required this.isHost,
    required this.isVideoEnabled,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final speakers = session.visibleSpeakers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.audioRoomParticipantsOnStage(speakers.length, room.maxSpeakers),
          style: DNText.mono(size: 9, color: context.dn.onSurface3),
        ),
        const SizedBox(height: 8),
        isVideoEnabled
            ? StreamBuilder<List<lk.RemoteParticipant>>(
                stream: LiveKitService.instance.participantsStream,
                builder: (context, snapshot) {
                  final remotePeers = snapshot.data ?? [];
                  final localPeer = LiveKitService.instance.localParticipant;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 1,
                    ),
                    itemCount: speakers.length,
                    itemBuilder: (_, i) {
                      final p = speakers[i];
                      lk.VideoTrack? videoTrack;
                      if (p.isCameraOn) {
                        if (p.userId == currentUserId && localPeer != null) {
                          videoTrack = localPeer.videoTrackPublications
                              .where(
                                (pub) => pub.source == lk.TrackSource.camera,
                              )
                              .firstOrNull
                              ?.track as lk.VideoTrack?;
                        } else {
                          final peer = remotePeers
                              .where((r) => r.identity == p.userId)
                              .firstOrNull;
                          videoTrack = peer?.videoTrackPublications
                              .where(
                                (pub) => pub.source == lk.TrackSource.camera,
                              )
                              .firstOrNull
                              ?.track as lk.VideoTrack?;
                        }
                      }
                      return SpeakerTile(
                        name: p.userName,
                        role: p.roleLabel,
                        mic: !p.isMuted,
                        video: true,
                        host: p.role == ParticipantRole.host,
                        talking: false,
                        size: 88,
                        videoTrack: videoTrack,
                      );
                    },
                  );
                },
              )
            : Wrap(
                spacing: 12,
                runSpacing: 12,
                children: speakers.map((p) {
                  return SpeakerTile(
                    name: p.userName,
                    role: p.roleLabel,
                    mic: !p.isMuted,
                    host: p.role == ParticipantRole.host,
                    talking: false,
                    size: 52,
                  );
                }).toList(),
              ),
      ],
    );
  }
}

// ─── Listeners section ────────────────────────────────────────────────────────

class _ListenersSection extends StatelessWidget {
  final AudioRoomSessionState session;

  const _ListenersSection({required this.session});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dn = context.dn;
    final listeners = session.visibleListeners;
    final handCount = session.handRaised.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(l10n.audioRoomListenersCount(listeners.length),
                style: DNText.mono(size: 9, color: dn.onSurface3),),
            if (handCount > 0) ...[
              const SizedBox(width: 8),
              Text(
                '+ $handCount mains levées ✋',
                style: DNText.mono(size: 9, color: DNColors.terra),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        ListenerGrid(
          names: listeners.map((p) => p.userName).toList(),
          totalCount: listeners.length,
        ),
      ],
    );
  }
}

// ─── Hand-raised section ──────────────────────────────────────────────────────

class _HandRaisedSection extends StatelessWidget {
  final List<ParticipantEntity> raised;
  final bool isHost;
  final ValueChanged<String> onInvite;
  final ValueChanged<String> onDismiss;

  const _HandRaisedSection({
    required this.raised,
    required this.isHost,
    required this.onInvite,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dn = context.dn;
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.audioRoomHandsRaisedSection(raised.length),
              style: DNText.mono(size: 9, color: DNColors.terra),),
          const SizedBox(height: 6),
          ...raised.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                          color: dn.surfaceVariant, shape: BoxShape.circle,),
                      alignment: Alignment.center,
                      child: Text(
                        p.userName.isEmpty ? '?' : p.userName[0],
                        style: DNText.mono(size: 9, color: dn.onSurface2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(p.userName,
                            style: DNText.sans(size: 12, color: dn.onSurface),),),
                    if (isHost) ...[
                      _ActionBtn(
                        label: '↑ ${l10n.audioRoomInviteLabel}',
                        bg: DNColors.terra,
                        fg: DNColors.paper,
                        onTap: () => onInvite(p.userId),
                      ),
                      const SizedBox(width: 6),
                      _ActionBtn(
                        label: '✕',
                        bg: dn.surface2,
                        fg: dn.onSurface3,
                        onTap: () => onDismiss(p.userId),
                      ),
                    ],
                  ],
                ),
              ),),
        ],
      );
  }
}

// ─── Moderation panel (host) ──────────────────────────────────────────────────

class _ModerationPanel extends ConsumerStatefulWidget {
  final AudioRoomSessionState session;
  final AudioRoomEntity room;
  final String currentUserId;

  const _ModerationPanel({
    required this.session,
    required this.room,
    required this.currentUserId,
  });

  @override
  ConsumerState<_ModerationPanel> createState() => _ModerationPanelState();
}

class _ModerationPanelState extends ConsumerState<_ModerationPanel> {
  ParticipantEntity? _selected;

  @override
  Widget build(BuildContext context) {
    if (_selected != null) {
      return _SelectedUserCard(
        participant: _selected!,
        onClose: () => setState(() => _selected = null),
        onCoHost: () => ref
            .read(audioRoomSessionProvider.notifier)
            .addCoHost(_selected!.userId),
        onMute: () => ref
            .read(audioRoomSessionProvider.notifier)
            .muteSpeaker(_selected!.userId),
        onDemote: () => ref
            .read(audioRoomSessionProvider.notifier)
            .demoteToListener(_selected!.userId),
        onKick: () => ref
            .read(audioRoomSessionProvider.notifier)
            .kickUser(_selected!.userId),
        onBlock: () => ref
            .read(audioRoomSessionProvider.notifier)
            .blockUser(_selected!.userId),
      );
    }

    final l10n = AppLocalizations.of(context)!;
    final dn = context.dn;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.audioRoomModerators,
            style: DNText.mono(size: 9, color: dn.onSurface3),),
        const SizedBox(height: 6),
        Row(
          children: [
            ...widget.room.moderatorIds.take(3).map((id) => Container(
                  width: 28,
                  height: 28,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                      color: dn.surfaceVariant, shape: BoxShape.circle,),
                  alignment: Alignment.center,
                  child: Text(l10n.moderatorInitialLabel,
                      style: DNText.mono(size: 9, color: dn.onSurface2),),
                ),),
            GestureDetector(
              onTap: () {},
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  border: Border.all(color: dn.onSurface4),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('+ ${l10n.audioRoomInviteLabel}',
                    style: DNText.mono(size: 9, color: dn.onSurface3),),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: DNColors.terra.withValues(alpha: dn.isDark ? 0.15 : 0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: DNColors.terra.withValues(alpha: 0.2),),
          ),
          child: Text(
            '⚠ Règles backend : ban 24h · kick permanent · actions loggées.',
            style: DNText.mono(size: 8, color: dn.onSurface2),
          ),
        ),
      ],
    );
  }
}

class _SelectedUserCard extends StatelessWidget {
  final ParticipantEntity participant;
  final VoidCallback onClose;
  final VoidCallback? onCoHost;
  final VoidCallback? onMute;
  final VoidCallback? onDemote;
  final VoidCallback? onKick;
  final VoidCallback? onBlock;

  const _SelectedUserCard({
    required this.participant,
    required this.onClose,
    this.onCoHost,
    this.onMute,
    this.onDemote,
    this.onKick,
    this.onBlock,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dn = context.dn;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: DNColors.terra, width: 1.5),
        borderRadius: BorderRadius.circular(10),
        color: dn.surface,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                    color: dn.surfaceVariant, shape: BoxShape.circle,),
                alignment: Alignment.center,
                child: Text(
                  participant.userName.isEmpty
                      ? '?'
                      : participant.userName[0],
                  style: DNText.serif(size: 20, color: dn.onSurface),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(participant.userName,
                        style: DNText.sans(
                            size: 13, w: FontWeight.w600, color: dn.onSurface,),),
                    Text(
                      '${participant.roleLabel} · 🎙 ${participant.isMuted ? 'muet' : 'actif'}',
                      style: DNText.mono(size: 9, color: dn.onSurface3),
                    ),
                  ],
                ),
              ),
              IconButton(
                  icon: AppIcon(AppIcon.close, size: 18, color: dn.onSurface3),
                  onPressed: onClose,),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            childAspectRatio: 2.5,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            children: [
              _ActionBtn(
                  label: '↑ ${l10n.audioRoomCoHostLabel}',
                  bg: DNColors.terra,
                  fg: DNColors.paper,
                  onTap: onCoHost,),
              _ActionBtn(
                  label: '🔇 ${l10n.audioRoomMuteAction}',
                  bg: dn.surface2,
                  fg: dn.onSurface,
                  onTap: onMute,),
              _ActionBtn(
                  label: '↓ ${l10n.audioRoomGoDownLabel}',
                  bg: dn.surface2,
                  fg: dn.onSurface,
                  onTap: onDemote,),
              _ActionBtn(
                  label: '👢 ${l10n.audioRoomKickLabel}',
                  bg: DNColors.danger,
                  fg: DNColors.paper,
                  onTap: onKick,),
              _ActionBtn(
                  label: '🚫 ${l10n.audioRoomBlockLabel}',
                  bg: DNColors.danger,
                  fg: DNColors.paper,
                  onTap: onBlock,),
              _ActionBtn(
                  label: '⚠ ${l10n.audioRoomWarnLabel}',
                  bg: DNColors.ochre,
                  fg: DNColors.paper,
                  onTap: null,),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Footer ───────────────────────────────────────────────────────────────────

class _RoomFooter extends StatelessWidget {
  final bool isHost;
  final bool isSpeaker;
  final bool isGhost;
  final bool isMuted;
  final bool isCameraOff;
  final AudioRoomEntity room;
  final String currentUserId;
  final VoidCallback onMute;
  final VoidCallback onCamera;
  final VoidCallback onHand;
  final VoidCallback onTip;
  final VoidCallback onShare;
  final VoidCallback onLeave;
  final VoidCallback onEnd;

  const _RoomFooter({
    required this.isHost,
    required this.isSpeaker,
    required this.isGhost,
    required this.isMuted,
    required this.isCameraOff,
    required this.room,
    required this.currentUserId,
    required this.onMute,
    required this.onCamera,
    required this.onHand,
    required this.onTip,
    required this.onShare,
    required this.onLeave,
    required this.onEnd,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dn = context.dn;
    final bg = isGhost ? DNColors.ink2 : dn.surface2;
    if (isHost) {
      return _Footer(bg: bg, children: [
        _FootBtn(
          label: isMuted ? '🔇' : '🎙',
          sublabel: isMuted ? l10n.audioRoomMuteLabel : l10n.audioRoomActiveLabel,
          active: !isMuted,
          onTap: onMute,
        ),
        _FootBtn(label: '⚙', sublabel: l10n.audioRoomSettingsLabel, onTap: () {}),
        _FootBtn(label: '📊', sublabel: l10n.audioRoomStatsLabel, onTap: () {}),
        _FootBtn(
          label: l10n.audioRoomEndLabel,
          sublabel: '',
          danger: true,
          onTap: onEnd,
        ),
      ],);
    }
    if (isSpeaker) {
      return _Footer(bg: bg, children: [
        _FootBtn(
          label: isMuted ? '🔇' : '🎙',
          sublabel: isMuted ? l10n.audioRoomMuteLabel : l10n.audioRoomActiveLabel,
          active: !isMuted,
          onTap: onMute,
        ),
        if (room.isVideoEnabled)
          _FootBtn(
            label: isCameraOff ? '📷' : '📹',
            sublabel: l10n.audioRoomCameraLabel,
            active: !isCameraOff,
            onTap: onCamera,
          ),
        _FootBtn(label: '✋', sublabel: l10n.audioRoomHandLabel, onTap: onHand),
        _FootBtn(
          label: '↓',
          sublabel: l10n.audioRoomGoDownLabel,
          danger: true,
          onTap: onLeave,
        ),
      ],);
    }
    return _Footer(bg: bg, children: [
      _FootBtn(label: '✋', sublabel: l10n.audioRoomHandLabel, onTap: onHand),
      _FootBtn(label: '🪙', sublabel: l10n.audioRoomTipLabel, ochre: true, onTap: onTip),
      _FootBtn(label: '↗', sublabel: l10n.audioRoomShareLabel, onTap: onShare),
      _FootBtn(
          label: l10n.audioRoomLeaveLabel, sublabel: '', danger: true, onTap: onLeave,),
    ],);
  }
}

class _Footer extends StatelessWidget {
  final Color bg;
  final List<Widget> children;

  const _Footer({required this.bg, required this.children});

  @override
  Widget build(BuildContext context) => Container(
        color: bg,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: children,
          ),
        ),
      );
}

class _FootBtn extends StatelessWidget {
  final String label;
  final String sublabel;
  final bool active;
  final bool danger;
  final bool ochre;
  final VoidCallback? onTap;

  const _FootBtn({
    required this.label,
    required this.sublabel,
    this.active = false,
    this.danger = false,
    this.ochre = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dn = context.dn;
    final bg = danger
        ? DNColors.danger
        : ochre
            ? DNColors.ochre
            : active
                ? DNColors.terra
                : dn.surface2;
    final fg = (danger || ochre || active) ? DNColors.paper : dn.onSurface;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(fontSize: 16, color: fg)),
            if (sublabel.isNotEmpty)
              Text(sublabel, style: DNText.mono(size: 8, color: fg)),
          ],
        ),
      ),
    );
  }
}

// ─── Tip toast ────────────────────────────────────────────────────────────────

class _TipToast extends StatelessWidget {
  final String text;

  const _TipToast({required this.text});

  @override
  Widget build(BuildContext context) {
    final dn = context.dn;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: DNColors.ochre),
        borderRadius: BorderRadius.circular(10),
        color: dn.surface,
      ),
      child: Row(
        children: [
          const Text('🪙', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: DNText.sans(size: 12, color: dn.onSurface)),
          ),
        ],
      ),
    );
  }
}

// ─── Action button ────────────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  final VoidCallback? onTap;

  const _ActionBtn({
    required this.label,
    required this.bg,
    required this.fg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          decoration:
              BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
          child: Text(label,
              style: DNText.mono(size: 9, color: fg),
              textAlign: TextAlign.center,),
        ),
      );
}
