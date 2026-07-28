import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../shared/widgets/dn_sheet_handle.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/adaptive_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../audio_rooms/domain/entities/audio_room_entity.dart';
import '../../domain/entities/podcast_entity.dart';
import '../providers/podcast_provider.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';
import 'package:diaspo_niger/core/errors/error_handler.dart';

/// Bottom sheet to save an audio room recording as a podcast episode
class SaveAsPodcastSheet extends ConsumerStatefulWidget {
  final AudioRoomEntity room;
  final String? recordingPath;
  final int? durationSeconds;

  const SaveAsPodcastSheet({
    super.key,
    required this.room,
    this.recordingPath,
    this.durationSeconds,
  });

  static Future<void> show(
    BuildContext context, {
    required AudioRoomEntity room,
    String? recordingPath,
    int? durationSeconds,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => SaveAsPodcastSheet(
            room: room,
            recordingPath: recordingPath,
            durationSeconds: durationSeconds,
          ),
    );
  }

  @override
  ConsumerState<SaveAsPodcastSheet> createState() => _SaveAsPodcastSheetState();
}

class _SaveAsPodcastSheetState extends ConsumerState<SaveAsPodcastSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  PodcastEntity? _selectedPodcast;
  bool _isLoading = false;
  bool _createNewPodcast = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill with room title
    _titleController.text = widget.room.title;
    _descriptionController.text = widget.room.description ?? '';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveEpisode() async {
    if (!_formKey.currentState!.validate()) return;

    final l10n = AppLocalizations.of(context)!;
    if (_selectedPodcast == null && !_createNewPodcast) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.podcastsSelectOrCreate),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // For now, show a message that the feature requires a recording
      // In production, this would access the actual recording file
      if (widget.recordingPath == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.podcastsRecordingSoon),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.pop(context);
        return;
      }

      final audioFile = File(widget.recordingPath!);
      if (!await audioFile.exists()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.podcastsAudioFileNotFound),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final podcastNotifier = ref.read(podcastNotifierProvider.notifier);

      // Create episode
      final episode = await podcastNotifier.createEpisode(
        podcastId: _selectedPodcast!.id,
        title: _titleController.text.trim(),
        description:
            _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
        audioFile: audioFile,
        durationSeconds: widget.durationSeconds ?? 0,
        sourceRoomId: widget.room.id,
      );

      if (!mounted) return;

      if (episode != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.podcastsEpisodePublished),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.podcastsPublishError),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ErrorHandler.instance.getShortMessage(
              ErrorHandler.instance.handleException(e),
            ),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final myPodcasts = ref.watch(myPodcastsProvider);
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: EdgeInsets.only(bottom: bottomPadding),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  const DnSheetHandle(),
                  const SizedBox(height: 20),

                  // Title
                  Row(
                    children: [
                      const AppIcon(
                        AppIcon.podcasts,
                        color: Colors.deepPurple,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.podcastsSaveAsPodcast,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.podcastsSaveAsPodcastDesc,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.onSurfaceColor.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Select Podcast Section
                  Text(
                    l10n.podcastsSelectPodcast,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),

                  myPodcasts.when(
                    data: (podcasts) {
                      if (podcasts.isEmpty) {
                        return _buildNoPodcastsMessage();
                      }

                      return Column(
                        children: [
                          // Existing podcasts
                          ...podcasts.map(
                            (podcast) => _buildPodcastOption(podcast),
                          ),

                          // Create new option
                          _buildCreateNewOption(),
                        ],
                      );
                    },
                    loading:
                        () => const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                    error: (e, _) => _buildNoPodcastsMessage(),
                  ),

                  const SizedBox(height: 24),

                  // Episode Title
                  Text(
                    l10n.podcastsEpisodeTitleInput,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      hintText: l10n.podcastsEpisodeTitleInput,
                      filled: true,
                      fillColor: context.backgroundColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return l10n.podcastsEpisodeTitleRequired;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Episode Description
                  Text(
                    l10n.podcastsPodcastDescription,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: l10n.podcastsEpisodeDescriptionInput,
                      filled: true,
                      fillColor: context.backgroundColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Room Info
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.headphones_rounded,
                          color: Colors.deepPurple,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.podcastsSourceRoom,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: Colors.deepPurple),
                              ),
                              Text(
                                widget.room.title,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                        if (widget.durationSeconds != null)
                          Text(
                            _formatDuration(widget.durationSeconds!),
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.deepPurple,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed:
                              _isLoading ? null : () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(l10n.cancel),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _saveEpisode,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child:
                              _isLoading
                                  ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                  : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.publish_rounded, size: 20),
                                      const SizedBox(width: 8),
                                      Text(l10n.podcastsPublish),
                                    ],
                                  ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPodcastOption(PodcastEntity podcast) {
    final isSelected = _selectedPodcast?.id == podcast.id && !_createNewPodcast;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPodcast = podcast;
          _createNewPodcast = false;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? Colors.deepPurple.withValues(alpha: 0.1)
                  : context.backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.deepPurple : context.borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Cover
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.deepPurple.withValues(alpha: 0.2),
                image:
                    podcast.coverImageUrl.isNotEmpty
                        ? DecorationImage(
                          image: NetworkImage(podcast.coverImageUrl),
                          fit: BoxFit.cover,
                        )
                        : null,
              ),
              child:
                  podcast.coverImageUrl.isEmpty
                      ? const AppIcon(AppIcon.podcasts, color: Colors.deepPurple)
                      : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    podcast.title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    AppLocalizations.of(context)!.podcastsEpisodes(podcast.totalEpisodes),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.onSurfaceColor.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const AppIcon(AppIcon.checkCircle, color: Colors.deepPurple),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateNewOption() {
    return GestureDetector(
      onTap: () {
        // Navigate to create podcast screen
        Navigator.pop(context);
        Navigator.pushNamed(context, '/podcasts/create');
      },
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: context.borderColor,
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.deepPurple.withValues(alpha: 0.1),
              ),
              child: const AppIcon(AppIcon.add, color: Colors.deepPurple),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.podcastsCreateNewPodcast,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.deepPurple,
                    ),
                  ),
                  Text(
                    AppLocalizations.of(context)!.podcastsStartSeries,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.onSurfaceColor.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: Colors.deepPurple,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoPodcastsMessage() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const AppIcon(AppIcon.podcasts, size: 48, color: Colors.orange),
          const SizedBox(height: 12),
          Text(
            AppLocalizations.of(context)!.podcastsNoPodcastsYet,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.podcastsCreateFirstPodcast,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.onSurfaceColor.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/podcasts/create');
            },
            icon: const Icon(Icons.add_rounded),
            label: Text(AppLocalizations.of(context)!.podcastsCreatePodcast),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }
}
