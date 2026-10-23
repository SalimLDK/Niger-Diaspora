import 'dart:async';

import 'package:diaspo_niger/core/theme/admin_colors.dart';
import 'package:diaspo_niger/core/theme/design_kit.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/support_admin_provider.dart';
import '../widgets/reglages_support_dialog.dart';

/// Support : la file des tickets des membres (spécification d'interfaces § 15).
///
/// Le fil visible par le membre et les notes internes sont deux zones
/// distinctes, de couleurs différentes. Chaque geste appelle une RPC ; les
/// boutons suivent le statut et le responsable, le serveur reste l'autorité
/// et ses refus s'affichent en clair.
class AdminSupportTicketsScreen extends ConsumerStatefulWidget {
  const AdminSupportTicketsScreen({super.key});

  @override
  ConsumerState<AdminSupportTicketsScreen> createState() =>
      _AdminSupportTicketsScreenState();
}

class _AdminSupportTicketsScreenState
    extends ConsumerState<AdminSupportTicketsScreen> {
  final _recherche = TextEditingController();
  String _terme = '';

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final peutVoir = ref.watch(permissionSupportProvider('support.tickets.view'));
    final filtre = ref.watch(filtreTicketsProvider);
    final tickets = ref.watch(ticketsAdminProvider);

    // Sans le droit de lecture, la table répond « vide » (RLS) : on le dit
    // plutôt que de montrer une file qui semble simplement calme.
    if (peutVoir.valueOrNull == false) {
      return Center(child: Text(l10n.supAdmNoAccess));
    }

    final filtres = <(String?, String)>[
      ('open', l10n.supAdmFilterOpen),
      ('in_progress', l10n.supAdmFilterInProgress),
      ('resolved', l10n.supAdmFilterResolved),
      ('closed', l10n.supAdmFilterClosed),
      ('escalated', l10n.supAdmFilterEscalated),
      (null, l10n.supAdmFilterAll),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.supAdmTitle,
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AdminColors.text)),
                  const SizedBox(height: 4),
                  Text(l10n.supAdmSubtitle,
                      style: const TextStyle(color: AdminColors.text3)),
                ],
              ),
            ),
            if ((ref.watch(permissionSupportProvider('support.templates.manage')).valueOrNull ??
                    false) ||
                (ref.watch(permissionSupportProvider('support.sla.manage')).valueOrNull ?? false))
              IconButton(
                tooltip: l10n.supSlaSettings,
                onPressed: () => unawaited(showDialog<void>(
                  context: context,
                  builder: (_) => const ReglagesSupportDialog(
                    libelleCategorie: _libelleCategorie,
                    libellePriorite: _libellePriorite,
                  ),
                )),
                icon: const Icon(Icons.tune_rounded),
              ),
            IconButton(
              tooltip: l10n.supAdmRetry,
              onPressed: () {
                ref.invalidate(ticketsAdminProvider);
                ref.invalidate(echeancesProvider);
              },
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final f in filtres)
              ChoiceChip(
                label: Text(f.$2),
                selected: filtre == f.$1,
                selectedColor: AdminColors.actionBlueBg,
                onSelected: (_) =>
                    ref.read(filtreTicketsProvider.notifier).state = f.$1,
              ),
            SizedBox(
              width: 280,
              child: TextField(
                controller: _recherche,
                onChanged: (v) => setState(() => _terme = v.trim().toLowerCase()),
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  hintText: l10n.supAdmSearchHint,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: tickets.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.supAdmLoadError(detailSupport(e)),
                      style: const TextStyle(color: AdminColors.statusRed)),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => ref.invalidate(ticketsAdminProvider),
                    child: Text(l10n.supAdmRetry),
                  ),
                ],
              ),
            ),
            data: (liste) {
              final vus = _terme.isEmpty
                  ? liste
                  : [
                      for (final t in liste)
                        if (t.sujet.toLowerCase().contains(_terme) ||
                            t.userName.toLowerCase().contains(_terme))
                          t,
                    ];
              if (vus.isEmpty) {
                return Center(
                  child: Text(l10n.supAdmEmpty,
                      style: const TextStyle(color: AdminColors.text3)),
                );
              }
              return ListView.separated(
                itemCount: vus.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) => _CarteTicket(key: ValueKey(vus[i].id), ticket: vus[i]),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ═══ Libellés ══════════════════════════════════════════════════════════════

String _libelleStatut(AppLocalizations l, String s) => switch (s) {
      'open' => l.supAdmStatusOpen,
      'in_progress' => l.supAdmStatusInProgress,
      'resolved' => l.supAdmStatusResolved,
      _ => l.supAdmStatusClosed,
    };

String _libellePriorite(AppLocalizations l, String p) => switch (p) {
      'low' => l.supAdmPrioLow,
      'high' => l.supAdmPrioHigh,
      'urgent' => l.supAdmPrioUrgent,
      _ => l.supAdmPrioNormal,
    };

String _libelleCategorie(AppLocalizations l, String c) => switch (c) {
      'transaction' => l.supAdmCatTransaction,
      'account' => l.supAdmCatAccount,
      'technical' => l.supAdmCatTechnical,
      'directory' => l.supAdmCatDirectory,
      'privacy' => l.supAdmCatPrivacy,
      'complaint' => l.supAdmCatComplaint,
      'appeal' => l.supAdmCatAppeal,
      'security' => l.supAdmCatSecurity,
      _ => l.supAdmCatOther,
    };

String _date(DateTime? d) => d == null
    ? ''
    : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

DesignBadgeTone _tonStatut(String s) => switch (s) {
      'open' || 'in_progress' => DesignBadgeTone.review,
      'resolved' => DesignBadgeTone.verified,
      _ => DesignBadgeTone.archived,
    };

// ═══ Un geste, son bilan ═══════════════════════════════════════════════════

/// Exécute [geste], relit ce qui a pu changer et dit le résultat. Rend vrai
/// seulement si le serveur a accepté. On relit même après un refus : il peut
/// venir d'un ticket qu'un autre agent vient de modifier.
Future<bool> _lancer(
  BuildContext context,
  WidgetRef ref,
  Future<void> Function() geste,
  String succes, {
  String? ticketId,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  String? echec;
  try {
    await geste();
  } catch (e) {
    echec = switch (classerRefusSupport(e)) {
      RefusSupport.permission => l10n.modoErrDenied,
      RefusSupport.conflit => l10n.modoErrConflict,
      RefusSupport.saisie => l10n.modoErrInput(detailSupport(e)),
      _ => l10n.modoErrGeneric(detailSupport(e)),
    };
  }
  ref.invalidate(ticketsAdminProvider);
  ref.invalidate(echeancesProvider);
  if (ticketId != null) ref.invalidate(notesTicketProvider(ticketId));
  messenger.showSnackBar(SnackBar(
    behavior: SnackBarBehavior.floating,
    backgroundColor: echec == null ? AdminColors.statusGreen : AdminColors.statusRed,
    content: Text(echec ?? succes),
  ));
  return echec == null;
}

/// Une saisie obligatoire dans un dialogue ; `null` si annulée.
Future<String?> _saisir(
  BuildContext context, {
  required String titre,
  required String libelle,
  required String confirmer,
  int max = 2000,
}) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        title: Text(titre),
        content: TextField(
          controller: controller,
          onChanged: (_) => setLocal(() {}),
          maxLines: 4,
          maxLength: max,
          decoration: InputDecoration(
            labelText: libelle,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppLocalizations.of(ctx)!.adminCancelAction)),
          ElevatedButton(
            onPressed: controller.text.trim().isEmpty
                ? null
                : () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(confirmer),
          ),
        ],
      ),
    ),
  ).whenComplete(controller.dispose);
}

