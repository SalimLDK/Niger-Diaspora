part of 'message_input.dart';

/// Texte : brouillon, mentions, émojis, envoi.
extension _TexteSaisie on _MessageInputState {
  void _loadDraft() {
    final draft = PreferencesService.instance.getMessageDraft(
      widget.conversationId,
    );
    if (draft != null && draft.isNotEmpty) {
      _controller.text = draft;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: draft.length),
      );
      // Le brouillon est injecté depuis initState, avant que le listener du
      // contrôleur ne soit posé : personne ne recalcule l'état dérivé. Sans
      // ça, le bouton reste sur le micro tant que l'utilisateur n'a pas tapé.
      _syncTextState(animateMorph: false);
    }
  }

  /// Recalcule l'état dérivé du texte (`_hasText`, `_showCounter`, morphing)
  /// à partir du contrôleur, au lieu d'attendre une frappe.
  ///
  /// Appelé depuis `initState` (brouillon restauré) : on assigne les champs
  /// directement, le premier build n'a pas encore eu lieu.
  void _syncTextState({required bool animateMorph}) {
    _hasText = _controller.text.trim().isNotEmpty;
    _showCounter = _controller.text.length >= _charCountThreshold;

    if (_hasText) {
      // Pas d'animation à l'ouverture : le bouton d'envoi doit être là d'emblée.
      if (animateMorph) {
        unawaited(_morphController.forward());
      } else {
        _morphController.value = _morphController.upperBound;
      }
    } else {
      if (animateMorph) {
        unawaited(_morphController.reverse());
      } else {
        _morphController.value = _morphController.lowerBound;
      }
    }
  }

  void _scheduleDraftSave() {
    // En modification, le champ porte le texte d'un message déjà envoyé. Le
    // sauver comme brouillon le ferait réapparaître à la réouverture de la
    // conversation, par-dessus celui que l'utilisateur avait commencé.
    if (_enModification) return;
    _draftSaveTimer?.cancel();
    _draftSaveTimer = Timer(const Duration(milliseconds: 500), () {
      unawaited(PreferencesService.instance.saveMessageDraft(
        widget.conversationId,
        _controller.text,
      ));
    });
  }

  void _clearDraft() {
    _draftSaveTimer?.cancel();
    unawaited(PreferencesService.instance.clearMessageDraft(widget.conversationId));
  }

  void _onMentionSelected(MentionCandidate candidate) {
    // On écrit le PSEUDO, pas le nom affiché. Avant, la mention insérait
    // `@Ibrahim Yacouba Maïdaoua` : un jeton à espaces, que la détection ne
    // savait pas relire — elle abandonne dès qu'une espace apparaît, donc seul
    // le premier mot était cherchable.
    final token = candidate.mentionToken;
    final text = _controller.text;
    final triggerOffset = _mentionTriggerOffset!;
    final cursor = _controller.selection.baseOffset;
    final newText = text.replaceRange(triggerOffset, cursor, '@$token ');
    _controller.text = newText;
    _controller.selection = TextSelection.collapsed(
      offset: triggerOffset + token.length + 2,
    );

    final mention = MentionedUser(id: candidate.id, name: token);
    if (!_pendingMentions.any((m) => m.id == mention.id)) {
      _pendingMentions = [..._pendingMentions, mention];
    }
    _clearMentionState();
    _focusNode.requestFocus();
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    // En modification, le bouton applique. Ni `clear` ni `_clearDraft` ici :
    // c'est l'écran qui referme la modification une fois l'écriture faite, et
    // `didUpdateWidget` rend alors le brouillon d'avant. Refusée, la
    // modification reste ouverte avec le texte saisi — on ne le perd pas.
    if (_enModification) {
      widget.onSubmitEdit?.call(text);
      return;
    }

    final finalMentions =
        _pendingMentions.where((m) => text.contains('@${m.name}')).toList();

    widget.onSendText(text, finalMentions);
    _pendingMentions = [];
    _clearMentionState();
    _controller.clear();
    _clearDraft();
    _focusNode.requestFocus();
  }

  void _onEmojiSelected(
    emoji_picker.Category? category,
    emoji_picker.Emoji emoji,
  ) {
    final text = _controller.text;
    final selection = _controller.selection;
    final start = selection.start >= 0 ? selection.start : text.length;
    final end = selection.end >= 0 ? selection.end : text.length;
    final newText = text.replaceRange(start, end, emoji.emoji);
    _controller.text = newText;
    _controller.selection = TextSelection.collapsed(
      offset: start + emoji.emoji.length,
    );
  }

  void _onBackspacePressed() {
    final text = _controller.text;
    final selection = _controller.selection;
    if (text.isNotEmpty && selection.start > 0) {
      // Handle emoji deletion (emojis can be multiple code units)
      final beforeCursor = text.substring(0, selection.start);
      final characters = beforeCursor.characters.toList();
      if (characters.isNotEmpty) {
        characters.removeLast();
        final newText = characters.join() + text.substring(selection.end);
        _controller.text = newText;
        _controller.selection = TextSelection.collapsed(
          offset: characters.join().length,
        );
      }
    }
  }

  void _showCameraPermissionError(PermissionResult result) {
    final l10n = AppLocalizations.of(context)!;
    final isPermanent = result == PermissionResult.permanentlyDenied;
    final message = PermissionService.getCameraPermissionDeniedMessageLocalized(
      result,
    );

    if (isPermanent) {
      unawaited(PermissionService.showPermissionDeniedDialog(
        context: context,
        title: l10n.cameraPermissionRequiredTitle,
        message: message,
        showSettingsButton: true,
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: context.errorColor),
      );
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx'],
    );

    if (result != null && result.files.single.path != null) {
      widget.onSendFile(File(result.files.single.path!), MessageType.file);
    }
  }
}

