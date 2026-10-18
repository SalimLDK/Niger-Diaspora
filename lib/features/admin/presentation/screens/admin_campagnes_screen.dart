import 'dart:async';

import 'package:diaspo_niger/core/theme/admin_colors.dart';
import 'package:diaspo_niger/core/theme/design_kit.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/campagnes_admin_provider.dart';

/// Notifications : les campagnes (spécification d'interfaces § 16).
///
/// Remplace l'ancien écran, qui écrivait une ligne `admin_notifications` et
/// annonçait « envoyée » alors que rien ne la lisait. Ici, « Envoyée » veut
/// dire que le serveur a créé les notifications, et l'écran montre combien :
/// créée n'est pas livrée, livrée n'est pas lue.
class AdminCampagnesScreen extends ConsumerWidget {
  const AdminCampagnesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final peutVoir = ref.watch(permissionCampagneProvider('communications.view'));
    final peutRediger =
        ref.watch(permissionCampagneProvider('communications.create')).valueOrNull ?? false;
    final vue = ref.watch(vueCampagnesProvider);
    final campagnes = ref.watch(campagnesProvider);

    if (peutVoir.valueOrNull == false) {
      return Center(child: Text(l10n.cmpAdmNoAccess));
    }

    final vues = {
      VueCampagnes.atraiter: l10n.cmpAdmFilterWork,
      VueCampagnes.envoyees: l10n.cmpAdmFilterSent,
      VueCampagnes.closes: l10n.cmpAdmFilterClosed,
      VueCampagnes.toutes: l10n.cmpAdmFilterAll,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.cmpAdmTitle,
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.w700, color: AdminColors.text)),
                const SizedBox(height: 4),
                Text(l10n.cmpAdmSubtitle, style: const TextStyle(color: AdminColors.text3)),
                const SizedBox(height: 2),
                Text(l10n.cmpAdmNoSchedule,
                    style: const TextStyle(fontSize: 12, color: AdminColors.text3)),
              ],
            ),
          ),
          IconButton(
            tooltip: l10n.cmpAdmRetry,
            onPressed: () => ref.invalidate(campagnesProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
          if (peutRediger)
            ElevatedButton.icon(
              onPressed: () => _editer(context, ref, null),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(l10n.cmpAdmNew),
            ),
        ]),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in vues.entries)
              ChoiceChip(
                label: Text(e.value),
                selected: vue == e.key,
                selectedColor: AdminColors.actionBlueBg,
                onSelected: (_) => ref.read(vueCampagnesProvider.notifier).state = e.key,
              ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: campagnes.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(l10n.cmpAdmLoadError(detailCampagne(e)),
                    style: const TextStyle(color: AdminColors.statusRed)),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => ref.invalidate(campagnesProvider),
                  child: Text(l10n.cmpAdmRetry),
                ),
              ]),
            ),
            data: (liste) => liste.isEmpty
                ? Center(
                    child: Text(l10n.cmpAdmEmpty,
                        style: const TextStyle(color: AdminColors.text3)))
                : ListView.separated(
                    itemCount: liste.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _CarteCampagne(
                      key: ValueKey(liste[i].id),
                      campagne: liste[i],
                      onEditer: () => _editer(context, ref, liste[i]),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> _editer(BuildContext context, WidgetRef ref, Campagne? existante) async {
    final res = await showDialog<_Saisie>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EditeurCampagne(existante: existante),
    );
    if (res == null || !context.mounted) return;
    await _lancer(
      context,
      ref,
      () => ref.read(campagnesAdminActionsProvider).enregistrer(
            id: existante?.id,
            type: res.type,
            titre: res.titre,
            texte: res.texte,
            audience: res.audience,
          ),
      AppLocalizations.of(context)!.cmpAdmSaved,
    );
  }
}

