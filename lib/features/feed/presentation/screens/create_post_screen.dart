import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import '../../../../core/services/image_upload_service.dart';
import '../../../../core/services/video_upload_service.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../domain/entities/post_entity.dart';
import '../providers/feed_provider.dart';
import '../theme/feed_text.dart';
import '../theme/feed_tokens.dart';
import '../widgets/feed_avatar.dart';
import '../widgets/hashtag_highlighting_controller.dart';
import '../widgets/feed_toast.dart';
import '../widgets/mention_text_field.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';

class CreatePostScreen extends ConsumerStatefulWidget {
  /// Si non null, l'écran est en mode édition et préremplit ce post.
  final PostEntity? editingPost;

  const CreatePostScreen({super.key, this.editingPost});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _contentController = HashtagHighlightingController();
  final _uploadService = ImageUploadService();
  final _videoUploadService = VideoUploadService();

  final List<File> _selectedFiles = [];

  /// Vidéo sélectionnée (mutuellement exclusive avec les images).
  File? _selectedVideo;

  /// Médias déjà uploadés (mode édition) : URLs distantes, supprimables.
  final List<String> _existingMediaUrls = [];
  List<MentionedUser> _mentionedUsers = [];
  List<MentionedGroup> _mentionedGroups = [];
  List<String> _hashtags = [];
  bool _isPublishing = false;

  /// Passe à `true` juste avant de quitter l'écran après une publication
  /// réussie : évite de re-sauvegarder le texte publié comme brouillon dans
  /// `dispose()`.
  bool _didPublish = false;

  bool get _isEditing => widget.editingPost != null;

  /// Un post vidéo n'autorise pas l'ajout/suppression d'images en édition.
  bool get _isVideoPost =>
      widget.editingPost?.mediaType == PostMediaType.video;

  @override
  void initState() {
    super.initState();
    final post = widget.editingPost;
    if (post != null) {
      _contentController.text = post.content;
      _mentionedUsers = List.of(post.mentionedUsers);
      _mentionedGroups = List.of(post.mentionedGroups);
      _hashtags = List.of(post.hashtags);
      _existingMediaUrls.addAll(post.mediaUrls);
    } else {
      // Nouvelle publication : reprend le brouillon local s'il y en a un
      // (carte « Brouillons » de Mon espace, §5a).
      final draft = ref.read(postDraftProvider);
      if (draft != null && draft.isNotEmpty) {
        _contentController.text = draft;
      }
    }
  }

  @override
  void dispose() {
    // Quitter sans publier sauvegarde le texte en brouillon (édition d'un
    // post existant exclue : ce n'est pas un brouillon de nouvelle publication).
    if (!_isEditing && !_didPublish) {
      ref.read(postDraftProvider.notifier).save(_contentController.text);
    }
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final result =
        await _uploadService.pickMultipleImagesWithResult(maxImages: 5);
    if (result.files.isNotEmpty) {
      setState(() {
        _selectedVideo = null; // exclusivité images/vidéo
        _selectedFiles.addAll(result.files);
        if (_selectedFiles.length > 5) {
          _selectedFiles.removeRange(5, _selectedFiles.length);
        }
      });
    }
  }

  Future<void> _pickVideo() async {
    final result = await _videoUploadService.pickVideoFromGallery();
    if (!mounted) return;
    if (result.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage!),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (result.isSuccess) {
      setState(() {
        _selectedFiles.clear(); // exclusivité images/vidéo
        _selectedVideo = result.file;
      });
    }
  }

  Future<void> _publish() async {
    final content = _contentController.text.trim();
    if (content.isEmpty &&
        _selectedFiles.isEmpty &&
        _existingMediaUrls.isEmpty &&
        _selectedVideo == null) {
      return;
    }

    setState(() => _isPublishing = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isPublishing = false);
      return;
    }

