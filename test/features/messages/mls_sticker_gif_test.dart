import 'dart:typed_data';

import 'package:diaspo_niger/core/crypto/mls/mls_delivery.dart';
import 'package:diaspo_niger/core/crypto/mls/mls_message_mapper.dart';
import 'package:diaspo_niger/core/crypto/mls/mls_payload_codec.dart';
import 'package:diaspo_niger/features/messages/domain/entities/message_entity.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ce que ce banc protège
/// ----------------------
/// Un sticker — et un GIF, qui emprunte le même transport — voyage en MLS
/// avec son URL dans `body['stickerUrl']`. Le mapper ne lisait que
/// `body['storagePath']`, qui n'existe que pour un média chiffré : l'entité
/// sortait avec `fileUrl == null`, `StickerBubble` recevait une chaîne vide,
/// et n'affichait qu'un cadre « image cassée ».
///
/// **L'expéditeur voyait la même chose** : sa propre copie est remappée
/// depuis ce payload dès l'accusé d'envoi. Rien dans le journal, aucune
/// erreur — le message part, s'affiche, et ne montre rien.
///
/// C'est la deuxième fois que ce mapper perd un champ qu'il ne repose pas
/// (voir `mediaChiffre`, corrigé le 2026-09-15) : d'où un banc par champ
/// plutôt qu'une relecture.
MlsMessageRow _ligne({String contentType = 'sticker'}) => MlsMessageRow(
  id: '11111111-1111-4111-8111-111111111111',
  conversationId: 'c1',
  senderId: 'u1',
  senderDeviceId: '22222222-2222-4222-8222-222222222222',
  epoch: 3,
  kind: 'content',
  contentType: contentType,
  ciphertext: Uint8List.fromList(const [1, 2, 3]),
  isDeleted: false,
  createdAt: DateTime.utc(2026, 9, 16, 5),
);

MessageEntity _mappe(String type, Map<String, dynamic> body) =>
    MlsMessageMapper.depuisPayload(
      MlsPayload(
        id: '',
        type: type,
        sentAt: DateTime.utc(2026, 9, 16, 5).millisecondsSinceEpoch,
        body: body,
      ),
      row: _ligne(contentType: type == 'sticker' ? 'sticker' : 'media'),
      senderName: 'Amina',
      currentUserId: 'u2',
    );

void main() {
  group('Sticker et GIF reçus en MLS', () {
    test('l\'URL du fournisseur arrive jusqu\'à la bulle', () {
      final e = _mappe('sticker', const {
        'stickerPackId': 'giphy',
        'stickerId': 'abc123',
        'stickerUrl': 'https://media.giphy.com/abc123.gif',
        'isAnimated': true,
      });

      expect(e.type, MessageType.sticker);
      // `StickerBubble` lit `fileUrl` : vide, elle ne rend qu'un cadre cassé.
      expect(e.fileUrl, 'https://media.giphy.com/abc123.gif');
      expect(e.stickerPackId, 'giphy');
      expect(e.stickerId, 'abc123');
      expect(e.isAnimatedSticker, isTrue);
    });

    test('un GIF se distingue d\'un pack par son stickerPackId', () {
      // Décision d'architecture : pas de `MessageType.gif`, le fournisseur
      // sert d'identifiant de pack. Le mapper doit donc le reposer tel quel.
      expect(
        _mappe('sticker', const {
          'stickerPackId': 'tenor',
          'stickerId': '42',
          'stickerUrl': 'https://media.tenor.com/42.gif',
        }).stickerPackId,
        'tenor',
      );
    });

    test('sans isAnimated, le sticker est fixe plutôt que null', () {
      expect(
        _mappe('sticker', const {
          'stickerPackId': 'p',
          'stickerId': 's',
          'stickerUrl': 'https://x.test/s.webp',
        }).isAnimatedSticker,
        isFalse,
      );
    });

    test('un média chiffré garde son storagePath dans fileUrl', () {
      // Le repli ajouté pour les stickers ne doit pas déplacer le média
      // chiffré, qui se télécharge par `storagePath` et non par une URL.
      final e = _mappe('image', const {
        'storagePath': 'conv/c1/img.enc',
        'fileKey': 'a2V5',
        'fileNonce': 'aXY=',
        'mimeType': 'image/jpeg',
      });

      expect(e.fileUrl, 'conv/c1/img.enc');
      expect(e.mediaChiffre, isNotNull);
    });
  });
}
