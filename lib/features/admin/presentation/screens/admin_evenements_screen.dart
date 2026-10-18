import 'package:diaspo_niger/core/theme/admin_colors.dart';
import 'package:diaspo_niger/core/theme/design_kit.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/evenements_admin_provider.dart';
import '../widgets/evenements_validation.dart';

/// Événements (spécification d'interfaces § 13) : un calendrier et des chiffres.
///
/// Seuls les événements publics sont listés ; les autres sont comptés. La
/// liste des inscrits est une donnée personnelle : permission dédiée, et chaque
/// consultation est journalisée côté serveur.
class AdminEvenementsScreen extends ConsumerWidget {
  const AdminEvenementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final peut = ref.watch(permissionEvenementsProvider('events.moderate'));
    if (peut.valueOrNull == false) {
      return Center(child: Text(l10n.evtCalNoAccess));
    }
    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.evtCalTitle,
              style: const TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w700, color: AdminColors.text)),
          const SizedBox(height: 4),
          Text(l10n.evtCalSubtitle, style: const TextStyle(color: AdminColors.text3)),
          const SizedBox(height: 12),
          TabBar(
            labelColor: AdminColors.actionBlue,
            unselectedLabelColor: AdminColors.text3,
            tabs: [
              Tab(text: l10n.evtCalTabCalendar),
              Tab(text: l10n.evtValTab),
              Tab(text: l10n.evtCalTabStats),
            ],
          ),
          const SizedBox(height: 12),
          const Expanded(
            child: TabBarView(
              children: [_Calendrier(), OngletValidationEvenements(), _Statistiques()],
            ),
          ),
        ],
      ),
    );
  }
}

