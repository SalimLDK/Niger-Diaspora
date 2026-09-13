import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/adaptive_colors.dart';
import '../../../../shared/widgets/sheet_handle.dart';
import '../../../groups/presentation/providers/group_provider.dart';
import '../../../groups/presentation/providers/invite_candidates_provider.dart';
import '../../domain/entities/event_audience.dart';

/// « Qui peut voir cet événement ? » — quatre choix posés en haut du
/// formulaire.
///
/// Remplace l'interrupteur « Publier dans le fil public » relégué sous la
/// catégorie : on ne le trouvait pas, et sa promesse (« visible uniquement par
/// les participants ») n'était de toute façon pas tenue par la base.
class EventAudiencePicker extends ConsumerWidget {
  final EventAudience audience;
  final ValueChanged<EventAudience> onChanged;

  /// Événement né d'une discussion : le choix « cette discussion » existe.
  final bool depuisUneDiscussion;

  /// Groupe d'origine (libellé « Membres du groupe » plutôt que
  /// « Participants de la discussion »).
  final bool depuisUnGroupe;

  const EventAudiencePicker({
    super.key,
    required this.audience,
    required this.onChanged,
    required this.depuisUneDiscussion,
    this.depuisUnGroupe = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final choix = <_Choix>[
      if (depuisUneDiscussion)
        _Choix(
          EventVisibility.discussion,
          Icons.forum_outlined,
          depuisUnGroupe ? 'Ce groupe' : 'Cette discussion',
          depuisUnGroupe
              ? 'Uniquement les membres du groupe.'
              : 'Uniquement les participants de la conversation.',
        ),
      _Choix(
        EventVisibility.groups,
        Icons.groups_outlined,
        'Mes groupes',
        audience.groups.isEmpty
            ? 'Les membres des groupes que vous choisissez.'
            : _resume(audience.groups.values),
      ),
      _Choix(
        EventVisibility.people,
        Icons.person_add_alt_1_outlined,
        'Personnes choisies',
        audience.people.isEmpty
            ? 'Seulement les personnes invitées (elles sont prévenues).'
            : _resume(audience.people.values),
      ),
      _Choix(
        EventVisibility.public,
        Icons.public,
        'Tout le monde',
        'Visible dans Événements par tous les membres.',
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < choix.length; i++) ...[
            if (i > 0)
              Container(height: 1, color: context.borderColor),
            _LigneChoix(
              choix: choix[i],
              actif: audience.visibility == choix[i].valeur,
              onTap: () => _choisir(context, choix[i].valeur),
            ),
          ],
        ],
      ),
    );
  }

  static String _resume(Iterable<String> noms) {
    final liste = noms.toList();
    if (liste.length <= 2) return liste.join(', ');
    return '${liste.take(2).join(', ')} et ${liste.length - 2} autre'
        '${liste.length - 2 > 1 ? 's' : ''}';
  }

  Future<void> _choisir(BuildContext context, EventVisibility valeur) async {
    switch (valeur) {
      case EventVisibility.groups:
        final groupes = await showModalBottomSheet<Map<String, String>>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _FeuilleGroupes(initial: audience.groups),
        );
        if (groupes == null) return;
        onChanged(
          audience.copyWith(
            visibility: groupes.isEmpty ? audience.visibility : valeur,
            groups: groupes,
          ),
        );
      case EventVisibility.people:
        final personnes = await showModalBottomSheet<Map<String, String>>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _FeuillePersonnes(initial: audience.people),
        );
        if (personnes == null) return;
        onChanged(
          audience.copyWith(
            visibility: personnes.isEmpty ? audience.visibility : valeur,
            people: personnes,
          ),
        );
      case EventVisibility.discussion:
      case EventVisibility.public:
        onChanged(audience.copyWith(visibility: valeur));
    }
  }
}

class _Choix {
  final EventVisibility valeur;
  final IconData icone;
  final String titre;
  final String detail;
  const _Choix(this.valeur, this.icone, this.titre, this.detail);
}

class _LigneChoix extends StatelessWidget {
  final _Choix choix;
  final bool actif;
  final VoidCallback onTap;

