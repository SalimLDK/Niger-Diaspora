import 'package:intl/intl.dart';

import '../../../../core/services/e2ee/undecryptable_placeholders.dart';
import '../../domain/entities/message_entity.dart';

/// Ce que « Copier » met dans le presse-papiers pour un message, ou `null`
/// s'il n'a rien de textuel à copier.
///
/// « Copier » n'existait que pour `MessageType.text` : la légende d'une photo
/// ou d'une vidéo, l'adresse d'une position, la question d'un sondage ne se
/// copiaient pas du tout. Une seule règle, ici, pour l'appui long, la
/// sélection du texte et la sélection multiple.
String? messageCopyText(MessageEntity message) {
  if (message.deletedForEveryone || message.type == MessageType.system) {
    return null;
  }

  switch (message.type) {
    case MessageType.text:
    case MessageType.poll:
      return _lisible(message.content);

    case MessageType.image:
    case MessageType.video:
      // Sans légende, `content` reprend le nom ou l'URL du fichier : ce n'est
      // pas un texte que l'utilisateur a écrit.
      if (message.content == message.fileName ||
          message.content == message.fileUrl) {
        return null;
      }
      return _lisible(message.content);

    case MessageType.location:
      final adresse = message.locationAddress?.trim() ?? '';
      final lat = message.latitude;
      final lng = message.longitude;
      final lignes = [
        if (adresse.isNotEmpty) adresse,
        // Même lien que la carte de la bulle : collé ailleurs, il s'ouvre.
        if (lat != null && lng != null)
          'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
      ];
      return lignes.isEmpty ? null : lignes.join('\n');

    case MessageType.file:
    case MessageType.audio:
    case MessageType.voiceNote:
    case MessageType.call:
    case MessageType.sticker:
    case MessageType.system:
      return null;
  }
}

/// Texte copié pour une sélection multiple, dans l'ordre chronologique.
///
/// Un seul message copiable : son texte brut, comme l'appui long. Plusieurs :
/// une ligne « [12/09/2026 21:04] Salim : texte » par message, pour que le
/// collage garde qui a dit quoi et quand. Les messages sans texte sont sautés.
String? selectionCopyText(List<MessageEntity> messages) {
  final copiables = [
    for (final m in [...messages]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt)))
      if (messageCopyText(m) case final texte?) (m, texte),
  ];
  if (copiables.isEmpty) return null;
  if (copiables.length == 1) return copiables.single.$2;

  final format = DateFormat('dd/MM/yyyy HH:mm');
  return copiables
      .map((c) => '[${format.format(c.$1.createdAt)}] ${c.$1.senderName} : ${c.$2}')
      .join('\n');
}

String? _lisible(String content) {
  if (content.trim().isEmpty) return null;
  if (kUndecryptablePlaceholders.contains(content)) return null;
  return content;
}