String _heure(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String _libelleStatut(AppLocalizations l, String s) => switch (s) {
      'draft' => l.evtCalStatusDraft,
      'ongoing' => l.evtCalStatusOngoing,
      'ended' => l.evtCalStatusEnded,
      'cancelled' => l.evtCalStatusCancelled,
      _ => l.evtCalStatusUpcoming,
    };

DesignBadgeTone _ton(String s) => switch (s) {
      'cancelled' => DesignBadgeTone.failed,
      'ended' => DesignBadgeTone.archived,
      _ => DesignBadgeTone.review,
    };

// ═══ Calendrier ════════════════════════════════════════════════════════════

class _Calendrier extends ConsumerStatefulWidget {
  const _Calendrier();

  @override
  ConsumerState<_Calendrier> createState() => _CalendrierState();
}

class _CalendrierState extends ConsumerState<_Calendrier> {
  DateTime _mois = DateTime(DateTime.now().year, DateTime.now().month);
  int? _jour;

  void _aller(int delta) => setState(() {
        _mois = DateTime(_mois.year, _mois.month + delta);
        _jour = null;
      });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final donnees = ref.watch(calendrierMoisProvider(_mois));
    final libelleMois = MaterialLocalizations.of(context).formatMonthYear(_mois);
    final peutVoirInscrits =
        ref.watch(permissionEvenementsProvider('events.attendance.view')).valueOrNull ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          IconButton(
              tooltip: l10n.evtCalPrevMonth,
              onPressed: () => _aller(-1),
              icon: const Icon(Icons.chevron_left_rounded)),
          Text(libelleMois, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          IconButton(
              tooltip: l10n.evtCalNextMonth,
              onPressed: () => _aller(1),
              icon: const Icon(Icons.chevron_right_rounded)),
          const Spacer(),
          IconButton(
            tooltip: l10n.evtCalRetry,
            onPressed: () => ref.invalidate(calendrierMoisProvider(_mois)),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ]),
        Text(l10n.evtCalTimezone(DateTime.now().timeZoneName),
            style: const TextStyle(fontSize: 11, color: AdminColors.text3)),
        const SizedBox(height: 8),
        Expanded(
          child: donnees.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(l10n.evtCalLoadError(detailEvenements(e)),
                    style: const TextStyle(color: AdminColors.statusRed)),
                OutlinedButton(
                    onPressed: () => ref.invalidate(calendrierMoisProvider(_mois)),
                    child: Text(l10n.evtCalRetry)),
              ]),
            ),
            data: (m) {
              final parJour = <int, List<EvenementCal>>{};
              for (final e in m.evenements) {
                parJour.putIfAbsent(e.debut.day, () => []).add(e);
              }
              final visibles = _jour == null
                  ? m.evenements
                  : (parJour[_jour] ?? const <EvenementCal>[]);
              return ListView(
                children: [
                  _Grille(
                    mois: _mois,
                    parJour: parJour,
                    selection: _jour,
                    onJour: (j) => setState(() => _jour = _jour == j ? null : j),
                  ),
                  const SizedBox(height: 8),
                  if (m.prives > 0)
                    Text(l10n.evtCalPrivateHidden('${m.prives}'),
                        style: const TextStyle(fontSize: 12, color: AdminColors.text3)),
                  const SizedBox(height: 8),
                  if (_jour != null)
                    TextButton(
                      onPressed: () => setState(() => _jour = null),
                      child: Text(l10n.evtCalAllMonth),
                    ),
                  if (visibles.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(_jour == null ? l10n.evtCalNoEventsMonth : l10n.evtCalNoEventsDay,
                          style: const TextStyle(color: AdminColors.text3)),
                    ),
                  for (final e in visibles)
                    _LigneEvenement(evenement: e, peutVoirInscrits: peutVoirInscrits),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Grille extends StatelessWidget {
  const _Grille({
    required this.mois,
    required this.parJour,
    required this.selection,
    required this.onJour,
  });

  final DateTime mois;
  final Map<int, List<EvenementCal>> parJour;
  final int? selection;
  final void Function(int) onJour;

  @override
  Widget build(BuildContext context) {
    final premier = DateTime(mois.year, mois.month);
    final nbJours = DateTime(mois.year, mois.month + 1, 0).day;
    final decalage = premier.weekday - 1; // lundi = 0
    final cases = decalage + nbJours;
    final lignes = (cases / 7).ceil();
    final noms = MaterialLocalizations.of(context).narrowWeekdays;
    final lundiPremier = [...noms.sublist(1), noms.first];

    return Column(children: [
      Row(children: [
        for (final n in lundiPremier)
          Expanded(
            child: Center(
              child: Text(n,
                  style: const TextStyle(fontSize: 11, color: AdminColors.text3)),
            ),
          ),
      ]),
      for (var l = 0; l < lignes; l++)
        Row(children: [
          for (var c = 0; c < 7; c++)
            Expanded(
              child: Builder(builder: (context) {
                final jour = l * 7 + c - decalage + 1;
                if (jour < 1 || jour > nbJours) return const SizedBox(height: 44);
                final n = parJour[jour]?.length ?? 0;
                final choisi = selection == jour;
                return InkWell(
                  onTap: n == 0 ? null : () => onJour(jour),
                  child: Container(
                    height: 44,
                    margin: const EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      color: choisi
                          ? AdminColors.actionBlueBg
                          : (n > 0 ? AdminColors.surfaceAlt : null),
                      border: Border.all(
                          color: choisi ? AdminColors.actionBlue : AdminColors.borderSubtle),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('$jour', style: const TextStyle(fontSize: 12)),
                        if (n > 0)
                          Text('$n',
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AdminColors.actionBlue)),
                      ],
                    ),
                  ),
                );
              }),
            ),
        ]),
    ]);
  }
}

