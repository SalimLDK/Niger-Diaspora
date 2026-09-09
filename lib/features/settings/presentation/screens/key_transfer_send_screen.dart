import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/services/e2ee/key_transfer_service.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../../../core/theme/design_kit.dart';
import '../../../../core/utils/screen_brightness_helper.dart';
import '../../../../core/utils/wakelock_helper.dart';
import '../../../../l10n/app_localizations.dart';

/// Ancien téléphone : dépose ses clés chiffrées et affiche le rendez-vous.
///
/// C'est lui qui montre le QR, pas le téléphone neuf — voir l'en-tête de
/// [KeyTransferService] : l'app n'autorise qu'une session par compte, donc se
/// connecter sur le neuf éjecte celui-ci. Le dépôt doit avoir eu lieu avant.
class KeyTransferSendScreen extends ConsumerStatefulWidget {
  const KeyTransferSendScreen({super.key});

  @override
  ConsumerState<KeyTransferSendScreen> createState() =>
      _KeyTransferSendScreenState();
}

enum _SendState { preparing, showing, noKeys, noSession, forgotten }

class _KeyTransferSendScreenState
    extends ConsumerState<KeyTransferSendScreen> {
  final List<KeyTransferInvite> _deposits = [];
  Timer? _rotation;
  _SendState _state = _SendState.preparing;

  @override
  void initState() {
    super.initState();
    // Un QR se scanne d'autant mieux que l'écran est lumineux, et l'écran qui
    // s'éteint au bout de trente secondes oblige à tout recommencer.
    unawaited(ScreenBrightnessHelper.max());
    unawaited(WakelockHelper.enable());
    _start();
  }

  @override
  void dispose() {
    _rotation?.cancel();
    unawaited(ScreenBrightnessHelper.restore());
    unawaited(WakelockHelper.disable());
    // On ne supprime PAS les dépôts en quittant l'écran.
    //
    // Le téléphone neuf scanne pendant que ce code est affiché, mais il ne va
    // chercher la charge qu'APRÈS s'être connecté — connexion qui, elle,
    // déconnecte cet appareil-ci et détruit cet écran. Nettoyer ici
    // supprimerait la ligne juste avant qu'elle serve. C'est `claim` qui
    // l'efface une fois importée, et le trigger de purge au bout d'un quart
    // d'heure sinon.
    super.dispose();
  }

  Future<void> _start() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      setState(() => _state = _SendState.noSession);
      return;
    }

    if (!await _depose(userId)) return;

    _rotation?.cancel();
    _rotation = Timer.periodic(KeyTransferService.rotateEvery, (_) async {
      if (!mounted) return;
      await _depose(userId);
    });
  }

  /// Dépose une charge neuve et n'offre plus que les deux dernières.
  Future<bool> _depose(String userId) async {
    final service = ref.read(keyTransferServiceProvider);
    try {
      final invite = await service.deposit(userId);
      if (!mounted) return false;
      setState(() {
        _deposits.add(invite);
        _state = _SendState.showing;
      });
      final gardes = KeyTransferService.keepValid(_deposits);
      await service.pruneDeposits(userId: userId, keep: gardes);
      return true;
    } on KeyTransferNoKeys {
      if (mounted) setState(() => _state = _SendState.noKeys);
      return false;
    } on KeyTransferNotAuthenticated {
      if (mounted) setState(() => _state = _SendState.noSession);
      return false;
    }
  }

  Future<void> _forgetKeys() async {
    final l10n = AppLocalizations.of(context)!;
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.keyTransferForgetConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.keyTransferForgetAction),
          ),
        ],
      ),
    );
    if (confirme != true) return;

    _rotation?.cancel();
    await ref.read(keyTransferServiceProvider).forgetLocalKeys(userId);
    if (mounted) setState(() => _state = _SendState.forgotten);
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: switch (_state) {
          _SendState.preparing => Padding(
            padding: const EdgeInsets.only(top: 80),
            child: Column(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                Text(l10n.keyTransferDepositing),
              ],
            ),
          ),
          _SendState.showing => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DesignBody(l10n.keyTransferSendHint),
              const SizedBox(height: 24),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: QrImageView(
                    // Clé sur l'identifiant : au renouvellement, Flutter
                    // reconstruit vraiment le code au lieu de réutiliser
                    // l'ancien élément peint.
                    key: ValueKey(_deposits.last.id),
                    data: _deposits.last.encode(),
                    size: 240,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.keyTransferQrRenews,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: context.textSecondaryColor,
                ),
              ),
              const SizedBox(height: 32),
              TextButton(
                onPressed: _forgetKeys,
                child: Text(l10n.keyTransferForgetAction),
              ),
            ],
          ),
          _SendState.noKeys => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Message(
                text: '${l10n.keyTransferNoKeys}\n\n'
                    '${l10n.keyStateAbsentWhy}\n\n'
                    '${l10n.keyStateAbsentHint}',
                good: false,
              ),
              const SizedBox(height: 24),
              DesignPrimaryButton(
                label: l10n.securityBackupTitle,
                onPressed: () => context.canPop()
                    ? context.pop()
                    : context.go('/settings/security/backup'),
              ),
            ],
          ),
          _SendState.noSession => _Message(
            text: l10n.keyTransferNotAuthenticated,
            good: false,
          ),
          _SendState.forgotten => _Message(
            text: l10n.keyTransferForgetDone,
            good: true,
          ),
        },
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, required this.good});

  final String text;
  final bool good;

  @override
  Widget build(BuildContext context) {
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
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
