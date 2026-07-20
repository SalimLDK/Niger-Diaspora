import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../../../../core/services/shared_media_service.dart';
import '../../../../core/theme/adaptive_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../domain/entities/conversation_entity.dart';
import '../../domain/entities/message_entity.dart';
import '../providers/message_provider.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';

/// Screen that lets the user choose a conversation to send shared media/text to.
///
/// Should be opened as a modal bottom sheet or pushed via GoRouter when content
/// is received from another app through receive_sharing_intent.
class ShareToConversationScreen extends ConsumerStatefulWidget {
  final List<SharedMediaFile> mediaFiles;

  const ShareToConversationScreen({super.key, required this.mediaFiles});

  /// Show the screen as a modal bottom sheet.
  /// Returns true if at least one item was shared successfully.
  static Future<bool?> show(
    BuildContext context, {
    required List<SharedMediaFile> mediaFiles,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ShareToConversationScreen(mediaFiles: mediaFiles),
    );
  }

  @override
  ConsumerState<ShareToConversationScreen> createState() =>
      _ShareToConversationScreenState();
}

class _ShareToConversationScreenState
    extends ConsumerState<ShareToConversationScreen> {
  String _searchQuery = '';
  String? _sendingToConversationId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final conversationsAsync = ref.watch(conversationsProvider);
    final currentUser = ref.watch(currentUserProvider).valueOrNull;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.textTertiaryColor.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                AppIcon(AppIcon.share, color: context.adaptivePrimaryColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.shareToConversation,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: context.textPrimaryColor,
                        ),
                      ),
                      Text(
                        l10n.sharedFromAnotherApp,
                        style: TextStyle(
                          fontSize: 11,
                          color: context.textTertiaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                _SharedMediaBadge(files: widget.mediaFiles),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Preview of shared content
          _SharedMediaPreview(files: widget.mediaFiles),
          const SizedBox(height: 12),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: l10n.searchConversation,
                prefixIcon: AppIcon(AppIcon.search,
                  color: context.textTertiaryColor,
                ),
                filled: true,
                fillColor: context.surfaceVariantColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Conversation list
          Expanded(
            child: conversationsAsync.when(
              data: (conversations) {
                final filtered =
                    conversations.where((conv) {
                      if (_searchQuery.isEmpty) return true;
                      final name = conv.name?.toLowerCase() ?? '';
                      return name.contains(_searchQuery.toLowerCase());
                    }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      l10n.noConversationFound,
                      style: TextStyle(color: context.textSecondaryColor),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final conversation = filtered[index];
                    final isLoading =
                        _sendingToConversationId == conversation.id;

                    return _ConversationTile(
                      conversation: conversation,
                      currentUserId: currentUser?.id,
                      isLoading: isLoading,
                      onTap: () => _shareTo(conversation),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error:
                  (_, __) => Center(
                    child: Text(
                      l10n.loadingError,
                      style: TextStyle(color: context.textSecondaryColor),
                    ),
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _shareTo(ConversationEntity conversation) async {
    if (_sendingToConversationId != null) return;

    setState(() {
      _sendingToConversationId = conversation.id;
    });

    final l10n = AppLocalizations.of(context)!;
    final sendNotifier = ref.read(sendMessageProvider.notifier);
    int successCount = 0;

    try {
      for (final file in widget.mediaFiles) {
        if (file.isText) {
          final text = file.sharedText ?? file.path;
          if (text.isNotEmpty) {
            final ok = await sendNotifier.sendText(
              conversationId: conversation.id,
              content: text,
            );
            if (ok) successCount++;
          }
        } else {
          final path = file.localPath;
          if (path.isEmpty || !File(path).existsSync()) continue;

          final localFile = File(path);
          MessageType type;
          if (file.isImage) {
            type = MessageType.image;
          } else if (file.isVideo) {
            type = MessageType.video;
          } else {
            type = MessageType.file;
          }

          final ok = await sendNotifier.sendFile(
            conversationId: conversation.id,
            file: localFile,
            type: type,
            caption: file.message?.isNotEmpty == true ? file.message : null,
          );
          if (ok) successCount++;
        }
      }

      if (mounted) {
        Navigator.of(context).pop(successCount > 0);

        final allSuccess = successCount == widget.mediaFiles.length;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              allSuccess
                  ? l10n.sharedContentSent
                  : l10n.someSharedContentNotSent,
            ),
            backgroundColor:
                allSuccess ? context.adaptivePrimaryColor : Colors.orange,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.shareError),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _sendingToConversationId = null;
        });
      }
    }
  }
}

class _SharedMediaBadge extends StatelessWidget {
  final List<SharedMediaFile> files;

  const _SharedMediaBadge({required this.files});

  @override
  Widget build(BuildContext context) {
    final count = files.length;
    final firstIsText = files.firstOrNull?.isText ?? false;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: context.adaptivePrimaryColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        firstIsText
            ? AppLocalizations.of(context)!.sharedTextCount
            : AppLocalizations.of(context)!.sharedFileCount(count),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: context.adaptivePrimaryColor,
        ),
      ),
    );
  }
}

