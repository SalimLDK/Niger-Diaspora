import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/image_upload_service.dart';
import '../../../core/services/video_upload_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../feed/presentation/theme/feed_tokens.dart';
import '../../profile/presentation/providers/profile_provider.dart';
import '../domain/entities/story_entity.dart';
import 'providers/story_provider.dart';

/// Pictogramme d'une audience de story.
IconData storyAudienceIcon(StoryAudience audience) => switch (audience) {
      StoryAudience.everyone => Icons.public_rounded,
      StoryAudience.followers => Icons.person_add_alt_1_rounded,
      StoryAudience.friends => Icons.people_alt_rounded,
      StoryAudience.closeList => Icons.stars_rounded,
    };

String _audienceHint(StoryAudience audience) => switch (audience) {
      StoryAudience.everyone => 'Tous les membres, sauf ceux que vous masquez.',
      StoryAudience.followers =>
        'Les personnes qui vous suivent, et vos amis.',
      StoryAudience.friends => 'Vos amis seulement.',
      StoryAudience.closeList =>
        'Seulement les personnes de votre liste restreinte.',
    };

/// Feuille « Qui peut voir ma story ? ». Renvoie l'audience choisie, ou
/// `null` si la feuille est fermée sans choix.
Future<StoryAudience?> showStoryAudienceSheet(
  BuildContext context, {
  required StoryAudience current,
  bool showManageLink = true,
}) {
  final tokens = FeedTokens.of(context);
  return showModalBottomSheet<StoryAudience>(
    context: context,
    backgroundColor: tokens.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
            child: Text(
              'Qui peut voir ma story ?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: tokens.text,
              ),
            ),
          ),
          for (final a in StoryAudience.values)
            ListTile(
              leading: Icon(
                storyAudienceIcon(a),
                color: a == current ? tokens.accent : tokens.mutedText,
              ),
              title: Text(
                a.label,
                style: TextStyle(fontWeight: FontWeight.w600, color: tokens.text),
              ),
              subtitle: Text(
                _audienceHint(a),
                style: TextStyle(fontSize: 12.5, color: tokens.mutedText),
              ),
              trailing: a == current
                  ? Icon(Icons.check_rounded, color: tokens.accent)
                  : null,
              onTap: () => Navigator.pop(sheetContext, a),
            ),
          if (showManageLink)
          ListTile(
            leading: Icon(Icons.tune_rounded, color: tokens.mutedText),
            title: Text(
              'Gérer la liste restreinte et les personnes masquées',
              style: TextStyle(fontSize: 13.5, color: tokens.text),
            ),
            trailing: Icon(Icons.chevron_right, color: tokens.mutedText),
            onTap: () {
              Navigator.pop(sheetContext);
              context.push('/feed/stories/privacy');
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// Publier une story : choix du média, de l'audience, envoi.
///
/// Partagé par le rail (« + » de mon avatar) et par le viewer (« Ajouter »
/// sur ma propre story) : on ne pouvait publier qu'une story, l'avatar
/// ouvrant le viewer dès qu'il en existait une.
///
/// Chaque échec est dit. Il était avalé à toutes les étapes — sélection,
/// envoi du média, écriture — et une story ratée ne se distinguait pas d'un
/// appui sans effet.
Future<void> startStoryCreation(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final tokens = FeedTokens.of(context);
  // Le conteneur, pas `ref` : l'envoi du média dure, et le widget appelant
  // (avatar du rail, viewer) peut être démonté entre-temps — un `ref` de
  // widget démonté lève, et l'exception partirait dans Crashlytics sans rien
  // afficher.
  final container = ProviderScope.containerOf(context, listen: false);

  final choice = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: tokens.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Consumer(
        builder: (context, ref, _) {
          final audience = ref.watch(storyDefaultAudienceProvider);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.photo_camera_outlined, color: tokens.accent),
                title: Text(l10n.storyTakePhoto),
                onTap: () => Navigator.pop(sheetContext, 'camera'),
              ),
              ListTile(
                leading:
                    Icon(Icons.photo_library_outlined, color: tokens.accent),
                title: Text(l10n.storyChooseFromGallery),
                onTap: () => Navigator.pop(sheetContext, 'gallery'),
              ),
              ListTile(
                leading: Icon(Icons.videocam_outlined, color: tokens.accent),
                title: Text(l10n.storyChooseVideo),
                subtitle: Text(
                  l10n.storyVideoMaxDuration,
                  style: TextStyle(fontSize: 12, color: tokens.mutedText),
                ),
                onTap: () => Navigator.pop(sheetContext, 'video'),
              ),
              Divider(height: 1, color: tokens.divider),
              ListTile(
                leading:
                    Icon(storyAudienceIcon(audience), color: tokens.mutedText),
                title: Text(
                  'Qui peut voir : ${audience.label}',
                  style: TextStyle(fontWeight: FontWeight.w600, color: tokens.text),
                ),
                trailing: Icon(Icons.chevron_right, color: tokens.mutedText),
                onTap: () async {
                  final picked = await showStoryAudienceSheet(
                    context,
                    current: audience,
                  );
                  if (picked != null) {
                    await ref.read(storyDefaultAudienceProvider.notifier).set(picked);
                  }
                },
              ),
            ],
          );
        },
      ),
    ),
  );
  if (choice == null || !context.mounted) return;

  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  final messenger = ScaffoldMessenger.of(context);
  final audience = container.read(storyDefaultAudienceProvider);
  final profile = container.read(profileNotifierProvider(user.uid)).valueOrNull;
  final authorName = profile?.displayName ?? user.displayName ?? l10n.you;
  final authorPhotoUrl = profile?.photoUrl ?? user.photoURL;
  final notifier = container.read(storyActionsNotifierProvider.notifier);
  final tempId = DateTime.now().millisecondsSinceEpoch.toString();

  void dire(String message, {bool erreur = false}) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: erreur ? Colors.red : null,
        ),
      );
  }

  String? echec;
  if (choice == 'video') {
    final videoService = VideoUploadService();
    final pick = await videoService.pickVideoFromGallery(
      maxDuration: const Duration(seconds: 30),
    );
    if (!pick.isSuccess || pick.file == null) return;
    dire('Publication de la story…');
    final upload = await videoService.uploadStoryVideo(
      file: pick.file!,
      storyId: tempId,
    );
    if (upload == null) {
      dire("La vidéo n'a pas pu être envoyée.", erreur: true);
      return;
    }
    echec = await notifier.createStory(
      authorId: user.uid,
      authorName: authorName,
      authorPhotoUrl: authorPhotoUrl,
      mediaUrl: upload.videoUrl,
      mediaType: StoryMediaType.video,
      videoDurationSeconds: upload.durationSeconds,
      audience: audience,
    );
  } else {
    final uploadService = ImageUploadService();
    final result = choice == 'camera'
        ? await uploadService.pickImageFromCameraWithResult()
        : await uploadService.pickImageFromGalleryWithResult();
    if (result.permissionDenied) {
      dire(
        choice == 'camera'
            ? "L'accès à l'appareil photo est refusé."
            : "L'accès aux photos est refusé.",
        erreur: true,
      );
      return;
    }
    if (!result.isSuccess || result.file == null) return;
    dire('Publication de la story…');
    final url = await uploadService.uploadImage(
      file: result.file!,
      type: ImageUploadType.story,
      id: tempId,
    );
    if (url == null) {
      dire("La photo n'a pas pu être envoyée.", erreur: true);
      return;
    }
    echec = await notifier.createStory(
      authorId: user.uid,
      authorName: authorName,
      authorPhotoUrl: authorPhotoUrl,
      mediaUrl: url,
      mediaType: StoryMediaType.image,
      audience: audience,
    );
  }

  if (echec != null) {
    dire(echec, erreur: true);
  } else {
    dire('Story publiée · ${audience.label}');
  }
}
