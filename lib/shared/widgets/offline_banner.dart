import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/connectivity_provider.dart';
import '../../core/services/offline_sync_service.dart';
import '../../l10n/app_localizations.dart';

/// Bannière affichée quand l'utilisateur est hors-ligne
class OfflineBanner extends ConsumerWidget {
  final Widget child;

  const OfflineBanner({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isConnected = ref.watch(connectivityNotifierProvider);

    return Column(
      children: [
        // Bannière offline
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: isConnected ? 0 : null,
          child: isConnected
              ? const SizedBox.shrink()
              : const _OfflineBannerContent(),
        ),
        // Contenu principal
        Expanded(child: child),
      ],
    );
  }
}

class _OfflineBannerContent extends StatelessWidget {
  const _OfflineBannerContent();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.errorContainer,
      child: SafeArea(
        bottom: false,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.cloud_off,
                size: 18,
                color: theme.colorScheme.onErrorContainer,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!.offlineMode,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              _SyncStatusIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}

class _SyncStatusIndicator extends StatefulWidget {
  @override
  State<_SyncStatusIndicator> createState() => _SyncStatusIndicatorState();
}

class _SyncStatusIndicatorState extends State<_SyncStatusIndicator> {
  late Stream<SyncStatus> _syncStream;

  @override
  void initState() {
    super.initState();
    _syncStream = OfflineSyncService.instance.syncStatusStream;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StreamBuilder<SyncStatus>(
      stream: _syncStream,
      builder: (context, snapshot) {
        final status = snapshot.data;

        if (status == null || !status.hasPendingActions) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.onErrorContainer.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (status.isSyncing)
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                )
              else
                Icon(
                  Icons.sync,
                  size: 14,
                  color: theme.colorScheme.onErrorContainer,
                ),
              const SizedBox(width: 6),
              Text(
                '${status.pendingCount}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Indicateur de synchronisation en cours
class SyncIndicator extends StatelessWidget {
  final bool isSyncing;
  final int pendingCount;

  const SyncIndicator({
    super.key,
    required this.isSyncing,
    required this.pendingCount,
  });

  @override
  Widget build(BuildContext context) {
    if (pendingCount == 0) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isSyncing)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            )
          else
            Icon(
              Icons.cloud_upload_outlined,
              size: 16,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          const SizedBox(width: 8),
          Text(
            isSyncing
                ? AppLocalizations.of(context)!.syncingLabel
                : AppLocalizations.of(context)!.pendingSyncCount(pendingCount),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