  const _LigneChoix({
    required this.choix,
    required this.actif,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = context.adaptivePrimaryColor;
    final aSousChoix = choix.valeur == EventVisibility.groups ||
        choix.valeur == EventVisibility.people;
    return Material(
      color: actif ? accent.withValues(alpha: 0.08) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(
                choix.icone,
                size: 22,
                color: actif ? accent : context.textSecondaryColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      choix.titre,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      choix.detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textTertiaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (aSousChoix && actif)
                Icon(Icons.edit_outlined, size: 18, color: accent)
              else if (aSousChoix)
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: context.textTertiaryColor,
                ),
              const SizedBox(width: 4),
              Icon(
                actif ? Icons.radio_button_checked : Icons.radio_button_off,
                size: 22,
                color: actif ? accent : context.textTertiaryColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Coque commune des deux feuilles : poignée, titre, contenu, bouton valider.
class _Feuille extends StatelessWidget {
  final String titre;
  final Widget? entete;
  final Widget contenu;
  final int nombre;
  final VoidCallback onValider;

  const _Feuille({
    required this.titre,
    required this.contenu,
    required this.nombre,
    required this.onValider,
    this.entete,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Container(
      height: media.size.height * 0.75,
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          const SheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                titre,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimaryColor,
                ),
              ),
            ),
          ),
          if (entete != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: entete,
            ),
          Expanded(child: contenu),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onValider,
                  child: Text(nombre == 0 ? 'Valider' : 'Valider ($nombre)'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeuilleGroupes extends ConsumerStatefulWidget {
  final Map<String, String> initial;
  const _FeuilleGroupes({required this.initial});

  @override
  ConsumerState<_FeuilleGroupes> createState() => _FeuilleGroupesState();
}

class _FeuilleGroupesState extends ConsumerState<_FeuilleGroupes> {
  late final Map<String, String> _choisis = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    final groupes = ref.watch(myGroupsNotifierProvider);
    return _Feuille(
      titre: 'Quels groupes ?',
      nombre: _choisis.length,
      onValider: () => Navigator.pop(context, _choisis),
      contenu: groupes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _Vide('Impossible de charger vos groupes.'),
        data: (liste) {
          if (liste.isEmpty) {
            return _Vide('Vous n\'êtes membre d\'aucun groupe.');
          }
          return ListView.builder(
            itemCount: liste.length,
            itemBuilder: (context, i) {
              final g = liste[i];
              final coche = _choisis.containsKey(g.id);
              return CheckboxListTile(
                value: coche,
                onChanged: (_) => setState(() {
                  coche ? _choisis.remove(g.id) : _choisis[g.id] = g.name;
                }),
                title: Text(g.name, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  '${g.memberIds.length} membre${g.memberIds.length > 1 ? 's' : ''}',
                ),
                secondary: _Avatar(url: g.imageUrl, icone: Icons.groups),
                controlAffinity: ListTileControlAffinity.trailing,
              );
            },
          );
        },
      ),
    );
  }
}

class _FeuillePersonnes extends ConsumerStatefulWidget {
  final Map<String, String> initial;
  const _FeuillePersonnes({required this.initial});

  @override
  ConsumerState<_FeuillePersonnes> createState() => _FeuillePersonnesState();
}

class _FeuillePersonnesState extends ConsumerState<_FeuillePersonnes> {
  late final Map<String, String> _choisis = {...widget.initial};
  final _recherche = TextEditingController();
  Timer? _attente;
  String _requete = '';

  /// Clé de famille figée une fois : comparée par identité (voir
  /// `inviteSuggestionsProvider`).
  static const List<String> _aucuneExclusion = [];

  @override
  void dispose() {
    _attente?.cancel();
    _recherche.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resultats = _requete.trim().length >= 2
        ? ref.watch(inviteSearchProvider(_requete))
        : ref.watch(inviteSuggestionsProvider(_aucuneExclusion));

    return _Feuille(
      titre: 'Qui inviter ?',
      nombre: _choisis.length,
      onValider: () => Navigator.pop(context, _choisis),
      entete: TextField(
        controller: _recherche,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Rechercher un membre',
          prefixIcon: const Icon(Icons.search, size: 20),
          filled: true,
          fillColor: context.surfaceVariantColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (v) {
          _attente?.cancel();
          _attente = Timer(
            const Duration(milliseconds: 350),
            () => mounted ? setState(() => _requete = v) : null,
          );
        },
      ),
      contenu: resultats.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _Vide('Recherche indisponible pour le moment.'),
        data: (liste) {
          // Les personnes déjà choisies restent en tête, même hors résultats.
          final ids = {for (final c in liste) c.id};
          final lignes = <(String, String, String?)>[
            for (final e in _choisis.entries)
              if (!ids.contains(e.key)) (e.key, e.value, null),
            for (final c in liste) (c.id, c.displayName, c.photoUrl),
          ];
          if (lignes.isEmpty) {
            return _Vide(
              _requete.trim().length >= 2
                  ? 'Personne ne correspond.'
                  : 'Tapez au moins deux lettres d\'un nom.',
            );
          }
          return ListView.builder(
            itemCount: lignes.length,
            itemBuilder: (context, i) {
              final (id, nom, photo) = lignes[i];
              final coche = _choisis.containsKey(id);
              return CheckboxListTile(
                value: coche,
                onChanged: (_) => setState(() {
                  coche ? _choisis.remove(id) : _choisis[id] = nom;
                }),
                title: Text(nom, overflow: TextOverflow.ellipsis),
                secondary: _Avatar(url: photo, icone: Icons.person),
                controlAffinity: ListTileControlAffinity.trailing,
              );
            },
          );
        },
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? url;
  final IconData icone;
  const _Avatar({required this.url, required this.icone});

  @override
  Widget build(BuildContext context) {
    final accent = context.adaptivePrimaryColor;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: url != null && url!.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: url!,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Icon(icone, color: accent),
            )
          : Icon(icone, color: accent),
    );
  }
}

class _Vide extends StatelessWidget {
  final String texte;
  const _Vide(this.texte);

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        texte,
        textAlign: TextAlign.center,
        style: TextStyle(color: context.textTertiaryColor),
      ),
    ),
  );
}
