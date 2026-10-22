import 'package:diaspo_niger/core/theme/admin_colors.dart';
import 'package:diaspo_niger/core/theme/design_kit.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/dossier_moderation_provider.dart';

/// Les deux sections du dossier de signalement : demandes d'informations
/// (référentiel § 6.1) et recours (§ 6.8). Chaque geste appelle une RPC ;
/// le serveur est l'autorité, les boutons ne font que refléter ce qu'il
/// acceptera (permission lue en base, statut du dossier).

String _jours(AppLocalizations l10n, DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Affiche le résultat d'un geste : succès, ou le refus expliqué. Rend vrai
/// seulement si le serveur a accepté.
Future<bool> _executer(
  BuildContext context,
  WidgetRef ref,
  Future<void> Function() geste,
  String succes, {
  required List<ProviderOrFamily> aRecharger,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  String? echec;
  try {
    await geste();
  } catch (e) {
    echec = switch (classerRefus(e)) {
      RefusModeration.permission => l10n.modoErrDenied,
      RefusModeration.conflit => l10n.modoErrConflict,
      RefusModeration.saisie => l10n.modoErrInput(detailRefus(e)),
      _ => l10n.modoErrGeneric(detailRefus(e)),
    };
  }
  // Un refus peut venir d'un dossier changé par quelqu'un d'autre : on relit
  // dans tous les cas pour que l'écran dise ce qui est vrai.
  for (final p in aRecharger) {
    ref.invalidate(p);
  }
  messenger.showSnackBar(SnackBar(
    behavior: SnackBarBehavior.floating,
    backgroundColor: echec == null ? AdminColors.statusGreen : AdminColors.statusRed,
    content: Text(echec ?? succes),
  ));
  return echec == null;
}

Widget _titre(String texte) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        texte,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 14,
          color: AdminColors.text,
        ),
      ),
    );

Widget _bloc({required List<Widget> children}) => Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AdminColors.surfaceAlt,
        border: Border.all(color: AdminColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );

Widget _etat(Object erreur, AppLocalizations l10n) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        l10n.modoLoadError(detailRefus(erreur)),
        style: const TextStyle(color: AdminColors.statusRed, fontSize: 13),
      ),
    );

// ═══ Demandes d'informations ═══════════════════════════════════════════════

class DemandesInformationsSection extends ConsumerWidget {
  const DemandesInformationsSection({
    super.key,
    required this.reportId,
    required this.reportStatus,
    required this.hasReportedUser,
  });

  final String reportId;
  final String reportStatus;
  final bool hasReportedUser;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final demandes = ref.watch(demandesInformationsProvider(reportId));
    final peutRediger =
        ref.watch(adminAPermissionProvider('moderation.info_requests.create')).valueOrNull ??
            false;
    final peutEnvoyer =
        ref.watch(adminAPermissionProvider('moderation.info_requests.send')).valueOrNull ??
            false;
    final peutConsigner =
        ref.watch(adminAPermissionProvider('moderation.reports.review')).valueOrNull ?? false;
    final enExamen = reportStatus == 'reviewing';

    return demandes.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(minHeight: 2),
      ),
      error: (e, _) => _etat(e, l10n),
      data: (liste) {
        // Rien à montrer ni à faire : la section n'encombre pas le dossier.
        if (liste.isEmpty && !(enExamen && peutRediger)) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _titre(l10n.modoInfoTitle),
            if (liste.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(l10n.modoInfoEmpty,
                    style: const TextStyle(color: AdminColors.text3, fontSize: 13)),
              ),
            for (final d in liste)
              _CarteDemande(
                demande: d,
                peutEnvoyer: peutEnvoyer && enExamen,
                peutConsigner: peutConsigner && enExamen,
                reportId: reportId,
              ),
            if (enExamen && peutRediger)
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => _redigerDemande(context, ref),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: Text(l10n.modoInfoNew),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(l10n.modoInfoNoChannel,
                  style: const TextStyle(color: AdminColors.text3, fontSize: 12)),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Future<void> _redigerDemande(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final saisie = await showDialog<({String kind, String questions, int jours})>(
      context: context,
      builder: (_) => _DialogueDemande(hasReportedUser: hasReportedUser),
    );
    if (saisie == null || !context.mounted) return;
    await _executer(
      context,
      ref,
      () => ref.read(dossierModerationActionsProvider).redigerDemande(
            reportId: reportId,
            destinataire: saisie.kind,
            questions: saisie.questions,
            echeance: DateTime.now().add(Duration(days: saisie.jours)),
          ),
      l10n.modoInfoDraftSaved,
      aRecharger: [demandesInformationsProvider(reportId)],
    );
  }
}