// ═══ La carte d'un ticket ══════════════════════════════════════════════════

class _CarteTicket extends ConsumerStatefulWidget {
  const _CarteTicket({super.key, required this.ticket});
  final TicketAdmin ticket;

  @override
  ConsumerState<_CarteTicket> createState() => _CarteTicketState();
}

class _CarteTicketState extends ConsumerState<_CarteTicket> {
  final _reponse = TextEditingController();
  final _note = TextEditingController();

  @override
  void dispose() {
    _reponse.dispose();
    _note.dispose();
    super.dispose();
  }

  TicketAdmin get t => widget.ticket;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final moi = FirebaseAuth.instance.currentUser?.uid;
    final aMoi = t.responsable != null && t.responsable == moi;
    final aUnAutre = t.responsable != null && !aMoi;
    final peutAssigner =
        ref.watch(permissionSupportProvider('support.tickets.assign')).valueOrNull ?? false;
    final peutRepondre =
        ref.watch(permissionSupportProvider('support.tickets.reply')).valueOrNull ?? false;
    final peutClore =
        ref.watch(permissionSupportProvider('support.tickets.close')).valueOrNull ?? false;
    final peutEscalader =
        ref.watch(permissionSupportProvider('support.tickets.escalate')).valueOrNull ?? false;
    final peutLever =
        ref.watch(permissionSupportProvider('support.tickets.escalation.resolve')).valueOrNull ??
            false;
    final echeance = ref.watch(echeancesProvider).valueOrNull?[t.id];
    final acts = ref.read(supportAdminActionsProvider);

