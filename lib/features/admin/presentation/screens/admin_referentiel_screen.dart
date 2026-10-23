import 'dart:async';

import 'package:diaspo_niger/core/theme/admin_colors.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/referentiel_admin_provider.dart';

/// Référentiel géographique (spécification d'interfaces § 12) : villes,
/// doublons, pays. Réservé au superAdmin : une ville fausse peut ouvrir des
/// groupes officiels. Le serveur contrôle les dépendances (profils, groupes) ;
/// l'écran montre ce qu'il refuse et pourquoi.
class AdminReferentielScreen extends ConsumerWidget {
  const AdminReferentielScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final peut = ref.watch(permissionReferentielProvider('geography.reference.manage'));
    if (peut.valueOrNull == false) {
      return Center(child: Text(l10n.refAdmNoAccess));
    }
    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.refAdmTitle,
              style: const TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w700, color: AdminColors.text)),
          const SizedBox(height: 4),
          Text(l10n.refAdmSubtitle, style: const TextStyle(color: AdminColors.text3)),
          const SizedBox(height: 12),
          TabBar(
            labelColor: AdminColors.actionBlue,
            unselectedLabelColor: AdminColors.text3,
            tabs: [
              Tab(text: l10n.refAdmTabCities),
              Tab(text: l10n.refAdmTabDuplicates),
              Tab(text: l10n.refAdmTabCountries),
            ],
          ),
          const SizedBox(height: 12),
          const Expanded(
            child: TabBarView(children: [_OngletVilles(), _OngletDoublons(), _OngletPays()]),
          ),
        ],
      ),
    );
  }
}

// ═══ Aides ═════════════════════════════════════════════════════════════════

Future<bool> _lancer(
  BuildContext context,
  WidgetRef ref,
  Future<void> Function() geste,
  String succes,
  List<ProviderOrFamily> aRelire,
) async {
  final l10n = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  String? echec;
  try {
    await geste();
  } catch (e) {
    // Le texte du serveur dit POURQUOI (profils, groupes, doublon…) : on le montre.
    echec = switch (classerRefusReferentiel(e)) {
      RefusReferentiel.permission => l10n.modoErrDenied,
      RefusReferentiel.conflit || RefusReferentiel.saisie => l10n.modoErrInput(detailReferentiel(e)),
      _ => l10n.modoErrGeneric(detailReferentiel(e)),
    };
  }
  for (final p in aRelire) {
    ref.invalidate(p);
  }
  messenger.showSnackBar(SnackBar(
    behavior: SnackBarBehavior.floating,
    backgroundColor: echec == null ? AdminColors.statusGreen : AdminColors.statusRed,
    content: Text(echec ?? succes),
  ));
  return echec == null;
}

Future<String?> _demanderMotif(BuildContext context, String titre, {String? avertissement}) {
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
                maxLines: 2,
                maxLength: 500,
                decoration: InputDecoration(
                    labelText: l10n.refAdmReason, border: const OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.refAdmCancel)),
            ElevatedButton(
              onPressed: controller.text.trim().length < 5
                  ? null
                  : () => Navigator.pop(ctx, controller.text.trim()),
              child: Text(l10n.refAdmConfirm),
            ),
          ],
        ),
      );
    },
  ).whenComplete(controller.dispose);
}

// ═══ Villes ════════════════════════════════════════════════════════════════

class _OngletVilles extends ConsumerStatefulWidget {
  const _OngletVilles();

  @override
  ConsumerState<_OngletVilles> createState() => _OngletVillesState();
}

class _OngletVillesState extends ConsumerState<_OngletVilles> {
  Timer? _delai;