class _CarteDemande extends ConsumerWidget {
  const _CarteDemande({
    required this.demande,
    required this.peutEnvoyer,
    required this.peutConsigner,
    required this.reportId,
  });

  final DemandeInformations demande;
  final bool peutEnvoyer;
  final bool peutConsigner;
  final String reportId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final d = demande;
    final (libelle, ton) = switch (d.status) {
      'draft' => (l10n.modoInfoStatusDraft, DesignBadgeTone.archived),
      'sent' when d.enRetard => (l10n.modoInfoStatusOverdue, DesignBadgeTone.failed),
      'sent' => (l10n.modoInfoStatusSent, DesignBadgeTone.review),
      'answered' => (l10n.modoInfoStatusAnswered, DesignBadgeTone.verified),
      _ => (l10n.modoInfoStatusCancelled, DesignBadgeTone.archived),
    };
    return _bloc(children: [
      Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          DesignBadge(libelle, tone: ton),
          Text(
            d.recipientKind == 'reporter'
                ? l10n.modoInfoRecipientReporter
                : l10n.modoInfoRecipientReported,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          Text(l10n.modoInfoDue(_jours(l10n, d.dueAt)),
              style: const TextStyle(color: AdminColors.text3, fontSize: 12)),
        ],
      ),
      const SizedBox(height: 8),
      SelectableText(d.questions, style: const TextStyle(fontSize: 13)),
      if (d.response != null) ...[
        const SizedBox(height: 8),
        Text(l10n.modoInfoResponseLabel,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
        SelectableText(d.response!, style: const TextStyle(fontSize: 13)),
      ],
      if (d.status == 'draft' && peutEnvoyer) ...[
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: () => _envoyer(context, ref),
          icon: const Icon(Icons.send_rounded, size: 16),
          label: Text(l10n.modoInfoSend),
        ),
      ],
      if (d.status == 'sent' && peutConsigner) ...[
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _consigner(context, ref),
          icon: const Icon(Icons.reply_rounded, size: 16),
          label: Text(l10n.modoInfoRecordResponse),
        ),
      ],
    ]);
  }

  Future<void> _envoyer(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    // Aperçu final : le texte exact, avant qu'il ne parte (§ 6.1 pas 6).
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.modoInfoSendTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.modoInfoSendBody),
              const SizedBox(height: 12),
              SelectableText(demande.questions),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.adminCancelAction)),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.modoInfoSend)),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await _executer(
      context,
      ref,
      () => ref.read(dossierModerationActionsProvider).envoyerDemande(demande.id),
      l10n.modoInfoSentOk,
      aRecharger: [demandesInformationsProvider(reportId)],
    );
  }

  Future<void> _consigner(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final texte = await _saisirTexte(
      context,
      titre: l10n.modoInfoRecordResponse,
      libelle: l10n.modoInfoResponseLabel,
      confirmer: l10n.adminConfirmAction,
      max: 4000,
    );
    if (texte == null || !context.mounted) return;
    await _executer(
      context,
      ref,
      () => ref.read(dossierModerationActionsProvider).consignerReponse(demande.id, texte),
      l10n.modoInfoResponseSaved,
      aRecharger: [demandesInformationsProvider(reportId)],
    );
  }
}

class _DialogueDemande extends StatefulWidget {
  const _DialogueDemande({required this.hasReportedUser});
  final bool hasReportedUser;

  @override
  State<_DialogueDemande> createState() => _DialogueDemandeState();
}

class _DialogueDemandeState extends State<_DialogueDemande> {
  final _questions = TextEditingController();
  String _kind = 'reporter';
  int _jours = 7;