String _libelleStatut(AppLocalizations l, String s) => switch (s) {
      'draft' => l.cmpAdmStatusDraft,
      'pending_approval' => l.cmpAdmStatusPending,
      'approved' => l.cmpAdmStatusApproved,
      'sending' => l.cmpAdmStatusSending,
      'sent' => l.cmpAdmStatusSent,
      'rejected' => l.cmpAdmStatusRejected,
      _ => l.cmpAdmStatusCancelled,
    };

DesignBadgeTone _ton(String s) => switch (s) {
      'sent' => DesignBadgeTone.verified,
      'rejected' => DesignBadgeTone.failed,
      'cancelled' => DesignBadgeTone.archived,
      _ => DesignBadgeTone.review,
    };

String _libelleType(AppLocalizations l, String t) => switch (t) {
      'transactional' => l.cmpAdmTypeTransactional,
      'security' => l.cmpAdmTypeSecurity,
      'official_info' => l.cmpAdmTypeOfficial,
      _ => l.cmpAdmTypePromotional,
    };

String _libelleAudience(AppLocalizations l, Map<String, dynamic> a) => switch (a['kind']) {
      'all' => l.cmpAdmAudienceAll,
      'country' => l.cmpAdmAudienceCountry('${a['country'] ?? ''}'),
      _ => l.cmpAdmAudienceUsers('${(a['user_ids'] as List?)?.length ?? 0}'),
    };

/// Exécute [geste], relit la file, dit le résultat ; vrai seulement si le
/// serveur a accepté. On relit même après un refus : un autre administrateur
/// a pu faire avancer la campagne entre-temps.
Future<bool> _lancer(
  BuildContext context,
  WidgetRef ref,
  Future<void> Function() geste,
  String succes,
) async {
  final l10n = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  String? echec;
  try {
    await geste();
  } catch (e) {
    echec = switch (classerRefusCampagne(e)) {
      RefusCampagne.permission => l10n.modoErrDenied,
      RefusCampagne.conflit => l10n.modoErrConflict,
      RefusCampagne.saisie => l10n.modoErrInput(detailCampagne(e)),
      _ => l10n.modoErrGeneric(detailCampagne(e)),
    };
  }
  ref.invalidate(campagnesProvider);
  messenger.showSnackBar(SnackBar(
    behavior: SnackBarBehavior.floating,
    backgroundColor: echec == null ? AdminColors.statusGreen : AdminColors.statusRed,
    content: Text(echec ?? succes),
  ));
  return echec == null;
}

Future<String?> _saisir(
  BuildContext context, {
  required String titre,
  required String libelle,
  String? avertissement,
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
                decoration:
                    InputDecoration(labelText: libelle, border: const OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: Text(l10n.cmpAdmCancelAction)),
            ElevatedButton(
              onPressed: controller.text.trim().length < 5
                  ? null
                  : () => Navigator.pop(ctx, controller.text.trim()),
              child: Text(l10n.cmpAdmConfirm),
            ),
          ],
        ),
      );
    },
  ).whenComplete(controller.dispose);
}

class _CarteCampagne extends ConsumerWidget {
  const _CarteCampagne({super.key, required this.campagne, required this.onEditer});