  @override
  void dispose() {
    _delai?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final villes = ref.watch(villesRefProvider);
    final pays = ref.watch(paysRefProvider).valueOrNull ?? const [];
    final filtre = ref.watch(paysFiltreProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 280,
              child: TextField(
                onChanged: (v) {
                  _delai?.cancel();
                  _delai = Timer(const Duration(milliseconds: 350),
                      () => ref.read(rechercheVilleProvider.notifier).state = v);
                },
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  hintText: l10n.refAdmSearchCity,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String?>(
                initialValue: filtre,
                isExpanded: true,
                isDense: true,
                decoration: InputDecoration(
                    labelText: l10n.refAdmCountry, border: const OutlineInputBorder()),
                items: [
                  DropdownMenuItem<String?>(value: null, child: Text(l10n.refAdmAllCountries)),
                  for (final p in pays) DropdownMenuItem<String?>(value: p.nom, child: Text(p.nom)),
                ],
                onChanged: (v) => ref.read(paysFiltreProvider.notifier).state = v,
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _editer(context, null),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(l10n.refAdmNewCity),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: villes.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(l10n.refAdmLoadError(detailReferentiel(e)),
                    style: const TextStyle(color: AdminColors.statusRed)),
                OutlinedButton(
                    onPressed: () => ref.invalidate(villesRefProvider),
                    child: Text(l10n.refAdmRetry)),
              ]),
            ),
            data: (liste) => liste.isEmpty
                ? Center(
                    child: Text(l10n.refAdmSearchHint,
                        style: const TextStyle(color: AdminColors.text3)))
                : ListView.separated(
                    itemCount: liste.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final v = liste[i];
                      return ListTile(
                        title: Text(v.nom),
                        subtitle: Text(
                            '${v.pays}${v.region != null ? ' · ${v.region}' : ''} · ${l10n.refAdmPopulation('${v.population}')} · #${v.id}'),
                        trailing: Wrap(spacing: 4, children: [
                          IconButton(
                            tooltip: l10n.refAdmEdit,
                            onPressed: () => _editer(context, v),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: l10n.refAdmDelete,
                            onPressed: () => _supprimer(context, v),
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ]),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> _editer(BuildContext context, VilleRef? v) async {
    final pays = await ref
        .read(paysRefProvider.future)
        .catchError((_) => const <({String nom, String code})>[]);
    if (!context.mounted) return;
    final res = await showDialog<_SaisieVille>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EditeurVille(ville: v, pays: [for (final p in pays) p.nom]),
    );
    if (res == null || !context.mounted) return;
    await _lancer(
      context,
      ref,
      () => ref.read(referentielAdminActionsProvider).enregistrerVille(
            id: v?.id,
            nom: res.nom,
            pays: res.pays,
            region: res.region,
            latitude: res.latitude,
            longitude: res.longitude,
            population: res.population,
            alias: res.alias,
            motif: res.motif,
          ),
      AppLocalizations.of(context)!.refAdmSaved,
      [villesRefProvider, doublonsVillesProvider],
    );
  }

  Future<void> _supprimer(BuildContext context, VilleRef v) async {
    final l10n = AppLocalizations.of(context)!;
    final motif = await _demanderMotif(context, l10n.refAdmDeleteTitle(v.nom),
        avertissement: l10n.refAdmDeleteWarn);
    if (motif == null || !context.mounted) return;
    await _lancer(context, ref,
        () => ref.read(referentielAdminActionsProvider).supprimer(v.id, motif),
        l10n.refAdmDeleted, [villesRefProvider, doublonsVillesProvider]);
  }
}

class _SaisieVille {
  const _SaisieVille(this.nom, this.pays, this.region, this.latitude, this.longitude,
      this.population, this.alias, this.motif);
  final String nom;
  final String pays;
  final String? region;
  final double latitude;
  final double longitude;
  final int population;
  final List<String> alias;
  final String motif;
}

class _EditeurVille extends StatefulWidget {
  const _EditeurVille({required this.ville, required this.pays});
  final VilleRef? ville;
  final List<String> pays;

  @override
  State<_EditeurVille> createState() => _EditeurVilleState();
}

class _EditeurVilleState extends State<_EditeurVille> {
  final _nom = TextEditingController();
  final _region = TextEditingController();
  final _lat = TextEditingController();
  final _lon = TextEditingController();
  final _pop = TextEditingController(text: '0');
  final _alias = TextEditingController();
  final _motif = TextEditingController();
  String? _pays;

  @override
  void initState() {
    super.initState();
    final v = widget.ville;
    if (v != null) {
      _nom.text = v.nom;
      _region.text = v.region ?? '';
      _lat.text = '${v.latitude}';
      _lon.text = '${v.longitude}';
      _pop.text = '${v.population}';
      _alias.text = v.alias.join(', ');
      _pays = v.pays;
    }
  }

  @override
  void dispose() {
    for (final c in [_nom, _region, _lat, _lon, _pop, _alias, _motif]) {
      c.dispose();
    }
    super.dispose();
  }

  double? get _latitude => double.tryParse(_lat.text.trim().replaceAll(',', '.'));
  double? get _longitude => double.tryParse(_lon.text.trim().replaceAll(',', '.'));

  bool get _valide =>
      _nom.text.trim().length >= 2 &&
      _pays != null &&
      _latitude != null &&
      _longitude != null &&
      int.tryParse(_pop.text.trim()) != null &&
      _motif.text.trim().length >= 5;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    InputDecoration deco(String t) =>
        InputDecoration(labelText: t, border: const OutlineInputBorder(), isDense: true);
    return AlertDialog(
      title: Text(widget.ville == null ? l10n.refAdmNewCity : l10n.refAdmEdit),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: _nom,
                  onChanged: (_) => setState(() {}),
                  decoration: deco(l10n.refAdmFieldName)),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: widget.pays.contains(_pays) ? _pays : null,
                isExpanded: true,
                decoration: deco(l10n.refAdmCountry),
                items: [for (final p in widget.pays) DropdownMenuItem(value: p, child: Text(p))],
                onChanged: (v) => setState(() => _pays = v),
              ),
              const SizedBox(height: 10),
              TextField(controller: _region, decoration: deco(l10n.refAdmFieldRegion)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: TextField(
                      controller: _lat,
                      onChanged: (_) => setState(() {}),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      decoration: deco(l10n.refAdmFieldLat)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                      controller: _lon,
                      onChanged: (_) => setState(() {}),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      decoration: deco(l10n.refAdmFieldLon)),
                ),
              ]),
              const SizedBox(height: 10),
              TextField(
                  controller: _pop,
                  onChanged: (_) => setState(() {}),
                  keyboardType: TextInputType.number,
                  decoration: deco(l10n.refAdmFieldPopulation)),
              const SizedBox(height: 10),
              TextField(controller: _alias, decoration: deco(l10n.refAdmFieldAliases)),
              const SizedBox(height: 10),
              TextField(
                  controller: _motif,
                  onChanged: (_) => setState(() {}),
                  maxLines: 2,
                  decoration: deco(l10n.refAdmReason)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.refAdmCancel)),
        ElevatedButton(
          onPressed: _valide
              ? () => Navigator.pop(
                    context,
                    _SaisieVille(
                      _nom.text.trim(),
                      _pays!,
                      _region.text.trim().isEmpty ? null : _region.text.trim(),
                      _latitude!,
                      _longitude!,
                      int.parse(_pop.text.trim()),
                      [
                        for (final a in _alias.text.split(','))
                          if (a.trim().isNotEmpty) a.trim(),
                      ],
                      _motif.text.trim(),
                    ),
                  )
              : null,
          child: Text(l10n.refAdmSave),
        ),
      ],
    );
  }
}

