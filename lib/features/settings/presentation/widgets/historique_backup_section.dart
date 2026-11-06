import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/error_handler.dart';
import '../../../../core/providers/uid_firebase_provider.dart';
import '../../../../core/services/e2ee/historique_backup_service.dart';
import '../../../../core/services/e2ee/key_backup_service.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../../../core/theme/design_kit.dart';
import '../../../../l10n/app_localizations.dart';

/// Sauvegarde automatique et restauration de l'historique des discussions
/// chiffrées.
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
  bool _actif = false;
  bool _lu = false;
  bool _occupe = false;

  @override
  void initState() {
    super.initState();
    unawaited(_lireEtat());
  }

  HistoriqueBackupService get _service =>
      ref.read(historiqueBackupServiceProvider);

  Future<void> _lireEtat() async {
    final uid = ref.read(uidFirebaseProvider);
    if (uid == null) return;
    final actif = await _service.estActive(uid);
    final infos = await _service.infos(uid);
    if (!mounted) return;
    setState(() {
      _actif = actif;
      _infos = infos;
      _lu = true;
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

  /// Exécute [action] avec le verrou « occupé », et traduit les échecs connus.
  Future<void> _faire(Future<void> Function(String uid) action) async {
    final uid = ref.read(uidFirebaseProvider);
    if (uid == null || _occupe) return;
    setState(() => _occupe = true);
    try {
      await action(uid);
    } on RienASauvegarderException {
      _message(l10n.historyBackupNothing, erreur: true);
    } on SauvegardeIllisibleException {
      _message(l10n.historyUnreadable, erreur: true);
    } on PassphraseException {
      _message(l10n.invalidPassphrase, erreur: true);
    } on BackupNotFoundException {
      _message(l10n.noBackupFound, erreur: true);
    } catch (e) {
      _message(_echec(e), erreur: true);
    } finally {
      if (mounted) setState(() => _occupe = false);
      unawaited(_lireEtat());
    }
  }

  String _resume(ResultatSauvegardeHistorique r) {
    final fait = l10n.historyBackupDone(r.messages);
    return r.tronque ? '$fait\n${l10n.historyBackupTruncated}' : fait;
  }

  Future<void> _activer() async {
    // Une sauvegarde existe déjà : une clé neuve la remplacerait. Le dire AVANT
    // de montrer la clé, pour qu'annuler reste possible et gratuit.
    if (_infos != null) {
      final continuer = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          content: Text(l10n.historyOverwriteWarning),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: ctx.errorColor),
              child: Text(l10n.historyKeyActivate),
            ),
          ],
        ),
      );
      if (continuer != true || !mounted) return;
    }

    final cle = HistoriqueBackupService.genererCle();
    final note = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DialogueCle(cle: cle),
    );
    if (note != true) return;

    final ecraser = _infos != null;
    await _faire((uid) async {
      await _service.activer(uid, cle: cle);
      // Activée même si l'envoi échoue (hors ligne) : le déclencheur
      // automatique reprendra.
      final r = await _service.sauvegarderMaintenant(uid, ecraser: ecraser);
      _message(_resume(r));
    });
  }

  Future<void> _sauvegarderMaintenant() => _faire((uid) async {
    final r = await _service.sauvegarderMaintenant(uid);
    _message(_resume(r));
  });

  Future<void> _restaurer() async {
    final cle = await showDialog<String>(
      context: context,
      builder: (_) => _DialogueCleSaisie(texte: l10n.historyRestoreHint),
    );
    if (cle == null) return;
    await _faire((uid) async {
      final ajoutes = await _service.restaurer(uid, cle);
      // La clé qui vient d'ouvrir la sauvegarde sert aux suivantes : sans quoi
      // le téléphone restauré ne sauvegarderait plus rien.
      await _service.activer(uid, cle: cle);
      _message(
        ajoutes == 0
            ? l10n.historyRestoreNothingNew
            : l10n.historyRestoreAutoOn(ajoutes),
      );
    });
  }

  Future<void> _desactiver() async {
    final confirme = await _confirmer(
      l10n.historyDisableConfirm,
      l10n.historyDisableAction,
    );
    if (!confirme) return;
    await _faire((uid) => _service.desactiver(uid));
  }

  Future<void> _supprimer() async {
    final confirme = await _confirmer(l10n.historyDeleteConfirm, l10n.delete);
    if (!confirme) return;
    await _faire((uid) async {
      await _service.supprimer(uid);
      _message(l10n.historyDeleteDone);
    });
  }

  Future<bool> _confirmer(String texte, String libelle) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(texte),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: ctx.errorColor),
            child: Text(libelle),
          ),
        ],
      ),
    );
    return ok == true && mounted;
  }

  String _dateCourte(DateTime d) =>
      '${d.day}/${d.month}/${d.year} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';

  String? get _sousTitre {
    if (!_lu) return null;
    if (!_actif) return l10n.historyBackupNone;
    final creeLe = _infos?.creeLe;
    if (creeLe == null) return l10n.historyAutoOn;
    return l10n.historyAutoOnLast(
      _dateCourte(creeLe),
      _infos?.messages ?? 0,
    );
  }

  @override
  Widget build(BuildContext context) {
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
              if (_actif) ...[
                DesignSettingsTile(
                  icon: const Icon(Icons.cloud_done_outlined),
                  title: l10n.historyAutoTitle,
                  subtitle: _sousTitre,
                ),
                DesignSettingsTile(
                  icon: const Icon(Icons.cloud_upload_outlined),
                  title: l10n.historyBackupNowAction,
                  onTap: _sauvegarderMaintenant,
                ),
              ] else
                DesignSettingsTile(
                  icon: const Icon(Icons.cloud_upload_outlined),
                  title: l10n.historyBackupAction,
                  subtitle: _sousTitre,
                  onTap: _lu ? _activer : null,
                ),
              DesignSettingsTile(
                icon: const Icon(Icons.cloud_download_outlined),
                title: l10n.historyRestoreAction,
                onTap: _restaurer,
              ),
              if (_actif)
                DesignSettingsTile(
                  icon: const Icon(Icons.cloud_off_outlined),
                  title: l10n.historyDisableAction,
                  onTap: _desactiver,
                ),
              if (_infos != null)
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

/// Montre la clé de récupération **une seule fois**. On ne la quitte qu'en
/// affirmant l'avoir notée : fermer à côté la perdrait pour de bon.
class _DialogueCle extends StatefulWidget {
  final String cle;
  const _DialogueCle({required this.cle});

  @override
  State<_DialogueCle> createState() => _DialogueCleState();
}

class _DialogueCleState extends State<_DialogueCle> {
  bool _note = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.historyKeyTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.historyKeyBody),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      widget.cle,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: widget.cle));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.passphraseCopied)),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _note,
              onChanged: (v) => setState(() => _note = v ?? false),
              title: Text(l10n.historyKeySaved),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: _note ? () => Navigator.of(context).pop(true) : null,
          child: Text(l10n.historyKeyActivate),
        ),
      ],
    );
  }
}

/// Saisie de la clé de récupération. Le contrôleur vit dans l'état du
/// dialogue : le libérer depuis l'appelant, pendant l'animation de fermeture,
/// le ferait utiliser après `dispose`.
class _DialogueCleSaisie extends StatefulWidget {
  final String texte;
  const _DialogueCleSaisie({required this.texte});

  @override
  State<_DialogueCleSaisie> createState() => _DialogueCleSaisieState();
}

class _DialogueCleSaisieState extends State<_DialogueCleSaisie> {
  final _saisie = TextEditingController();
  String? _erreur;

  @override
  void dispose() {
    _saisie.dispose();
    super.dispose();
  }

  void _valider() {
    // Espaces et casse ne font pas partie de la clé : on la recopie à la main.
    final cle = _saisie.text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '-');
    if (cle.length < 8) {
      setState(
        () => _erreur = AppLocalizations.of(context)!.passphraseMinLength,
      );
      return;
    }
    Navigator.of(context).pop(cle);
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
              autofocus: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: l10n.passphrase,
                border: const OutlineInputBorder(),
                errorText: _erreur,
              ),
            ),
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