  @override
  void dispose() {
    _questions.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final valide = _questions.text.trim().length >= 10;
    return AlertDialog(
      title: Text(l10n.modoInfoNew),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _kind,
              isExpanded: true,
              decoration: InputDecoration(labelText: l10n.modoInfoRecipientLabel),
              items: [
                DropdownMenuItem(
                    value: 'reporter', child: Text(l10n.modoInfoRecipientReporter)),
                // Sans membre signalé identifié, le serveur refuse : on
                // n'offre pas ce qu'il refusera.
                if (widget.hasReportedUser)
                  DropdownMenuItem(
                      value: 'reported', child: Text(l10n.modoInfoRecipientReported)),
              ],
              onChanged: (v) => setState(() => _kind = v ?? _kind),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _questions,
              onChanged: (_) => setState(() {}),
              maxLines: 5,
              maxLength: 2000,
              decoration: InputDecoration(
                labelText: l10n.modoInfoQuestionsLabel,
                hintText: l10n.modoInfoQuestionsHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              initialValue: _jours,
              decoration: InputDecoration(labelText: l10n.modoInfoDueLabel),
              items: [
                for (final j in const [3, 7, 14, 30])
                  DropdownMenuItem(value: j, child: Text(l10n.modoInfoDueDays(j))),
              ],
              onChanged: (v) => setState(() => _jours = v ?? _jours),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: Text(l10n.adminCancelAction)),
        ElevatedButton(
          onPressed: valide
              ? () => Navigator.pop(
                  context, (kind: _kind, questions: _questions.text.trim(), jours: _jours))
              : null,
          child: Text(l10n.modoInfoCreate),
        ),
      ],
    );
  }
}

// ═══ Recours ═══════════════════════════════════════════════════════════════

class RecoursSection extends ConsumerWidget {
  const RecoursSection({
    super.key,
    required this.reportId,
    required this.reportStatus,
  });

  final String reportId;
  final String reportStatus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final recours = ref.watch(recoursDuDossierProvider(reportId));
    final peutEnregistrer =
        ref.watch(adminAPermissionProvider('moderation.appeals.review')).valueOrNull ?? false;
    final peutTrancher =
        ref.watch(adminAPermissionProvider('moderation.appeals.decide')).valueOrNull ?? false;
    final moi = FirebaseAuth.instance.currentUser?.uid;

    return recours.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) {
        // Sans `moderation.appeals.view`, la lecture est refusée : ce n'est
        // pas une panne, la section n'a simplement pas lieu d'être.
        if (classerRefus(e) == RefusModeration.permission) return const SizedBox.shrink();
        return _etat(e, l10n);
      },
      data: (liste) {
        final ouvert = liste.any((r) => r.ouvert);
        final peutOuvrir = reportStatus == 'resolved' && peutEnregistrer && !ouvert;
        if (liste.isEmpty && !peutOuvrir) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _titre(l10n.modoAppealTitle),
            for (final r in liste)
              _CarteRecours(
                recours: r,
                reportId: reportId,
                moi: moi,
                peutPrendre: peutEnregistrer,
                peutTrancher: peutTrancher,
              ),
            if (peutOuvrir)
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => _enregistrer(context, ref),
                  icon: const Icon(Icons.gavel_rounded, size: 16),
                  label: Text(l10n.modoAppealRegister),
                ),
              ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Future<void> _enregistrer(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final texte = await _saisirTexte(
      context,
      titre: l10n.modoAppealRegister,
      libelle: l10n.modoAppealArgumentLabel,
      confirmer: l10n.adminConfirmAction,
      max: 4000,
      min: 10,
    );
    if (texte == null || !context.mounted) return;
    await _executer(
      context,
      ref,
      () => ref.read(dossierModerationActionsProvider).enregistrerRecours(reportId, texte),
      l10n.modoAppealRegistered,
      aRecharger: [recoursDuDossierProvider(reportId)],
    );
  }
}

class _CarteRecours extends ConsumerWidget {
  const _CarteRecours({
    required this.recours,
    required this.reportId,
    required this.moi,
    required this.peutPrendre,
    required this.peutTrancher,
  });

  final RecoursModeration recours;
  final String reportId;
  final String? moi;
  final bool peutPrendre;
  final bool peutTrancher;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final r = recours;
    final (libelle, ton) = switch (r.status) {
      'received' => (l10n.modoAppealStatusReceived, DesignBadgeTone.review),
      'under_review' => (l10n.modoAppealStatusUnderReview, DesignBadgeTone.review),
      'upheld' => (l10n.modoAppealOutcomeUpheld, DesignBadgeTone.archived),
      'reduced' => (l10n.modoAppealOutcomeReduced, DesignBadgeTone.verified),
      'annulled' => (l10n.modoAppealOutcomeAnnulled, DesignBadgeTone.verified),
      _ => (l10n.modoAppealOutcomeSentBack, DesignBadgeTone.review),
    };
    // Séparation des tâches : le serveur refuse ; l'écran l'explique plutôt
    // que d'offrir un bouton qui échouera.
    final estLeDecideur = moi != null && moi == r.contestedDecider;
    final estLExaminateur = moi != null && moi == r.reviewerId;

