import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:diaspo_niger/l10n/app_localizations.dart';

import '../../../../core/theme/adaptive_colors.dart';
import '../../../../core/theme/design_kit.dart';
import '../../../../shared/widgets/sheet_handle.dart';
import '../../domain/entities/group_entity.dart';
import '../../domain/entities/group_invite_entity.dart';
import '../providers/group_request_provider.dart';
import '../providers/invite_candidates_provider.dart';

/// Qui peut inviter dans un groupe : ses administrateurs, personne d'autre.
///
/// Calqué sur `is_group_admin()` côté base — `GroupEntity.adminIds` est
/// justement reconstruit depuis `group_members` avec les rôles `owner`/`admin`
/// — parce que c'est la policy RLS qui tranche à l'arrivée. Une entrée offerte
/// plus largement que la policy se solderait par un refus muet, le défaut que
/// ce module a déjà payé plusieurs fois.
///
/// `creatorId` n'ouvre volontairement pas ce droit : sur un groupe officiel il
/// désigne le compte perso qui a déclenché la création, sans rôle réel en base
/// (cf. `docs/ops/GROUPES_OFFICIELS.md`).
bool peutInviterDansGroupe(GroupEntity group, String? userId) =>
    userId != null && group.adminIds.contains(userId);

/// Feuille « Inviter des membres » : la seule façon, dans l'app, de faire
/// entrer quelqu'un dans un groupe privé.
///
/// Elle écrit une ligne `group_invites` ; l'invité la voit dans l'onglet
/// Groupes et c'est lui qui s'inscrit en acceptant. Ce détour n'est pas un
/// choix d'interface : `group_members` n'accepte que des lignes où l'appelant
/// est lui-même le membre inséré (policy `group_members_own`), un
/// administrateur ne *peut* donc pas inscrire quelqu'un d'autre directement.
class InviteMembersSheet extends ConsumerStatefulWidget {
  const InviteMembersSheet({super.key, required this.group});

  final GroupEntity group;

  static Future<void> show(
    BuildContext context, {
    required GroupEntity group,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => InviteMembersSheet(group: group),
    );
  }

  @override
  ConsumerState<InviteMembersSheet> createState() => _InviteMembersSheetState();
}

class _InviteMembersSheetState extends ConsumerState<InviteMembersSheet> {
  final TextEditingController _searchController = TextEditingController();

  /// Figée une fois : c'est la clé de famille de `inviteSuggestionsProvider`,
  /// comparée par identité (cf. le commentaire du provider).
  late final List<String> _excludeIds;
  late final Set<String> _memberIds;

  /// Requête réellement appliquée, distincte du texte tapé : la recherche part
  /// en réseau, on la laisse retomber avant de l'envoyer.
  String _query = '';
  Timer? _debounce;

