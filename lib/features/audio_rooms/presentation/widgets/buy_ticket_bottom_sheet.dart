import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/currency_service.dart';
import '../../../../core/theme/dn_colors.dart';
import '../../../../core/theme/dn_text.dart';
import '../../../../core/theme/dn_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/audio_room_entity.dart';
import '../../domain/entities/room_ticket_entity.dart';
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
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  String _paymentMethod = 'stripe';
  bool _isPurchasing = false;

  /// Prix en **unité mineure**, tel que le stocke l'entité et tel que Stripe
  /// l'attend. Le `/ 100` d'affichage était faux pour le FCFA, qui n'a pas de
  /// subdivision : un billet à 5 000 FCFA s'annonçait « 50 FCFA ».
  int get _priceMinor => widget.room.ticketPrice ?? 0;

  /// Commission réellement prélevée par `process-room-ticket` (15 %). La
  /// feuille annonçait 5 %, donc « 95 % » à l'hôte, pour un prélèvement réel
  /// de 15 %.
  int get _commissionMinor => RoomTicketEntity.calculateCommission(_priceMinor);
  int get _hostPayoutMinor => _priceMinor - _commissionMinor;

  /// Devise réelle du billet : le prix s'affichait en € en dur, y compris pour
  /// un salon facturé en XOF.
  Currency get _currency =>
      CurrencyExtension.fromCode(widget.room.ticketCurrency ?? 'EUR');

  String _money(int minorAmount) =>
      CurrencyService.instance.formatMinor(minorAmount, _currency);

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
    final price = _priceMinor;
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
                  _money(price),
                  style: DNText.serif(size: 26, w: FontWeight.w600, color: dn.onSurface),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l10n.platformCommission,
                        style: DNText.mono(size: 8, color: dn.onSurface3),),
                    Text('-${_money(_commissionMinor)}',
                        style: DNText.mono(size: 8, color: dn.onSurface3),),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l10n.hostShareLabel,
                        style: DNText.mono(size: 8, color: dn.onSurface3),),
                    Text('+${_money(_hostPayoutMinor)}',
                        style: DNText.mono(size: 8, color: DNColors.leaf),),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          Text(l10n.paymentMethodLabel, style: DNText.mono(size: 9, color: dn.onSurface3)),
          const SizedBox(height: 8),
          // Le code PIN ne concerne que le mobile money. La mention était
          // affichée en pied de feuille, donc également quand « Carte
          // bancaire » était sélectionné : elle est désormais portée par les
          // seules méthodes concernées (maquette 1h).
          ...[
            (
              id: 'stripe',
              label: l10n.ticketPaymentMethodCard,
              emoji: '💳',
              needsPin: false,
            ),
            (id: 'wave', label: 'Wave Mobile Money', emoji: '📱', needsPin: true),
            (id: 'mynita', label: l10n.recipientTypeMynita, emoji: '🌍', needsPin: true),
          ].map((m) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _PaymentRadio(
                  value: m.id,
                  label: m.label,
                  emoji: m.emoji,
                  subtitle: m.needsPin ? l10n.ticketPinRequired : null,
                  groupValue: _paymentMethod,
                  onChanged: (v) => setState(() => _paymentMethod = v),
                ),
              ),),

          const SizedBox(height: 8),

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
                    l10n.ticketBuyAndJoin(_money(price)),
                    style: DNText.sans(
                        size: 15, w: FontWeight.w600, color: DNColors.paper,),
                  ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              l10n.ticketReplayAccessNote,
              textAlign: TextAlign.center,
              style: DNText.mono(size: 8, color: dn.onSurface3),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ligne de moyen de paiement : encadrée, sélectionnable en entier, avec un
/// [subtitle] optionnel réservé aux méthodes qui demandent un code PIN.
class _PaymentRadio extends StatelessWidget {
  final String value;
  final String label;
  final String emoji;
  final String? subtitle;
  final String? groupValue;
  final ValueChanged<String> onChanged;

  const _PaymentRadio({
    required this.value,
    required this.label,
    required this.emoji,
    required this.groupValue,
    required this.onChanged,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final dn = context.dn;
    final selected = groupValue == value;

    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: dn.surface2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? DNColors.terra : dn.onSurface4,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: DNText.sans(
                      size: 13,
                      w: FontWeight.w600,
                      color: dn.onSurface,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: DNText.mono(size: 8, color: dn.onSurface3),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 18,
              height: 18,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? DNColors.terra : dn.onSurface4,
                  width: 1.5,
                ),
              ),
              child: selected
                  ? Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                        color: DNColors.terra,
                        shape: BoxShape.circle,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
