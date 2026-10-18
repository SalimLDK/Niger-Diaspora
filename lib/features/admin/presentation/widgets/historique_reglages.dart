import 'dart:async';

import 'package:diaspo_niger/core/theme/admin_colors.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/reglages_historique_datasource.dart';
import '../providers/app_settings_provider.dart';

/// Les entrées de l'historique, les plus récentes d'abord. Une lecture qui
/// échoue reste une erreur (jamais « aucun changement »).
final reglagesHistoriqueProvider =
    FutureProvider.autoDispose<List<EntreeHistoriqueReglage>>(
  (ref) => ReglagesHistoriqueSource().lire(),
);

/// Historique des réglages (référentiel § 13) : qui a changé quoi, de quelle
/// valeur à quelle valeur, quand — et le retour arrière d'une modification.
class HistoriqueReglagesDialog extends ConsumerWidget {
  const HistoriqueReglagesDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final entrees = ref.watch(reglagesHistoriqueProvider);

    return AlertDialog(
      title: Text(l10n.rgHistTitle),
      content: SizedBox(
        width: 640,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.rgHistSubtitle,
                style: const TextStyle(fontSize: 12, color: AdminColors.text3)),
            const SizedBox(height: 12),
            Flexible(
              child: entrees.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(l10n.rgHistLoadError('$e'),
                      style: const TextStyle(color: AdminColors.statusRed)),
                  TextButton(
                    onPressed: () => ref.invalidate(reglagesHistoriqueProvider),
                    child: Text(l10n.rgHistRetry),
                  ),
                ]),
                data: (liste) => liste.isEmpty
                    ? Text(l10n.rgHistEmpty,
                        style: const TextStyle(color: AdminColors.text3))
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: liste.length,
                        separatorBuilder: (_, __) => const Divider(height: 24),
                        itemBuilder: (_, i) => _Entree(entree: liste[i]),
                      ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: Text(l10n.rgHistClose)),
      ],
    );
  }
}

String _jour(DateTime? d) => d == null
    ? '—'
    : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

class _Entree extends ConsumerWidget {
  const _Entree({required this.entree});
  final EntreeHistoriqueReglage entree;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final e = entree;
    final differences = e.differences;
    String valeur(Object? v) => v == null ? l10n.rgHistAbsent : '$v';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(e.section, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(
              e.nature == 'restore' ? l10n.rgHistKindRestore : l10n.rgHistKindUpdate,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: e.nature == 'restore'
                    ? AdminColors.statusAmberStrong
                    : AdminColors.text3,
              ),
            ),
            Text(_jour(e.date),
                style: const TextStyle(fontSize: 12, color: AdminColors.text3)),
            Text(l10n.rgHistBy(e.par),
                style: const TextStyle(fontSize: 12, color: AdminColors.text3)),
          ],
        ),
        if (e.motif != null)
          Text(l10n.rgHistReason(e.motif!), style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 6),
        if (differences.isEmpty)
          Text(l10n.rgHistNoDiff,
              style: const TextStyle(fontSize: 12, color: AdminColors.text3))
        else
          for (final d in differences)
            SelectableText(
              l10n.rgHistChange(d.cle, valeur(d.avant), valeur(d.apres)),
              style: const TextStyle(fontSize: 13),
            ),
        const SizedBox(height: 6),
        if (e.restaurable)
          OutlinedButton.icon(
            onPressed: () => unawaited(_restaurer(context, ref)),
            icon: const Icon(Icons.undo_rounded, size: 16),
            label: Text(l10n.rgHistRestore),
          )
        else
          Text(l10n.rgHistNoBefore,
              style: const TextStyle(fontSize: 11, color: AdminColors.text3)),
      ],
    );
  }

  Future<void> _restaurer(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final controller = TextEditingController();
    final motif = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(l10n.rgHistRestoreTitle(entree.section)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.rgHistRestoreBody, style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                onChanged: (_) => setLocal(() {}),
                maxLength: 500,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: l10n.rgHistRestoreReason,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.rgHistRestoreCancel)),
            ElevatedButton(
              onPressed: controller.text.trim().length < 5
                  ? null
                  : () => Navigator.pop(ctx, controller.text.trim()),
              child: Text(l10n.rgHistRestoreConfirm),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (motif == null) return;

    String? echec;
    try {
      await ref.read(appSettingsNotifierProvider.notifier).restaurerSection(
            section: entree.section,
            valeur: entree.avant!,
            entreeId: entree.id,
            motif: motif,
            updatedBy: FirebaseAuth.instance.currentUser?.uid ?? '',
          );
    } catch (e) {
      echec = '$e';
    }
    ref.invalidate(reglagesHistoriqueProvider);
    messenger.showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: echec == null ? AdminColors.statusGreen : AdminColors.statusRed,
      content: Text(echec == null ? l10n.rgHistRestored : l10n.rgHistRestoreFailed(echec)),
    ));
  }
}
