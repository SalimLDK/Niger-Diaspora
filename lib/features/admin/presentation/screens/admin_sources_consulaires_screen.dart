import 'package:diaspo_niger/core/theme/admin_colors.dart';
import 'package:diaspo_niger/core/theme/design_kit.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/dossier_moderation_provider.dart' show adminAPermissionProvider;
import '../providers/sources_consulaires_provider.dart';

/// Sources et révisions à faire (spécification d'interfaces § 14).
///
/// Lecture seule : l'écran dit ce qui manque, et mène à l'écran où le corriger.
class AdminSourcesConsulairesScreen extends ConsumerStatefulWidget {
  const AdminSourcesConsulairesScreen({super.key, required this.onOuvrir});

  final void Function(String destination) onOuvrir;

  @override
  ConsumerState<AdminSourcesConsulairesScreen> createState() =>
      _AdminSourcesConsulairesScreenState();
}

class _AdminSourcesConsulairesScreenState extends ConsumerState<AdminSourcesConsulairesScreen> {
  ProblemeSource? _filtre;

  String _libelle(AppLocalizations l, ProblemeSource p) => switch (p) {
        ProblemeSource.sansSource => l.srcAdmNoSource,
        ProblemeSource.jamaisVerifiee => l.srcAdmNeverChecked,
        ProblemeSource.revisionDepassee => l.srcAdmReviewOverdue,
        ProblemeSource.sansRevisionPrevue => l.srcAdmNoReviewPlanned,
      };

  bool _garde(List<ProblemeSource> p) => _filtre == null || p.contains(_filtre);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final peutVoir = ref.watch(adminAPermissionProvider('consular.view'));
    final donnees = ref.watch(sourcesConsulairesProvider);

    if (peutVoir.valueOrNull == false) return Center(child: Text(l10n.demAdmNoAccess));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.srcAdmTitle,
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.w700, color: AdminColors.text)),
                const SizedBox(height: 4),
                Text(l10n.srcAdmSubtitle, style: const TextStyle(color: AdminColors.text3)),
              ],
            ),
          ),
          IconButton(
            tooltip: l10n.srcAdmRetry,
            onPressed: () => ref.invalidate(sourcesConsulairesProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          ChoiceChip(
            label: Text(l10n.srcAdmAll),
            selected: _filtre == null,
            selectedColor: AdminColors.actionBlueBg,
            onSelected: (_) => setState(() => _filtre = null),
          ),
          for (final p in ProblemeSource.values)
            ChoiceChip(
              label: Text(_libelle(l10n, p)),
              selected: _filtre == p,
              selectedColor: AdminColors.actionBlueBg,
              onSelected: (_) => setState(() => _filtre = p),
            ),
        ]),
        const SizedBox(height: 12),
        Expanded(
          child: donnees.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(l10n.srcAdmLoadError(detailSources(e)),
                    style: const TextStyle(color: AdminColors.statusRed)),
                const SizedBox(height: 8),
                OutlinedButton(
                    onPressed: () => ref.invalidate(sourcesConsulairesProvider),
                    child: Text(l10n.srcAdmRetry)),
              ]),
            ),
            data: (s) {
              final dem = [for (final d in s.demarches) if (_garde(d.problemes)) d];
              final amb = [for (final a in s.ambassades) if (_garde(a.problemes)) a];
              return ListView(children: [
                _entete(l10n.srcAdmProcedures(dem.length.toString(), s.totalDemarches.toString())),
                if (dem.isEmpty) _vide(l10n),
                for (final d in dem) _carteDemarche(l10n, d),
                const SizedBox(height: 16),
                _entete(l10n.srcAdmEmbassies(amb.length.toString(), s.totalAmbassades.toString())),
                if (amb.isEmpty) _vide(l10n),
                for (final a in amb) _carteAmbassade(l10n, a),
              ]);
            },
          ),
        ),
      ],
    );
  }

  Widget _entete(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      );

  Widget _vide(AppLocalizations l10n) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(l10n.srcAdmNothing, style: const TextStyle(color: AdminColors.text3)),
      );

  Widget _badges(AppLocalizations l10n, List<ProblemeSource> p) => Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          for (final x in p)
            DesignBadge(_libelle(l10n, x),
                tone: x == ProblemeSource.revisionDepassee
                    ? DesignBadgeTone.failed
                    : DesignBadgeTone.review),
        ],
      );

  Widget _carteDemarche(AppLocalizations l10n, SourceDemarche d) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          onTap: () => widget.onOuvrir('demarches'),
          title: Text(d.titre.isEmpty ? d.id : d.titre,
              maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 4),
            _badges(l10n, d.problemes),
            if (d.sourceUrl != null && d.sourceUrl!.trim().isNotEmpty)
              Text('${d.editeur ?? '—'} · ${d.sourceUrl}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AdminColors.text3)),
            if (d.revisionLe != null)
              Text(l10n.srcAdmReviewOn(_jour(d.revisionLe!)),
                  style: const TextStyle(fontSize: 12, color: AdminColors.text3)),
          ]),
          trailing: d.publiee ? null : Text(l10n.srcAdmUnpublished, style: const TextStyle(fontSize: 12)),
        ),
      );

  Widget _carteAmbassade(AppLocalizations l10n, SourceAmbassade a) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          onTap: () => widget.onOuvrir('embassies'),
          title: Text(a.nom, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 4),
            _badges(l10n, a.problemes),
            if (a.ville.isNotEmpty)
              Text(a.ville, style: const TextStyle(fontSize: 12, color: AdminColors.text3)),
            if (a.sourceUrl != null && a.sourceUrl!.trim().isNotEmpty)
              Text(a.sourceUrl!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AdminColors.text3)),
          ]),
        ),
      );
}

String _jour(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