    // Upload des nouveaux fichiers image sélectionnés.
    final List<String> uploadedUrls = [];
    for (final file in _selectedFiles) {
      final tempPostId = DateTime.now().millisecondsSinceEpoch.toString();
      final url = await _uploadService.uploadImage(
        file: file,
        type: ImageUploadType.post,
        id: tempPostId,
      );
      if (url != null) uploadedUrls.add(url);
    }

    // Always extract hashtags from final content as source of truth
    final finalHashtags = extractHashtags(content);
    final hashtags = finalHashtags.isNotEmpty ? finalHashtags : _hashtags;

    final bool success;
    if (_isEditing) {
      final editing = widget.editingPost!;
      // Post vidéo : on préserve le média existant, sinon on fusionne
      // médias conservés + nouveaux uploads.
      final List<String> finalUrls = _isVideoPost
          ? editing.mediaUrls
          : [..._existingMediaUrls, ...uploadedUrls];
      final PostMediaType finalType = _isVideoPost
          ? PostMediaType.video
          : (finalUrls.isEmpty ? PostMediaType.none : PostMediaType.images);

      final post = editing.copyWith(
        content: content,
        mediaUrls: finalUrls,
        mediaType: finalType,
        mentionedUsers: _mentionedUsers,
        mentionedGroups: _mentionedGroups,
        hashtags: hashtags,
        updatedAt: DateTime.now(),
      );
      success = await ref.read(feedNotifierProvider.notifier).updatePost(post);
    } else {
      // Upload vidéo le cas échéant (mutuellement exclusif avec les images).
      List<String> finalUrls = uploadedUrls;
      PostMediaType finalType =
          uploadedUrls.isNotEmpty ? PostMediaType.images : PostMediaType.none;
      String? videoThumb;
      int? videoDur;
      if (_selectedVideo != null) {
        final tempId = DateTime.now().millisecondsSinceEpoch.toString();
        final res = await _videoUploadService.uploadPostVideo(
          file: _selectedVideo!,
          postId: tempId,
        );
        if (res != null) {
          finalUrls = [res.videoUrl];
          finalType = PostMediaType.video;
          videoThumb = res.thumbnailUrl;
          videoDur = res.durationSeconds;
        }
      }

      final profileAsync = ref.read(profileNotifierProvider(user.uid));
      final authorCountry =
          profileAsync.whenOrNull(data: (p) => p?.currentCountry);
      final authorCity =
          profileAsync.whenOrNull(data: (p) => p?.currentCity);

      final now = DateTime.now();
      final post = PostEntity(
        id: '',
        authorId: user.uid,
        authorName: user.displayName ?? user.email ?? 'Utilisateur',
        authorPhotoUrl: user.photoURL,
        content: content,
        mediaUrls: finalUrls,
        mediaType: finalType,
        createdAt: now,
        updatedAt: now,
        mentionedUsers: _mentionedUsers,
        mentionedGroups: _mentionedGroups,
        hashtags: hashtags,
        authorCountry: authorCountry,
        authorCity: authorCity,
        videoThumbnailUrl: videoThumb,
        videoDurationSeconds: videoDur,
      );
      success = await ref.read(feedNotifierProvider.notifier).createPost(post);
    }

    if (success && !_isEditing) {
      _didPublish = true;
      await ref.read(postDraftProvider.notifier).clear();
    }

