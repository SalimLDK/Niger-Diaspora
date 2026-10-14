part of 'message_input.dart';

/// Pièces jointes : caméra, galerie, vidéo, position, fin d'enregistrement.
extension _PiecesSaisie on _MessageInputState {
  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final video = await picker.pickVideo(source: ImageSource.gallery);

    if (video != null && mounted) {
      // Navigate to preview screen for video
      final result = await Navigator.push<MediaPreviewResult>(
        context,
        MaterialPageRoute(
          builder:
              (_) => MediaPreviewScreen(
                file: File(video.path),
                type: MediaType.video,
                conversationId: widget.conversationId,
              ),
        ),
      );

      if (result != null && mounted) {
        widget.onSendFile(result.file, MessageType.video, caption: result.caption);
      }
    }
  }

  /// Revue groupée (§27d) avant envoi : pellicule + qualité réduite + poids
  /// annoncé. Appelée seulement quand il y a plusieurs médias — 1 seul
  /// continue de passer par [MediaPreviewScreen] (édition Signal-style).
  Future<void> _reviewAndSendBatch(List<GalleryPick> picks) async {
    final result = await Navigator.push<MediaBatchPreviewResult>(
      context,
      MaterialPageRoute(builder: (_) => MediaBatchPreviewScreen(picks: picks)),
    );
    if (result == null || result.picks.isEmpty || !mounted) return;
    for (final p in result.picks) {
      widget.onSendFile(p.file, p.isVideo ? MessageType.video : MessageType.image);
    }
  }

  /// Caméra unifiée (photo/vidéo dans le même écran). 1 média passe par
  /// l'aperçu Signal-style, plusieurs passent par la revue groupée (§27d).
  Future<void> _openCamera() async {
    final permissionResult =
        await PermissionService().requestCameraPermission();
    if (permissionResult != PermissionResult.granted) {
      if (mounted) _showCameraPermissionError(permissionResult);
      return;
    }
    if (!mounted) return;
    final result = await Navigator.push<List<CameraMedia>>(
      context,
      MaterialPageRoute(builder: (_) => const CameraCaptureScreen()),
    );
    if (result == null || result.isEmpty || !mounted) return;
    if (result.length == 1) {
      widget.onSendFile(
        result.first.file,
        result.first.isVideo ? MessageType.video : MessageType.image,
      );
      return;
    }
    await _reviewAndSendBatch(
      result.map((m) => GalleryPick(m.file, m.isVideo)).toList(),
    );
  }

  /// Galerie intégrée (grille photo_manager, jamais le gestionnaire de
  /// fichiers). 1 média passe par l'aperçu, plusieurs passent par la revue
  /// groupée (§27d) avant d'être envoyés.
  Future<void> _pickFromGalleryUnified() async {
    if (!mounted) return;
    final picks = await Navigator.push<List<GalleryPick>>(
      context,
      MaterialPageRoute(builder: (_) => const GalleryPickerScreen()),
    );
    if (picks == null || picks.isEmpty || !mounted) return;
    if (picks.length == 1) {
      final p = picks.first;
      final result = await Navigator.push<MediaPreviewResult>(
        context,
        MaterialPageRoute(
          builder:
              (_) => MediaPreviewScreen(
                file: p.file,
                type: p.isVideo ? MediaType.video : MediaType.image,
                conversationId: widget.conversationId,
              ),
        ),
      );
      if (result != null && mounted) {
        widget.onSendFile(
          result.file,
          result.type == MediaType.video ? MessageType.video : MessageType.image,
          caption: result.caption,
        );
      }
    } else {
      await _reviewAndSendBatch(picks);
    }
  }

  void _showAttachmentOptions() {
    // Unfocus to hide keyboard before showing attachment options
    _focusNode.unfocus();
    final l10n = AppLocalizations.of(context)!;
    unawaited(showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.textTertiaryColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  l10n.sendFileTitle,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: context.textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 24),
                // First row - Caméra (unifiée photo/vidéo) + Galerie intégrée
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _AttachmentOption(
                      icon: Icons.camera_alt,
                      label: l10n.cameraSection,
                      color: AttachmentAccents.camera.of(context),
                      onTap: () {
                        Navigator.pop(context);
                        unawaited(_openCamera());
                      },
                    ),
                    _AttachmentOption(
                      icon: Icons.photo_library,
                      label: l10n.photosLabel,
                      color: AttachmentAccents.gallery.of(context),
                      onTap: () {
                        Navigator.pop(context);
                        unawaited(_pickFromGalleryUnified());
                      },
                    ),
                    _AttachmentOption(
                      icon: Icons.video_library,
                      label: l10n.videosLabel,
                      color: AttachmentAccents.video.of(context),
                      onTap: () {
                        Navigator.pop(context);
                        unawaited(_pickVideo());
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Second row - Audio, Documents
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _AttachmentOption(
                      icon: Icons.audiotrack,
                      label: l10n.audioLabel,
                      color: AttachmentAccents.audio.of(context),
                      onTap: () {
                        Navigator.pop(context);
                        unawaited(_pickAudio());
                      },
                    ),
                    _AttachmentOption(
                      icon: Icons.insert_drive_file,
                      label: l10n.documentsLabel,
                      color: AttachmentAccents.document.of(context),
                      onTap: () {
                        Navigator.pop(context);
                        unawaited(_pickFile());
                      },
                    ),
                  ],
                ),
                if (widget.onCreateEvent != null ||
                    widget.onCreatePoll != null) ...[
                  const SizedBox(height: 16),
                  // Third row - Contenu interactif (Événement, Sondage)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      if (widget.onCreateEvent != null)
                        _AttachmentOption(
                          icon: Icons.event,
                          label: l10n.eventLabel,
                          color: AttachmentAccents.event.of(context),
                          onTap: () {
                            Navigator.pop(context);
                            widget.onCreateEvent!();
                          },
                        ),
                      if (widget.onCreatePoll != null)
                        _AttachmentOption(
                          icon: Icons.poll,
                          label: l10n.pollLabel,
                          color: AttachmentAccents.poll.of(context),
                          onTap: () {
                            Navigator.pop(context);
                            widget.onCreatePoll!();
                          },
                        ),
                    ],
                  ),
                ],
                // La section « Caméra » qui suivait (Photo + Vidéo dédiées)
                // faisait doublon avec la tuile Caméra unifiée de la première
                // rangée, sous un séparateur qui reprenait le même libellé.
                // Location option
                if (widget.onSendLocation != null) ...[
                  const SizedBox(height: 20),
                  // Divider with label
                  Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: context.outlineColor.withValues(alpha: 0.2),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          l10n.locationSection,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.textTertiaryColor,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: context.outlineColor.withValues(alpha: 0.2),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _AttachmentOption(
                        icon: Icons.location_on,
                        label: l10n.positionLabel,
                        color: AttachmentAccents.location.of(context),
                        onTap: () {
                          Navigator.pop(context);
                          unawaited(_showLocationPicker());
                        },
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
              ],
            ),
          ),
    ));
  }

  Future<void> _showLocationPicker() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => LocationPickerModal(
            onLocationSelected: (lat, lng, address) {
              widget.onSendLocation?.call(lat, lng, address);
            },
          ),
    );
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    if (_isCancelling) {
      await _recordingService.cancelRecording();
      await HapticFeedback.lightImpact();
    } else {
      final result = await _recordingService.stopRecording();
      if (result != null && widget.onSendAudio != null) {
        final (file, duration, waveform) = result;
        widget.onSendAudio!(file, duration, waveform);
        await HapticFeedback.mediumImpact();
      }
    }

    _resetRecordingState();
  }

  void _onLongPressRelease() {
    if (!_isRecording) return;

    if (_isCancelling) {
      // Annuler l'enregistrement
      unawaited(_recordingService.cancelRecording());
      unawaited(HapticFeedback.lightImpact());
      _resetRecordingState();
    } else if (!_isLocked) {
      // Envoyer l'enregistrement
      unawaited(_stopRecording());
    }
    // Si verrouillé, ne rien faire - l'utilisateur utilisera les boutons
  }
}

