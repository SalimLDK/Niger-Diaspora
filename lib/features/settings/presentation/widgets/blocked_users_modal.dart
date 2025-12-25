import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import '../../domain/entities/blocked_user_entity.dart';
import '../providers/blocked_users_provider.dart';
import '../../../../core/theme/adaptive_colors.dart';

class BlockedUsersModal extends ConsumerWidget {
  const BlockedUsersModal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final blockedUsersAsync = ref.watch(blockedUsersProvider);

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
                color: context.borderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l10n.blockedUsers,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: context.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 20),
          blockedUsersAsync.when(
            data:
                (users) =>
                    users.isEmpty
                        ? _buildEmptyState(context, l10n)
                        : _buildUsersList(context, ref, users, l10n),
            loading:
                () => Padding(
                  padding: const EdgeInsets.all(40),
                  child: CircularProgressIndicator(
                    color: context.adaptivePrimaryColor,
                  ),
                ),
            error:
                (error, _) => Padding(
                  padding: const EdgeInsets.all(40),
                  child: Text(
                    '${l10n.error}: $error',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppLocalizations l10n) {
    return Column(
      children: [
        const SizedBox(height: 20),
        Icon(
          Icons.block,
          size: 64,
          color: context.textTertiaryColor.withValues(alpha: 0.3),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.noBlockedUsers,
          style: TextStyle(color: context.textTertiaryColor),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildUsersList(
    BuildContext context,
    WidgetRef ref,
    List<BlockedUserEntity> users,
    AppLocalizations l10n,
  ) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.5,
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: users.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: context.borderColor),
        itemBuilder: (context, index) {
          final user = users[index];
          return _BlockedUserTile(user: user);
        },
      ),
    );
  }
}

class _BlockedUserTile extends ConsumerStatefulWidget {
  final BlockedUserEntity user;

  const _BlockedUserTile({required this.user});

  @override
  ConsumerState<_BlockedUserTile> createState() => _BlockedUserTileState();
}

class _BlockedUserTileState extends ConsumerState<_BlockedUserTile> {
  bool _isLoading = false;

  Future<void> _unblockUser() async {
    final l10n = AppLocalizations.of(context)!;
    final successMessage =
        '${widget.user.displayName} ${l10n.userUnblocked.toLowerCase()}';
    final errorMessage = l10n.error;

    setState(() => _isLoading = true);

    final success = await ref
        .read(blockUserNotifierProvider.notifier)
        .unblockUser(widget.user.id);

    if (mounted) {
      setState(() => _isLoading = false);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: context.surfaceVariantColor,
        backgroundImage:
            widget.user.photoUrl != null
                ? CachedNetworkImageProvider(widget.user.photoUrl!)
                : null,
        child:
            widget.user.photoUrl == null
                ? Text(
                  widget.user.displayName.isNotEmpty
                      ? widget.user.displayName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    color: context.adaptivePrimaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                )
                : null,
      ),
      title: Text(
        widget.user.displayName,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: context.textPrimaryColor,
        ),
      ),
      subtitle: Text(
        l10n.blockedOn(_formatDate(widget.user.blockedAt)),
        style: TextStyle(fontSize: 12, color: context.textTertiaryColor),
      ),
      trailing:
          _isLoading
              ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.adaptivePrimaryColor,
                ),
              )
              : TextButton(
                onPressed: _unblockUser,
                child: Text(
                  l10n.unblock,
                  style: TextStyle(color: context.adaptivePrimaryColor),
                ),
              ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
