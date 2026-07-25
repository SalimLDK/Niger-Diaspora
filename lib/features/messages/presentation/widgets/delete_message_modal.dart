import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:diaspo_niger/shared/widgets/app_icon.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../domain/entities/message_entity.dart';
import '../providers/message_provider.dart';
import '../providers/conversation_actions_provider.dart';

class DeleteMessageModal extends ConsumerStatefulWidget {
  final MessageEntity message;
  final String conversationId;
  final String currentUserId;
  final bool isAdmin;
  final VoidCallback? onDeleted;

  const DeleteMessageModal({
    super.key,
    required this.message,
    required this.conversationId,
    required this.currentUserId,
    this.isAdmin = false,
    this.onDeleted,
  });

  static Future<void> show(
    BuildContext context, {
    required MessageEntity message,
    required String conversationId,
    required String currentUserId,
    bool isAdmin = false,
    VoidCallback? onDeleted,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (context) => DeleteMessageModal(
            message: message,
            conversationId: conversationId,
            currentUserId: currentUserId,
            isAdmin: isAdmin,
            onDeleted: onDeleted,
          ),
    );
  }

  @override
  ConsumerState<DeleteMessageModal> createState() => _DeleteMessageModalState();
}

class _DeleteMessageModalState extends ConsumerState<DeleteMessageModal> {
  bool get _canDeleteForEveryone =>
      widget.isAdmin ||
      widget.message.canDeleteForEveryone(widget.currentUserId);

  Future<void> _deleteForMe() async {
    // Unfocus to prevent keyboard from appearing
    FocusScope.of(context).unfocus();
    // Close modal immediately - deletion happens in background with optimistic update
    Navigator.pop(context);

    final success = await ref
        .read(deleteMessageProvider.notifier)
        .deleteForMe(
          conversationId: widget.conversationId,
          messageId: widget.message.id,
        );

    if (success) {
      widget.onDeleted?.call();
    }
    // No SnackBar - the message disappears instantly thanks to optimistic update
  }

  Future<void> _deleteForEveryone() async {
    // Check for time limit (only for non-admins)
    if (!widget.isAdmin &&
        DateTime.now().difference(widget.message.createdAt).inHours >= 1) {
      if (mounted) {
        Navigator.pop(context); // Close modal
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible de supprimer le message après 1h'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Unfocus to prevent keyboard from appearing
    FocusScope.of(context).unfocus();
    // Close modal immediately - deletion happens in background with optimistic update
    Navigator.pop(context);

    final success = await ref
        .read(deleteMessageProvider.notifier)
        .deleteForEveryone(
          conversationId: widget.conversationId,
          messageId: widget.message.id,
        );

    if (success) {
      widget.onDeleted?.call();
    }
    // No SnackBar - the message shows "supprimé" instantly thanks to optimistic update
  }

  Future<void> _reportMessage() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => _ReportDialog(),
    );

    if (reason == null || !mounted) return;

    // Unfocus to prevent keyboard from appearing
    FocusScope.of(context).unfocus();
    // Close modal immediately
    Navigator.pop(context);

    await ref
        .read(conversationActionsNotifierProvider.notifier)
        .reportMessage(
          conversationId: widget.conversationId,
          messageId: widget.message.id,
          reason: reason,
        );
    // No SnackBar - silent operation
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.textTertiaryColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Supprimer le message',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimaryColor,
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Delete for me option
            _OptionTile(
              icon: AppIcon(AppIcon.delete, color: context.textPrimaryColor),
              title: 'Supprimer pour moi',
              subtitle: 'Le message sera supprimé uniquement de votre vue',
              onTap: _deleteForMe,
            ),

            // Delete for everyone option (if allowed)
            if (_canDeleteForEveryone)
              _OptionTile(
                icon: const Icon(Icons.delete_forever, color: Colors.red),
                title: 'Supprimer pour tous',
                subtitle:
                    'Le message sera supprimé pour tous les participants',
                isDestructive: true,
                onTap: _deleteForEveryone,
              ),

            // Report message option (for messages not sent by current user)
            if (widget.message.senderId != widget.currentUserId)
              _OptionTile(
                icon: const AppIcon(AppIcon.flag, color: Colors.red),
                title: 'Signaler le message',
                subtitle: 'Signaler ce message aux administrateurs',
                isDestructive: true,
                onTap: _reportMessage,
              ),

            const SizedBox(height: 8),

            // Cancel button
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Annuler',
                    style: TextStyle(
                      fontSize: 16,
                      color: context.textSecondaryColor,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final Widget icon;
  final String title;
  final String subtitle;
  final bool isDestructive;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.isDestructive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? Colors.red : context.textPrimaryColor;

    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: (isDestructive ? Colors.red : context.adaptivePrimaryColor)
              .withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: icon,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: context.textTertiaryColor),
      ),
      onTap: onTap,
    );
  }
}

class _ReportDialog extends StatefulWidget {
  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  String? _selectedReason;

  final List<Map<String, String>> _reasons = [
    {'value': 'spam', 'label': 'Spam'},
    {'value': 'harassment', 'label': 'Harcèlement'},
    {'value': 'inappropriate', 'label': 'Contenu inapproprié'},
    {'value': 'violence', 'label': 'Violence ou menaces'},
    {'value': 'other', 'label': 'Autre'},
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.surfaceColor,
      title: Text(
        'Signaler le message',
        style: TextStyle(color: context.textPrimaryColor),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Motif du signalement :',
            style: TextStyle(color: context.textSecondaryColor),
          ),
          const SizedBox(height: 16),
          RadioGroup<String>(
            groupValue: _selectedReason,
            onChanged: (value) => setState(() => _selectedReason = value),
            child: Column(
              children: _reasons
                  .map(
                    (reason) => RadioListTile<String>(
                      title: Text(
                        reason['label']!,
                        style: TextStyle(color: context.textPrimaryColor),
                      ),
                      value: reason['value']!,
                      activeColor: context.adaptivePrimaryColor,
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Annuler',
            style: TextStyle(color: context.textSecondaryColor),
          ),
        ),
        ElevatedButton(
          onPressed:
              _selectedReason != null
                  ? () => Navigator.pop(context, _selectedReason)
                  : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: context.adaptivePrimaryColor,
          ),
          child: const Text('Envoyer'),
        ),
      ],
    );
  }
}