// ═══ Doublons ══════════════════════════════════════════════════════════════

class _OngletDoublons extends ConsumerWidget {
  const _OngletDoublons();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final doublons = ref.watch(doublonsVillesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
              child: Text(l10n.refAdmDuplicatesHelp,
                  style: const TextStyle(fontSize: 12, color: AdminColors.text3))),
          IconButton(
            tooltip: l10n.refAdmRetry,
            onPressed: () => ref.invalidate(doublonsVillesProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ]),
        const SizedBox(height: 8),
        Expanded(
          child: doublons.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text(l10n.refAdmLoadError(detailReferentiel(e)),
                  style: const TextStyle(color: AdminColors.statusRed)),
            ),
            data: (liste) => liste.isEmpty
                ? Center(child: Text(l10n.refAdmNoDuplicates))
                : ListView.separated(
                    itemCount: liste.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _CarteDoublon(d: liste[i]),
                  ),
          ),
        ),
      ],
    );
  }
}

class _CarteDoublon extends ConsumerWidget {
  const _CarteDoublon({required this.d});
  final DoublonVille d;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    Future<void> fusionner(int garder, int retirer) async {
      final motif = await _demanderMotif(context, l10n.refAdmMergeTitle,
          avertissement: l10n.refAdmMergeWarn);
      if (motif == null || !context.mounted) return;
      await _lancer(context, ref,
          () => ref.read(referentielAdminActionsProvider).fusionner(garder, retirer, motif),
          l10n.refAdmMerged, [doublonsVillesProvider, villesRefProvider]);
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        border: Border.all(color: AdminColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${d.nomA} · ${d.pays} — ${l10n.refAdmDistance('${d.distanceKm}')}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton(
              onPressed: () => fusionner(d.idA, d.idB),
              child: Text(l10n.refAdmKeepA('#${d.idA}', '${d.profilsA}', '${d.groupesA}',
                  '#${d.idB}')),
            ),
            OutlinedButton(
              onPressed: () => fusionner(d.idB, d.idA),
              child: Text(l10n.refAdmKeepA('#${d.idB}', '${d.profilsB}', '${d.groupesB}',
                  '#${d.idA}')),
            ),
          ]),
        ],
      ),
    );
  }
}

