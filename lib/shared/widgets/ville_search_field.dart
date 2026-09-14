import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/providers/villes_provider.dart';
import '../../core/theme/adaptive_colors.dart';
import '../../core/utils/locale_helper.dart';
import '../../core/widgets/location_disclosure.dart';
import 'custom_text_field.dart';

/// Champ ville : une recherche dans le référentiel, pas un champ de texte nu.
///
/// « Mont… » propose Montréal. Le choix de l'usager est une LIGNE de
/// `public.villes` ([onVilleChoisie]), et c'est elle qui ouvrira un groupe de
/// ville. Rien n'oblige à choisir : le texte saisi reste valable — le profil
/// le garde dans sa colonne `city`, simplement sans groupe.
///
/// Le champ ne ment pas sur son état : tant qu'aucune ligne n'est retenue, la
/// pastille reste éteinte. C'est la différence entre « j'habite à Montréal, la
/// ville que la base connaît » et « j'ai tapé Montreal ».
class VilleSearchField extends ConsumerStatefulWidget {
  const VilleSearchField({
    super.key,
    required this.controller,
    required this.onVilleChoisie,
    this.villeChoisieId,
    this.pays,
    this.label,
    this.enabled = true,
    this.autoriserLocalisation = false,
    this.focusNode,
  });

  /// Le texte saisi. Reste la source de `users.city`.
  final TextEditingController controller;

  /// Appelé avec la ligne retenue, ou `null` dès que l'usager retouche le
  /// texte — une ville choisie puis modifiée n'est plus cette ville.
  final ValueChanged<Ville?> onVilleChoisie;

  /// Identifiant de la ligne actuellement retenue, si l'écran en porte une.
  ///
  /// Un identifiant, et pas un [Ville] : au chargement d'un profil, l'écran ne
  /// connaît que `users.ville_id`. Fabriquer un [Ville] à partir de ce qu'on
  /// a sous la main donnerait un objet à moitié faux.
  final int? villeChoisieId;

  /// Nom du pays (« Canada ») ou code hérité (« CA »). `null` cherche partout.
  final String? pays;

  final String? label;
  final bool enabled;

  /// Propose « Utiliser ma position ». Faux par défaut : lire la position est
  /// un accès à demander, pas un service à rendre d'office.
  final bool autoriserLocalisation;

  /// Focus tenu par l'écran, quand il a besoin d'amener l'usager sur ce champ
  /// — le profil le fait pour « champ à corriger » (§11f). Le champ n'en
  /// dispose pas : il ne l'a pas créé.
  final FocusNode? focusNode;

  @override
  ConsumerState<VilleSearchField> createState() => _VilleSearchFieldState();
}

class _VilleSearchFieldState extends ConsumerState<VilleSearchField> {
  late final FocusNode _focus;
  String _texte = '';
  bool _ouvert = false;

  Ville? _proposition;
  bool _localisationEnCours = false;
  String? _messageLocalisation;

  @override
  void initState() {
    super.initState();
    _focus = widget.focusNode ?? FocusNode();
    _texte = widget.controller.text;
    _focus.addListener(() {
      if (!mounted) return;
      setState(() => _ouvert = _focus.hasFocus);
    });
  }

  @override
  void dispose() {
    if (widget.focusNode == null) _focus.dispose();
    super.dispose();
  }

  void _surSaisie(String valeur) {
    // Toute frappe défait le choix : sinon le profil garderait `ville_id` de
    // Montréal avec « Montreu » écrit dans `city`.
    if (widget.villeChoisieId != null) widget.onVilleChoisie(null);
    setState(() {
      _texte = valeur;
      _proposition = null;
      _messageLocalisation = null;
    });
  }

  void _choisir(Ville ville) {
    widget.controller.text = ville.nom;
    widget.controller.selection =
        TextSelection.collapsed(offset: ville.nom.length);
    widget.onVilleChoisie(ville);
    setState(() {
      _texte = ville.nom;
      _proposition = null;
      _messageLocalisation = null;
    });
    _focus.unfocus();
  }

