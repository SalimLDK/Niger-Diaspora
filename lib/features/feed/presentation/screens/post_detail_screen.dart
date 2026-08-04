import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:diaspo_niger/l10n/app_localizations.dart';
import '../../domain/entities/comment_entity.dart';
import '../../domain/entities/post_entity.dart';
import '../providers/feed_provider.dart';
import '../theme/feed_text.dart';
import '../theme/feed_tokens.dart';
import '../widgets/comment_tile.dart';
import '../widgets/feed_avatar.dart';
import '../widgets/hashtag_highlighting_controller.dart';
import '../widgets/mention_text_field.dart';
import '../widgets/post_card.dart';
import '../widgets/post_card_skeleton.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';

class PostDetailScreen extends ConsumerStatefulWidget {
  final String postId;

  const PostDetailScreen({super.key, required this.postId});

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final _commentController = HashtagHighlightingController();
  final _scrollController = ScrollController();
  bool _isSending = false;
  List<MentionedUser> _commentMentions = [];
  List<MentionedGroup> _commentGroups = [];
  List<String> _commentHashtags = [];

  /// Commentaire auquel on répond (null = commentaire racine).
  CommentEntity? _replyingTo;

  /// Ids des commentaires racines dont les réponses sont dépliées.
  final Set<String> _expandedReplyIds = {};

  String get _currentUserId =>
      FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isSending) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSending = true);

    final finalHashtags = extractHashtags(text);

    // Profondeur capée à 1 : répondre à une réponse rattache à son parent racine.
    final replyTarget = _replyingTo;
    final parentId = replyTarget == null
        ? null
        : (replyTarget.parentCommentId ?? replyTarget.id);

    final comment = CommentEntity(
      id: '',
      postId: widget.postId,
      authorId: user.uid,
      authorName: user.displayName ?? user.email ?? 'Utilisateur',
      authorPhotoUrl: user.photoURL,
      content: text,
      createdAt: DateTime.now(),
      mentionedUsers: _commentMentions,
      mentionedGroups: _commentGroups,
      hashtags: finalHashtags.isNotEmpty ? finalHashtags : _commentHashtags,
      parentCommentId: parentId,
    );

    final success = await ref
        .read(commentsProvider(widget.postId).notifier)
        .addComment(widget.postId, comment);

    if (success) {
      _commentController.clear();
      // Déplie automatiquement le fil parent pour montrer la nouvelle réponse.
      if (parentId != null) {
        setState(() {
          _expandedReplyIds.add(parentId);
          _replyingTo = null;
        });
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }

    setState(() => _isSending = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final detail = ref.watch(postDetailProvider(widget.postId));
    final post = detail.post;
    final commentsState = ref.watch(commentsProvider(widget.postId));
    final tokens = FeedTokens.of(context);
    final currentUser = FirebaseAuth.instance.currentUser;
    // Coloration live des #hashtags / @mentions dans le composer (§13).
    _commentController.highlightColor = tokens.hashtagColor;

    return Scaffold(
      backgroundColor: tokens.bg,
      appBar: AppBar(
        backgroundColor: tokens.bg,
        // Repli vers l'accueil quand la pile est vide (entrée par deep link).
        leading: IconButton(
          icon: AppIcon(AppIcon.arrowBack, color: tokens.text),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
        title: Text(l10n.feedTitle, style: FeedText.heading(tokens, size: 17)),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Le post est introuvable ou en échec : on n'affiche ni squelette ni
          // commentaires, et surtout pas le composer — inviter à commenter une
          // publication qui n'existe pas n'a aucun sens.
          if (detail.status == PostDetailStatus.notFound ||
              detail.status == PostDetailStatus.failed)
            Expanded(
              child: _PostUnavailable(
                isNotFound: detail.status == PostDetailStatus.notFound,
                l10n: l10n,
                onRetry: detail.status == PostDetailStatus.failed
                    ? () => ref
                        .read(postDetailProvider(widget.postId).notifier)
                        .refresh(widget.postId)
                    : null,
                onBack: () =>
                    context.canPop() ? context.pop() : context.go('/home'),
              ),
            )
          else ...[
          Expanded(
            child: ListView(
              controller: _scrollController,
              children: [
                if (post != null)
                  PostCard(post: post, isDetail: true)
                else
                  const PostCardSkeleton(),
                if (commentsState.isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (commentsState.comments.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        l10n.noComments,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: tokens.mutedText,
                            ),
                      ),
                    ),
                  )
                else
                  ..._buildCommentWidgets(commentsState),
              ],
            ),
          ),
          if (_replyingTo != null)
            _ReplyingBanner(
              name: _replyingTo!.authorName,
              l10n: l10n,
              onCancel: () => setState(() => _replyingTo = null),
            ),
          _CommentInput(
            controller: _commentController,
            isSending: _isSending,
            onSend: _sendComment,
            avatarName: currentUser?.displayName ?? currentUser?.email ?? '',
            avatarPhotoUrl: currentUser?.photoURL,
            onTagsChanged: (users, groups, hashtags) {
              _commentMentions = users;
              _commentGroups = groups;
              _commentHashtags = hashtags;
            },
            l10n: l10n,
          ),
          ],
        ],
      ),
    );
  }

  /// Construit la liste plate des tuiles : chaque commentaire racine, suivi de
  /// ses réponses si le fil est déplié.
  List<Widget> _buildCommentWidgets(CommentsState state) {
    final notifier = ref.read(commentsProvider(widget.postId).notifier);
    final widgets = <Widget>[];
    for (final c in state.comments) {
      widgets.add(
        CommentTile(
          comment: c,
          currentUserId: _currentUserId,
          isLiked: state.likedCommentIds.contains(c.id),
          onToggleLike: () => notifier.toggleCommentLike(c.id),
          onReply: () => setState(() => _replyingTo = c),
          repliesExpanded: _expandedReplyIds.contains(c.id),
          onToggleReplies: () => setState(() {
            if (!_expandedReplyIds.remove(c.id)) _expandedReplyIds.add(c.id);
          }),
          onDelete: (id) => notifier.deleteComment(widget.postId, id),
        ),
      );
      if (_expandedReplyIds.contains(c.id)) {
        for (final r in c.replies) {
          widgets.add(
            CommentTile(
              comment: r,
              currentUserId: _currentUserId,
              isReply: true,
              isLiked: state.likedCommentIds.contains(r.id),
              onToggleLike: () => notifier.toggleCommentLike(r.id),
              onReply: () => setState(() => _replyingTo = r),
              onDelete: (id) => notifier.deleteComment(widget.postId, id),
            ),
          );
        }
      }
    }
    return widgets;
  }
}