    return _bloc(children: [
      DesignBadge(libelle, tone: ton),
      const SizedBox(height: 8),
      Text(
        l10n.modoAppealContested(r.contestedAction ?? '—', r.contestedReason ?? '—'),
        style: const TextStyle(color: AdminColors.text3, fontSize: 12),
      ),
      const SizedBox(height: 8),
      SelectableText(r.argument, style: const TextStyle(fontSize: 13)),
      if (r.decisionNote != null) ...[
        const SizedBox(height: 8),
        Text(l10n.modoAppealNoteLabel,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
        SelectableText(r.decisionNote!, style: const TextStyle(fontSize: 13)),
      ],
      if (r.ouvert && estLeDecideur) ...[
        const SizedBox(height: 8),
        Text(l10n.modoAppealSelfConflict,
            style: const TextStyle(color: AdminColors.statusAmber, fontSize: 12)),
      ],
      if (r.status == 'received' && peutPrendre && !estLeDecideur) ...[
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: () => _executer(
            context,
            ref,
            () => ref.read(dossierModerationActionsProvider).prendreRecours(r.id),
            l10n.modoAppealTaken,
            aRecharger: [recoursDuDossierProvider(reportId)],
          ),
          icon: const Icon(Icons.play_arrow_rounded, size: 16),
          label: Text(l10n.modoAppealTake),
        ),
      ],
      if (r.status == 'under_review' && peutTrancher && estLExaminateur) ...[
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: () => _trancher(context, ref),
          icon: const Icon(Icons.gavel_rounded, size: 16),
          label: Text(l10n.modoAppealDecide),
        ),
      ],
    ]);
  }

  Future<void> _trancher(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final choix = await showDialog<({String issue, String motif})>(
      context: context,
      builder: (_) => const _DialogueIssue(),
    );
    if (choix == null || !context.mounted) return;
    await _executer(
      context,
      ref,
      () => ref
          .read(dossierModerationActionsProvider)
          .trancherRecours(recours.id, choix.issue, choix.motif),
      l10n.modoAppealDecided,
      aRecharger: [recoursDuDossierProvider(reportId)],
    );
  }
}

class _DialogueIssue extends StatefulWidget {
  const _DialogueIssue();

  @override
  State<_DialogueIssue> createState() => _DialogueIssueState();
}

class _DialogueIssueState extends State<_DialogueIssue> {
  final _motif = TextEditingController();
  String? _issue;

  @override
  void dispose() {
    _motif.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final libelles = {
      'upheld': l10n.modoAppealOutcomeUpheld,
      'reduced': l10n.modoAppealOutcomeReduced,
      'annulled': l10n.modoAppealOutcomeAnnulled,
      'sent_back': l10n.modoAppealOutcomeSentBack,
    };
    return AlertDialog(
      title: Text(l10n.modoAppealDecide),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _issue,
              isExpanded: true,
              decoration: InputDecoration(labelText: l10n.modoAppealOutcomeLabel),
              items: [
                for (final e in libelles.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) => setState(() => _issue = v),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _motif,
              onChanged: (_) => setState(() {}),
              maxLines: 4,
              maxLength: 2000,
              decoration: InputDecoration(
                labelText: l10n.modoAppealNoteLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            Text(l10n.modoAppealOutcomeNote,
                style: const TextStyle(color: AdminColors.text3, fontSize: 12)),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: Text(l10n.adminCancelAction)),
        ElevatedButton(
          onPressed: _issue == null || _motif.text.trim().isEmpty
              ? null
              : () => Navigator.pop(context, (issue: _issue!, motif: _motif.text.trim())),
          child: Text(l10n.adminConfirmAction),
        ),
      ],
    );
  }
}

/// Une saisie libre obligatoire, dans un dialogue.
Future<String?> _saisirTexte(
  BuildContext context, {
  required String titre,
  required String libelle,
  required String confirmer,
  required int max,
  int min = 1,
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
          maxLines: 5,
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
            onPressed: controller.text.trim().length < min
                ? null
                : () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(confirmer),
          ),
        ],
      ),
    ),
  ).whenComplete(controller.dispose);
}
