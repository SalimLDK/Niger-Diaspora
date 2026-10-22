import 'dart:async';

import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/message_erreur.dart';
import '../../../../core/services/supabase_auth_bridge.dart';
import '../../../../core/theme/adaptive_colors.dart';

/// État de validation d'un événement de l'organisateur.
///
/// Quand l'équipe active la validation avant publication, un événement public
/// reste invisible des autres membres tant qu'il n'est pas approuvé (migration
/// 20261020090000). Sans cette bannière, l'organisateur verrait son événement
/// comme n'importe quel autre, sans savoir que personne d'autre ne le voit.
class EtatValidation {
  const EtatValidation(this.statut, this.motif);

  /// approved | pending | rejected
  final String statut;
  final String? motif;
}

/// `null` quand la ligne n'est pas lisible : on n'affiche alors rien plutôt
/// qu'une fausse alerte. Les anciennes bases sans la colonne retombent ici.
final etatValidationEvenementProvider =
    FutureProvider.autoDispose.family<EtatValidation?, String>((ref, eventId) async {
  final row = await Supabase.instance.client
      .from('events')
      .select('approval_status, approval_note')
      .eq('id', eventId)
      .maybeSingle();
  if (row == null) return null;
  return EtatValidation(
    row['approval_status'] as String? ?? 'approved',
    row['approval_note'] as String?,
  );
});

class BandeauValidationEvenement extends ConsumerStatefulWidget {
  const BandeauValidationEvenement({super.key, required this.eventId});
  final String eventId;

  @override
  ConsumerState<BandeauValidationEvenement> createState() =>
      _BandeauValidationEvenementState();
}

class _BandeauValidationEvenementState extends ConsumerState<BandeauValidationEvenement> {
  bool _envoi = false;

  Future<void> _resoumettre() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _envoi = true);
    String? echec;
    try {
      await SupabaseAuthBridge.instance.exigerSession();
      await Supabase.instance.client
          .rpc('event_resubmit', params: {'p_id': widget.eventId});
    } catch (e) {
      echec = messageErreurUsager(e);
    }
    ref.invalidate(etatValidationEvenementProvider(widget.eventId));
    if (!mounted) return;
    setState(() => _envoi = false);
    messenger.showSnackBar(SnackBar(content: Text(echec ?? l10n.evtOrgResubmitted)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final etat = ref.watch(etatValidationEvenementProvider(widget.eventId)).valueOrNull;
    if (etat == null || etat.statut == 'approved') return const SizedBox.shrink();

    final refuse = etat.statut == 'rejected';
    final couleur = refuse ? context.errorColor : context.warningColor;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: couleur.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(refuse ? Icons.block_outlined : Icons.hourglass_top_rounded,
                size: 20, color: couleur),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    refuse ? l10n.evtOrgRejectedTitle : l10n.evtOrgPendingTitle,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimaryColor),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    refuse
                        ? l10n.evtOrgRejectedBody(etat.motif ?? '—')
                        : l10n.evtOrgPendingBody,
                    style: TextStyle(fontSize: 12, color: context.textSecondaryColor),
                  ),
                ],
              ),
            ),
          ]),
          if (refuse)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _envoi ? null : () => unawaited(_resoumettre()),
                child: Text(l10n.evtOrgResubmit),
              ),
            ),
        ],
      ),
    );
  }
}