class _SharedMediaPreview extends StatelessWidget {
  final List<SharedMediaFile> files;

  const _SharedMediaPreview({required this.files});

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) return const SizedBox.shrink();

    final first = files.first;
    final isText = first.isText;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.surfaceVariantColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildThumbnail(context, first),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isText
                      ? first.sharedText ?? ''
                      : first.path.split('/').last,
                  style: TextStyle(
                    fontSize: 14,
                    color: context.textPrimaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: isText ? 4 : 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (files.length > 1)
                  Text(
                    AppLocalizations.of(context)!.sharedFileCount(files.length - 1),
                    style: TextStyle(
                      fontSize: 12,
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

  Widget _buildThumbnail(BuildContext context, SharedMediaFile file) {
    if (file.isImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(file.localPath),
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _FallbackIcon(type: file.type),
        ),
      );
    }

    if (file.isText) {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: context.adaptivePrimaryColor.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.short_text, color: context.adaptivePrimaryColor),
      );
    }

    return _FallbackIcon(type: file.type);
  }
}

class _FallbackIcon extends StatelessWidget {
  final SharedMediaType type;

  const _FallbackIcon({required this.type});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    switch (type) {
      case SharedMediaType.video:
        icon = Icons.videocam;
      case SharedMediaType.file:
        icon = Icons.insert_drive_file;
      case SharedMediaType.image:
        icon = Icons.image;
      case SharedMediaType.text:
      case SharedMediaType.url:
        icon = Icons.short_text;
    }

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: context.adaptiveSecondaryColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: context.adaptiveSecondaryColor),
    );
  }
}

class _ConversationTile extends ConsumerWidget {
  final ConversationEntity conversation;
  final String? currentUserId;
  final bool isLoading;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.conversation,
    required this.currentUserId,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String displayName = conversation.name ?? 'Conversation';
    String? avatarUrl = conversation.imageUrl;

    if (conversation.isIndividual && currentUserId != null) {
      final otherUserId = conversation.getOtherParticipantId(currentUserId!);
      final otherUser = ref.watch(userStreamProvider(otherUserId)).valueOrNull;
      if (otherUser != null) {
        displayName = otherUser.displayName ?? displayName;
        avatarUrl = otherUser.photoUrl ?? avatarUrl;
      }
    }

    return ListTile(
      onTap: isLoading ? null : onTap,
      leading: CircleAvatar(
        radius: 24,
        backgroundColor:
            conversation.isGroup
                ? context.adaptiveSecondaryColor.withValues(alpha: 0.2)
                : context.adaptivePrimaryColor.withValues(alpha: 0.2),
        backgroundImage:
            avatarUrl != null && avatarUrl.isNotEmpty
                ? CachedNetworkImageProvider(avatarUrl)
                : null,
        child:
            avatarUrl == null || avatarUrl.isEmpty
                ? (conversation.isGroup
                    ? AppIcon(
                      AppIcon.groups,
                      color: context.adaptiveSecondaryColor,
                    )
                    : AppIcon(
                      AppIcon.person,
                      color: context.adaptivePrimaryColor,
                    ))
                : null,
      ),
      title: Text(
        displayName,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: context.textPrimaryColor,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        conversation.isGroup ? 'Groupe' : 'Message privé',
        style: TextStyle(fontSize: 13, color: context.textSecondaryColor),
      ),
      trailing:
          isLoading
              ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.adaptivePrimaryColor,
                ),
              )
              : AppIcon(AppIcon.send, size: 20, color: context.adaptivePrimaryColor),
    );
  }
}
