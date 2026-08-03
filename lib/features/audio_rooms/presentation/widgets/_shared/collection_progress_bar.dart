import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/services/currency_service.dart';
import '../../../../../core/theme/dn_colors.dart';
import '../../../../../core/theme/dn_text.dart';
import '../../../../../core/theme/dn_theme.dart';
import '../../../domain/entities/tip_entity.dart';
import '../../providers/monetization_provider.dart';

/// Horizontal fundraising progress bar.
class CollectionProgressBar extends ConsumerWidget {
  final double current;
  final double goal;
  final String beneficiary;

  /// Salon dont la collecte est affichée. Sert à compter les contributeurs :
  /// les deux points de montage passaient `contributors: 0` en dur, si bien
  /// que la ligne annonçait « 0 contrib. » même sur une collecte alimentée.
  final String roomId;

  /// Devise de la collecte (`AudioRoomEntity.ticketCurrency`). L'objectif et le
  /// montant courant étaient suffixés « € » en dur, y compris sur un salon
  /// libellé en XOF.
  final String? currencyCode;

  const CollectionProgressBar({
    required this.current,
    required this.goal,
    required this.beneficiary,
    required this.roomId,
    this.currencyCode,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dn = context.dn;
    final pct = goal > 0 ? (current / goal).clamp(0.0, 1.0) : 0.0;
    final currency = CurrencyExtension.fromCode(currencyCode ?? 'EUR');
    String money(double amount) =>
        CurrencyService.instance.format(amount, currency);

    // Contributeurs distincts : un donateur qui envoie trois pourboires compte
    // pour un. Seuls les paiements aboutis comptent.
    final contributors = ref
            .watch(roomTipsProvider(roomId))
            .valueOrNull
            ?.where((t) => t.status == TipStatus.completed)
            .map((t) => t.senderId)
            .toSet()
            .length ??
        0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: dn.surfaceVariant,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '📦 Objectif ${money(goal)}',
                style: DNText.mono(size: 9, color: dn.onSurface3),
              ),
              Text(
                '${(pct * 100).round()}% · ${money(current)}',
                style: DNText.mono(size: 10, color: DNColors.leaf),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: dn.surface2,
              valueColor: const AlwaysStoppedAnimation(DNColors.leaf),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$beneficiary · $contributors contrib.',
            style: DNText.mono(size: 8, color: dn.onSurface3),
          ),
        ],
      ),
    );
  }
}
