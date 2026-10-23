import 'dart:async';

import 'package:diaspo_niger/core/theme/admin_colors.dart';
import 'package:diaspo_niger/core/theme/design_kit.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/securite_admin_provider.dart';

/// Sécurité et conformité (spécification d'interfaces § 17) : les demandes
/// relatives aux données personnelles, et les incidents de sécurité.
///
/// Rubrique réservée au superAdmin : elle touche des données personnelles et
/// des preuves. Les droits réels sont relus en base ; le menu n'est qu'un
/// indice.
class AdminSecuriteScreen extends ConsumerWidget {
  const AdminSecuriteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final peut = ref.watch(permissionSecuriteProvider('privacy.requests.manage'));
    if (peut.valueOrNull == false) {
      return Center(child: Text(l10n.secAdmNoAccess));
    }
    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.secAdmTitle,
              style: const TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w700, color: AdminColors.text)),
          const SizedBox(height: 4),
          Text(l10n.secAdmSubtitle, style: const TextStyle(color: AdminColors.text3)),
          const SizedBox(height: 12),
          TabBar(
            labelColor: AdminColors.actionBlue,
            unselectedLabelColor: AdminColors.text3,
            tabs: [Tab(text: l10n.secAdmTabRequests), Tab(text: l10n.secAdmTabIncidents)],
          ),
          const SizedBox(height: 12),
          const Expanded(
            child: TabBarView(children: [_OngletDemandes(), _OngletIncidents()]),
          ),
        ],
      ),
    );
  }
}

// ═══ Aides communes ════════════════════════════════════════════════════════

String _jour(DateTime? d) => d == null
    ? '—'
    : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

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
    echec = switch (classerRefusSecurite(e)) {
      RefusSecurite.permission => l10n.modoErrDenied,
      RefusSecurite.conflit => l10n.modoErrConflict,
      RefusSecurite.saisie => l10n.modoErrInput(detailSecurite(e)),
      _ => l10n.modoErrGeneric(detailSecurite(e)),
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

/// Un ou plusieurs champs texte obligatoires dans un dialogue ; `null` si
/// annulé. [libelles] : un champ par entrée, tous requis (5 caractères au
/// moins, 10 pour [minLongs]).
Future<List<String>?> _saisir(
  BuildContext context, {
  required String titre,
  required List<String> libelles,
  String? aide,
  String? avertissement,
  Set<int> minLongs = const {},
}) {
  final controllers = [for (final _ in libelles) TextEditingController()];
  return showDialog<List<String>>(
    context: context,
    builder: (ctx) {
      final l10n = AppLocalizations.of(ctx)!;
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          bool valide() {
            for (var i = 0; i < controllers.length; i++) {
              final min = minLongs.contains(i) ? 10 : 5;
              if (controllers[i].text.trim().length < min) return false;
            }
            return true;
          }

          return AlertDialog(
            title: Text(titre),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (avertissement != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(avertissement,
                            style: const TextStyle(
                                fontSize: 12, color: AdminColors.statusAmberStrong)),
                      ),
                    if (aide != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(aide,
                            style: const TextStyle(fontSize: 12, color: AdminColors.text3)),
                      ),
                    for (var i = 0; i < libelles.length; i++) ...[
                      TextField(
                        controller: controllers[i],
                        onChanged: (_) => setLocal(() {}),
                        maxLines: 3,
                        maxLength: 2000,
                        decoration: InputDecoration(
                            labelText: libelles[i], border: const OutlineInputBorder()),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(l10n.secAdmCancelAction)),
              ElevatedButton(
                onPressed: valide()
                    ? () => Navigator.pop(ctx, [for (final c in controllers) c.text.trim()])
                    : null,
                child: Text(l10n.secAdmConfirm),
              ),
            ],
          );
        },
      );
    },
  ).whenComplete(() {
    for (final c in controllers) {
      c.dispose();
    }
  });
}

