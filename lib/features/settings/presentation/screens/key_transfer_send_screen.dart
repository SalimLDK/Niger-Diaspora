import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/services/e2ee/key_transfer_service.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../../../core/theme/design_kit.dart';
import '../../../../l10n/app_localizations.dart';

/// Ancien téléphone : lit le QR du nouveau et lui envoie les clés.
///
/// L'appareil n'oublie ses propres clés qu'après l'accusé de réception du
/// nouveau : sans cette confirmation, un import raté laisserait le compte sans
/// aucune copie de l'identité.
class KeyTransferSendScreen extends ConsumerStatefulWidget {
  const KeyTransferSendScreen({super.key});

  @override
  ConsumerState<KeyTransferSendScreen> createState() =>
      _KeyTransferSendScreenState();
}

enum _SendStep { scanning, sending, waitingAck, done, failed }

class _KeyTransferSendScreenState
    extends ConsumerState<KeyTransferSendScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    returnImage: false,
  );

  _SendStep _step = _SendStep.scanning;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_step != _SendStep.scanning) return;

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
    await _transfer(invite);
  }

  Future<void> _transfer(KeyTransferInvite invite) async {
    final l10n = AppLocalizations.of(context)!;
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      _fail(l10n.keyTransferNotAuthenticated);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.keyTransferConfirmTitle),
        content: Text(l10n.keyTransferConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.keyTransferConfirmAction),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      await _controller.start();
      if (mounted) setState(() => _step = _SendStep.scanning);
      return;
    }

    setState(() => _step = _SendStep.sending);
    final service = ref.read(keyTransferServiceProvider);
    try {
      await service.sendKeys(invite: invite, userId: userId);
    } on KeyTransferAccountMismatch {
      _fail(l10n.keyTransferWrongAccount);
      return;
    } on KeyTransferNoKeys {
      _fail(l10n.keyTransferNoKeys);
      return;
    } on KeyTransferNotAuthenticated {
      _fail(l10n.keyTransferNotAuthenticated);
      return;
    }

    if (!mounted) return;
    setState(() => _step = _SendStep.waitingAck);

    final acked = await service.awaitConsumed(invite: invite);
    if (!mounted) return;
    if (!acked) {
      // Les clés restent ici : c'est le cas le moins mauvais, l'appareil neuf
      // pourra retenter avec un code neuf.
      _fail(l10n.keyTransferNoAck);
      return;
    }

    await service.forgetLocalKeys(invite: invite, userId: userId);
    if (mounted) setState(() => _step = _SendStep.done);
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _step = _SendStep.failed;
      _error = message;
    });
  }

  Future<void> _restart() async {
    setState(() {
      _step = _SendStep.scanning;
      _error = null;
    });
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
              : context.go('/settings/security/backup'),
        ),
        backgroundColor: context.backgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        title: DesignTitle(l10n.keyTransferSendTitle, size: 22),
      ),
      body: switch (_step) {
        _SendStep.scanning => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: DesignBody(l10n.keyTransferScanHint),
            ),
            Expanded(
              child: MobileScanner(
                controller: _controller,
                onDetect: _onDetect,
              ),
            ),
          ],
        ),
        _SendStep.sending => _Progress(message: l10n.keyTransferSending),
        _SendStep.waitingAck => _Progress(message: l10n.keyTransferWaitingAck),
        _SendStep.done => _Final(
          message: l10n.keyTransferDone,
          good: true,
          actionLabel: l10n.close,
          onAction: () => context.canPop()
              ? context.pop()
              : context.go('/settings/security/backup'),
        ),
        _SendStep.failed => _Final(
          message: _error ?? l10n.keyTransferNoAck,
          good: false,
          actionLabel: l10n.keyTransferRetry,
          onAction: _restart,
        ),
      },
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _Final extends StatelessWidget {
  const _Final({
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
