import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/adaptive_colors.dart';
import '../../../../core/theme/design_kit.dart';
import '../providers/official_group_departure_provider.dart';

/// Avertissement et choix : quitter le groupe officiel d'un pays que le
/// profil n'indique plus depuis six mois, ou y rester.
///
/// N'apparaît que si la base a une proposition à confirmer pour ce groupe
/// (`departs_groupe_officiel.statut = 'a_confirmer'`, posée par la tâche
/// quotidienne `proposer_departs_groupes_officiels`, qui envoie aussi la
/// notification `officialGroupLeave` menant à cette fiche).
///
/// **Rien ne se passe sans un appui** : ignorer la carte, c'est rester
/// membre. « Quitter le groupe » redemande confirmation, comme le départ
/// ordinaire du menu.
class OfficialGroupDepartureCard extends ConsumerStatefulWidget {
  final String groupId;

  /// Appelé une fois le départ enregistré : l'écran se rafraîchit et se ferme,
  /// comme après « Quitter le groupe ».
  final VoidCallback onLeft;

  const OfficialGroupDepartureCard({
    super.key,
    required this.groupId,
    required this.onLeft,
  });

  @override
  ConsumerState<OfficialGroupDepartureCard> createState() =>
      _OfficialGroupDepartureCardState();
}

class _OfficialGroupDepartureCardState
    extends ConsumerState<OfficialGroupDepartureCard> {
  bool _saving = false;

  Future<void> _answer({required bool leave}) async {
    final l10n = AppLocalizations.of(context)!;

    if (leave) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.leaveGroupTitle),
          content: Text(l10n.leaveGroupConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text(l10n.leaveGroup),
            ),
          ],
        ),
      );
      if (confirm != true || !mounted) return;
    }

    setState(() => _saving = true);
    String? result;
    Object? error;
    try {
      result = await ref
          .read(officialGroupDepartureDataSourceProvider)
          .answer(widget.groupId, leave: leave);
    } catch (e) {
      error = e;
    }
    if (!mounted) return;
    setState(() => _saving = false);

    final messenger = ScaffoldMessenger.of(context);
    if (error != null) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.officialGroupDepartureFailed)),
      );
      return;
    }

    // `null` : plus rien à décider (réponse donnée ailleurs, ou retour dans
    // ce pays entre-temps). Dans tous les cas on relit : la carte disparaît.
    ref.invalidate(pendingOfficialGroupDepartureProvider(widget.groupId));
    if (result == 'quitte') {
      messenger.showSnackBar(SnackBar(content: Text(l10n.groupLeft)));
      widget.onLeft();
    } else if (result == 'reste') {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.officialGroupDepartureStayed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final departure = ref
        .watch(pendingOfficialGroupDepartureProvider(widget.groupId))
        .valueOrNull;
    if (departure == null) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final date = DateFormat.yMMMMd(
      Localizations.localeOf(context).toString(),
    ).format(departure.changedAt);

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.surfaceVariantColor,
          borderRadius: BorderRadius.circular(kDesignRadius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              departure.formerCity == null
                  ? l10n.officialGroupDepartureTitle
                  : l10n.officialGroupDepartureCityTitle,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: context.textPrimaryColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              departure.formerCity == null
                  ? l10n.officialGroupDepartureBody(date, departure.formerCountry)
                  : l10n.officialGroupDepartureCityBody(
                      date, departure.formerCity!),
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: context.textSecondaryColor,
              ),
            ),
            const SizedBox(height: 14),
            // L'un sous l'autre : côte à côte, deux libellés longs débordent
            // dès que l'échelle de police de l'appareil est agrandie.
            DesignDestructiveButton(
              label: l10n.leaveGroupTitle,
              isLoading: _saving,
              onPressed: _saving ? null : () => _answer(leave: true),
            ),
            const SizedBox(height: 8),
            DesignSecondaryButton(
              label: l10n.officialGroupDepartureStay,
              onPressed: _saving ? null : () => _answer(leave: false),
            ),
          ],
        ),
      ),
    );
  }
}