Widget _filtres<T>(
  Map<T, String> options,
  T courant,
  void Function(T) choisir,
) =>
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final e in options.entries)
          ChoiceChip(
            label: Text(e.value),
            selected: courant == e.key,
            selectedColor: AdminColors.actionBlueBg,
            onSelected: (_) => choisir(e.key),
          ),
      ],
    );

Widget _erreur(Object e, AppLocalizations l10n, VoidCallback reessayer) => Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(l10n.secAdmLoadError(detailSecurite(e)),
            style: const TextStyle(color: AdminColors.statusRed)),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: reessayer, child: Text(l10n.secAdmRetry)),
      ]),
    );

Widget _carte({required Widget titre, required Widget sousTitre, required List<Widget> corps}) =>
    Container(
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
        title: titre,
        subtitle: Padding(padding: const EdgeInsets.only(top: 6), child: sousTitre),
        children: corps,
      ),
    );

// ═══ Demandes de données ═══════════════════════════════════════════════════

class _OngletDemandes extends ConsumerWidget {
  const _OngletDemandes();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final vue = ref.watch(vueDemandesProvider);
    final demandes = ref.watch(demandesDonneesProvider);
    final vues = {
      VueSecurite.enCours: l10n.secAdmFilterOpen,
      VueSecurite.closes: l10n.secAdmFilterClosed,
      VueSecurite.toutes: l10n.secAdmFilterAll,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: _filtres(vues, vue,
                (v) => ref.read(vueDemandesProvider.notifier).state = v),
          ),
          IconButton(
            tooltip: l10n.secAdmRetry,
            onPressed: () => ref.invalidate(demandesDonneesProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
          ElevatedButton.icon(
            onPressed: () => _nouvelle(context, ref),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(l10n.secAdmReqNew),
          ),
        ]),
        const SizedBox(height: 8),
        Text(l10n.secAdmReqDueHelp,
            style: const TextStyle(fontSize: 12, color: AdminColors.text3)),
        const SizedBox(height: 12),
        Expanded(
          child: demandes.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                _erreur(e, l10n, () => ref.invalidate(demandesDonneesProvider)),
            data: (liste) => liste.isEmpty
                ? Center(
                    child: Text(l10n.secAdmEmpty,
                        style: const TextStyle(color: AdminColors.text3)))
                : ListView.separated(
                    itemCount: liste.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) =>
                        _CarteDemande(key: ValueKey(liste[i].id), demande: liste[i]),
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> _nouvelle(BuildContext context, WidgetRef ref) async {
    final res = await showDialog<_NouvelleDemande>(
      context: context,
      builder: (_) => const _DialogueDemande(),
    );
    if (res == null || !context.mounted) return;
    await _lancer(
      context,
      ref,
      () => ref.read(securiteAdminActionsProvider).creerDemande(
            nature: res.nature,
            compte: res.compte,
            contact: res.contact,
            perimetre: res.perimetre,
            echeance: DateTime.now().add(Duration(days: res.jours)),
          ),
      AppLocalizations.of(context)!.secAdmReqCreated,
      [demandesDonneesProvider],
    );
  }
}

String _libelleNature(AppLocalizations l, String n) => switch (n) {
      'access' => l.secAdmReqKindAccess,
      'rectification' => l.secAdmReqKindRectification,
      'erasure' => l.secAdmReqKindErasure,
      'portability' => l.secAdmReqKindPortability,
      _ => l.secAdmReqKindObjection,
    };

String _libelleStatutDemande(AppLocalizations l, String s) => switch (s) {
      'received' => l.secAdmReqStatusReceived,
      'identity_verified' => l.secAdmReqStatusIdentity,
      'in_progress' => l.secAdmReqStatusInProgress,
      'completed' => l.secAdmReqStatusCompleted,
      'refused' => l.secAdmReqStatusRefused,
      _ => l.secAdmReqStatusCancelled,
    };

class _CarteDemande extends ConsumerWidget {
  const _CarteDemande({super.key, required this.demande});
  final DemandeDonnees demande;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final d = demande;
    final acts = ref.read(securiteAdminActionsProvider);
    final relecture = [demandesDonneesProvider];

