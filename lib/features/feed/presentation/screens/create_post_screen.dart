import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:diaspo_niger/l10n/app_localizations.dart';
import '../../../../core/services/image_upload_service.dart';
import '../../../../core/services/video_upload_service.dart';
import '../../../messages/presentation/widgets/location_picker_modal.dart';
import '../../../polls/domain/entities/poll_entity.dart';
import '../../../polls/presentation/providers/poll_provider.dart';
import '../../../polls/presentation/widgets/create_poll_sheet.dart';
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

/// Ce que l'éditeur doit ouvrir à l'arrivée (amorces de l'état vide §5g).
enum ComposeIntent { blank, photo, poll }

/// Brouillon de sondage composé avant publication (le post n'a pas encore
/// d'id — voir `_publish()`).
class _PollDraft {
  final String question;
  final List<String> optionLabels;
  final bool allowMultiple;
  final DateTime? endsAt;

  const _PollDraft({
    required this.question,
    required this.optionLabels,
    required this.allowMultiple,
    this.endsAt,
  });
}

class _LocationDraft {
  final double latitude;
  final double longitude;
  final String address;

  const _LocationDraft({
    required this.latitude,
    required this.longitude,
    required this.address,
  });
}

class CreatePostScreen extends ConsumerStatefulWidget {
  /// Si non null, l'écran est en mode édition et préremplit ce post.
  final PostEntity? editingPost;

  /// Brouillon local à reprendre (carte « Brouillons », §5a/§5b). `null` pour
  /// une nouvelle publication : un brouillon est alors créé à la volée si
  /// l'utilisateur quitte l'écran sans publier.
  final String? draftId;

  /// Amorce depuis l'état vide de Mes publications (§5g) : ouvre directement
  /// le sélecteur de photos ou la feuille de sondage à l'arrivée.
  final ComposeIntent compose;

