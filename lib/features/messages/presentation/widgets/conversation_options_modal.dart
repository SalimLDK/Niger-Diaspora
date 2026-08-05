import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../../../shared/widgets/app_icon.dart';
import '../../../../shared/widgets/sheet_handle.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../polls/domain/entities/poll_entity.dart';
import '../../../polls/presentation/widgets/create_poll_sheet.dart';
import '../../../settings/presentation/providers/blocked_users_provider.dart';
import '../../../reports/domain/entities/report_entity.dart';
import '../../../reports/presentation/widgets/report_content_modal.dart';
import '../../domain/services/message_export_service.dart';
import '../providers/conversation_actions_provider.dart';
import '../providers/message_provider.dart';
import 'auto_delete_settings_sheet.dart';
import 'mute_duration_sheet.dart';

const _pollAccent = Color(0xFF6B5CE0);

class ConversationOptionsModal extends ConsumerStatefulWidget {
  final String conversationId;
  final String? otherUserId;
  final String? otherUserName;
  final String? otherUserPhotoUrl;
  final bool isMuted;
  final bool isArchived;
  final bool isGroup;
  final bool isAdmin;
  final int? autoDeleteAfterSeconds;
  final VoidCallback? onChangeBackground;
  final VoidCallback? onSearch;

  // Actions de creation de contenu de groupe (event/poll), regroupees en haut
  final String? groupId;
  final bool canPostEvents;
  final bool canPostPolls;

  const ConversationOptionsModal({
    super.key,
    required this.conversationId,
    this.otherUserId,
    this.otherUserName,
    this.otherUserPhotoUrl,
    this.isMuted = false,
    this.isArchived = false,
    this.isGroup = false,
    this.isAdmin = false,
    this.autoDeleteAfterSeconds,
    this.onChangeBackground,
    this.onSearch,
    this.groupId,
    this.canPostEvents = false,
    this.canPostPolls = false,
  });

  @override
  ConsumerState<ConversationOptionsModal> createState() =>
      _ConversationOptionsModalState();
}

