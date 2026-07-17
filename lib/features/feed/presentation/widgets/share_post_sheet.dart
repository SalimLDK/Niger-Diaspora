import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:diaspo_niger/l10n/app_localizations.dart';
import '../../../../core/services/deep_link_service.dart';
import '../../../../features/messages/presentation/providers/message_provider.dart';
import '../../domain/entities/post_entity.dart';
import '../providers/feed_provider.dart';
import 'package:diaspo_niger/shared/utils/external_share.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';

class SharePostSheet extends ConsumerStatefulWidget {
  final PostEntity post;

  const SharePostSheet({super.key, required this.post});

  @override
  ConsumerState<SharePostSheet> createState() => _SharePostSheetState();
}

class _SharePostSheetState extends ConsumerState<SharePostSheet> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSending = false;
  bool _isSharingExternally = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _share(String conversationId, String conversationName) async {
    setState(() => _isSending = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isSending = false);
      return;
    }

    final preview = widget.post.content.length > 100
        ? '${widget.post.content.substring(0, 100)}…'
        : widget.post.content;

    final postData = <String, dynamic>{
      'postId': widget.post.id,
      'authorId': widget.post.authorId,
      'authorName': widget.post.authorName,
      'content': preview,
      if (widget.post.mediaUrls.isNotEmpty) 'mediaUrl': widget.post.mediaUrls.first,
    };

    await ref.read(sendMessageProvider.notifier).sendText(
          conversationId: conversationId,
          content: '📌 Post de ${widget.post.authorName}',
          postData: postData,
        );

    if (mounted) {
      setState(() => _isSending = false);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.postShared),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  String get _postLink => DeepLinkService.instance.generatePostLink(
        widget.post.id,
        authorName: widget.post.authorName,
      );

  String _buildShareText(AppLocalizations l10n) {
    final post = widget.post;
    final preview = post.content.length > 200
        ? '${post.content.substring(0, 200)}…'
        : post.content;
    return l10n.sharePostMessage(post.authorName, preview, _postLink);
  }

  /// Lance un partage externe et enregistre le partage si l'app cible
  /// s'est bien ouverte.
  Future<void> _shareExternalVia(Future<bool> Function() launcher) async {
    setState(() => _isSharingExternally = true);
    try {
      final shared = await launcher();
      if (shared) {
        unawaited(
          ref
              .read(feedNotifierProvider.notifier)
              .trackExternalShare(widget.post.id),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSharingExternally = false);
      }
    }
  }

  Future<void> _shareViaWhatsApp() {
    final text = _buildShareText(AppLocalizations.of(context)!);
    return _shareExternalVia(() => ExternalShare.whatsApp(text));
  }

  Future<void> _shareViaFacebook() {
    return _shareExternalVia(() => ExternalShare.facebook(_postLink));
  }

  Future<void> _shareViaX() {
    final text = _buildShareText(AppLocalizations.of(context)!);
    return _shareExternalVia(() => ExternalShare.x(text));
  }

  /// Feuille de partage système : seul chemin qui joint le média du post.
  Future<void> _shareViaSystem() {
    final text = _buildShareText(AppLocalizations.of(context)!);
    return _shareExternalVia(() async {
      XFile? file;
      if (widget.post.mediaUrls.isNotEmpty) {
        final downloaded = await _downloadMediaToTemp(widget.post.mediaUrls.first);
        if (downloaded != null) {
          file = XFile(downloaded.path);
        }
      }

      if (!mounted) return false;
      return ExternalShare.system(
        text: text,
        files: file != null ? [file] : null,
      );
    });
  }

  Future<File?> _downloadMediaToTemp(String url) async {
    try {
      final extension = url.split('.').last.split('?').first;
      final name = 'share_${DateTime.now().millisecondsSinceEpoch}.${extension.isNotEmpty ? extension : 'jpg'}';
      final tempDir = await getTemporaryDirectory();
      final path = '${tempDir.path}/$name';
      await Dio().download(url, path);
      final file = File(path);
      return await file.exists() ? file : null;
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final conversationsAsync = ref.watch(conversationsProvider);
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Text(
                    l10n.sharePost,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // External share section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.shareVia,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _ShareButton(
                        asset: AppIcon.whatsapp,
                        color: const Color(0xFF25D366),
                        label: l10n.shareWhatsApp,
                        onTap: _isSharingExternally ? null : _shareViaWhatsApp,
                      ),
                      _ShareButton(
                        asset: AppIcon.facebook,
                        color: const Color(0xFF1877F2),
                        label: l10n.shareFacebook,
                        onTap: _isSharingExternally ? null : _shareViaFacebook,
                      ),
                      _ShareButton(
                        asset: AppIcon.x,
                        color: theme.colorScheme.onSurface,
                        label: l10n.shareX,
                        onTap: _isSharingExternally ? null : _shareViaX,
                      ),
                      _ShareButton(
                        icon: Icons.more_horiz,
                        color: theme.colorScheme.primary,
                        label: l10n.shareMore,
                        onTap: _isSharingExternally ? null : _shareViaSystem,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: l10n.searchMembersGroups,
                  prefixIcon: const AppIcon(AppIcon.search, color: Colors.teal, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
                onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: conversationsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => Center(child: Text(l10n.feedError)),
                data: (conversations) {
                  final filtered = conversations.where((c) {
                    if (_searchQuery.isEmpty) return true;
                    final name = (c.name ?? '').toLowerCase();
                    return name.contains(_searchQuery);
                  }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(
                        l10n.feedEmpty,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: scrollController,
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final conv = filtered[index];
                      final name = conv.name ?? l10n.messages;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: conv.imageUrl != null
                              ? NetworkImage(conv.imageUrl!)
                              : null,
                          child: conv.imageUrl == null
                              ? Text(
                                  name.isNotEmpty
                                      ? name[0].toUpperCase()
                                      : '?',
                                )
                              : null,
                        ),
                        title: Text(
                          name,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: _isSending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : IconButton(
                                icon: const AppIcon(AppIcon.send,
                                  color: Colors.teal,
                                ),
                                onPressed: () => _share(conv.id, name),
                              ),
                        onTap: _isSending ? null : () => _share(conv.id, name),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ShareButton extends StatelessWidget {
  /// Icone Material (fallback) ou glyphe SVG de marque via [asset].
  final IconData? icon;
  final String? asset;
  final Color color;
  final String label;
  final VoidCallback? onTap;

  const _ShareButton({
    this.icon,
    this.asset,
    required this.color,
    required this.label,
    this.onTap,
  }) : assert(icon != null || asset != null);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: asset != null
                  ? AppIcon(asset!, color: color, size: 24)
                  : Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color:
                    onTap == null
                        ? Theme.of(context).disabledColor
                        : Theme.of(context).colorScheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