    if (mounted) {
      setState(() => _isPublishing = false);
      if (success) {
        if (!_isEditing) showFeedToast(context, 'Publication créée');
        context.pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.publishError),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Feuille d'audience : les publications sont toujours publiques (aucune
  /// portée privée au modèle), la feuille explique donc la conséquence.
  void _showAudienceSheet(BuildContext context, FeedTokens tokens) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: tokens.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: tokens.divider,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  AppIcon(AppIcon.public, size: 20, color: tokens.accent),
                  const SizedBox(width: 10),
                  Text(
                    'Public',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: tokens.text,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Cette publication sera visible par toute la diaspora sur '
                'Diaspo Niger.',
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.5,
                  color: tokens.mutedText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final user = FirebaseAuth.instance.currentUser;
    final tokens = FeedTokens.of(context);
    // Coloration live des #hashtags / @mentions dans la saisie (§13).
    _contentController.highlightColor = tokens.hashtagColor;

    return Scaffold(
      backgroundColor: tokens.bg,
      appBar: AppBar(
        backgroundColor: tokens.bg,
        elevation: 0,
        leading: TextButton(
          onPressed: _isPublishing ? null : () => context.pop(),
          child: Text(l10n.cancel, style: TextStyle(color: tokens.accent)),
        ),
        leadingWidth: 88,
        title: Text(
          _isEditing ? l10n.editPostTitle : l10n.createPost,
          style: FeedText.heading(tokens, size: 16),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: tokens.accent),
              onPressed: _isPublishing ? null : _publish,
              child: _isPublishing
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: tokens.onAccent,
                      ),
                    )
                  : Text(_isEditing ? l10n.saveChanges : l10n.publishPost),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      FeedAvatar(
                        name: user?.displayName ?? '',
                        photoUrl: user?.photoURL,
                        tokens: tokens,
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.displayName ?? '',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14.5,
                              color: tokens.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          // Puce d'audience : icône + « Public » + chevron.
                          // Les posts sont toujours publics ; le tap explique
                          // la portée (aucune audience privée au modèle).
                          GestureDetector(
                            onTap: () => _showAudienceSheet(context, tokens),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: tokens.tagNeutralBg,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AppIcon(
                                    AppIcon.public,
                                    size: 13,
                                    color: tokens.tagNeutralFg,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Public',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: tokens.tagNeutralFg,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    size: 16,
                                    color: tokens.tagNeutralFg,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  MentionTextField(
                    controller: _contentController,
                    hintText: l10n.postPlaceholder,
                    maxLines: null,
                    style: TextStyle(fontSize: 16, height: 1.6, color: tokens.text),
                    decoration: InputDecoration(
                      hintText: l10n.postPlaceholder,
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: tokens.mutedText),
                    ),
                    onTagsChanged: (users, groups, hashtags) {
                      _mentionedUsers = users;
                      _mentionedGroups = groups;
                      _hashtags = hashtags;
                    },
                  ),
                  if (!_isVideoPost &&
                      (_existingMediaUrls.length + _selectedFiles.length) > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '${_existingMediaUrls.length + _selectedFiles.length}/5',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: tokens.mutedText,
                        ),
                      ),
                    ),
                  if (_existingMediaUrls.isNotEmpty && !_isVideoPost) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 90,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _existingMediaUrls.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          return Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  _existingMediaUrls[index],
                                  width: 90,
                                  height: 90,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 90,
                                    height: 90,
                                    color: Colors.grey.shade300,
                                    child: const Icon(Icons.broken_image),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () => setState(
                                    () => _existingMediaUrls.removeAt(index),
                                  ),
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const AppIcon(AppIcon.close,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                  if (_selectedFiles.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 90,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _selectedFiles.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          return Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  _selectedFiles[index],
                                  width: 90,
                                  height: 90,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () => setState(
                                    () => _selectedFiles.removeAt(index),
                                  ),
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const AppIcon(AppIcon.close,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                  if (_selectedVideo != null) ...[
                    const SizedBox(height: 12),
                    Stack(
                      children: [
                        Container(
                          height: 160,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.play_circle_outline,
                              color: Colors.white70,
                              size: 48,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedVideo = null),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const AppIcon(AppIcon.close,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppIcon(AppIcon.public, size: 14, color: tokens.mutedText),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Les publications publiques sont visibles par toute la diaspora.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: tokens.mutedText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: tokens.divider)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.photo_library_outlined, color: tokens.accent),
                    tooltip: l10n.addMedia,
                    onPressed:
                        (_isPublishing || _isVideoPost) ? null : _pickImages,
                  ),
                  IconButton(
                    icon: AppIcon(AppIcon.video, color: tokens.accent),
                    tooltip: l10n.addVideo,
                    onPressed:
                        (_isPublishing || _isEditing) ? null : _pickVideo,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
