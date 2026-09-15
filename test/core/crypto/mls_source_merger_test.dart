import 'package:diaspo_niger/core/crypto/mls/mls_message_mapper.dart';
import 'package:diaspo_niger/core/crypto/mls/mls_source_merger.dart';
import 'package:diaspo_niger/features/messages/domain/entities/message_entity.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ce que ces tests protègent (plan MLS § 2.3, phase 5)
/// ----------------------------------------------------
/// Une conversation qui bascule à MLS garde son historique : celui-ci est
/// gelé, lisible par le serveur, et ne peut pas être ré-encapsulé (produire
/// un ciphertext MLS exigerait des clés que personne ne doit avoir). Les deux
/// sources cohabitent donc dans le même fil, séparées par un repère visible.
///
/// Ce que ces tests empêchent, concrètement : un séparateur affiché sans
/// raison — qui ferait croire à l'utilisateur qu'une partie de ses messages
/// n'est pas chiffrée alors que tout l'est —, et un séparateur compté comme
/// un message par ce qui compte les messages.

MessageEntity _m(String id, DateTime quand, {String contenu = ''}) => MessageEntity(
      id: id,
      senderId: 'u1',
      senderName: 'Amina',
      content: contenu.isEmpty ? id : contenu,
      type: MessageType.text,
      status: MessageStatus.sent,
      createdAt: quand,
    );

void main() {
  final t0 = DateTime(2026, 9, 1, 10);
  final bascule = DateTime(2026, 9, 15, 12);

  group('fusion des deux sources', () {
    test('legacy puis séparateur puis MLS, dans l’ordre', () {
      final fusion = MlsSourceMerger.fusionner(
        legacy: [_m('vieux1', t0), _m('vieux2', t0.add(const Duration(minutes: 1)))],
        mls: [_m('neuf1', bascule.add(const Duration(minutes: 1)))],
        mlsSince: bascule,
      );
      expect(fusion.map((m) => m.id), [
        'vieux1',
        'vieux2',
        MlsMessageMapper.idSeparateur,
        'neuf1',
      ]);
      // Le séparateur porte la date de bascule : il se range au bon endroit
      // si quelque chose retrie la liste.
      expect(fusion[2].createdAt, bascule);
      expect(fusion[2].type, MessageType.system);
    });

    test('aucun séparateur quand un seul côté a des messages', () {
      // Conversation qui n'a jamais rien reçu en MLS : rien à annoncer.
      expect(
        MlsSourceMerger.fusionner(legacy: [_m('a', t0)], mls: const [], mlsSince: bascule)
            .map((m) => m.id),
        ['a'],
      );
      // Conversation neuve, née après la bascule : tout est chiffré, et dire
      // « messages d'avant » au-dessus du premier message serait un mensonge.
      expect(
        MlsSourceMerger.fusionner(legacy: const [], mls: [_m('b', bascule)], mlsSince: bascule)
            .map((m) => m.id),
        ['b'],
      );
      expect(
        MlsSourceMerger.fusionner(legacy: const [], mls: const [], mlsSince: bascule),
        isEmpty,
      );
    });

    test('sans date de bascule, le séparateur prend celle du premier message MLS', () {
      final quand = bascule.add(const Duration(hours: 3));
      final fusion = MlsSourceMerger.fusionner(
        legacy: [_m('a', t0)],
        mls: [_m('b', quand)],
        mlsSince: null,
      );
      expect(fusion[1].createdAt, quand);
    });
  });

  group('le séparateur n’est pas un message', () {
    test('il se retire de ce qui compte', () {
      final fusion = MlsSourceMerger.fusionner(
        legacy: [_m('a', t0)],
        mls: [_m('b', bascule)],
        mlsSince: bascule,
      );
      expect(fusion, hasLength(3));
      expect(MlsSourceMerger.sansSeparateur(fusion).map((m) => m.id), ['a', 'b']);
    });

    test('son identifiant est réservé et reconnaissable', () {
      expect(MlsMessageMapper.estSeparateur(MlsMessageMapper.separateur(bascule)), isTrue);
      expect(MlsMessageMapper.estSeparateur(_m('a', t0)), isFalse);
      // Un vrai identifiant ne peut pas ressembler à celui-là : les messages
      // portent des uuid ou des identifiants Firestore.
      expect(MlsMessageMapper.idSeparateur.startsWith('__'), isTrue);
    });
  });

  group('type de contenu annoncé au serveur', () {
    test('grossier par construction : il est visible du serveur', () {
      expect(MlsMessageMapper.contentType('text'), 'text');
      // Une photo et une vidéo sont indiscernables côté serveur.
      expect(MlsMessageMapper.contentType('image'), 'media');
      expect(MlsMessageMapper.contentType('video'), 'media');
      expect(MlsMessageMapper.contentType('file'), 'media');
      expect(MlsMessageMapper.contentType('voiceNote'), 'voice');
      expect(MlsMessageMapper.contentType('sticker'), 'sticker');
      // Un type inconnu ne fuit pas : il passe pour du texte.
      expect(MlsMessageMapper.contentType('type_futur'), 'text');
    });
  });
}
