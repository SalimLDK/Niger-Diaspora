import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/adaptive_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/services/e2ee/device_sync_service.dart';
import '../../../../core/services/e2ee/models/e2ee_models.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';

/// Nombre maximal d'appareils par compte, imposé par la synchro E2EE.
const int _kMaxDevices = 5;

/// Écran de gestion des appareils connectés (fiche 20b) : bandeau
/// d'explication chiffré, carte « cet appareil » mise en avant, empreinte de
/// clé lisible, et Renommer / Révoquer sortis du menu ⋯.
class DevicesScreen extends ConsumerStatefulWidget {
  const DevicesScreen({super.key});

  @override
  ConsumerState<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends ConsumerState<DevicesScreen> {
  bool _isLoading = true;
  List<E2EEDeviceInfo> _devices = [];
  String? _currentDeviceId;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    setState(() => _isLoading = true);

    try {
      final deviceSyncService = ref.read(deviceSyncServiceProvider);
      final devices = await deviceSyncService.getMyDevices(userId);
      final currentDevice = await deviceSyncService.getCurrentDevice(userId);

      if (!mounted) return;
      setState(() {
        _devices = devices;
        _currentDeviceId = currentDevice?.deviceId;
      });
    } catch (e) {
      debugPrint('Error loading devices: $e');
      _showErrorSnackBar('Erreur lors du chargement des appareils');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _renameDevice(E2EEDeviceInfo device) async {
    final controller = TextEditingController(text: device.deviceName);

    final l10n = AppLocalizations.of(context)!;
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final dialogL10n = AppLocalizations.of(ctx)!;
        return AlertDialog(
          title: Text(dialogL10n.renameDeviceTitle),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: dialogL10n.deviceNameLabel,
              border: const OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(dialogL10n.cancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: Text(dialogL10n.rename),
            ),
          ],
        );
      },
    );

