import 'package:diaspo_niger/core/theme/admin_colors.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../providers/demarches_admin_provider.dart';

/// Ce que l'éditeur rend : seulement les champs touchés (le serveur complète
/// avec la version publiée ou le brouillon en cours), la source, et le motif.
class ResultatEditeurDemarche {
  const ResultatEditeurDemarche({
    required this.demarcheId,
    required this.contenu,
    required this.sourceUrl,
    required this.sourcePublisher,
    required this.verifieLe,
    required this.prochaineRevision,
    required this.motif,
  });

  final String demarcheId;
  final Map<String, dynamic> contenu;
  final String? sourceUrl;
  final String? sourcePublisher;
  final DateTime? verifieLe;
  final DateTime? prochaineRevision;
  final String? motif;
}

const _typesDeDemande = [
  'consularId',
  'birthCertificate',
  'marriageCertificate',
  'deathCertificate',
  'passportNewRequest',
  'passportRenewal',
  'laissezPasser',
  'legalDocument',
  'other',
];

/// Le formulaire d'une démarche (spécification d'interfaces § 14).
///
/// Les pièces gardent les clés que l'éditeur ne montre pas (forme, groupe
/// alternatif, note) : on édite un champ, on n'en efface pas un autre. De même
/// pour le coût.
class EditeurDemarche extends StatefulWidget {
  const EditeurDemarche({super.key, required this.ligne, required this.rubriques});

  final LigneDemarche? ligne;
  final List<RubriqueDemarche> rubriques;

  @override
  State<EditeurDemarche> createState() => _EditeurDemarcheState();
}

class _EditeurDemarcheState extends State<EditeurDemarche> {
  late final bool _nouvelle = widget.ligne == null;
  late final Map<String, dynamic> _base;

  final _id = TextEditingController();
  final _titre = TextEditingController();
  final _resume = TextEditingController();
  final _delai = TextEditingController();
  final _coutLibelle = TextEditingController();
  final _coutMontant = TextEditingController();
  final _avertissements = TextEditingController();
  final _sourceUrl = TextEditingController();
  final _sourceEditeur = TextEditingController();
  final _motif = TextEditingController();

  String? _rubrique;
  String _typeDemande = 'other';
  String _lieu = 'consulat';
  String _coutStatut = 'inconnu';
  DateTime? _verifieLe;
  DateTime? _revision;
  late List<Map<String, dynamic>> _pieces;
  bool _modifie = false;

  @override
  void initState() {
    super.initState();
    final l = widget.ligne;
    _base = Map<String, dynamic>.from(l?.brouillon?.contenu ?? l?.live?.contenu ?? {});
    _id.text = l?.id ?? '';
    _titre.text = _base['titre'] as String? ?? '';
    _resume.text = _base['resume'] as String? ?? '';
    _delai.text = _base['delai'] as String? ?? '';
    _rubrique = _base['rubrique'] as String?;
    _typeDemande = _base['request_type'] as String? ?? 'other';
    _lieu = _base['lieu'] as String? ?? 'consulat';
    final cout = Map<String, dynamic>.from((_base['cout'] as Map?) ?? {});
    _coutLibelle.text = cout['libelle'] as String? ?? '';
    _coutMontant.text = cout['montantXof']?.toString() ?? '';
    _coutStatut = cout['statut'] as String? ?? 'inconnu';
    _avertissements.text =
        ((_base['avertissements'] as List?) ?? const []).join('\n');
    _pieces = [
      for (final p in (_base['pieces'] as List?) ?? const [])
        Map<String, dynamic>.from(p as Map),
    ];
    _sourceUrl.text = l?.brouillon?.sourceUrl ?? l?.live?.sourceUrl ?? '';
    _sourceEditeur.text =
        l?.brouillon?.sourcePublisher ?? l?.live?.sourcePublisher ?? '';
    _verifieLe = l?.brouillon?.verifieLe ?? l?.live?.verifieLe;
    _revision = l?.brouillon?.prochaineRevision ?? l?.live?.prochaineRevision;
    _motif.text = l?.brouillon?.motif ?? '';
  }

