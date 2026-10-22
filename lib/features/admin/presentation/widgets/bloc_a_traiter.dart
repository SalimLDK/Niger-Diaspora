import 'package:diaspo_niger/core/theme/admin_colors.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/a_traiter_provider.dart';

/// « À traiter » : les files qui attendent, selon les droits de l'agent
/// (spécification d'interfaces § 7). Chaque ligne dit ce qu'elle compte, ce
/// qui y est urgent et depuis quand, et ouvre la rubrique qui la traite.
class BlocATraiter extends ConsumerWidget {
  const BlocATraiter({super.key, required this.onOuvrir});

  /// Ouvre une rubrique du menu par son identifiant ; le menu revérifie le droit.
  final void Function(String destination) onOuvrir;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final liste = ref.watch(aTraiterProvider);

    String libelle(String cle) => switch (cle) {
          'reports' => l10n.tbAdmReports,
          'support' => l10n.tbAdmSupport,
          'demarches' => l10n.tbAdmDemarches,
          'campaigns' => l10n.tbAdmCampaigns,
          'privacy' => l10n.tbAdmPrivacy,
          'incidents' => l10n.tbAdmIncidents,
          _ => l10n.tbAdmListings,
        };
    String definition(String cle) => switch (cle) {
          'reports' => l10n.tbAdmReportsDef,
          'support' => l10n.tbAdmSupportDef,
          'demarches' => l10n.tbAdmDemarchesDef,
          'campaigns' => l10n.tbAdmCampaignsDef,
          'privacy' => l10n.tbAdmPrivacyDef,
          'incidents' => l10n.tbAdmIncidentsDef,
          _ => l10n.tbAdmListingsDef,
        };
    String? urgent(String cle) => switch (cle) {
          'reports' => l10n.tbAdmReportsUrgent,
          'support' => l10n.tbAdmSupportUrgent,
          'demarches' => l10n.tbAdmDemarchesUrgent,
          'privacy' => l10n.tbAdmPrivacyUrgent,
          'incidents' => l10n.tbAdmIncidentsUrgent,
          _ => null,
        };
    String jour(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    String heure(DateTime d) =>
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        border: Border.all(color: AdminColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(l10n.tbAdmTitle,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700, color: AdminColors.text)),
            ),
            IconButton(
              tooltip: l10n.tbAdmRefresh,
              onPressed: () => ref.invalidate(aTraiterProvider),
              icon: const Icon(Icons.refresh_rounded, size: 18),
            ),
          ]),
          Text(l10n.tbAdmSubtitle,
              style: const TextStyle(fontSize: 12, color: AdminColors.text3)),
          liste.maybeWhen(
            data: (l) => l.calculeLe == null
                ? const SizedBox.shrink()
                : Text(l10n.tbAdmComputedAt(heure(l.calculeLe!)),
                    style: const TextStyle(fontSize: 12, color: AdminColors.text3)),
            orElse: () => const SizedBox.shrink(),
          ),
          const SizedBox(height: 12),
          liste.when(
            loading: () => const LinearProgressIndicator(minHeight: 2),
            error: (e, _) => Row(children: [
              Expanded(
                child: Text(l10n.tbAdmLoadError(detailATraiter(e)),
                    style: const TextStyle(color: AdminColors.statusRed, fontSize: 13)),
              ),
              TextButton(
                onPressed: () => ref.invalidate(aTraiterProvider),
                child: Text(l10n.tbAdmRetry),
              ),
            ]),
            data: (l) => l.elements.isEmpty
                ? Text(l10n.tbAdmNothingForRole,
                    style: const TextStyle(color: AdminColors.text3))
                : Column(
                    children: [
                      for (final e in _tries(l.elements))
                        InkWell(
                          onTap: e.destination.isEmpty ? null : () => onOuvrir(e.destination),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 44,
                                  child: Text(
                                    '${e.nombre}',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: (e.urgent ?? 0) > 0
                                          ? AdminColors.statusRed
                                          : AdminColors.text,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(libelle(e.cle),
                                          style: const TextStyle(fontWeight: FontWeight.w600)),
                                      Text(definition(e.cle),
                                          style: const TextStyle(
                                              fontSize: 12, color: AdminColors.text3)),
                                      if (e.nombre == 0)
                                        Text(l10n.tbAdmCalm,
                                            style: const TextStyle(
                                                fontSize: 12, color: AdminColors.text3))
                                      else ...[
                                        if ((e.urgent ?? 0) > 0 && urgent(e.cle) != null)
                                          Text(
                                            l10n.tbAdmUrgentPrefix('${e.urgent}', urgent(e.cle)!),
                                            style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: AdminColors.statusRed),
                                          ),
                                        if (e.leMoinsRecent != null)
                                          Text(l10n.tbAdmOldest(jour(e.leMoinsRecent!)),
                                              style: const TextStyle(
                                                  fontSize: 12, color: AdminColors.text3)),
                                      ],
                                    ],
                                  ),
                                ),
                                if (e.destination.isNotEmpty)
                                  const Icon(Icons.chevron_right_rounded,
                                      color: AdminColors.text3),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// Ce qui est urgent d'abord, puis le plus gros, puis l'ordre des clés :
  /// une file calme ne passe pas devant une file en retard.
  List<ElementATraiter> _tries(List<ElementATraiter> liste) {
    final copie = [...liste];
    copie.sort((a, b) {
      final ua = (a.urgent ?? 0) > 0 ? 0 : 1;
      final ub = (b.urgent ?? 0) > 0 ? 0 : 1;
      if (ua != ub) return ua.compareTo(ub);
      if (a.nombre != b.nombre) return b.nombre.compareTo(a.nombre);
      return a.cle.compareTo(b.cle);
    });
    return copie;
  }
}
