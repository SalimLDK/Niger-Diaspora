import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/dn_colors.dart';
import '../../../../core/theme/dn_text.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/participant_entity.dart';
import '../providers/audio_room_provider.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';

/// Les trois actions de modération ciblées de la vue fantôme.
enum _GhostModAction { mute, kick, block }

/// /audio-rooms/:roomId/ghost — dark admin view, invisible to room participants.
///
/// L'écran doit ouvrir lui-même la session fantôme : sans
/// [AudioRoomSessionNotifier.joinAsGhostModerator], `state.isGhostMode` reste
/// faux, le bypass `canModerate` du provider ne se déclenche jamais et les
/// trois actions ne trouvent aucun participant à cibler.
class GhostModeratorScreen extends ConsumerStatefulWidget {
  final String roomId;

  const GhostModeratorScreen({super.key, required this.roomId});

  @override
  ConsumerState<GhostModeratorScreen> createState() =>
      _GhostModeratorScreenState();
}

class _GhostModeratorScreenState extends ConsumerState<GhostModeratorScreen> {
  late final AudioRoomSessionNotifier _notifier;

  /// Vrai seulement si c'est cet écran qui a ouvert la session fantôme. Un
  /// admin déjà présent dans le salon ne doit pas en être sorti à la fermeture.
  bool _joinedHere = false;
  bool _joining = true;
  String? _joinError;

