import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/currency_service.dart';
import '../../../../core/theme/dn_colors.dart';
import '../../../../core/theme/dn_text.dart';
import '../../../../core/theme/dn_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/participant_entity.dart';
import '../providers/monetization_provider.dart';
import '../widgets/_shared/tip_coin_animation.dart';

/// Bottom sheet for sending a tip — floating 🪙 coins + ochre CTA.
class SendTipBottomSheet extends ConsumerStatefulWidget {
  final String roomId;
  final ParticipantEntity recipient;
  final String currency;

  /// Titre du salon, affiché sous le nom du destinataire (maquette 1g).
  /// Optionnel : sans lui, on retombe sur l'état du micro.
  final String? roomTitle;

  const SendTipBottomSheet({
    super.key,
    required this.roomId,
    required this.recipient,
    this.currency = 'EUR',
    this.roomTitle,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String roomId,
    required ParticipantEntity recipient,
    String currency = 'EUR',
    String? roomTitle,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SendTipBottomSheet(
        roomId: roomId,
        recipient: recipient,
        currency: currency,
        roomTitle: roomTitle,
      ),
    );
  }

  @override
  ConsumerState<SendTipBottomSheet> createState() =>
      _SendTipBottomSheetState();
}

class _SendTipBottomSheetState extends ConsumerState<SendTipBottomSheet> {
  static const _amounts = [1.0, 2.0, 5.0, 10.0, 20.0, 50.0];
  double _selected = 5.0;
  final _msgCtrl = TextEditingController();
  bool _isSending = false;

  double get _platformFee => _selected * 0.05;
  double get _recipientGets => _selected - _platformFee;

  /// Part réellement perçue, calculée plutôt que codée en dur à « 95 % ».
  int get _recipientSharePercent =>
      _selected == 0 ? 0 : ((_recipientGets / _selected) * 100).round();

  Currency get _currency => CurrencyExtension.fromCode(widget.currency);

  String _money(double amount) =>
      CurrencyService.instance.format(amount, _currency);

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _isSending = true);
    try {
      await ref
          .read(monetizationNotifierProvider.notifier)
          .sendTip(
            roomId: widget.roomId,
            recipientId: widget.recipient.userId,
            recipientName: widget.recipient.userName,
            amount: (_selected * 100).round(),
            currency: widget.currency,
            message: _msgCtrl.text.trim().isNotEmpty ? _msgCtrl.text.trim() : null,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dn = context.dn;
    final l10n = AppLocalizations.of(context)!;
    final roomTitle = widget.roomTitle?.trim();
    return Container(
      decoration: BoxDecoration(
        color: dn.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24,),
      child: Stack(
        children: [
          const Positioned(left: 20, top: 0, child: TipCoinAnimation(x: 0, delayMs: 0)),
          const Positioned(left: 80, top: 0, child: TipCoinAnimation(x: 0, delayMs: 300)),
          const Positioned(left: 160, top: 0, child: TipCoinAnimation(x: 0, delayMs: 150)),
          const Positioned(left: 240, top: 0, child: TipCoinAnimation(x: 0, delayMs: 450)),

          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: dn.onSurface4,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                        color: dn.surfaceVariant, shape: BoxShape.circle,),
                    alignment: Alignment.center,
                    child: Text(
                      widget.recipient.userName.isEmpty
                          ? '?'
                          : widget.recipient.userName[0],
                      style: DNText.mono(size: 13, color: dn.onSurface2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.recipient.userName,
                            style: DNText.sans(
                                size: 13, w: FontWeight.w600, color: dn.onSurface,),),
                        // La maquette situe le don : « Speaker · <salon> ».
                        // Sans titre de salon, on garde l'état du micro.
                        Text(
                          roomTitle != null && roomTitle.isNotEmpty
                              ? '${widget.recipient.roleLabel} · $roomTitle'
                              : '${widget.recipient.roleLabel} · '
                                  '🎙 ${widget.recipient.isMuted ? l10n.liveMicMuted : l10n.liveMicLabel}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DNText.mono(size: 9, color: dn.onSurface3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                childAspectRatio: 2.5,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                children: _amounts.map((amt) {
                  final active = _selected == amt;
                  return GestureDetector(
                    onTap: () => setState(() => _selected = amt),
                    child: Container(
                      decoration: BoxDecoration(
                        color: active ? DNColors.ochre : dn.surface2,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: active ? DNColors.ochre : dn.onSurface4,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _money(amt),
                        style: DNText.serif(
                          size: 16,
                          color: active ? DNColors.paper : dn.onSurface,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _msgCtrl,
                style: DNText.sans(size: 13, color: dn.onSurface),
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context)!.optionalMessageHint,
                  hintStyle: DNText.sans(size: 13, color: dn.onSurface4),
                  filled: true,
                  fillColor: dn.surface2,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        BorderSide(color: dn.onSurface4, style: BorderStyle.none),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                        color: DNColors.ochre, style: BorderStyle.none,),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 10),

              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: dn.surface2,
                  borderRadius: BorderRadius.circular(8),
                ),
                // La maquette montre les deux montants : ce que l'on débourse
                // et ce que le destinataire touche après commission.
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.sendTipYouSend,
                          style: DNText.mono(size: 9, color: dn.onSurface3),
                        ),
                        Text(
                          _money(_selected),
                          style: DNText.mono(size: 9, color: dn.onSurface),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            l10n.recipientReceives(widget.recipient.userName),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: DNText.mono(size: 9, color: dn.onSurface3),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_money(_recipientGets)} ($_recipientSharePercent%)',
                          style: DNText.mono(size: 9, color: DNColors.leaf),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              ElevatedButton(
                onPressed: _isSending ? null : _send,
                style: ElevatedButton.styleFrom(
                  backgroundColor: DNColors.ochre,
                  foregroundColor: DNColors.paper,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),),
                  elevation: 0,
                ),
                child: _isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2,),
                      )
                    : Text(
                        '🪙 ${l10n.sendTipSend(_money(_selected))}',
                        style: DNText.sans(
                            size: 15,
                            w: FontWeight.w600,
                            color: DNColors.paper,),
                      ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  l10n.sendTipShownInRoomNote,
                  textAlign: TextAlign.center,
                  style: DNText.mono(size: 8, color: dn.onSurface3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
