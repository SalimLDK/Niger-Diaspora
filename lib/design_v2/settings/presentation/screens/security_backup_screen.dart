import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/design_kit.dart';
import '../../../../core/theme/adaptive_colors.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/e2ee/key_backup_service.dart';
import '../../../../l10n/app_localizations.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';
import 'package:diaspo_niger/core/errors/error_handler.dart';

/// Écran de sauvegarde et restauration des clés E2EE
class SecurityBackupScreen extends ConsumerStatefulWidget {
  const SecurityBackupScreen({super.key});

  @override
  ConsumerState<SecurityBackupScreen> createState() => _SecurityBackupScreenState();
}

class _SecurityBackupScreenState extends ConsumerState<SecurityBackupScreen> {
  final _passphraseController = TextEditingController();
  final _confirmPassphraseController = TextEditingController();
  final _restorePassphraseController = TextEditingController();

  bool _isLoading = false;
  bool _hasBackup = false;
  bool _showPassphrase = false;
  BackupMetadata? _backupMetadata;
  String? _generatedPassphrase;
  PassphraseStrength _passphraseStrength = PassphraseStrength.weak;

  @override
  void initState() {
    super.initState();
    _checkExistingBackup();
  }

  @override
  void dispose() {
    _passphraseController.dispose();
    _confirmPassphraseController.dispose();
    _restorePassphraseController.dispose();
    super.dispose();
  }

  Future<void> _checkExistingBackup() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    setState(() => _isLoading = true);

