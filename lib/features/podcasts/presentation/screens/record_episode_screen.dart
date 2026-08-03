import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/audio_recording_service.dart';
import '../../../../core/services/video_upload_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/podcast_episode_entity.dart';
import '../providers/podcast_provider.dart';
import 'package:diaspo_niger/shared/widgets/app_icon.dart';
import 'package:diaspo_niger/core/errors/error_handler.dart';

/// Screen for recording/uploading a podcast episode
class RecordEpisodeScreen extends ConsumerStatefulWidget {
  final String podcastId;

  const RecordEpisodeScreen({super.key, required this.podcastId});

  @override
  ConsumerState<RecordEpisodeScreen> createState() =>
      _RecordEpisodeScreenState();
}

class _RecordEpisodeScreenState extends ConsumerState<RecordEpisodeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Media mode
  bool _isVideoMode = false;

  // Audio state
  File? _audioFile;
  String? _audioFileName;

  // Enregistrement micro en direct (le service est partagé avec les messages
  // vocaux : on ne l'arrête jamais globalement, on annule seulement le nôtre).
  final _recorder = AudioRecordingService();
  bool _isRecording = false;
  bool _isRecordingPaused = false;
  int _recordSeconds = 0;
  double _amplitude = 0;
  StreamSubscription<int>? _durationSub;
  StreamSubscription<double>? _amplitudeSub;

  // Video state
  File? _videoFile;
  String? _videoThumbnailUrl;
  double _videoUploadProgress = 0;

  int _durationSeconds = 0;
  bool _isPremium = false;
  bool _isLoading = false;
  final List<ChapterEntity> _chapters = [];

  final _videoUploadService = VideoUploadService();

  @override
  void dispose() {
    _durationSub?.cancel();
    _amplitudeSub?.cancel();
    // Quitter l'écran en cours d'enregistrement doit libérer le micro.
    if (_isRecording) _recorder.cancelRecording();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final l10n = AppLocalizations.of(context)!;

    final path = await _recorder.startRecording();
    if (path == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.podcastRecordPermissionDenied)),
        );
      }
      return;
    }

    _durationSub = _recorder.durationStream.listen((s) {
      if (mounted) setState(() => _recordSeconds = s);
    });
    _amplitudeSub = _recorder.amplitudeStream.listen((a) {
      if (mounted) setState(() => _amplitude = a);
    });

    setState(() {
      _isRecording = true;
      _isRecordingPaused = false;
      _recordSeconds = 0;
      _amplitude = 0;
      // Un nouvel enregistrement remplace le fichier importé précédemment.
      _audioFile = null;
      _audioFileName = null;
    });
  }

  Future<void> _togglePauseRecording() async {
    if (_isRecordingPaused) {
      await _recorder.resumeRecording();
    } else {
      await _recorder.pauseRecording();
    }
    if (mounted) setState(() => _isRecordingPaused = !_isRecordingPaused);
  }

  Future<void> _stopRecording() async {
    final l10n = AppLocalizations.of(context)!;
    final result = await _recorder.stopRecording();
    await _durationSub?.cancel();
    await _amplitudeSub?.cancel();
    _durationSub = null;
    _amplitudeSub = null;

    if (!mounted) return;

    if (result == null) {
      setState(() {
        _isRecording = false;
        _isRecordingPaused = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.podcastRecordFailed)),
      );
      return;
    }

    final (file, duration, _) = result;
    setState(() {
      _isRecording = false;
      _isRecordingPaused = false;
      _audioFile = file;
      _audioFileName = l10n.podcastRecordedFileName;
      // Durée exacte, contrairement à l'estimation par taille de fichier de
      // l'import.
      _durationSeconds = duration;
    });
  }

  Future<void> _cancelRecording() async {
    await _recorder.cancelRecording();
    await _durationSub?.cancel();
    await _amplitudeSub?.cancel();
    _durationSub = null;
    _amplitudeSub = null;
    if (mounted) {
      setState(() {
        _isRecording = false;
        _isRecordingPaused = false;
        _recordSeconds = 0;
        _amplitude = 0;
      });
    }
  }

  Future<void> _pickVideoFile() async {
    final result = await _videoUploadService.pickVideoFromGallery();
    if (result.cancelled) return;
    if (result.errorMessage != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.errorMessage!)),
        );
      }
      return;
    }
    final duration = await _videoUploadService.getVideoDuration(result.file!.path);
    final thumbnail = await _videoUploadService.generateThumbnail(result.file!.path);
    setState(() {
      _videoFile = result.file;
      _videoThumbnailUrl = thumbnail?.path;
      _durationSeconds = duration;
    });
  }

  Future<void> _pickAudioFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );

    if (result != null && result.files.isNotEmpty) {
      final file = File(result.files.first.path!);
      setState(() {
        _audioFile = file;
        _audioFileName = result.files.first.name;
        // Estimate duration from file size (rough estimate)
        // ~128kbps = ~16KB/s
        final sizeInBytes = file.lengthSync();
        _durationSeconds = (sizeInBytes / (16 * 1024)).round();
      });
    }
  }

  void _addChapter(AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (ctx) {
        final titleController = TextEditingController();
        final minutesController = TextEditingController();
        final secondsController = TextEditingController();

        return AlertDialog(
          title: Text(l10n.podcastsAddChapterDialog),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: l10n.podcastsChapterTitleLabel,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: minutesController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: l10n.podcastsMinutes),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(':'),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: secondsController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: l10n.podcastsSeconds),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.podcastsCancel),
            ),
            ElevatedButton(
              onPressed: () {
                final title = titleController.text.trim();
                final minutes = int.tryParse(minutesController.text) ?? 0;
                final seconds = int.tryParse(secondsController.text) ?? 0;
                final startSeconds = minutes * 60 + seconds;

                if (title.isNotEmpty) {
                  setState(() {
                    _chapters.add(
                      ChapterEntity(title: title, startSeconds: startSeconds),
                    );
                    _chapters.sort(
                      (a, b) => a.startSeconds.compareTo(b.startSeconds),
                    );
                  });
                }
                Navigator.pop(ctx);
              },
              child: Text(l10n.podcastsAdd),
            ),
          ],
        );
      },
    );
  }

  Future<void> _publishEpisode() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    if (!_isVideoMode && _audioFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.podcastsSelectAudioFile)),
      );
      return;
    }

    if (_isVideoMode && _videoFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.selectVideoFirst)),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? uploadedVideoUrl;
      String? uploadedThumbnailUrl;

      if (_isVideoMode && _videoFile != null) {
        final tempId = DateTime.now().millisecondsSinceEpoch.toString();
        final result = await _videoUploadService.uploadEpisodeVideo(
          file: _videoFile!,
          podcastId: widget.podcastId,
          episodeId: tempId,
          onProgress: (p) => setState(() => _videoUploadProgress = p),
        );
        uploadedVideoUrl = result?.videoUrl;
        uploadedThumbnailUrl = result?.thumbnailUrl;
        if (result != null) _durationSeconds = result.durationSeconds;
      }

      final episode = await ref
          .read(podcastNotifierProvider.notifier)
          .createEpisode(
            podcastId: widget.podcastId,
            title: _titleController.text.trim(),
            description:
                _descriptionController.text.trim().isNotEmpty
                    ? _descriptionController.text.trim()
                    : null,
            audioFile: _isVideoMode ? File('') : _audioFile!,
            durationSeconds: _durationSeconds,
            chapters: _chapters,
            isPremium: _isPremium,
            mediaType: _isVideoMode ? 'video' : 'audio',
            videoUrl: uploadedVideoUrl,
            thumbnailUrl: uploadedThumbnailUrl,
          );

      if (episode != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.podcastsEpisodePublished)),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(
            content: Text(
              ErrorHandler.instance.getShortMessage(
                ErrorHandler.instance.handleException(e),
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Carte d'enregistrement micro : bouton unique au repos, chrono + niveau
  /// d'entrée + pause/terminer/annuler pendant l'enregistrement.
  Widget _buildRecorderCard(AppLocalizations l10n) {
    final theme = Theme.of(context);

    if (!_isRecording) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                l10n.podcastRecordMicHint,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _startRecording,
                  icon: const Icon(Icons.mic_rounded),
                  label: Text(l10n.podcastRecordStart),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      color: theme.colorScheme.errorContainer.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  _isRecordingPaused
                      ? Icons.pause_circle_filled_rounded
                      : Icons.fiber_manual_record,
                  color: theme.colorScheme.error,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.podcastRecordMicTitle,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Text(
                  _formatDuration(_recordSeconds),
                  style: const TextStyle(
                    fontFeatures: [FontFeature.tabularFigures()],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Niveau d'entrée : la seule preuve visible que le micro capte.
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: _isRecordingPaused ? 0 : _amplitude,
                minHeight: 6,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(theme.colorScheme.error),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _togglePauseRecording,
                    icon: Icon(
                      _isRecordingPaused
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded,
                    ),
                    label: Text(
                      _isRecordingPaused
                          ? l10n.podcastRecordResume
                          : l10n.podcastRecordPause,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _stopRecording,
                    icon: const Icon(Icons.stop_rounded),
                    label: Text(l10n.podcastRecordStop),
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: _cancelRecording,
              child: Text(
                l10n.podcastRecordDiscard,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}min ${secs}s';
    }
    return '${minutes}min ${secs}s';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.podcastsNewEpisodeTitle)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Media mode selector
            Center(
              child: SegmentedButton<bool>(
                segments: [
                  ButtonSegment(value: false, label: Text(AppLocalizations.of(context)!.audioLabel), icon: const Icon(Icons.headphones)),
                  ButtonSegment(value: true, label: Text(AppLocalizations.of(context)!.videoLabel), icon: AppIcon(AppIcon.video, color: Theme.of(context).iconTheme.color!)),
                ],
                selected: {_isVideoMode},
                onSelectionChanged: (s) => setState(() => _isVideoMode = s.first),
              ),
            ),
            const SizedBox(height: 16),

            // File picker (audio or video based on mode)
            if (_isVideoMode) ...[
              Card(
                child: InkWell(
                  onTap: _pickVideoFile,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        if (_videoFile != null && _videoThumbnailUrl != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(_videoThumbnailUrl!),
                              height: 120,
                              fit: BoxFit.cover,
                            ),
                          )
                        else
                          Icon(
                            _videoFile != null ? Icons.video_file : Icons.upload_file,
                            size: 48,
                            color: _videoFile != null
                                ? Theme.of(context).primaryColor
                                : Colors.grey,
                          ),
                        const SizedBox(height: 12),
                        Text(
                          _videoFile != null
                              ? VideoUploadService.displayName(_videoFile!)
                              : 'Sélectionner une vidéo (max 100 Mo)',
                          style: TextStyle(color: _videoFile != null ? null : Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                        if (_isLoading && _videoUploadProgress > 0) ...[
                          const SizedBox(height: 12),
                          LinearProgressIndicator(value: _videoUploadProgress),
                          Text(
                            '${(_videoUploadProgress * 100).toStringAsFixed(0)} %',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ] else ...[
              // Audio file picker
              Card(
                child: InkWell(
                  onTap: _pickAudioFile,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(
                          _audioFile != null ? Icons.audio_file : Icons.upload_file,
                          size: 48,
                          color: _audioFile != null
                              ? Theme.of(context).primaryColor
                              : Colors.grey,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _audioFile != null
                              ? _audioFileName ?? l10n.podcastsFileSelected
                              : l10n.podcastsAudioFileTitle,
                          style: TextStyle(
                            color: _audioFile != null ? null : Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (_audioFile != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            l10n.podcastsEstimatedDuration(
                              _formatDuration(_durationSeconds),
                            ),
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Enregistrement micro : seul l'import de fichier existait, on ne
              // pouvait pas produire un épisode depuis le téléphone.
              _buildRecorderCard(l10n),
            ],
            const SizedBox(height: 24),

            // Title
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: l10n.podcastsEpisodeTitle,
                border: const OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return l10n.podcastsEpisodeTitleRequired;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: l10n.podcastsDescriptionNotes,
                border: const OutlineInputBorder(),
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 16),

            // Chapters
            Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.podcastsChapters,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => _addChapter(l10n),
                          icon: AppIcon(AppIcon.add, color: Theme.of(context).iconTheme.color!),
                          label: Text(l10n.podcastsAdd),
                        ),
                      ],
                    ),
                  ),
                  if (_chapters.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 16,
                        right: 16,
                        bottom: 16,
                      ),
                      child: Text(
                        l10n.podcastsNoChaptersAdded,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _chapters.length,
                      itemBuilder: (context, index) {
                        final chapter = _chapters[index];
                        return ListTile(
                          leading: CircleAvatar(child: Text('${index + 1}')),
                          title: Text(chapter.title),
                          subtitle: Text(chapter.formattedStartTime),
                          trailing: IconButton(
                            icon: const AppIcon(AppIcon.delete),
                            onPressed: () {
                              setState(() => _chapters.removeAt(index));
                            },
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Premium toggle
            SwitchListTile(
              title: Text(l10n.podcastsPremiumEpisode),
              subtitle: Text(l10n.podcastsPremiumEpisodeDesc),
              value: _isPremium,
              onChanged: (value) => setState(() => _isPremium = value),
            ),
            const SizedBox(height: 24),

            // Publish button
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _publishEpisode,
                icon:
                    _isLoading
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.publish),
                label: Text(
                  _isLoading ? l10n.podcastsPublishing : l10n.podcastsPublishEpisode,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