class _ConversationOptionsModalState
    extends ConsumerState<ConversationOptionsModal> {
  bool _isLoading = false;

  String? _getAutoDeleteLabel(AppLocalizations l10n) {
    final seconds = widget.autoDeleteAfterSeconds;
    if (seconds == null) return l10n.off;
    if (seconds == 86400) return l10n.hours24;
    if (seconds == 604800) return l10n.days7;
    if (seconds == 2592000) return l10n.days30;
    return '$seconds s';
  }

  Future<void> _muteConversation() async {
    final l10n = AppLocalizations.of(context)!;

    if (widget.isMuted) {
      // Unmute - direct action
      setState(() => _isLoading = true);

      final success = await ref
          .read(conversationActionsNotifierProvider.notifier)
          .muteConversation(widget.conversationId, false);

      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? l10n.unmuteConversation : l10n.error),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } else {
      // Mute - show duration selection sheet
      Navigator.pop(context);
      await MuteDurationSheet.show(
        context,
        conversationId: widget.conversationId,
      );
    }
  }

  Future<void> _archiveConversation() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isLoading = true);

    final success = await ref
        .read(conversationActionsNotifierProvider.notifier)
        .archiveConversation(widget.conversationId, !widget.isArchived);

    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? (widget.isArchived
                    ? l10n.unarchiveConversation
                    : l10n.archiveConversation)
                : l10n.error,
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteConversation() async {
    final l10n = AppLocalizations.of(context)!;
    String deleteType = 'me'; // Default to soft delete

    if (widget.isAdmin) {
      final choice = await showDialog<String>(
        context: context,
        builder:
            (context) => SimpleDialog(
              title: Text(l10n.deleteConversation),
              children: [
                SimpleDialogOption(
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 24,
                  ),
                  onPressed: () => Navigator.pop(context, 'me'),
                  child: Text(l10n.deleteForMe),
                ),
                SimpleDialogOption(
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 24,
                  ),
                  onPressed: () => Navigator.pop(context, 'all'),
                  child: Text(
                    l10n.deleteForEveryone,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
      );

      if (choice == null) return;
      deleteType = choice;
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Text(l10n.deleteConversation),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.confirmDeleteConversation),
                  // CORRECTION: Ajouter avertissement pour conversations 1:1
                  if (!widget.isGroup) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const AppIcon(AppIcon.warning,
                            color: Colors.orange,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l10n.deleteConversationWarning,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange[800],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(l10n.cancel),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: Text(l10n.delete),
                ),
              ],
            ),
      );

      if (confirmed != true) return;
    }

    if (!mounted) return;

    setState(() => _isLoading = true);

    final success = await ref
        .read(conversationActionsNotifierProvider.notifier)
        .deleteConversation(
          widget.conversationId,
          forEveryone: deleteType == 'all',
        );

    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.pop(context);

      if (success) {
        context.pop(); // Go back from conversation screen
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.conversationDeleted),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.deleteError),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _blockUser() async {
    if (widget.otherUserId == null) return;
    final l10n = AppLocalizations.of(context)!;
    final userName = widget.otherUserName ?? l10n.user;

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(l10n.blockUserTitle),
            content: Text(l10n.confirmBlockUser(userName)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.cancel),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: Text(l10n.block),
              ),
            ],
          ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);

    final success = await ref
        .read(blockUserNotifierProvider.notifier)
        .blockUser(
          targetUserId: widget.otherUserId!,
          targetDisplayName: widget.otherUserName ?? l10n.user,
          targetPhotoUrl: widget.otherUserPhotoUrl,
        );

    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? l10n.userBlocked : l10n.blockError),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _unblockUser() async {
    if (widget.otherUserId == null) return;
    final l10n = AppLocalizations.of(context)!;
    final userName = widget.otherUserName ?? l10n.user;

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(l10n.unblockUserTitle),
            content: Text(l10n.confirmUnblockUser(userName)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.cancel),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.adaptivePrimaryColor,
                ),
                child: Text(l10n.unblock),
              ),
            ],
          ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);

    final success = await ref
        .read(blockUserNotifierProvider.notifier)
        .unblockUser(widget.otherUserId!);

    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? l10n.userUnblocked : l10n.unblockError),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _reportConversation() async {
    Navigator.pop(context);

    await ReportContentModal.show(
      context,
      targetType: widget.isGroup
          ? ReportTargetType.group
          : ReportTargetType.conversation,
      targetId: widget.conversationId,
      targetName: widget.otherUserName,
      conversationId: widget.conversationId,
    );
  }

  Future<void> _exportConversation() async {
    final l10n = AppLocalizations.of(context)!;

    final format = await showDialog<ExportFormat>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.exportConversation),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.text_snippet),
              title: Text(l10n.exportFormatTxt),
              onTap: () => Navigator.pop(ctx, ExportFormat.txt),
            ),
            ListTile(
              leading: const Icon(Icons.code),
              title: Text(l10n.exportFormatJson),
              onTap: () => Navigator.pop(ctx, ExportFormat.json),
            ),
            ListTile(
              leading: const Icon(Icons.html),
              title: Text(l10n.exportFormatHtml),
              onTap: () => Navigator.pop(ctx, ExportFormat.html),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );

    if (format == null || !mounted) return;

    setState(() => _isLoading = true);

    try {
      final conversation = await ref.read(
        conversationStreamProvider(widget.conversationId).future,
      );
      final messagesResult = await ref
          .read(messageRepositoryProvider)
          .getMessages(widget.conversationId)
          .first;
      final currentUser = ref.read(currentUserProvider).valueOrNull;

      final messages = messagesResult.getOrElse(() => []);

      if (conversation == null || messages.isEmpty) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.noMessagesToExport),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final file = await MessageExportService().exportConversation(
        conversation: conversation,
        messages: messages,
        format: format,
        currentUserId: currentUser?.id ?? '',
      );

      await MessageExportService().shareExportedFile(file);

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.exportError),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(20),
      // Scrollable + hauteur bornée : la liste d'options dépasse l'écran
      // en paysage ou sur petits écrans (RenderFlex overflow sinon).
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHandle(),
          const SizedBox(height: 20),
          Text(
            l10n.conversationOptions,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: context.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 20),
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.all(20),
              child: CircularProgressIndicator(
                color: context.adaptivePrimaryColor,
              ),
            )
          else ...[
            if (widget.isGroup && widget.groupId != null && widget.canPostEvents)
              _buildOption(
                iconWidget: AppIcon(
                  AppIcon.event,
                  size: 20,
                  color: context.adaptivePrimaryColor,
                ),
                title: 'Créer un événement',
                onTap: () {
                  Navigator.pop(context);
                  context.push('/groups/${widget.groupId}/events/create');
                },
              ),
            if (!widget.isGroup)
              _buildOption(
                iconWidget: AppIcon(
                  AppIcon.event,
                  size: 20,
                  color: context.adaptivePrimaryColor,
                ),
                title: 'Créer un événement',
                onTap: () {
                  Navigator.pop(context);
                  context.push(
                    '/conversations/${widget.conversationId}/events/create',
                  );
                },
              ),
            if (widget.isGroup && widget.groupId != null && widget.canPostPolls)
              _buildOption(
                iconWidget: const AppIcon(AppIcon.poll, size: 20, color: _pollAccent),
                title: 'Créer un sondage',
                onTap: () {
                  Navigator.pop(context);
                  showCreatePollSheet(
                    context,
                    contextType: PollContextType.group,
                    contextId: widget.groupId!,
                  );
                },
              ),
            if ((widget.isGroup &&
                    widget.groupId != null &&
                    (widget.canPostEvents || widget.canPostPolls)) ||
                !widget.isGroup)
              const Divider(),
            if (widget.onSearch != null)
              _buildOption(
                iconWidget: AppIcon(AppIcon.search, color: context.adaptivePrimaryColor),
                title: l10n.searchTitle,
                onTap: () {
                  Navigator.pop(context);
                  widget.onSearch?.call();
                },
              ),
            // La sous-barre « Médias · ÉCO » a disparu de la conversation
            // (fiche 6b : ÉCO tient sur la ligne épinglée). Le raccourci vers
            // la galerie n'est pas perdu pour autant, il vit ici.
            _buildOption(
              iconWidget: AppIcon(
                AppIcon.image,
                color: context.adaptivePrimaryColor,
              ),
              title: l10n.sharedMedia,
              onTap: () {
                Navigator.pop(context);
                context.push('/messages/${widget.conversationId}/media');
              },
            ),
            _buildOption(
              icon:
                  widget.isMuted
                      ? Icons.notifications_active
                      : Icons.notifications_off,
              title: widget.isMuted ? l10n.unmute : l10n.mute,
              onTap: _muteConversation,
            ),
            _buildOption(
              icon: Icons.timer_outlined,
              title: l10n.disappearingMessages,
              subtitle: _getAutoDeleteLabel(l10n),
              onTap: () {
                Navigator.pop(context);
                AutoDeleteSettingsSheet.show(
                  context,
                  conversationId: widget.conversationId,
                  currentDurationSeconds: widget.autoDeleteAfterSeconds,
                );
              },
            ),
            _buildOption(
              iconWidget: widget.isArchived
                  ? Icon(Icons.unarchive, color: context.adaptivePrimaryColor)
                  : AppIcon(AppIcon.archive, color: context.adaptivePrimaryColor),
              title: widget.isArchived ? l10n.unarchive : l10n.archive,
              onTap: _archiveConversation,
            ),
            if (widget.onChangeBackground != null)
              _buildOption(
                icon: Icons.wallpaper_outlined,
                title: l10n.changeWallpaper,
                onTap: () {
                  Navigator.pop(context);
                  widget.onChangeBackground?.call();
                },
              ),
            _buildOption(
              iconWidget: AppIcon(AppIcon.starBorder, color: context.adaptivePrimaryColor),
              title: l10n.starredMessages,
              onTap: () {
                Navigator.pop(context);
                context.push('/messages/${widget.conversationId}/starred');
              },
            ),
            _buildOption(
              icon: Icons.download_outlined,
              title: l10n.exportConversation,
              onTap: _exportConversation,
            ),
            if (!widget.isGroup && widget.otherUserId != null) ...[
              const Divider(),
              Consumer(
                builder: (context, ref, _) {
                  final blockedUsers = ref.watch(blockedUsersProvider).valueOrNull ?? [];
                  final isBlocked = blockedUsers.any((u) => u.id == widget.otherUserId);

                  return _buildOption(
                    iconWidget: isBlocked
                        ? AppIcon(AppIcon.checkCircle, color: context.adaptivePrimaryColor)
                        : const Icon(Icons.block, color: Colors.red),
                    title: isBlocked ? l10n.unblockUser : l10n.blockUser,
                    onTap: isBlocked ? _unblockUser : _blockUser,
                    isDestructive: !isBlocked,
                  );
                },
              ),
            ],
            const Divider(),
            _buildOption(
              iconWidget: AppIcon(AppIcon.flag, color: context.adaptivePrimaryColor),
              title: l10n.report,
              onTap: _reportConversation,
            ),
            // Action destructive isolée en bas, après un filet (§16).
            const Divider(),
            _buildOption(
              iconWidget: const AppIcon(AppIcon.delete, color: Colors.red),
              title: l10n.deleteConversation,
              onTap: _deleteConversation,
              isDestructive: true,
            ),
          ],
          const SizedBox(height: 20),
        ],
        ),
      ),
    );
  }

  Widget _buildOption({
    IconData? icon,
    Widget? iconWidget,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    assert(icon != null || iconWidget != null);
    final color = isDestructive ? Colors.red : context.textPrimaryColor;

    return ListTile(
      leading: iconWidget ??
          Icon(
            icon,
            color: isDestructive ? Colors.red : context.adaptivePrimaryColor,
          ),
      title: Text(title, style: TextStyle(color: color)),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: context.textSecondaryColor,
              ),
            )
          : null,
      onTap: onTap,
    );
  }
}
