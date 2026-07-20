import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/e2ee/message_crypto_service.dart';
import '../../../../core/services/e2ee/sender_key_service.dart';
import '../../../../core/theme/adaptive_colors.dart';

/// Shown inside a message bubble when E2EE decryption failed because no
/// Signal session (1:1) or Sender Key (group) exists on this device.
///
/// For 1:1 conversations: re-establishes the Signal session via X3DH.
/// For group conversations: fetches any missed Sender Key distributions
/// from Firestore.  In both cases the original ciphertext cannot be
/// decrypted retroactively — the user must ask the sender to resend.
class E2EESessionRequiredBubble extends ConsumerStatefulWidget {
  final String senderId;
  final bool isSentByMe;
  /// Non-null for group conversations: the group's Sender Key ID used in
  /// [SenderKeyService.fetchPendingDistributions].
  final String? groupId;

  const E2EESessionRequiredBubble({
    super.key,
    required this.senderId,
    required this.isSentByMe,
    this.groupId,
  });

  @override
  ConsumerState<E2EESessionRequiredBubble> createState() =>
      _E2EESessionRequiredBubbleState();
}

class _E2EESessionRequiredBubbleState
    extends ConsumerState<E2EESessionRequiredBubble> {
  bool _loading = false;
  bool _done = false;
  String? _errorMessage;

  Future<void> _reEstablish() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      if (widget.groupId != null) {
        // Group: pull any Sender Key distributions we may have missed.
        await ref
            .read(senderKeyServiceProvider)
            .fetchPendingDistributions(widget.groupId!);
      } else {
        // 1:1: re-run X3DH key exchange with the sender.
        await ref
            .read(messageCryptoServiceProvider)
            .preEstablishSessions([widget.senderId]);
      }
      if (mounted) setState(() { _done = true; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMessage = 'Échec: ${e.toString().split('\n').first}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGroup = widget.groupId != null;

    if (_done) {
      return _InfoRow(
        icon: Icons.check_circle_outline,
        color: Colors.green.shade600,
        text: isGroup
            ? 'Clé de groupe récupérée — demandez à renvoyer le message.'
            : 'Session rétablie — demandez à renvoyer le message.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _InfoRow(
          icon: Icons.lock_clock_outlined,
          color: Colors.orange.shade700,
          text: isGroup
              ? 'Message chiffré — clé de groupe introuvable'
              : widget.isSentByMe
                  ? 'Message chiffré (session expirée sur cet appareil)'
                  : 'Message chiffré — session Signal requise',
        ),
        const SizedBox(height: 6),
        if (!_loading)
          GestureDetector(
            onTap: _reEstablish,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.orange.shade600),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isGroup ? 'Récupérer la clé de groupe' : 'Rétablir la session',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.orange.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          )
        else
          const SizedBox(
            height: 16,
            width: 16,
            child: CircularProgressIndicator(strokeWidth: 1.5),
          ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 4),
          Text(
            _errorMessage!,
            style: TextStyle(fontSize: 10, color: context.errorColor),
          ),
        ],
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _InfoRow({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }
}
