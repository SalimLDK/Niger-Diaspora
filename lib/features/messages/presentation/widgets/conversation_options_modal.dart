import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../../settings/presentation/providers/blocked_users_provider.dart';
import '../providers/conversation_actions_provider.dart';

class ConversationOptionsModal extends ConsumerStatefulWidget {
  final String conversationId;
  final String? otherUserId;
  final String? otherUserName;
  final String? otherUserPhotoUrl;
  final bool isMuted;
  final bool isArchived;
  final bool isGroup;
  final bool isAdmin;
  final VoidCallback? onChangeBackground;

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
    this.onChangeBackground,
  });

  @override
  ConsumerState<ConversationOptionsModal> createState() =>
      _ConversationOptionsModalState();
}

class _ConversationOptionsModalState
    extends ConsumerState<ConversationOptionsModal> {
  bool _isLoading = false;

  Future<void> _muteConversation() async {
    setState(() => _isLoading = true);

    final success = await ref
        .read(conversationActionsNotifierProvider.notifier)
        .muteConversation(widget.conversationId, !widget.isMuted);

    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? (widget.isMuted
                    ? 'Notifications réactivées'
                    : 'Conversation mise en sourdine')
                : 'Erreur',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _archiveConversation() async {
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
                    ? 'Conversation désarchivée'
                    : 'Conversation archivée')
                : 'Erreur',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteConversation() async {
    String deleteType = 'me'; // Default to soft delete

    if (widget.isAdmin) {
      final choice = await showDialog<String>(
        context: context,
        builder:
            (context) => SimpleDialog(
              title: const Text('Supprimer la conversation'),
              children: [
                SimpleDialogOption(
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 24,
                  ),
                  onPressed: () => Navigator.pop(context, 'me'),
                  child: const Text('Supprimer pour moi'),
                ),
                SimpleDialogOption(
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 24,
                  ),
                  onPressed: () => Navigator.pop(context, 'all'),
                  child: const Text(
                    'Supprimer pour tout le monde',
                    style: TextStyle(color: Colors.red),
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
              title: const Text('Supprimer la conversation'),
              content: const Text(
                'Voulez-vous vraiment supprimer cette conversation ? Cette action est irréversible pour vous.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Supprimer'),
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

    // ... existing success handling ...

    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.pop(context);

      if (success) {
        context.pop(); // Go back from conversation screen
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Conversation supprimée'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de la suppression'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _blockUser() async {
    if (widget.otherUserId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Bloquer l\'utilisateur'),
            content: Text(
              'Voulez-vous vraiment bloquer ${widget.otherUserName ?? 'cet utilisateur'} ? '
              'Vous ne recevrez plus de messages de sa part.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Bloquer'),
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
          targetDisplayName: widget.otherUserName ?? 'Utilisateur',
          targetPhotoUrl: widget.otherUserPhotoUrl,
        );

    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Utilisateur bloqué' : 'Erreur lors du blocage',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _reportConversation() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => _ReportDialog(),
    );

    if (reason == null || !mounted) return;

    setState(() => _isLoading = true);

    final success =
        widget.isGroup
            ? await ref
                .read(conversationActionsNotifierProvider.notifier)
                .reportGroup(
                  conversationId: widget.conversationId,
                  reason: reason,
                )
            : await ref
                .read(conversationActionsNotifierProvider.notifier)
                .reportConversation(
                  conversationId: widget.conversationId,
                  reason: reason,
                );

    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Signalement envoyé' : 'Erreur lors du signalement',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Options de la conversation',
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
            _buildOption(
              icon:
                  widget.isMuted
                      ? Icons.notifications_active
                      : Icons.notifications_off,
              title:
                  widget.isMuted
                      ? 'Réactiver les notifications'
                      : 'Mettre en sourdine',
              onTap: _muteConversation,
            ),
            _buildOption(
              icon: widget.isArchived ? Icons.unarchive : Icons.archive,
              title: widget.isArchived ? 'Désarchiver' : 'Archiver',
              onTap: _archiveConversation,
            ),
            if (widget.onChangeBackground != null)
              _buildOption(
                icon: Icons.wallpaper_outlined,
                title: 'Changer le fond d\'écran',
                onTap: () {
                  Navigator.pop(context);
                  widget.onChangeBackground?.call();
                },
              ),
            _buildOption(
              icon: Icons.delete_outline,
              title: 'Supprimer la conversation',
              onTap: _deleteConversation,
              isDestructive: true,
            ),
            if (!widget.isGroup && widget.otherUserId != null) ...[
              const Divider(),
              _buildOption(
                icon: Icons.block,
                title: 'Bloquer l\'utilisateur',
                onTap: _blockUser,
                isDestructive: true,
              ),
            ],
            const Divider(),
            _buildOption(
              icon: Icons.flag_outlined,
              title: 'Signaler',
              onTap: _reportConversation,
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final color = isDestructive ? Colors.red : context.textPrimaryColor;

    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? Colors.red : context.adaptivePrimaryColor,
      ),
      title: Text(title, style: TextStyle(color: color)),
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
    {'value': 'other', 'label': 'Autre'},
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Signaler'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Motif du signalement :'),
          const SizedBox(height: 16),
          ..._reasons.map(
            (reason) => RadioListTile<String>(
              title: Text(reason['label']!),
              value: reason['value']!,
              groupValue: _selectedReason,
              onChanged: (value) => setState(() => _selectedReason = value),
              activeColor: context.adaptivePrimaryColor,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
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
