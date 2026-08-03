import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/adaptive_colors.dart';
import '../../../../core/theme/design_kit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../core/services/e2ee/device_sync_service.dart';
import '../../../../core/services/e2ee/models/e2ee_models.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';

/// Ecran de gestion des appareils connectes
/// Permet de voir, renommer et revoquer les appareils
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

      setState(() {
        _devices = devices;
        _currentDeviceId = currentDevice?.deviceId;
      });
    } catch (e) {
      debugPrint('Error loading devices: $e');
      _showErrorSnackBar('Erreur lors du chargement des appareils');
    } finally {
      setState(() => _isLoading = false);
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
      await deviceSyncService.renameDevice(userId, device.deviceId, newName);

      _showSuccessSnackBar(l10n.deviceRenameSuccess);
      await _loadDevices();
    } catch (e) {
      _showErrorSnackBar(l10n.deviceRenameError);
    }
  }

  Future<void> _revokeDevice(E2EEDeviceInfo device) async {
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
      final success = await deviceSyncService.removeDevice(userId, device.deviceId);

      if (success) {
        _showSuccessSnackBar('Appareil revoque');
      } else {
        _showErrorSnackBar('Impossible de revoquer cet appareil');
      }
      await _loadDevices();
    } catch (e) {
      _showErrorSnackBar('Erreur lors de la revocation');
      setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: context.errorColor,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: context.successColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: context.backgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        title: DesignTitle(l10n.connectedDevices, size: 22),
        actions: [
          IconButton(
            icon: AppIcon(AppIcon.refresh, color: Theme.of(context).iconTheme.color!),
            onPressed: _loadDevices,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _devices.isEmpty
              ? _buildEmptyState(theme)
              : _buildDevicesList(theme),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.devices,
              size: 64,
              color: context.textSecondaryColor,
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.noDeviceRegistered,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.devicesE2eeWillAppear,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: context.textSecondaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDevicesList(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(16),
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
                    AppIcon(AppIcon.info,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Gestion des appareils',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  // La copie localisée existait déjà, accents compris ;
                  // l'écran en affichait un double codé en dur, sans
                  // accents.
                  AppLocalizations.of(context)!.deviceManagementInfo,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Device count
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_devices.length}/5 appareils',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_devices.length >= 5)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: context.warningBackgroundColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Limite atteinte',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.warningColor,
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 8),

        // Devices list
        ..._devices.map((device) => _buildDeviceCard(device, theme)),
      ],
    );
  }

  Widget _buildDeviceCard(E2EEDeviceInfo device, ThemeData theme) {
    final isCurrentDevice = device.deviceId == _currentDeviceId;
    final lastActiveText = _formatLastActive(device.lastActive);

    // Generate fingerprint from identity key (first 16 chars)
    final fingerprint = device.identityKeyPublic.isNotEmpty
        ? device.identityKeyPublic.substring(0, 16.clamp(0, device.identityKeyPublic.length))
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Device icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isCurrentDevice
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getDeviceIcon(device.platform),
                    color: isCurrentDevice
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                  ),
                ),
                const SizedBox(width: 16),

                // Device info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              device.deviceName,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isCurrentDevice) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: context.successBackgroundColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Cet appareil',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: context.successColor,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_getPlatformName(device.platform)} - $lastActiveText',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: context.textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),

                // Actions
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (action) {
                    switch (action) {
                      case 'rename':
                        _renameDevice(device);
                        break;
                      case 'revoke':
                        _revokeDevice(device);
                        break;
                    }
                  },
                  itemBuilder: (ctx) {
                    final menuL10n = AppLocalizations.of(ctx)!;
                    return [
                    PopupMenuItem(
                      value: 'rename',
                      child: Row(
                        children: [
                          const Icon(Icons.edit),
                          const SizedBox(width: 12),
                          Text(menuL10n.rename),
                        ],
                      ),
                    ),
                    if (!isCurrentDevice)
                      PopupMenuItem(
                        value: 'revoke',
                        child: Row(
                          children: [
                            AppIcon(AppIcon.delete, color: context.errorColor),
                            const SizedBox(width: 12),
                            Text(
                              menuL10n.revokeDevice,
                              style: TextStyle(color: context.errorColor),
                            ),
                          ],
                        ),
                      ),
                  ];
                  },
                ),
              ],
            ),

            // Fingerprint
            if (fingerprint != null && fingerprint.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.fingerprint,
                    size: 16,
                    color: context.textSecondaryColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Empreinte: $fingerprint...',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        color: context.textSecondaryColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getDeviceIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'android':
        return Icons.phone_android;
      case 'ios':
        return Icons.phone_iphone;
      case 'web':
        return Icons.web;
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

  String _getPlatformName(String platform) {
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

  String _formatLastActive(DateTime lastActive) {
    final now = DateTime.now();
    final diff = now.difference(lastActive);

    if (diff.inMinutes < 5) {
      return 'En ligne';
    } else if (diff.inMinutes < 60) {
      return 'Il y a ${diff.inMinutes} min';
    } else if (diff.inHours < 24) {
      return 'Il y a ${diff.inHours}h';
    } else if (diff.inDays < 7) {
      return 'Il y a ${diff.inDays}j';
    } else {
      return '${lastActive.day}/${lastActive.month}/${lastActive.year}';
    }
  }
}
