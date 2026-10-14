part of 'message_bubble.dart';

/// Actions sur le contenu : enregistrer, ouvrir, partager, suivre un lien.
extension _ActionsBulle on _MessageBubbleState {
  Future<void> _saveImageToGallery(String imageUrl) async {
    final service = FileDownloadService();
    final hasPermission = await service.hasGalleryPermission();
    if (!hasPermission) {
      final granted = await service.requestGalleryPermission();
      if (!granted) return;
    }
    final success = estUrlLocale(imageUrl)
        ? await enregistrerImageLocaleDansGalerie(cheminDepuisUrlLocale(imageUrl))
        : await service.downloadImageToGallery(
          imageUrl,
          messageId: widget.message.id,
        );
    if (mounted) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? l10n.imageSaved : l10n.saveFailed),
          backgroundColor: success ? Colors.green : Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _saveVideoToDevice(String videoUrl) async {
    final msg = widget.message;
    final bool ok;
    if (estUrlLocale(videoUrl)) {
      // Vidéo chiffrée, déjà déchiffrée sur l'appareil par MediaChiffreGate.
      // Télécharger son URL distante enregistrerait le blob chiffré — ce que
      // faisait l'ancien code, avec « Vidéo enregistrée » à l'écran.
      final service = FileDownloadService();
      if (!await service.hasGalleryPermission() &&
          !await service.requestGalleryPermission()) {
        return;
      }
      ok = await enregistrerVideoLocaleDansGalerie(
        cheminDepuisUrlLocale(videoUrl),
      );
    } else {
      final fileName =
          msg.fileName?.isNotEmpty == true ? msg.fileName! : '${msg.id}.mp4';
      final file = await FileDownloadService().downloadToAppDirectory(
        videoUrl,
        fileName: fileName,
        messageId: msg.id,
      );
      ok = file != null;
    }
    if (mounted) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? l10n.videoSaved : l10n.saveFailed),
          backgroundColor: ok ? Colors.green : Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _openFile(String? url) async {
    if (url == null) return;
    // Document déchiffré : pas d'URL à ouvrir dans un navigateur, on passe
    // par la feuille de partage du système, qui sait « ouvrir avec ».
    if (estUrlLocale(url)) {
      await SharePlus.instance.share(
        ShareParams(files: [XFile(cheminDepuisUrlLocale(url))]),
      );
      return;
    }
    // Add https:// if no protocol is specified
    String normalizedUrl = url;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      normalizedUrl = 'https://$url';
    }
    final uri = Uri.parse(normalizedUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _shareMessage() async {
    final l10n = AppLocalizations.of(context)!;
    final scaffold = ScaffoldMessenger.of(context);
    final message = widget.message;

    try {
      if (message.type == MessageType.text) {
        await SharePlus.instance.share(ShareParams(text: message.content));
        return;
      }

      // Média chiffré : partager le fichier déjà déchiffré (cache), jamais
      // le blob que `fileUrl` désigne.
      final mediaChiffre = message.mediaChiffre;
      if (mediaChiffre != null) {
        final chemin = await ref.read(
          mediaDechiffreProvider(
            DemandeMediaDechiffre(message.id, mediaChiffre),
          ).future,
        );
        final legende =
            message.content.isNotEmpty && message.content != message.fileName
                ? message.content
                : '';
        await SharePlus.instance.share(
          ShareParams(files: [XFile(chemin)], text: legende),
        );
        return;
      }

      final url = message.fileUrl;
      if (url == null || url.isEmpty) {
        scaffold.showSnackBar(
          SnackBar(
            content: Text(l10n.shareError),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      scaffold.showSnackBar(
        SnackBar(
          content: Text(l10n.shareDownloadingMedia),
          duration: const Duration(seconds: 1),
        ),
      );

      String fileName = message.fileName ?? '';
      if (fileName.isEmpty) {
        final ext = url.split('.').last.split('?').first;
        final sanitized = ext.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
        fileName =
            'shared_${message.type.name}_${DateTime.now().millisecondsSinceEpoch}.${sanitized.isNotEmpty ? sanitized : 'file'}';
      }

      final file = await FileDownloadService().downloadToTemp(
        url,
        fileName: fileName,
      );

      if (file == null) {
        scaffold.showSnackBar(
          SnackBar(
            content: Text(l10n.shareError),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final caption =
          message.content.isNotEmpty &&
                  message.content != message.fileName &&
                  message.content != message.fileUrl
              ? message.content
              : '';

      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: caption),
      );
    } catch (e) {
      scaffold.showSnackBar(
        SnackBar(
          content: Text(l10n.shareError),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleLinkTap(_LinkMatch match) async {
    switch (match.type) {
      case _LinkType.url:
        // Un lien de l'app s'ouvre dans l'app, empilé sur la discussion. La
        // boîte de confirmation protège d'un site tiers, pas de nos propres
        // écrans — et par `launchUrl`, Android renvoyait le lien à l'app, dont
        // le `router.go` effaçait la discussion de la pile.
        final route = QrCodeParser.routeInterne(match.text);
        if (route != null) {
          if (mounted) unawaited(context.push(route));
          break;
        }
        final confirmed = await _showUrlConfirmDialog(match.text);
        if (confirmed == true) {
          await _openFile(match.text);
        }
        break;
      case _LinkType.phone:
        final cleanNumber = match.text.replaceAll(RegExp(r'[\s.\-()]'), '');
        final confirmed = await _showPhoneConfirmDialog(cleanNumber);
        if (confirmed == true) {
          final uri = Uri.parse('tel:$cleanNumber');
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri);
          }
        }
        break;
      case _LinkType.email:
        final uri = Uri.parse('mailto:${match.text}');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
        break;
      case _LinkType.mention:
        // `match.text` porte le `@` : le pseudo commence après.
        final handle = match.text.startsWith('@')
            ? match.text.substring(1)
            : match.text;
        final userId = widget.message.mentionedUsers
            .where((m) => mentionHandleMatches(m.name, handle))
            .map((m) => m.id)
            .firstOrNull;
        if (userId != null && mounted) unawaited(context.push('/profile/$userId'));
        break;
    }
  }

  Future<bool?> _showPhoneConfirmDialog(String phoneNumber) {
    final l10n = AppLocalizations.of(context)!;
    return showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.phone, color: AppColors.success),
                const SizedBox(width: 8),
                Text(l10n.audioCall),
              ],
            ),
            content: Text('${l10n.callConfirmMessage} $phoneNumber ?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l10n.audioCall),
              ),
            ],
          ),
    );
  }

  Future<bool?> _showUrlConfirmDialog(String url) {
    final l10n = AppLocalizations.of(context)!;
    return showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  Icons.open_in_browser,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(l10n.openLink),
              ],
            ),
            content: Text('${l10n.openLinkConfirmMessage}\n\n$url'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l10n.open),
              ),
            ],
          ),
    );
  }
}

