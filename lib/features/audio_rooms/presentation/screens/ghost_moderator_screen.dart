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
class GhostModeratorScreen extends ConsumerWidget {
  final String roomId;

  const GhostModeratorScreen({super.key, required this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final session = ref.watch(audioRoomSessionProvider);
    final room = session.room;

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
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: DNColors.terra,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              l10n.ghostSuperAdminBadge,
                              style: DNText.mono(size: 9, color: DNColors.paper),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        room?.title ?? 'Salon audio',
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
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      childAspectRatio: 1.8,
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
                          label: l10n.ghostReports,
                          value: '0',
                          color: DNColors.danger,
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
                            context,
                            ref,
                            action: _GhostModAction.mute,
                          ),
                        ),
                        _GhostAction(
                          label: '👢 ${l10n.ghostExclude}',
                          color: DNColors.ink2,
                          onTap: () => _pickAndApply(
                            context,
                            ref,
                            action: _GhostModAction.kick,
                          ),
                        ),
                        _GhostAction(
                          label: '🚫 ${l10n.ghostBlockGlobal}',
                          color: DNColors.danger.withValues(alpha: 0.8),
                          onTap: () => _pickAndApply(
                            context,
                            ref,
                            action: _GhostModAction.block,
                          ),
                        ),
                        _GhostAction(
                          label: '⚠ ${l10n.audioRoomWarnLabel}',
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
                      onTap: () => _confirmForceClose(context, ref),
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
  Future<void> _pickAndApply(
    BuildContext context,
    WidgetRef ref, {
    required _GhostModAction action,
  }) async {
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
                      p.role.name,
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

    if (target == null || !context.mounted) return;

    final notifier = ref.read(audioRoomSessionProvider.notifier);
    switch (action) {
      case _GhostModAction.mute:
        await notifier.muteSpeaker(target.userId);
      case _GhostModAction.kick:
        await notifier.kickUser(target.userId);
      case _GhostModAction.block:
        await notifier.blockUser(target.userId);
    }

    if (!context.mounted) return;
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

  Future<void> _confirmForceClose(BuildContext context, WidgetRef ref) async {
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
    if (ok == true && context.mounted) {
      await ref
          .read(audioRoomSessionProvider.notifier)
          .forceEndRoom('Force-closed by admin ghost moderator');
      if (context.mounted) context.pop();
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
            Text(value,
                style: DNText.serif(size: 28, color: color),),
            Text(label, style: DNText.mono(size: 9, color: DNColors.ink3)),
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