  final Campagne campagne;
  final VoidCallback onEditer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final c = campagne;
    final moi = FirebaseAuth.instance.currentUser?.uid;
    final estAuteur = c.auteur == moi;
    bool perm(String k) => ref.watch(permissionCampagneProvider(k)).valueOrNull ?? false;
    final peutRediger = perm('communications.create');
    final peutEnvoyer = perm('communications.send');
    final acts = ref.read(campagnesAdminActionsProvider);

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
        title: Text(c.titre,
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
              DesignBadge(_libelleStatut(l10n, c.statut), tone: _ton(c.statut)),
              Text(_libelleType(l10n, c.type),
                  style: const TextStyle(fontSize: 12, color: AdminColors.text3)),
              Text(_libelleAudience(l10n, c.audience),
                  style: const TextStyle(fontSize: 12, color: AdminColors.text3)),
            ],
          ),
        ),
        children: [
          SelectableText(c.texte, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 12),
          // Ce que l'envoi atteindrait (avant) ou a atteint (après).
          if (c.statut == 'pending_approval' || c.statut == 'approved' || c.statut == 'sending')
            _Decompte(id: c.id),
          if (c.statut == 'sending' || c.statut == 'sent' || c.statut == 'cancelled')
            _Bilan(id: c.id),
          if (c.noteRelecture != null)
            Text(l10n.cmpAdmReviewNote(c.noteRelecture!),
                style: const TextStyle(fontSize: 12, color: AdminColors.text3)),
          if (c.motifAnnulation != null)
            Text(l10n.cmpAdmCancelReason(c.motifAnnulation!),
                style: const TextStyle(fontSize: 12, color: AdminColors.text3)),
          if (c.statut == 'pending_approval' && estAuteur)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(l10n.cmpAdmWaiting,
                  style: const TextStyle(fontSize: 12, color: AdminColors.text3)),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (peutRediger && (c.statut == 'draft' || c.statut == 'rejected'))
                OutlinedButton.icon(
                  onPressed: onEditer,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: Text(l10n.cmpAdmEdit),
                ),
              if (peutRediger && c.statut == 'draft')
                ElevatedButton.icon(
                  onPressed: () => unawaited(
                      _lancer(context, ref, () => acts.soumettre(c.id), l10n.cmpAdmSubmitted)),
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: Text(l10n.cmpAdmSubmit),
                ),
              if (peutEnvoyer && c.statut == 'pending_approval' && !estAuteur) ...[
                ElevatedButton.icon(
                  onPressed: () => unawaited(_lancer(context, ref,
                      () => acts.relire(c.id, approuver: true), l10n.cmpAdmApproved)),
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: Text(l10n.cmpAdmApprove),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final motif = await _saisir(context,
                        titre: l10n.cmpAdmReject, libelle: l10n.cmpAdmRejectReason);
                    if (motif == null || !context.mounted) return;
                    await _lancer(context, ref,
                        () => acts.relire(c.id, approuver: false, note: motif),
                        l10n.cmpAdmRejected);
                  },
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: Text(l10n.cmpAdmReject),
                ),
              ],
              if (peutEnvoyer && (c.statut == 'approved' || c.statut == 'sending'))
                ElevatedButton.icon(
                  onPressed: () => _envoyer(context, ref, c),
                  icon: const Icon(Icons.campaign_rounded, size: 16),
                  label: Text(c.statut == 'sending' ? l10n.cmpAdmResume : l10n.cmpAdmSend),
                ),
              // L'auteur retire son propre texte avant l'approbation ; ensuite
              // l'arrêt appartient à qui détient l'envoi.
              if ((c.statut == 'draft' || c.statut == 'pending_approval') &&
                      (estAuteur ? peutRediger : peutEnvoyer) ||
                  ((c.statut == 'approved' || c.statut == 'sending') && peutEnvoyer))
                OutlinedButton.icon(
                  onPressed: () async {
                    final motif = await _saisir(
                      context,
                      titre: l10n.cmpAdmCancel,
                      libelle: l10n.cmpAdmCancelReasonLabel,
                      avertissement:
                          c.statut == 'sending' ? l10n.cmpAdmCancelWarnSending : null,
                    );
                    if (motif == null || !context.mounted) return;
                    await _lancer(
                        context, ref, () => acts.annuler(c.id, motif), l10n.cmpAdmCancelled);
                  },
                  icon: const Icon(Icons.block_rounded, size: 16),
                  label: Text(l10n.cmpAdmCancel),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Confirme avec le vrai nombre de comptes, puis envoie lot après lot en
  /// montrant l'avancement. Un lot qui échoue arrête la boucle : les comptes
  /// déjà traités ne seront pas renotifiés à la reprise.
  Future<void> _envoyer(BuildContext context, WidgetRef ref, Campagne c) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final acts = ref.read(campagnesAdminActionsProvider);

    DecompteAudience decompte;
    try {
      decompte = await ref.read(decompteAudienceProvider(c.id).future);
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        backgroundColor: AdminColors.statusRed,
        content: Text(l10n.cmpAdmLoadError(detailCampagne(e))),
      ));
      return;
    }
    if (!context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.cmpAdmSendConfirmTitle),
        content: Text(l10n.cmpAdmSendConfirmBody('${decompte.notifies}')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cmpAdmCancelAction)),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.cmpAdmConfirm)),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    final avancement = ValueNotifier<(int, int)>((0, -1));
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: ValueListenableBuilder<(int, int)>(
          valueListenable: avancement,
          builder: (_, v, __) => Row(children: [
            const SizedBox(
                width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 16),
            Expanded(
              child: Text(v.$2 < 0
                  ? '…'
                  : l10n.cmpAdmSendProgress('${v.$1}', '${v.$2}')),
            ),
          ]),
        ),
      ),
    ));

    var traites = 0;
    var creees = 0;
    String? echec;
    try {
      while (true) {
        final lot = await acts.envoyerUnLot(c.id);
        traites += lot.traites;
        creees += lot.creees;
        avancement.value = (traites, lot.restants);
        // Un lot qui ne traite rien alors qu'il reste des comptes ne ferait
        // que tourner : on s'arrête et on le dit.
        if (lot.termine || lot.restants == 0 || lot.traites == 0) break;
      }
    } catch (e) {
      echec = detailCampagne(e);
    }
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    avancement.dispose();

    ref.invalidate(campagnesProvider);
    ref.invalidate(bilanEnvoiProvider(c.id));
    messenger.showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: echec == null ? AdminColors.statusGreen : AdminColors.statusRed,
      content: Text(echec == null
          ? l10n.cmpAdmSendDone('$creees')
          : l10n.cmpAdmSendStopped(echec)),
    ));
  }
}