    return Container(
      decoration: BoxDecoration(
        color: AdminColors.surface,
        border: Border.all(color: AdminColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.all(16),
        shape: const Border(),
        collapsedShape: const Border(),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        onExpansionChanged: (ouvert) {
          // Ouvrir le ticket vaut lecture ; un échec ici n'empêche rien.
          if (ouvert && t.nonLuDuMembre && peutRepondre) {
            unawaited(acts
                .marquerLu(t.id)
                .then((_) => ref.invalidate(ticketsAdminProvider), onError: (_) {}));
          }
        },
        title: Text(t.sujet.isEmpty ? '—' : t.sujet,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DesignBadge(_libelleStatut(l10n, t.statut), tone: _tonStatut(t.statut)),
              if (t.escalade)
                DesignBadge(l10n.supSlaEscalatedBadge, tone: DesignBadgeTone.failed),
              if (echeance != null && echeance.enRetard)
                DesignBadge(l10n.supSlaLateBadge, tone: DesignBadgeTone.failed),
              if (t.priorite == 'high' || t.priorite == 'urgent')
                DesignBadge(_libellePriorite(l10n, t.priorite),
                    tone: DesignBadgeTone.failed),
              Text(_libelleCategorie(l10n, t.categorie),
                  style: const TextStyle(fontSize: 12, color: AdminColors.text3)),
              Text(
                  l10n.supAdmMember(t.userName.isEmpty
                      ? l10n.supAdmMemberUnnamed
                      : t.userName),
                  style: const TextStyle(fontSize: 12, color: AdminColors.text3)),
              Text(l10n.supAdmUpdated(_date(t.misAJourLe)),
                  style: const TextStyle(fontSize: 12, color: AdminColors.text3)),
              if (t.nonLuDuMembre)
                Text(l10n.supAdmUnread,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AdminColors.actionBlue)),
            ],
          ),
        ),
        children: [
          Text(
            t.responsable == null
                ? l10n.supAdmUnassigned
                : (aMoi ? l10n.supAdmAssignedToYou : l10n.supAdmAssignedToOther),
            style: const TextStyle(fontSize: 12, color: AdminColors.text3),
          ),
          if (t.escalade && t.escaladeMotif != null) ...[
            const SizedBox(height: 4),
            Text(l10n.supSlaEscalationReason(t.escaladeMotif!),
                style: const TextStyle(fontSize: 13, color: AdminColors.statusRed)),
          ],
          if (echeance?.premiereAvant != null)
            Text(l10n.supSlaDueFirst(_date(echeance!.premiereAvant)),
                style: TextStyle(
                    fontSize: 12,
                    color: echeance.premiereEnRetard ? AdminColors.statusRed : AdminColors.text3)),
          if (echeance?.resolutionAvant != null)
            Text(l10n.supSlaDueResolution(_date(echeance!.resolutionAvant)),
                style: TextStyle(
                    fontSize: 12,
                    color: echeance.resolutionEnRetard ? AdminColors.statusRed : AdminColors.text3)),
          if (t.resolution != null) ...[
            const SizedBox(height: 4),
            Text(l10n.supAdmResolution(t.resolution!),
                style: const TextStyle(fontSize: 13)),
          ],
          const SizedBox(height: 16),
          _titre(l10n.supAdmConversation),
          for (final m in t.messages) _Bulle(message: m),
          if (t.enCours && peutRepondre) ...[
            const SizedBox(height: 8),
            _ChoixModele(
              categorie: t.categorie,
              onChoisi: (texte) => setState(() => _reponse.text = texte),
            ),
            TextField(
              controller: _reponse,
              onChanged: (_) => setState(() {}),
              maxLines: 3,
              maxLength: 4000,
              decoration: InputDecoration(
                labelText: l10n.supAdmReplyLabel,
                helperText: l10n.supAdmReplyHint,
                border: const OutlineInputBorder(),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _reponse.text.trim().isEmpty
                    ? null
                    : () async {
                        final ok = await _lancer(
                          context,
                          ref,
                          () => acts.repondre(t.id, _reponse.text.trim()),
                          l10n.supAdmReplySent,
                        );
                        if (ok) _reponse.clear();
                      },
                icon: const Icon(Icons.send_rounded, size: 16),
                label: Text(l10n.supAdmSendReply),
              ),
            ),
          ] else if (t.statut == 'open' && peutRepondre)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(l10n.supAdmMustTake,
                  style: const TextStyle(fontSize: 12, color: AdminColors.text3)),
            ),
          const SizedBox(height: 16),
          _NotesInternes(
            ticketId: t.id,
            peutNoter: peutRepondre,
            controller: _note,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (t.statut != 'resolved' && t.statut != 'closed' && peutAssigner)
                SizedBox(
                  width: 190,
                  child: DropdownButtonFormField<String>(
                    initialValue: t.priorite,
                    isDense: true,
                    decoration: InputDecoration(
                      labelText: l10n.supAdmPriorityLabel,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      for (final p in const ['low', 'normal', 'high', 'urgent'])
                        DropdownMenuItem(value: p, child: Text(_libellePriorite(l10n, p))),
                    ],
                    onChanged: (v) {
                      if (v == null || v == t.priorite) return;
                      unawaited(_lancer(context, ref, () => acts.prioriser(t.id, v), l10n.supAdmDone));
                    },
                  ),
                ),
              if (t.statut == 'open' && peutAssigner)
                ElevatedButton.icon(
                  onPressed: () => _lancer(
                      context, ref, () => acts.transitionner(t.id, 'in_progress'), l10n.supAdmDone),
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                  label: Text(l10n.supAdmTake),
                ),
              if (t.statut == 'in_progress' && aUnAutre && peutAssigner)
                OutlinedButton.icon(
                  onPressed: () => _avecMotif(l10n.supAdmReasonTakeOver, l10n.supAdmTakeOver,
                      (n) => acts.transitionner(t.id, 'in_progress', note: n)),
                  icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                  label: Text(l10n.supAdmTakeOver),
                ),
              if (t.statut == 'in_progress' && peutRepondre)
                ElevatedButton.icon(
                  onPressed: () => _avecMotif(l10n.supAdmReasonResolve, l10n.supAdmResolve,
                      (n) => acts.transitionner(t.id, 'resolved', note: n)),
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: Text(l10n.supAdmResolve),
                ),
              if ((t.statut == 'in_progress' || t.statut == 'resolved') && peutClore)
                OutlinedButton.icon(
                  onPressed: () => _avecMotif(l10n.supAdmReasonClose, l10n.supAdmClose,
                      (n) => acts.transitionner(t.id, 'closed', note: n)),
                  icon: const Icon(Icons.lock_outline_rounded, size: 16),
                  label: Text(l10n.supAdmClose),
                ),
              if (t.statut != 'resolved' && t.statut != 'closed' && !t.escalade && peutEscalader)
                OutlinedButton.icon(
                  onPressed: () => _avecMotif(l10n.supSlaEscalateReason, l10n.supSlaEscalate,
                      (n) => acts.escalader(t.id, n)),
                  icon: const Icon(Icons.priority_high_rounded, size: 16),
                  label: Text(l10n.supSlaEscalate),
                ),
              if (t.escalade && peutLever)
                OutlinedButton.icon(
                  onPressed: () => _lancer(
                      context, ref, () => acts.leverEscalade(t.id), l10n.supAdmDone),
                  icon: const Icon(Icons.flag_outlined, size: 16),
                  label: Text(l10n.supSlaEscalationLift),
                ),
              if (t.statut == 'resolved' && peutAssigner)
                OutlinedButton.icon(
                  onPressed: () => _avecMotif(l10n.supAdmReasonReopen, l10n.supAdmReopen,
                      (n) => acts.transitionner(t.id, 'in_progress', note: n)),
                  icon: const Icon(Icons.undo_rounded, size: 16),
                  label: Text(l10n.supAdmReopen),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _avecMotif(
    String question,
    String confirmer,
    Future<void> Function(String) geste,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final texte = await _saisir(context, titre: confirmer, libelle: question, confirmer: confirmer);
    if (texte == null || !mounted) return;
    await _lancer(context, ref, () => geste(texte), l10n.supAdmDone);
  }
}

Widget _titre(String texte) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(texte,
          style: const TextStyle(
              fontWeight: FontWeight.w700, fontSize: 14, color: AdminColors.text)),
    );

class _Bulle extends StatelessWidget {
  const _Bulle({required this.message});
  final MessageTicket message;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final support = message.deSupport;
    return Align(
      alignment: support ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: support ? AdminColors.actionBlueBg : AdminColors.surfaceAlt,
          border: Border.all(color: AdminColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${support ? l10n.supAdmFromSupport : l10n.supAdmFromMember} · ${_date(message.date)}',
              style: const TextStyle(fontSize: 11, color: AdminColors.text3),
            ),
            const SizedBox(height: 4),
            SelectableText(message.contenu, style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

/// Les notes internes : une zone ambre, hors du fil du membre.
class _NotesInternes extends ConsumerWidget {
  const _NotesInternes({
    required this.ticketId,
    required this.peutNoter,
    required this.controller,
  });

  final String ticketId;
  final bool peutNoter;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final notes = ref.watch(notesTicketProvider(ticketId));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AdminColors.statusAmberBg,
        border: Border.all(color: AdminColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${l10n.supAdmNotesTitle} — ${l10n.supAdmNotesHint}',
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AdminColors.statusAmberStrong)),
          const SizedBox(height: 8),
          notes.when(
            loading: () => const LinearProgressIndicator(minHeight: 2),
            error: (e, _) => Text(l10n.supAdmLoadError(detailSupport(e)),
                style: const TextStyle(color: AdminColors.statusRed, fontSize: 12)),
            data: (liste) => liste.isEmpty
                ? Text(l10n.supAdmNotesEmpty,
                    style: const TextStyle(fontSize: 12, color: AdminColors.text3))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final n in liste)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_date(n.date),
                                  style: const TextStyle(
                                      fontSize: 11, color: AdminColors.text3)),
                              SelectableText(n.texte,
                                  style: const TextStyle(fontSize: 13)),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
          if (peutNoter) ...[
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              maxLines: 2,
              maxLength: 4000,
              decoration: InputDecoration(
                labelText: l10n.supAdmNoteLabel,
                filled: true,
                fillColor: AdminColors.surface,
                border: const OutlineInputBorder(),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                onPressed: () async {
                  final texte = controller.text.trim();
                  if (texte.isEmpty) return;
                  final ok = await _lancer(
                    context,
                    ref,
                    () => ref.read(supportAdminActionsProvider).noter(ticketId, texte),
                    l10n.supAdmNoteAdded,
                    ticketId: ticketId,
                  );
                  if (ok) controller.clear();
                },
                child: Text(l10n.supAdmAddNote),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══ Le choix d'un modèle ═════════════════════════════════════════════════

/// Un modèle remplace le brouillon de réponse ; l'agent le relit avant d'envoyer.
/// Les modèles de la catégorie du ticket, et ceux sans catégorie.
class _ChoixModele extends ConsumerWidget {
  const _ChoixModele({required this.categorie, required this.onChoisi});
  final String categorie;
  final void Function(String texte) onChoisi;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final modeles = ref.watch(modelesReponseProvider).valueOrNull ?? const <ModeleReponse>[];
    final proposes =
        modeles.where((m) => m.categorie == null || m.categorie == categorie).toList();
    if (proposes.isEmpty) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: PopupMenuButton<ModeleReponse>(
        tooltip: l10n.supSlaInsertTemplate,
        onSelected: (m) => onChoisi(m.texte),
        itemBuilder: (_) => [
          for (final m in proposes) PopupMenuItem(value: m, child: Text(m.titre)),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.article_outlined, size: 16, color: AdminColors.actionBlue),
            const SizedBox(width: 6),
            Text(l10n.supSlaInsertTemplate,
                style: const TextStyle(fontSize: 13, color: AdminColors.actionBlue)),
          ]),
        ),
      ),
    );
  }
}