  /// La durée du salon est calculée à l'affichage : sans réveil périodique elle
  /// resterait figée à la valeur du premier build.
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _notifier = ref.read(audioRoomSessionProvider.notifier);
    _ticker = Timer.periodic(
      const Duration(seconds: 30),
      (_) => setState(() {}),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _joinAsGhost());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    if (_joinedHere) {
      // Sinon l'admin resterait rattaché au salon (et présent dans
      // moderatorIds) après la fermeture de l'écran.
      _notifier.leaveRoom();
    }
    super.dispose();
  }

  Future<void> _joinAsGhost() async {
    final session = ref.read(audioRoomSessionProvider);

    // Déjà en session fantôme sur ce salon : ne pas rejoindre deux fois.
    if (session.isGhostMode && session.room?.id == widget.roomId) {
      if (mounted) setState(() => _joining = false);
      return;
    }

    final ok = await _notifier.joinAsGhostModerator(widget.roomId);
    if (!mounted) return;
    setState(() {
      _joining = false;
      _joinedHere = ok;
      _joinError = ok ? null : ref.read(audioRoomSessionProvider).error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final session = ref.watch(audioRoomSessionProvider);
    final room = session.room;

    if (_joining) {
      return const Scaffold(
        backgroundColor: DNColors.ink,
        body: Center(
          child: CircularProgressIndicator(color: DNColors.terra),
        ),
      );
    }

    // Salon introuvable, compte non admin, échec réseau : sans ça l'écran
    // s'affichait avec des compteurs à zéro et des actions sans cible.
    if (_joinError != null) {
      return Scaffold(
        backgroundColor: DNColors.ink,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('⚠', style: TextStyle(fontSize: 32)),
                const SizedBox(height: 12),
                Text(
                  _joinError!,
                  textAlign: TextAlign.center,
                  style: DNText.sans(size: 14, color: DNColors.paper),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => context.pop(),
                  child: Text(
                    l10n.cancel,
                    style: DNText.sans(color: DNColors.ochre),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: DNColors.ink,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const AppIcon(AppIcon.arrowBack, color: DNColors.paper, size: 20),
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(width: 4),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // « MODÉRATION · 42:18 » : le rôle et depuis combien de
                      // temps le salon tourne, au lieu d'une pastille qui ne
                      // disait que le rôle.
                      Text(
                        l10n.ghostModerationHeader(
                          room?.startedAt != null
                              ? _elapsed(room!.startedAt!)
                              : '--:--',
                        ),
                        style: DNText.mono(size: 9, color: DNColors.terra),
                      ),
                      Text(
                        room?.title ?? l10n.audioRoomsTitle,
                        style: DNText.serif(size: 16, color: DNColors.paper),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Warning banner
            Container(
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF3A2200),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: DNColors.ochre.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Text('⚠', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 8),
                  Text(
                    l10n.ghostInvisibleNotice,
                    style: DNText.mono(size: 9, color: DNColors.ochre),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 100),
                child: Column(
                  children: [
                    // Live data 2×2 grid
                    // Trois cartes, comme la maquette. La quatrième
                    // (« Signalements ») affichait un `0` codé en dur : rien
                    // ne compte les signalements d'un salon, elle annonçait
                    // donc « aucun problème » sans rien savoir.
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 3,
                      childAspectRatio: 1.15,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      children: [
                        _StatCard(
                          label: l10n.ghostListeners,
                          value: '${session.visibleListeners.length}',
                          color: DNColors.paper,
                        ),
                        _StatCard(
                          label: l10n.ghostSpeakers,
                          value: '${session.visibleSpeakers.length}',
                          color: DNColors.terra,
                        ),
                        _StatCard(
                          label: l10n.ghostDuration,
                          value: room?.startedAt != null
                              ? _elapsed(room!.startedAt!)
                              : '--:--',
                          color: DNColors.ochre,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Ghost action grid
                    Text(
                      l10n.ghostActionsTitle,
                      style: DNText.mono(size: 9, color: DNColors.ink3),
                    ),
                    const SizedBox(height: 8),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      childAspectRatio: 2.2,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      children: [
                        _GhostAction(
                          label: '🔇 ${l10n.ghostMuteSilent}',
                          color: DNColors.ink2,
                          onTap: () => _pickAndApply(
                            action: _GhostModAction.mute,
                          ),
                        ),
                        _GhostAction(
                          label: '👢 ${l10n.ghostExclude}',
                          color: DNColors.ink2,
                          onTap: () => _pickAndApply(
                            action: _GhostModAction.kick,
                          ),
                        ),
                        _GhostAction(
                          label: '🚫 ${l10n.ghostBlockGlobal}',
                          color: DNColors.danger.withValues(alpha: 0.8),
                          onTap: () => _pickAndApply(
                            action: _GhostModAction.block,
                          ),
                        ),
                        _GhostAction(
                          label: '⚠ ${l10n.ghostWarnHost}',
                          color: DNColors.ink2,
                          onTap: () => ref
                              .read(audioRoomSessionProvider.notifier)
                              .warnHost('Avertissement modérateur'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Force close
                    GestureDetector(
                      onTap: _confirmForceClose,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: DNColors.danger,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          AppLocalizations.of(context)!.audioRoomForceCloseLabel,
                          style: DNText.sans(
                              size: 14, w: FontWeight.w600, color: DNColors.paper,),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppLocalizations.of(context)!.audioRoomForceCloseAuditNote,
                      style: DNText.mono(size: 8, color: DNColors.danger),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Les trois actions de modération ciblent un participant : on ouvre la
  /// liste des participants visibles, puis on applique l'action au choix fait.
  Future<void> _pickAndApply({required _GhostModAction action}) async {
    final l10n = AppLocalizations.of(context)!;
    final session = ref.read(audioRoomSessionProvider);
    final targets = [...session.visibleSpeakers, ...session.visibleListeners];

    if (targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.ghostNoParticipants)),
      );
      return;
    }

    final target = await showModalBottomSheet<ParticipantEntity>(
      context: context,
      backgroundColor: DNColors.ink2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                l10n.ghostPickParticipantTitle,
                style: DNText.serif(size: 16, color: DNColors.paper),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: targets.length,
                itemBuilder: (_, i) {
                  final p = targets[i];
                  return ListTile(
                    title: Text(
                      p.userName,
                      style: DNText.sans(size: 14, color: DNColors.paper),
                    ),
                    subtitle: Text(
                      p.roleLabel,
                      style: DNText.mono(size: 9, color: DNColors.ink3),
                    ),
                    onTap: () => Navigator.pop(sheetContext, p),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (target == null || !mounted) return;

    final notifier = ref.read(audioRoomSessionProvider.notifier);
    switch (action) {
      case _GhostModAction.mute:
        await notifier.muteSpeaker(target.userId);
      case _GhostModAction.kick:
        await notifier.kickUser(target.userId);
      case _GhostModAction.block:
        await notifier.blockUser(target.userId);
    }

    if (!mounted) return;
    final error = ref.read(audioRoomSessionProvider).error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error ??
              switch (action) {
                _GhostModAction.mute => l10n.ghostActionMuted(target.userName),
                _GhostModAction.kick => l10n.ghostActionKicked(target.userName),
                _GhostModAction.block =>
                  l10n.ghostActionBlocked(target.userName),
              },
        ),
        backgroundColor: error != null ? DNColors.danger : null,
      ),
    );
  }

  Future<void> _confirmForceClose() async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: DNColors.ink2,
        title: Text(l10n.audioRoomForceCloseTitle,
            style: DNText.serif(size: 18, color: DNColors.paper),),
        content: Text(
          l10n.audioRoomForceCloseDesc,
          style: DNText.sans(size: 13, color: DNColors.ink4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel, style: DNText.sans(color: DNColors.ink3)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.audioRoomForceButton,
                style: DNText.sans(color: DNColors.danger, w: FontWeight.w600),),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await ref
          .read(audioRoomSessionProvider.notifier)
          .forceEndRoom('Force-closed by admin ghost moderator');
      if (mounted) context.pop();
    }
  }

  static String _elapsed(DateTime start) {
    final diff = DateTime.now().difference(start);
    final h = diff.inHours.toString().padLeft(2, '0');
    final m = (diff.inMinutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: DNColors.ink2,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // La valeur rétrécit plutôt que de déborder : les cartes sont
            // plus étroites depuis le passage à trois colonnes.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: DNText.serif(size: 26, color: color)),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: DNText.mono(size: 8, color: DNColors.ink3),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
}

class _GhostAction extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _GhostAction({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: DNText.mono(size: 9, color: DNColors.paper),
            textAlign: TextAlign.center,
          ),
        ),
      );
}