/// État affiché quand la publication ne peut pas être montrée.
///
/// Deux cas distincts : elle n'existe pas (rien à réessayer, on propose le
/// retour au fil), ou le chargement a échoué (réessayer a du sens).
class _PostUnavailable extends StatelessWidget {
  final bool isNotFound;
  final AppLocalizations l10n;
  final VoidCallback? onRetry;
  final VoidCallback onBack;

  const _PostUnavailable({
    required this.isNotFound,
    required this.l10n,
    required this.onRetry,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = FeedTokens.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: tokens.surface,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: AppIcon(
                  isNotFound ? AppIcon.searchOff : AppIcon.refresh,
                  color: tokens.mutedText,
                  size: 32,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isNotFound ? l10n.postNotFoundTitle : l10n.postLoadFailedTitle,
              textAlign: TextAlign.center,
              style: FeedText.heading(tokens, size: 19),
            ),
            const SizedBox(height: 8),
            Text(
              isNotFound
                  ? l10n.postNotFoundMessage
                  : l10n.postLoadFailedMessage,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: tokens.mutedText),
            ),
            const SizedBox(height: 24),
            if (onRetry != null)
              FilledButton(
                onPressed: onRetry,
                child: Text(l10n.retry),
              )
            else
              FilledButton(
                onPressed: onBack,
                child: Text(l10n.backToFeed),
              ),
            if (onRetry != null)
              TextButton(
                onPressed: onBack,
                child: Text(
                  l10n.backToFeed,
                  style: TextStyle(color: tokens.mutedText),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReplyingBanner extends StatelessWidget {
  final String name;
  final AppLocalizations l10n;
  final VoidCallback onCancel;

  const _ReplyingBanner({
    required this.name,
    required this.l10n,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = FeedTokens.of(context);
    return Container(
      width: double.infinity,
      color: tokens.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(Icons.reply_rounded, size: 16, color: tokens.mutedText),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.replyingTo(name),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: tokens.mutedText),
            ),
          ),
          GestureDetector(
            onTap: onCancel,
            child: AppIcon(AppIcon.close, size: 16, color: tokens.mutedText),
          ),
        ],
      ),
    );
  }
}

class _CommentInput extends StatelessWidget {
  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;
  final String avatarName;
  final String? avatarPhotoUrl;
  final void Function(
    List<MentionedUser> users,
    List<MentionedGroup> groups,
    List<String> hashtags,
  )? onTagsChanged;
  final AppLocalizations l10n;

  const _CommentInput({
    required this.controller,
    required this.isSending,
    required this.onSend,
    required this.avatarName,
    this.avatarPhotoUrl,
    this.onTagsChanged,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = FeedTokens.of(context);
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: tokens.bg,
          border: Border(top: BorderSide(color: tokens.divider)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            FeedAvatar(
              name: avatarName,
              photoUrl: avatarPhotoUrl,
              radius: 16,
              tokens: tokens,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: MentionTextField(
                controller: controller,
                hintText: l10n.commentPlaceholder,
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: l10n.commentPlaceholder,
                  hintStyle: TextStyle(color: tokens.mutedText),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: tokens.surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                onTagsChanged: onTagsChanged,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: isSending ? null : onSend,
              icon: isSending
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: tokens.accent,
                      ),
                    )
                  : AppIcon(AppIcon.send, color: tokens.accent),
            ),
          ],
        ),
      ),
    );
  }
}
