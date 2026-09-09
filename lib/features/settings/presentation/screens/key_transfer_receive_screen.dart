import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/services/e2ee/e2ee_backup_coordinator.dart';
import '../../../../core/services/e2ee/key_transfer_service.dart';
import '../../../../core/services/e2ee/messaging_e2ee_service.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../../../core/theme/design_kit.dart';
import '../../../../l10n/app_localizations.dart';

/// Téléphone neuf : scanne le code affiché par l'ancien.
///
/// **Cet écran doit fonctionner sans session.** L'app n'autorise qu'une session
/// par compte : se connecter ici éjecte l'ancien téléphone, qui ne pourrait
/// alors plus rien déposer. On scanne donc d'abord, on retient le rendez-vous,
/// et `E2EEBackupCoordinator` le reprend juste après la connexion.
///
/// Quand la session est déjà là (l'ancien téléphone a été déconnecté
/// autrement), la reprise se fait tout de suite, sans repasser par la connexion.
class KeyTransferReceiveScreen extends ConsumerStatefulWidget {
  const KeyTransferReceiveScreen({super.key});

  @override
  ConsumerState<KeyTransferReceiveScreen> createState() =>
      _KeyTransferReceiveScreenState();
}

enum _ReceiveState { scanning, claiming, done, signInNeeded, wrongAccount, expired, corrupted }

class _KeyTransferReceiveScreenState
    extends ConsumerState<KeyTransferReceiveScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    returnImage: false,
  );

  _ReceiveState _state = _ReceiveState.scanning;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_state != _ReceiveState.scanning) return;

    KeyTransferInvite? invite;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value == null) continue;
      invite = KeyTransferInvite.tryParse(value);
      if (invite != null) break;
    }
    // Un QR de partage de profil, ou celui du voisin : on continue à scanner
    // plutôt que d'afficher une erreur à chaque code qui passe.
    if (invite == null) return;

    await _controller.stop();
    if (!mounted) return;
    await _handle(invite);
  }

  Future<void> _handle(KeyTransferInvite invite) async {
    final service = ref.read(keyTransferServiceProvider);
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      // Pas encore connecté : on retient le rendez-vous, la reprise se fera au
      // démarrage E2EE juste après la connexion.
      await service.rememberPending(invite);
      if (mounted) setState(() => _state = _ReceiveState.signInNeeded);
      return;
    }

    if (userId != invite.userId) {
      if (mounted) setState(() => _state = _ReceiveState.wrongAccount);
      return;
    }

    setState(() => _state = _ReceiveState.claiming);
    try {
      await service.claim(invite: invite, userId: userId);
      await ref.read(messagingE2EEServiceProvider).initialize(userId);
      await ref
          .read(e2eeBackupCoordinatorProvider.notifier)
          .clearSnooze(userId);
      if (mounted) setState(() => _state = _ReceiveState.done);
    } on KeyTransferExpired {
      if (mounted) setState(() => _state = _ReceiveState.expired);
    } on KeyTransferCorrupted {
      if (mounted) setState(() => _state = _ReceiveState.corrupted);
    } on KeyTransferAccountMismatch {
      if (mounted) setState(() => _state = _ReceiveState.wrongAccount);
    } on KeyTransferNotAuthenticated {
      // La session n'était pas prête : on retombe sur le chemin « scanné puis
      // connecté », qui repassera par le coordinateur.
      await service.rememberPending(invite);
      if (mounted) setState(() => _state = _ReceiveState.signInNeeded);
    }
  }

  Future<void> _restart() async {
    setState(() => _state = _ReceiveState.scanning);
    await _controller.start();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go('/auth/login'),
        ),
        backgroundColor: context.backgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        title: DesignTitle(l10n.keyTransferReceiveTitle, size: 22),
      ),
      body: switch (_state) {
        _ReceiveState.scanning => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: DesignBody(l10n.keyTransferScanFirst),
            ),
            Expanded(
              child: MobileScanner(
                controller: _controller,
                onDetect: _onDetect,
              ),
            ),
          ],
        ),
        _ReceiveState.claiming => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                Text(l10n.keyTransferWaiting, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
        _ReceiveState.signInNeeded => _Outcome(
          message: l10n.keyTransferScannedSignIn,
          good: true,
          actionLabel: l10n.keyTransferSignInAction,
          onAction: () => context.go('/auth/login'),
        ),
        _ReceiveState.done => _Outcome(
          message: l10n.keyTransferImported,
          good: true,
          actionLabel: l10n.close,
          onAction: () => context.canPop()
              ? context.pop()
              : context.go('/settings/security/backup'),
        ),
        _ReceiveState.wrongAccount => _Outcome(
          message: l10n.keyTransferWrongAccount,
          good: false,
          actionLabel: l10n.keyTransferRetry,
          onAction: _restart,
        ),
        _ReceiveState.expired => _Outcome(
          message: l10n.keyTransferExpired,
          good: false,
          actionLabel: l10n.keyTransferRetry,
          onAction: _restart,
        ),
        _ReceiveState.corrupted => _Outcome(
          message: l10n.keyTransferCorrupted,
          good: false,
          actionLabel: l10n.keyTransferRetry,
          onAction: _restart,
        ),
      },
    );
  }
}

class _Outcome extends StatelessWidget {
  const _Outcome({
    required this.message,
    required this.good,
    required this.actionLabel,
    required this.onAction,
  });

  final String message;
  final bool good;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
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
          ),
          const SizedBox(height: 24),
          DesignPrimaryButton(label: actionLabel, onPressed: onAction),
        ],
      ),
    );
  }
}
