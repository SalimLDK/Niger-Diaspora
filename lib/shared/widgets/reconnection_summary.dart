import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/offline_sync_service.dart';
import '../../core/theme/adaptive_colors.dart';
import '../../features/messages/presentation/providers/message_provider.dart';
import '../../features/notifications/presentation/providers/notification_provider.dart';
import '../../l10n/app_localizations.dart';

/// Monte l'écoute des reprises de connexion et présente le bilan (maquette 3b).
///
/// À placer une seule fois, au-dessus du routeur : la reprise peut survenir
/// sur n'importe quel écran.
class ReconnectionWatcher extends ConsumerStatefulWidget {
  final Widget child;

  const ReconnectionWatcher({super.key, required this.child});

  @override
  ConsumerState<ReconnectionWatcher> createState() =>
      _ReconnectionWatcherState();
}

class _ReconnectionWatcherState extends ConsumerState<ReconnectionWatcher> {
  StreamSubscription<ReconnectionReport>? _sub;

  /// Évite d'empiler deux feuilles si deux synchronisations se suivent.
  bool _isShowing = false;

  @override
  void initState() {
    super.initState();
    _sub = OfflineSyncService.instance.reconnectionStream.listen(_onReport);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _onReport(ReconnectionReport report) async {
    if (!mounted || _isShowing) return;
    _isShowing = true;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReconnectionSummarySheet(report: report),
    );
    _isShowing = false;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Bilan d'une reprise : ce qui est parti, ce qui a été perdu, ce qui est
/// arrivé pendant l'absence.
class ReconnectionSummarySheet extends ConsumerWidget {
  final ReconnectionReport report;

  const ReconnectionSummarySheet({super.key, required this.report});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final unreadMessages = ref.watch(totalUnreadCountProvider);
    final unreadNotifs = ref.watch(unreadNotificationsCountProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Icon(Icons.cloud_done_rounded,
                    size: 22, color: context.successColor,),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.reconnectedTitle,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: context.textPrimaryColor,
                        ),
                      ),
                      if (report.outageDuration != null)
                        Text(
                          l10n.reconnectedAfter(
                              _formatDuration(report.outageDuration!),),
                          style: TextStyle(
                            fontSize: 12,
                            color: context.textTertiaryColor,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            // L'abandon est la seule issue irrattrapable : il passe avant
            // tout le reste.
            if (report.abandonedCount > 0) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.errorBackgroundColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 18, color: context.errorColor,),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.reconnectedAbandonedWarning(
                            report.abandonedCount,),
                        style: TextStyle(
                          fontSize: 12.5,
                          color: context.textPrimaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 22),
            _SectionLabel(l10n.reconnectedSentSection),
            const SizedBox(height: 6),
            ...report.actions.map((a) => _ActionRow(action: a)),

            const SizedBox(height: 22),
            _SectionLabel(l10n.reconnectedReceivedSection),
            const SizedBox(height: 6),
            if (unreadMessages == 0 && unreadNotifs == 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  l10n.reconnectedNothingReceived,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.textSecondaryColor,
                  ),
                ),
              )
            else ...[
              if (unreadMessages > 0)
                _ReceivedRow(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: l10n.reconnectedUnreadMessages(unreadMessages),
                ),
              if (unreadNotifs > 0)
                _ReceivedRow(
                  icon: Icons.notifications_none_rounded,
                  label: l10n.reconnectedUnreadNotifications(unreadNotifs),
                ),
            ],

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.close),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDuration(Duration d) {
    if (d.inHours >= 1) return '${d.inHours} h ${d.inMinutes % 60} min';
    if (d.inMinutes >= 1) return '${d.inMinutes} min';
    return '${d.inSeconds} s';
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: context.textTertiaryColor,
        ),
      );
}

class _ActionRow extends StatelessWidget {
  final SyncedActionReport action;

  const _ActionRow({required this.action});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final (icon, color, label) = switch (action.outcome) {
      SyncOutcome.sent => (
          Icons.check_circle_outline_rounded,
          context.successColor,
          l10n.reconnectedOutcomeSent,
        ),
      SyncOutcome.retrying => (
          Icons.schedule_rounded,
          context.warningColor,
          l10n.reconnectedOutcomeRetrying,
        ),
      SyncOutcome.abandoned => (
          Icons.cancel_outlined,
          context.errorColor,
          l10n.reconnectedOutcomeAbandoned,
        ),
    };

    final what = switch (action.actionType) {
      OfflineActionType.create => l10n.reconnectedActionCreate,
      OfflineActionType.update => l10n.reconnectedActionUpdate,
      OfflineActionType.delete => l10n.reconnectedActionDelete,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              // La collection est le seul libellé disponible : la file
              // d'attente ne stocke pas de titre lisible par un humain.
              '$what · ${action.collection}',
              style: TextStyle(fontSize: 13, color: context.textPrimaryColor),
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 11.5, color: color),
          ),
        ],
      ),
    );
  }
}

class _ReceivedRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ReceivedRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Icon(icon, size: 17, color: context.textTertiaryColor),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(fontSize: 13, color: context.textPrimaryColor),
            ),
          ],
        ),
      );
}
