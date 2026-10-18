import 'dart:async';

import 'package:diaspo_niger/core/theme/admin_colors.dart';
import 'package:diaspo_niger/core/theme/design_kit.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/demarches_admin_provider.dart';
import '../providers/dossier_moderation_provider.dart'
    show adminAPermissionProvider, classerRefus, detailRefus, RefusModeration;
import '../widgets/editeur_demarche.dart';

/// Démarches consulaires : la file de rédaction, relecture et publication
/// (spécification d'interfaces § 14, référentiel § 9).
///
/// Les boutons reflètent le statut du brouillon, l'auteur et la permission ;
/// le serveur reste l'autorité (séparation auteur / approbateur, version de
/// base) et ses refus s'affichent en clair.
class AdminDemarchesScreen extends ConsumerStatefulWidget {
  const AdminDemarchesScreen({super.key});

  @override
  ConsumerState<AdminDemarchesScreen> createState() => _AdminDemarchesScreenState();
}

enum _Vue { toutes, atraiter, publiees, depubliees, enRetard }

class _AdminDemarchesScreenState extends ConsumerState<AdminDemarchesScreen> {
  _Vue _vue = _Vue.toutes;
  String _terme = '';

  bool _garde(LigneDemarche l) => switch (_vue) {
        _Vue.toutes => true,
        _Vue.atraiter => l.brouillon != null,
        _Vue.publiees => l.live?.publiee ?? false,
        _Vue.depubliees => l.live != null && !l.live!.publiee,
        _Vue.enRetard => (l.live?.publiee ?? false) && l.live!.revisionEnRetard,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final peutVoir = ref.watch(adminAPermissionProvider('consular.view'));
    final peutEditer =
        ref.watch(adminAPermissionProvider('consular.procedures.edit')).valueOrNull ?? false;
    final lignes = ref.watch(lignesDemarchesProvider);

    if (peutVoir.valueOrNull == false) {
      return Center(child: Text(l10n.demAdmNoAccess));
    }

    final vues = {
      _Vue.toutes: l10n.demAdmFilterAll,
      _Vue.atraiter: l10n.demAdmFilterWork,
      _Vue.publiees: l10n.demAdmFilterPublished,
      _Vue.depubliees: l10n.demAdmFilterUnpublished,
      _Vue.enRetard: l10n.demAdmFilterOverdue,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.demAdmTitle,
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.w700, color: AdminColors.text)),
                const SizedBox(height: 4),
                Text(l10n.demAdmSubtitle, style: const TextStyle(color: AdminColors.text3)),
              ],
            ),
          ),
          IconButton(
            tooltip: l10n.demAdmRetry,
            onPressed: () => ref.invalidate(lignesDemarchesProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
          if (peutEditer)
            ElevatedButton.icon(
              onPressed: () => _editer(null),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(l10n.demAdmNew),
            ),
        ]),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final e in vues.entries)
              ChoiceChip(
                label: Text(e.value),
                selected: _vue == e.key,
                selectedColor: AdminColors.actionBlueBg,
                onSelected: (_) => setState(() => _vue = e.key),
              ),
            SizedBox(
              width: 260,
              child: TextField(
                onChanged: (v) => setState(() => _terme = v.trim().toLowerCase()),
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  hintText: l10n.demAdmSearchHint,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: lignes.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(l10n.demAdmLoadError(detailRefus(e)),
                    style: const TextStyle(color: AdminColors.statusRed)),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => ref.invalidate(lignesDemarchesProvider),
                  child: Text(l10n.demAdmRetry),
                ),
              ]),
            ),
            data: (liste) {
              final vues = [
                for (final l in liste)
                  if (_garde(l) &&
                      (_terme.isEmpty ||
                          l.titre.toLowerCase().contains(_terme) ||
                          l.id.contains(_terme)))
                    l,
              ];
              if (vues.isEmpty) {
                return Center(
                    child: Text(l10n.demAdmEmpty,
                        style: const TextStyle(color: AdminColors.text3)));
              }
              return ListView.separated(
                itemCount: vues.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) => _CarteDemarche(
                  key: ValueKey(vues[i].id),
                  ligne: vues[i],
                  onEditer: () => _editer(vues[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _editer(LigneDemarche? ligne) async {
    final rubriques = await ref.read(rubriquesDemarchesProvider.future).catchError(
          (_) => const <RubriqueDemarche>[],
        );
    if (!mounted) return;
    final res = await showDialog<ResultatEditeurDemarche>(
      context: context,
      barrierDismissible: false,
      builder: (_) => EditeurDemarche(ligne: ligne, rubriques: rubriques),
    );
    if (res == null || !mounted) return;
    await _lancer(
      context,
      ref,
      () => ref.read(demarchesAdminActionsProvider).enregistrer(
            demarcheId: res.demarcheId,
            contenu: res.contenu,
            sourceUrl: res.sourceUrl,
            sourcePublisher: res.sourcePublisher,
            verifieLe: res.verifieLe,
            prochaineRevision: res.prochaineRevision,
            motif: res.motif,
          ),
      AppLocalizations.of(context)!.demAdmDraftSaved,
    );
  }
}

/// Exécute [geste], relit la file, dit le résultat. Vrai seulement si le
/// serveur a accepté. On relit même après un refus : il peut venir d'un
/// texte qu'un autre administrateur vient de faire avancer.
Future<bool> _lancer(
  BuildContext context,
  WidgetRef ref,
  Future<void> Function() geste,
  String succes, {
  String Function()? succesCalcule,
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
  ref.invalidate(lignesDemarchesProvider);
  messenger.showSnackBar(SnackBar(
    behavior: SnackBarBehavior.floating,
    backgroundColor: echec == null ? AdminColors.statusGreen : AdminColors.statusRed,
    content: Text(echec ?? (succesCalcule?.call() ?? succes)),
  ));
  return echec == null;
}

Future<String?> _saisir(
  BuildContext context, {
  required String titre,
  required String libelle,
  String? avertissement,
  bool obligatoire = true,
}) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) {
      final l10n = AppLocalizations.of(ctx)!;
      return StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(titre),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (avertissement != null) ...[
                Text(avertissement,
                    style: const TextStyle(fontSize: 12, color: AdminColors.statusAmberStrong)),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: controller,
                onChanged: (_) => setLocal(() {}),
                maxLines: 3,
                maxLength: 1000,
                decoration: InputDecoration(
                    labelText: libelle, border: const OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: Text(l10n.demAdmCancel)),
            ElevatedButton(
              onPressed: obligatoire && controller.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(ctx, controller.text.trim()),
              child: Text(l10n.demAdmConfirm),
            ),
          ],
        ),
      );
    },
  ).whenComplete(controller.dispose);
}