    return _carte(
      titre: Text(_libelleNature(l10n, d.nature),
          style: const TextStyle(fontWeight: FontWeight.w600)),
      sousTitre: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          DesignBadge(
            _libelleStatutDemande(l10n, d.statut),
            tone: switch (d.statut) {
              'completed' => DesignBadgeTone.verified,
              'refused' => DesignBadgeTone.failed,
              'cancelled' => DesignBadgeTone.archived,
              _ => DesignBadgeTone.review,
            },
          ),
          if (d.enRetard) DesignBadge(l10n.secAdmReqOverdue, tone: DesignBadgeTone.failed),
          if (d.depuisApp)
            Text(l10n.secAdmReqFromApp,
                style: const TextStyle(fontSize: 12, color: AdminColors.text3)),
          if (d.ouverte && d.nonAttribuee)
            DesignBadge(l10n.secAdmReqUnassigned, tone: DesignBadgeTone.review),
          Text(l10n.secAdmReqDueInternal(_jour(d.echeance)),
              style: const TextStyle(fontSize: 12, color: AdminColors.text3)),
        ],
      ),
      corps: [
        // Les données du demandeur ne s'affichent qu'ici, dépliées.
        Text(l10n.secAdmReqRequester(d.compte ?? d.contact ?? '—'),
            style: const TextStyle(fontSize: 13)),
        if (d.perimetre != null)
          Text(l10n.secAdmReqScope(d.perimetre!), style: const TextStyle(fontSize: 13)),
        if (d.methodeIdentite != null)
          Text(l10n.secAdmReqIdentity(d.methodeIdentite!),
              style: const TextStyle(fontSize: 13)),
        if (d.resultat != null)
          Text(l10n.secAdmReqResult(d.resultat!), style: const TextStyle(fontSize: 13)),
        if (d.nature == 'erasure' && d.compte != null) _EtatSuppression(id: d.id),
        if (d.statut == 'received' && !d.nonAttribuee)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(l10n.secAdmReqNeedsIdentity,
                style: const TextStyle(fontSize: 12, color: AdminColors.text3)),
          ),
        const SizedBox(height: 12),
        // Tant que personne ne l'a prise, une demande de l'application n'offre
        // que cela : le serveur refuse d'en faire davantage.
        if (d.ouverte && d.nonAttribuee)
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              onPressed: () => unawaited(_lancer(context, ref, () => acts.prendreDemande(d.id),
                  l10n.secAdmDone, relecture)),
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
              label: Text(l10n.secAdmReqTake),
            ),
          )
        else if (d.ouverte)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (d.statut == 'received')
                ElevatedButton.icon(
                  onPressed: () async {
                    final v = await _saisir(context,
                        titre: l10n.secAdmReqVerify,
                        libelles: [l10n.secAdmReqVerifyMethod]);
                    if (v == null || !context.mounted) return;
                    await _lancer(context, ref, () => acts.verifierIdentite(d.id, v[0]),
                        l10n.secAdmDone, relecture);
                  },
                  icon: const Icon(Icons.verified_user_outlined, size: 16),
                  label: Text(l10n.secAdmReqVerify),
                ),
              if (d.compte != null &&
                  (d.statut == 'identity_verified' || d.statut == 'in_progress'))
                OutlinedButton.icon(
                  onPressed: () => unawaited(showDialog<void>(
                    context: context,
                    builder: (_) => _EtatDesLieux(id: d.id),
                  )),
                  icon: const Icon(Icons.fact_check_outlined, size: 16),
                  label: Text(l10n.secAdmReqSummary),
                ),
              if (d.statut == 'identity_verified')
                ElevatedButton.icon(
                  onPressed: () => unawaited(_lancer(
                      context,
                      ref,
                      () => acts.transitionnerDemande(d.id, 'in_progress'),
                      l10n.secAdmDone,
                      relecture)),
                  icon: const Icon(Icons.play_arrow_rounded, size: 16),
                  label: Text(l10n.secAdmReqStart),
                ),
              if (d.statut == 'in_progress')
                ElevatedButton.icon(
                  onPressed: () async {
                    final v = await _saisir(context,
                        titre: l10n.secAdmReqComplete,
                        libelles: [
                          l10n.secAdmReqInternalCompleteNote,
                          if (d.compte != null) l10n.secAdmReqAnswerLabel,
                        ],
                        aide: d.compte != null ? l10n.secAdmReqAnswerHelp : null,
                        avertissement: l10n.secAdmReqCompleteWarn,
                        minLongs: d.compte != null ? {1} : const {});
                    if (v == null || !context.mounted) return;
                    await _lancer(
                        context,
                        ref,
                        () => acts.transitionnerDemande(d.id, 'completed',
                            note: v[0], reponse: v.length > 1 ? v[1] : null),
                        l10n.secAdmDone,
                        relecture);
                  },
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: Text(l10n.secAdmReqComplete),
                ),
              OutlinedButton.icon(
                onPressed: () async {
                  final v = await _saisir(context,
                      titre: l10n.secAdmReqRefuse,
                      libelles: [
                        l10n.secAdmReqInternalRefuseNote,
                        if (d.compte != null) l10n.secAdmReqAnswerLabel,
                      ],
                      aide: d.compte != null ? l10n.secAdmReqAnswerHelp : null,
                      minLongs: d.compte != null ? {1} : const {});
                  if (v == null || !context.mounted) return;
                  await _lancer(
                      context,
                      ref,
                      () => acts.transitionnerDemande(d.id, 'refused',
                          note: v[0], reponse: v.length > 1 ? v[1] : null),
                      l10n.secAdmDone,
                      relecture);
                },
                icon: const Icon(Icons.close_rounded, size: 16),
                label: Text(l10n.secAdmReqRefuse),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final v = await _saisir(context,
                      titre: l10n.secAdmReqCancel, libelles: [l10n.secAdmReqCancelNote]);
                  if (v == null || !context.mounted) return;
                  await _lancer(
                      context,
                      ref,
                      () => acts.transitionnerDemande(d.id, 'cancelled', note: v[0]),
                      l10n.secAdmDone,
                      relecture);
                },
                icon: const Icon(Icons.block_rounded, size: 16),
                label: Text(l10n.secAdmReqCancel),
              ),
            ],
          ),
      ],
    );
  }
}