class _Decompte extends ConsumerWidget {
  const _Decompte({required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final d = ref.watch(decompteAudienceProvider(id));
    return d.when(
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (e, _) => Text(l10n.cmpAdmLoadError(detailCampagne(e)),
          style: const TextStyle(color: AdminColors.statusRed, fontSize: 12)),
      data: (v) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          l10n.cmpAdmAudienceCount('${v.total}', '${v.ignores}', '${v.notifies}'),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _Bilan extends ConsumerWidget {
  const _Bilan({required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final b = ref.watch(bilanEnvoiProvider(id));
    return b.when(
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (e, _) => Text(l10n.cmpAdmLoadError(detailCampagne(e)),
          style: const TextStyle(color: AdminColors.statusRed, fontSize: 12)),
      data: (v) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          l10n.cmpAdmRecipients('${v.creees}', '${v.ignorees}'),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _Saisie {
  const _Saisie(this.type, this.titre, this.texte, this.audience);
  final String type;
  final String titre;
  final String texte;
  final Map<String, dynamic> audience;
}

class _EditeurCampagne extends StatefulWidget {
  const _EditeurCampagne({required this.existante});
  final Campagne? existante;

  @override
  State<_EditeurCampagne> createState() => _EditeurCampagneState();
}

class _EditeurCampagneState extends State<_EditeurCampagne> {
  final _titre = TextEditingController();
  final _texte = TextEditingController();
  final _pays = TextEditingController();
  final _comptes = TextEditingController();
  String _type = 'official_info';
  String _audience = 'country';
  bool _modifie = false;

  @override
  void initState() {
    super.initState();
    final c = widget.existante;
    if (c != null) {
      _titre.text = c.titre;
      _texte.text = c.texte;
      _type = c.type;
      _audience = c.audienceKind.isEmpty ? 'country' : c.audienceKind;
      _pays.text = c.audience['country'] as String? ?? '';
      _comptes.text = ((c.audience['user_ids'] as List?) ?? const []).join('\n');
    }
  }

  @override
  void dispose() {
    for (final c in [_titre, _texte, _pays, _comptes]) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> get _ids => [
        for (final l in _comptes.text.split(RegExp(r'[\n,;]')))
          if (l.trim().isNotEmpty) l.trim(),
      ];

  bool get _valide {
    if (_titre.text.trim().length < 3 || _texte.text.trim().length < 10) return false;
    return switch (_audience) {
      'country' => _pays.text.trim().length >= 2,
      'users' => _ids.isNotEmpty && _ids.length <= 100,
      _ => true,
    };
  }

  Map<String, dynamic> get _audienceJson => switch (_audience) {
        'country' => {'kind': 'country', 'country': _pays.text.trim()},
        'users' => {'kind': 'users', 'user_ids': _ids},
        _ => {'kind': 'all'},
      };

  void _touch() => setState(() => _modifie = true);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final types = {
      'official_info': l10n.cmpAdmTypeOfficial,
      'promotional': l10n.cmpAdmTypePromotional,
      'security': l10n.cmpAdmTypeSecurity,
      'transactional': l10n.cmpAdmTypeTransactional,
    };
    return PopScope(
      canPop: !_modifie,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final quitter = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            content: Text(l10n.cmpAdmUnsaved),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(l10n.cmpAdmCancelAction)),
              ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(l10n.cmpAdmConfirm)),
            ],
          ),
        );
        if (quitter == true && context.mounted) Navigator.pop(context);
      },
      child: AlertDialog(
        title: Text(widget.existante == null ? l10n.cmpAdmEditorNew : l10n.cmpAdmEditorEdit),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  isExpanded: true,
                  decoration: InputDecoration(
                      labelText: l10n.cmpAdmFieldType, border: const OutlineInputBorder()),
                  items: [
                    for (final e in types.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (v) {
                    _type = v ?? _type;
                    _touch();
                  },
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 12),
                  child: Text(l10n.cmpAdmTypeHelp,
                      style: const TextStyle(fontSize: 11, color: AdminColors.text3)),
                ),
                TextField(
                  controller: _titre,
                  onChanged: (_) => _touch(),
                  maxLength: 80,
                  decoration: InputDecoration(
                      labelText: l10n.cmpAdmFieldTitle, border: const OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _texte,
                  onChanged: (_) => _touch(),
                  maxLength: 300,
                  maxLines: 4,
                  decoration: InputDecoration(
                      labelText: l10n.cmpAdmFieldBody, border: const OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _audience,
                  isExpanded: true,
                  decoration: InputDecoration(
                      labelText: l10n.cmpAdmFieldAudience, border: const OutlineInputBorder()),
                  items: [
                    DropdownMenuItem(value: 'all', child: Text(l10n.cmpAdmAudienceAll)),
                    DropdownMenuItem(
                        value: 'country', child: Text(l10n.cmpAdmAudienceCountry('…'))),
                    DropdownMenuItem(
                        value: 'users', child: Text(l10n.cmpAdmAudienceUsers('…'))),
                  ],
                  onChanged: (v) {
                    _audience = v ?? _audience;
                    _touch();
                  },
                ),
                if (_audience == 'country') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pays,
                    onChanged: (_) => _touch(),
                    decoration: InputDecoration(
                        labelText: l10n.cmpAdmFieldCountry,
                        border: const OutlineInputBorder()),
                  ),
                ],
                if (_audience == 'users') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _comptes,
                    onChanged: (_) => _touch(),
                    maxLines: 4,
                    decoration: InputDecoration(
                        labelText: l10n.cmpAdmFieldUsers,
                        border: const OutlineInputBorder()),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.maybePop(context),
              child: Text(l10n.cmpAdmCancelAction)),
          ElevatedButton(
            onPressed: _valide
                ? () => Navigator.pop(
                    context,
                    _Saisie(_type, _titre.text.trim(), _texte.text.trim(), _audienceJson))
                : null,
            child: Text(l10n.cmpAdmSaveDraft),
          ),
        ],
      ),
    );
  }
}