String _jour(DateTime? d) => d == null
    ? '—'
    : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

class _CarteDemarche extends ConsumerWidget {
  const _CarteDemarche({super.key, required this.ligne, required this.onEditer});

  final LigneDemarche ligne;
  final VoidCallback onEditer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final live = ligne.live;
    final b = ligne.brouillon;
    final moi = FirebaseAuth.instance.currentUser?.uid;
    final estAuteur = b != null && b.auteur == moi;
    bool perm(String k) => ref.watch(adminAPermissionProvider(k)).valueOrNull ?? false;
    final peutEditer = perm('consular.procedures.edit');
    final peutApprouver = perm('consular.procedures.approve');
    final peutPublier = perm('consular.procedures.publish');
    final acts = ref.read(demarchesAdminActionsProvider);

    final contenu = b?.contenu ?? live?.contenu ?? const <String, dynamic>{};
    final pieces = (contenu['pieces'] as List?) ?? const [];
    final avert = (contenu['avertissements'] as List?) ?? const [];
    final cout = Map<String, dynamic>.from((contenu['cout'] as Map?) ?? {});
    final sourceUrl = b?.sourceUrl ?? live?.sourceUrl;
    final editeur = b?.sourcePublisher ?? live?.sourcePublisher;
    final verifieLe = b?.verifieLe ?? live?.verifieLe;

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
        title: Text(ligne.titre,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (live != null)
                DesignBadge(
                  live.publiee ? l10n.demAdmStatusPublished : l10n.demAdmStatusUnpublished,
                  tone: live.publiee ? DesignBadgeTone.verified : DesignBadgeTone.archived,
                ),
              if (b != null)
                DesignBadge(
                  switch (b.statut) {
                    'pending' => l10n.demAdmDraftPending,
                    'approved' => l10n.demAdmDraftApproved,
                    _ => l10n.demAdmDraftDraft,
                  },
                  tone: DesignBadgeTone.review,
                ),
              if (live != null)
                Text(l10n.demAdmVersion('${live.version}'),
                    style: const TextStyle(fontSize: 12, color: AdminColors.text3)),
              if (live != null && live.publiee && live.revisionEnRetard)
                DesignBadge(l10n.demAdmReviewOverdue, tone: DesignBadgeTone.failed),
              if (live != null && live.publiee && live.prochaineRevision == null)
                Text(l10n.demAdmReviewUnplanned,
                    style: const TextStyle(fontSize: 12, color: AdminColors.text3)),
              if (verifieLe != null)
                Text(l10n.demAdmVerified(_jour(verifieLe)),
                    style: const TextStyle(fontSize: 12, color: AdminColors.text3)),
            ],
          ),
        ),
        children: [
          if ((contenu['resume'] as String?)?.isNotEmpty ?? false) ...[
            _titre(l10n.demAdmSummary),
            SelectableText(contenu['resume'] as String, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
          ],
          _titre(l10n.demAdmCost),
          Text(
            cout['montantXof'] != null
                ? '${cout['libelle'] ?? ''} ${cout['montantXof']} FCFA'.trim()
                : l10n.demAdmCostUnknown,
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          if (pieces.isNotEmpty) ...[
            _titre(l10n.demAdmPieces),
            for (final p in pieces)
              Text('• ${(p as Map)['libelle'] ?? ''}', style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
          ],
          if (avert.isNotEmpty) ...[
            _titre(l10n.demAdmWarnings),
            for (final a in avert)
              Text('• $a',
                  style: const TextStyle(fontSize: 12, color: AdminColors.statusAmberStrong)),
            const SizedBox(height: 12),
          ],
          if (sourceUrl != null)
            SelectableText('${l10n.demAdmSource(editeur ?? '—')}\n$sourceUrl',
                style: const TextStyle(fontSize: 12, color: AdminColors.text3)),
          if (live?.prochaineRevision != null)
            Text(l10n.demAdmNextReview(_jour(live!.prochaineRevision)),
                style: const TextStyle(fontSize: 12, color: AdminColors.text3)),
          if (b != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AdminColors.actionBlueBg,
                border: Border.all(color: AdminColors.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.demAdmDraftBy(
                        estAuteur ? l10n.demAdmDraftByYou : l10n.demAdmDraftByOther),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  if (b.motif != null) Text(l10n.demAdmChangeReason(b.motif!)),
                  if (b.noteRelecture != null) Text(l10n.demAdmReviewNote(b.noteRelecture!)),
                  if (b.statut == 'pending' && estAuteur)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(l10n.demAdmWaitingReview,
                          style: const TextStyle(fontSize: 12, color: AdminColors.text3)),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (peutEditer && (b == null || b.statut == 'draft'))
                OutlinedButton.icon(
                  onPressed: onEditer,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: Text(l10n.demAdmEdit),
                ),
              if (peutEditer && b != null && b.statut == 'draft')
                ElevatedButton.icon(
                  onPressed: () => unawaited(_lancer(context, ref,
                      () => acts.soumettre(b.id), l10n.demAdmSubmitted)),
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: Text(l10n.demAdmSubmit),
                ),
              if (peutEditer && b != null)
                OutlinedButton.icon(
                  onPressed: () => unawaited(_lancer(
                      context, ref, () => acts.retirer(b.id), l10n.demAdmWithdrawn)),
                  icon: const Icon(Icons.undo_rounded, size: 16),
                  label: Text(l10n.demAdmWithdraw),
                ),
              if (peutApprouver && b != null && b.statut == 'pending' && !estAuteur) ...[
                ElevatedButton.icon(
                  onPressed: () => unawaited(_lancer(context, ref,
                      () => acts.relire(b.id, approuver: true), l10n.demAdmApproved)),
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: Text(l10n.demAdmApprove),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final motif = await _saisir(context,
                        titre: l10n.demAdmReject, libelle: l10n.demAdmRejectReason);
                    if (motif == null || !context.mounted) return;
                    await _lancer(
                        context,
                        ref,
                        () => acts.relire(b.id, approuver: false, note: motif),
                        l10n.demAdmRejected);
                  },
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: Text(l10n.demAdmReject),
                ),
              ],
              if (peutPublier && b != null && b.statut == 'approved')
                ElevatedButton.icon(
                  onPressed: () async {
                    var n = 0;
                    await _lancer(
                      context,
                      ref,
                      () async {
                        n = await acts.publier(b.id);
                      },
                      '',
                      // Le numéro de version n'est connu qu'une fois publié.
                      succesCalcule: () => l10n.demAdmPublished('$n'),
                    );
                  },
                  icon: const Icon(Icons.public_rounded, size: 16),
                  label: Text(l10n.demAdmPublish),
                ),
              if (peutPublier && live != null && live.publiee)
                OutlinedButton.icon(
                  onPressed: () async {
                    final motif = await _saisir(context,
                        titre: l10n.demAdmUnpublish,
                        libelle: l10n.demAdmUnpublishReason,
                        avertissement: l10n.demAdmUnpublishWarn);
                    if (motif == null || !context.mounted) return;
                    await _lancer(context, ref, () => acts.depublier(live.id, motif),
                        l10n.demAdmUnpublished);
                  },
                  icon: const Icon(Icons.visibility_off_outlined, size: 16),
                  label: Text(l10n.demAdmUnpublish),
                ),
              if (live != null)
                TextButton.icon(
                  onPressed: () => _historique(context, ref, live.id),
                  icon: const Icon(Icons.history_rounded, size: 16),
                  label: Text(l10n.demAdmHistory),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _titre(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      );

  Future<void> _historique(BuildContext context, WidgetRef ref, String id) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => Consumer(builder: (ctx, ref, _) {
        final l10n = AppLocalizations.of(ctx)!;
        final versions = ref.watch(versionsDemarcheProvider(id));
        return AlertDialog(
          title: Text(l10n.demAdmHistory),
          content: SizedBox(
            width: 460,
            child: versions.when(
              loading: () => const LinearProgressIndicator(minHeight: 2),
              error: (e, _) => Text(l10n.demAdmLoadError(detailRefus(e)),
                  style: const TextStyle(color: AdminColors.statusRed)),
              data: (liste) => liste.isEmpty
                  ? Text(l10n.demAdmHistoryEmpty)
                  : ListView(
                      shrinkWrap: true,
                      children: [
                        for (final v in liste)
                          ListTile(
                            dense: true,
                            title: Text(
                                '${l10n.demAdmVersion('${v.version}')} · ${v.evenement == 'published' ? l10n.demAdmHistoryPublished : l10n.demAdmHistoryUnpublished}'),
                            subtitle: Text(
                                '${_jour(v.date)}${v.motif != null ? ' — ${v.motif}' : ''}'),
                          ),
                      ],
                    ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: Text(l10n.demAdmConfirm)),
          ],
        );
      }),
    );
  }
}
