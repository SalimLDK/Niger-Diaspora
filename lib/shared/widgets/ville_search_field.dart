import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/utils/locale_helper.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import '../../core/providers/villes_provider.dart';
import '../../core/theme/adaptive_colors.dart';
import 'custom_text_field.dart';

/// Champ ville : une recherche dans le référentiel, pas un champ de texte nu.
///
/// « Mont… » propose Montréal. Le choix de l'usager est une LIGNE de
/// `public.villes` ([onVilleChoisie]), et c'est elle qui ouvrira un groupe de
/// ville. Rien n'oblige à choisir : le texte saisi reste valable — le profil
/// le garde dans sa colonne `city`, simplement sans groupe.
///
/// Le champ ne ment pas sur son état : tant qu'aucune ligne n'est retenue, la
/// pastille de gauche reste éteinte. C'est la différence entre « j'habite à
/// Montréal, la ville que la base connaît » et « j'ai tapé Montreal ».
class VilleSearchField extends ConsumerStatefulWidget {
  const VilleSearchField({
    super.key,
    required this.controller,
    required this.onVilleChoisie,
    this.villeChoisie,
    this.pays,
    this.label,
    this.enabled = true,
  });

  /// Le texte saisi. Reste la source de `users.city`.
  final TextEditingController controller;

  /// Appelé avec la ligne retenue, ou `null` dès que l'usager retouche le
  /// texte — une ville choisie puis modifiée n'est plus cette ville.
  final ValueChanged<Ville?> onVilleChoisie;

  /// Ligne actuellement retenue, si l'écran en porte une.
  final Ville? villeChoisie;

  /// Nom du pays (« Canada ») ou code hérité (« CA »). `null` cherche partout.
  final String? pays;

  final String? label;
  final bool enabled;

  @override
  ConsumerState<VilleSearchField> createState() => _VilleSearchFieldState();
}

class _VilleSearchFieldState extends ConsumerState<VilleSearchField> {
  final FocusNode _focus = FocusNode();
  String _texte = '';
  bool _ouvert = false;

  @override
  void initState() {
    super.initState();
    _texte = widget.controller.text;
    _focus.addListener(() {
      if (!mounted) return;
      setState(() => _ouvert = _focus.hasFocus);
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _surSaisie(String valeur) {
    // Toute frappe défait le choix : sinon le profil garderait `ville_id` de
    // Montréal avec « Montreu » écrit dans `city`.
    if (widget.villeChoisie != null) widget.onVilleChoisie(null);
    setState(() => _texte = valeur);
  }

  void _choisir(Ville ville) {
    widget.controller.text = ville.nom;
    widget.controller.selection =
        TextSelection.collapsed(offset: ville.nom.length);
    widget.onVilleChoisie(ville);
    setState(() => _texte = ville.nom);
    _focus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final choisie = widget.villeChoisie;

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
          suffix: choisie == null
              ? null
              : Icon(Icons.check_circle, size: 18, color: context.successColor),
        ),
        if (_ouvert && widget.enabled) _suggestions(l10n),
      ],
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
