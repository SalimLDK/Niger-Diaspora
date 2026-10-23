import 'dart:async';

import 'package:diaspo_niger/core/theme/admin_colors.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/support_admin_provider.dart';

/// Les réglages du support : modèles de réponse et délais de service.
///
/// Chaque section n'apparaît que pour qui détient la permission ; le serveur
/// reste l'autorité et ses refus s'affichent dans le dialogue, pas derrière lui.
class ReglagesSupportDialog extends ConsumerStatefulWidget {
  const ReglagesSupportDialog({
    super.key,
    required this.libelleCategorie,
    required this.libellePriorite,
  });

  final String Function(AppLocalizations, String) libelleCategorie;
  final String Function(AppLocalizations, String) libellePriorite;

  @override
  ConsumerState<ReglagesSupportDialog> createState() => _ReglagesSupportDialogState();
}

const _categories = [
  'transaction', 'account', 'technical', 'other', 'directory',
  'privacy', 'complaint', 'appeal', 'security',
];
const _priorites = ['low', 'normal', 'high', 'urgent'];

class _ReglagesSupportDialogState extends ConsumerState<ReglagesSupportDialog> {
  final _premiere = TextEditingController();
  final _resolution = TextEditingController();
  String _cat = 'account';
  String _prio = 'normal';
  String? _message;
  bool _echec = false;

  @override
  void dispose() {
    _premiere.dispose();
    _resolution.dispose();
    super.dispose();
  }

  Future<bool> _executer(Future<void> Function() geste, String succes) async {
    final l10n = AppLocalizations.of(context)!;
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
    ref.invalidate(modelesReponseProvider);
    ref.invalidate(delaisCiblesProvider);
    ref.invalidate(echeancesProvider);
    if (!mounted) return echec == null;
    setState(() {
      _echec = echec != null;
      _message = echec ?? succes;
    });
    return echec == null;
  }

