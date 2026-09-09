import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/services/e2ee/e2ee_backup_coordinator.dart';
import '../../../../core/services/e2ee/key_transfer_service.dart';
import '../../../../core/services/e2ee/messaging_e2ee_service.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../../../core/theme/design_kit.dart';
import '../../../../l10n/app_localizations.dart';

/// Nouveau téléphone : affiche le rendez-vous et attend les clés de l'ancien.
///
/// Le QR porte l'identifiant du rendez-vous, le compte visé et une clé
/// AES-256 tirée au sort ici. Elle ne part jamais sur le réseau : c'est ce qui
/// permet au serveur de relayer la charge sans pouvoir la lire.
class KeyTransferReceiveScreen extends ConsumerStatefulWidget {
  const KeyTransferReceiveScreen({super.key});

  @override
  ConsumerState<KeyTransferReceiveScreen> createState() =>
      _KeyTransferReceiveScreenState();
}

enum _ReceiveState { waiting, done, timedOut, corrupted, noSession }

class _KeyTransferReceiveScreenState
    extends ConsumerState<KeyTransferReceiveScreen> {
  KeyTransferInvite? _invite;
  _ReceiveState _state = _ReceiveState.waiting;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      setState(() => _state = _ReceiveState.noSession);
      return;
    }

    final service = ref.read(keyTransferServiceProvider);
    final invite = service.createInvite(userId);
    setState(() {
      _invite = invite;
      _state = _ReceiveState.waiting;
    });

    try {
      final received = await service.awaitAndImport(invite: invite);
      if (!mounted) return;
      if (!received) {
        setState(() => _state = _ReceiveState.timedOut);
        return;
      }
      // Les clés sont en place : démarrer Signal et republier cet appareil,
      // puis rendre la parole aux bandeaux de rappel (la situation a changé).
      await ref.read(messagingE2EEServiceProvider).initialize(userId);
      await ref
          .read(e2eeBackupCoordinatorProvider.notifier)
          .clearSnooze(userId);
      if (!mounted) return;
      setState(() => _state = _ReceiveState.done);
    } on KeyTransferCorrupted {
      if (mounted) setState(() => _state = _ReceiveState.corrupted);
    } on KeyTransferNotAuthenticated {
      if (mounted) setState(() => _state = _ReceiveState.noSession);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final invite = _invite;

    return Scaffold(
      appBar: AppBar(
        // Sortie explicite : la flèche implicite disparaît quand `canPop()` est
        // faux (écran atteint par lien profond ou notification).
        leading: BackButton(
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go('/settings/security/backup'),
        ),
        backgroundColor: context.backgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        title: DesignTitle(l10n.keyTransferReceiveTitle, size: 22),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_state == _ReceiveState.waiting && invite != null) ...[
              DesignBody(l10n.keyTransferReceiveHint),
              const SizedBox(height: 24),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: QrImageView(
                    data: invite.encode(),
                    size: 240,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Flexible(child: Text(l10n.keyTransferWaiting)),
                ],
              ),
            ],
            if (_state != _ReceiveState.waiting) ...[
              _Outcome(state: _state),
              const SizedBox(height: 24),
              if (_state == _ReceiveState.done)
                DesignPrimaryButton(
                  label: l10n.close,
                  onPressed: () => context.canPop()
                      ? context.pop()
                      : context.go('/settings/security/backup'),
                )
              else
                DesignPrimaryButton(
                  label: l10n.keyTransferRetry,
                  onPressed: _start,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Outcome extends StatelessWidget {
  const _Outcome({required this.state});

  final _ReceiveState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final (String message, bool good) = switch (state) {
      _ReceiveState.done => (l10n.keyTransferImported, true),
      _ReceiveState.timedOut => (l10n.keyTransferTimeout, false),
      _ReceiveState.corrupted => (l10n.keyTransferCorrupted, false),
      _ReceiveState.noSession => (l10n.keyTransferNotAuthenticated, false),
      _ReceiveState.waiting => (l10n.keyTransferWaiting, true),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: good
            ? context.successBackgroundColor
            : context.warningBackgroundColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            good ? Icons.check_circle_outline : Icons.error_outline,
            color: good ? context.successColor : context.warningColor,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}
