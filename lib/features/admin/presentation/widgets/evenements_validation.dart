import 'dart:async';

import 'package:diaspo_niger/core/theme/admin_colors.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/evenements_admin_provider.dart';

/// L'onglet « À valider » des événements : la file, et le réglage qui l'active.
///
/// Le réglage naît désactivé. Le serveur décide de tout (droits, séparation
/// organisateur / approbateur, états) ; ses refus s'affichent en clair.
class OngletValidationEvenements extends ConsumerWidget {
  const OngletValidationEvenements({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final peutApprouver = ref.watch(permissionEvenementsProvider('events.approve'));
    final peutRegler = ref.watch(permissionEvenementsProvider('events.approval.configure'));
    final exigee = ref.watch(validationExigeeProvider);
    final file = ref.watch(evenementsEnAttenteProvider);

    return ListView(
      children: [
        if (peutRegler.valueOrNull == true) ...[
          exigee.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text(l10n.evtValLoadError(detailEvenements(e)),
                style: const TextStyle(color: AdminColors.statusRed)),
            data: (on) => Card(
              child: SwitchListTile(
                title: Text(l10n.evtValSetting),
                subtitle: Text(on ? l10n.evtValSettingOn : l10n.evtValSettingOff),
                value: on,
                onChanged: (v) => unawaited(_regler(context, ref, v)),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (peutApprouver.valueOrNull == false)
          Text(l10n.evtValNoAccess, style: const TextStyle(color: AdminColors.text3))
        else
          file.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Column(children: [
              Text(l10n.evtValLoadError(detailEvenements(e)),
                  style: const TextStyle(color: AdminColors.statusRed)),
              OutlinedButton(
                  onPressed: () => ref.invalidate(evenementsEnAttenteProvider),
                  child: Text(l10n.evtCalRetry)),
            ]),
            data: (liste) => liste.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(l10n.evtValEmpty, style: const TextStyle(color: AdminColors.text3)),
                  )
                : Column(children: [for (final e in liste) _Carte(evenement: e)]),
          ),
      ],
    );
  }

  Future<void> _regler(BuildContext context, WidgetRef ref, bool v) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(v ? l10n.evtValEnableTitle : l10n.evtValDisableTitle),
        content: Text(v ? l10n.evtValEnableBody : l10n.evtValDisableBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.adminCancelAction)),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.evtValConfirm)),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await _executer(context, ref, () => ref.read(validationEvenementsActionsProvider).regler(v));
  }
}

/// Un geste, son bilan : on dit l'échec comme le succès, et on relit.
Future<bool> _executer(
    BuildContext context, WidgetRef ref, Future<void> Function() geste) async {
  final l10n = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  String? echec;
  try {
    await geste();
  } catch (e) {
    final code = e is PostgrestException ? e.code : null;
    echec = switch (code) {
      '42501' => l10n.modoErrDenied,
      '55000' => l10n.modoErrConflict,
      '22023' => l10n.modoErrInput(detailEvenements(e)),
      _ => l10n.modoErrGeneric(detailEvenements(e)),
    };
  }
  ref.invalidate(evenementsEnAttenteProvider);
  ref.invalidate(validationExigeeProvider);
  messenger.showSnackBar(SnackBar(
    behavior: SnackBarBehavior.floating,
    backgroundColor: echec == null ? AdminColors.statusGreen : AdminColors.statusRed,
    content: Text(echec ?? l10n.evtCalDone),
  ));
  return echec == null;
}

class _Carte extends ConsumerWidget {
  const _Carte({required this.evenement});
  final EvenementEnAttente evenement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final e = evenement;
    final quand = e.debut == null
        ? ''
        : '${e.debut!.day.toString().padLeft(2, '0')}/${e.debut!.month.toString().padLeft(2, '0')}/${e.debut!.year}';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(e.titre.isEmpty ? '—' : e.titre, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
            [quand, e.ville, e.organisateur].where((x) => x != null && x.isNotEmpty).join(' · ')),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          TextButton(
            onPressed: () => unawaited(_refuser(context, ref)),
            child: Text(l10n.evtValReject),
          ),
          const SizedBox(width: 4),
          ElevatedButton(
            onPressed: () => unawaited(
                _executer(context, ref, () => ref.read(validationEvenementsActionsProvider).approuver(e.id))),
            child: Text(l10n.evtValApprove),
          ),
        ]),
      ),
    );
  }

  Future<void> _refuser(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final motif = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(l10n.evtValReject),
          content: TextField(
            controller: controller,
            maxLines: 3,
            maxLength: 1000,
            onChanged: (_) => setLocal(() {}),
            decoration: InputDecoration(
                labelText: l10n.evtValRejectReason, border: const OutlineInputBorder()),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: Text(l10n.adminCancelAction)),
            ElevatedButton(
              onPressed: controller.text.trim().length < 5
                  ? null
                  : () => Navigator.pop(ctx, controller.text.trim()),
              child: Text(l10n.evtValReject),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (motif == null || !context.mounted) return;
    await _executer(context, ref,
        () => ref.read(validationEvenementsActionsProvider).refuser(evenement.id, motif));
  }
}