    try {
      final backupService = ref.read(keyBackupServiceProvider);
      final hasBackup = await backupService.hasBackup(userId);

      if (hasBackup) {
        final metadata = await backupService.getBackupMetadata(userId);
        setState(() {
          _hasBackup = true;
          _backupMetadata = metadata;
        });
      }
    } catch (e) {
      debugPrint('Error checking backup: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _updatePassphraseStrength(String passphrase) {
    final backupService = ref.read(keyBackupServiceProvider);
    setState(() {
      _passphraseStrength = backupService.evaluatePassphraseStrength(passphrase);
    });
  }

  Future<void> _generatePassphrase() async {
    final backupService = ref.read(keyBackupServiceProvider);
    final passphrase = backupService.generateSecurePassphrase();

    setState(() {
      _generatedPassphrase = passphrase;
      _passphraseController.text = passphrase;
      _confirmPassphraseController.text = passphrase;
      _passphraseStrength = PassphraseStrength.strong;
    });
  }

  Future<void> _createBackup() async {
    final l10n = AppLocalizations.of(context)!;
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final passphrase = _passphraseController.text;
    final confirmPassphrase = _confirmPassphraseController.text;

    if (passphrase.length < 8) {
      _showErrorSnackBar(l10n.passphraseMinLength);
      return;
    }

    if (passphrase != confirmPassphrase) {
      _showErrorSnackBar('Les passphrases ne correspondent pas');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final backupService = ref.read(keyBackupServiceProvider);
      await backupService.createAndUploadBackup(userId, passphrase);

      _showSuccessSnackBar(l10n.backupCreatedSuccess);
      _passphraseController.clear();
      _confirmPassphraseController.clear();
      setState(() => _generatedPassphrase = null);

      await _checkExistingBackup();
    } catch (e) {
      _showErrorSnackBar(
        ErrorHandler.instance.getShortMessage(
          ErrorHandler.instance.handleException(e),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _restoreBackup() async {
    final l10n = AppLocalizations.of(context)!;
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final passphrase = _restorePassphraseController.text;

    if (passphrase.isEmpty) {
      _showErrorSnackBar('Veuillez entrer votre passphrase');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final backupService = ref.read(keyBackupServiceProvider);
      await backupService.downloadAndRestoreBackup(userId, passphrase);

      _showSuccessSnackBar(l10n.keysRestoredSuccess);
      _restorePassphraseController.clear();

      if (mounted) {
        Navigator.of(context).pop();
      }
    } on PassphraseException {
      _showErrorSnackBar('Passphrase incorrecte');
    } on BackupNotFoundException {
      _showErrorSnackBar(l10n.noBackupFound);
    } catch (e) {
      _showErrorSnackBar('Erreur lors de la restauration: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteBackup() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.securityDeleteBackupTitle),
        content: Text(l10n.securityDeleteBackupContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    setState(() => _isLoading = true);

    try {
      final backupService = ref.read(keyBackupServiceProvider);
      await backupService.deleteBackup(userId);

      _showSuccessSnackBar(l10n.securityBackupDeleted);
      setState(() {
        _hasBackup = false;
        _backupMetadata = null;
      });
    } catch (e) {
      _showErrorSnackBar(
        ErrorHandler.instance.getShortMessage(
          ErrorHandler.instance.handleException(e),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        backgroundColor: context.backgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        title: DesignTitle(l10n.securityBackupTitle, size: 22),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              AppIcon(AppIcon.lock,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  l10n.endToEndEncryption,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            l10n.e2eeDescription,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Existing backup info
                  if (_hasBackup) ...[
                    Text(
                      l10n.existingBackup,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      color: Colors.green.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.cloud_done,
                                  color: Colors.green.shade700,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  l10n.backupActive,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ],
                            ),
                            if (_backupMetadata != null) ...[
                              const SizedBox(height: 12),
                              if (_backupMetadata!.createdAt != null)
                                Text(
                                  l10n.backupCreatedOn(_formatDate(_backupMetadata!.createdAt!)),
                                  style: theme.textTheme.bodySmall,
                                ),
                              if (_backupMetadata!.deviceInfo != null)
                                Text(
                                  'Appareil: ${_backupMetadata!.deviceInfo}',
                                  style: theme.textTheme.bodySmall,
                                ),
                            ],
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _deleteBackup,
                                    icon: AppIcon(AppIcon.delete, color: theme.colorScheme.primary),
                                    label: Text(AppLocalizations.of(context)!.delete),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Restore section
                    Text(
                      AppLocalizations.of(context)!.restoreOnThisDevice,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppLocalizations.of(context)!.enterPassphraseToRestore,
                              style: theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _restorePassphraseController,
                              obscureText: !_showPassphrase,
                              decoration: InputDecoration(
                                labelText: AppLocalizations.of(context)!.passphrase,
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _showPassphrase
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _showPassphrase = !_showPassphrase;
                                    });
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _restoreBackup,
                                icon: const Icon(Icons.restore),
                                label: Text(AppLocalizations.of(context)!.restoreKeys),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    // Create backup section
                    Text(
                      l10n.createBackupButton,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Warning
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  AppIcon(
                                    AppIcon.warning,
                                    color: Colors.orange.shade700,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'N\'oubliez pas votre passphrase ! '
                                      '${l10n.passphraseRequiredNote}',
                                      style: TextStyle(
                                        color: Colors.orange.shade900,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Generate passphrase button
                            OutlinedButton.icon(
                              onPressed: _generatePassphrase,
                              icon: const Icon(Icons.auto_awesome),
                              label: Text(AppLocalizations.of(context)!.generatePassphrase),
                            ),

                            if (_generatedPassphrase != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _generatedPassphrase!,
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.copy),
                                      onPressed: () {
                                        Clipboard.setData(
                                          ClipboardData(text: _generatedPassphrase!),
                                        );
                                        _showSuccessSnackBar(l10n.passphraseCopied);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 16),

                            // Passphrase input
                            TextField(
                              controller: _passphraseController,
                              obscureText: !_showPassphrase,
                              onChanged: _updatePassphraseStrength,
                              decoration: InputDecoration(
                                labelText: AppLocalizations.of(context)!.passphrase,
                                hintText: AppLocalizations.of(context)!.passphraseHint,
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _showPassphrase
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _showPassphrase = !_showPassphrase;
                                    });
                                  },
                                ),
                              ),
                            ),

                            const SizedBox(height: 8),

                            // Strength indicator
                            _buildStrengthIndicator(),

                            const SizedBox(height: 16),

                            // Confirm passphrase
                            TextField(
                              controller: _confirmPassphraseController,
                              obscureText: !_showPassphrase,
                              decoration: InputDecoration(
                                labelText: AppLocalizations.of(context)!.confirmPassphraseLabel,
                                border: const OutlineInputBorder(),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Create button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _passphraseStrength != PassphraseStrength.weak
                                    ? _createBackup
                                    : null,
                                icon: const Icon(Icons.cloud_upload),
                                label: Text(AppLocalizations.of(context)!.createBackupButton),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildStrengthIndicator() {
    final l10n = AppLocalizations.of(context)!;
    Color color;
    String text;
    double progress;

    switch (_passphraseStrength) {
      case PassphraseStrength.weak:
        color = Colors.red;
        text = l10n.weak;
        progress = 0.33;
        break;
      case PassphraseStrength.medium:
        color = Colors.orange;
        text = l10n.medium;
        progress = 0.66;
        break;
      case PassphraseStrength.strong:
        color = Colors.green;
        text = l10n.strong;
        progress = 1.0;
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey.shade200,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
        const SizedBox(height: 4),
        Text(
          '${l10n.passphraseStrength}: $text',
          style: TextStyle(
            color: color,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} à ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
