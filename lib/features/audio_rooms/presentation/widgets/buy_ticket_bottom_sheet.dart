import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/dn_colors.dart';
import '../../../../core/theme/dn_text.dart';
import '../../../../core/theme/dn_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/audio_room_entity.dart';
import '../providers/monetization_provider.dart';

/// Bottom sheet for buying a room ticket — Sahel design.
class BuyTicketBottomSheet extends ConsumerStatefulWidget {
  final AudioRoomEntity room;

  const BuyTicketBottomSheet({super.key, required this.room});

  static Future<bool?> show(
    BuildContext context, {
    required AudioRoomEntity room,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BuyTicketBottomSheet(room: room),
    );
  }

  @override
  ConsumerState<BuyTicketBottomSheet> createState() =>
      _BuyTicketBottomSheetState();
}

class _BuyTicketBottomSheetState extends ConsumerState<BuyTicketBottomSheet> {
  String _paymentMethod = 'stripe';
  bool _isPurchasing = false;

  double get _price => (widget.room.ticketPrice ?? 0) / 100;
  double get _commission => _price * 0.05;
  double get _hostPayout => _price - _commission;

  Future<void> _purchase() async {
    setState(() => _isPurchasing = true);
    try {
      await ref
          .read(monetizationNotifierProvider.notifier)
          .purchaseRoomTicket(
            roomId: widget.room.id,
            roomTitle: widget.room.title,
            sellerId: widget.room.hostId,
            priceAmount: widget.room.ticketPrice ?? 0,
            currency: widget.room.ticketCurrency ?? 'EUR',
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dn = context.dn;
    final price = _price;
    return Container(
      decoration: BoxDecoration(
        color: dn.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24,),
      child: Column(
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

          Text(l10n.paidRoomBadge, style: DNText.mono(size: 9, color: dn.onSurface3)),
          const SizedBox(height: 6),
          Text(
            widget.room.title,
            style: DNText.serif(size: 22, italic: true, color: dn.onSurface),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                    color: dn.surfaceVariant, shape: BoxShape.circle,),
                alignment: Alignment.center,
                child: Text(
                  widget.room.hostName.isEmpty ? '?' : widget.room.hostName[0],
                  style: DNText.mono(size: 11, color: dn.onSurface2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.room.hostName,
                        style: DNText.sans(
                            size: 13, w: FontWeight.w600, color: dn.onSurface,),),
                    Text(l10n.verifiedHostBadge,
                        style: DNText.mono(size: 9, color: dn.onSurface3),),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: dn.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '€${price.toStringAsFixed(2)}',
                  style: DNText.serif(size: 26, w: FontWeight.w600, color: dn.onSurface),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l10n.platformCommission,
                        style: DNText.mono(size: 8, color: dn.onSurface3),),
                    Text('-€${_commission.toStringAsFixed(2)}',
                        style: DNText.mono(size: 8, color: dn.onSurface3),),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l10n.hostShareLabel,
                        style: DNText.mono(size: 8, color: dn.onSurface3),),
                    Text('+€${_hostPayout.toStringAsFixed(2)}',
                        style: DNText.mono(size: 8, color: DNColors.leaf),),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          Text(l10n.paymentMethodLabel, style: DNText.mono(size: 9, color: dn.onSurface3)),
          const SizedBox(height: 8),
          ...[
            ('stripe', 'Carte bancaire', '💳'),
            ('wave', 'Wave Mobile Money', '📱'),
            ('mynita', 'Mynita', '🌍'),
          ].map((m) => _PaymentRadio(
                value: m.$1,
                label: m.$2,
                emoji: m.$3,
                groupValue: _paymentMethod,
                onChanged: (v) => setState(() => _paymentMethod = v!),
              ),),

          const SizedBox(height: 16),

          ElevatedButton(
            onPressed: _isPurchasing ? null : _purchase,
            style: ElevatedButton.styleFrom(
              backgroundColor: DNColors.terra,
              foregroundColor: DNColors.paper,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: _isPurchasing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2,),
                  )
                : Text(
                    '🔓 Acheter & rejoindre · €${price.toStringAsFixed(2)}',
                    style: DNText.sans(
                        size: 15, w: FontWeight.w600, color: DNColors.paper,),
                  ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Code PIN demandé pour confirmer',
              style: DNText.mono(size: 8, color: dn.onSurface3),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentRadio extends StatelessWidget {
  final String value;
  final String label;
  final String emoji;
  final String? groupValue;
  final ValueChanged<String?> onChanged;

  const _PaymentRadio({
    required this.value,
    required this.label,
    required this.emoji,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => RadioMenuButton<String>(
        value: value,
        groupValue: groupValue,
        onChanged: onChanged,
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Text(label,
                style: DNText.sans(size: 13, color: context.dn.onSurface),),
          ],
        ),
      );
}