  int? _heures(String t) {
    final s = t.trim();
    if (s.isEmpty) return null;
    final n = int.tryParse(s);
    return (n == null || n < 1 || n > 8760) ? -1 : n;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final peutModeles =
        ref.watch(permissionSupportProvider('support.templates.manage')).valueOrNull ?? false;
    final peutDelais =
        ref.watch(permissionSupportProvider('support.sla.manage')).valueOrNull ?? false;

    return AlertDialog(
      title: Text(l10n.supSlaSettingsTitle),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_message!,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _echec ? AdminColors.statusRed : AdminColors.statusGreen)),
                ),
              if (!peutModeles && !peutDelais) Text(l10n.supAdmNoAccess),
              if (peutModeles) ..._modeles(l10n),
              if (peutModeles && peutDelais) const Divider(height: 32),
              if (peutDelais) ..._delais(l10n),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: Text(l10n.supSlaClose)),
      ],
    );
  }

  // ── Modèles ──────────────────────────────────────────────────────────────

  List<Widget> _modeles(AppLocalizations l10n) {
    final modeles = ref.watch(modelesReponseProvider);
    return [
      Text(l10n.supSlaTemplatesTitle,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      modeles.when(
        loading: () => const LinearProgressIndicator(),
        error: (e, _) => Text(l10n.supAdmLoadError(detailSupport(e)),
            style: const TextStyle(color: AdminColors.statusRed)),
        data: (liste) => liste.isEmpty
            ? Text(l10n.supSlaTemplatesEmpty,
                style: const TextStyle(color: AdminColors.text3))
            : Column(children: [
                for (final m in liste)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(m.titre, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                        m.categorie == null
                            ? l10n.supSlaTemplateAnyCategory
                            : widget.libelleCategorie(l10n, m.categorie!),
                        style: const TextStyle(fontSize: 12)),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        tooltip: l10n.supSlaTemplateEdit,
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        onPressed: () => unawaited(_editerModele(m)),
                      ),
                      IconButton(
                        tooltip: l10n.supSlaTemplateDelete,
                        icon: const Icon(Icons.delete_outline_rounded, size: 20),
                        onPressed: () => unawaited(_supprimerModele(m)),
                      ),
                    ]),
                  ),
              ]),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: () => unawaited(_editerModele(null)),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: Text(l10n.supSlaTemplateNew),
        ),
      ),
    ];
  }

  Future<void> _editerModele(ModeleReponse? m) async {
    final l10n = AppLocalizations.of(context)!;
    final titre = TextEditingController(text: m?.titre ?? '');
    final texte = TextEditingController(text: m?.texte ?? '');
    String? cat = m?.categorie;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(m == null ? l10n.supSlaTemplateNew : l10n.supSlaTemplateEdit),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                  controller: titre,
                  maxLength: 120,
                  onChanged: (_) => setLocal(() {}),
                  decoration: InputDecoration(
                      labelText: l10n.supSlaTemplateTitleLabel,
                      border: const OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: texte,
                  maxLength: 4000,
                  maxLines: 6,
                  onChanged: (_) => setLocal(() {}),
                  decoration: InputDecoration(
                      labelText: l10n.supSlaTemplateBodyLabel,
                      border: const OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  initialValue: cat,
                  decoration: InputDecoration(
                      labelText: l10n.supSlaTemplateCategoryLabel,
                      border: const OutlineInputBorder()),
                  items: [
                    DropdownMenuItem<String?>(
                        value: null, child: Text(l10n.supSlaTemplateAnyCategory)),
                    for (final c in _categories)
                      DropdownMenuItem<String?>(
                          value: c, child: Text(widget.libelleCategorie(l10n, c))),
                  ],
                  onChanged: (v) => setLocal(() => cat = v),
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.adminCancelAction)),
            ElevatedButton(
              onPressed: titre.text.trim().isEmpty || texte.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(ctx, true),
              child: Text(l10n.supSlaTemplateSave),
            ),
          ],
        ),
      ),
    );
    final t = titre.text.trim();
    final b = texte.text.trim();
    titre.dispose();
    texte.dispose();
    if (ok != true || !mounted) return;
    await _executer(
        () => ref.read(supportAdminActionsProvider).enregistrerModele(m?.id, t, b, cat),
        l10n.supAdmDone);
  }

  Future<void> _supprimerModele(ModeleReponse m) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(l10n.supSlaTemplateDeleteConfirm(m.titre)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.adminCancelAction)),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.supSlaTemplateDelete)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _executer(
        () => ref.read(supportAdminActionsProvider).supprimerModele(m.id), l10n.supAdmDone);
  }

  // ── Délais ───────────────────────────────────────────────────────────────

  List<Widget> _delais(AppLocalizations l10n) {
    final cibles = ref.watch(delaisCiblesProvider);
    return [
      Text(l10n.supSlaTargetsTitle,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      Text(l10n.supSlaTargetsNote,
          style: const TextStyle(fontSize: 12, color: AdminColors.text3)),
      const SizedBox(height: 8),
      cibles.when(
        loading: () => const LinearProgressIndicator(),
        error: (e, _) => Text(l10n.supAdmLoadError(detailSupport(e)),
            style: const TextStyle(color: AdminColors.statusRed)),
        data: (liste) => liste.isEmpty
            ? Text(l10n.supSlaTargetsEmpty, style: const TextStyle(color: AdminColors.text3))
            : Column(children: [
                for (final c in liste)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                        '${widget.libelleCategorie(l10n, c.categorie)} · '
                        '${widget.libellePriorite(l10n, c.priorite)}'),
                    subtitle: Text(l10n.supSlaTargetLine(
                        c.premiere?.toString() ?? l10n.supSlaNoValue,
                        c.resolution?.toString() ?? l10n.supSlaNoValue)),
                    trailing: IconButton(
                      tooltip: l10n.supSlaTargetRemove,
                      icon: const Icon(Icons.delete_outline_rounded, size: 20),
                      onPressed: () => unawaited(_executer(
                          () => ref
                              .read(supportAdminActionsProvider)
                              .arreterDelai(c.categorie, c.priorite, null, null),
                          l10n.supAdmDone)),
                    ),
                  ),
              ]),
      ),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        SizedBox(
          width: 170,
          child: DropdownButtonFormField<String>(
            initialValue: _cat,
            isExpanded: true,
            decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
            items: [
              for (final c in _categories)
                DropdownMenuItem(
                    value: c,
                    child: Text(widget.libelleCategorie(l10n, c),
                        overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) => setState(() => _cat = v ?? _cat),
          ),
        ),
        SizedBox(
          width: 130,
          child: DropdownButtonFormField<String>(
            initialValue: _prio,
            isExpanded: true,
            decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
            items: [
              for (final p in _priorites)
                DropdownMenuItem(value: p, child: Text(widget.libellePriorite(l10n, p))),
            ],
            onChanged: (v) => setState(() => _prio = v ?? _prio),
          ),
        ),
        SizedBox(
          width: 130,
          child: TextField(
            controller: _premiere,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
                labelText: l10n.supSlaFirstHours,
                border: const OutlineInputBorder(),
                isDense: true),
          ),
        ),
        SizedBox(
          width: 130,
          child: TextField(
            controller: _resolution,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
                labelText: l10n.supSlaResolutionHours,
                border: const OutlineInputBorder(),
                isDense: true),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            final p = _heures(_premiere.text);
            final r = _heures(_resolution.text);
            if (p == -1 || r == -1 || (p == null && r == null)) {
              setState(() {
                _echec = true;
                _message = l10n.supSlaHoursInvalid;
              });
              return;
            }
            unawaited(_executer(
                () => ref.read(supportAdminActionsProvider).arreterDelai(_cat, _prio, p, r),
                l10n.supAdmDone));
          },
          child: Text(l10n.supSlaTargetSave),
        ),
      ]),
    ];
  }
}
