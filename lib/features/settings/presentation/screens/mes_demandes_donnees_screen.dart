import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/supabase_auth_bridge.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../../../l10n/app_localizations.dart';

/// Les demandes de l'utilisateur sur ses données : en faire une (accès,
/// rectification, opposition) et suivre son état.
///
/// L'effacement et la portabilité n'y sont pas : « Supprimer mon compte » et
/// « Exporter mes données » font tout de suite ce qu'elles réclameraient, et
/// l'écran le dit. Le serveur refuse d'ailleurs ces deux natures.
///
/// L'utilisateur ne lit que l'ÉTAT de ses demandes (jamais les notes internes
/// ni l'agent) ; aucune promesse de délai n'est faite ici.
class MesDemandesDonneesScreen extends ConsumerStatefulWidget {
  const MesDemandesDonneesScreen({super.key});

  @override
  ConsumerState<MesDemandesDonneesScreen> createState() =>
      _MesDemandesDonneesScreenState();
}

class _Demande {
  const _Demande(this.id, this.nature, this.statut, this.creeeLe, this.reponse);
  final String id;
  final String nature;
  final String statut;
  final DateTime? creeeLe;

  /// La réponse de l'équipe, seulement une fois la demande traitée ou refusée.
  final String? reponse;

  bool get ouverte =>
      statut == 'received' || statut == 'identity_verified' || statut == 'in_progress';
}

final _mesDemandesProvider = FutureProvider.autoDispose<List<_Demande>>((ref) async {
  await SupabaseAuthBridge.instance.exigerSession();
  final rows = await Supabase.instance.client.rpc('privacy_request_mine') as List;
  return [
    for (final r in rows)
      _Demande(
        r['id'] as String,
        r['kind'] as String,
        r['status'] as String,
        DateTime.tryParse(r['created_at'] as String? ?? '')?.toLocal(),
        r['answer'] as String?,
      ),
  ];
});

class _MesDemandesDonneesScreenState extends ConsumerState<MesDemandesDonneesScreen> {
  bool _enCours = false;

  String _libelleNature(AppLocalizations l, String n) => switch (n) {
        'access' => l.mesDonneesKindAccess,
        'rectification' => l.mesDonneesKindRectification,
        _ => l.mesDonneesKindObjection,
      };

  String _libelleStatut(AppLocalizations l, String s) => switch (s) {
        'received' => l.mesDonneesStatusReceived,
        'identity_verified' => l.mesDonneesStatusIdentity,
        'in_progress' => l.mesDonneesStatusInProgress,
        'completed' => l.mesDonneesStatusCompleted,
        'refused' => l.mesDonneesStatusRefused,
        _ => l.mesDonneesStatusCancelled,
      };

  String _jour(DateTime? d) => d == null
      ? '—'
      : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  /// Annonce le résultat réel : un refus du serveur se lit, il ne se perd pas.
  Future<void> _lancer(Future<void> Function() geste, String succes) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _enCours = true);
    String? echec;
    try {
      await SupabaseAuthBridge.instance.exigerSession();
      await geste();
    } on PostgrestException catch (e) {
      echec = switch (e.code) {
        '55000' => l10n.mesDonneesAlreadyOpen,
        '22023' => e.message,
        _ => l10n.mesDonneesFailed,
      };
    } catch (_) {
      echec = l10n.mesDonneesFailed;
    }
    if (!mounted) return;
    setState(() => _enCours = false);
    ref.invalidate(_mesDemandesProvider);
    messenger.showSnackBar(SnackBar(content: Text(echec ?? succes)));
  }

  Future<void> _nouvelle(String nature) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final texte = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(_libelleNature(l10n, nature)),
          content: TextField(
            controller: controller,
            onChanged: (_) => setLocal(() {}),
            maxLines: 5,
            maxLength: 1000,
            decoration: InputDecoration(
              labelText: l10n.mesDonneesDetailsLabel,
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: Text(l10n.mesDonneesCancel)),
            ElevatedButton(
              onPressed: controller.text.trim().length < 10
                  ? null
                  : () => Navigator.pop(ctx, controller.text.trim()),
              child: Text(l10n.mesDonneesSend),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (texte == null || !mounted) return;
    await _lancer(
      () => Supabase.instance.client.rpc('privacy_request_submit',
          params: {'p_kind': nature, 'p_details': texte}),
      l10n.mesDonneesSent,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final demandes = ref.watch(_mesDemandesProvider);

    return Scaffold(
      appBar: AppBar(
        // Une sortie visible même si l'écran est atteint par un lien profond.
        leading: BackButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/settings'),
        ),
        title: Text(l10n.mesDonneesTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l10n.mesDonneesIntro),
          const SizedBox(height: 8),
          Text(l10n.mesDonneesNoTimeline,
              style: TextStyle(fontSize: 12, color: context.textTertiaryColor)),
          const SizedBox(height: 12),
          Text(l10n.mesDonneesOtherFlows,
              style: TextStyle(fontSize: 12, color: context.textTertiaryColor)),
          const SizedBox(height: 16),
          for (final n in const ['access', 'rectification', 'objection'])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton(
                onPressed: _enCours ? null : () => unawaited(_nouvelle(n)),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(_libelleNature(l10n, n)),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text(l10n.mesDonneesListTitle,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 8),
          demandes.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
            // Une erreur de lecture n'est pas « aucune demande ».
            error: (_, __) => Column(children: [
              Text(l10n.mesDonneesLoadError),
              TextButton(
                onPressed: () => ref.invalidate(_mesDemandesProvider),
                child: Text(l10n.mesDonneesRetry),
              ),
            ]),
            data: (liste) => liste.isEmpty
                ? Text(l10n.mesDonneesEmpty,
                    style: TextStyle(color: context.textTertiaryColor))
                : Column(
                    children: [
                      for (final d in liste)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(_libelleNature(l10n, d.nature)),
                          isThreeLine: d.reponse != null,
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  '${_libelleStatut(l10n, d.statut)} · ${l10n.mesDonneesDate(_jour(d.creeeLe))}'),
                              if (d.reponse != null) ...[
                                const SizedBox(height: 6),
                                Text(l10n.mesDonneesAnswerLabel,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600, fontSize: 12)),
                                SelectableText(d.reponse!),
                              ],
                            ],
                          ),
                          trailing: d.ouverte
                              ? TextButton(
                                  onPressed: _enCours
                                      ? null
                                      : () => unawaited(_lancer(
                                            () => Supabase.instance.client.rpc(
                                                'privacy_request_withdraw',
                                                params: {'p_id': d.id}),
                                            l10n.mesDonneesWithdrawn,
                                          )),
                                  child: Text(l10n.mesDonneesWithdraw),
                                )
                              : null,
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
