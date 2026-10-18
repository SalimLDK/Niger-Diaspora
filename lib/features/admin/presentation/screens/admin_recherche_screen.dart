
import 'package:diaspo_niger/core/theme/admin_colors.dart';
import 'package:diaspo_niger/core/theme/design_kit.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/recherche_admin_provider.dart';

/// « À traiter » et recherche globale (spécification d'interfaces § 3 et § 4).
///
/// La file se lit à l'ouverture et se relit au geste : elle est comptée en base,
/// pas tenue à jour. La recherche ne part qu'à la validation — elle est
/// journalisée (jamais le mot cherché).
class AdminRechercheScreen extends ConsumerStatefulWidget {
  const AdminRechercheScreen({super.key, required this.onOuvrir});

  /// Mène à une destination du tableau de bord, par son identifiant.
  final void Function(String destination) onOuvrir;

  @override
  ConsumerState<AdminRechercheScreen> createState() => _AdminRechercheScreenState();
}

class _AdminRechercheScreenState extends ConsumerState<AdminRechercheScreen> {
  final _champ = TextEditingController();

  @override
  void dispose() {
    _champ.dispose();
    super.dispose();
  }

  void _lancer() {
    final mot = _champ.text.trim();
    if (mot.length < 2) return;
    ref.read(motRechercheProvider.notifier).state = mot;
    ref.invalidate(rechercheGlobaleProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.rchAdmTitle,
              style: const TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w700, color: AdminColors.text)),
          const SizedBox(height: 4),
          Text(l10n.rchAdmSubtitle, style: const TextStyle(color: AdminColors.text3)),
          const SizedBox(height: 12),
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: AdminColors.actionBlue,
            tabs: [Tab(text: l10n.rchAdmTabQueue), Tab(text: l10n.rchAdmTabSearch)],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(children: [_file(l10n), _recherche(l10n)]),
          ),
        ],
      ),
    );
  }

  // ── À traiter ────────────────────────────────────────────────────────────

  String _libelleFamille(AppLocalizations l, String cle) => switch (cle) {
        'reports' => l.rchAdmQReports,
        'appeals' => l.rchAdmQAppeals,
        'tickets' => l.rchAdmQTickets,
        'tickets_escalated' => l.rchAdmQTicketsEscalated,
        'tickets_overdue' => l.rchAdmQTicketsOverdue,
        'privacy' => l.rchAdmQPrivacy,
        'procedures' => l.rchAdmQProcedures,
        'campaigns' => l.rchAdmQCampaigns,
        'events_pending' => l.rchAdmQEventsPending,
        'businesses_review' => l.rchAdmQBusinessesReview,
        _ => cle,
      };

  Widget _file(AppLocalizations l10n) {
    final file = ref.watch(fileATraiterProvider);
    return file.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _erreur(l10n, detailRecherche(e), () => ref.invalidate(fileATraiterProvider)),
      data: (lignes) {
        final ouvertes = lignes.where((x) => x.total > 0).toList();
        return ListView(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: l10n.rchAdmRefresh,
                onPressed: () => ref.invalidate(fileATraiterProvider),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ),
            if (ouvertes.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l10n.rchAdmQueueEmpty,
                    style: const TextStyle(color: AdminColors.text3)),
              ),
            for (final x in ouvertes)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  onTap: () => widget.onOuvrir(destinationDe(x.cle)),
                  title: Text(_libelleFamille(l10n, x.cle),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: x.plusAncien == null
                      ? null
                      : Text(l10n.rchAdmOldest(_jour(x.plusAncien!))),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (x.enRetard > 0)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: DesignBadge(l10n.rchAdmLate(x.enRetard.toString()),
                            tone: DesignBadgeTone.failed),
                      ),
                    DesignBadge(x.total.toString(), tone: DesignBadgeTone.review),
                  ]),
                ),
              ),
          ],
        );
      },
    );
  }

  // ── Recherche ────────────────────────────────────────────────────────────

  String _libelleGenre(AppLocalizations l, String g) => switch (g) {
        'members' => l.rchAdmKindMembers,
        'tickets' => l.rchAdmKindTickets,
        'reports' => l.rchAdmKindReports,
        'businesses' => l.rchAdmKindBusinesses,
        'events' => l.rchAdmKindEvents,
        'procedures' => l.rchAdmKindProcedures,
        'embassies' => l.rchAdmKindEmbassies,
        'campaigns' => l.rchAdmKindCampaigns,
        _ => g,
      };

  Widget _recherche(AppLocalizations l10n) {
    final mot = ref.watch(motRechercheProvider);
    final reponse = ref.watch(rechercheGlobaleProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: TextField(
              controller: _champ,
              maxLength: 80,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _lancer(),
              decoration: InputDecoration(
                labelText: l10n.rchAdmSearchLabel,
                helperText: l10n.rchAdmSearchHelp,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.search_rounded),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(onPressed: _lancer, child: Text(l10n.rchAdmSearchGo)),
        ]),
        const SizedBox(height: 8),
        Expanded(
          child: mot == null
              ? const SizedBox.shrink()
              : reponse.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) =>
                      _erreur(l10n, detailRecherche(e), () => ref.invalidate(rechercheGlobaleProvider)),
                  data: (r) => r == null ? const SizedBox.shrink() : _resultats(l10n, r),
                ),
        ),
      ],
    );
  }

  Widget _resultats(AppLocalizations l10n, ReponseRecherche r) {
    return ListView(
      children: [
        if (r.ignorees.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
                l10n.rchAdmSkipped(r.ignorees.map((g) => _libelleGenre(l10n, g)).join(', ')),
                style: const TextStyle(fontSize: 12, color: AdminColors.text3)),
          ),
        if (r.total == 0)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l10n.rchAdmNoResult, style: const TextStyle(color: AdminColors.text3)),
          ),
        for (final g in r.groupes) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(_libelleGenre(l10n, g.genre),
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          for (final x in g.resultats)
            Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                dense: true,
                onTap: () => widget.onOuvrir(destinationDe(g.genre)),
                title: Text(x.titre.isEmpty ? '—' : x.titre,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: x.sousTitre.isEmpty
                    ? null
                    : Text(x.sousTitre, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: x.statut.isEmpty ? null : Text(x.statut, style: const TextStyle(fontSize: 12)),
              ),
            ),
        ],
      ],
    );
  }

  Widget _erreur(AppLocalizations l10n, String detail, VoidCallback reessayer) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(l10n.rchAdmLoadError(detail),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AdminColors.statusRed)),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: reessayer, child: Text(l10n.rchAdmRetry)),
        ]),
      );
}

String _jour(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