    if (newName == null || newName.isEmpty || newName == device.deviceName) {
      return;
    }

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      final deviceSyncService = ref.read(deviceSyncServiceProvider);
      // `renameDevice` renvoie false sur échec au lieu de lever : sans ce
      // test, un renommage refusé affichait quand même « Appareil renommé ».
      final success = await deviceSyncService.renameDevice(
        userId,
        device.deviceId,
        newName,
      );
      if (success) {
        _showSuccessSnackBar(l10n.deviceRenameSuccess);
        await _loadDevices();
      } else {
        _showErrorSnackBar(l10n.deviceRenameError);
      }
    } catch (e) {
      _showErrorSnackBar(l10n.deviceRenameError);
    }
  }

  Future<void> _revokeDevice(E2EEDeviceInfo device) async {
    // La maquette révoque sans confirmation ; on la garde — l'appareil perd
    // l'accès à tous ses messages et ne le récupère pas.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final dialogL10n = AppLocalizations.of(ctx)!;
        return AlertDialog(
          title: Text(dialogL10n.revokeDeviceQuestion),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(dialogL10n.revokeDeviceConfirmMessage(device.deviceName)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.warningBackgroundColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    AppIcon(AppIcon.warning, color: context.warningColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        dialogL10n.revokeDeviceWarning,
                        style: TextStyle(
                          fontSize: 13,
                          color: context.warningColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(dialogL10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: context.errorColor),
              child: Text(dialogL10n.revokeDevice),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    setState(() => _isLoading = true);

    try {
      final deviceSyncService = ref.read(deviceSyncServiceProvider);
      final success = await deviceSyncService.removeDevice(
        userId,
        device.deviceId,
      );

      if (success) {
        _showSuccessSnackBar('Appareil révoqué');
      } else {
        _showErrorSnackBar('Impossible de révoquer cet appareil');
      }
      await _loadDevices();
    } catch (e) {
      _showErrorSnackBar('Erreur lors de la révocation');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: context.errorColor),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: context.successColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            Expanded(
              child:
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : RefreshIndicator(
                        // Remplace le bouton d'actualisation de l'en-tête,
                        // que la fiche ne prévoit pas.
                        onRefresh: _loadDevices,
                        child:
                            _devices.isEmpty
                                ? _buildEmptyState(context)
                                : _buildDevicesList(context),
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap:
                  () =>
                      context.canPop()
                          ? context.pop()
                          : context.go('/settings/security'),
              child: SizedBox(
                width: 24,
                height: 48,
                child: Center(
                  child: AppIcon(
                    AppIcon.arrowBack,
                    size: 24,
                    color: context.textPrimaryColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                AppLocalizations.of(context)!.connectedDevices,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimaryColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
      children: [
        Icon(Icons.devices, size: 64, color: context.textTertiaryColor),
        const SizedBox(height: 16),
        Text(
          l10n.noDeviceRegistered,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: context.textPrimaryColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.devicesE2eeWillAppear,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: context.textSecondaryColor),
        ),
      ],
    );
  }

  Widget _buildDevicesList(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        _InfoBanner(count: _devices.length),
        const SizedBox(height: 14),
        // Si aucune carte ne porte « CET APPAREIL », l'utilisateur a devant
        // lui des lignes indiscernables et peut révoquer la sienne. Le dire
        // vaut mieux que de laisser deviner.
        if (_devices.every((d) => d.deviceId != _currentDeviceId)) ...[
          const _UnknownCurrentDeviceNotice(),
          const SizedBox(height: 14),
        ],
        for (final device in _devices)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _DeviceCard(
              device: device,
              isCurrent: device.deviceId == _currentDeviceId,
              onRename: () => _renameDevice(device),
              onRevoke: () => _revokeDevice(device),
            ),
          ),
        const SizedBox(height: 4),
        const _LimitNotice(),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Bandeau d'explication
// ---------------------------------------------------------------------------

/// « 3 appareils sur 5 » et ce que révoquer implique, dans un seul bloc — le
/// compteur vivait loin de l'explication qui lui donne son sens.
class _InfoBanner extends StatelessWidget {
  final int count;

  const _InfoBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: AppIcon(
              AppIcon.info,
              size: 18,
              color: context.textSecondaryColor,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count > 1
                      ? '$count appareils sur $_kMaxDevices'
                      : '$count appareil sur $_kMaxDevices',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  AppLocalizations.of(context)!.deviceManagementInfo,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: context.textSecondaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Affiché quand aucun appareil de la liste ne correspond à l'identifiant
/// local — après une réinstallation qui a vidé les données, typiquement.
class _UnknownCurrentDeviceNotice extends StatelessWidget {
  const _UnknownCurrentDeviceNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.warningBackgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.warningColor.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          AppIcon(AppIcon.warning, size: 18, color: context.warningColor),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              "Cet appareil n'a pas pu être identifié dans la liste. "
              'Vérifiez l\'empreinte avant de révoquer quoi que ce soit.',
              style: TextStyle(
                fontSize: 12,
                height: 1.45,
                color: context.textSecondaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Avertissement de limite, affiché en permanence : la contrainte se
/// découvrait au moment de connecter un 6e appareil, trop tard.
class _LimitNotice extends StatelessWidget {
  const _LimitNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.warningBackgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.warningColor.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        children: [
          AppIcon(AppIcon.warning, size: 18, color: context.warningColor),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              'Au-delà de $_kMaxDevices appareils, il faudra en révoquer un '
              'avant d\'en connecter un nouveau.',
              style: TextStyle(
                fontSize: 12,
                height: 1.45,
                color: context.textSecondaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Carte d'appareil
// ---------------------------------------------------------------------------

class _DeviceCard extends StatelessWidget {
  final E2EEDeviceInfo device;
  final bool isCurrent;
  final VoidCallback onRename;
  final VoidCallback onRevoke;

  const _DeviceCard({
    required this.device,
    required this.isCurrent,
    required this.onRename,
    required this.onRevoke,
  });

  @override
  Widget build(BuildContext context) {
    final fingerprint = _formatFingerprint(device.identityKeyPublic);
    final lastActive = _formatLastActive(device.lastActive);
    final isOnline = DateTime.now().difference(device.lastActive).inMinutes < 5;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(18),
        // L'appareil courant se reconnaît au cadre, pas seulement au badge.
        border: Border.all(
          color: isCurrent ? context.successColor : context.borderColor,
          width: isCurrent ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color:
                      isCurrent
                          ? context.successBackgroundColor
                          : context.surfaceVariantColor,
                  borderRadius: BorderRadius.circular(13),
                ),
                alignment: Alignment.center,
                child: Icon(
                  _deviceIcon(device.platform),
                  size: 21,
                  color:
                      isCurrent
                          ? context.successColor
                          : context.textSecondaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            device.deviceName,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: context.textPrimaryColor,
                            ),
                          ),
                        ),
                        if (isCurrent) ...[
                          const SizedBox(width: 7),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: context.successBackgroundColor,
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Text(
                              'CET APPAREIL',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: context.successColor,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_platformName(device.platform)} · $lastActive',
                      style: TextStyle(
                        fontSize: 11.5,
                        color:
                            isOnline
                                ? context.successColor
                                : context.textTertiaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (fingerprint != null) ...[
            const SizedBox(height: 9),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: context.surfaceVariantColor,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                'Empreinte : $fingerprint',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: context.textSecondaryColor,
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          // Les actions sortent du menu ⋯ : sur un écran de sécurité, ce qu'on
          // peut faire à un appareil doit se voir.
          if (isCurrent)
            _CardAction(label: 'Renommer', onTap: onRename)
          else
            Row(
              children: [
                Expanded(child: _CardAction(label: 'Renommer', onTap: onRename)),
                const SizedBox(width: 8),
                Expanded(
                  child: _CardAction(
                    label: 'Révoquer',
                    danger: true,
                    onTap: onRevoke,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// Rend l'empreinte comparable à l'œil : majuscules, groupes de 4, tronquée.
  /// C'est le même préfixe de clé qu'avant, juste lisible.
  static String? _formatFingerprint(String identityKey) {
    if (identityKey.isEmpty) return null;
    final raw = identityKey
        .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
        .toUpperCase();
    if (raw.isEmpty) return null;
    final take = raw.length < 12 ? raw.length : 12;
    final groups = <String>[];
    for (var i = 0; i < take; i += 4) {
      groups.add(raw.substring(i, (i + 4) > take ? take : i + 4));
    }
    return '${groups.join(' ')}…';
  }

  static IconData _deviceIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'android':
        return Icons.smartphone;
      case 'ios':
        return Icons.tablet_mac;
      case 'web':
        return Icons.public;
      case 'windows':
        return Icons.desktop_windows;
      case 'macos':
        return Icons.laptop_mac;
      case 'linux':
        return Icons.computer;
      default:
        return Icons.devices;
    }
  }

  static String _platformName(String platform) {
    switch (platform.toLowerCase()) {
      case 'android':
        return 'Android';
      case 'ios':
        return 'iPhone/iPad';
      case 'web':
        return 'Navigateur Web';
      case 'windows':
        return 'Windows';
      case 'macos':
        return 'macOS';
      case 'linux':
        return 'Linux';
      default:
        return platform;
    }
  }

  static String _formatLastActive(DateTime lastActive) {
    final diff = DateTime.now().difference(lastActive);
    if (diff.inMinutes < 5) return 'en ligne';
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
    if (diff.inDays < 7) return 'il y a ${diff.inDays} j';
    return '${lastActive.day}/${lastActive.month}/${lastActive.year}';
  }
}

class _CardAction extends StatelessWidget {
  final String label;
  final bool danger;
  final VoidCallback onTap;

  const _CardAction({
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(11);
    return InkWell(
      borderRadius: radius,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(
            color:
                danger
                    ? context.errorColor.withValues(alpha: 0.35)
                    : context.borderStrongColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: danger ? context.errorColor : context.textSecondaryColor,
          ),
        ),
      ),
    );
  }
}