  /// Sélection conservée par id ET par candidat : le nom est exigé à l'écriture
  /// de l'invitation, et la liste sous les yeux change quand la recherche
  /// change. Ne garder que les ids perdrait le nom d'un choix fait plus tôt.
  final Map<String, InviteCandidate> _selected = {};

  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _excludeIds = List.unmodifiable(widget.group.memberIds);
    _memberIds = widget.group.memberIds.toSet();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    // `DesignSearchField` lit `controller.text` au build (croix d'effacement) :
    // sans ce setState immédiat, la croix n'apparaîtrait qu'au débat suivant.
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _query = value);
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    setState(() => _query = '');
  }

  Future<void> _send() async {
    if (_selected.isEmpty || _sending) return;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() => _sending = true);
    final notifier = ref.read(groupInviteNotifierProvider.notifier);

    final envoyes = <String>{};
    final echoues = <String>[];
    for (final candidat in _selected.values) {
      final ok = await notifier.inviteUser(
        groupId: widget.group.id,
        groupName: widget.group.name,
        groupImageUrl: widget.group.imageUrl,
        inviteeId: candidat.id,
        inviteeName: candidat.displayName,
        inviteePhotoUrl: candidat.photoUrl,
      );
      if (ok) {
        envoyes.add(candidat.id);
      } else {
        echoues.add(candidat.displayName);
      }
    }

    if (!mounted) return;
    setState(() => _sending = false);

    if (echoues.isEmpty) {
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.inviteSent),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Le compte-rendu nomme les personnes plutôt que d'annoncer « n
    // invitations » : quand une partie seulement échoue, savoir laquelle est
    // la seule information utile. Les envois réussis quittent la sélection
    // pour qu'un second appui ne les rejoue pas.
    setState(() => _selected.removeWhere((id, _) => envoyes.contains(id)));
    messenger.showSnackBar(
      SnackBar(
        content: Text('${l10n.inviteError} : ${echoues.join(', ')}'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final insets = MediaQuery.viewInsetsOf(context).bottom;
    final hauteur = (MediaQuery.sizeOf(context).height * 0.8 - insets).clamp(
      240.0,
      double.infinity,
    );

    // Invitations déjà posées sur ce groupe : une invitation en attente rend
    // la personne non sélectionnable, sinon l'`upsert` réécrirait la même
    // ligne sans que rien ne se passe de plus côté invité.
    final invitations =
        ref.watch(groupSentInvitesProvider(widget.group.id)).valueOrNull ??
        const <GroupInviteEntity>[];
    final enAttente = {
      for (final invitation in invitations)
        if (invitation.status == GroupInviteStatus.pending)
          invitation.inviteeId,
    };

    final recherche = _query.trim().length >= 2;
    final resultats =
        recherche
            ? ref.watch(inviteSearchProvider(_query))
            : ref.watch(inviteSuggestionsProvider(_excludeIds));

    // La recherche ratisse tous les profils visibles : c'est ici que les
    // membres déjà présents en sortent, le provider de recherche ne les
    // connaît pas.
    final candidats = [
      for (final candidat in resultats.valueOrNull ?? const <InviteCandidate>[])
        if (!_memberIds.contains(candidat.id)) candidat,
    ];

    return Padding(
      padding: EdgeInsets.only(bottom: insets),
      child: SizedBox(
        height: hauteur,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: context.backgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: SheetHandle(),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.person_add_alt_1_outlined,
                      color: context.adaptivePrimaryColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.inviteMember,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: context.textPrimaryColor,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: context.textSecondaryColor,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: DesignSearchField(
                  controller: _searchController,
                  hintText: l10n.searchMember,
                  onChanged: _onSearchChanged,
                  onClear: _clearSearch,
                  active: recherche,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _buildListe(
                  l10n: l10n,
                  recherche: recherche,
                  resultats: resultats,
                  candidats: candidats,
                  enAttente: enAttente,
                ),
              ),
              _buildBarreBasse(l10n),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListe({
    required AppLocalizations l10n,
    required bool recherche,
    required AsyncValue<List<InviteCandidate>> resultats,
    required List<InviteCandidate> candidats,
    required Set<String> enAttente,
  }) {
    // `valueOrNull`, jamais `value` : en Riverpod 2 ce dernier RELANCE
    // l'erreur au lieu de rendre null, et l'écran rouge remplacerait la
    // feuille dès que la recherche part hors ligne.
    if (resultats.isLoading && resultats.valueOrNull == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (resultats.hasError && resultats.valueOrNull == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.loadingError,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.textSecondaryColor),
          ),
        ),
      );
    }
    if (candidats.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            recherche
                ? l10n.noResultsFound
                : 'Personne à suggérer pour l\'instant. Cherchez par nom '
                    'ci-dessus.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: context.textSecondaryColor,
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      itemCount: candidats.length,
      itemBuilder: (context, index) {
        final candidat = candidats[index];
        return _TuileCandidat(
          candidat: candidat,
          deja: enAttente.contains(candidat.id),
          selectionne: _selected.containsKey(candidat.id),
          onTap:
              () => setState(() {
                if (_selected.remove(candidat.id) == null) {
                  _selected[candidat.id] = candidat;
                }
              }),
        );
      },
    );
  }

  Widget _buildBarreBasse(AppLocalizations l10n) {
    final nombre = _selected.length;
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.paddingOf(context).bottom + 12,
      ),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        border: Border(top: BorderSide(color: context.borderColor)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            // Dire d'emblée que l'invité doit accepter : sans ça, un
            // administrateur revient sur la fiche, ne voit pas le nouveau
            // membre et croit que l'invitation a échoué.
            'L\'invitation apparaît dans l\'onglet Groupes de la personne, '
            'qui entre dans le groupe en l\'acceptant.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: context.textTertiaryColor,
            ),
          ),
          const SizedBox(height: 12),
          DesignPrimaryButton(
            label:
                nombre > 0
                    ? '${l10n.inviteMember} · $nombre'
                    : l10n.inviteMember,
            isLoading: _sending,
            onPressed: nombre == 0 || _sending ? null : _send,
          ),
        ],
      ),
    );
  }
}

class _TuileCandidat extends StatelessWidget {
  const _TuileCandidat({
    required this.candidat,
    required this.deja,
    required this.selectionne,
    required this.onTap,
  });

  final InviteCandidate candidat;
  final bool deja;
  final bool selectionne;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sousTitre =
        deja
            ? l10n.inviteAlreadySent
            : (candidat.subtitle?.trim().isNotEmpty ?? false)
            ? candidat.subtitle!.trim()
            : candidat.isFriend
            ? l10n.friends
            : null;

    return Opacity(
      opacity: deja ? 0.55 : 1,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        onTap: deja ? null : onTap,
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: context.adaptivePrimaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child:
              candidat.photoUrl != null
                  ? CachedNetworkImage(
                    imageUrl: candidat.photoUrl!,
                    fit: BoxFit.cover,
                    placeholder:
                        (_, __) => Icon(
                          Icons.person,
                          color: context.adaptivePrimaryColor,
                        ),
                    errorWidget:
                        (_, __, ___) => Icon(
                          Icons.person,
                          color: context.adaptivePrimaryColor,
                        ),
                  )
                  : Icon(Icons.person, color: context.adaptivePrimaryColor),
        ),
        title: Text(
          candidat.displayName,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: context.textPrimaryColor,
          ),
        ),
        subtitle:
            sousTitre == null
                ? null
                : Text(
                  sousTitre,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: context.textTertiaryColor,
                  ),
                ),
        trailing:
            deja
                ? Icon(
                  Icons.schedule,
                  size: 20,
                  color: context.textTertiaryColor,
                )
                : Icon(
                  selectionne
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color:
                      selectionne
                          ? context.adaptivePrimaryColor
                          : context.textTertiaryColor,
                ),
      ),
    );
  }
}