class _EtatSuppression extends ConsumerWidget {
  const _EtatSuppression({required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final e = ref.watch(etatSuppressionProvider(id));
    return e.when(
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (err, _) => Text(l10n.secAdmLoadError(detailSecurite(err)),
          style: const TextStyle(color: AdminColors.statusRed, fontSize: 12)),
      data: (v) => v.lie
          ? Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.secAdmReqErasureState(
                      v.comptePresent == false
                          ? l10n.secAdmReqAccountGone
                          : l10n.secAdmReqAccountPresent,
                      v.statut ?? l10n.secAdmReqDeletionNone,
                    ),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  Text(l10n.secAdmReqErasureHelp,
                      style: const TextStyle(fontSize: 11, color: AdminColors.text3)),
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

/// Les nombres d'un compte, après vérification d'identité. Aucun contenu.
class _EtatDesLieux extends ConsumerWidget {
  const _EtatDesLieux({required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final s = ref.watch(etatDesLieuxProvider(id));
    final libelles = {
      'messages_sent': l10n.secAdmSumMessages,
      'posts': l10n.secAdmSumPosts,
      'post_comments': l10n.secAdmSumComments,
      'stories': l10n.secAdmSumStories,
      'friends': l10n.secAdmSumFriends,
      'groups': l10n.secAdmSumGroups,
      'notifications': l10n.secAdmSumNotifications,
      'events_organized': l10n.secAdmSumEvents,
      'businesses': l10n.secAdmSumBusinesses,
      'support_tickets': l10n.secAdmSumTickets,
      'reports_filed': l10n.secAdmSumReports,
      'blocked_users': l10n.secAdmSumBlocked,
      'devices': l10n.secAdmSumDevices,
    };
    return AlertDialog(
      title: Text(l10n.secAdmReqSummary),
      content: SizedBox(
        width: 420,
        child: s.when(
          loading: () => const LinearProgressIndicator(minHeight: 2),
          error: (e, _) => Text(l10n.secAdmLoadError(detailSecurite(e)),
              style: const TextStyle(color: AdminColors.statusRed)),
          data: (m) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.secAdmReqSummaryHelp,
                  style: const TextStyle(fontSize: 12, color: AdminColors.text3)),
              const SizedBox(height: 8),
              for (final e in libelles.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(children: [
                    Expanded(child: Text(e.value)),
                    Text('${m[e.key] ?? '—'}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ]),
                ),
              if (m['note'] != null) ...[
                const SizedBox(height: 8),
                Text('${m['note']}',
                    style: const TextStyle(fontSize: 11, color: AdminColors.text3)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: Text(l10n.secAdmConfirm)),
      ],
    );
  }
}

class _NouvelleDemande {
  const _NouvelleDemande(this.nature, this.compte, this.contact, this.perimetre, this.jours);
  final String nature;
  final String? compte;
  final String? contact;
  final String? perimetre;
  final int jours;
}

class _DialogueDemande extends StatefulWidget {
  const _DialogueDemande();

  @override
  State<_DialogueDemande> createState() => _DialogueDemandeState();
}

class _DialogueDemandeState extends State<_DialogueDemande> {
  final _compte = TextEditingController();
  final _contact = TextEditingController();
  final _perimetre = TextEditingController();
  String _nature = 'access';
  int _jours = 30;

  @override
  void dispose() {
    _compte.dispose();
    _contact.dispose();
    _perimetre.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final natures = {
      'access': l10n.secAdmReqKindAccess,
      'rectification': l10n.secAdmReqKindRectification,
      'erasure': l10n.secAdmReqKindErasure,
      'portability': l10n.secAdmReqKindPortability,
      'objection': l10n.secAdmReqKindObjection,
    };
    final valide = _compte.text.trim().isNotEmpty || _contact.text.trim().isNotEmpty;
    return AlertDialog(
      title: Text(l10n.secAdmReqNew),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _nature,
                isExpanded: true,
                decoration: InputDecoration(
                    labelText: l10n.secAdmReqFieldKind, border: const OutlineInputBorder()),
                items: [
                  for (final e in natures.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: (v) => setState(() => _nature = v ?? _nature),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _compte,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                    labelText: l10n.secAdmReqFieldAccount, border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _contact,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                    labelText: l10n.secAdmReqFieldContact, border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _perimetre,
                maxLines: 2,
                decoration: InputDecoration(
                    labelText: l10n.secAdmReqFieldScope, border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _jours,
                decoration: InputDecoration(
                    labelText: l10n.secAdmReqFieldDue, border: const OutlineInputBorder()),
                items: [
                  for (final j in const [7, 15, 30, 60, 90])
                    DropdownMenuItem(value: j, child: Text(l10n.secAdmReqDays('$j'))),
                ],
                onChanged: (v) => setState(() => _jours = v ?? _jours),
              ),
              const SizedBox(height: 8),
              Text(l10n.secAdmReqDueHelp,
                  style: const TextStyle(fontSize: 11, color: AdminColors.text3)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: Text(l10n.secAdmCancelAction)),
        ElevatedButton(
          onPressed: valide
              ? () => Navigator.pop(
                    context,
                    _NouvelleDemande(
                      _nature,
                      _compte.text.trim().isEmpty ? null : _compte.text.trim(),
                      _contact.text.trim().isEmpty ? null : _contact.text.trim(),
                      _perimetre.text.trim().isEmpty ? null : _perimetre.text.trim(),
                      _jours,
                    ),
                  )
              : null,
          child: Text(l10n.secAdmSave),
        ),
      ],
    );
  }
}

// ═══ Incidents ═════════════════════════════════════════════════════════════

String _libelleGravite(AppLocalizations l, String s) => switch (s) {
      'low' => l.secAdmIncSevLow,
      'medium' => l.secAdmIncSevMedium,
      'high' => l.secAdmIncSevHigh,
      _ => l.secAdmIncSevCritical,
    };

String _libelleStatutIncident(AppLocalizations l, String s) => switch (s) {
      'open' => l.secAdmIncStatusOpen,
      'contained' => l.secAdmIncStatusContained,
      'resolved' => l.secAdmIncStatusResolved,
      _ => l.secAdmIncStatusClosed,
    };

class _OngletIncidents extends ConsumerWidget {
  const _OngletIncidents();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final vue = ref.watch(vueIncidentsProvider);
    final incidents = ref.watch(incidentsProvider);
    final vues = {
      VueSecurite.enCours: l10n.secAdmFilterOpen,
      VueSecurite.closes: l10n.secAdmFilterClosed,
      VueSecurite.toutes: l10n.secAdmFilterAll,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: _filtres(vues, vue,
                (v) => ref.read(vueIncidentsProvider.notifier).state = v),
          ),
          IconButton(
            tooltip: l10n.secAdmRetry,
            onPressed: () => ref.invalidate(incidentsProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
          ElevatedButton.icon(
            onPressed: () => _ouvrir(context, ref),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(l10n.secAdmIncNew),
          ),
        ]),
        const SizedBox(height: 12),
        Expanded(
          child: incidents.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _erreur(e, l10n, () => ref.invalidate(incidentsProvider)),
            data: (liste) => liste.isEmpty
                ? Center(
                    child: Text(l10n.secAdmEmpty,
                        style: const TextStyle(color: AdminColors.text3)))
                : ListView.separated(
                    itemCount: liste.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) =>
                        _CarteIncident(key: ValueKey(liste[i].id), incident: liste[i]),
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> _ouvrir(BuildContext context, WidgetRef ref) async {
    final res = await showDialog<_NouvelIncident>(
      context: context,
      builder: (_) => const _DialogueIncident(),
    );
    if (res == null || !context.mounted) return;
    await _lancer(
      context,
      ref,
      () => ref.read(securiteAdminActionsProvider).ouvrirIncident(
            titre: res.titre,
            gravite: res.gravite,
            resume: res.resume,
            impact: res.impact,
          ),
      AppLocalizations.of(context)!.secAdmIncOpened,
      [incidentsProvider],
    );
  }
}

class _CarteIncident extends ConsumerStatefulWidget {
  const _CarteIncident({super.key, required this.incident});
  final IncidentSecurite incident;

  @override
  ConsumerState<_CarteIncident> createState() => _CarteIncidentState();
}

class _CarteIncidentState extends ConsumerState<_CarteIncident> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final i = widget.incident;
    final acts = ref.read(securiteAdminActionsProvider);
    final chrono = ref.watch(chronologieIncidentProvider(i.id));
    final relecture = <ProviderOrFamily>[incidentsProvider, chronologieIncidentProvider(i.id)];

    return _carte(
      titre: Text(i.titre,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      sousTitre: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          DesignBadge(
            _libelleGravite(l10n, i.gravite),
            tone: (i.gravite == 'high' || i.gravite == 'critical')
                ? DesignBadgeTone.failed
                : DesignBadgeTone.review,
          ),
          DesignBadge(
            _libelleStatutIncident(l10n, i.statut),
            tone: i.clos ? DesignBadgeTone.archived : DesignBadgeTone.review,
          ),
          Text(l10n.secAdmIncDetected(_jour(i.detecteLe)),
              style: const TextStyle(fontSize: 12, color: AdminColors.text3)),
        ],
      ),
      corps: [
        SelectableText(i.resume, style: const TextStyle(fontSize: 13)),
        if (i.impact != null) ...[
          const SizedBox(height: 6),
          Text(l10n.secAdmIncImpact(i.impact!), style: const TextStyle(fontSize: 13)),
        ],
        if (i.clos) ...[
          const SizedBox(height: 8),
          _bloc(l10n.secAdmIncCloseCause, i.cause),
          _bloc(l10n.secAdmIncCloseActions, i.mesures),
          _bloc(l10n.secAdmIncCloseLessons, i.enseignements),
        ],
        const SizedBox(height: 12),
        Text(l10n.secAdmIncTimeline,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        Text(l10n.secAdmIncTimelineHint,
            style: const TextStyle(fontSize: 11, color: AdminColors.text3)),
        const SizedBox(height: 6),
        chrono.when(
          loading: () => const LinearProgressIndicator(minHeight: 2),
          error: (e, _) => Text(l10n.secAdmLoadError(detailSecurite(e)),
              style: const TextStyle(color: AdminColors.statusRed, fontSize: 12)),
          data: (liste) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final e in liste)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_jour(e.date),
                          style: const TextStyle(fontSize: 11, color: AdminColors.text3)),
                      SelectableText(e.texte, style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (!i.clos) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _note,
            maxLines: 2,
            maxLength: 4000,
            decoration: InputDecoration(
                labelText: l10n.secAdmIncNoteLabel, border: const OutlineInputBorder()),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(
              onPressed: () async {
                final t = _note.text.trim();
                if (t.isEmpty) return;
                final ok = await _lancer(context, ref, () => acts.noter(i.id, t),
                    l10n.secAdmDone, relecture);
                if (ok) _note.clear();
              },
              child: Text(l10n.secAdmIncAddNote),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (i.statut == 'open')
                ElevatedButton(
                  onPressed: () => _passer(context, 'contained', l10n.secAdmIncContain, relecture),
                  child: Text(l10n.secAdmIncContain),
                ),
              if (i.statut == 'open' || i.statut == 'contained')
                ElevatedButton(
                  onPressed: () => _passer(context, 'resolved', l10n.secAdmIncResolve, relecture),
                  child: Text(l10n.secAdmIncResolve),
                ),
              if (i.statut == 'resolved')
                ElevatedButton(
                  onPressed: () => _clore(context, relecture),
                  child: Text(l10n.secAdmIncClose),
                ),
              OutlinedButton(
                onPressed: () => _gravite(context, relecture),
                child: Text(l10n.secAdmIncSetSeverity),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _bloc(String titre, String? texte) => texte == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text.rich(TextSpan(children: [
            TextSpan(text: '$titre : ', style: const TextStyle(fontWeight: FontWeight.w600)),
            TextSpan(text: texte),
          ], style: const TextStyle(fontSize: 13))),
        );

  Future<void> _passer(BuildContext context, String vers, String titre,
      List<ProviderOrFamily> relecture) async {
    final l10n = AppLocalizations.of(context)!;
    final v = await _saisir(context, titre: titre, libelles: [l10n.secAdmIncTransitionNote]);
    if (v == null || !context.mounted) return;
    await _lancer(
        context,
        ref,
        () => ref
            .read(securiteAdminActionsProvider)
            .transitionnerIncident(widget.incident.id, vers, v[0]),
        l10n.secAdmDone,
        relecture);
  }

  Future<void> _clore(BuildContext context, List<ProviderOrFamily> relecture) async {
    final l10n = AppLocalizations.of(context)!;
    final v = await _saisir(
      context,
      titre: l10n.secAdmIncClose,
      aide: l10n.secAdmIncCloseHelp,
      libelles: [
        l10n.secAdmIncTransitionNote,
        l10n.secAdmIncCloseCause,
        l10n.secAdmIncCloseActions,
        l10n.secAdmIncCloseLessons,
      ],
      minLongs: {1, 2, 3},
    );
    if (v == null || !context.mounted) return;
    await _lancer(
        context,
        ref,
        () => ref.read(securiteAdminActionsProvider).transitionnerIncident(
              widget.incident.id,
              'closed',
              v[0],
              cause: v[1],
              mesures: v[2],
              enseignements: v[3],
            ),
        l10n.secAdmDone,
        relecture);
  }

  Future<void> _gravite(BuildContext context, List<ProviderOrFamily> relecture) async {
    final l10n = AppLocalizations.of(context)!;
    final choix = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.secAdmIncSetSeverity),
        children: [
          for (final g in const ['low', 'medium', 'high', 'critical'])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, g),
              child: Text(_libelleGravite(l10n, g)),
            ),
        ],
      ),
    );
    if (choix == null || !context.mounted) return;
    final v = await _saisir(context,
        titre: l10n.secAdmIncSetSeverity, libelles: [l10n.secAdmIncSeverityReason]);
    if (v == null || !context.mounted) return;
    await _lancer(
        context,
        ref,
        () => ref
            .read(securiteAdminActionsProvider)
            .changerGravite(widget.incident.id, choix, v[0]),
        l10n.secAdmDone,
        relecture);
  }
}

class _NouvelIncident {
  const _NouvelIncident(this.titre, this.gravite, this.resume, this.impact);
  final String titre;
  final String gravite;
  final String resume;
  final String? impact;
}

class _DialogueIncident extends StatefulWidget {
  const _DialogueIncident();

  @override
  State<_DialogueIncident> createState() => _DialogueIncidentState();
}

class _DialogueIncidentState extends State<_DialogueIncident> {
  final _titre = TextEditingController();
  final _resume = TextEditingController();
  final _impact = TextEditingController();
  String _gravite = 'medium';

  @override
  void dispose() {
    _titre.dispose();
    _resume.dispose();
    _impact.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final valide = _titre.text.trim().length >= 5 && _resume.text.trim().length >= 10;
    return AlertDialog(
      title: Text(l10n.secAdmIncNew),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titre,
                onChanged: (_) => setState(() {}),
                maxLength: 120,
                decoration: InputDecoration(
                    labelText: l10n.secAdmIncFieldTitle, border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _gravite,
                decoration: InputDecoration(
                    labelText: l10n.secAdmIncFieldSeverity,
                    border: const OutlineInputBorder()),
                items: [
                  for (final g in const ['low', 'medium', 'high', 'critical'])
                    DropdownMenuItem(value: g, child: Text(_libelleGravite(l10n, g))),
                ],
                onChanged: (v) => setState(() => _gravite = v ?? _gravite),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _resume,
                onChanged: (_) => setState(() {}),
                maxLines: 4,
                maxLength: 2000,
                decoration: InputDecoration(
                    labelText: l10n.secAdmIncFieldSummary,
                    border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _impact,
                maxLines: 2,
                maxLength: 1000,
                decoration: InputDecoration(
                    labelText: l10n.secAdmIncFieldImpact,
                    border: const OutlineInputBorder()),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: Text(l10n.secAdmCancelAction)),
        ElevatedButton(
          onPressed: valide
              ? () => Navigator.pop(
                    context,
                    _NouvelIncident(
                      _titre.text.trim(),
                      _gravite,
                      _resume.text.trim(),
                      _impact.text.trim().isEmpty ? null : _impact.text.trim(),
                    ),
                  )
              : null,
          child: Text(l10n.secAdmSave),
        ),
      ],
    );
  }
}
