import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/error_handler.dart';
import '../../../../core/providers/uid_firebase_provider.dart';
import '../../../../core/services/e2ee/historique_backup_service.dart';
import '../../../../core/services/e2ee/key_backup_service.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../../../core/theme/design_kit.dart';
import '../../../../l10n/app_localizations.dart';

/// Sauvegarde et restauration manuelles du texte des discussions chiffrées.
///
/// Réservé aux comptes passés à MLS : leurs clés ne quittent pas le téléphone
/// (`mls_chemin_base.dart`), donc ce que le cache local a gardé en clair est
/// tout ce qui peut survivre à une réinstallation. Voir
/// [HistoriqueBackupService] pour ce qui est emporté et ce qui ne l'est pas.
class HistoriqueBackupSection extends ConsumerStatefulWidget {
  const HistoriqueBackupSection({super.key});

  @override
  ConsumerState<HistoriqueBackupSection> createState() =>
      _HistoriqueBackupSectionState();
}

class _HistoriqueBackupSectionState
    extends ConsumerState<HistoriqueBackupSection> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  /// `null` après lecture = aucune sauvegarde sur Storage.
  InfosHistorique? _infos;
  bool _infosLues = false;
  bool _occupe = false;

  @override
  void initState() {
    super.initState();
    unawaited(_lireInfos());
  }

  Future<void> _lireInfos() async {
    final uid = ref.read(uidFirebaseProvider);
    if (uid == null) return;
    final infos = await ref.read(historiqueBackupServiceProvider).infos(uid);
    if (!mounted) return;
    setState(() {
      _infos = infos;
      _infosLues = true;
    });
  }

  void _message(String texte, {bool erreur = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(texte),
        backgroundColor: erreur ? context.errorColor : context.successColor,
      ),
    );
  }

  String _echec(Object e) => ErrorHandler.instance.getShortMessage(
    ErrorHandler.instance.handleException(e),
  );

  Future<String?> _demanderPassphrase({
    required String texte,
    required bool confirmer,
  }) => showDialog<String>(
    context: context,
    builder: (_) => _DialoguePassphrase(texte: texte, confirmer: confirmer),
  );

  Future<void> _sauvegarder() async {
    final uid = ref.read(uidFirebaseProvider);
    if (uid == null || _occupe) return;
    final passphrase = await _demanderPassphrase(
      texte: l10n.historyBackupDialogHint,
      confirmer: true,
    );
    if (passphrase == null) return;

    setState(() => _occupe = true);
    try {
      final r = await ref
          .read(historiqueBackupServiceProvider)
          .sauvegarder(uid, passphrase);
      final fait = l10n.historyBackupDone(r.messages);
      _message(r.tronque ? '$fait\n${l10n.historyBackupTruncated}' : fait);
      await _lireInfos();
    } on RienASauvegarderException {
      _message(l10n.historyBackupNothing, erreur: true);
    } catch (e) {
      _message(_echec(e), erreur: true);
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  Future<void> _restaurer() async {
    final uid = ref.read(uidFirebaseProvider);
    if (uid == null || _occupe) return;
    final passphrase = await _demanderPassphrase(
      texte: l10n.historyRestoreHint,
      confirmer: false,
    );
    if (passphrase == null) return;

    setState(() => _occupe = true);
    try {
      final ajoutes = await ref
          .read(historiqueBackupServiceProvider)
          .restaurer(uid, passphrase);
      _message(
        ajoutes == 0
            ? l10n.historyRestoreNothingNew
            : l10n.historyRestoreDone(ajoutes),
      );
    } on PassphraseException {
      _message(l10n.invalidPassphrase, erreur: true);
    } on BackupNotFoundException {
      _message(l10n.noBackupFound, erreur: true);
    } catch (e) {
      _message(_echec(e), erreur: true);
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  Future<void> _supprimer() async {
    final uid = ref.read(uidFirebaseProvider);
    if (uid == null || _occupe) return;
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(l10n.historyDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: ctx.errorColor),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirme != true) return;

    setState(() => _occupe = true);
    try {
      await ref.read(historiqueBackupServiceProvider).supprimer(uid);
      _message(l10n.historyDeleteDone);
      await _lireInfos();
    } catch (e) {
      _message(_echec(e), erreur: true);
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  String _dateCourte(DateTime d) =>
      '${d.day}/${d.month}/${d.year} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final infos = _infos;
    final creeLe = infos?.creeLe;
    final dernier = creeLe == null
        ? l10n.historyBackupNone
        : l10n.historyBackupLast(_dateCourte(creeLe), infos?.messages ?? 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DesignSectionLabel(l10n.historyBackupSection),
        DesignBody(l10n.historyBackupBody),
        const SizedBox(height: 12),
        if (_occupe)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          DesignSettingsCard(
            children: [
              DesignSettingsTile(
                icon: const Icon(Icons.cloud_upload_outlined),
                title: l10n.historyBackupAction,
                subtitle: _infosLues ? dernier : null,
                onTap: _sauvegarder,
              ),
              DesignSettingsTile(
                icon: const Icon(Icons.cloud_download_outlined),
                title: l10n.historyRestoreAction,
                onTap: _restaurer,
              ),
              if (infos != null)
                DesignSettingsTile(
                  icon: const Icon(Icons.delete_outline),
                  title: l10n.delete,
                  iconColor: context.errorColor,
                  titleColor: context.errorColor,
                  onTap: _supprimer,
                ),
            ],
          ),
      ],
    );
  }
}

/// Saisie de passphrase. Les contrôleurs vivent dans l'état du dialogue : les
/// libérer depuis l'appelant, pendant l'animation de fermeture, les ferait
/// utiliser après `dispose`.
class _DialoguePassphrase extends StatefulWidget {
  final String texte;
  final bool confirmer;

  const _DialoguePassphrase({required this.texte, required this.confirmer});

  @override
  State<_DialoguePassphrase> createState() => _DialoguePassphraseState();
}

class _DialoguePassphraseState extends State<_DialoguePassphrase> {
  final _saisie = TextEditingController();
  final _confirmation = TextEditingController();
  bool _visible = false;
  String? _erreur;

  @override
  void dispose() {
    _saisie.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  void _valider() {
    final l10n = AppLocalizations.of(context)!;
    if (_saisie.text.length < 8) {
      setState(() => _erreur = l10n.passphraseMinLength);
      return;
    }
    if (widget.confirmer && _saisie.text != _confirmation.text) {
      setState(() => _erreur = 'Les passphrases ne correspondent pas');
      return;
    }
    Navigator.of(context).pop(_saisie.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.texte),
            const SizedBox(height: 16),
            TextField(
              controller: _saisie,
              obscureText: !_visible,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.passphrase,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _visible ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () => setState(() => _visible = !_visible),
                ),
              ),
            ),
            if (widget.confirmer) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _confirmation,
                obscureText: !_visible,
                decoration: InputDecoration(
                  labelText: l10n.confirmPassphraseLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
            if (_erreur != null) ...[
              const SizedBox(height: 8),
              Text(_erreur!, style: TextStyle(color: context.errorColor)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        TextButton(onPressed: _valider, child: Text(l10n.confirm)),
      ],
    );
  }
}
