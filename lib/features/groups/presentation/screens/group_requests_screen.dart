import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/date_formatter.dart';
import '../../domain/entities/group_request_entity.dart';
import '../providers/group_provider.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';

class GroupRequestsScreen extends ConsumerWidget {
  final String groupId;

  const GroupRequestsScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    // Note: groupPendingRequestsProvider must be defined in group_provider.dart
    final requestsAsync = ref.watch(groupPendingRequestsProvider(groupId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Demandes d\'adhésion'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: requestsAsync.when(
        data: (requests) {
          if (requests.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.person_add_disabled_outlined,
                    size: 64,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.noPendingRequests,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final request = requests[index];
              return _RequestItem(request: request, groupId: groupId);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Erreur: $error')),
      ),
    );
  }
}

class _RequestItem extends ConsumerStatefulWidget {
  final GroupRequestEntity request;
  final String groupId;

  const _RequestItem({required this.request, required this.groupId});

  @override
  ConsumerState<_RequestItem> createState() => _RequestItemState();
}

class _RequestItemState extends ConsumerState<_RequestItem> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  bool _isLoading = false;

  Future<void> _approve() async {
    setState(() => _isLoading = true);
    try {
      final repository = ref.read(groupRepositoryProvider);
      final result = await repository.approveJoinRequest(widget.request.id);
      result.fold(
        (failure) => ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message))),
        (_) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.groupApprovedRequest)));
        },
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _reject() async {
    setState(() => _isLoading = true);
    try {
      final repository = ref.read(groupRepositoryProvider);
      final result = await repository.rejectJoinRequest(widget.request.id);
      result.fold(
        (failure) => ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message))),
        (_) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.groupDeclinedRequest)));
        },
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 24,
        backgroundImage:
            widget.request.requesterPhotoUrl != null
                ? NetworkImage(widget.request.requesterPhotoUrl!)
                : null,
        child:
            widget.request.requesterPhotoUrl == null
                ? Text(
                  widget.request.requesterName[0].toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                )
                : null,
      ),
      title: Text(
        widget.request.requesterName,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.request.message != null &&
              widget.request.message!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                widget.request.message!,
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              widget.request.createdAt != null
                  ? DateFormatter.timeAgo(widget.request.createdAt!)
                  : '',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
      trailing:
          _isLoading
              ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
              : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: _reject,
                    tooltip: l10n.groupRejectAction,
                  ),
                  IconButton(
                    icon: Icon(Icons.check, color: theme.colorScheme.primary),
                    onPressed: _approve,
                    tooltip: l10n.groupApproveAction,
                  ),
                ],
              ),
    );
  }
}