// ═══ Pays ══════════════════════════════════════════════════════════════════

class _OngletPays extends ConsumerStatefulWidget {
  const _OngletPays();

  @override
  ConsumerState<_OngletPays> createState() => _OngletPaysState();
}

class _OngletPaysState extends ConsumerState<_OngletPays> {
  String _terme = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final pays = ref.watch(paysRefProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.refAdmCountriesHelp,
            style: const TextStyle(fontSize: 12, color: AdminColors.text3)),
        const SizedBox(height: 8),
        Wrap(spacing: 12, runSpacing: 8, children: [
          SizedBox(
            width: 260,
            child: TextField(
              onChanged: (v) => setState(() => _terme = v.trim().toLowerCase()),
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                hintText: l10n.refAdmSearchCountry,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => _ajouter(context),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(l10n.refAdmNewCountry),
          ),
        ]),
        const SizedBox(height: 8),
        Expanded(
          child: pays.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text(l10n.refAdmLoadError(detailReferentiel(e)),
                  style: const TextStyle(color: AdminColors.statusRed)),
            ),
            data: (liste) {
              final vus = [
                for (final p in liste)
                  if (_terme.isEmpty || p.nom.toLowerCase().contains(_terme)) p,
              ];
              return ListView.separated(
                itemCount: vus.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) => ListTile(
                  dense: true,
                  title: Text(vus[i].nom),
                  trailing: Text(vus[i].code),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _ajouter(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final nom = TextEditingController();
    final code = TextEditingController();
    final motif = TextEditingController();
    final res = await showDialog<List<String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(l10n.refAdmNewCountry),
          content: SizedBox(
            width: 420,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: nom,
                onChanged: (_) => setLocal(() {}),
                decoration: InputDecoration(
                    labelText: l10n.refAdmFieldName, border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: code,
                onChanged: (_) => setLocal(() {}),
                maxLength: 2,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                    labelText: l10n.refAdmFieldIso, border: const OutlineInputBorder()),
              ),
              TextField(
                controller: motif,
                onChanged: (_) => setLocal(() {}),
                decoration: InputDecoration(
                    labelText: l10n.refAdmReason, border: const OutlineInputBorder()),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.refAdmCancel)),
            ElevatedButton(
              onPressed: nom.text.trim().length >= 2 &&
                      RegExp(r'^[A-Z]{2}$').hasMatch(code.text.trim()) &&
                      motif.text.trim().length >= 5
                  ? () => Navigator.pop(
                      ctx, [nom.text.trim(), code.text.trim(), motif.text.trim()])
                  : null,
              child: Text(l10n.refAdmSave),
            ),
          ],
        ),
      ),
    );
    nom.dispose();
    code.dispose();
    motif.dispose();
    if (res == null || !context.mounted) return;
    await _lancer(
      context,
      ref,
      () => ref.read(referentielAdminActionsProvider).ajouterPays(res[0], res[1], res[2]),
      l10n.refAdmSaved,
      [paysRefProvider],
    );
  }
}