  /// « Vous êtes à Montréal ? »
  ///
  /// Trois choses, dans cet ordre, et aucune n'est facultative :
  ///
  /// 1. la divulgation avant la boîte système — c'est ce que Google a refusé
  ///    le 2026-09-09 quand elle manquait, et le texte de `champVille` dit ce
  ///    qui se passe vraiment ici : lecture unique, rien d'enregistré, rien de
  ///    partagé, pas de place sur la carte des membres ;
  /// 2. une précision BASSE. Une ville se trouve au kilomètre près ; demander
  ///    mieux serait collecter plus que nécessaire pour la même réponse ;
  /// 3. c'est la ville de la LISTE la plus proche des coordonnées qui est
  ///    proposée, jamais le texte que renvoie le géocodage de l'appareil —
  ///    c'est lui qui écrirait « Almoustapha » dans un profil.
  Future<void> _localiser() async {
    final l10n = context.l10n;
    setState(() {
      _messageLocalisation = null;
      _localisationEnCours = true;
    });
    try {
      final autorise = await demanderLocalisationAvecDivulgation(
        context,
        usage: UsageLocalisation.champVille,
      );
      if (!mounted) return;
      if (!autorise) {
        setState(() => _localisationEnCours = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 15),
        ),
      );
      final ville = await ref.read(villesServiceProvider).laPlusProche(
            latitude: position.latitude,
            longitude: position.longitude,
          );
      if (!mounted) return;
      setState(() {
        _localisationEnCours = false;
        _proposition = ville;
        _messageLocalisation = ville == null ? l10n.cityNoneNearby : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _localisationEnCours = false;
        _messageLocalisation = l10n.cityLocationFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final retenue = widget.villeChoisieId != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CustomTextField(
          controller: widget.controller,
          focusNode: _focus,
          label: widget.label ?? l10n.currentCity,
          hint: l10n.cityFieldHint,
          enabled: widget.enabled,
          onChanged: _surSaisie,
          prefixIcon: Icons.location_city_outlined,
          suffix: retenue
              ? Icon(Icons.check_circle, size: 18, color: context.successColor)
              : null,
        ),
        if (_proposition != null) _proposer(l10n, _proposition!),
        if (_messageLocalisation != null)
          _ligneTexte(_messageLocalisation!, context.textTertiaryColor),
        if (widget.autoriserLocalisation && widget.enabled && !retenue)
          _boutonLocalisation(l10n),
        if (_ouvert && widget.enabled) _suggestions(l10n),
      ],
    );
  }

  Widget _boutonLocalisation(AppLocalizations l10n) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton.icon(
        onPressed: _localisationEnCours ? null : _localiser,
        icon: _localisationEnCours
            ? const SizedBox(
                height: 14,
                width: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.my_location, size: 16),
        label: Text(l10n.cityUseMyLocation, style: const TextStyle(fontSize: 13)),
      ),
    );
  }

  Widget _proposer(AppLocalizations l10n, Ville ville) {
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.spacing8),
      padding: const EdgeInsets.all(AppSpacing.spacing12),
      decoration: BoxDecoration(
        color: context.primaryBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.cityNearbyQuestion(ville.libelle),
            style: TextStyle(fontSize: 13, color: context.textPrimaryColor),
          ),
          const SizedBox(height: AppSpacing.spacing4),
          Row(
            children: [
              TextButton(
                onPressed: () => _choisir(ville),
                child: Text(l10n.cityNearbyConfirm),
              ),
              TextButton(
                onPressed: () => setState(() => _proposition = null),
                child: Text(l10n.no),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _suggestions(AppLocalizations l10n) {
    final critere = RechercheVille(pays: widget.pays, texte: _texte.trim());
    final resultats = ref.watch(rechercheVillesProvider(critere));

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.spacing4),
      decoration: BoxDecoration(
        color: context.surfaceElevatedColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderColor),
      ),
      child: resultats.when(
        // `when` et non `.value` : en Riverpod 2, lire `.value` sur une erreur
        // la relance, et le champ tomberait en écran rouge hors ligne.
        loading: () => _ligneSimple(const SizedBox(
          height: 16,
          width: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        )),
        error: (_, __) => _ligneTexte(l10n.citySearchFailed, context.errorColor),
        data: (villes) {
          if (villes.isEmpty) {
            return _ligneTexte(
              _texte.trim().isEmpty ? l10n.cityTypeToSearch : l10n.cityNoResult,
              context.textTertiaryColor,
            );
          }
          return ListView.separated(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: villes.length > 6 ? 6 : villes.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: context.borderColor),
            itemBuilder: (context, i) {
              final ville = villes[i];
              return InkWell(
                onTap: () => _choisir(ville),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.spacing16,
                    vertical: AppSpacing.spacing8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          ville.libelle,
                          style: TextStyle(color: context.textPrimaryColor),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        ville.pays,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textTertiaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _ligneSimple(Widget enfant) => Padding(
        padding: const EdgeInsets.all(AppSpacing.spacing16),
        child: Center(child: enfant),
      );

  Widget _ligneTexte(String texte, Color couleur) => Padding(
        padding: const EdgeInsets.all(AppSpacing.spacing16),
        child: Text(texte, style: TextStyle(fontSize: 13, color: couleur)),
      );
}