  const CreatePostScreen({
    super.key,
    this.editingPost,
    this.draftId,
    this.compose = ComposeIntent.blank,
  });

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen>
    with WidgetsBindingObserver {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  final _contentController = HashtagHighlightingController();
  final _uploadService = ImageUploadService();
  final _videoUploadService = VideoUploadService();

  final List<File> _selectedFiles = [];

  /// Vidéo sélectionnée (mutuellement exclusive avec les images).
  File? _selectedVideo;

  /// Médias déjà uploadés (mode édition) : URLs distantes, supprimables.
  final List<String> _existingMediaUrls = [];

  /// Sondage/lieu composés — mutuellement exclusifs entre eux et avec les
  /// médias (un seul type de contenu joint à la fois, §13/23d).
  _PollDraft? _pollDraft;
  _LocationDraft? _locationDraft;

  List<MentionedUser> _mentionedUsers = [];
  List<MentionedGroup> _mentionedGroups = [];
  List<String> _hashtags = [];
  bool _isPublishing = false;

  /// Passe à `true` juste avant de quitter l'écran après une publication
  /// réussie : évite de re-sauvegarder le texte publié comme brouillon dans
  /// `dispose()`.
  bool _didPublish = false;

  /// Identifiant du brouillon local associé à cet écran : celui repris à
  /// l'ouverture, ou un identifiant neuf créé pour cette session de rédaction.
  /// Chaque passage dans l'éditeur a donc le sien — deux rédactions
  /// successives ne s'écrasent plus l'une l'autre.
  late final String _draftId;

  /// Notifier des brouillons capturé à l'`initState`. **Ne pas remplacer par
  /// un `ref.read` dans `dispose()`** : `ref` n'y est plus utilisable, et
  /// comme `main.dart` renvoie `FlutterError.onError` vers Crashlytics,
  /// l'exception ne s'affiche nulle part — le brouillon disparaissait en
  /// silence.
  PostDraftsNotifier? _draftsNotifier;

  /// Sauvegarde différée pendant la frappe : le texte survit à un crash ou à
  /// un « kill » de l'app, sans écrire à chaque caractère.
  Timer? _draftDebounce;

  bool get _isEditing => widget.editingPost != null;

  /// Un post vidéo n'autorise pas l'ajout/suppression d'images en édition.
  bool get _isVideoPost =>
      widget.editingPost?.mediaType == PostMediaType.video;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final post = widget.editingPost;
    if (post != null) {
      _contentController.text = post.content;
      _mentionedUsers = List.of(post.mentionedUsers);
      _mentionedGroups = List.of(post.mentionedGroups);
      _hashtags = List.of(post.hashtags);
      _existingMediaUrls.addAll(post.mediaUrls);
      _draftId = '';
    } else {
      // Nouvelle publication : reprend le brouillon demandé s'il y en a un
      // (carte « Brouillons » de Mon espace §5a, cartes brouillon §5b).
      _draftId = widget.draftId ?? const Uuid().v4();
      _draftsNotifier = ref.read(postDraftsProvider.notifier);
      final draft = _draftsNotifier!.byId(_draftId);
      if (draft != null) {
        _contentController.text = draft.text;
      }
      _contentController.addListener(_scheduleDraftSave);
      // Amorces de §5g : on attend la première frame, sinon le sélecteur
      // s'ouvrirait avant que l'écran ne soit monté.
      if (widget.compose != ComposeIntent.blank) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          switch (widget.compose) {
            case ComposeIntent.photo:
              _pickImages();
            case ComposeIntent.poll:
              _pickPoll();
            case ComposeIntent.blank:
              break;
          }
        });
      }
    }
  }

  /// Quitter l'app par le bouton Accueil ne dépile pas l'écran : `dispose()`
  /// n'est jamais appelé et le texte serait perdu. On sauvegarde donc aussi
  /// dès que l'app passe en arrière-plan.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _persistDraft();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _draftDebounce?.cancel();
    _contentController.removeListener(_scheduleDraftSave);
    // Quitter sans publier sauvegarde le texte en brouillon (édition d'un
    // post existant exclue : ce n'est pas un brouillon de nouvelle publication).
    _persistDraft();
    _contentController.dispose();
    super.dispose();
  }

  void _scheduleDraftSave() {
    _draftDebounce?.cancel();
    _draftDebounce = Timer(
      const Duration(milliseconds: 800),
      _persistDraft,
    );
  }

  /// Un texte vide supprime le brouillon plutôt que d'en laisser un fantôme.
  void _persistDraft() {
    if (_isEditing || _didPublish) return;
    _draftsNotifier?.save(_draftId, _contentController.text);
  }

  Future<void> _pickImages() async {
    final result =
        await _uploadService.pickMultipleImagesWithResult(maxImages: 5);
    if (result.files.isNotEmpty) {
      setState(() {
        _selectedVideo = null; // exclusivité images/vidéo
        _pollDraft = null; // exclusivité média/sondage/lieu
        _locationDraft = null;
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
        _pollDraft = null; // exclusivité média/sondage/lieu
        _locationDraft = null;
        _selectedVideo = result.file;
      });
    }
  }

  void _pickPoll() {
    showCreatePollSheet(
      context,
      contextType: PollContextType.post,
      contextId: '', // ignoré : onDraft intercepte la soumission
      onDraft: (question, options, allowMultiple, endsAt) {
        setState(() {
          _selectedFiles.clear();
          _selectedVideo = null;
          _locationDraft = null;
          _pollDraft = _PollDraft(
            question: question,
            optionLabels: options,
            allowMultiple: allowMultiple,
            endsAt: endsAt,
          );
        });
      },
    );
  }

  Future<void> _pickLocation() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LocationPickerModal(
        onLocationSelected: (lat, lng, address) {
          setState(() {
            _selectedFiles.clear();
            _selectedVideo = null;
            _pollDraft = null;
            _locationDraft = _LocationDraft(
              latitude: lat,
              longitude: lng,
              address: address,
            );
          });
        },
      ),
    );
  }

  Future<void> _publish() async {
    final content = _contentController.text.trim();
    if (content.isEmpty &&
        _selectedFiles.isEmpty &&
        _existingMediaUrls.isEmpty &&
        _selectedVideo == null &&
        _pollDraft == null &&
        _locationDraft == null) {
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
    // Le sondage est cree apres le post : son echec ne doit pas passer sous
    // le toast « Publication creee », qui laisserait croire a un sondage joint.
    bool pollFailed = false;
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
        authorName: user.displayName ?? user.email ?? l10n.user,
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
        latitude: _locationDraft?.latitude,
        longitude: _locationDraft?.longitude,
        locationAddress: _locationDraft?.address,
      );
      final created =
          await ref.read(feedNotifierProvider.notifier).createPost(post);
      success = created != null;

      // Le sondage n'est créé qu'une fois le post publié (son id n'existait
      // pas avant) — voir le doc-comment de _pollDraft/showCreatePollSheet.
      if (created != null && _pollDraft != null) {
        pollFailed = null ==
            await ref.read(pollActionsNotifierProvider.notifier).createPostPoll(
              postId: created.id,
              question: _pollDraft!.question,
              optionLabels: _pollDraft!.optionLabels,
              allowMultiple: _pollDraft!.allowMultiple,
              endsAt: _pollDraft!.endsAt,
            );
      }
    }

    if (success && !_isEditing) {
      _didPublish = true;
      await ref.read(postDraftsProvider.notifier).delete(_draftId);
    }

    if (mounted) {
      setState(() => _isPublishing = false);
      if (success) {
        if (!_isEditing) {
          showFeedToast(
            context,
            pollFailed
                ? "Publication créée, mais le sondage n'a pas pu être joint"
                : 'Publication créée',
          );
        }
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
                    l10n.public,
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
                                    l10n.public,
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
                  if (_pollDraft != null) ...[
                    const SizedBox(height: 12),
                    _AttachmentPreview(
                      tokens: tokens,
                      icon: Icons.poll_outlined,
                      label:
                          '${_pollDraft!.question} · ${_pollDraft!.optionLabels.length} options',
                      onRemove: () => setState(() => _pollDraft = null),
                    ),
                  ],
                  if (_locationDraft != null) ...[
                    const SizedBox(height: 12),
                    _AttachmentPreview(
                      tokens: tokens,
                      icon: Icons.location_on_outlined,
                      label: _locationDraft!.address,
                      onRemove: () => setState(() => _locationDraft = null),
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
                  // Sondage / Lieu (§13/23d) : un seul type de contenu joint
                  // à la fois, uniquement pour une nouvelle publication (le
                  // sondage a besoin de l'id du post, pas encore créé en
                  // édition).
                  IconButton(
                    icon: AppIcon(AppIcon.poll, color: tokens.accent),
                    tooltip: l10n.pollLabel,
                    onPressed: (_isPublishing || _isEditing) ? null : _pickPoll,
                  ),
                  IconButton(
                    icon: Icon(Icons.location_on_outlined, color: tokens.accent),
                    tooltip: l10n.feedPlaceLabel,
                    onPressed:
                        (_isPublishing || _isEditing) ? null : _pickLocation,
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

/// Puce de prévisualisation du sondage/lieu composé, avec retrait — même
/// esprit que les vignettes média déjà présentes.
class _AttachmentPreview extends StatelessWidget {
  final FeedTokens tokens;
  final IconData icon;
  final String label;
  final VoidCallback onRemove;

  const _AttachmentPreview({
    required this.tokens,
    required this.icon,
    required this.label,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.divider),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: tokens.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13.5, color: tokens.text),
            ),
          ),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close_rounded, size: 18, color: tokens.mutedText),
          ),
        ],
      ),
    );
  }
}
