import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/core/services/e2ee/undecryptable_placeholders.dart';
import 'package:diaspo_niger/features/messages/domain/entities/message_entity.dart';
import 'package:diaspo_niger/features/messages/presentation/utils/message_copy_text.dart';

/// « Je n'arrive pas à faire certains types de copie » (2026-09-12) : Copier
/// n'existait que pour les messages texte.
void main() {
  MessageEntity msg(
    MessageType type, {
    String content = '',
    String? fileName,
    String? fileUrl,
    String? adresse,
    double? lat,
    double? lng,
    bool supprime = false,
    String nom = 'Salim',
    DateTime? le,
  }) =>
      MessageEntity(
        id: 'm-${type.name}-$content',
        senderId: nom.toLowerCase(),
        senderName: nom,
        content: content,
        type: type,
        fileName: fileName,
        fileUrl: fileUrl,
        locationAddress: adresse,
        latitude: lat,
        longitude: lng,
        deletedForEveryone: supprime,
        createdAt: le ?? DateTime(2026, 9, 12, 21, 4),
      );

  group('messageCopyText', () {
    test('texte : le texte tel quel, mise en forme comprise', () {
      expect(
        messageCopyText(msg(MessageType.text, content: 'Salut *toi* ❤️')),
        'Salut *toi* ❤️',
      );
    });

    test('photo et vidéo : la légende', () {
      expect(
        messageCopyText(
          msg(MessageType.image, content: 'Niamey au lever', fileName: 'a.jpg'),
        ),
        'Niamey au lever',
      );
      expect(
        messageCopyText(msg(MessageType.video, content: 'Le mariage')),
        'Le mariage',
      );
    });

    test('photo sans légende : rien (content = nom ou URL du fichier)', () {
      expect(
        messageCopyText(
          msg(MessageType.image, content: 'a.jpg', fileName: 'a.jpg'),
        ),
        isNull,
      );
      expect(
        messageCopyText(
          msg(MessageType.video, content: 'https://x/v.mp4', fileUrl: 'https://x/v.mp4'),
        ),
        isNull,
      );
      expect(messageCopyText(msg(MessageType.image)), isNull);
    });

    test('position : adresse puis lien de carte', () {
      expect(
        messageCopyText(
          msg(MessageType.location, adresse: 'Plateau, Niamey', lat: 13.5, lng: 2.1),
        ),
        'Plateau, Niamey\n'
        'https://www.google.com/maps/search/?api=1&query=13.5,2.1',
      );
      expect(
        messageCopyText(msg(MessageType.location, lat: 13.5, lng: 2.1)),
        'https://www.google.com/maps/search/?api=1&query=13.5,2.1',
      );
    });

    test('sondage : la question', () {
      expect(
        messageCopyText(msg(MessageType.poll, content: 'On se voit samedi ?')),
        'On se voit samedi ?',
      );
    });

    test('rien à copier : supprimé, illisible, vocal, sticker, document', () {
      expect(
        messageCopyText(msg(MessageType.text, content: 'x', supprime: true)),
        isNull,
      );
      for (final marqueur in kUndecryptablePlaceholders) {
        expect(
          messageCopyText(msg(MessageType.text, content: marqueur)),
          isNull,
          reason: 'un marqueur technique ne part pas dans le presse-papiers',
        );
      }
      expect(messageCopyText(msg(MessageType.voiceNote)), isNull);
      expect(messageCopyText(msg(MessageType.sticker)), isNull);
      expect(
        messageCopyText(msg(MessageType.file, content: 'cv.pdf', fileName: 'cv.pdf')),
        isNull,
      );
    });
  });

  group('selectionCopyText', () {
    test('un seul message copiable : son texte brut', () {
      expect(
        selectionCopyText([
          msg(MessageType.voiceNote),
          msg(MessageType.text, content: 'Bonjour'),
        ]),
        'Bonjour',
      );
    });

    test('plusieurs : horodatés, nommés, dans l\'ordre chronologique', () {
      expect(
        selectionCopyText([
          msg(
            MessageType.text,
            content: 'Très bien',
            nom: 'Sim',
            le: DateTime(2026, 9, 12, 21, 6),
          ),
          msg(MessageType.text, content: 'Ça va ?'),
          msg(MessageType.sticker),
        ]),
        '[12/09/2026 21:04] Salim : Ça va ?\n'
        '[12/09/2026 21:06] Sim : Très bien',
      );
    });

    test('rien de copiable : null', () {
      expect(selectionCopyText([msg(MessageType.sticker)]), isNull);
      expect(selectionCopyText(const []), isNull);
    });
  });
}