class _LigneEvenement extends ConsumerWidget {
  const _LigneEvenement({required this.evenement, required this.peutVoirInscrits});
  final EvenementCal evenement;
  final bool peutVoirInscrits;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final ev = evenement;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        border: Border.all(color: AdminColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(ev.titre, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DesignBadge(_libelleStatut(l10n, ev.statut), tone: _ton(ev.statut)),
              Text('${ev.debut.day.toString().padLeft(2, '0')}/${ev.debut.month.toString().padLeft(2, '0')} · ${_heure(ev.debut)}',
                  style: const TextStyle(fontSize: 12, color: AdminColors.text3)),
              if (ev.enLigne)
                Text(l10n.evtCalOnline,
                    style: const TextStyle(fontSize: 12, color: AdminColors.text3))
              else if (ev.ville != null)
                Text(ev.ville!, style: const TextStyle(fontSize: 12, color: AdminColors.text3)),
              Text(
                  ev.capacite == null
                      ? l10n.evtCalAttendees('${ev.inscrits}')
                      : l10n.evtCalAttendeesOf('${ev.inscrits}', '${ev.capacite}'),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              if (peutVoirInscrits)
                TextButton(
                  onPressed: () => _inscrits(context, ev),
                  child: Text(l10n.evtCalSeeAttendees),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _inscrits(BuildContext context, EvenementCal e) async {
    final l10n = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.evtCalAttendeesTitle(e.titre)),
        content: SizedBox(
          width: 420,
          // La lecture part à l'ouverture du dialogue, une fois : chaque lecture est journalisée.
          child: FutureBuilder<List<Inscrit>>(
            future: lireInscrits(e.id),
            builder: (ctx, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const LinearProgressIndicator(minHeight: 2);
              }
              if (snap.hasError) {
                return Text(l10n.evtCalLoadError(detailEvenements(snap.error!)),
                    style: const TextStyle(color: AdminColors.statusRed));
              }
              final liste = snap.data ?? const <Inscrit>[];
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.evtCalAttendeesWarn,
                      style: const TextStyle(fontSize: 11, color: AdminColors.text3)),
                  const SizedBox(height: 8),
                  if (liste.isEmpty)
                    Text(l10n.evtCalAttendeesEmpty)
                  else
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                          for (final i in liste)
                            ListTile(
                              dense: true,
                              title: Text(i.nom.isEmpty ? i.userId : i.nom),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.evtCalDone)),
        ],
      ),
    );
  }
}

// ═══ Statistiques ══════════════════════════════════════════════════════════

class _Statistiques extends ConsumerWidget {
  const _Statistiques();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final fenetre = ref.watch(fenetreStatsProvider);
    final stats = ref.watch(statsEvenementsProvider);
    return ListView(
      children: [
        Wrap(spacing: 8, children: [
          for (final j in const [7, 30, 90, 365])
            ChoiceChip(
              label: Text(l10n.evtCalDays('$j')),
              selected: fenetre == j,
              selectedColor: AdminColors.actionBlueBg,
              onSelected: (_) => ref.read(fenetreStatsProvider.notifier).state = j,
            ),
        ]),
        const SizedBox(height: 12),
        stats.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Column(children: [
            Text(l10n.evtCalLoadError(detailEvenements(e)),
                style: const TextStyle(color: AdminColors.statusRed)),
            OutlinedButton(
                onPressed: () => ref.invalidate(statsEvenementsProvider),
                child: Text(l10n.evtCalRetry)),
          ]),
          data: (s) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(spacing: 12, runSpacing: 12, children: [
                _Carte(l10n.evtCalStatCreated, '${s.crees}'),
                _Carte(l10n.evtCalStatUpcoming, '${s.aVenir}'),
                _Carte(l10n.evtCalStatRegistrations, '${s.inscriptions}'),
                _Carte(l10n.evtCalStatCancelled, '${s.annules}'),
                _Carte(
                  l10n.evtCalStatFill,
                  s.tauxRemplissage == null
                      ? l10n.evtCalStatNone
                      : '${(s.tauxRemplissage! * 100).round()} %',
                ),
              ]),
              const SizedBox(height: 16),
              Text(l10n.evtCalStatDefinitions,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              for (final d in s.definitions.values)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('• $d',
                      style: const TextStyle(fontSize: 12, color: AdminColors.text3)),
                ),
              const SizedBox(height: 8),
              if (s.nonMesure.isNotEmpty)
                Text(l10n.evtCalStatNotMeasured(s.nonMesure.join(', ')),
                    style: const TextStyle(
                        fontSize: 12, color: AdminColors.statusAmberStrong)),
            ],
          ),
        ),
      ],
    );
  }
}

class _Carte extends StatelessWidget {
  const _Carte(this.libelle, this.valeur);
  final String libelle;
  final String valeur;

  @override
  Widget build(BuildContext context) => Container(
        width: 200,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AdminColors.surface,
          border: Border.all(color: AdminColors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(valeur,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(libelle, style: const TextStyle(fontSize: 12, color: AdminColors.text3)),
          ],
        ),
      );
}