  @override
  void dispose() {
    for (final c in [
      _id, _titre, _resume, _delai, _coutLibelle, _coutMontant,
      _avertissements, _sourceUrl, _sourceEditeur, _motif,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _touch() => setState(() => _modifie = true);

  bool get _valide {
    if (_titre.text.trim().length < 3 || _rubrique == null) return false;
    if (_nouvelle && !RegExp(r'^[a-z0-9_]{3,64}$').hasMatch(_id.text)) return false;
    // Modifier une démarche existante exige un motif (le serveur le redit).
    if (!_nouvelle && widget.ligne?.brouillon == null && _motif.text.trim().isEmpty) {
      return false;
    }
    return true;
  }

  ResultatEditeurDemarche _resultat() {
    final cout = Map<String, dynamic>.from((_base['cout'] as Map?) ?? {});
    cout['libelle'] = _coutLibelle.text.trim().isEmpty ? null : _coutLibelle.text.trim();
    cout['montantXof'] = int.tryParse(_coutMontant.text.trim());
    cout['statut'] = _coutStatut;
    return ResultatEditeurDemarche(
      demarcheId: _id.text.trim(),
      contenu: {
        'titre': _titre.text.trim(),
        'rubrique': _rubrique,
        'request_type': _typeDemande,
        'lieu': _lieu,
        'resume': _resume.text.trim().isEmpty ? null : _resume.text.trim(),
        'delai': _delai.text.trim().isEmpty ? null : _delai.text.trim(),
        'cout': cout,
        'pieces': [
          for (final p in _pieces)
            if ((p['libelle'] as String? ?? '').trim().isNotEmpty) p,
        ],
        'avertissements': [
          for (final ligne in _avertissements.text.split('\n'))
            if (ligne.trim().isNotEmpty) ligne.trim(),
        ],
      },
      sourceUrl: _sourceUrl.text.trim().isEmpty ? null : _sourceUrl.text.trim(),
      sourcePublisher:
          _sourceEditeur.text.trim().isEmpty ? null : _sourceEditeur.text.trim(),
      verifieLe: _verifieLe,
      prochaineRevision: _revision,
      motif: _motif.text.trim().isEmpty ? null : _motif.text.trim(),
    );
  }

  Future<void> _choisirDate(bool verification) async {
    final now = DateTime.now();
    final choisie = await showDatePicker(
      context: context,
      initialDate: (verification ? _verifieLe : _revision) ?? now,
      firstDate: DateTime(2020),
      lastDate: verification ? now : DateTime(now.year + 5),
    );
    if (choisie == null) return;
    setState(() {
      if (verification) {
        _verifieLe = choisie;
      } else {
        _revision = choisie;
      }
      _modifie = true;
    });
  }

  String _jour(DateTime? d) => d == null
      ? '—'
      : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final statuts = {
      'connu': l10n.demAdmCostStatusKnown,
      'inconnu': l10n.demAdmCostStatusUnknown,
      'non_mentionne': l10n.demAdmCostStatusNotMentioned,
      'variable_par_pays': l10n.demAdmCostStatusVariable,
    };
    final types = {..._typesDeDemande, _typeDemande}.toList();

    return PopScope(
      canPop: !_modifie,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final quitter = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            content: Text(l10n.demAdmUnsaved),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(l10n.demAdmCancel)),
              ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(l10n.demAdmConfirm)),
            ],
          ),
        );
        if (quitter == true && context.mounted) Navigator.pop(context);
      },
      child: Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 820),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Row(children: [
                  Expanded(
                    child: Text(
                      _nouvelle ? l10n.demAdmEditorNewTitle : l10n.demAdmEditorEditTitle,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.demAdmCancel,
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ]),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_nouvelle) ...[
                        _champ(_id, l10n.demAdmFieldId),
                        const SizedBox(height: 12),
                      ],
                      _champ(_titre, l10n.demAdmFieldTitle, max: 200),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: widget.rubriques.any((r) => r.id == _rubrique) ? _rubrique : null,
                        isExpanded: true,
                        decoration: _deco(l10n.demAdmFieldRubrique),
                        items: [
                          for (final r in widget.rubriques)
                            DropdownMenuItem(value: r.id, child: Text(r.titre)),
                        ],
                        onChanged: (v) {
                          _rubrique = v;
                          _touch();
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _typeDemande,
                            isExpanded: true,
                            decoration: _deco(l10n.demAdmFieldRequestType),
                            items: [
                              for (final t in types)
                                DropdownMenuItem(value: t, child: Text(t)),
                            ],
                            onChanged: (v) {
                              _typeDemande = v ?? _typeDemande;
                              _touch();
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: ['consulat', 'tribunal_niger'].contains(_lieu) ? _lieu : 'consulat',
                            isExpanded: true,
                            decoration: _deco(l10n.demAdmFieldLieu),
                            items: [
                              DropdownMenuItem(
                                  value: 'consulat', child: Text(l10n.demAdmLieuConsulat)),
                              DropdownMenuItem(
                                  value: 'tribunal_niger',
                                  child: Text(l10n.demAdmLieuTribunal)),
                            ],
                            onChanged: (v) {
                              _lieu = v ?? _lieu;
                              _touch();
                            },
                          ),
                        ),
                      ]),
                      const SizedBox(height: 12),
                      _champ(_resume, l10n.demAdmFieldSummary, lignes: 4, max: 2000),
                      const SizedBox(height: 12),
                      _champ(_delai, l10n.demAdmFieldDelai),
                      const SizedBox(height: 16),
                      Text(l10n.demAdmCost,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      _champ(_coutLibelle, l10n.demAdmFieldCostLabel),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: _champ(_coutMontant, l10n.demAdmFieldCostAmount,
                              clavier: TextInputType.number),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: statuts.containsKey(_coutStatut) ? _coutStatut : 'inconnu',
                            isExpanded: true,
                            decoration: _deco(l10n.demAdmFieldCostStatus),
                            items: [
                              for (final e in statuts.entries)
                                DropdownMenuItem(value: e.key, child: Text(e.value)),
                            ],
                            onChanged: (v) {
                              _coutStatut = v ?? _coutStatut;
                              _touch();
                            },
                          ),
                        ),
                      ]),
                      const SizedBox(height: 16),
                      Text(l10n.demAdmPiecesTitle,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      for (var i = 0; i < _pieces.length; i++) _lignePiece(i, l10n),
                      TextButton.icon(
                        onPressed: () {
                          _pieces.add({'libelle': '', 'obligatoire': true, 'quantite': 1});
                          _touch();
                        },
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: Text(l10n.demAdmAddPiece),
                      ),
                      const SizedBox(height: 12),
                      _champ(_avertissements, l10n.demAdmWarningsTitle, lignes: 4),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AdminColors.surfaceAlt,
                          border: Border.all(color: AdminColors.border),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.demAdmSourceTitle,
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            _champ(_sourceUrl, l10n.demAdmFieldSourceUrl),
                            const SizedBox(height: 12),
                            _champ(_sourceEditeur, l10n.demAdmFieldSourcePublisher),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text('${l10n.demAdmFieldVerifiedAt} : ${_jour(_verifieLe)}'),
                                OutlinedButton(
                                    onPressed: () => _choisirDate(true),
                                    child: Text(l10n.demAdmPickDate)),
                                Text('${l10n.demAdmFieldNextReview} : ${_jour(_revision)}'),
                                OutlinedButton(
                                    onPressed: () => _choisirDate(false),
                                    child: Text(l10n.demAdmPickDate)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _champ(
                        _motif,
                        _nouvelle
                            ? l10n.demAdmFieldChangeReasonNew
                            : l10n.demAdmFieldChangeReason,
                        lignes: 2,
                        max: 1000,
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                        onPressed: () => Navigator.maybePop(context),
                        child: Text(l10n.demAdmCancel)),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _valide ? () => Navigator.pop(context, _resultat()) : null,
                      child: Text(l10n.demAdmSaveDraft),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _lignePiece(int i, AppLocalizations l10n) {
    final p = _pieces[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextFormField(
              key: ValueKey('piece-$i-${_pieces.length}'),
              initialValue: p['libelle'] as String? ?? '',
              onChanged: (v) {
                p['libelle'] = v;
                _modifie = true;
              },
              decoration: _deco(l10n.demAdmPieceLabel),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 64,
            child: TextFormField(
              key: ValueKey('qte-$i-${_pieces.length}'),
              initialValue: '${p['quantite'] ?? 1}',
              keyboardType: TextInputType.number,
              onChanged: (v) {
                p['quantite'] = int.tryParse(v) ?? 1;
                _modifie = true;
              },
              decoration: _deco(l10n.demAdmPieceQuantity),
            ),
          ),
          Column(children: [
            Text(l10n.demAdmPieceRequired, style: const TextStyle(fontSize: 10)),
            Switch(
              value: p['obligatoire'] as bool? ?? true,
              onChanged: (v) {
                p['obligatoire'] = v;
                _touch();
              },
            ),
          ]),
          IconButton(
            tooltip: l10n.demAdmRemovePiece,
            onPressed: () {
              _pieces.removeAt(i);
              _touch();
            },
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }

  InputDecoration _deco(String libelle) =>
      InputDecoration(labelText: libelle, border: const OutlineInputBorder(), isDense: true);

  Widget _champ(
    TextEditingController c,
    String libelle, {
    int lignes = 1,
    int? max,
    TextInputType? clavier,
  }) =>
      TextField(
        controller: c,
        onChanged: (_) => _touch(),
        maxLines: lignes,
        maxLength: max,
        keyboardType: clavier,
        decoration: _deco(libelle),
      );
}
